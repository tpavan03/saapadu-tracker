import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Native credentials live in the Android Keystore/iOS Keychain. The old
/// SharedPreferences token is migrated once, only after the secure write succeeds.
class SecureSessionStorage extends LocalStorage {
  SecureSessionStorage({
    required this.storageKey,
    FlutterSecureStorage? storage,
  }) : _storage = storage ??
            const FlutterSecureStorage(
              aOptions: AndroidOptions(storageNamespace: 'saapadu_auth_v1'),
              iOptions: IOSOptions(
                accessibility: KeychainAccessibility.first_unlock_this_device,
              ),
            );

  final String storageKey;
  final FlutterSecureStorage _storage;
  Future<void> _pendingWrite = Future<void>.value();
  SharedPreferences? _legacy;

  @override
  Future<void> initialize() async {
    _legacy = await SharedPreferences.getInstance();
    if (await _storage.read(key: storageKey) != null) return;
    final oldSession = _legacy!.getString(storageKey);
    if (oldSession == null) return;
    await _storage.write(key: storageKey, value: oldSession);
    await _legacy!.remove(storageKey);
  }

  @override
  Future<bool> hasAccessToken() async => await accessToken() != null;

  @override
  Future<String?> accessToken() async {
    await _pendingWrite;
    return _storage.read(key: storageKey);
  }

  Future<void> _write(Future<void> Function() operation) {
    final next =
        _pendingWrite.catchError((Object _) {}).then((_) => operation());
    _pendingWrite = next;
    return next;
  }

  @override
  Future<void> persistSession(String persistSessionString) => _write(() async {
        await _storage.write(key: storageKey, value: persistSessionString);
        await _legacy?.remove(storageKey);
      });

  @override
  Future<void> removePersistedSession() => _write(() async {
        await _storage.delete(key: storageKey);
        await _legacy?.remove(storageKey);
      });
}
