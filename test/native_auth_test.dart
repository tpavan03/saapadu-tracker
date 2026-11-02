import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:saapadu/cloud_sync_service.dart';
import 'package:saapadu/app_state.dart';
import 'package:saapadu/main.dart';
import 'package:saapadu/models.dart';
import 'package:saapadu/screens/home_shell.dart';
import 'package:saapadu/screens/login_screen.dart';
import 'package:saapadu/secure_session_storage.dart';
import 'package:saapadu/theme.dart';

class _CodeCloud extends CloudSyncService {
  int requests = 0;
  int verifications = 0;
  int googleLaunches = 0;
  bool failRequest = false;
  bool failVerification = false;
  bool failGoogle = false;

  @override
  bool get configured => true;

  @override
  bool get authorized => false;

  @override
  Future<void> requestEmailCode(String email) async {
    requests++;
    if (failRequest) throw StateError('Connection unavailable; try again.');
  }

  @override
  Future<void> verifyEmailCode(String email, String code) async {
    verifications++;
    if (failVerification) {
      throw const AuthException('Invalid or expired code.', statusCode: '403');
    }
  }

  @override
  Future<void> signInWithGoogle() async {
    googleLaunches++;
    if (failGoogle) throw StateError('Browser unavailable');
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const key = 'sb-native-auth-fixture-auth-token';

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
  });

  test(
      'native credentials survive a new storage instance and migrate out of plain preferences',
      () async {
    SharedPreferences.setMockInitialValues({key: 'legacy-session-fixture'});
    final first = SecureSessionStorage(storageKey: key);
    await first.initialize();
    expect(await first.accessToken(), 'legacy-session-fixture');
    expect((await SharedPreferences.getInstance()).getString(key), isNull);
    await first.persistSession('refreshed-session-fixture');
    final reopened = SecureSessionStorage(storageKey: key);
    await reopened.initialize();
    expect(await reopened.hasAccessToken(), isTrue);
    expect(await reopened.accessToken(), 'refreshed-session-fixture');
  });

  test('a queued refresh cannot resurrect credentials after sign-out',
      () async {
    final storage = SecureSessionStorage(storageKey: key);
    await storage.initialize();
    final refreshing = storage.persistSession('refresh-fixture');
    final signingOut = storage.removePersistedSession();
    await Future.wait([refreshing, signingOut]);
    final reopened = SecureSessionStorage(storageKey: key);
    await reopened.initialize();
    expect(await reopened.hasAccessToken(), isFalse);
  });

  test(
      'Supabase restores the same native user across process-style client restarts without OAuth',
      () async {
    const userId = '11111111-1111-4111-8111-111111111111';
    final expires =
        DateTime.now().add(const Duration(hours: 2)).millisecondsSinceEpoch ~/
            1000;
    String part(Map<String, Object> value) =>
        base64Url.encode(utf8.encode(jsonEncode(value))).replaceAll('=', '');
    final token = '${part({'alg': 'HS256'})}.${part({
          'sub': userId,
          'exp': expires
        })}.fixture';
    final session = jsonEncode({
      'access_token': token,
      'refresh_token': 'fixture-refresh',
      'token_type': 'bearer',
      'expires_in': 7200,
      'expires_at': expires,
      'user': {
        'id': userId,
        'email': 'native-fixture@example.invalid',
        'aud': 'authenticated',
        'app_metadata': {},
        'user_metadata': {},
        'created_at': '2026-11-02T00:00:00Z'
      },
    });
    FlutterSecureStorage.setMockInitialValues({key: session});
    for (var restart = 0; restart < 2; restart++) {
      final storage = SecureSessionStorage(storageKey: key);
      final sdk = await Supabase.initialize(
        url: 'https://native-auth-fixture.supabase.invalid',
        publishableKey: 'public-test-fixture',
        debug: false,
        authOptions: FlutterAuthClientOptions(
            localStorage: storage,
            autoRefreshToken: false,
            detectSessionInUri: false),
      );
      try {
        expect(sdk.client.auth.currentUser?.id, userId);
        expect(sdk.client.auth.currentSession?.refreshToken, 'fixture-refresh');
        await storage.accessToken();
        await Future<void>.delayed(Duration.zero);
      } finally {
        await sdk.dispose();
      }
    }
  });

  testWidgets(
      'native sign-in stays inside the app, preserves errors and can resend without an old code',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final cloud = _CodeCloud()..failRequest = true;
    await tester.pumpWidget(MaterialApp(
        theme: buildTheme(),
        home: LoginScreen(
            cloud: cloud,
            emailOtpEnabled: true,
            resendCooldown: Duration.zero)));
    expect(cloud.requests, 0);
    expect(cloud.googleLaunches, 0);
    await tester.enterText(
        find.byType(TextFormField).first, 'native-fixture@example.invalid');
    await tester.ensureVisible(find.text('Email me a code'));
    await tester.tap(find.text('Email me a code'));
    await tester.pumpAndSettle();
    expect(find.text('Connection unavailable; try again.'), findsOneWidget);
    expect(find.text('native-fixture@example.invalid'), findsOneWidget);
    cloud.failRequest = false;
    await tester.tap(find.text('Email me a code'));
    await tester.pump();
    await tester.pump();
    expect(find.text('Email code'), findsOneWidget);
    await tester.ensureVisible(find.text('Resend code'));
    await tester.tap(find.text('Resend code'));
    await tester.pump();
    await tester.pump();
    expect(cloud.requests, 3);
    expect(cloud.verifications, 0);
    cloud.failVerification = true;
    await tester.enterText(find.byType(TextFormField).last, '123456');
    await tester.ensureVisible(find.text('Verify & sign in'));
    await tester.tap(find.text('Verify & sign in'));
    await tester.pump();
    await tester.pump();
    expect(
        find.textContaining('That code could not be verified'), findsOneWidget);
    expect(find.text('123456'), findsOneWidget);
    expect(cloud.googleLaunches, 0);
    await tester.pumpWidget(const SizedBox.shrink());
    cloud.dispose();
  });

  testWidgets(
      'native Google sign-in opens only after a tap and failed sign-in leaves the local choice available',
      (tester) async {
    final cloud = _CodeCloud()..failGoogle = true;
    var localChoices = 0;
    await tester.pumpWidget(MaterialApp(
        theme: buildTheme(),
        home: LoginScreen(
            cloud: cloud, onContinueLocally: () => localChoices++)));
    expect(find.text('Email me a code'), findsNothing);
    expect(cloud.googleLaunches, 0);
    await tester.ensureVisible(find.text('Continue with Google'));
    await tester.tap(find.text('Continue with Google'));
    await tester.pumpAndSettle();
    expect(cloud.googleLaunches, 1);
    expect(
        find.textContaining('Google sign-in could not open'), findsOneWidget);
    await tester.ensureVisible(find.text('Continue on this device'));
    await tester.tap(find.text('Continue on this device'));
    await tester.pumpAndSettle();
    expect(localChoices, 1);
    expect(cloud.googleLaunches, 1);
    await tester.pumpWidget(const SizedBox.shrink());
    cloud.dispose();
  });

  testWidgets(
      'a returning native diary opens offline without another login, but explicit sign-out shows a choice',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    const profile = Profile(
        name: 'Native fixture',
        sex: 'Male',
        birthYear: 1990,
        heightCm: 175,
        currentWeightKg: 80,
        goalWeightKg: 75,
        activityLevel: 'Sedentary',
        weeklyGoalKg: .5);
    SharedPreferences.setMockInitialValues(
        {'profile': jsonEncode(profile.toJson())});
    final cloud = _CodeCloud();
    final state = AppState(cloud: cloud);
    await state.initialize();
    await tester.pumpWidget(SaapaduApp(state: state));
    await tester.pumpAndSettle();
    expect(find.byType(HomeShell), findsOneWidget);
    expect(find.byType(LoginScreen), findsNothing);
    expect(cloud.requests, 0);
    expect(cloud.googleLaunches, 0);
    cloud.userRequestedSignOut = true;
    state.notifyListeners();
    await tester.pumpAndSettle();
    expect(find.byType(LoginScreen), findsOneWidget);
    await tester.ensureVisible(find.text('Continue on this device'));
    await tester.tap(find.text('Continue on this device'));
    await tester.pumpAndSettle();
    expect(find.byType(HomeShell), findsOneWidget);
    expect(state.profile?.name, 'Native fixture');
    await tester.pumpWidget(const SizedBox.shrink());
    state.dispose();
    cloud.dispose();
  });
}
