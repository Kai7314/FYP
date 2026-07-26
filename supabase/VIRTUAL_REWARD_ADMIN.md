# Virtual Reward Admin

EthernaCare rewards are virtual badges and vouchers. Users earn active rewards
automatically from their check-in streak. Voucher codes are generated uniquely
for each user by Supabase. The separate administrator interface manages the
virtual reward catalog.

## Authorize One Admin Account

The administrator must first have a confirmed Supabase Auth account. In
Supabase Dashboard > SQL Editor, replace the example with that account's email:

```sql
select public.set_reward_admin_by_email(
  'admin@example.com',
  'Virtual reward administrator',
  true
);
```

The email must exactly match an existing account. The normal app has no link to
the administrator interface.

To remove access:

```sql
select public.set_reward_admin_by_email(
  'admin@example.com',
  'Virtual reward administrator',
  false
);
```

## Open The Separate Admin Interface

For the Windows administrator build:

```powershell
flutter run -d windows --dart-define=ADMIN_MODE=true
```

For a local web build, start Flutter web and open:

```text
http://localhost:<port>/#/admin/rewards
```

A production web host can expose `/admin/rewards` when it rewrites that path to
the Flutter application.

The admin signs in with the allowlisted email and password. Supabase checks the
active `reward_admins` row before returning catalog data or accepting changes.

## Access Rules

- Normal users can read active rewards and earned badges.
- Only an active allowlisted admin can list inactive rewards.
- Only protected admin RPCs can create, edit, activate, or deactivate rewards.
- Admins can permanently delete selected rewards only before any user earns
  them. Earned rewards must be deactivated to preserve user history.
- The client cannot directly insert, update, or delete catalog rows.
- Rewards are virtual; there is no delivery request or fulfillment queue.
