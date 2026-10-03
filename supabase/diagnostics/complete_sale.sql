-- Run in the Supabase SQL Editor and share the result.
-- Read-only: returns schema definitions, not marketplace records.
with relevant_tables as (
  select c.oid, n.nspname, c.relname, c.relrowsecurity
  from pg_class c
  join pg_namespace n on n.oid = c.relnamespace
  where n.nspname = 'public'
    and c.relkind in ('r', 'p')
    and c.relname in (
      'products', 'conversations', 'messages', 'transactions',
      'profiles', 'notifications', 'seller_ratings'
    )
), relevant_functions as (
  select p.oid, n.nspname, p.proname
  from pg_proc p
  join pg_namespace n on n.oid = p.pronamespace
  where p.prokind = 'f'
    and (
      (n.nspname = 'public' and (
        p.proname ilike '%complete%sale%'
        or p.proname in (
          'reserve_product', 'cancel_product_reservation',
          'sale_buyer_candidates', 'current_user_is_staff'
        )
      ))
      or p.oid in (
        select t.tgfoid from pg_trigger t
        where t.tgrelid in (select oid from relevant_tables)
          and not t.tgisinternal
      )
    )
)
select jsonb_pretty(jsonb_build_object(
  'functions', coalesce((
    select jsonb_agg(jsonb_build_object(
      'schema', f.nspname,
      'name', f.proname,
      'definition', pg_get_functiondef(f.oid),
      'authenticated_can_execute',
        has_function_privilege('authenticated', f.oid, 'EXECUTE')
    ) order by f.nspname, f.proname)
    from relevant_functions f
  ), '[]'::jsonb),
  'tables', coalesce((
    select jsonb_agg(jsonb_build_object(
      'name', r.relname,
      'rls_enabled', r.relrowsecurity,
      'columns', (
        select jsonb_agg(jsonb_build_object(
          'name', a.attname,
          'type', format_type(a.atttypid, a.atttypmod),
          'not_null', a.attnotnull,
          'default', pg_get_expr(d.adbin, d.adrelid)
        ) order by a.attnum)
        from pg_attribute a
        left join pg_attrdef d on d.adrelid = a.attrelid
          and d.adnum = a.attnum
        where a.attrelid = r.oid and a.attnum > 0 and not a.attisdropped
      ),
      'constraints', (
        select jsonb_agg(pg_get_constraintdef(c.oid))
        from pg_constraint c where c.conrelid = r.oid
      ),
      'triggers', (
        select jsonb_agg(pg_get_triggerdef(t.oid))
        from pg_trigger t where t.tgrelid = r.oid and not t.tgisinternal
      ),
      'policies', (
        select jsonb_agg(to_jsonb(p)) from pg_policies p
        where p.schemaname = r.nspname and p.tablename = r.relname
      )
    ) order by r.relname)
    from relevant_tables r
  ), '[]'::jsonb)
)) as sale_diagnostics;
