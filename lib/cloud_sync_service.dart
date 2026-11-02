import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'secure_session_storage.dart';

class CloudBackup {
  const CloudBackup({
    required this.payload,
    required this.revision,
    required this.updatedAt,
  });

  final Map<String, dynamic> payload;
  final int revision;
  final DateTime updatedAt;
}

enum CloudSyncStatus {
  unavailable,
  signedOut,
  syncing,
  synced,
  offline,
  denied
}

class CloudSyncService extends ChangeNotifier {
  static const _url = String.fromEnvironment('SUPABASE_URL');
  static const _publishableKey =
      String.fromEnvironment('SUPABASE_PUBLISHABLE_KEY');
  static const _allowedEmail = String.fromEnvironment('ALLOWED_EMAIL');

  StreamSubscription<AuthState>? _authSubscription;
  Timer? _uploadTimer;
  Future<void> Function()? _pendingUpload;
  bool _initialized = false;
  SecureSessionStorage? _secureStorage;
  bool userRequestedSignOut = false;
  static const _signOutIntentKey = 'saapadu_explicit_signout';

  bool ready = false;
  CloudSyncStatus status = CloudSyncStatus.unavailable;
  String? lastError;

  bool get configured =>
      _url.trim().isNotEmpty && _publishableKey.trim().isNotEmpty;

  SupabaseClient? get _client =>
      configured && _initialized ? Supabase.instance.client : null;
  User? get user => _client?.auth.currentUser;
  String? get email => user?.email;
  bool get signedIn => user != null;
  bool get authorized =>
      signedIn &&
      (_allowedEmail.trim().isEmpty ||
          email?.trim().toLowerCase() == _allowedEmail.trim().toLowerCase());

  Future<void> initialize() async {
    if (_initialized) return;
    final preferences = await SharedPreferences.getInstance();
    userRequestedSignOut = preferences.getBool(_signOutIntentKey) ?? false;
    if (!configured) {
      ready = true;
      status = CloudSyncStatus.unavailable;
      notifyListeners();
      return;
    }
    try {
      _secureStorage = kIsWeb
          ? null
          : SecureSessionStorage(
              storageKey:
                  'sb-${Uri.parse(_url).host.split('.').first}-auth-token',
            );
      await Supabase.initialize(
        url: _url,
        publishableKey: _publishableKey,
        debug: false,
        authOptions: FlutterAuthClientOptions(
          authFlowType: AuthFlowType.pkce,
          autoRefreshToken: true,
          persistSession: true,
          localStorage: _secureStorage,
          detectSessionInUriPredicate: kIsWeb
              ? null
              : (uri) =>
                  uri.scheme == 'in.tpavan.saapadu' &&
                  uri.host == 'login-callback',
        ),
      );
      _initialized = true;
    } catch (_) {
      // A failed cloud/credential initialization must not discard the diary or
      // stop a native device from opening its locally saved records.
      lastError =
          'Cloud sign-in could not initialize. Device logging is available.';
      status = CloudSyncStatus.offline;
      ready = true;
      notifyListeners();
      return;
    }
    _authSubscription = _client!.auth.onAuthStateChange.listen(
      (data) {
        if (data.session == null) {
          status = CloudSyncStatus.signedOut;
        } else if (!authorized) {
          status = CloudSyncStatus.denied;
        } else {
          userRequestedSignOut = false;
          unawaited(preferences.remove(_signOutIntentKey));
          status = CloudSyncStatus.syncing;
        }
        ready = true;
        notifyListeners();
      },
      onError: (Object error, StackTrace stackTrace) {
        lastError = error.toString();
        status = CloudSyncStatus.offline;
        ready = true;
        notifyListeners();
      },
    );
    ready = true;
    status = !signedIn
        ? CloudSyncStatus.signedOut
        : authorized
            ? CloudSyncStatus.syncing
            : CloudSyncStatus.denied;
    notifyListeners();
  }

  Future<void> signInWithGoogle() async {
    if (_client == null) {
      throw StateError(
          'Cloud sign-in is unavailable. Try again when connected.');
    }
    lastError = null;
    final redirectTo = kIsWeb
        ? Uri.base.resolve('/').toString()
        : 'in.tpavan.saapadu://login-callback/';
    await _client!.auth.signInWithOAuth(
      OAuthProvider.google,
      redirectTo: redirectTo,
      scopes: 'openid email profile',
    );
  }

