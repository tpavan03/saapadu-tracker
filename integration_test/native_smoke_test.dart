import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:saapadu/app_state.dart';
import 'package:saapadu/cloud_sync_service.dart';
import 'package:saapadu/main.dart';
import 'package:saapadu/models.dart';
import 'package:saapadu/screens/home_shell.dart';
import 'package:saapadu/screens/profile_screen.dart';
import 'package:saapadu/screens/weight_check_in_screen.dart';
import 'package:saapadu/secure_session_storage.dart';
import 'package:saapadu/weight_trend.dart';

class _DeviceOnlyCloud extends CloudSyncService {
  @override
  bool get configured => false;
}

Finder field(String label) => find.widgetWithText(TextFormField, label);

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  // Android debug builds use a separate .debug application ID and data store.
  // No real sign-in, email, provider request or production data is used here.
  testWidgets(
      'native secure storage, profile editing and weekly forecast persist',
      (tester) async {
    expect(kIsWeb, isFalse);
    const enabled = bool.fromEnvironment('SAAPADU_NATIVE_SMOKE');
    expect(enabled, isTrue,
        reason: 'Enable this isolated debug-device trial explicitly.');
    final first = SecureSessionStorage(storageKey: 'native-smoke-isolated');
    await first.initialize();
    await first.persistSession('{"fixture":"native-only"}');
    final second = SecureSessionStorage(storageKey: 'native-smoke-isolated');
    await second.initialize();
    expect(await second.accessToken(), '{"fixture":"native-only"}');
    await second.removePersistedSession();
    expect(await first.accessToken(), isNull);

    final state = AppState(cloud: _DeviceOnlyCloud());
    await state.initialize();
    await state.saveProfile(Profile(
        name: 'Native trial',
        sex: 'Male',
        birthYear: DateTime.now().year - 35,
        heightCm: 175,
        currentWeightKg: 90,
        goalWeightKg: 85,
        activityLevel: 'Sedentary',
        weeklyGoalKg: .5));
    await tester.pumpWidget(SaapaduApp(state: state));
    await tester.pumpAndSettle();
    expect(find.byType(HomeShell), findsOneWidget);
    final home = tester.element(find.byType(HomeShell));
    Navigator.of(home).push(
        MaterialPageRoute<void>(builder: (_) => ProfileScreen(state: state)));
    await tester.pumpAndSettle();
    await tester.enterText(field('Height'), '180');
    await tester.enterText(field('Age'), '38');
    await tester.enterText(field('Current weight'), '89');
    await tester.ensureVisible(find.text('Save profile'));
    await tester.tap(find.text('Save profile'));
    await tester.pumpAndSettle();
    expect(state.profile!.heightCm, 180);
    expect(state.profile!.birthYear, DateTime.now().year - 38);
    expect(state.profile!.currentWeightKg, 89);

    final now = DateTime.now();
    await state.logWeight(90, date: now.subtract(const Duration(days: 14)));
    await state.logWeight(89.5, date: now.subtract(const Duration(days: 7)));
    expect(state.weightForecast.basis, WeightForecastBasis.checkInTrend);
    expect(state.weightForecast.weeklyChangeKg, closeTo(-.5, .001));
    final restored = AppState(cloud: _DeviceOnlyCloud());
    await restored.initialize();
    expect(restored.profile!.heightCm, 180);
    expect(restored.profile!.currentWeightKg, 89);
    expect(restored.weightForecast.basis, WeightForecastBasis.checkInTrend);

    Navigator.of(tester.element(find.byType(HomeShell))).push(
        MaterialPageRoute<void>(
            builder: (_) => WeightCheckInScreen(state: state)));
    await tester.pumpAndSettle();
    await tester.enterText(field('Weight'), '88.9');
    await tester.ensureVisible(find.text('Save check-in'));
    await tester.tap(find.text('Save check-in'));
    await tester.pumpAndSettle();
    expect(state.profile!.currentWeightKg, 88.9);
    expect(state.weights.where((entry) => entry.date == dateKey(now)),
        hasLength(1));
    expect(tester.takeException(), isNull);
    // Only synthetic measurements/check outcomes are printed, never credentials.
    debugPrint(jsonEncode({
      'native': true,
      'androidSecureStorage': true,
      'editableProfile': true,
      'weeklyForecast': true,
      'devicePersistence': true,
      'checkInCorrections': true
    }));
    restored.dispose();
  });
}
