-- FaithBridge — estructura para el MODO IGLESIA (fase 2).
-- Las tablas existen para que la arquitectura no tenga que rehacerse, pero el
-- backend mantiene la función deshabilitada (app_config.church_mode_enabled=false)
-- hasta validar el MVP personal y la rentabilidad del plan Iglesia.

begin;

create table if not exists public.church_sessions (
  id               uuid primary key default gen_random_uuid(),
  org_id           uuid not null references public.organizations (id) on delete cascade,
  created_by       uuid not null references auth.users (id) on delete restrict,
  live_session_id  uuid references public.live_sessions (id) on delete set null,
  -- Código corto para unirse. Se guarda solo el hash; el código se muestra una vez.
  join_code_hash   text not null unique,
  is_private       boolean not null default true,   -- nunca se listan públicamente
  source_lang      text not null check (source_lang in ('en', 'es')),
  target_lang      text check (target_lang in ('en', 'es')),  -- un idioma destino por sesión
  max_listeners    integer not null default 30 check (max_listeners between 1 and 500),
  status           text not null default 'scheduled' check (status in ('scheduled', 'live', 'ended')),
  starts_at        timestamptz,
  ended_at         timestamptz,
  created_at       timestamptz not null default now(),
  join_expires_at  timestamptz not null default now() + interval '6 hours'
);

-- Asistentes conectados (para contar asistentes simultáneos y tráfico por separado).
create table if not exists public.church_session_listeners (
  church_session_id uuid not null references public.church_sessions (id) on delete cascade,
  listener_id       uuid not null,  -- id anónimo o user_id; no requiere cuenta
  joined_at         timestamptz not null default now(),
  left_at           timestamptz,
  bytes_sent        bigint not null default 0,
  primary key (church_session_id, listener_id, joined_at)
);

-- Métricas separadas del modo iglesia: minutos de transmisión, asistentes, tráfico.
create table if not exists public.church_usage (
  org_id            uuid not null references public.organizations (id) on delete cascade,
  period_start      timestamptz not null,
  broadcast_seconds integer not null default 0,
  peak_listeners    integer not null default 0,
  listener_seconds  bigint not null default 0,
  egress_bytes      bigint not null default 0,
  primary key (org_id, period_start)
);

alter table public.church_sessions          enable row level security;
alter table public.church_session_listeners enable row level security;
alter table public.church_usage             enable row level security;

-- Solo miembros de la organización ven sus sesiones. Los asistentes se unen
-- mediante el backend con el código; no existe consulta pública ni directorio.
drop policy if exists church_sessions_member_select on public.church_sessions;
create policy church_sessions_member_select on public.church_sessions for select to authenticated
  using (public.is_org_member(org_id));
drop policy if exists church_usage_member_select on public.church_usage;
create policy church_usage_member_select on public.church_usage for select to authenticated
  using (public.is_org_member(org_id));
grant select on public.church_sessions, public.church_usage to authenticated;

insert into public.app_config (key, value) values ('church_mode_enabled', 'false'::jsonb)
on conflict (key) do nothing;

commit;
