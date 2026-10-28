import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:saapadu/app_state.dart';
import 'package:saapadu/cloud_sync_service.dart';
import 'package:saapadu/models.dart';
import 'package:saapadu/screens/fasting_screen.dart';
import 'package:saapadu/screens/home_shell.dart';
import 'package:saapadu/theme.dart';

const profile = Profile(
    name: 'Test',
    sex: 'Male',
    birthYear: 1990,
    heightCm: 175,
    currentWeightKg: 75,
    goalWeightKg: 70,
    activityLevel: 'Sedentary',
    weeklyGoalKg: .5);

Future<AppState> stateForTest() async {
  SharedPreferences.setMockInitialValues({});
  final cloud = CloudSyncService();
  await cloud.initialize();
  final state = AppState(cloud: cloud);
  await state.initialize();
  await state.saveProfile(profile);
  return state;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('legacy fasting records preserve the chosen window and absolute start',
      () {
    final old = FastingState.fromJson(
        {'startedAt': '2026-10-28T06:00:00Z', 'targetHours': 16});
    expect(old.targetHours, 16);
    expect(old.history, isEmpty);
    expect(old.elapsedAt(DateTime.parse('2026-10-28T09:00:00Z')).inHours, 3);
    expect(old.targetAt, DateTime.parse('2026-10-28T22:00:00Z'));
    expect(FastingState.fromJson({}).targetHours, 12);
  });

  test('start/end are idempotent and early endings stay in persisted history',
      () async {
    final state = await stateForTest();
    final start = DateTime.utc(2026, 10, 28, 6);
    await state.startFast(12, now: start);
    await state.startFast(16, now: start.add(const Duration(hours: 1)));
    expect(state.fasting.startedAt, start);
    expect(state.fasting.targetHours, 12);
    await state.stopFast(now: start.add(const Duration(hours: 6)));
    await state.stopFast(now: start.add(const Duration(hours: 8)));
    expect(state.fasting.history, hasLength(1));
    expect(state.fasting.history.first.duration.inHours, 6);
    expect(state.fasting.history.first.targetReached, false);
    final reload = AppState(cloud: CloudSyncService());
    await reload.initialize();
    expect(reload.fasting.history.first.duration.inHours, 6);
    final backup = state.exportBackup();
    await state.importBackup(backup);
    expect(state.fasting.history, hasLength(1));
    state.dispose();
    reload.dispose();
  });

  test('fasting never changes calorie goals or silently discards food',
      () async {
    final state = await stateForTest();
    final target = state.baseCalorieTarget;
    await state.startFast(14);
    await state.addFood(state.foods.first, 1, 'Breakfast');
    expect(state.baseCalorieTarget, target);
    expect(state.caloriesEaten, state.foods.first.calories);
    expect(state.fasting.isActive, true);
    await state.setFastingTarget(16);
    expect(state.fasting.targetHours, 14);
    state.dispose();
  });

  test('invalid windows and excluded profiles cannot start timers', () async {
    final state = await stateForTest();
    await expectLater(state.startFast(30), throwsFormatException);
    await state
        .saveProfile(profile.copyWith(birthYear: DateTime.now().year - 16));
    await expectLater(state.startFast(12), throwsFormatException);
    expect(state.fasting.isActive, false);
    state.dispose();
  });

  testWidgets('fasting consent, active timer and saved ending work together',
      (tester) async {
    tester.view.resetPhysicalSize();
    tester.view.physicalSize = const Size(1200, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final state = (await tester.runAsync(stateForTest))!;
    await tester.pumpWidget(AnimatedBuilder(
        animation: state,
        builder: (context, _) => MaterialApp(
            theme: buildTheme(),
            home: Scaffold(body: FastingScreen(state: state)))));
    await tester.tap(find.text('Start fasting timer'));
    await tester.pumpAndSettle();
    expect(find.text('Before you start'), findsOneWidget);
    expect(state.fasting.isActive, false);
    await tester.tap(find.byType(CheckboxListTile));
    await tester.pump();
    await tester.tap(find.text('Start my timer'));
    await tester.pumpAndSettle();
    expect(state.fasting.isActive, true);
    await tester.tap(find.text('End & save window'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('End & save'));
    await tester.pumpAndSettle();
    expect(state.fasting.isActive, false);
    expect(state.fasting.history, hasLength(1));
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    state.dispose();
  });

  testWidgets('mobile navigation and the diary stay within a narrow viewport',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final state = (await tester.runAsync(stateForTest))!;
    await tester.pumpWidget(
        MaterialApp(theme: buildTheme(), home: HomeShell(state: state)));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('Fasting').last);
    await tester.pumpAndSettle();
    expect(find.text('Make space for your routine.'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    state.dispose();
  });
}
