-- Borrado global y simétrico (incremental; no reescribe migraciones aplicadas).
--
-- Antes de borrar una finanza o un proyecto se eliminan las filas que no tenían
-- FK hacia su origen (distribuciones polimórficas y notificaciones), y las
-- finanzas asociadas a un proyecto/suscripción dejan de quedar huérfanas.
-- Los archivos de Storage se borran desde el cliente antes de borrar la fila:
-- las políticas de storage exigen que la fila padre siga existiendo.

-- ---------------------------------------------------------------------------
-- Movimientos: limpiar distribuciones y notificaciones antes de borrar la fila.
-- `files.transaction_id` ya tiene ON DELETE CASCADE.
-- ---------------------------------------------------------------------------
create or replace function public.cleanup_transaction_before_delete()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  delete from public.invoices where transaction_id = old.id;

  delete from public.cost_distributions
   where source_type = 'expense' and source_id = old.id;

  delete from public.notifications
   where category = 'finance' and target_id = old.id;

  return old;
end;
$$;

drop trigger if exists transactions_cleanup on public.transactions;
create trigger transactions_cleanup
  before delete on public.transactions
  for each row execute function public.cleanup_transaction_before_delete();

-- ---------------------------------------------------------------------------
-- Suscripciones: sus movimientos y distribuciones se borran con ella.
-- ---------------------------------------------------------------------------
create or replace function public.cleanup_subscription_before_delete()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  delete from public.cost_distributions
   where source_type = 'subscription' and source_id = old.id;

  -- Al borrar cada movimiento se dispara `transactions_cleanup`, que limpia
  -- sus distribuciones y notificaciones antes de que desaparezca la suscripción.
  delete from public.transactions where subscription_id = old.id;

  delete from public.notifications
   where category = 'finance' and target_id = old.id;

  return old;
end;
$$;

drop trigger if exists subscriptions_cleanup on public.subscriptions;
create trigger subscriptions_cleanup
  before delete on public.subscriptions
  for each row execute function public.cleanup_subscription_before_delete();

-- ---------------------------------------------------------------------------
-- Proyectos: finanzas, agenda, facturas y notificaciones asociadas.
-- El resto (tareas, ocurrencias, archivos, jardín, herramientas, tiempo,
-- actividad, progreso y miembros) ya cascaba por FK.
-- ---------------------------------------------------------------------------
create or replace function public.cleanup_project_before_delete()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  -- Primero suscripciones: su trigger elimina también sus movimientos.
  delete from public.subscriptions where project_id = old.id;
  delete from public.transactions where project_id = old.id;
  delete from public.events where project_id = old.id;
  delete from public.invoices where project_id = old.id;

  delete from public.notifications
   where category = 'project' and target_id = old.id;

  return old;
end;
$$;

drop trigger if exists projects_cleanup on public.projects;
create trigger projects_cleanup
  before delete on public.projects
  for each row execute function public.cleanup_project_before_delete();
