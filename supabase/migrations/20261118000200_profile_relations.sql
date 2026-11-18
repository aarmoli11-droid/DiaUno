-- Relaciones para que PostgREST pueda embeber el nombre visible del autor.
alter table public.task_comments
  drop constraint if exists task_comments_author_profile_fkey;
alter table public.task_comments
  add constraint task_comments_author_profile_fkey
  foreign key (author_id) references public.profiles(id) on delete cascade;

alter table public.activity_log
  drop constraint if exists activity_log_actor_profile_fkey;
alter table public.activity_log
  add constraint activity_log_actor_profile_fkey
  foreign key (actor_id) references public.profiles(id) on delete cascade;

alter table public.garden_progress_events
  drop constraint if exists garden_user_profile_fkey;
alter table public.garden_progress_events
  add constraint garden_user_profile_fkey
  foreign key (user_id) references public.profiles(id) on delete cascade;
