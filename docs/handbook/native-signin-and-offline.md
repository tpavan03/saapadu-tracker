# Use native sign-in and offline mode

The Android app offers **Continue with Google** and **Continue on this device**. Choose Google when you want the account's existing cloud diary; choose device mode to keep a diary without signing in. The first explicit Google login may open its consent screen. Later app launches restore the saved session instead of automatically starting browser authentication.

If you have an older Saapadu installation, keep it until you have checked the restored history. The new package has its own device storage. A JSON backup is the transfer path for an unsynced diary; simply installing another package does not copy the old application's preferences.

Native session storage and ordinary diary storage are separate. A network outage does not mean the locally saved diary has been erased. Do not clear app data as a first response to a temporary cloud error.

## Implementation references

- [lib/cloud_sync_service.dart](../../lib/cloud_sync_service.dart)
- [lib/main.dart](../../lib/main.dart)
- [docs/native_android.md](../../docs/native_android.md)
