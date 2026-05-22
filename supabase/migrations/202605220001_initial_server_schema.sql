-- boubiga Supabase initial schema.
-- Apply after creating a Supabase project. The mobile app reads only
-- published_configs through Edge Functions; draft tables are admin-only.

create extension if not exists pgcrypto;

do $$
begin
  if not exists (select 1 from pg_type where typname = 'admin_role') then
    create type public.admin_role as enum ('owner', 'editor', 'viewer');
  end if;
  if not exists (select 1 from pg_type where typname = 'content_status') then
    create type public.content_status as enum ('draft', 'published', 'archived');
  end if;
  if not exists (select 1 from pg_type where typname = 'os_platform') then
    create type public.os_platform as enum ('ios', 'ipados');
  end if;
  if not exists (select 1 from pg_type where typname = 'ios_severity') then
    create type public.ios_severity as enum ('normal', 'security', 'major');
  end if;
  if not exists (select 1 from pg_type where typname = 'remote_severity') then
    create type public.remote_severity as enum ('info', 'normal', 'warning', 'critical');
  end if;
  if not exists (select 1 from pg_type where typname = 'target_surface') then
    create type public.target_surface as enum ('todo', 'caution', 'solve', 'diagnosis');
  end if;
  if not exists (select 1 from pg_type where typname = 'access_level') then
    create type public.access_level as enum ('free', 'pro');
  end if;
  if not exists (select 1 from pg_type where typname = 'rule_match_type') then
    create type public.rule_match_type as enum ('all', 'any');
  end if;
  if not exists (select 1 from pg_type where typname = 'rule_operator') then
    create type public.rule_operator as enum (
      'eq', 'neq', 'lt', 'lte', 'gt', 'gte', 'between', 'is_null', 'is_not_null', 'in'
    );
  end if;
  if not exists (select 1 from pg_type where typname = 'candidate_status') then
    create type public.candidate_status as enum ('pending', 'approved', 'rejected');
  end if;
end $$;

create table if not exists public.admin_profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  role public.admin_role not null default 'viewer',
  created_at timestamptz not null default now()
);

create table if not exists public.app_config_versions (
  id uuid primary key default gen_random_uuid(),
  version_number integer not null unique,
  status public.content_status not null default 'draft',
  notes text,
  created_by uuid references auth.users(id),
  published_by uuid references auth.users(id),
  created_at timestamptz not null default now(),
  published_at timestamptz
);

