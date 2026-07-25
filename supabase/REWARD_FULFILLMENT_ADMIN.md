# Reward Fulfillment Admin

The live database migration is:

`supabase/migrations/202607250003_reward_fulfillment_admin.sql`

It provides:

- `reward_catalog`: server-owned reward goals and item details.
- `rewards`: earned reward ownership, synchronized from check-in streaks.
- `reward_requests`: item, request time, recipient, phone, address, status,
  tracking reference, and admin notes.
- `reward_admins`: the fixed Supabase Auth users allowed to open the admin
  fulfillment queue.

## Assign The Fixed Admin

The administrator must already have a Supabase Auth account. In the Supabase
Dashboard SQL Editor, run this once with the real admin email:

```sql
select public.set_reward_admin_by_email(
  'admin@example.com',
  'Primary reward administrator',
  true
);
```

Sign out and sign back in as that account. Open **Rewards**, then use the admin
icon in the page title to open **Reward Requests**.

To remove access:

```sql
select public.set_reward_admin_by_email(
  'admin@example.com',
  'Primary reward administrator',
  false
);
```

Normal app users cannot call this setup function. It is restricted to the
Supabase `service_role` and the Dashboard SQL Editor.

## Fulfillment Flow

1. Supabase calculates the signed-in user's current check-in streak.
2. Eligible rewards are recorded by `sync_current_user_rewards()`.
3. The user confirms a recipient, phone number, and delivery address.
4. `request_current_user_reward()` verifies eligibility and prevents duplicate
   requests.
5. An approved administrator reviews the queue and changes the status through
   Pending, Preparing, Shipped, and Delivered, or marks it Rejected.
6. Users see the latest request status on their Rewards page.
