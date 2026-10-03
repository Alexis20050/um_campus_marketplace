-- Run in Supabase SQL Editor and share the result.
-- Read-only: returns schema/function definitions, not user records.
select jsonb_pretty(jsonb_build_object(
  'functions', (
    select coalesce(jsonb_agg(jsonb_build_object(
      'name', p.proname,
      'definition', pg_get_functiondef(p.oid)
    ) order by p.proname), '[]'::jsonb)
    from pg_proc p
    join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public' and p.prokind = 'f'
      and p.proname in (
        'admin_user_detail', 'admin_user_listings', 'admin_users',
        'admin_dashboard_stats', 'admin_listing_detail', 'current_user_is_staff',
        'admin_reports_for_user'
      )
  ),
  'columns', (
    select coalesce(jsonb_agg(jsonb_build_object(
      'table', table_name,
      'column', column_name,
      'type', data_type
    ) order by table_name, ordinal_position), '[]'::jsonb)
    from information_schema.columns
    where table_schema = 'public'
      and table_name in ('profiles', 'products', 'transactions', 'reports')
  )
)) as admin_activity_diagnostics;
