-- Additive guards; existing RPCs, RLS policies and notification triggers remain.
begin;

create or replace function public.messaging_is_blocked(p_user_id uuid)
returns boolean language plpgsql security definer set search_path = '' as $$
begin
  if auth.uid() is null then
    raise exception 'Sign in to check messaging access';
  end if;
  return exists (select 1 from public.user_blocks
    where (blocker_id = auth.uid() and blocked_id = p_user_id)
       or (blocker_id = p_user_id and blocked_id = auth.uid()));
end;
$$;
revoke all on function public.messaging_is_blocked(uuid) from public, anon;
grant execute on function public.messaging_is_blocked(uuid) to authenticated;

-- Serialize block changes and sends for the same pair. No history is deleted.
create or replace function public.guard_marketplace_messaging()
returns trigger language plpgsql security definer set search_path = '' as $$
declare a uuid; b uuid;
begin
  if tg_table_name = 'user_blocks' then
    if tg_op = 'DELETE' then a := old.blocker_id; b := old.blocked_id;
    else a := new.blocker_id; b := new.blocked_id; end if;
  elsif tg_table_name = 'conversations' then
    a := new.buyer_id; b := new.seller_id;
  else
    select buyer_id, seller_id into a, b from public.conversations
      where id = new.conversation_id;
    if a is null or b is null then raise exception 'Conversation is unavailable'; end if;
    if new.sender_id not in (a, b) then raise exception 'Invalid message sender'; end if;
  end if;
  perform pg_advisory_xact_lock(hashtextextended(least(a::text,b::text) || ':' || greatest(a::text,b::text), 0));
  if tg_table_name <> 'user_blocks' and exists (
    select 1 from public.user_blocks where
      (blocker_id = a and blocked_id = b) or (blocker_id = b and blocked_id = a)
  ) then raise exception 'Messaging is unavailable because a user has blocked the other.'; end if;
  if tg_op = 'DELETE' then return old; end if;
  return new;
end;
$$;
revoke all on function public.guard_marketplace_messaging() from public, anon, authenticated;
create trigger marketplace_block_pair_guard before insert or update or delete on public.user_blocks
  for each row execute function public.guard_marketplace_messaging();
create trigger marketplace_conversation_guard before insert or update of buyer_id, seller_id on public.conversations
  for each row execute function public.guard_marketplace_messaging();
create trigger marketplace_message_guard before insert or update of conversation_id, sender_id, content on public.messages
  for each row execute function public.guard_marketplace_messaging();

-- Validate reservations against an actual buyer message, including direct writes.
create or replace function public.guard_marketplace_reservation()
returns trigger language plpgsql security definer set search_path = '' as $$
begin
  if new.reserved_by is not null and
    (new.reserved_by is distinct from old.reserved_by or
     new.reserved_conversation_id is distinct from old.reserved_conversation_id) then
    if old.reserved_by is not null then
      raise exception 'Cancel the existing reservation before choosing another buyer';
    end if;
    if new.is_sold or new.is_archived or new.moderation_status = 'hidden' then
      raise exception 'This listing is no longer available for reservation';
    end if;
    if not exists (
      select 1 from public.conversations c where c.id = new.reserved_conversation_id
        and c.product_id = new.id and c.seller_id = new.seller_id
        and c.buyer_id = new.reserved_by and c.buyer_id <> c.seller_id
        and exists (select 1 from public.messages m where m.conversation_id = c.id and m.sender_id = c.buyer_id)
    ) then raise exception 'Choose a buyer who has messaged about this listing'; end if;
  end if;
  return new;
end;
$$;
revoke all on function public.guard_marketplace_reservation() from public, anon, authenticated;
create trigger marketplace_reservation_guard before update of reserved_by, reserved_conversation_id on public.products
  for each row execute function public.guard_marketplace_reservation();

-- Run before the existing complete_sale body, so its update order cannot clear
-- the reservation before validation. Preserve its return type and all side effects.
alter function public.complete_sale(uuid) rename to complete_sale_marketplace_original;
revoke all on function public.complete_sale_marketplace_original(uuid) from public, anon, authenticated;
do $$
declare result_type text;
begin
  select pg_get_function_result('public.complete_sale_marketplace_original(uuid)'::regprocedure) into result_type;
  execute format($wrapper$
    create function public.complete_sale(p_conversation_id uuid)
    returns %s language plpgsql security definer set search_path = '' as $body$
    declare c public.conversations%%rowtype; p public.products%%rowtype;
    begin
      select * into c from public.conversations where id = p_conversation_id;
      if auth.uid() is null or c.seller_id is distinct from auth.uid() then
        raise exception 'Only the seller can complete this sale';
      end if;
      select * into p from public.products where id = c.product_id for update;
      if p.reserved_by is not null and
        (p.reserved_by is distinct from c.buyer_id or
         (p.reserved_conversation_id is not null and p.reserved_conversation_id is distinct from c.id)) then
        raise exception 'Cancel the reservation before choosing another buyer';
      end if;
      return public.complete_sale_marketplace_original(p_conversation_id);
    end;
    $body$;
  $wrapper$, result_type);
end;
$$;
revoke all on function public.complete_sale(uuid) from public, anon;
grant execute on function public.complete_sale(uuid) to authenticated;
commit;