  String _validatedEmail(String value) {
    final normalized = value.trim().toLowerCase();
    if (!RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(normalized)) {
      throw const FormatException('Enter a valid email address.');
    }
    if (_allowedEmail.trim().isNotEmpty &&
        normalized != _allowedEmail.trim().toLowerCase()) {
      throw StateError(
          'Use the email address configured for your Saapadu diary.');
    }
    return normalized;
  }

  Future<void> requestEmailCode(String email) async {
    final normalized = _validatedEmail(email);
    if (_client == null) {
      throw StateError(
          'Cloud sign-in is unavailable. Try again when connected.');
    }
    lastError = null;
    await _client!.auth
        .signInWithOtp(email: normalized, shouldCreateUser: true);
  }

  Future<void> verifyEmailCode(String email, String code) async {
    final normalized = _validatedEmail(email);
    if (!RegExp(r'^\d{6,8}$').hasMatch(code.trim())) {
      throw const FormatException('Enter the numeric code from your email.');
    }
    if (_client == null) {
      throw StateError(
          'Cloud sign-in is unavailable. Try again when connected.');
    }
    final result = await _client!.auth.verifyOTP(
      email: normalized,
      token: code.trim(),
      type: OtpType.email,
    );
    if (result.session == null) {
      throw StateError(
          'The code did not complete sign-in. Request a new code.');
    }
  }

  Future<void> signOut() async {
    if (!configured) return;
    userRequestedSignOut = true;
    await (await SharedPreferences.getInstance())
        .setBool(_signOutIntentKey, true);
    _uploadTimer?.cancel();
    _pendingUpload = null;
    try {
      await _client?.auth.signOut();
    } catch (_) {
      lastError =
          'Signed out on this device. Remote sign-out could not be confirmed while offline.';
    } finally {
      await _secureStorage?.removePersistedSession();
      status = CloudSyncStatus.signedOut;
      notifyListeners();
    }
  }

  Future<CloudBackup?> fetchBackup() async {
    if (!authorized) return null;
    try {
      status = CloudSyncStatus.syncing;
      notifyListeners();
      final row = await _client!
          .from('user_backups')
          .select('payload, revision, updated_at')
          .eq('user_id', user!.id)
          .maybeSingle();
      status = CloudSyncStatus.synced;
      lastError = null;
      notifyListeners();
      if (row == null) return null;
      return CloudBackup(
        payload: Map<String, dynamic>.from(row['payload'] as Map),
        revision: (row['revision'] as num?)?.toInt() ?? 1,
        updatedAt: DateTime.parse(row['updated_at'] as String).toUtc(),
      );
    } catch (error) {
      lastError = error.toString();
      status = CloudSyncStatus.offline;
      notifyListeners();
      rethrow;
    }
  }

  Future<void> uploadBackup(
    Map<String, dynamic> payload, {
    int revision = 1,
  }) async {
    if (!authorized) return;
    try {
      status = CloudSyncStatus.syncing;
      notifyListeners();
      await _client!.from('user_backups').upsert({
        'user_id': user!.id,
        'payload': payload,
        'schema_version': 1,
        'revision': revision,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      }, onConflict: 'user_id');
      status = CloudSyncStatus.synced;
      lastError = null;
      notifyListeners();
    } catch (error) {
      lastError = error.toString();
      status = CloudSyncStatus.offline;
      notifyListeners();
      rethrow;
    }
  }

  void scheduleUpload(Future<void> Function() upload) {
    if (!authorized) return;
    _pendingUpload = upload;
    _uploadTimer?.cancel();
    _uploadTimer = Timer(const Duration(seconds: 2), () async {
      final action = _pendingUpload;
      _pendingUpload = null;
      if (action == null) return;
      try {
        await action();
      } catch (_) {
        // The local copy remains authoritative until a later retry succeeds.
      }
    });
  }

  @override
  void dispose() {
    _uploadTimer?.cancel();
    _authSubscription?.cancel();
    super.dispose();
  }
}
