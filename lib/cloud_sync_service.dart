import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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

  bool ready = false;
  CloudSyncStatus status = CloudSyncStatus.unavailable;
  String? lastError;

  bool get configured =>
      _url.trim().isNotEmpty &&
      _publishableKey.trim().isNotEmpty &&
      _allowedEmail.trim().isNotEmpty;

  SupabaseClient? get _client => configured ? Supabase.instance.client : null;
  User? get user => _client?.auth.currentUser;
  String? get email => user?.email;
  bool get signedIn => user != null;
  bool get authorized =>
      signedIn &&
      email?.trim().toLowerCase() == _allowedEmail.trim().toLowerCase();

  Future<void> initialize() async {
    if (!configured) {
      ready = true;
      status = CloudSyncStatus.unavailable;
      notifyListeners();
      return;
    }
    await Supabase.initialize(
      url: _url,
      publishableKey: _publishableKey,
      authOptions: const FlutterAuthClientOptions(
        authFlowType: AuthFlowType.pkce,
      ),
    );
    _authSubscription = _client!.auth.onAuthStateChange.listen(
      (data) {
        if (data.session == null) {
          status = CloudSyncStatus.signedOut;
        } else if (!authorized) {
          status = CloudSyncStatus.denied;
        } else {
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
    if (!configured) return;
    lastError = null;
    final redirectTo = kIsWeb
        ? Uri.base.resolve('/').toString()
        : 'com.example.saapadu://login-callback/';
    await _client!.auth.signInWithOAuth(
      OAuthProvider.google,
      redirectTo: redirectTo,
      scopes: 'openid email profile',
    );
  }

  Future<void> signOut() async {
    if (!configured) return;
    _uploadTimer?.cancel();
    await _client!.auth.signOut();
    status = CloudSyncStatus.signedOut;
    notifyListeners();
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
