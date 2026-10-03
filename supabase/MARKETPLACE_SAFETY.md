# Marketplace safety and reservations

## Deployment

Apply `migrations/202609300001_marketplace_safety.sql` once, using the Supabase SQL editor or your normal migration runner, before releasing this Flutter build. This migration has not been run against the hosted database from this workspace. No database CLI or live database connection was available.

The script runs in one transaction and expects the existing tables and RPCs referenced by the local app. It adds:

- `messaging_is_blocked(p_user_id)`: authenticated callers can check their own pair in either direction, even when RLS hides incoming block rows. The Flutter provider fails closed if the RPC fails or returns an unexpected value.
- Triggers on blocks, conversations and messages: block changes and message writes share a pair lock; a block in either direction rejects new conversations and messages. Participant/content changes are also checked. Read receipts and existing message history are preserved.
- A reservation trigger: the selected conversation must belong to this product, seller and buyer, and contain a message sent by that buyer. Sold, archived and hidden products cannot receive a new reservation. An existing reservation must be cancelled before changing buyers.
- A wrapper around `complete_sale(uuid)`: locks the product and checks the reserved buyer/conversation before invoking the original implementation. The original is renamed to `complete_sale_marketplace_original`, its existing return type is retained, and direct execution by public/anonymous/authenticated roles is revoked. Existing transaction, rating and notification behavior remains in the original function.

The migration retains existing RLS and report/admin/reservation RPCs. It does not delete rows, grant staff roles, change auth keys, or add device push notifications. When updating `complete_sale` in later migrations, retain these checks and the original-function permission restriction.

## Hosted verification

Use two student test accounts and an active staff test account after applying the migration:

1. Report another user's listing and profile. Confirm both appear in `admin_reports('pending')`. Reporting alone must leave the listing visible.
2. Create a conversation and exchange messages. Block in either direction. Test new conversations and sends as both users, including direct REST writes. Both must fail; history and read receipts should remain available under the existing read policies. Unblock and confirm sends resume. If both users blocked each other, both blocks must be removed.
3. Reserve a listing for a buyer who sent a message. A conversation with no buyer message must be rejected. Confirm the reservation notification and RESERVED chip. Cancel and confirm the listing becomes active.
4. Reserve for buyer A and call `complete_sale` with buyer B's conversation directly: it must fail. Complete with A: verify one transaction, sold state, existing notification and rating eligibility. Existing manually sold listings must remain ineligible for a new rating without a transaction.
5. Tap product, conversation and transaction notifications, including hidden/deleted targets. Confirm read state, navigation and graceful unavailable-content handling.
6. Confirm staff can dismiss, hide, suspend and restore through existing RPCs. Student callers must be denied by the deployed backend. Verify suspended staff cannot use admin RPCs.

The local repository does not contain definitions for the existing report/admin/rating RPCs or RLS policies. Their deployed authorization and side effects require these hosted checks. Global hidden-listing/suspended-user directories were not added; restoration remains available through resolved reports.

Check the dedicated account without changing its permissions:

```sql
select id, email, role, account_status
from public.profiles
where lower(email) = 'alexissecuya@gmail.com';
```

Admin routing requires both an active admin/moderator profile and a successful `current_user_is_staff` result. The email alone grants no access. The actual hosted account was not inspected in this workspace.

## Files changed in this task

- `lib/models/product.dart`: restore the parsing and immutable-image behavior required by existing tests.
- `lib/providers/message_provider.dart`: server block checks before conversation lookup/creation and message insertion; existing injection, unread and send-status behavior retained.
- `lib/providers/rating_provider.dart`: buyer candidates must have sent a message.
- `lib/providers/admin_provider.dart`: explicit active staff profile check; failed access checks propagate to AuthGate's retry screen.
- `lib/utils/complete_sale_flow.dart`: shared reserve/buyer selection and fresh reservation constraints.
- `lib/screens/my_listings_screen.dart`: reserve/cancel actions, confirmation, progress, reload, and RESERVED status.
- `lib/screens/product_detail_screen.dart`: reusable listing report sheet and submission feedback.
- `lib/screens/notifications_screen.dart`: read-and-open navigation, progress, and unavailable-target handling.
- `lib/screens/transaction_history_screen.dart`: open a specified transaction's details.
- `lib/screens/admin_dashboard_screen.dart`: moderation confirmations, busy controls, and restore error handling, including restoring a user suspended through a listing report.
- `test/message_blocking_test.dart`: blocked conversation/send, unblock, and fail-closed regression tests using a local fake HTTP backend.
- This document and the SQL migration above.

Existing profile report/block/unblock controls, admin shell, OAuth/deep links, session refresh and Supabase constants are preserved. Notifications remain in-app realtime notifications; delivery while the app is closed is not implemented.