create table if not exists public.os_versions (
  id uuid primary key default gen_random_uuid(),
  platform public.os_platform not null default 'ios',
  latest_version text not null,
  release_date date,
  severity public.ios_severity not null default 'normal',
  message text not null default '',
  source_url text,
  status public.content_status not null default 'draft',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.os_release_candidates (
  id uuid primary key default gen_random_uuid(),
  platform text not null,
  detected_version text not null,
  detected_release_date date,
  source_url text,
  source_text text,
  confidence numeric,
  status public.candidate_status not null default 'pending',
  detected_at timestamptz not null default now(),
  reviewed_by uuid references auth.users(id),
  reviewed_at timestamptz
);

create table if not exists public.condition_thresholds (
  id uuid primary key default gen_random_uuid(),
  metric text not null unique,
  label text not null,
  good_min numeric,
  warning_min numeric,
  critical_below numeric,
  unit text,
  status public.content_status not null default 'draft',
  updated_at timestamptz not null default now()
);

create table if not exists public.content_guides (
  id uuid primary key default gen_random_uuid(),
  slug text not null unique,
  category text not null,
  title text not null,
  summary text,
  body text,
  access_level public.access_level not null default 'free',
  priority integer not null default 100,
  min_ios_version text,
  max_ios_version text,
  status public.content_status not null default 'draft',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.action_items (
  id uuid primary key default gen_random_uuid(),
  slug text not null unique,
  title text not null,
  description text not null default '',
  category text not null,
  target_surface public.target_surface not null,
  severity public.remote_severity not null default 'info',
  cta_label text,
  action_type text,
  guide_slug text references public.content_guides(slug),
  access_level public.access_level not null default 'free',
  priority integer not null default 100,
  status public.content_status not null default 'draft',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.rules (
  id uuid primary key default gen_random_uuid(),
  slug text not null unique,
  name text not null,
  action_item_id uuid references public.action_items(id) on delete cascade,
  match_type public.rule_match_type not null default 'all',
  is_active boolean not null default true,
  status public.content_status not null default 'draft',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.rule_conditions (
  id uuid primary key default gen_random_uuid(),
  rule_id uuid not null references public.rules(id) on delete cascade,
  metric text not null,
  operator public.rule_operator not null,
  value_json jsonb,
  created_at timestamptz not null default now()
);

create table if not exists public.published_configs (
  id uuid primary key default gen_random_uuid(),
  version_number integer not null unique,
  config_json jsonb not null,
  published_by uuid references auth.users(id),
  published_at timestamptz not null default now(),
  is_current boolean not null default false
);

create unique index if not exists one_current_published_config
  on public.published_configs (is_current)
  where is_current;

create table if not exists public.audit_logs (
  id uuid primary key default gen_random_uuid(),
  actor_id uuid references auth.users(id),
  action text not null,
  target_table text,
  target_id uuid,
  before_json jsonb,
  after_json jsonb,
  created_at timestamptz not null default now()
);

create or replace function public.touch_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

drop trigger if exists touch_os_versions_updated_at on public.os_versions;
create trigger touch_os_versions_updated_at
before update on public.os_versions
for each row execute function public.touch_updated_at();

drop trigger if exists touch_content_guides_updated_at on public.content_guides;
create trigger touch_content_guides_updated_at
before update on public.content_guides
for each row execute function public.touch_updated_at();

drop trigger if exists touch_action_items_updated_at on public.action_items;
create trigger touch_action_items_updated_at
before update on public.action_items
for each row execute function public.touch_updated_at();

drop trigger if exists touch_rules_updated_at on public.rules;
create trigger touch_rules_updated_at
before update on public.rules
for each row execute function public.touch_updated_at();

create or replace function public.current_admin_role()
returns public.admin_role
language sql
security definer
set search_path = public
stable
as $$
  select role from public.admin_profiles where id = auth.uid()
$$;

create or replace function public.is_admin()
returns boolean
language sql
security definer
set search_path = public
stable
as $$
  select public.current_admin_role() is not null
$$;

create or replace function public.can_edit_admin_content()
returns boolean
language sql
security definer
set search_path = public
stable
as $$
  select public.current_admin_role() in ('owner', 'editor')
$$;

alter table public.admin_profiles enable row level security;
alter table public.app_config_versions enable row level security;
alter table public.os_versions enable row level security;
alter table public.os_release_candidates enable row level security;
alter table public.condition_thresholds enable row level security;
alter table public.content_guides enable row level security;
alter table public.action_items enable row level security;
alter table public.rules enable row level security;
alter table public.rule_conditions enable row level security;
alter table public.published_configs enable row level security;
alter table public.audit_logs enable row level security;

drop policy if exists "admins can read admin profiles" on public.admin_profiles;
create policy "admins can read admin profiles"
on public.admin_profiles for select
using (public.is_admin());

drop policy if exists "owners can manage admin profiles" on public.admin_profiles;
create policy "owners can manage admin profiles"
on public.admin_profiles for all
using (public.current_admin_role() = 'owner')
with check (public.current_admin_role() = 'owner');

drop policy if exists "admins can read app config versions" on public.app_config_versions;
create policy "admins can read app config versions"
on public.app_config_versions for select
using (public.is_admin());

drop policy if exists "editors can manage app config versions" on public.app_config_versions;
create policy "editors can manage app config versions"
on public.app_config_versions for all
using (public.can_edit_admin_content())
with check (public.can_edit_admin_content());

drop policy if exists "admins can read os versions" on public.os_versions;
create policy "admins can read os versions"
on public.os_versions for select
using (public.is_admin());

drop policy if exists "editors can manage os versions" on public.os_versions;
create policy "editors can manage os versions"
on public.os_versions for all
using (public.can_edit_admin_content())
with check (public.can_edit_admin_content());

drop policy if exists "admins can read os candidates" on public.os_release_candidates;
create policy "admins can read os candidates"
on public.os_release_candidates for select
using (public.is_admin());

drop policy if exists "editors can manage os candidates" on public.os_release_candidates;
create policy "editors can manage os candidates"
on public.os_release_candidates for all
using (public.can_edit_admin_content())
with check (public.can_edit_admin_content());

drop policy if exists "admins can read thresholds" on public.condition_thresholds;
create policy "admins can read thresholds"
on public.condition_thresholds for select
using (public.is_admin());

drop policy if exists "editors can manage thresholds" on public.condition_thresholds;
create policy "editors can manage thresholds"
on public.condition_thresholds for all
using (public.can_edit_admin_content())
with check (public.can_edit_admin_content());

drop policy if exists "admins can read guides" on public.content_guides;
create policy "admins can read guides"
on public.content_guides for select
using (public.is_admin());

drop policy if exists "editors can manage guides" on public.content_guides;
create policy "editors can manage guides"
on public.content_guides for all
using (public.can_edit_admin_content())
with check (public.can_edit_admin_content());

drop policy if exists "admins can read action items" on public.action_items;
create policy "admins can read action items"
on public.action_items for select
using (public.is_admin());

drop policy if exists "editors can manage action items" on public.action_items;
create policy "editors can manage action items"
on public.action_items for all
using (public.can_edit_admin_content())
with check (public.can_edit_admin_content());

drop policy if exists "admins can read rules" on public.rules;
create policy "admins can read rules"
on public.rules for select
using (public.is_admin());

drop policy if exists "editors can manage rules" on public.rules;
create policy "editors can manage rules"
on public.rules for all
using (public.can_edit_admin_content())
with check (public.can_edit_admin_content());

drop policy if exists "admins can read rule conditions" on public.rule_conditions;
create policy "admins can read rule conditions"
on public.rule_conditions for select
using (public.is_admin());

drop policy if exists "editors can manage rule conditions" on public.rule_conditions;
create policy "editors can manage rule conditions"
on public.rule_conditions for all
using (public.can_edit_admin_content())
with check (public.can_edit_admin_content());

drop policy if exists "public can read current published config" on public.published_configs;
create policy "public can read current published config"
on public.published_configs for select
using (is_current = true);

drop policy if exists "editors can manage published configs" on public.published_configs;
create policy "editors can manage published configs"
on public.published_configs for all
using (public.can_edit_admin_content())
with check (public.can_edit_admin_content());

drop policy if exists "admins can read audit logs" on public.audit_logs;
create policy "admins can read audit logs"
on public.audit_logs for select
using (public.is_admin());

drop policy if exists "editors can insert audit logs" on public.audit_logs;
create policy "editors can insert audit logs"
on public.audit_logs for insert
with check (public.can_edit_admin_content());
