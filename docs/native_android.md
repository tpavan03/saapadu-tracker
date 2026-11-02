# Saapadu for Android

Saapadu **2.0.0+4** is a compiled Flutter Android application. Its screens, navigation, diary and fasting timer run on the device. It shares the existing Supabase cloud-history backend with the website.

| Item | Value |
| --- | --- |
| Release package | `in.tpavan.saapadu` |
| Minimum Android version | Android 7.0, API 24 |
| Release | `2.0.0+4` |
| Authentication callback | `in.tpavan.saapadu://login-callback/` |
| Debug package | `in.tpavan.saapadu.debug` |
| Interface | Midnight ink, soft mint and saffron; original steaming-bowl launcher |

## Install and bring your diary

Download **[Saapadu-2.0.0.apk](https://github.com/tpavan03/saapadu-tracker/releases/download/v2.0.0/Saapadu-2.0.0.apk)** from the GitHub release. Android may ask you to allow installation from the browser or file manager used to open the APK.

The package identity changed from the earlier `com.example.saapadu` build. Both apps can remain installed together; Android does not transfer the old package's local storage automatically.

1. Keep the old app installed and open **More → Data & backup → Copy backup** there. Save the complete JSON text somewhere private.
2. Install the new app. If the old diary was synced, sign in using the **same Google account** to restore that account's cloud history.
3. For a device-only diary, choose **Continue on this device**, then use **More → Data & backup → Restore** and paste the saved JSON.
4. Check your meals, measurements and history before removing an old installation or clearing its data.

Manual JSON backup remains useful even when cloud sync is enabled. Restoring a backup is an explicit recovery operation; keep copies of both diaries before replacing an existing local history.

## Sign-in and local storage

Choose **Continue on this device** for an account-free, local diary. Meal logging and saved personal data remain available offline. Cloud sync needs a connection.

The first explicit **Google sign-in** may open the system browser for Google consent and then return to the app through `in.tpavan.saapadu://login-callback/`. Normal app launches restore the saved Supabase session, so opening the app does not start a new browser login each time. Signing out or a revoked session can require another sign-in.

Native session credentials are persisted through `flutter_secure_storage`, using Android's protected storage and Keystore. Diary data is saved locally, and a signed-in diary syncs to the existing account's cloud backup. When first connecting a device diary to an account that already has history, Saapadu restores the cloud diary and retains the offline draft separately. **More → Data & backup → Copy saved offline diary** retrieves that draft. A failed first connection does not upload the draft over an unverified existing cloud history.

**Email-code sign-in is disabled in this release.** The current Supabase project has no custom SMTP provider. Provider settings alone do not establish reliable email-code delivery, so the interface does not offer it as a working login method. Google and device-only use are available without adding an email service.

The existing personal Supabase project already allows the native callback above. A fork using another project must add that exact callback to **Authentication → URL Configuration** and configure Google separately. The website retains its HTTPS callback.

## Profile and weekly check-ins

- Open **More**, find your profile, and tap **Edit** to change name, age, height, current weight, activity and the body reference used for calorie estimates. Saving a changed current weight also records today's weigh-in.
- Open **Progress → Log weight** for a dated reading. **View and edit weight check-ins** lets you correct past entries. The Today page shows an in-app weekly check-in prompt; this is not a scheduled Android notification.
- **Goal plan** controls goal weight, pace, custom calorie target and your requested date. Your requested date stays distinct from the changing **estimated goal date**.

The forecast uses readings from the most recent 28 days. At least three readings spanning 14 days are needed for an observed trend; with less history, the app uses a calorie-plan estimate. The latest dated weight updates current measurements, and older diary entries retain their saved targets. A plateau or trend away from the goal can leave the estimated date unavailable rather than inventing a completion date.

Recommendations respect calorie safety floors and the actual achievable deficit. A missed date does not trigger automatic calorie cuts. Estimates are a planning aid rather than a medical prediction.

## Build from source

Use the Flutter SDK version required by the project, Android SDK tools and JDK 17. From the repository root:

```bash
flutter pub get
flutter analyze
flutter test
```

The public Supabase client configuration can be stored in the ignored file `.secrets/native-build.json`:

```json
{
  "SUPABASE_URL": "https://PROJECT_REF.supabase.co",
  "SUPABASE_PUBLISHABLE_KEY": "YOUR_PUBLIC_PUBLISHABLE_KEY"
}
```

These values are included in the client binary. Never add a Supabase secret or `service_role` key. The file does not need Google client secrets, a Gemini key or any unrelated service credential.

The personal release uses an owner-controlled RSA-3072 signing key at `.secrets/android/saapadu-release.jks`. Gradle reads its configuration from the ignored `android/key.properties` file:

```properties
storeFile=../../.secrets/android/saapadu-release.jks
storePassword=YOUR_PRIVATE_STORE_PASSWORD
keyAlias=YOUR_SIGNING_ALIAS
keyPassword=YOUR_PRIVATE_KEY_PASSWORD
```

Keep the keystore, alias and passwords backed up privately. The same signing identity is required to install future updates over this package. Neither the keystore nor `key.properties` belongs in Git. A fork should create its own signing identity and Android package name.

Build the signed APK:

```bash
flutter build apk --release --dart-define-from-file=.secrets/native-build.json
```

The output is `build/app/outputs/flutter-apk/app-release.apk`. The `v2.0.0` release distributes it as `Saapadu-2.0.0.apk`.

## Native verification

Unit and widget checks cover profile edits, forecast rules, calorie guardrails, persistence, account restoration and responsive layouts. Run them using the commands above. Actual Google consent and deep-link return need a configured Google account on a device; a passing widget test does not establish that provider flow.

The isolated integration test checks Android secure storage, profile edits, dated weigh-ins, forecasts and restoration of synthetic local data:

```bash
flutter test integration_test/native_smoke_test.dart \
  -d DEVICE_ID --dart-define=SAAPADU_NATIVE_SMOKE=true
```

Use a debug emulator or test device. Debug builds have the separate `in.tpavan.saapadu.debug` package and data store. This test uses a device-only cloud stub, makes no real provider request and does not verify production Google login. Do not change it to use a real diary or account.

## Web and backend continuity

Pushing to `main` continues to deploy the existing website through its linked Vercel project. Android APKs must be rebuilt and distributed separately; a website deployment cannot update an installed native binary.

Both clients use the existing Supabase `user_backups` storage and account-isolation policies. This native release adds no SQL migration and does not replace the backend. See [cloud setup](cloud_setup.md), [historical backend verification](backend-verification.md), and the [README](../README.md).
