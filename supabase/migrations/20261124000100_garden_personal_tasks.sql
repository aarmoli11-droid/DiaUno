-- El jardín también registra tareas personales: esos eventos no tienen
-- proyecto, por lo que project_id es NULL y pertenecen a quien completó la
-- tarea. Estos tres objetos ya están así en el proyecto de desarrollo; la
-- migración los hace reproducibles en un entorno creado desde cero.

alter table public.garden_progress_events
  alter column project_id drop not null;

-- RLS sigue activo: el dueño ve sus eventos personales y, para el resto,
-- se aplica la misma regla de acceso por proyecto que al resto del módulo.
drop policy if exists garden_select on public.garden_progress_events;
create policy garden_select on public.garden_progress_events for select to authenticated
using (
  (project_id is null and user_id = auth.uid())
  or (project_id is not null and public.can_read_project(project_id))
);

-- El trigger evita duplicados por ocurrencia y conserva event_type, que es
-- el origen real del evento; flower_type refleja el hito acumulado.
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
