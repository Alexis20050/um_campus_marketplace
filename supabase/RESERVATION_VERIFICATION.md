# Seller reservation verification

## Current implementation

The existing seller menu already contained Reserve Item and Cancel Reservation. They were only exposed through an unlabeled overflow menu. The menu used `isReserved` rather than the existing eligibility getters, so it also offered reservation on hidden products. Public cards and product details did not display reservation status.

The fix exposes listing actions directly, uses model eligibility, and retains reserved listings in the Active filter. Successful mutations perform one seller-listing read while retaining the existing realtime subscription. Cancellation clears the UI from the returned server data rather than guessing a successful database update.

Existing calls are retained:

- `sale_buyer_candidates(p_product_id)` through `RatingProvider.fetchBuyersForProduct`, including its existing check for an actual message sent by that buyer.
- `reserve_product(p_conversation_id)` through `ProductProvider.reserveProduct`.
- `cancel_product_reservation(p_product_id)` through `ProductProvider.cancelReservation`.
- `complete_sale(p_conversation_id)` through `RatingProvider.completeSale`.

There are no new notification writes, reservation RPCs, or database migrations in this fix. MessageProvider, its injectable client, notifications, and admin operations are unchanged.

## Backend evidence and remaining verification

`migrations/202609300001_marketplace_safety.sql` contains an UPDATE trigger that rejects new reservations on sold, archived, or hidden products; validates the listing, seller, buyer, conversation, and buyer message; and requires cancellation before changing the reserved buyer. Its sale wrapper locks the product and rejects a different reserved buyer or conversation before calling the original sale implementation.

The repository does **not** contain the bodies of `reserve_product`, `cancel_product_reservation`, the original `complete_sale`, product RLS policies, or reservation notification triggers. The existing safety document says the migration was not deployed from this workspace. Therefore seller authorization in the reservation/cancellation RPCs, live deployment of the guards, clearing all three reservation fields, transaction creation, and notification side effects cannot be established from the local SQL alone. UI checks are not a substitute for these deployed checks.

Use this read-only query in the project's SQL editor to retrieve the relevant installed functions:

```sql
select n.nspname as schema_name, p.proname,
       pg_get_function_identity_arguments(p.oid) as arguments,
       pg_get_functiondef(p.oid) as definition
from pg_proc p
join pg_namespace n on n.oid = p.pronamespace
where n.nspname = 'public'
  and p.proname in (
    'reserve_product', 'cancel_product_reservation',
    'complete_sale', 'complete_sale_marketplace_original',
    'sale_buyer_candidates', 'guard_marketplace_reservation'
  );
```

Confirm with seller, buyer A, and buyer B test sessions:

1. A conversation without a buyer message is ineligible. After A sends a message, the seller can reserve for A and A receives the existing notification.
2. Non-sellers cannot reserve or cancel another seller's listing, including direct RPC requests. Sold, archived, hidden, and arbitrary-conversation reservations fail.
3. Cancellation clears `reserved_by`, `reserved_conversation_id`, and `reserved_at`, returns the item to active status, and produces only the existing cancellation notification.
4. A direct sale call using B's conversation while reserved for A fails. A's conversation creates exactly one verified transaction and marks the listing sold, with the existing rating/notification effects.
5. Reserve/cancel updates My Listings immediately. Reserved products remain in Explore, and an open product detail follows the existing ProductProvider realtime updates.

Do not recreate or replace the deployed reservation functions before inspecting their definitions.
