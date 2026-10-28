# Saapadu 1.2

- New mint, emerald and saffron visual system, bundled DM Sans/Sora, consistent
  rounded iconography, richer sign-in and responsive navigation.
- Fasting has its own destination: 12:12,14:10,16:8 and custom windows,
  persistent absolute timestamps, a real-time dial and saved session history.
- Consent/eligibility checks, neutral early endings and meal-during-fast prompts.
- Quick water additions, repeated previous meals, clearable food search,
  duplicate-save prevention and named food-removal confirmations.
- Existing nutrition catalog, custom foods, calorie/macro calculations, goals,
  movement, sleep, weight records, backups and Supabase storage remain intact.

Production uses the existing Vercel project and existing Supabase URL/key
recovered from its currently published client build. Public client values stay
in ignored `.env.build.local`; never commit tokens or secret keys.

Build with `flutter build web --release --dart-define-from-file=.env.build.local`.
The static build directory is `build/web`. APK command is identical with `apk`
in place of `web`, subject to the installed Android toolchain.

The existing Supabase project was paused during initial inspection and the
owner resumed it on 28 October 2026. The original project's auth health and
settings now return HTTP 200, Google OAuth is enabled, and anonymous access to
`user_backups` is denied with HTTP 401 / PostgreSQL 42501. No authenticated test
session was available, so a signed-in backup read/write roundtrip has not been
verified. The existing SQL migration defines per-user read/insert/update
policies and this release preserves that same table and payload format.

Future Vercel Git builds use `scripts/vercel-build.sh`, pinned to official Flutter
3.47.3. The existing project's public SUPABASE_URL and SUPABASE_PUBLISHABLE_KEY
environment values supply compile-time configuration; no secret/service-role
key is used. GitHub app repository access must also be enabled in Vercel for
automatic Git deployments. Manual CLI deployment remains available.
