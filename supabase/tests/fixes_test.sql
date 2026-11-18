-- Pruebas SQL reales contra el backend (transacción con ROLLBACK: no deja datos).
-- Ejecutar: supabase db query --linked -f supabase/tests/fixes_test.sql

begin;

insert into auth.users (id, email, encrypted_password, created_at, updated_at)
values
  ('11111111-1111-4111-8111-111111111111', 'owner_test@example.invalid', '', now(), now()),
  ('22222222-2222-4222-8222-222222222222', 'other_test@example.invalid', '', now(), now());

insert into public.projects (id, owner_id, name, created_by, updated_by)
values ('33333333-3333-4333-8333-333333333333',
        '11111111-1111-4111-8111-111111111111', 'Proyecto prueba',
        '11111111-1111-4111-8111-111111111111',
        '11111111-1111-4111-8111-111111111111');

insert into public.tasks (id, project_id, created_by, title)
values
  ('44444444-4444-4444-8444-444444444444', '33333333-3333-4333-8333-333333333333',
   '11111111-1111-4111-8111-111111111111', 'Tarea de proyecto'),
  ('55555555-5555-4555-8555-555555555555', null,
   '11111111-1111-4111-8111-111111111111', 'Tarea personal');

-- ---------------------------------------------------------------------------
-- Jardín: tarea personal con project_id NULL y sin duplicados.
-- ---------------------------------------------------------------------------
update public.task_occurrences
   set status = 'completed', completed_by = '11111111-1111-4111-8111-111111111111'
 where task_id in ('44444444-4444-4444-8444-444444444444',
                   '55555555-5555-4555-8555-555555555555');

-- Segunda transición para comprobar que no se crea un segundo evento.
update public.task_occurrences
   set status = 'pending'
 where task_id = '55555555-5555-4555-8555-555555555555';
update public.task_occurrences
   set status = 'completed'
 where task_id = '55555555-5555-4555-8555-555555555555';

do $$
declare
  v_total integer;
  v_personal integer;
  v_tipo text;
  v_duplicados integer;
  v_flower text;
begin
  select count(*) into v_total from public.garden_progress_events
   where user_id = '11111111-1111-4111-8111-111111111111';
  if v_total <> 2 then
    raise exception 'Jardín: esperaba 2 eventos, obtuve %', v_total;
  end if;

  select count(*) into v_personal from public.garden_progress_events
   where project_id is null and occurrence_id in (
     select id from public.task_occurrences
      where task_id = '55555555-5555-4555-8555-555555555555');
  if v_personal <> 1 then
    raise exception 'Jardín: la tarea personal no generó exactamente 1 evento';
  end if;

  select event_type, flower_type into v_tipo, v_flower
    from public.garden_progress_events
   where project_id is null;
  if v_tipo <> 'task_completed' then
    raise exception 'Jardín: el evento personal cambió de tipo (%)', v_tipo;
  end if;
  if v_flower is null then
    raise exception 'Jardín: falta flower_type determinista';
  end if;

  select count(*) into v_duplicados
    from (select occurrence_id from public.garden_progress_events
           where occurrence_id is not null group by occurrence_id having count(*) > 1) d;
  if v_duplicados <> 0 then
    raise exception 'Jardín: hay eventos duplicados por ocurrencia';
  end if;
end $$;

-- ---------------------------------------------------------------------------
-- Distribuciones: INSERT / UPDATE / DELETE en amount, percent y equal.
-- ---------------------------------------------------------------------------
insert into public.transactions (id, owner_id, type, amount, description, created_by)
values ('66666666-6666-4666-8666-666666666666',
        '11111111-1111-4111-8111-111111111111', 'expense', 100,
        'Gasto prueba', '11111111-1111-4111-8111-111111111111');
insert into public.subscriptions (id, owner_id, name, amount, created_by)
values ('77777777-7777-4777-8777-777777777777',
        '11111111-1111-4111-8111-111111111111', 'Suscripción prueba', 50,
        '11111111-1111-4111-8111-111111111111');

-- amount: 60 + 30 cabe; 60 + 50 debe fallar; UPDATE que excede debe fallar; DELETE libera.
do $$
declare v_id1 uuid := gen_random_uuid(); v_id2 uuid := gen_random_uuid(); v_rechazado boolean;
begin
  insert into public.cost_distributions (id, source_type, source_id, project_id, mode, share_value)
  values (v_id1, 'expense', '66666666-6666-4666-8666-666666666666',
          '33333333-3333-4333-8333-333333333333', 'amount', 60);
  insert into public.cost_distributions (id, source_type, source_id, project_id, mode, share_value)
  values (v_id2, 'expense', '66666666-6666-4666-8666-666666666666',
          '33333333-3333-4333-8333-333333333333', 'amount', 30);

  v_rechazado := false;
  begin
    insert into public.cost_distributions (source_type, source_id, project_id, mode, share_value)
    values ('expense', '66666666-6666-4666-8666-666666666666',
            '33333333-3333-4333-8333-333333333333', 'amount', 50);
  exception when others then v_rechazado := true;
  end;
  if not v_rechazado then raise exception 'amount: no rechazó suma superior al total'; end if;

  v_rechazado := false;
  begin
    update public.cost_distributions set share_value = 80 where id = v_id2;
  exception when others then v_rechazado := true;
  end;
  if not v_rechazado then raise exception 'amount: no rechazó UPDATE superior al total'; end if;

  delete from public.cost_distributions where id = v_id2;
  insert into public.cost_distributions (source_type, source_id, project_id, mode, share_value)
  values ('expense', '66666666-6666-4666-8666-666666666666',
          '33333333-3333-4333-8333-333333333333', 'amount', 40);
