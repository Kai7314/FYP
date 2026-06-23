# EthernaCare Data and Cache Strategy

Supabase is the source of truth. Local storage is an acceleration and
offline-reading layer, never the authority for authentication or safety writes.

| Data | Local behavior | Server/API behavior |
| --- | --- | --- |
| Auth session | Managed by `supabase_flutter` secure session persistence | Supabase Auth validates credentials and issues JWT sessions |
| User profile | Cached inside the dashboard snapshot | Refreshed from `public.users` |
| Check-in history/streak | Cached after a successful dashboard refresh | Check-in creation and duplicate-day validation remain on Supabase |
| Reward catalog | Cached with `catalog_version` | Downloaded again only when the newest server version increases |
| Earned rewards | Cached for immediate/offline display | Reconciled with `public.rewards`; server rows are authoritative |
| Weather | Cached for 30 minutes | Refreshed from Open-Meteo using device coordinates |
| Device location | Last-known location is used first | A fresh GPS position is requested when no cached position exists |
| Emergency alerts | Not queued locally | Always written directly to Supabase because this is safety-critical |

When adding a reward in `public.reward_catalog`, assign a `catalog_version`
higher than the existing maximum. The app compares this value with its local
version and refreshes the full catalog only when necessary.
