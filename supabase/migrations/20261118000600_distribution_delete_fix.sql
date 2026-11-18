-- Corrección incremental sobre 20261118000300:
-- borrar todas las filas de una distribución equal debe ser válido (la app
-- reemplaza la distribución completa con DELETE + INSERT). Sólo se exige al
-- menos un participante en INSERT/UPDATE, y se evita dividir entre cero.

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
    if tg_op <> 'DELETE' and v_count < 1 then
      raise exception 'La distribución equal necesita al menos un participante';
    end if;
    if v_count > 0 and (v_min <> 1 or v_max <> 1) then
      raise exception 'Todas las partes de una distribución equal deben ser iguales';
    end if;
    if v_count > 0 and trunc(v_total * 100) / v_count < 1 then
      raise exception 'El total no admite % partes de al menos 1 céntimo', v_count;
    end if;
  end if;

  if tg_op = 'DELETE' then
    return old;
  end if;
  return new;
end;
$$;
