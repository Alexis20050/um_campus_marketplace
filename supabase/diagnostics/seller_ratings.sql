-- Run in the Supabase SQL Editor as the database owner.
-- Read-only: returns configuration and counts, without review text or user IDs.
select jsonb_pretty(jsonb_build_object(
  'saved_ratings', (select count(*) from public.seller_ratings),
  'ratings_with_missing_seller', (
    select count(*) from public.seller_ratings where seller_id is null
  ),
  'ratings_with_wrong_seller', (
    select count(*)
    from public.seller_ratings r
    join public.transactions t on t.id = r.transaction_id
    where r.seller_id is distinct from t.seller_id
  ),
  'ratings_without_transaction', (
    select count(*)
    from public.seller_ratings r
    left join public.transactions t on t.id = r.transaction_id
    where t.id is null
  ),
  'rls_enabled', (
    select relrowsecurity from pg_class
    where oid = 'public.seller_ratings'::regclass
  ),
  'authenticated_can_select',
    has_table_privilege('authenticated', 'public.seller_ratings', 'SELECT'),
  'policies', (
    select coalesce(jsonb_agg(to_jsonb(p)), '[]'::jsonb)
    from pg_policies p
    where schemaname = 'public' and tablename = 'seller_ratings'
  ),
  'realtime_enabled', exists (
    select 1 from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public' and tablename = 'seller_ratings'
  ),
  'submission_functions', (
    select coalesce(jsonb_agg(pg_get_functiondef(p.oid)), '[]'::jsonb)
    from pg_proc p
    join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public' and p.proname = 'submit_seller_rating'
      and p.prokind = 'f'
  )
)) as seller_rating_diagnostics;
