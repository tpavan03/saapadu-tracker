import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:saapadu/app_state.dart';
import 'package:saapadu/cloud_sync_service.dart';
import 'package:saapadu/models.dart';
import 'package:saapadu/screens/more_screen.dart';
import 'package:saapadu/theme.dart';

void main() {
  testWidgets('fasting windows opened from More render inside a page',
      (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.75;
    addTearDown(tester.view.reset);
    final state = (await tester.runAsync(() async {
      SharedPreferences.setMockInitialValues({});
      final s = AppState(cloud: CloudSyncService());
      await s.initialize();
      await s.saveProfile(const Profile(
          name: 'Test',
          sex: 'Male',
          birthYear: 1995,
          heightCm: 175,
          currentWeightKg: 75,
          goalWeightKg: 70,
          activityLevel: 'Sedentary',
          weeklyGoalKg: .5));
      return s;
    }))!;
    await tester.pumpWidget(MaterialApp(
        theme: buildTheme(),
        home: Scaffold(body: MoreScreen(state: state))));
    await tester.tap(find.text('Your fasting windows'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('Choose a window'), findsOneWidget);
    expect(find.byType(ChoiceChip), findsWidgets);
    await tester.pumpWidget(const SizedBox());
    state.dispose();
  });
}
