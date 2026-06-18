-- Seed SLU HR client/dashboard access after the Supabase Auth user exists.
-- First create the user in Supabase Dashboard > Authentication > Users with:
-- Email: vonderheidcharlie@gmail.com
-- Name: Charlie Vonderheid
-- Role: client
-- Then run this SQL in the Supabase SQL editor.

do $$
declare
  target_user_id uuid;
  target_client_id uuid;
  target_dashboard_id uuid;
begin
  select id
  into target_user_id
  from auth.users
  where lower(email) = lower('vonderheidcharlie@gmail.com')
  limit 1;

  if target_user_id is null then
    raise exception 'Create auth user vonderheidcharlie@gmail.com in Supabase Auth before running this seed.';
  end if;

  insert into public.profiles (id, email, full_name, company_name, role, is_active)
    values (
    target_user_id,
    'vonderheidcharlie@gmail.com',
    'Charlie Vonderheid',
    'SLU HR',
    'client',
    true
  )
  on conflict (id) do update
  set
    email = excluded.email,
    full_name = excluded.full_name,
    company_name = excluded.company_name,
    role = excluded.role,
    is_active = excluded.is_active;

  select id
  into target_client_id
  from public.clients
  where name = 'SLU HR'
  order by created_at asc
  limit 1;

  if target_client_id is null then
    insert into public.clients (name, contact_email, is_active)
    values ('SLU HR', 'vonderheidcharlie@gmail.com', true)
    returning id into target_client_id;
    else
    update public.clients
    set contact_email = 'vonderheidcharlie@gmail.com',
        is_active = true
    where id = target_client_id;
  end if;

  insert into public.client_members (client_id, user_id, member_role, is_active)
    values (target_client_id, target_user_id, 'viewer', true)
  on conflict (client_id, user_id) do update
  set member_role = excluded.member_role,
      is_active = excluded.is_active;

  select id
  into target_dashboard_id
  from public.power_bi_dashboards
  where client_id = target_client_id
    and name = 'sluhr'
  order by created_at asc
  limit 1;

  if target_dashboard_id is null then
    insert into public.power_bi_dashboards (
      client_id,
      name,
      description,
      embed_url,
      content_type,
      app_id,
      app_url,
      tenant_id,
      report_id,
      is_active
    )
    values (
      target_client_id,
      'sluhr',
      'SLU HR Power BI dashboard',
      'https://app.powerbi.com/reportEmbed?reportId=cd4e7a75-eed4-4499-8247-7544a8cf8a46&appId=d8360d81-fd0a-414e-ad23-0d52b07a74bb&autoAuth=true&ctid=2d0ad075-b724-4e09-be9f-55c901df5cd8&pageName=9727d21b8f88e2dd3b27',
      'app',
      'd8360d81-fd0a-414e-ad23-0d52b07a74bb',
      'https://app.powerbi.com/groups/me/apps/d8360d81-fd0a-414e-ad23-0d52b07a74bb/reports/cd4e7a75-eed4-4499-8247-7544a8cf8a46/9727d21b8f88e2dd3b27?experience=power-bi',
      '2d0ad075-b724-4e09-be9f-55c901df5cd8',
      'cd4e7a75-eed4-4499-8247-7544a8cf8a46',
      true
    )
    returning id into target_dashboard_id;
  else
    update public.power_bi_dashboards
    set description = 'SLU HR Power BI dashboard',
        embed_url = 'https://app.powerbi.com/reportEmbed?reportId=cd4e7a75-eed4-4499-8247-7544a8cf8a46&appId=d8360d81-fd0a-414e-ad23-0d52b07a74bb&autoAuth=true&ctid=2d0ad075-b724-4e09-be9f-55c901df5cd8&pageName=9727d21b8f88e2dd3b27',
        content_type = 'app',
        app_id = 'd8360d81-fd0a-414e-ad23-0d52b07a74bb',
        app_url = 'https://app.powerbi.com/groups/me/apps/d8360d81-fd0a-414e-ad23-0d52b07a74bb/reports/cd4e7a75-eed4-4499-8247-7544a8cf8a46/9727d21b8f88e2dd3b27?experience=power-bi',
        tenant_id = '2d0ad075-b724-4e09-be9f-55c901df5cd8',
        report_id = 'cd4e7a75-eed4-4499-8247-7544a8cf8a46',
        is_active = true
    where id = target_dashboard_id;
  end if;

  insert into public.dashboard_user_access (dashboard_id, user_id, is_active)
    values (target_dashboard_id, target_user_id, true)
  on conflict (dashboard_id, user_id) do update
  set is_active = excluded.is_active;
end $$;
