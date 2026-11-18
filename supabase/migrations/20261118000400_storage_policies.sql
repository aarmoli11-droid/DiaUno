-- Storage: sustituye las políticas genéricas por políticas específicas por bucket.
-- Las evidencias de tareas siguen siendo visibles para el equipo del proyecto;
-- los comprobantes financieros NO amplían acceso a los compañeros de proyecto.

drop policy if exists storage_owner_read on storage.objects;
drop policy if exists storage_owner_insert on storage.objects;
drop policy if exists storage_owner_update on storage.objects;
drop policy if exists storage_owner_delete on storage.objects;

-- Helper: ¿puede el usuario leer la ocurrencia a la que pertenece la evidencia?
create or replace function public.can_read_occurrence(p_occurrence uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
      from public.task_occurrences o
      join public.tasks t on t.id = o.task_id
     where o.id = p_occurrence
       and (
         (t.project_id is null and (t.created_by = auth.uid() or t.assigned_to = auth.uid()))
         or (t.project_id is not null and public.can_read_project(t.project_id))
       )
  );
$$;

-- Helper: ¿puede el usuario escribir evidencia en esa ocurrencia?
create or replace function public.can_write_occurrence(p_occurrence uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
      from public.task_occurrences o
      join public.tasks t on t.id = o.task_id
     where o.id = p_occurrence
       and (
         (t.project_id is null and t.created_by = auth.uid())
         or (t.project_id is not null
             and public.has_project_role(t.project_id, array['owner','admin','collaborator']))
       )
  );
$$;

revoke all on function public.can_read_occurrence(uuid) from public;
grant execute on function public.can_read_occurrence(uuid) to authenticated;
revoke all on function public.can_write_occurrence(uuid) from public;
grant execute on function public.can_write_occurrence(uuid) to authenticated;

-- task-evidence: {uid}/tasks/{occurrence_id}/{archivo}
create policy task_evidence_read on storage.objects for select to authenticated
using (
  bucket_id = 'task-evidence'
  and (storage.foldername(name))[1] = auth.uid()::text
  and (storage.foldername(name))[2] = 'tasks'
  and public.can_read_occurrence(((storage.foldername(name))[3])::uuid)
);
create policy task_evidence_insert on storage.objects for insert to authenticated
with check (
  bucket_id = 'task-evidence'
  and (storage.foldername(name))[1] = auth.uid()::text
  and (storage.foldername(name))[2] = 'tasks'
  and public.can_write_occurrence(((storage.foldername(name))[3])::uuid)
);
create policy task_evidence_update on storage.objects for update to authenticated
using (
  bucket_id = 'task-evidence'
  and (storage.foldername(name))[1] = auth.uid()::text
)
with check (
  bucket_id = 'task-evidence'
  and (storage.foldername(name))[1] = auth.uid()::text
  and public.can_write_occurrence(((storage.foldername(name))[3])::uuid)
);
create policy task_evidence_delete on storage.objects for delete to authenticated
using (
  bucket_id = 'task-evidence'
  and (storage.foldername(name))[1] = auth.uid()::text
  and public.can_write_occurrence(((storage.foldername(name))[3])::uuid)
);

-- finance-receipts: {uid}/finance/{transaction_id}/{archivo}.
-- Sólo el dueño de la transacción; pertenecer al proyecto NO basta.
create policy finance_receipts_read on storage.objects for select to authenticated
using (
  bucket_id = 'finance-receipts'
  and (storage.foldername(name))[1] = auth.uid()::text
  and (storage.foldername(name))[2] = 'finance'
  and exists (
    select 1 from public.transactions t
     where t.id = ((storage.foldername(name))[3])::uuid
       and t.owner_id = auth.uid()
  )
);
create policy finance_receipts_insert on storage.objects for insert to authenticated
with check (
  bucket_id = 'finance-receipts'
  and (storage.foldername(name))[1] = auth.uid()::text
  and (storage.foldername(name))[2] = 'finance'
  and exists (
    select 1 from public.transactions t
     where t.id = ((storage.foldername(name))[3])::uuid
       and t.owner_id = auth.uid()
  )
);
create policy finance_receipts_update on storage.objects for update to authenticated
using (
  bucket_id = 'finance-receipts'
  and (storage.foldername(name))[1] = auth.uid()::text
)
with check (
  bucket_id = 'finance-receipts'
  and (storage.foldername(name))[1] = auth.uid()::text
  and (storage.foldername(name))[2] = 'finance'
  and exists (
    select 1 from public.transactions t
     where t.id = ((storage.foldername(name))[3])::uuid
       and t.owner_id = auth.uid()
  )
);
create policy finance_receipts_delete on storage.objects for delete to authenticated
using (
  bucket_id = 'finance-receipts'
  and (storage.foldername(name))[1] = auth.uid()::text
  and (storage.foldername(name))[2] = 'finance'
  and exists (
    select 1 from public.transactions t
     where t.id = ((storage.foldername(name))[3])::uuid
       and t.owner_id = auth.uid()
  )
);

-- avatars: bucket público de lectura; escritura únicamente en la carpeta propia.
create policy avatars_read on storage.objects for select to authenticated
using (bucket_id = 'avatars');
create policy avatars_insert on storage.objects for insert to authenticated
with check (
  bucket_id = 'avatars'
  and (storage.foldername(name))[1] = auth.uid()::text
);
create policy avatars_update on storage.objects for update to authenticated
using (
  bucket_id = 'avatars'
  and (storage.foldername(name))[1] = auth.uid()::text
)
with check (
  bucket_id = 'avatars'
  and (storage.foldername(name))[1] = auth.uid()::text
);
create policy avatars_delete on storage.objects for delete to authenticated
using (
  bucket_id = 'avatars'
  and (storage.foldername(name))[1] = auth.uid()::text
);
