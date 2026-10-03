-- Run this entire file in Supabase SQL Editor as the database owner.
-- Seller ratings are visible on profiles to signed-in marketplace users.
-- Submissions continue through the existing verified-purchase RPC.
begin;

alter table public.seller_ratings enable row level security;
grant select on table public.seller_ratings to authenticated;

drop policy if exists seller_ratings_read_authenticated
  on public.seller_ratings;
create policy seller_ratings_read_authenticated
  on public.seller_ratings
  for select
  to authenticated
  using ((select auth.uid()) is not null);

-- Safe to rerun when the table already belongs to the publication.
do $$
begin
  if not exists (
    select 1 from pg_publication
    where pubname = 'supabase_realtime' and puballtables
  ) and not exists (
    select 1 from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public'
      and tablename = 'seller_ratings'
  ) then
    alter publication supabase_realtime add table public.seller_ratings;
  end if;
end;
$$;

notify pgrst, 'reload schema';
commit;
