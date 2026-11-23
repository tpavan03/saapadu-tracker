import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:saapadu/app_state.dart';
import 'package:saapadu/cloud_sync_service.dart';
import 'package:saapadu/models.dart';
import 'package:saapadu/screens/combos_screen.dart';
import 'package:saapadu/screens/diary_screen.dart';
import 'package:saapadu/screens/food_search_screen.dart';
import 'package:saapadu/screens/progress_screen.dart';
import 'package:saapadu/screens/reminder_settings_screen.dart';
import 'package:saapadu/screens/supplements_screen.dart';
import 'package:saapadu/screens/today_screen.dart';
import 'package:saapadu/screens/weight_check_in_screen.dart';
import 'package:saapadu/theme.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    for (final font in [
      ('DM Sans', 'assets/fonts/DMSans.ttf'),
      ('Sora', 'assets/fonts/Sora.ttf'),
      ('MaterialIcons', 'fonts/MaterialIcons-Regular.otf'),
    ]) {
      final loader = FontLoader(font.$1)..addFont(rootBundle.load(font.$2));
      await loader.load();
    }
  });

  Future<AppState> seeded() async {
    SharedPreferences.setMockInitialValues({});
    final state = AppState(cloud: CloudSyncService());
    await state.initialize();
    await state.saveProfile(const Profile(
        name: 'Pavan',
        sex: 'Male',
        birthYear: 1995,
        heightCm: 175,
        currentWeightKg: 75,
        goalWeightKg: 70,
        activityLevel: 'Sedentary',
        weeklyGoalKg: .5));
    final dosa = state.foods.first;
    await state.addFood(dosa, 1, 'Breakfast');
    await state.addFood(dosa, 1.5, 'Lunch');
    await state.saveCombo(MealCombo(
        id: 'c',
        name: 'My usual breakfast with a long descriptive name',
        meal: 'Breakfast',
        items: [ComboItem(food: dosa, servings: 2)]));
    await state.saveSupplement(const Supplement(
        id: 's',
        name: 'Whey protein isolate',
        dose: '1 scoop',
        slot: 'After workout',
        calories: 120,
        proteinG: 24,
        reminderEnabled: true));
    await state.toggleSupplement('s');
    await state.saveBodyComposition(dateKey(DateTime.now()),
        {'waistCm': 84, 'bodyFatPct': 24.5, 'muscleKg': 33});
    return state;
  }

  for (final scale in [1.0, 2.0]) {
    testWidgets('v2.1 screens fit 390 px at text $scale', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final state = (await tester.runAsync(seeded))!;
      final screens = <String, Widget>{
        'today': Scaffold(
            body: TodayScreen(
                state: state,
                onDiary: () {},
                onActivity: () {},
                onFasting: () {})),
        'diary': Scaffold(body: DiaryScreen(state: state)),
        'progress': Scaffold(body: ProgressScreen(state: state)),
        'search': FoodSearchScreen(state: state, initialMeal: 'Breakfast'),
        'supplements': SupplementsScreen(state: state),
        'reminders': ReminderSettingsScreen(state: state),
        'combos': CombosScreen(state: state),
        'checkin': WeightCheckInScreen(state: state),
      };
      for (final entry in screens.entries) {
        await tester.pumpWidget(MaterialApp(
          theme: buildTheme(),
          builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: TextScaler.linear(scale)),
              child: child!),
          home: entry.value,
        ));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull,
            reason: '${entry.key} at text $scale');
      }
      // Open the add-food sheet with the continuous serving control.
      await tester.pumpWidget(MaterialApp(
          theme: buildTheme(),
          builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: TextScaler.linear(scale)),
              child: child!),
          home: FoodSearchScreen(state: state, initialMeal: 'Breakfast')));
      await tester.pumpAndSettle();
      await tester.tap(find.text(state.foods.first.name).first);
      await tester.pumpAndSettle();
      expect(find.byType(Slider), findsOneWidget);
      expect(tester.takeException(), isNull, reason: 'serving sheet');
      await tester.pumpWidget(const SizedBox());
      state.dispose();
    });
  }
}
