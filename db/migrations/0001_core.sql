-- FaithBridge — esquema principal (PostgreSQL 15+ / Supabase).
-- Ejecutar en orden. Diseñado para Supabase: usa auth.users y auth.uid().
-- En desarrollo local sin Supabase, aplicar antes db/dev/0000_supabase_shim.sql.
--
-- Principio: el BACKEND (rol de servicio) es la única vía de escritura para
-- cuotas, beneficios, sesiones y webhooks. Las políticas RLS permiten a cada
-- usuario autenticado LEER y BORRAR solo sus propios datos (defensa en
-- profundidad si la app consulta Supabase directamente).

begin;

create extension if not exists pgcrypto;

-- ───────────────────────── Perfiles ─────────────────────────
create table if not exists public.profiles (
  user_id        uuid primary key references auth.users (id) on delete cascade,
  ui_locale      text not null default 'es' check (ui_locale in ('es', 'en')),
  -- Consentimiento separado para usar contenido en mejora de modelos.
  -- Por defecto: false. Hoy NINGÚN flujo usa contenido para entrenamiento.
  training_consent boolean not null default false,
  -- Días que se conservan las transcripciones guardadas (luego se purgan).
  transcript_retention_days integer not null default 365
    check (transcript_retention_days between 1 and 3650),
  created_at     timestamptz not null default now()
);

-- ───────────────────────── Organizaciones (modo iglesia, fase 2) ─────────────
create table if not exists public.organizations (
  id          uuid primary key default gen_random_uuid(),
  name        text not null check (char_length(name) between 2 and 120),
  created_by  uuid not null references auth.users (id) on delete restrict,
  -- El organizador declara tener autorización para transmitir/procesar el audio.
  audio_authorization_attested_at timestamptz,
  created_at  timestamptz not null default now()
);

create table if not exists public.organization_members (
  org_id    uuid not null references public.organizations (id) on delete cascade,
  user_id   uuid not null references auth.users (id) on delete cascade,
  role      text not null check (role in ('owner', 'admin', 'member')),
  added_at  timestamptz not null default now(),
  primary key (org_id, user_id)
);

-- ───────────────────────── Beneficios (fuente: tienda vía RevenueCat) ────────
-- Una fila por usuario con el estado vigente calculado en servidor.
create table if not exists public.entitlements (
  user_id        uuid primary key references auth.users (id) on delete cascade,
  plan           text not null default 'none' check (plan in ('none', 'personal', 'church')),
  status         text not null default 'none'
                 check (status in ('none', 'trial', 'active', 'grace', 'billing_issue',
                                   'cancelled_active', 'expired', 'refunded')),
  product_id     text,
  store          text,
  is_sandbox     boolean not null default false,
  period_start   timestamptz,
  period_end     timestamptz,
  access_until   timestamptz,          -- fin del acceso (incluye periodo de gracia)
  will_renew     boolean not null default false,
  trial_granted_at timestamptz,        -- primera vez que se concedió cuota de prueba
  updated_at     timestamptz not null default now()
);

-- Cuota por periodo de facturación (trial o pagado). Los segundos se miden en
-- el servidor a partir del audio realmente recibido.
create table if not exists public.usage_periods (
  user_id        uuid not null references auth.users (id) on delete cascade,
  period_start   timestamptz not null,
  period_end     timestamptz not null,
  kind           text not null check (kind in ('trial', 'paid')),
  quota_seconds  integer not null check (quota_seconds >= 0),
  used_seconds   integer not null default 0 check (used_seconds >= 0),
  primary key (user_id, period_start),
  check (period_end > period_start)
);

create table if not exists public.usage_events (
  id           bigserial primary key,
  user_id      uuid not null references auth.users (id) on delete cascade,
  period_start timestamptz not null,
  session_id   uuid,
  kind         text not null check (kind in ('live_audio', 'text_translation')),
  seconds      integer not null check (seconds >= 0),
  created_at   timestamptz not null default now()
);
create index if not exists usage_events_user_idx on public.usage_events (user_id, created_at desc);

