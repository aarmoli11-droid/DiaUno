-- Roles y privacidad de perfiles:
-- 1) Un admin no puede autoconsignarse owner ni asignar owners.
-- 2) Sólo el owner actual puede transferir la propiedad del proyecto.
-- 3) Los perfiles compartidos exponen nombre visible, no correo ni datos privados.

create or replace function public.is_project_owner(p_project uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1 from public.projects p
     where p.id = p_project and p.owner_id = auth.uid()
  );
$$;

revoke all on function public.is_project_owner(uuid) from public;
grant execute on function public.is_project_owner(uuid) to authenticated;

-- project_members -----------------------------------------------------------
drop policy if exists members_insert on public.project_members;
create policy members_insert on public.project_members for insert to authenticated
with check (
  -- El owner puede invitar a cualquier rol (incluido otro owner).
  public.is_project_owner(project_id)
  -- Un admin puede invitar colaboradores/viewers/admins, pero nunca owners.
  or (
    public.has_project_role(project_id, array['admin'])
    and role <> 'owner'
  )
);

drop policy if exists members_update on public.project_members;
create policy members_update on public.project_members for update to authenticated
using (
  public.is_project_owner(project_id)
  or public.has_project_role(project_id, array['admin'])
)
with check (
  public.is_project_owner(project_id)
  or (
    public.has_project_role(project_id, array['admin'])
    and role <> 'owner'
    and user_id not in (
      select owner_id from public.projects where id = project_id
    )
  )
);

drop policy if exists members_delete on public.project_members;
create policy members_delete on public.project_members for delete to authenticated
using (
  public.is_project_owner(project_id)
  or (
    public.has_project_role(project_id, array['admin'])
    and user_id not in (
      select owner_id from public.projects where id = project_id
    )
  )
);

-- projects ------------------------------------------------------------------
drop policy if exists projects_update on public.projects;
create policy projects_update on public.projects for update to authenticated
using (
  public.is_project_owner(id)
  or public.has_project_role(id, array['admin'])
)
with check (
  public.is_project_owner(id)
  or public.has_project_role(id, array['admin'])
);

-- La transferencia de propiedad requiere autorización del owner actual.
create or replace function public.guard_project_owner_change()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if new.owner_id is distinct from old.owner_id
     and old.owner_id <> auth.uid() then
    raise exception 'Sólo el owner actual puede cambiar el propietario del proyecto';
  end if;
  return new;
end;
$$;

drop trigger if exists projects_guard_owner_change on public.projects;
create trigger projects_guard_owner_change
  before update of owner_id on public.projects
  for each row execute function public.guard_project_owner_change();

-- Mantiene la membresía coherente cuando el owner transfiere el proyecto.
create or replace function public.sync_project_owner_change()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if new.owner_id = old.owner_id then
    return new;
  end if;

  insert into public.project_members (project_id, user_id, role, invited_by)
  values (new.id, new.owner_id, 'owner', old.owner_id)
  on conflict (project_id, user_id) do update set role = 'owner';

  update public.project_members
     set role = 'collaborator'
   where project_id = new.id
     and user_id = old.owner_id
     and role = 'owner';
  return new;
end;
$$;

drop trigger if exists projects_owner_change on public.projects;
create trigger projects_owner_change
  after update of owner_id on public.projects
  for each row execute function public.sync_project_owner_change();

-- profiles ------------------------------------------------------------------
-- El perfil propio se lee con todos sus campos mediante RPC; el resto de
-- usuarios sólo recibe id, display_name y avatar_url (column grants).
create or replace function public.get_my_profile()
returns table (
  id uuid,
  display_name text,
  email text,
  avatar_url text,
  locale text,
  timezone text,
  theme_mode text,
  onboarding_completed boolean
)
language sql
stable
security definer
set search_path = public
as $$
  select p.id, p.display_name, p.email, p.avatar_url, p.locale, p.timezone,
         p.theme_mode, p.onboarding_completed
    from public.profiles p
   where p.id = auth.uid();
$$;

revoke all on function public.get_my_profile() from public;
grant execute on function public.get_my_profile() to authenticated;

revoke select on public.profiles from authenticated;
grant select (id, display_name, avatar_url) on public.profiles to authenticated;
