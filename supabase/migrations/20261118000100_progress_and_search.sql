-- Ajustes posteriores al esquema inicial:
-- 1) project_progress pasa de vista a tabla para exponer una FK a PostgREST.
-- 2) Búsqueda segura de perfiles para invitar colaboradores por nombre.

drop view if exists public.project_progress;

create table if not exists public.project_progress (
  project_id uuid primary key references public.projects(id) on delete cascade,
  total_occurrences integer not null default 0,
  completed_occurrences integer not null default 0,
  progress_percent integer not null default 0 check (progress_percent between 0 and 100),
  garden_points bigint not null default 0
);

create or replace function public.refresh_project_progress(p_project uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if p_project is null then return; end if;

  insert into public.project_progress (
    project_id, total_occurrences, completed_occurrences, progress_percent
  )
  select
    p.id,
    count(o.id)::integer,
    count(o.id) filter (where o.status = 'completed')::integer,
    case when count(o.id) = 0 then 0
         else (100 * count(o.id) filter (where o.status = 'completed') / count(o.id))::integer
    end
  from public.projects p
  left join public.tasks t on t.project_id = p.id
  left join public.task_occurrences o on o.task_id = t.id
  where p.id = p_project
  group by p.id
  on conflict (project_id) do update set
    total_occurrences = excluded.total_occurrences,
    completed_occurrences = excluded.completed_occurrences,
    progress_percent = excluded.progress_percent;

  update public.project_progress pp
     set garden_points = coalesce((
       select sum(g.points) from public.garden_progress_events g
       where g.project_id = p_project
     ), 0)
   where pp.project_id = p_project;
end;
$$;

create or replace function public.touch_project_progress()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_project uuid;
begin
  if tg_table_name = 'task_occurrences' then
    select project_id into v_project
      from public.tasks where id = coalesce(new.task_id, old.task_id);
  else
    v_project := coalesce(new.project_id, old.project_id);
  end if;
  perform public.refresh_project_progress(v_project);
  if tg_op = 'DELETE' then return old; end if;
  return new;
end;
$$;

drop trigger if exists tasks_progress on public.tasks;
create trigger tasks_progress after insert or update or delete on public.tasks
  for each row execute function public.touch_project_progress();
drop trigger if exists occurrences_progress on public.task_occurrences;
create trigger occurrences_progress after insert or update or delete on public.task_occurrences
  for each row execute function public.touch_project_progress();
drop trigger if exists garden_progress on public.garden_progress_events;
create trigger garden_progress after insert or delete on public.garden_progress_events
  for each row execute function public.touch_project_progress();

select public.refresh_project_progress(id) from public.projects;

alter table public.project_progress enable row level security;
drop policy if exists progress_select on public.project_progress;
create policy progress_select on public.project_progress for select to authenticated
using (public.can_read_project(project_id));

-- Devuelve sólo id y nombre visible: nunca expone correos de otros usuarios.
create or replace function public.search_profiles(p_query text)
returns table (id uuid, display_name text)
language sql
stable
security definer
set search_path = public
as $$
  select p.id, p.display_name
  from public.profiles p
  where p.id <> auth.uid()
    and p.display_name ilike '%' || p_query || '%'
  order by p.display_name
  limit 20;
$$;

revoke all on function public.search_profiles(text) from public;
grant execute on function public.search_profiles(text) to authenticated;
