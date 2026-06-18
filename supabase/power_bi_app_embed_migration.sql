-- Run this in the Supabase SQL editor to support Power BI app embeds.

alter table public.power_bi_dashboards
add column if not exists content_type text not null default 'app',
add column if not exists app_id text,
add column if not exists app_url text;

do $$
begin
  if not exists (
    select 1
    from pg_constraint
    where conname = 'power_bi_dashboards_content_type_check'
  ) then
    alter table public.power_bi_dashboards
    add constraint power_bi_dashboards_content_type_check
    check (content_type in ('app', 'report', 'dashboard', 'tile'));
  end if;
end $$;

update public.power_bi_dashboards d
set
  content_type = 'app',
  app_id = 'd8360d81-fd0a-414e-ad23-0d52b07a74bb',
  app_url = 'https://app.powerbi.com/groups/me/apps/d8360d81-fd0a-414e-ad23-0d52b07a74bb/reports/cd4e7a75-eed4-4499-8247-7544a8cf8a46/9727d21b8f88e2dd3b27?experience=power-bi',
  embed_url = 'https://app.powerbi.com/groups/me/apps/d8360d81-fd0a-414e-ad23-0d52b07a74bb/reports/cd4e7a75-eed4-4499-8247-7544a8cf8a46/9727d21b8f88e2dd3b27?experience=power-bi',
  report_id = null,
  dataset_id = null,
  is_active = true,
  updated_at = now()
from public.clients c
where d.client_id = c.id
  and c.name = 'SLU HR'
  and d.name = 'sluhr';
