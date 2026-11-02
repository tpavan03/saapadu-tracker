# Android 2.0 verification

Verified 2 November 2026 using Flutter 3.47.3, Dart 3.13.3, JDK 17 and an Android 15 / API 35 x86_64 emulator.

## Release artifact

- `flutter build apk --release --dart-define-from-file=.secrets/native-build.json`: exit 0.
- Package `in.tpavan.saapadu`, version `2.0.0`, version code `4`, minimum API 24, target API 36.
- Universal APK includes `arm64-v8a`, `armeabi-v7a` and `x86_64`.
- `apksigner verify --verbose --print-certs`: exit 0, APK Signature Scheme v2, owner RSA-3072 signing certificate.
- Certificate SHA-256: `3ec60a531fe7fc9df398c689d979040bab6de70079386b9444fc0ade860ac220`.
- APK SHA-256: `aad8e8603cce8b5379743c4602500bdc56f6b0d58f7ae23cec35a58b6e1dd7bf`.
- Installed the signed release through `adb install`: success. Its screens render in the Flutter activity; the home screen contains no browser wrapper.

The owner signing key and passwords remain in ignored local files. They are not part of the source repository or release assets.

## Application checks

- `flutter analyze`: exit 0, no issues.
- `flutter test`: exit 0, **59 checks passed**.
- `flutter test integration_test/native_smoke_test.dart -d emulator-5554 --dart-define=SAAPADU_NATIVE_SMOKE=true`: exit 0, **1 native integration test passed**. This used Android secure storage, profile form edits, actual device preferences, dated weigh-ins, restart restoration of the local state and a corrected same-day reading in the isolated debug package.
- Premium design audit, strict mode: exit 0, zero findings.
- Widget checks include all six main destinations at phone widths and enlarged text, profile edits, dated check-ins, same-day corrections, calorie-floor forecasts and preservation of historical targets.
- Account tests cover first-link cloud history preservation, retention of offline drafts, failed lookup followed by edits/restart, account switching and delayed responses from a previous account.

## Personal backend and installed release

Used two disposable confirmed accounts in the existing personal Supabase project, without sending email:

- Authenticated backup write and exact read-back succeeded.
- A second account could neither read nor update the first account's backup.
- Anonymous access was denied.
- Delivered a real disposable Supabase session through the release application's Android callback. The native app restored the synthetic profile and weight history.
- Force-stopped and reopened the release **twice**. Each launch opened the native diary, and **More → Sign out** remained available, confirming an authenticated session rather than only a cached profile. No automatic browser launch occurred.
- Both disposable accounts and their backup were removed after verification; the credential fixture was deleted.

The [home screenshot](images/android-home.png) is from that installed release and contains synthetic data.

This verifies session persistence and the application callback. It does **not** verify an interactive Google account-consent flow on a user's phone. Google sign-in still uses the configured provider and may open its secure browser screen when explicitly requested. Email OTP is disabled; no custom SMTP provider or paid Supabase change was introduced.

## Reproduction

Follow [native_android.md](native_android.md) for the build and isolated native-device test. Run Flutter analyze, tests and release builds sequentially in one checkout: concurrent Flutter commands can regenerate the Android plugin registry with incompatible debug/release plugin selections.