-- ───────────────────────── Sesiones en vivo ─────────────────────────
create table if not exists public.live_sessions (
  id              uuid primary key default gen_random_uuid(),
  user_id         uuid not null references auth.users (id) on delete cascade,
  org_id          uuid references public.organizations (id) on delete cascade,
  mode            text not null default 'personal' check (mode in ('personal', 'church')),
  source_lang     text not null check (source_lang in ('en', 'es')),
  target_lang     text check (target_lang in ('en', 'es')),
  save_transcript boolean not null default false,
  status          text not null default 'active' check (status in ('active', 'ended')),
  end_reason      text,
  audio_seconds   integer not null default 0,
  started_at      timestamptz not null default now(),
  last_heartbeat  timestamptz not null default now(),
  ended_at        timestamptz,
  check (target_lang is null or target_lang <> source_lang)
);
-- Control de concurrencia: una sola sesión personal activa por usuario.
create unique index if not exists live_sessions_one_active_personal
  on public.live_sessions (user_id) where status = 'active' and mode = 'personal';

-- ───────────────────────── Transcripciones (solo si el usuario elige guardar) ─
create table if not exists public.transcripts (
  id           uuid primary key default gen_random_uuid(),
  user_id      uuid not null references auth.users (id) on delete cascade,
  org_id       uuid references public.organizations (id) on delete cascade,
  session_id   uuid references public.live_sessions (id) on delete set null,
  title        text not null default '',
  source_lang  text not null check (source_lang in ('en', 'es')),
  target_lang  text check (target_lang in ('en', 'es')),
  created_at   timestamptz not null default now(),
  expires_at   timestamptz not null
);
create index if not exists transcripts_user_idx on public.transcripts (user_id, created_at desc);
create index if not exists transcripts_expiry_idx on public.transcripts (expires_at);

create table if not exists public.transcript_segments (
  transcript_id   uuid not null references public.transcripts (id) on delete cascade,
  seq             integer not null check (seq >= 0),
  start_ms        integer not null,
  end_ms          integer not null,
  source_text     text not null,
  translated_text text,
  translation_status text not null default 'none'
                  check (translation_status in ('none', 'ok', 'failed')),
  primary key (transcript_id, seq)
);

-- ───────────────────────── Glosario ─────────────────────────
-- user_id NULL = término por defecto del sistema (lectura para todos).
create table if not exists public.glossary_terms (
  id           uuid primary key default gen_random_uuid(),
  user_id      uuid references auth.users (id) on delete cascade,
  org_id       uuid references public.organizations (id) on delete cascade,
  source_lang  text not null check (source_lang in ('en', 'es')),
  target_lang  text not null check (target_lang in ('en', 'es')),
  source_term  text not null check (char_length(source_term) between 1 and 80),
  target_term  text not null check (char_length(target_term) between 1 and 80),
  created_at   timestamptz not null default now(),
  check (source_lang <> target_lang)
);
create unique index if not exists glossary_unique_term
  on public.glossary_terms (coalesce(user_id, '00000000-0000-0000-0000-000000000000'::uuid),
                            source_lang, target_lang, lower(source_term));

-- ───────────────────────── Webhooks (idempotencia) ─────────────────────────
create table if not exists public.webhook_events (
  provider     text not null,
  event_id     text not null,
  event_type   text not null,
  app_user_id  text,
  received_at  timestamptz not null default now(),
  processed_at timestamptz,
  error        text,
  primary key (provider, event_id)
);

-- ───────────────────────── Operación: interruptor y presupuesto ─────────────
create table if not exists public.app_config (
  key        text primary key,
  value      jsonb not null,
  updated_at timestamptz not null default now()
);
insert into public.app_config (key, value) values
  ('live_sessions_enabled', 'true'::jsonb),
  ('text_translation_enabled', 'true'::jsonb),
  ('max_concurrent_live_sessions', '200'::jsonb),
  ('daily_cost_limit_usd', '25'::jsonb)
on conflict (key) do nothing;

-- Costo ESTIMADO por día y proveedor (para alertas y límite de gasto).
create table if not exists public.spend_ledger (
  day       date not null,
  provider  text not null,
  units     numeric not null default 0,
  est_usd   numeric(12, 6) not null default 0,
  primary key (day, provider)
);

create table if not exists public.account_deletions (
  id            bigserial primary key,
  user_id_hash  text not null,     -- sha256 del id; no se guarda el id real
  requested_at  timestamptz not null default now(),
  completed_at  timestamptz
);

