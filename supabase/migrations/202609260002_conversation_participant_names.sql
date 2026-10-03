-- Run this entire file in Supabase SQL Editor as the database owner.
-- A profile's SELECT policy can hide names in conversation joins. This
-- function returns only names, and only for the caller's own conversations.
-- Existing profile policies and email access are left unchanged.
begin;

create or replace function public.get_conversation_participant_names(
  conversation_ids uuid[]
)
returns table (
  conversation_id uuid,
  buyer_name text,
  seller_name text
)
language sql
stable
security definer
set search_path = ''
as $$
  select c.id,
    case when position('@' in buyer.name) = 0 then buyer.name::text end,
    case when position('@' in seller.name) = 0 then seller.name::text end
  from public.conversations c
  left join public.profiles buyer on buyer.id = c.buyer_id
  left join public.profiles seller on seller.id = c.seller_id
  where c.id = any(conversation_ids)
    and (select auth.uid()) is not null
    and ((select auth.uid()) = c.buyer_id
      or (select auth.uid()) = c.seller_id);
$$;

revoke all on function public.get_conversation_participant_names(uuid[])
  from public, anon;
grant execute on function public.get_conversation_participant_names(uuid[])
  to authenticated;

notify pgrst, 'reload schema';
commit;