end $$;

-- amount en suscripción: el total correcto es el de la suscripción (50).
do $$
declare v_rechazado boolean;
begin
  v_rechazado := false;
  begin
    insert into public.cost_distributions (source_type, source_id, project_id, mode, share_value)
    values ('subscription', '77777777-7777-4777-8777-777777777777',
            '33333333-3333-4333-8333-333333333333', 'amount', 60);
  exception when others then v_rechazado := true;
  end;
  if not v_rechazado then raise exception 'amount: no validó contra el total de la suscripción'; end if;
end $$;

-- percent: 60 + 40 cabe; 60 + 50 debe fallar; DELETE permite reemplazar.
do $$
declare v_id uuid := gen_random_uuid(); v_rechazado boolean;
begin
  insert into public.cost_distributions (id, source_type, source_id, project_id, mode, share_value)
  values (v_id, 'expense', '66666666-6666-4666-8666-666666666666',
          '33333333-3333-4333-8333-333333333333', 'percent', 60);
  insert into public.cost_distributions (source_type, source_id, project_id, mode, share_value)
  values ('expense', '66666666-6666-4666-8666-666666666666',
          '33333333-3333-4333-8333-333333333333', 'percent', 40);

  v_rechazado := false;
  begin
    insert into public.cost_distributions (source_type, source_id, project_id, mode, share_value)
    values ('expense', '66666666-6666-4666-8666-666666666666',
            '33333333-3333-4333-8333-333333333333', 'percent', 50);
  exception when others then v_rechazado := true;
  end;
  if not v_rechazado then raise exception 'percent: no rechazó suma superior al 100'; end if;

  v_rechazado := false;
  begin
    update public.cost_distributions set share_value = 101 where id = v_id;
  exception when others then v_rechazado := true;
  end;
  if not v_rechazado then raise exception 'percent: no rechazó un porcentaje individual > 100'; end if;

  delete from public.cost_distributions
   where source_id = '66666666-6666-4666-8666-666666666666' and mode = 'percent';
end $$;

-- equal: exige 1 parte por participante, al menos uno, y reparto posible a céntimos.
do $$
declare
  v_id uuid := gen_random_uuid();
  v_rechazado boolean;
  v_count integer;
begin
  insert into public.cost_distributions (id, source_type, source_id, project_id, mode, share_value)
  values (v_id, 'expense', '66666666-6666-4666-8666-666666666666',
          '33333333-3333-4333-8333-333333333333', 'equal', 1);
  insert into public.cost_distributions (source_type, source_id, project_id, mode, share_value)
  values ('expense', '66666666-6666-4666-8666-666666666666',
          '33333333-3333-4333-8333-333333333333', 'equal', 1);

  v_rechazado := false;
  begin
    insert into public.cost_distributions (source_type, source_id, project_id, mode, share_value)
    values ('expense', '66666666-6666-4666-8666-666666666666',
            '33333333-3333-4333-8333-333333333333', 'equal', 2);
  exception when others then v_rechazado := true;
  end;
  if not v_rechazado then raise exception 'equal: aceptó partes desiguales'; end if;

  -- DELETE deja 1 participante: sigue siendo válido (100 € / 1 = 100 €).
  delete from public.cost_distributions
   where source_id = '66666666-6666-4666-8666-666666666666' and mode = 'equal'
     and id <> v_id;
  select count(*) into v_count from public.cost_distributions
   where source_id = '66666666-6666-4666-8666-666666666666' and mode = 'equal';
  if v_count <> 1 then raise exception 'equal: DELETE no se aplicó correctamente'; end if;

  -- Borrar el último participante también debe funcionar.
  delete from public.cost_distributions where id = v_id;
end $$;

-- ---------------------------------------------------------------------------
-- RLS / privilegios: proyecto ajeno, correos de perfiles, jardín y memberships.
-- ---------------------------------------------------------------------------
set local role authenticated;
set local request.jwt.claims = '{"sub":"22222222-2222-4222-8222-222222222222","role":"authenticated"}';

do $$
declare v_count integer; v_ok boolean;
begin
  select count(*) into v_count from public.projects
   where id = '33333333-3333-4333-8333-333333333333';
  if v_count <> 0 then raise exception 'RLS: usuario ajeno leyó el proyecto'; end if;

  if has_column_privilege('authenticated', 'public.profiles', 'email', 'SELECT') then
    raise exception 'Privacidad: email de perfiles sigue expuesto';
  end if;
  if not has_column_privilege('authenticated', 'public.profiles', 'display_name', 'SELECT') then
    raise exception 'Privacidad: display_name debería ser visible';
  end if;

  v_ok := false;
  begin
    insert into public.garden_progress_events (project_id, user_id, event_type, points)
    values ('33333333-3333-4333-8333-333333333333',
            '22222222-2222-4222-8222-222222222222', 'milestone', 10);
  exception when others then v_ok := true;
  end;
  if not v_ok then raise exception 'Jardín: un usuario insertó eventos arbitrarios'; end if;

  v_ok := false;
  begin
    insert into public.project_members (project_id, user_id, role)
    values ('33333333-3333-4333-8333-333333333333',
            '22222222-2222-4222-8222-222222222222', 'owner');
  exception when others then v_ok := true;
  end;
  if not v_ok then raise exception 'Roles: un usuario ajeno se asignó owner'; end if;
end $$;

reset role;
select 'Todas las pruebas SQL pasaron' as resultado;
rollback;
