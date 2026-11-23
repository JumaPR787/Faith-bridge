-- FaithBridge — modo iglesia: ajustes para la implementación de la fase 2.
begin;

alter table public.church_sessions
  add column if not exists save_transcript boolean not null default false,
  add column if not exists transcript_id uuid references public.transcripts (id) on delete set null;

-- Búsquedas frecuentes.
create index if not exists church_sessions_org_idx on public.church_sessions (org_id, created_at desc);
create index if not exists church_listeners_session_idx on public.church_session_listeners (church_session_id);
create index if not exists org_members_user_idx on public.organization_members (user_id);

-- Los miembros de la organización pueden ver las conexiones de oyentes
-- (anónimas: solo id aleatorio, horas y bytes) para medir la asistencia.
alter table public.church_session_listeners enable row level security;
drop policy if exists church_listeners_member_select on public.church_session_listeners;
create policy church_listeners_member_select on public.church_session_listeners for select to authenticated
  using (exists (select 1 from public.church_sessions cs
                 where cs.id = church_session_id and public.is_org_member(cs.org_id)));
grant select on public.church_session_listeners to authenticated;

commit;
