-- Correcciones incrementales (no reescriben migraciones ya aplicadas):
-- 1) El jardín admite tareas personales (project_id NULL) y no duplica eventos.
-- 2) Las escrituras del jardín quedan reservadas al trigger de dominio.
-- 3) validate_distribution_sum valida INSERT, UPDATE y DELETE en los 3 modos.

-- ---------------------------------------------------------------------------
-- 1) Jardín: proyecto opcional.
-- ---------------------------------------------------------------------------
alter table public.garden_progress_events
  alter column project_id drop not null;

-- Un evento por ocurrencia como máximo; evita recompensas duplicadas si el
-- trigger se dispara más de una vez para la misma transición.
create unique index if not exists garden_progress_one_per_occurrence
  on public.garden_progress_events (occurrence_id)
  where occurrence_id is not null;

create or replace function public.record_garden_progress()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_task public.tasks%rowtype;
  v_points integer;
  v_total bigint;
  v_flower text;
begin
  if new.status <> 'completed' or old.status = 'completed' then
    return new;
  end if;

  select * into v_task from public.tasks where id = new.task_id;
  if not found then
    return new;
  end if;

  -- Una sola recompensa por ocurrencia, incluso si el estado oscila.
  if exists (
    select 1 from public.garden_progress_events where occurrence_id = new.id
  ) then
    return new;
  end if;

  v_points := case v_task.priority
    when 'urgent' then 40
    when 'high' then 30
    when 'medium' then 20
    else 10
  end;

  -- project_id puede ser NULL: es una tarea personal, no de proyecto.
  insert into public.garden_progress_events
    (project_id, user_id, occurrence_id, event_type, points, flower_type)
  values
    (v_task.project_id,
     coalesce(new.completed_by, v_task.created_by),
     new.id, 'task_completed', v_points, null);

  if v_task.project_id is not null then
    select coalesce(sum(points), 0) into v_total
      from public.garden_progress_events
     where project_id = v_task.project_id;
    v_flower := case
      when v_total >= 400 then 'orchid'
      when v_total >= 250 then 'sunflower'
      when v_total >= 120 then 'tulip'
      when v_total >= 40 then 'daisy'
      else 'sprout'
    end;
  else
    v_flower := 'sprout';
  end if;

  -- Conservamos event_type = 'task_completed' para no perder el origen del
  -- evento; el hito se refleja en flower_type.
  update public.garden_progress_events
     set flower_type = v_flower
   where occurrence_id = new.id;
  return new;
end;
$$;

-- Los usuarios pueden ver su jardín personal y el de los proyectos compartidos,
-- pero no pueden insertar eventos arbitrarios: sólo el trigger los genera.
drop policy if exists garden_select on public.garden_progress_events;
create policy garden_select on public.garden_progress_events for select to authenticated
using (
  (project_id is null and user_id = auth.uid())
  or (project_id is not null and public.can_read_project(project_id))
);
drop policy if exists garden_insert on public.garden_progress_events;

-- ---------------------------------------------------------------------------
-- 2) Distribuciones: validación completa en los tres modos y tres operaciones.
-- ---------------------------------------------------------------------------
create or replace function public.validate_distribution_sum()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_source_type text;
  v_source_id uuid;
  v_mode text;
  v_share numeric(14,4);
  v_total numeric(14,2);
  v_sum numeric(14,4);
  v_count integer;
  v_min numeric(14,4);
  v_max numeric(14,4);
  v_excluded uuid;
begin
  if tg_op = 'DELETE' then
    v_source_type := old.source_type;
    v_source_id := old.source_id;
    v_mode := old.mode;
    v_share := old.share_value;
    v_excluded := old.id;
  else
    v_source_type := new.source_type;
    v_source_id := new.source_id;
    v_mode := new.mode;
    v_share := new.share_value;
    v_excluded := null;
  end if;

  if v_source_type = 'subscription' then
    select amount into v_total from public.subscriptions where id = v_source_id;
  else
    select amount into v_total from public.transactions where id = v_source_id;
  end if;

  if v_total is null then
    raise exception 'La distribución hace referencia a un origen inexistente';
  end if;

  if v_mode = 'amount' then
    if v_share > v_total + 0.01 then
      raise exception 'El importe asignado (%) supera el total (%)', v_share, v_total;
    end if;
    select coalesce(sum(share_value), 0) into v_sum
      from public.cost_distributions
     where source_type = v_source_type
       and source_id = v_source_id
       and mode = 'amount'
       and id is distinct from v_excluded;
    if tg_op <> 'DELETE' then
      v_sum := v_sum + v_share;
    end if;
    if v_sum > v_total + 0.01 then
      raise exception 'La suma de importes (%) supera el total (%)', v_sum, v_total;
    end if;

  elsif v_mode = 'percent' then
    if v_share > 100 then
      raise exception 'El porcentaje asignado (%) supera el 100 %%', v_share;
    end if;
    select coalesce(sum(share_value), 0) into v_sum
      from public.cost_distributions
     where source_type = v_source_type
       and source_id = v_source_id
       and mode = 'percent'
       and id is distinct from v_excluded;
    if tg_op <> 'DELETE' then
      v_sum := v_sum + v_share;
    end if;
    if v_sum > 100 then
      raise exception 'La suma de porcentajes (%) supera el 100 %%', v_sum;
    end if;

  else
    -- 'equal': cada participante aporta exactamente 1 parte.
    if v_share <> 1 then
      raise exception 'En modo equal cada participante debe aportar 1 parte';
    end if;
    select count(*), coalesce(min(share_value), 1), coalesce(max(share_value), 1)
      into v_count, v_min, v_max
      from public.cost_distributions
     where source_type = v_source_type
       and source_id = v_source_id
       and mode = 'equal'
       and id is distinct from v_excluded;
    if tg_op <> 'DELETE' then
      v_count := v_count + 1;
    end if;
    if v_count < 1 then
      raise exception 'La distribución equal necesita al menos un participante';
    end if;
    if v_min <> 1 or v_max <> 1 then
      raise exception 'Todas las partes de una distribución equal deben ser iguales';
    end if;
    -- Reparto del resto: cada parte debe valer al menos 1 céntimo para que
    -- la suma de partes a céntimos cubra exactamente el total.
    if trunc(v_total * 100) / v_count < 1 then
      raise exception 'El total no admite % partes de al menos 1 céntimo', v_count;
    end if;
  end if;

  if tg_op = 'DELETE' then
    return old;
  end if;
  return new;
end;
$$;