-- ───────────────────────── RLS ─────────────────────────
alter table public.profiles             enable row level security;
alter table public.organizations        enable row level security;
alter table public.organization_members enable row level security;
alter table public.entitlements         enable row level security;
alter table public.usage_periods        enable row level security;
alter table public.usage_events         enable row level security;
alter table public.live_sessions        enable row level security;
alter table public.transcripts          enable row level security;
alter table public.transcript_segments  enable row level security;
alter table public.glossary_terms       enable row level security;
alter table public.webhook_events       enable row level security;
alter table public.app_config           enable row level security;
alter table public.spend_ledger         enable row level security;
alter table public.account_deletions    enable row level security;
-- webhook_events, app_config, spend_ledger y account_deletions: sin políticas
-- => inaccesibles para usuarios; solo el rol de servicio del backend.

create or replace function public.is_org_member(p_org uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select exists (select 1 from public.organization_members m
                 where m.org_id = p_org and m.user_id = auth.uid());
$$;

-- Perfiles
drop policy if exists profiles_self_select on public.profiles;
create policy profiles_self_select on public.profiles for select to authenticated
  using (user_id = auth.uid());
drop policy if exists profiles_self_update on public.profiles;
create policy profiles_self_update on public.profiles for update to authenticated
  using (user_id = auth.uid()) with check (user_id = auth.uid());

-- Organizaciones: solo miembros las ven. Nunca hay listado público.
drop policy if exists orgs_member_select on public.organizations;
create policy orgs_member_select on public.organizations for select to authenticated
  using (public.is_org_member(id));
drop policy if exists org_members_select on public.organization_members;
create policy org_members_select on public.organization_members for select to authenticated
  using (public.is_org_member(org_id));

-- Beneficios y uso: solo lectura propia.
drop policy if exists entitlements_self_select on public.entitlements;
create policy entitlements_self_select on public.entitlements for select to authenticated
  using (user_id = auth.uid());
drop policy if exists usage_periods_self_select on public.usage_periods;
create policy usage_periods_self_select on public.usage_periods for select to authenticated
  using (user_id = auth.uid());
drop policy if exists usage_events_self_select on public.usage_events;
create policy usage_events_self_select on public.usage_events for select to authenticated
  using (user_id = auth.uid());
drop policy if exists live_sessions_self_select on public.live_sessions;
create policy live_sessions_self_select on public.live_sessions for select to authenticated
  using (user_id = auth.uid());

-- Transcripciones: el dueño lee y borra; miembros de la organización leen.
drop policy if exists transcripts_select on public.transcripts;
create policy transcripts_select on public.transcripts for select to authenticated
  using (user_id = auth.uid() or (org_id is not null and public.is_org_member(org_id)));
drop policy if exists transcripts_delete on public.transcripts;
create policy transcripts_delete on public.transcripts for delete to authenticated
  using (user_id = auth.uid());
drop policy if exists segments_select on public.transcript_segments;
create policy segments_select on public.transcript_segments for select to authenticated
  using (exists (select 1 from public.transcripts t where t.id = transcript_id
                 and (t.user_id = auth.uid() or (t.org_id is not null and public.is_org_member(t.org_id)))));

-- Glosario: términos del sistema visibles; propios con CRUD.
drop policy if exists glossary_select on public.glossary_terms;
create policy glossary_select on public.glossary_terms for select to authenticated
  using ((user_id is null and org_id is null) or user_id = auth.uid());
drop policy if exists glossary_insert on public.glossary_terms;
create policy glossary_insert on public.glossary_terms for insert to authenticated
  with check (user_id = auth.uid() and org_id is null);
drop policy if exists glossary_delete on public.glossary_terms;
create policy glossary_delete on public.glossary_terms for delete to authenticated
  using (user_id = auth.uid());

-- Privilegios mínimos para el rol "authenticated" (Supabase).
revoke all on all tables in schema public from anon;
grant select on public.profiles, public.organizations, public.organization_members,
  public.entitlements, public.usage_periods, public.usage_events, public.live_sessions,
  public.transcripts, public.transcript_segments, public.glossary_terms to authenticated;
grant update (ui_locale, training_consent, transcript_retention_days) on public.profiles to authenticated;
grant delete on public.transcripts, public.glossary_terms to authenticated;
grant insert (user_id, source_lang, target_lang, source_term, target_term) on public.glossary_terms to authenticated;

-- ───────────────────────── Retención ─────────────────────────
create or replace function public.purge_expired_transcripts()
returns integer language plpgsql security definer set search_path = public as $$
declare n integer;
begin
  delete from public.transcripts where expires_at < now();
  get diagnostics n = row_count;
  return n;
end $$;
revoke all on function public.purge_expired_transcripts() from public, anon, authenticated;

commit;
