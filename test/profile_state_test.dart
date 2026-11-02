import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:saapadu/app_state.dart';
import 'package:saapadu/cloud_sync_service.dart';
import 'package:saapadu/models.dart';
import 'package:saapadu/screens/profile_screen.dart';
import 'package:saapadu/theme.dart';

const profile = Profile(
    name: 'Test',
    sex: 'Male',
    birthYear: 1990,
    heightCm: 175,
    currentWeightKg: 80,
    goalWeightKg: 75,
    activityLevel: 'Sedentary',
    weeklyGoalKg: .5);
Future<AppState> makeState() async {
  SharedPreferences.setMockInitialValues({});
  final state = AppState(cloud: CloudSyncService());
  await state.initialize();
  await state.saveProfile(profile);
  return state;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
      'profile edits save measurements and a check-in while preserving old diary targets',
      () async {
    final state = await makeState();
    final yesterday = DateTime.now().subtract(const Duration(days: 1));
    state.setSelectedDate(yesterday);
    await state.updateWellness(
        DailyWellness(date: dateKey(yesterday), baseCalorieTarget: 2100));
    final oldTarget = state.wellness[dateKey(yesterday)]!.baseCalorieTarget;
    await state.saveProfile(
        profile.copyWith(heightCm: 180, birthYear: 1985, currentWeightKg: 79));
    expect(state.profile!.heightCm, 180);
    expect(state.weights.last.weightKg, 79);
    expect(state.weights.where((e) => e.date == dateKey(DateTime.now())),
        hasLength(1));
    expect(state.wellness[dateKey(yesterday)]!.baseCalorieTarget, oldTarget);
    final restored = AppState(cloud: CloudSyncService());
    await restored.initialize();
    expect(restored.profile!.birthYear, 1985);
    expect(restored.profile!.heightCm, 180);
    expect(restored.profile!.currentWeightKg, 79);
    state.dispose();
    restored.dispose();
  });
  test(
      'correcting an older dated check-in does not replace the latest current weight',
      () async {
    final state = await makeState();
    await state.logWeight(82,
        date: DateTime.now().subtract(const Duration(days: 14)));
    expect(state.profile!.currentWeightKg, 80);
    await state.logWeight(81.5,
        date: DateTime.now().subtract(const Duration(days: 14)));
    expect(state.weights, hasLength(2));
    expect(state.weights.first.weightKg, 81.5);
    expect(state.profile!.currentWeightKg, 80);
    expect(
        () => state.logWeight(70,
            date: DateTime.now().add(const Duration(days: 1))),
        throwsFormatException);
    state.dispose();
  });
  test('a slow week does not increase the deficit to chase the requested date',
      () async {
    final state = await makeState();
    final requestedDate = DateTime.now().add(const Duration(days: 10));
    await state.saveProfile(
        profile.copyWith(goalDate: requestedDate, weeklyGoalKg: .5));
    final target = state.planRecommendation.recommendedTarget;
    expect(state.planRecommendation.plannedWeeklyRateKg, .5);
    await state.logWeight(81);
    expect(state.profile!.goalDate, requestedDate);
    expect(state.planRecommendation.plannedWeeklyRateKg, .5);
    expect(state.planRecommendation.recommendedTarget,
        greaterThanOrEqualTo(target));
    state.dispose();
  });
  test('weekly check-in reminders use the latest saved measurement date',
      () async {
    final state = await makeState();
    expect(state.weightCheckInDue, false);
    state.weights.clear();
    await state.logWeight(81,
        date: DateTime.now().subtract(const Duration(days: 8)));
    expect(state.weightCheckInDue, true);
    await state.logWeight(80.5);
    expect(state.weightCheckInDue, false);
    state.dispose();
  });
  testWidgets('profile editor exposes editable age, height and current weight',
      (tester) async {
    final state = (await tester.runAsync(makeState))!;
    await tester.pumpWidget(
        MaterialApp(theme: buildTheme(), home: ProfileScreen(state: state)));
    expect(
        find.widgetWithText(TextFormField, 'Current weight'), findsOneWidget);
    expect(find.widgetWithText(TextFormField, 'Height'), findsOneWidget);
    expect(find.widgetWithText(TextFormField, 'Age'), findsOneWidget);
    await tester.enterText(find.widgetWithText(TextFormField, 'Age'), '17');
    await tester.ensureVisible(find.text('Save profile'));
    await tester.tap(find.text('Save profile'));
    await tester.pumpAndSettle();
    expect(find.text('Enter 18.0–120.0 years'), findsOneWidget);
    expect(state.profile!.birthYear, 1990);
    await tester.pumpWidget(const SizedBox());
    state.dispose();
  });
}
