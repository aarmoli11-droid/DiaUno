-- DíaUno: esquema inicial.
-- Diseñado para Supabase Postgres 17. Todas las tablas de datos de usuario usan RLS.
-- El proyecto Supabase es nuevo y exclusivo de esta aplicación.

create extension if not exists pgcrypto;

-- ---------------------------------------------------------------------------
-- Catálogos y perfiles.
-- ---------------------------------------------------------------------------
create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  display_name text not null check (char_length(display_name) between 1 and 80),
  email text not null,
  avatar_url text,
  locale text not null default 'es',
  timezone text not null default 'America/Costa_Rica',
  theme_mode text not null default 'system' check (theme_mode in ('light','dark','system')),
  onboarding_completed boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.profiles (id, display_name, email)
  values (
    new.id,
    coalesce(nullif(new.raw_user_meta_data ->> 'display_name', ''), split_part(new.email, '@', 1)),
    coalesce(new.email, '')
  )
  on conflict (id) do nothing;
  return new;
end;
$$;

create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

-- ---------------------------------------------------------------------------
-- Proyectos y membresías.
-- ---------------------------------------------------------------------------
create table if not exists public.projects (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references auth.users(id) on delete cascade,
  name text not null check (char_length(trim(name)) between 1 and 100),
  description text not null default '',
  color_hex text not null default '#3D7A5B',
  icon_name text not null default 'folder',
  status text not null default 'active' check (status in ('active','paused','completed','archived')),
  start_date date,
  end_date date,
  created_by uuid not null references auth.users(id),
  updated_by uuid not null references auth.users(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint projects_date_order check (end_date is null or start_date is null or end_date >= start_date)
);

create table if not exists public.project_members (
  project_id uuid not null references public.projects(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  role text not null check (role in ('owner','admin','collaborator','viewer')),
  invited_by uuid references auth.users(id),
  created_at timestamptz not null default now(),
  primary key (project_id, user_id)
);

create or replace function public.sync_project_owner_membership()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.project_members (project_id, user_id, role, invited_by)
  values (new.id, new.owner_id, 'owner', new.created_by)
  on conflict (project_id, user_id) do update set role = 'owner';
  return new;
end;
$$;

create trigger projects_owner_membership
  after insert on public.projects
  for each row execute function public.sync_project_owner_membership();

-- ---------------------------------------------------------------------------
-- Helpers de seguridad (SECURITY DEFINER para evitar recursión en RLS).
-- Se crean después de projects/project_members para que Postgres pueda validarlos.
-- ---------------------------------------------------------------------------
create or replace function public.has_project_role(p_project uuid, p_roles text[])
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1 from public.project_members m
    where m.project_id = p_project
      and m.user_id = auth.uid()
      and m.role = any(p_roles)
  ) or exists (
    select 1 from public.projects p
    where p.id = p_project
      and p.owner_id = auth.uid()
      and 'owner' = any(p_roles)
  );
$$;

create or replace function public.can_read_project(p_project uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select public.has_project_role(
    p_project,
    array['owner','admin','collaborator','viewer']
  );
$$;

create or replace function public.shares_project_with(p_user uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1 from public.project_members mine
    join public.project_members theirs on theirs.project_id = mine.project_id
    where mine.user_id = auth.uid() and theirs.user_id = p_user
  ) or exists (
    select 1 from public.projects p
    join public.project_members m on m.project_id = p.id
    where p.owner_id = auth.uid() and m.user_id = p_user
  ) or exists (
    select 1 from public.projects p
    join public.project_members m on m.project_id = p.id
    where p.owner_id = p_user and m.user_id = auth.uid()
  );
$$;

grant execute on function public.has_project_role(uuid, text[]) to authenticated;
grant execute on function public.can_read_project(uuid) to authenticated;
grant execute on function public.shares_project_with(uuid) to authenticated;

-- ---------------------------------------------------------------------------
-- Tareas, ocurrencias y comentarios.
-- Las tareas definen la serie; cada ocurrencia conserva su propio estado e historial.
-- ---------------------------------------------------------------------------
create table if not exists public.tasks (
  id uuid primary key default gen_random_uuid(),
  project_id uuid references public.projects(id) on delete cascade,
  created_by uuid not null references auth.users(id),
  updated_by uuid references auth.users(id),
  assigned_to uuid references auth.users(id),
  title text not null check (char_length(trim(title)) between 1 and 160),
  description text not null default '',
  priority text not null default 'medium' check (priority in ('low','medium','high','urgent')),
  recurrence text not null default 'none' check (recurrence in ('none','daily','weekly','monthly')),
  recurrence_interval integer not null default 1 check (recurrence_interval >= 1),
  recurrence_end_date date,
  start_date date not null default current_date,
  due_time time,
  estimated_minutes integer not null default 0 check (estimated_minutes >= 0),
  series_group_id uuid,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint tasks_recurrence_end check (
    recurrence_end_date is null or recurrence_end_date >= start_date
  )
);

create table if not exists public.task_occurrences (
  id uuid primary key default gen_random_uuid(),
  task_id uuid not null references public.tasks(id) on delete cascade,
  due_date date not null,
  status text not null default 'pending' check (status in ('pending','in_progress','completed','cancelled')),
  completed_at timestamptz,
  completed_by uuid references auth.users(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (task_id, due_date)
);

create or replace function public.create_first_occurrence()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.task_occurrences (task_id, due_date)
  values (new.id, new.start_date)
  on conflict (task_id, due_date) do nothing;
  return new;
end;
$$;

create trigger tasks_first_occurrence
  after insert on public.tasks
  for each row execute function public.create_first_occurrence();

create table if not exists public.task_comments (
  id uuid primary key default gen_random_uuid(),
  occurrence_id uuid not null references public.task_occurrences(id) on delete cascade,
  author_id uuid not null references auth.users(id),
  body text not null check (char_length(trim(body)) between 1 and 2000),
  created_at timestamptz not null default now()
);

-- ---------------------------------------------------------------------------
-- Agenda: eventos (compromisos), distintos de tareas.
-- ---------------------------------------------------------------------------
create table if not exists public.events (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references auth.users(id) on delete cascade,
  project_id uuid references public.projects(id) on delete set null,
  created_by uuid not null references auth.users(id),
  title text not null check (char_length(trim(title)) between 1 and 160),
  description text not null default '',
  location text,
  starts_at timestamptz not null,
  ends_at timestamptz not null,
  all_day boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint events_time_order check (ends_at >= starts_at)
);

-- ---------------------------------------------------------------------------
-- Finanzas compartidas.
-- Un gasto/suscripción se registra una sola vez; las distribuciones son vistas lógicas.
-- ---------------------------------------------------------------------------
create table if not exists public.subscriptions (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references auth.users(id) on delete cascade,
  project_id uuid references public.projects(id) on delete set null,
  name text not null check (char_length(trim(name)) between 1 and 120),
  provider text not null default '',
  amount numeric(14,2) not null check (amount > 0),
  currency text not null default 'USD' check (char_length(currency) = 3),
  billing_cycle text not null default 'monthly' check (billing_cycle in ('weekly','monthly','quarterly','yearly')),
  next_payment_date date,
  status text not null default 'active' check (status in ('active','paused','cancelled')),
  is_shared boolean not null default false,
  created_by uuid not null references auth.users(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.transactions (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references auth.users(id) on delete cascade,
  project_id uuid references public.projects(id) on delete set null,
  subscription_id uuid references public.subscriptions(id) on delete set null,
  type text not null check (type in ('income','expense')),
  category text not null default 'general',
  amount numeric(14,2) not null check (amount > 0),
  currency text not null default 'USD' check (char_length(currency) = 3),
  description text not null default '',
  occurred_on date not null default current_date,
  due_date date,
  payment_status text not null default 'paid' check (payment_status in ('pending','paid','overdue','cancelled')),
  reference text,
  created_by uuid not null references auth.users(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- El importe histórico es inmutable: los cambios de precio crean nuevos movimientos.
create or replace function public.prevent_transaction_amount_change()
returns trigger
language plpgsql
as $$
begin
  if new.amount is distinct from old.amount then
    raise exception 'El importe de un movimiento histórico no puede modificarse';
  end if;
  return new;
end;
$$;

create trigger transactions_immutable_amount
  before update on public.transactions
  for each row execute function public.prevent_transaction_amount_change();

create table if not exists public.cost_distributions (
  id uuid primary key default gen_random_uuid(),
  source_type text not null check (source_type in ('subscription','expense')),
  source_id uuid not null,
  project_id uuid references public.projects(id) on delete cascade,
  user_id uuid references auth.users(id) on delete cascade,
  mode text not null check (mode in ('amount','percent','equal')),
  share_value numeric(14,4) not null check (share_value > 0),
  created_at timestamptz not null default now(),
  constraint distribution_target check (
    (project_id is not null and user_id is null) or
    (project_id is null and user_id is not null)
  ),
  constraint distribution_percent_range check (
    mode <> 'percent' or share_value <= 100
  )
);

create or replace function public.validate_distribution_sum()
returns trigger
language plpgsql
as $$
declare
  v_source_type text;
  v_source_id uuid;
  v_mode text;
  v_total numeric(14,2);
  v_sum numeric(14,4);
begin
  if tg_op = 'DELETE' then
    v_source_type := old.source_type;
    v_source_id := old.source_id;
    v_mode := old.mode;
  else
    v_source_type := new.source_type;
    v_source_id := new.source_id;
    v_mode := new.mode;
  end if;

  if v_mode = 'equal' then
    if tg_op = 'DELETE' then return old; end if;
    return new;
  end if;

  if v_source_type = 'subscription' then
    select amount into v_total from public.subscriptions where id = v_source_id;
  else
    select amount into v_total from public.transactions where id = v_source_id;
  end if;

  select coalesce(sum(share_value), 0) into v_sum
  from public.cost_distributions
  where source_type = v_source_type and source_id = v_source_id and mode = v_mode;

  if v_sum > v_total + 0.01 then
    raise exception 'La suma de la distribución (%) supera el total (%)', v_sum, v_total;
  end if;
  if tg_op = 'DELETE' then return old; end if;
  return new;
end;
$$;

create trigger distributions_validate_sum
  before insert or update or delete on public.cost_distributions
  for each row execute function public.validate_distribution_sum();

create table if not exists public.invoices (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references auth.users(id) on delete cascade,
  project_id uuid references public.projects(id) on delete set null,
  transaction_id uuid references public.transactions(id) on delete set null,
  number text not null,
  amount numeric(14,2) not null check (amount > 0),
  currency text not null default 'USD',
  issued_on date not null default current_date,
  due_on date,
  status text not null default 'draft' check (status in ('draft','issued','paid','void')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (owner_id, number)
);

create table if not exists public.files (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references auth.users(id) on delete cascade,
  project_id uuid references public.projects(id) on delete cascade,
  occurrence_id uuid references public.task_occurrences(id) on delete cascade,
  transaction_id uuid references public.transactions(id) on delete cascade,
  bucket text not null check (bucket in ('task-evidence','finance-receipts','avatars')),
  storage_path text not null,
  file_name text not null,
  mime_type text,
  size_bytes bigint not null default 0 check (size_bytes >= 0),
  uploaded_by uuid not null references auth.users(id),
  created_at timestamptz not null default now()
);

-- ---------------------------------------------------------------------------
-- Herramientas externas, tiempo, notificaciones, jardín y actividad.
-- ---------------------------------------------------------------------------
create table if not exists public.external_tools (
  id uuid primary key default gen_random_uuid(),
  project_id uuid not null references public.projects(id) on delete cascade,
  name text not null check (char_length(trim(name)) between 1 and 100),
  description text not null default '',
  url text not null check (url ~ '^https?://'),
  category text not null default 'other',
  icon_name text not null default 'link',
  status text not null default 'active' check (status in ('active','inactive')),
  created_by uuid not null references auth.users(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.time_entries (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references auth.users(id) on delete cascade,
  project_id uuid references public.projects(id) on delete cascade,
  occurrence_id uuid references public.task_occurrences(id) on delete cascade,
  description text not null default '',
  started_at timestamptz not null,
  ended_at timestamptz,
  duration_seconds integer not null default 0 check (duration_seconds >= 0),
  is_manual boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint time_entry_target check (
    project_id is not null or occurrence_id is not null
  ),
  constraint time_entry_order check (ended_at is null or ended_at >= started_at)
);

create unique index time_entries_single_active_timer
  on public.time_entries (owner_id)
  where ended_at is null;

create table if not exists public.notifications (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  category text not null check (category in ('task','agenda','finance','project','system')),
  title text not null,
  body text not null default '',
  target_type text,
  target_id uuid,
  is_read boolean not null default false,
  created_at timestamptz not null default now(),
  read_at timestamptz
);

create table if not exists public.garden_progress_events (
  id uuid primary key default gen_random_uuid(),
  project_id uuid not null references public.projects(id) on delete cascade,
  user_id uuid not null references auth.users(id),
  occurrence_id uuid references public.task_occurrences(id) on delete set null,
  event_type text not null check (event_type in ('task_completed','milestone')),
  points integer not null check (points > 0),
  flower_type text,
  created_at timestamptz not null default now()
);

-- Progreso determinista: sin recompensas aleatorias y sin pérdida por inactividad.
create or replace function public.record_garden_progress()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_task public.tasks%rowtype;
  v_points integer;
  v_total integer;
  v_flower text;
begin
  if new.status <> 'completed' or old.status = 'completed' then
    return new;
  end if;

  select * into v_task from public.tasks where id = new.task_id;
  v_points := case v_task.priority
    when 'urgent' then 40
    when 'high' then 30
    when 'medium' then 20
    else 10
  end;

  insert into public.garden_progress_events (project_id, user_id, occurrence_id, event_type, points)
  values (v_task.project_id, coalesce(new.completed_by, v_task.created_by), new.id, 'task_completed', v_points);

  if v_task.project_id is not null then
    select coalesce(sum(points), 0) into v_total
    from public.garden_progress_events where project_id = v_task.project_id;
    v_flower := case
      when v_total >= 400 then 'orchid'
      when v_total >= 250 then 'sunflower'
      when v_total >= 120 then 'tulip'
      when v_total >= 40 then 'daisy'
      else 'sprout'
    end;
    update public.garden_progress_events
       set flower_type = v_flower, event_type = 'milestone'
     where id = (select id from public.garden_progress_events
                 where project_id = v_task.project_id
                 order by created_at desc, id desc limit 1);
  end if;
  return new;
end;
$$;

create trigger task_completion_garden_progress
  after update of status on public.task_occurrences
  for each row execute function public.record_garden_progress();

create table if not exists public.activity_log (
  id uuid primary key default gen_random_uuid(),
  project_id uuid not null references public.projects(id) on delete cascade,
  actor_id uuid not null references auth.users(id),
  action text not null,
  entity_type text not null,
  entity_id uuid,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

create or replace function public.log_project_activity()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_project uuid;
  v_actor uuid;
  v_entity text;
  v_action text;
begin
  v_entity := tg_table_name;
  v_action := lower(tg_op);

  if tg_table_name = 'tasks' then
    v_project := new.project_id;
    v_actor := coalesce(new.updated_by, new.created_by);
  elsif tg_table_name = 'task_occurrences' then
    select project_id, created_by into v_project, v_actor
      from public.tasks where id = new.task_id;
  elsif tg_table_name = 'external_tools' then
    v_project := new.project_id;
    v_actor := coalesce(new.created_by, new.updated_by);
  else
    v_project := new.id;
    v_actor := coalesce(new.updated_by, new.created_by);
  end if;

  if v_project is not null then
    insert into public.activity_log (project_id, actor_id, action, entity_type, entity_id)
    values (v_project, coalesce(v_actor, auth.uid()), v_action, v_entity, new.id);
  end if;

  if tg_op = 'DELETE' then return old; end if;
  return new;
end;
$$;

create trigger projects_activity after insert or update on public.projects
  for each row execute function public.log_project_activity();
create trigger tasks_activity after insert or update on public.tasks
  for each row execute function public.log_project_activity();
create trigger occurrences_activity after update on public.task_occurrences
  for each row execute function public.log_project_activity();
create trigger tools_activity after insert or update on public.external_tools
  for each row execute function public.log_project_activity();

-- ---------------------------------------------------------------------------
-- updated_at genérico.
-- ---------------------------------------------------------------------------
create or replace function public.touch_updated_at()
returns trigger language plpgsql as $$
begin
  new.updated_at := now();
  return new;
end;
$$;

create or replace function public.set_tasks_updated_by()
returns trigger language plpgsql as $$
begin
  if tg_op = 'INSERT' then
    new.updated_by := coalesce(new.updated_by, new.created_by);
  else
    new.updated_by := coalesce(auth.uid(), new.created_by);
  end if;
  return new;
end;
$$;

drop trigger if exists tasks_updated_by on public.tasks;
create trigger tasks_updated_by before insert or update on public.tasks
  for each row execute function public.set_tasks_updated_by();

drop trigger if exists touch_profiles on public.profiles;
create trigger touch_profiles before update on public.profiles for each row execute function public.touch_updated_at();
drop trigger if exists touch_projects on public.projects;
create trigger touch_projects before update on public.projects for each row execute function public.touch_updated_at();
drop trigger if exists touch_tasks on public.tasks;
create trigger touch_tasks before update on public.tasks for each row execute function public.touch_updated_at();
drop trigger if exists touch_occurrences on public.task_occurrences;
create trigger touch_occurrences before update on public.task_occurrences for each row execute function public.touch_updated_at();
drop trigger if exists touch_events on public.events;
create trigger touch_events before update on public.events for each row execute function public.touch_updated_at();
drop trigger if exists touch_subscriptions on public.subscriptions;
create trigger touch_subscriptions before update on public.subscriptions for each row execute function public.touch_updated_at();
drop trigger if exists touch_transactions on public.transactions;
create trigger touch_transactions before update on public.transactions for each row execute function public.touch_updated_at();
drop trigger if exists touch_invoices on public.invoices;
create trigger touch_invoices before update on public.invoices for each row execute function public.touch_updated_at();
drop trigger if exists touch_tools on public.external_tools;
create trigger touch_tools before update on public.external_tools for each row execute function public.touch_updated_at();
drop trigger if exists touch_time_entries on public.time_entries;
create trigger touch_time_entries before update on public.time_entries for each row execute function public.touch_updated_at();
-- ---------------------------------------------------------------------------
-- Índices de consulta.
-- ---------------------------------------------------------------------------
create index if not exists idx_projects_owner on public.projects(owner_id, created_at desc);
create index if not exists idx_members_user on public.project_members(user_id);
create index if not exists idx_tasks_project on public.tasks(project_id);
create index if not exists idx_tasks_assignee on public.tasks(assigned_to);
create index if not exists idx_occurrences_due on public.task_occurrences(due_date, status);
create index if not exists idx_events_owner_start on public.events(owner_id, starts_at);
create index if not exists idx_events_project on public.events(project_id);
create index if not exists idx_transactions_owner_date on public.transactions(owner_id, occurred_on desc);
create index if not exists idx_transactions_project on public.transactions(project_id);
create index if not exists idx_subscriptions_owner on public.subscriptions(owner_id);
create index if not exists idx_distributions_source on public.cost_distributions(source_type, source_id);
create index if not exists idx_files_owner on public.files(owner_id);
create index if not exists idx_time_owner_started on public.time_entries(owner_id, started_at desc);
create index if not exists idx_notifications_user on public.notifications(user_id, is_read, created_at desc);
create index if not exists idx_garden_project on public.garden_progress_events(project_id, created_at);
create index if not exists idx_activity_project on public.activity_log(project_id, created_at desc);

-- ---------------------------------------------------------------------------
-- Vistas de apoyo. 20261118000100 la convierte en tabla materializada.
-- ---------------------------------------------------------------------------
create or replace view public.project_progress as
select
  p.id as project_id,
  count(o.id) as total_occurrences,
  count(o.id) filter (where o.status = 'completed') as completed_occurrences,
  case when count(o.id) = 0 then 0
       else round(100.0 * count(o.id) filter (where o.status = 'completed') / count(o.id))::integer
  end as progress_percent,
  coalesce((select sum(g.points) from public.garden_progress_events g where g.project_id = p.id), 0) as garden_points
from public.projects p
left join public.tasks t on t.project_id = p.id
left join public.task_occurrences o on o.task_id = t.id
group by p.id;

-- ---------------------------------------------------------------------------
-- RLS.
-- ---------------------------------------------------------------------------
alter table public.profiles enable row level security;
alter table public.projects enable row level security;
alter table public.project_members enable row level security;
alter table public.tasks enable row level security;
alter table public.task_occurrences enable row level security;
alter table public.task_comments enable row level security;
alter table public.events enable row level security;
alter table public.subscriptions enable row level security;
alter table public.transactions enable row level security;
alter table public.cost_distributions enable row level security;
alter table public.invoices enable row level security;
alter table public.files enable row level security;
alter table public.external_tools enable row level security;
alter table public.time_entries enable row level security;
alter table public.notifications enable row level security;
alter table public.garden_progress_events enable row level security;
alter table public.activity_log enable row level security;

-- profiles
create policy profiles_select on public.profiles for select to authenticated
using (id = auth.uid() or public.shares_project_with(id));
create policy profiles_update on public.profiles for update to authenticated
using (id = auth.uid()) with check (id = auth.uid());

-- projects
create policy projects_select on public.projects for select to authenticated
using (owner_id = auth.uid() or public.can_read_project(id));
create policy projects_insert on public.projects for insert to authenticated
with check (owner_id = auth.uid());
create policy projects_update on public.projects for update to authenticated
using (public.has_project_role(id, array['owner','admin']))
with check (public.has_project_role(id, array['owner','admin']));
create policy projects_delete on public.projects for delete to authenticated
using (owner_id = auth.uid());

-- project_members
create policy members_select on public.project_members for select to authenticated
using (
  user_id = auth.uid()
  or exists (select 1 from public.projects p where p.id = project_id and p.owner_id = auth.uid())
  or public.can_read_project(project_id)
);
create policy members_insert on public.project_members for insert to authenticated
with check (public.has_project_role(project_id, array['owner','admin']));
create policy members_update on public.project_members for update to authenticated
using (public.has_project_role(project_id, array['owner','admin']))
with check (public.has_project_role(project_id, array['owner','admin']));
create policy members_delete on public.project_members for delete to authenticated
using (public.has_project_role(project_id, array['owner','admin']));

-- tasks (lectura: cualquier rol; escritura: owner/admin/collaborator)
create policy tasks_select on public.tasks for select to authenticated
using (
  (project_id is null and (created_by = auth.uid() or assigned_to = auth.uid()))
  or (project_id is not null and public.can_read_project(project_id))
);
create policy tasks_insert on public.tasks for insert to authenticated
with check (
  (project_id is null and created_by = auth.uid())
  or (project_id is not null and public.has_project_role(project_id, array['owner','admin','collaborator']))
);
create policy tasks_update on public.tasks for update to authenticated
using (
  (project_id is null and created_by = auth.uid())
  or (project_id is not null and public.has_project_role(project_id, array['owner','admin','collaborator']))
)
with check (
  (project_id is null and created_by = auth.uid())
  or (project_id is not null and public.has_project_role(project_id, array['owner','admin','collaborator']))
);
create policy tasks_delete on public.tasks for delete to authenticated
using (
  (project_id is null and created_by = auth.uid())
  or (project_id is not null and public.has_project_role(project_id, array['owner','admin']))
);

-- task_occurrences
create policy occurrences_select on public.task_occurrences for select to authenticated
using (exists (
  select 1 from public.tasks t where t.id = task_id
    and ((t.project_id is null and (t.created_by = auth.uid() or t.assigned_to = auth.uid()))
         or (t.project_id is not null and public.can_read_project(t.project_id)))
));
create policy occurrences_insert on public.task_occurrences for insert to authenticated
with check (exists (
  select 1 from public.tasks t where t.id = task_id
    and ((t.project_id is null and t.created_by = auth.uid())
         or (t.project_id is not null and public.has_project_role(t.project_id, array['owner','admin','collaborator'])))
));
create policy occurrences_update on public.task_occurrences for update to authenticated
using (exists (
  select 1 from public.tasks t where t.id = task_id
    and ((t.project_id is null and (t.created_by = auth.uid() or t.assigned_to = auth.uid()))
         or (t.project_id is not null and public.has_project_role(t.project_id, array['owner','admin','collaborator'])))
))
with check (exists (
  select 1 from public.tasks t where t.id = task_id
    and ((t.project_id is null and (t.created_by = auth.uid() or t.assigned_to = auth.uid()))
         or (t.project_id is not null and public.has_project_role(t.project_id, array['owner','admin','collaborator'])))
));
create policy occurrences_delete on public.task_occurrences for delete to authenticated
using (exists (
  select 1 from public.tasks t where t.id = task_id
    and public.has_project_role(t.project_id, array['owner','admin'])
));

-- task_comments
create policy comments_select on public.task_comments for select to authenticated
using (exists (select 1 from public.task_occurrences o where o.id = occurrence_id));
create policy comments_insert on public.task_comments for insert to authenticated
with check (author_id = auth.uid() and exists (select 1 from public.task_occurrences o where o.id = occurrence_id));
create policy comments_delete on public.task_comments for delete to authenticated
using (author_id = auth.uid());

-- events
create policy events_select on public.events for select to authenticated
using (owner_id = auth.uid() or (project_id is not null and public.can_read_project(project_id)));
create policy events_insert on public.events for insert to authenticated
with check (
  owner_id = auth.uid() and created_by = auth.uid()
  and (project_id is null or public.has_project_role(project_id, array['owner','admin','collaborator']))
);
create policy events_update on public.events for update to authenticated
using (owner_id = auth.uid())
with check (owner_id = auth.uid());
create policy events_delete on public.events for delete to authenticated
using (owner_id = auth.uid());

-- subscriptions / transactions / invoices / distributions
create policy subscriptions_select on public.subscriptions for select to authenticated
using (owner_id = auth.uid() or (project_id is not null and public.can_read_project(project_id)));
create policy subscriptions_insert on public.subscriptions for insert to authenticated
with check (owner_id = auth.uid() and created_by = auth.uid());
create policy subscriptions_update on public.subscriptions for update to authenticated
using (owner_id = auth.uid()) with check (owner_id = auth.uid());
create policy subscriptions_delete on public.subscriptions for delete to authenticated
using (owner_id = auth.uid());

create policy transactions_select on public.transactions for select to authenticated
using (owner_id = auth.uid() or (project_id is not null and public.can_read_project(project_id)));
create policy transactions_insert on public.transactions for insert to authenticated
with check (owner_id = auth.uid() and created_by = auth.uid());
create policy transactions_update on public.transactions for update to authenticated
using (owner_id = auth.uid()) with check (owner_id = auth.uid());
create policy transactions_delete on public.transactions for delete to authenticated
using (owner_id = auth.uid());

create policy distributions_select on public.cost_distributions for select to authenticated
using (
  (source_type = 'subscription' and exists (
    select 1 from public.subscriptions s where s.id = source_id and s.owner_id = auth.uid()))
  or (source_type = 'expense' and exists (
    select 1 from public.transactions t where t.id = source_id and t.owner_id = auth.uid()))
  or (project_id is not null and public.can_read_project(project_id))
);
create policy distributions_insert on public.cost_distributions for insert to authenticated
with check (
  (source_type = 'subscription' and exists (
    select 1 from public.subscriptions s where s.id = source_id and s.owner_id = auth.uid()))
  or (source_type = 'expense' and exists (
    select 1 from public.transactions t where t.id = source_id and t.owner_id = auth.uid()))
);
create policy distributions_delete on public.cost_distributions for delete to authenticated
using (
  (source_type = 'subscription' and exists (
    select 1 from public.subscriptions s where s.id = source_id and s.owner_id = auth.uid()))
  or (source_type = 'expense' and exists (
    select 1 from public.transactions t where t.id = source_id and t.owner_id = auth.uid()))
);

create policy invoices_select on public.invoices for select to authenticated
using (owner_id = auth.uid() or (project_id is not null and public.can_read_project(project_id)));
create policy invoices_insert on public.invoices for insert to authenticated
with check (owner_id = auth.uid());
create policy invoices_update on public.invoices for update to authenticated
using (owner_id = auth.uid()) with check (owner_id = auth.uid());
create policy invoices_delete on public.invoices for delete to authenticated
using (owner_id = auth.uid());

-- files
create policy files_select on public.files for select to authenticated
using (owner_id = auth.uid() or (project_id is not null and public.can_read_project(project_id)));
create policy files_insert on public.files for insert to authenticated
with check (owner_id = auth.uid() and uploaded_by = auth.uid());
create policy files_delete on public.files for delete to authenticated
using (owner_id = auth.uid() or (project_id is not null and public.has_project_role(project_id, array['owner','admin'])));

-- external_tools
create policy tools_select on public.external_tools for select to authenticated
using (public.can_read_project(project_id));
create policy tools_insert on public.external_tools for insert to authenticated
with check (public.has_project_role(project_id, array['owner','admin','collaborator']));
create policy tools_update on public.external_tools for update to authenticated
using (public.has_project_role(project_id, array['owner','admin','collaborator']))
with check (public.has_project_role(project_id, array['owner','admin','collaborator']));
create policy tools_delete on public.external_tools for delete to authenticated
using (public.has_project_role(project_id, array['owner','admin']));

-- time_entries
create policy time_select on public.time_entries for select to authenticated
using (owner_id = auth.uid() or (project_id is not null and public.can_read_project(project_id)));
create policy time_insert on public.time_entries for insert to authenticated
with check (owner_id = auth.uid());
create policy time_update on public.time_entries for update to authenticated
using (owner_id = auth.uid()) with check (owner_id = auth.uid());
create policy time_delete on public.time_entries for delete to authenticated
using (owner_id = auth.uid());

-- notificaciones, jardín y actividad
create policy notifications_select on public.notifications for select to authenticated
using (user_id = auth.uid());
create policy notifications_update on public.notifications for update to authenticated
using (user_id = auth.uid()) with check (user_id = auth.uid());
create policy notifications_delete on public.notifications for delete to authenticated
using (user_id = auth.uid());

create policy garden_select on public.garden_progress_events for select to authenticated
using (public.can_read_project(project_id));
create policy garden_insert on public.garden_progress_events for insert to authenticated
with check (user_id = auth.uid() and public.can_read_project(project_id));

create policy activity_select on public.activity_log for select to authenticated
using (public.can_read_project(project_id));

-- ---------------------------------------------------------------------------
-- Storage: rutas {user_id}/{nombre}. Políticas por carpeta raíz.
-- ---------------------------------------------------------------------------
insert into storage.buckets (id, name, public, file_size_limit)
values
  ('task-evidence', 'task-evidence', false, 10485760),
  ('finance-receipts', 'finance-receipts', false, 10485760),
  ('avatars', 'avatars', true, 2097152)
on conflict (id) do nothing;

create policy storage_owner_read on storage.objects for select to authenticated
using (
  bucket_id in ('task-evidence','finance-receipts','avatars')
  and (storage.foldername(name))[1] = auth.uid()::text
);
create policy storage_owner_insert on storage.objects for insert to authenticated
with check (
  bucket_id in ('task-evidence','finance-receipts','avatars')
  and (storage.foldername(name))[1] = auth.uid()::text
);
create policy storage_owner_update on storage.objects for update to authenticated
using (
  bucket_id in ('task-evidence','finance-receipts','avatars')
  and (storage.foldername(name))[1] = auth.uid()::text
)
with check (
  bucket_id in ('task-evidence','finance-receipts','avatars')
  and (storage.foldername(name))[1] = auth.uid()::text
);
create policy storage_owner_delete on storage.objects for delete to authenticated
using (
  bucket_id in ('task-evidence','finance-receipts','avatars')
  and (storage.foldername(name))[1] = auth.uid()::text
);
