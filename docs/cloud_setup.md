# Optional Google login and cloud history

The tracker works locally without an account. Cloud sync adds recovery across browsers and devices while keeping the local copy available offline.

## One-time setup

1. Create a free Supabase project.
2. Run `supabase/migrations/202609170001_cloud_backup.sql` in its SQL editor.
3. In Google Auth Platform, create a Web OAuth client. Add `https://saapadu-tracker.vercel.app` as an authorized JavaScript origin and the Supabase callback shown in the provider screen (`https://PROJECT_REF.supabase.co/auth/v1/callback`) as the authorized redirect URI.
4. Enable Google under Supabase **Authentication → Providers** and paste the Google client ID and secret there.
5. In Supabase **Authentication → URL Configuration**, add these redirect URLs:
   - `https://saapadu-tracker.vercel.app/` for the website.
   - `com.example.saapadu://login-callback/` for the Android APK.
6. Set the Supabase Site URL to `https://saapadu-tracker.vercel.app/`.
7. If the project already used the original single-email policy, run `supabase/migrations/202609180001_multi_user_backup_policies.sql` once in SQL Editor. Each authenticated account is then isolated by its Supabase user ID.
8. Build Flutter with the public project values:

```bash
flutter build web --release \
  --dart-define=SUPABASE_URL=https://PROJECT_REF.supabase.co \
  --dart-define=SUPABASE_PUBLISHABLE_KEY=YOUR_PUBLISHABLE_KEY
```

The publishable key is designed for browser use. Never put a Supabase secret key or `service_role` key in this application.

## Storage behavior

- The browser copy is written first, so logging still works through a network interruption.
- Signed-in changes are uploaded after a short debounce.
- On first login, an existing cloud backup is restored; when none exists, the current browser history becomes the first cloud backup.
- Each signed-in account has its own cloud row and a new account starts onboarding separately. Switching accounts on the same browser clears the previous account's local diary before restoring the new account.
- Manual JSON copy/restore remains available as a second recovery path.
