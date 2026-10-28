# Hosted backup verification

Checked on 28 October 2026 against the existing Supabase project and `public.user_backups` table after project restoration. No replacement project or database was created.

| Check | Actual result |
|---|---|
| Auth health | HTTP200 |
| Auth settings | HTTP200; Google and email enabled |
| Two confirmed disposable users sign in | Passed using temporary passwords; no emails sent |
| Each user inserts its own backup row | Passed |
| Each user reloads its exact payload | Passed |
| Each user upserts a changed payload on `user_id` and reloads | Passed |
| UserB reads UserA's row | HTTP200, empty result |
| UserB updates UserA's row | HTTP200, zero affected rows; original payload unchanged |
| UserB inserts a row using UserA's ID | HTTP403, PostgreSQL42501 |
| Anonymous read | HTTP401 |
| Anonymous insert | HTTP401 |
| Exact synthetic row cleanup | HTTP204 for each row |
| Synthetic user deletion | HTTP200 for each user |
| Final exact-ID row check | Zero synthetic rows remain |

The disposable users used unique `example.invalid` addresses and were created already confirmed through the admin API, so no signup or recovery email was sent. API keys, passwords and session tokens were held only in subprocess memory; none were added to the app, logs or repository. Real user rows were not inspected, modified or deleted.

The same authenticated persistence and isolation checks passed against Exam Prep King's existing `user_state` table, including an AP SI/NICL version3 payload. Its transient schema-cache error was fixed by reloading the cache after restoration; no initialization migration was applied.

Google authorize requests with the web return `https://saapadu-tracker.vercel.app/` and native return `com.example.saapadu://login-callback/` both produced HTTP302 to `accounts.google.com`. The redirect was not followed. OAuth state was opaque, so this confirms provider initiation without independently proving the final callback allowlist.

This verifies the hosted REST persistence and access-control path with real authenticated sessions. It does not claim a human completed Google OAuth, a native callback returned on a physical phone, or two physical devices were used. The app's device-only diary and JSON backups remain independent recovery paths.
