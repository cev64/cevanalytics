-- CEV Analytics client portal schema for Supabase
-- Run this in the Supabase SQL editor after creating your project.
-- This creates the tables and row-level security policies needed for:
-- 1) username/password client access through Supabase Auth
-- 2) assigning clients to one or more Power BI dashboards
-- 3) future row-level security so users only see their assigned dashboard records

begin;

create extension if not exists pgcrypto;

create type public.portal_user_role as enum ('client', 'admin');
create type public.client_member_role as enum ('viewer', 'manager');

create table public.profiles (
  id uuid primary key references auth.users (id) on delete cascade,
  email text not null,
  full_name text,
  company_name text,
  role public.portal_user_role not null default 'client',
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.clients (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  contact_email text,
  notes text,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.client_members (
  id uuid primary key default gen_random_uuid(),
  client_id uuid not null references public.clients (id) on delete cascade,
  user_id uuid not null references auth.users (id) on delete cascade,
  member_role public.client_member_role not null default 'viewer',
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint client_members_unique_user_per_client unique (client_id, user_id)
);

create table public.power_bi_dashboards (
  id uuid primary key default gen_random_uuid(),
  client_id uuid not null references public.clients (id) on delete cascade,
  name text not null,
  description text,
  embed_url text not null,
  content_type text not null default 'app',
  app_id text,
  app_url text,
  workspace_id text,
  report_id text,
  dataset_id text,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint power_bi_dashboards_content_type_check
    check (content_type in ('app', 'report', 'dashboard', 'tile'))
);

create table public.dashboard_user_access (
  id uuid primary key default gen_random_uuid(),
  dashboard_id uuid not null references public.power_bi_dashboards (id) on delete cascade,
  user_id uuid not null references auth.users (id) on delete cascade,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint dashboard_user_access_unique unique (dashboard_id, user_id)
);

create index profiles_email_idx on public.profiles (lower(email));
create index client_members_user_id_idx on public.client_members (user_id);
create index client_members_client_id_idx on public.client_members (client_id);
create index power_bi_dashboards_client_id_idx on public.power_bi_dashboards (client_id);
create index dashboard_user_access_user_id_idx on public.dashboard_user_access (user_id);
create index dashboard_user_access_dashboard_id_idx on public.dashboard_user_access (dashboard_id);

create or replace function public.set_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

create trigger set_profiles_updated_at
before update on public.profiles
for each row execute function public.set_updated_at();

create trigger set_clients_updated_at
before update on public.clients
for each row execute function public.set_updated_at();

create trigger set_client_members_updated_at
before update on public.client_members
for each row execute function public.set_updated_at();

create trigger set_power_bi_dashboards_updated_at
before update on public.power_bi_dashboards
for each row execute function public.set_updated_at();

create trigger set_dashboard_user_access_updated_at
before update on public.dashboard_user_access
for each row execute function public.set_updated_at();

create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.profiles (id, email, full_name, company_name)
  values (
    new.id,
    coalesce(new.email, ''),
    new.raw_user_meta_data ->> 'full_name',
    new.raw_user_meta_data ->> 'company_name'
  )
  on conflict (id) do update
  set email = excluded.email;

  return new;
end;
$$;

create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

create or replace function public.current_user_is_admin()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.profiles
    where id = auth.uid()
      and role = 'admin'
      and is_active = true
  );
$$;

create or replace function public.current_user_can_access_client(target_client_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select public.current_user_is_admin()
    or exists (
      select 1
      from public.client_members cm
      join public.profiles p on p.id = cm.user_id
      where cm.client_id = target_client_id
        and cm.user_id = auth.uid()
        and cm.is_active = true
        and p.is_active = true
    );
$$;

create or replace function public.current_user_can_access_dashboard(target_dashboard_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select public.current_user_is_admin()
    or exists (
      select 1
      from public.power_bi_dashboards d
      where d.id = target_dashboard_id
        and d.is_active = true
        and public.current_user_can_access_client(d.client_id)
    )
    or exists (
      select 1
      from public.dashboard_user_access dua
      join public.profiles p on p.id = dua.user_id
      where dua.dashboard_id = target_dashboard_id
        and dua.user_id = auth.uid()
        and dua.is_active = true
        and p.is_active = true
    );
$$;

alter table public.profiles enable row level security;
alter table public.clients enable row level security;
alter table public.client_members enable row level security;
alter table public.power_bi_dashboards enable row level security;
alter table public.dashboard_user_access enable row level security;

create policy "Profiles are viewable by owner or admins"
on public.profiles
for select
to authenticated
using (id = auth.uid() or public.current_user_is_admin());

create policy "Users can update their own basic profile"
on public.profiles
for update
to authenticated
using (id = auth.uid())
with check (id = auth.uid() and role = 'client');

create policy "Admins can manage profiles"
on public.profiles
for all
to authenticated
using (public.current_user_is_admin())
with check (public.current_user_is_admin());

create policy "Clients are viewable by members or admins"
on public.clients
for select
to authenticated
using (public.current_user_can_access_client(id));

create policy "Admins can manage clients"
on public.clients
for all
to authenticated
using (public.current_user_is_admin())
with check (public.current_user_is_admin());

create policy "Client memberships are viewable by member or admins"
on public.client_members
for select
to authenticated
using (user_id = auth.uid() or public.current_user_is_admin());

create policy "Admins can manage client memberships"
on public.client_members
for all
to authenticated
using (public.current_user_is_admin())
with check (public.current_user_is_admin());

create policy "Dashboards are viewable by assigned users, client members, or admins"
on public.power_bi_dashboards
for select
to authenticated
using (public.current_user_can_access_dashboard(id));

create policy "Admins can manage dashboards"
on public.power_bi_dashboards
for all
to authenticated
using (public.current_user_is_admin())
with check (public.current_user_is_admin());

create policy "Dashboard access rows are viewable by assigned user or admins"
on public.dashboard_user_access
for select
to authenticated
using (user_id = auth.uid() or public.current_user_is_admin());

create policy "Admins can manage dashboard user access"
on public.dashboard_user_access
for all
to authenticated
using (public.current_user_is_admin())
with check (public.current_user_is_admin());

revoke all on public.profiles from anon;
revoke all on public.clients from anon;
revoke all on public.client_members from anon;
revoke all on public.power_bi_dashboards from anon;
revoke all on public.dashboard_user_access from anon;

grant select, update on public.profiles to authenticated;
grant select on public.clients to authenticated;
grant select on public.client_members to authenticated;
grant select on public.power_bi_dashboards to authenticated;
grant select on public.dashboard_user_access to authenticated;

commit;
