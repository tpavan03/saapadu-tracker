import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:saapadu/app_state.dart';
import 'package:saapadu/cloud_sync_service.dart';
import 'package:saapadu/health_import.dart';
import 'package:saapadu/insights.dart';
import 'package:saapadu/models.dart';
import 'package:saapadu/reminders.dart';

const profile = Profile(
    name: 'Partner',
    sex: 'Female',
    birthYear: 1994,
    heightCm: 160,
    currentWeightKg: 62,
    goalWeightKg: 57,
    activityLevel: 'Sedentary',
    weeklyGoalKg: .25);

String daysAgo(int n, [DateTime? from]) {
  final t = from ?? DateTime.now();
  return dateKey(DateTime(t.year, t.month, t.day - n));
}

const dosa = {
  'id': 'plain-dosa',
  'name': 'Plain dosa',
  'aliases': ['dosai'],
  'category': 'Breakfast',
  'servingLabel': '1 dosa',
  'servingGrams': 80,
  'calories': 168,
  'proteinG': 3.9,
  'carbsG': 29,
  'fatG': 3.7,
  'fiberG': 1.2,
  'sourceKey': 'IFCT_2017',
  'isCustom': false,
};

/// Exactly the shape the v2.0 app wrote (no v2.1 keys anywhere).
Map<String, dynamic> oldBackup() => {
      'format': 'saapadu-backup-v1',
      'exportedAt': '2026-11-20T10:00:00.000Z',
      'lastChangedAt': '2026-11-20T10:00:00.000Z',
      'profile': profile.toJson(),
      'foodLogs': [
        {
          'id': '1',
          'date': daysAgo(3),
          'meal': 'Breakfast',
          'food': dosa,
          'servings': 2
        },
        {
          'id': '2',
          'date': daysAgo(2),
          'meal': 'Dinner',
          'food': dosa,
          'servings': 1.5
        },
      ],
      'workouts': [
        {
          'id': 'w1',
          'date': daysAgo(3),
          'typeId': 'walking_brisk',
          'typeName': 'Walking — brisk',
          'durationMinutes': 30,
          'met': 4.8,
          'caloriesBurned': 118
        }
      ],
      'customFoods': [],
      'weights': [
        {'date': daysAgo(10), 'weightKg': 63.0},
        {'date': daysAgo(3), 'weightKg': 62.0},
      ],
      'wellness': [
        {
          'date': daysAgo(3),
          'waterMl': 0,
          'sleepHours': 6.5,
          'steps': 4200,
          'exerciseCalories': 0,
          'note': '',
          'baseCalorieTarget': 1650,
          'proteinTarget': 99.2,
          'carbsTarget': 160.0,
          'fatTarget': 51.3,
          'fiberTarget': 25.0
        },
        {
          'date': daysAgo(2),
          'waterMl': 1750,
          'sleepHours': 0.0,
          'steps': 0,
          'exerciseCalories': 220,
          'note': 'ok',
          'baseCalorieTarget': 1650,
          'proteinTarget': 99.2,
          'carbsTarget': 160.0,
          'fatTarget': 51.3,
          'fiberTarget': 25.0
        },
      ],
      'fasting': {'startedAt': null, 'targetHours': 14, 'history': []},
    };

/// The v2.0 app's DailyWellness.fromJson, verbatim, to prove an older app
/// can read what v2.1 writes.
Map<String, Object?> oldAppReadsWellness(Map<String, dynamic> j) => {
      'date': j['date'] as String,
      'waterMl': j['waterMl'] as int? ?? 0,
      'sleepHours': (j['sleepHours'] as num?)?.toDouble() ?? 0,
      'steps': j['steps'] as int? ?? 0,
      'exerciseCalories': j['exerciseCalories'] as int? ?? 0,
      'note': j['note'] as String? ?? '',
      'baseCalorieTarget': (j['baseCalorieTarget'] as num?)?.round(),
    };

Future<AppState> makeState({String? waterStart}) async {
  SharedPreferences.setMockInitialValues({
    if (waterStart != null) 'water_default_start': waterStart,
  });
  final state = AppState(cloud: CloudSyncService());
  await state.initialize();
  return state;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('backward compatibility', () {
    test('an old v2.0 backup loads with identical history', () async {
      final state = await makeState();
      final original = oldBackup();
      await state.importBackup(jsonEncode(original));

      for (final n in [3, 2]) {
        final key = daysAgo(n);
        final day = state.wellness[key]!;
        final stored = (original['wellness'] as List)
            .cast<Map<String, dynamic>>()
            .firstWhere((w) => w['date'] == key);
        // Re-exported JSON for a historical day is byte-for-byte the same.
        expect(jsonEncode(day.toJson()), jsonEncode(stored));
        // Water before the v2.1 start shows exactly what was stored.
        expect(state.waterFor(key), stored['waterMl']);
        expect(day.effectiveSteps, stored['steps']);
        expect(day.effectiveSleepHours, stored['sleepHours']);
      }
      expect(state.waterFor(daysAgo(5)), 0, reason: 'no record stays 0');
      expect(state.caloriesFor(daysAgo(3)), closeTo(336, .01));
      expect(state.caloriesFor(daysAgo(2)), closeTo(252, .01));
      // Activity credit uses the same max-of-sources rule as before.
      state.setSelectedDate(DateTime.parse(daysAgo(2)));
      expect(state.exerciseCalories, 110);
      expect(state.baseCalorieTarget, 1650);
      expect(state.weights.map((w) => w.toJson()).toList(),
          original['weights']);
      expect(state.workouts.single.toJson(),
          (original['workouts'] as List).single);
      expect(state.loggingStreakDays, 0);
      state.dispose();
    });

    test('v2.1 output stays readable by the older app', () async {
      final state = await makeState();
      await state.saveProfile(profile);
      await state.setWater(2500);
      await state.applyHealthImport(HealthImport(
          fromKey: daysAgo(0),
          toKey: daysAgo(0),
          days: [
            HealthDay(
                date: daysAgo(0), steps: 9000, activeCalories: 300, sleepHours: 7)
          ]));
      final exported = jsonDecode(state.exportBackup()) as Map<String, dynamic>;
      expect(exported['format'], 'saapadu-backup-v1');
      for (final w in (exported['wellness'] as List)) {
        final read = oldAppReadsWellness(Map<String, dynamic>.from(w as Map));
        expect(read['waterMl'], isA<int>());
      }
      for (final w in exported['weights'] as List) {
        expect((w as Map)['weightKg'], isA<num>());
      }
      state.dispose();
    });

    test('a backup without v2.1 keys keeps local combos and supplements',
        () async {
      final state = await makeState();
      await state.saveProfile(profile);
      await state.saveCombo(MealCombo(
          id: 'c1',
          name: 'My usual breakfast',
          meal: 'Breakfast',
          items: [ComboItem(food: FoodItem.fromJson(dosa), servings: 2)]));
      await state.saveSupplement(
          const Supplement(id: 's1', name: 'Vitamin D', dose: '1 tablet'));
      await state.importBackup(jsonEncode(oldBackup()));
      expect(state.combos.single.name, 'My usual breakfast');
      expect(state.supplements.single.name, 'Vitamin D');
      final restored = AppState(cloud: CloudSyncService());
      await restored.initialize();
      expect(restored.combos.single.items.single.servings, 2);
      state.dispose();
      restored.dispose();
    });
  });

  group('water default', () {
    test('days before the start keep stored values; later days count 4 L',
        () async {
      final start = daysAgo(1);
      final state = await makeState(waterStart: start);
      await state.importBackup(jsonEncode(oldBackup()));
      expect(state.waterDefaultStart, start);
      expect(state.waterFor(daysAgo(3)), 0);
      expect(state.waterFor(daysAgo(2)), 1750);
      expect(state.waterFor(daysAgo(1)), 4000);
      expect(state.waterFor(daysAgo(0)), 4000);
      state.setSelectedDate(DateTime.now());
      expect(state.selectedWaterIsDefault, isTrue);
      await state.adjustWater(-250);
      expect(state.selectedWater, 3750);
      expect(state.selectedWaterIsDefault, isFalse);
      await state.setWater(0);
      expect(state.selectedWater, 0, reason: 'an explicit 0 is respected');
      await state.resetWater();
      expect(state.selectedWater, 4000);
      // Snapshotting targets on a day (logging food) does not set water.
      state.setSelectedDate(DateTime.parse(daysAgo(1)));
      await state.addFood(FoodItem.fromJson(dosa), 1, 'Lunch');
      expect(state.waterFor(daysAgo(1)), 4000);
      // History before the start is still untouched.
      expect(state.waterFor(daysAgo(3)), 0);
      expect(state.waterFor(daysAgo(2)), 1750);
      state.dispose();
    });

    test('an old-app value on/after the start day still wins', () {
      final key = daysAgo(0);
      expect(
          WaterDefaults.effective(
              DailyWellness(date: key, waterMl: 500), key, startKey: key),
          500);
      expect(
          WaterDefaults.effective(DailyWellness(date: key), key, startKey: key),
          4000);
      expect(
          WaterDefaults.effective(
              DailyWellness(date: key, waterSet: true), key, startKey: key),
          0);
      expect(WaterDefaults.effective(null, key, startKey: null), 0);
    });

    test('restoring a backup moves the start earlier, never later', () async {
      final state = await makeState(waterStart: daysAgo(0));
      final backup = oldBackup()..['waterDefaultStart'] = daysAgo(1);
      await state.importBackup(jsonEncode(backup));
      expect(state.waterDefaultStart, daysAgo(1));
      final later = oldBackup()..['waterDefaultStart'] = daysAgo(0);
      await state.importBackup(jsonEncode(later));
      expect(state.waterDefaultStart, daysAgo(1));
      state.dispose();
    });

    test('a fresh install starts the default today', () async {
      final state = await makeState();
      expect(state.waterDefaultStart, dateKey(DateTime.now()));
      state.dispose();
    });
  });

  group('continuous servings', () {
    final food = FoodItem.fromJson(dosa);
    test('servings and grams convert both ways and clamp to 0.1–10', () {
      expect(ServingMath.gramsFor(food, 1.5), 120);
      expect(ServingMath.servingsFromGrams(food, 100), 1.25);
      expect(ServingMath.servingsFromGrams(food, 2), .1);
      expect(ServingMath.servingsFromGrams(food, 5000), 10);
      expect(ServingMath.normalize(1.23456), 1.23);
      expect(ServingMath.normalize(0), .1);
      expect(ServingMath.parse('1,5'), 1.5);
      expect(ServingMath.parse('abc'), isNull);
      expect(ServingMath.format(1.5), '1.5');
      expect(ServingMath.format(2), '2');
      expect(
          ServingMath.servingsFromGrams(
              FoodItem.fromJson({...dosa, 'servingGrams': 0}), 50),
          isNull);
    });

    test('editing an entry changes only its quantity', () async {
      final state = await makeState();
      await state.saveProfile(profile);
      await state.addFood(food, 1, 'Breakfast');
      final id = state.logs.single.id;
      await state.updateFoodServings(id, 1.37);
      expect(state.logs.single.servings, 1.37);
      expect(state.logs.single.meal, 'Breakfast');
      expect(state.caloriesEaten, closeTo(168 * 1.37, .01));
      state.dispose();
    });
  });

  group('streak and weekly summary', () {
    FoodLog log(String date) => FoodLog(
        id: date,
        date: date,
        meal: 'Lunch',
        food: FoodItem.fromJson(dosa),
        servings: 1);
    test('streak counts consecutive logged days and survives a quiet morning',
        () {
      final today = DateTime(2026, 11, 24);
      final logs = [
        log('2026-11-23'),
        log('2026-11-22'),
        log('2026-11-21'),
        log('2026-11-19')
      ];
      expect(loggingStreak(logs, today), 3);
      expect(loggingStreak([...logs, log('2026-11-24')], today), 4);
      expect(loggingStreak([log('2026-11-20')], today), 0);
    });

    test('weekly averages use logged days only', () {
      final today = DateTime(2026, 11, 24);
      final facts = {
        '2026-11-24': const DayFacts(
            calories: 1800, protein: 80, target: 1700, steps: 6000, logged: true),
        '2026-11-22': const DayFacts(
            calories: 1600, protein: 60, target: 1700, steps: 0, logged: true),
        '2026-11-20': const DayFacts(
            calories: 0, protein: 0, target: 1700, steps: 4000, logged: false),
      };
      final w = weeklySummary(
          today: today,
          factsFor: (k) =>
              facts[k] ??
              const DayFacts(
                  calories: 0, protein: 0, target: 1700, steps: 0, logged: false),
          weights: const [
            WeightEntry(date: '2026-11-10', weightKg: 63),
            WeightEntry(date: '2026-11-20', weightKg: 62.6),
            WeightEntry(date: '2026-11-24', weightKg: 62.2),
          ]);
      expect(w.daysLogged, 2);
      expect(w.avgCalories, 1700);
      expect(w.avgTarget, 1700);
      expect(w.avgProtein, 70);
      expect(w.totalSteps, 10000);
      expect(w.avgSteps, 5000);
      expect(w.weightChangeKg, -.8);
      expect(w.fromKey, '2026-11-18');
    });
  });

  group('reminder decisions', () {
    final now = DateTime(2026, 11, 24, 8, 0);
    final all = const ReminderSettings().recommended();
    test('meal reminders skip meals already logged today', () {
      final plan = planReminders(
          now: now,
          settings: all,
          inputs: const ReminderInputs(loggedMeals: {
            '2026-11-24': {'Breakfast'}
          }));
      final today = plan.where((r) => r.at.day == 24).map((r) => r.title);
      expect(today, isNot(contains('Log your Breakfast')));
      expect(today, contains('Log your Lunch'));
      expect(plan.where((r) => r.at.day == 25).map((r) => r.title),
          contains('Log your Breakfast'));
      expect(plan.every((r) => r.at.isAfter(now)), isTrue);
      expect(plan.map((r) => r.id).toSet().length, plan.length);
    });

    test('past times today are not scheduled', () {
      final plan = planReminders(
          now: DateTime(2026, 11, 24, 14, 0),
          settings: all,
          inputs: const ReminderInputs());
      expect(
          plan.where((r) => r.at.day == 24).map((r) => r.title),
          isNot(anyOf(contains('Log your Breakfast'),
              contains('Log your Lunch'))));
    });

    test('evening nudge only when the day looks incomplete', () {
      expect(dayLooksIncomplete({'Breakfast'}, 900, 1800), isTrue);
      expect(dayLooksIncomplete({'Breakfast', 'Lunch'}, 500, 1800), isTrue);
      expect(dayLooksIncomplete({'Breakfast', 'Lunch'}, 1200, 1800), isFalse);
      final plan = planReminders(
          now: now,
          settings: all,
          inputs: const ReminderInputs(
              loggedMeals: {
                '2026-11-24': {'Breakfast', 'Lunch', 'Dinner'}
              },
              caloriesByDate: {'2026-11-24': 1700},
              calorieTarget: 1800));
      expect(
          plan.where((r) => r.at.day == 24).map((r) => r.title),
          isNot(contains('Fill in today\'s log')));
    });

    test('everything is off by default', () {
      expect(const ReminderSettings().anyEnabled, isFalse);
      expect(
          planReminders(
              now: now,
              settings: const ReminderSettings(),
              inputs: const ReminderInputs()),
          isEmpty);
    });

    test('weigh-in, fasting and supplement reminders', () {
      final settings = const ReminderSettings().copyWith(
          weighIn: const ReminderToggle(enabled: true, minutes: 7 * 60),
          fasting: const ReminderToggle(enabled: true, minutes: 20 * 60),
          supplements: true);
      final plan = planReminders(
          now: now,
          settings: settings,
          inputs: ReminderInputs(
            nextWeighIn: DateTime(2026, 11, 20),
            measurementsDue: true,
            fastingActive: true,
            fastingTargetAt: DateTime(2026, 11, 24, 10),
            supplements: const [
              Supplement(
                  id: 'a',
                  name: 'Vitamin D',
                  reminderEnabled: true,
                  reminderMinutes: 9 * 60),
              Supplement(
                  id: 'b',
                  name: 'Fish oil',
                  reminderEnabled: true,
                  reminderMinutes: 9 * 60),
            ],
            supplementsTaken: const {
              '2026-11-24': {'a'}
            },
          ));
      final weigh = plan.firstWhere((r) => r.title == 'Weekly check-in');
      expect(weigh.at, DateTime(2026, 11, 25, 7), reason: 'overdue, 7:00 passed');
      expect(weigh.body, contains('waist'));
      expect(plan.any((r) => r.title == 'Fasting window complete'), isTrue);
      expect(plan.any((r) => r.title.startsWith('Start your fasting')), isFalse,
          reason: 'a window is already active');
      final today = plan.where((r) => r.at.day == 24).map((r) => r.title);
      expect(today, contains('Time for Fish oil'));
      expect(today, isNot(contains('Time for Vitamin D')));
    });

    test('settings survive a round trip and bad JSON falls back to off', () {
      final s = const ReminderSettings().recommended();
      final back = ReminderSettings.decode(s.encode());
      expect(back.lunch.enabled, isTrue);
      expect(back.lunch.minutes, s.lunch.minutes);
      expect(ReminderSettings.decode('{bad').anyEnabled, isFalse);
    });
  });

  group('Health Connect import', () {
    test('manual values win and imports never touch pre-upgrade days',
        () async {
      final state = await makeState(waterStart: daysAgo(2));
      await state.importBackup(jsonEncode(oldBackup()));
      final before = jsonEncode(state.wellness[daysAgo(3)]!.toJson());
      state.setSelectedDate(DateTime.now());
      await state.updateWellness(
          state.selectedWellness.copyWith(steps: 5000));
      await state.addWorkout(WorkoutEntry(
          id: 'manual',
          date: daysAgo(0),
          typeId: 'walking_brisk',
          typeName: 'Walking — brisk',
          durationMinutes: 30,
          met: 4.8,
          caloriesBurned: 120));
      await state.logWeight(61.8);
      final data = HealthImport(
        fromKey: daysAgo(3),
        toKey: daysAgo(0),
        days: [
          HealthDay(date: daysAgo(3), steps: 12000, weightKg: 70),
          HealthDay(date: daysAgo(1), steps: 8000, sleepHours: 7.2, weightKg: 61.9,
              composition: const {'bodyFatPct': 31.5, 'leanKg': 42}),
          HealthDay(date: daysAgo(0), steps: 9000, activeCalories: 400,
              weightKg: 65),
        ],
        workouts: [
          ImportedWorkout(
              uuid: 'u1', date: daysAgo(0), activity: 'WALKING', minutes: 31),
          ImportedWorkout(
              uuid: 'u2', date: daysAgo(1), activity: 'RUNNING', minutes: 20),
          ImportedWorkout(
              uuid: 'u2', date: daysAgo(1), activity: 'RUNNING', minutes: 20),
        ],
      );
      await state.applyHealthImport(data);
      await state.applyHealthImport(data); // a second sync adds nothing

      // Pre-upgrade day: untouched.
      expect(jsonEncode(state.wellness[daysAgo(3)]!.toJson()), before);
      final oldWeight = state.weights.singleWhere((w) => w.date == daysAgo(3));
      expect(oldWeight.weightKg, 62.0);
      expect(oldWeight.imported, isFalse);
      // Today: manual steps and manual weight win.
      final today = state.wellness[daysAgo(0)]!;
      expect(today.effectiveSteps, 5000);
      expect(today.importedSteps, 9000);
      expect(today.stepsImported, isFalse);
      expect(state.weights.firstWhere((w) => w.date == daysAgo(0)).weightKg,
          61.8);
      expect(state.weights.firstWhere((w) => w.date == daysAgo(0)).imported,
          isFalse);
      // Manual workout wins over the imported copy of the same walk.
      expect(state.workouts.where((w) => w.date == daysAgo(0)), hasLength(2));
      expect(state.workoutCaloriesFor(daysAgo(0)), 120);
      // Yesterday: imported values fill in, marked imported, once.
      final y = state.wellness[daysAgo(1)]!;
      expect(y.effectiveSteps, 8000);
      expect(y.stepsImported, isTrue);
      expect(y.effectiveSleepHours, 7.2);
      expect(state.workouts.where((w) => w.date == daysAgo(1)), hasLength(1));
      expect(state.workoutCaloriesFor(daysAgo(1)), greaterThan(0));
      final yw = state.weights.firstWhere((w) => w.date == daysAgo(1));
      expect(yw.imported, isTrue);
      expect(state.bodyComposition[daysAgo(1)]!['bodyFatPct'], 31.5);
      // Profile weight still follows the latest (manual) reading.
      expect(state.profile!.currentWeightKg, 61.8);
      // A manual composition edit wins over a later import.
      await state.saveBodyComposition(daysAgo(1), {'bodyFatPct': 30.0});
      await state.applyHealthImport(data);
      expect(state.bodyComposition[daysAgo(1)]!['bodyFatPct'], 30.0);
      expect(state.bodyComposition[daysAgo(1)]!.importedFields,
          isNot(contains('bodyFatPct')));
      expect(state.bodyComposition[daysAgo(1)]!['leanKg'], 42);
      // Imported active energy and steps never sum with workouts.
      state.setSelectedDate(DateTime.now());
      expect(state.exerciseCalories, 200, reason: '50% of max(400, 120, steps)');
      state.dispose();
    });

    test('overlapping sleep sessions from two apps are merged', () {
      final night = sleepHoursByWakeDate([
        (DateTime(2026, 11, 23, 23), DateTime(2026, 11, 24, 6)),
        (DateTime(2026, 11, 23, 23, 30), DateTime(2026, 11, 24, 6, 30)),
        (DateTime(2026, 11, 24, 14), DateTime(2026, 11, 24, 14, 30)),
      ]);
      expect(night['2026-11-24'], 8.0);
    });
  });

  group('supplements', () {
    test('ticked items add calories once and track adherence', () async {
      final state = await makeState();
      await state.saveProfile(profile);
      state.setSelectedDate(DateTime.now());
      await state.saveSupplement(const Supplement(
          id: 'whey', name: 'Whey protein', calories: 120, proteinG: 24));
      await state.saveSupplement(const Supplement(id: 'd', name: 'Vitamin D'));
      await state.toggleSupplement('whey');
      await state.toggleSupplement('d');
      expect(state.caloriesEaten, 120);
      expect(state.proteinEaten, 24);
      // Editing the supplement later does not change a ticked day.
      await state.saveSupplement(state.supplements.first.copyWith(calories: 150));
      expect(state.caloriesEaten, 120);
      // Logged as a food too: counted once (the food entry).
      await state.addFood(
          FoodItem.fromJson({...dosa, 'id': 'w', 'name': 'Whey Protein', 'calories': 118}),
          1,
          'Snacks');
      expect(state.caloriesEaten, 118);
      final stats =
          supplementStats('d', state.supplementIntakes, DateTime.now());
      expect(stats.takenDays, 1);
      expect(stats.streak, 1);
      await state.toggleSupplement('d');
      expect(state.supplementTaken('d'), isFalse);
      await state.removeSupplement('whey');
      expect(state.activeSupplements.map((s) => s.id), ['d']);
      expect(state.supplementIntakes.where((i) => i.supplementId == 'whey'),
          hasLength(1));
      state.dispose();
    });
  });

  group('quick logging and protein', () {
    test('combos log several items; recent and frequent foods', () async {
      final state = await makeState();
      await state.saveProfile(profile);
      final food = FoodItem.fromJson(dosa);
      final chutney = FoodItem.fromJson(
          {...dosa, 'id': 'chutney', 'name': 'Coconut chutney', 'calories': 60});
      final combo = MealCombo(
          id: 'c',
          name: 'My usual breakfast',
          meal: 'Breakfast',
          items: [
            ComboItem(food: food, servings: 2),
            ComboItem(food: chutney, servings: 1)
          ]);
      await state.saveCombo(combo);
      await state.logCombo(combo);
      expect(state.selectedLogs, hasLength(2));
      expect(state.caloriesEaten, closeTo(396, .01));
      expect(state.recentFoods().map((f) => f.id), containsAll(['plain-dosa', 'chutney']));
      expect(state.frequentFoods(), isEmpty, reason: 'needs two uses');
      await state.addFood(food, 1, 'Dinner');
      expect(state.frequentFoods().first.id, 'plain-dosa');
      await state.saveCombo(combo.copyWith(name: 'Sunday breakfast'));
      expect(state.combos.single.name, 'Sunday breakfast');
      await state.deleteCombo('c');
      expect(state.combos, isEmpty);
      expect(MealCombo.fromJson(combo.toJson()).items.first.servings, 2);
      state.dispose();
    });

    test('protein nudge only for light main meals', () {
      expect(proteinNudge('Breakfast', 8, hasEntries: true), contains('curd'));
      expect(proteinNudge('Breakfast', 24, hasEntries: true), isNull);
      expect(proteinNudge('Snacks', 2, hasEntries: true), isNull);
      expect(proteinNudge('Lunch', 0, hasEntries: false), isNull);
    });
  });

  group('body composition', () {
    test('manual edits, removal and JSON round trip', () {
      const empty = BodyComposition(date: '2026-11-24');
      final a = empty.withImported({'bodyFatPct': 30, 'muscleKg': 40});
      final b = a.withManual({'muscleKg': 41, 'waistCm': 82});
      expect(b.importedFields, {'bodyFatPct'});
      expect(b.withImported({'muscleKg': 39})['muscleKg'], 41);
      final c = b.withManual({'waistCm': null});
      expect(c['waistCm'], isNull);
      final back = BodyComposition.fromJson(b.toJson());
      expect(back.values, b.values);
      expect(back.importedFields, b.importedFields);
    });

    test('measurement nudge every two weeks', () async {
      final state = await makeState();
      await state.saveProfile(profile);
      expect(state.measurementsDue, isTrue);
      await state.saveBodyComposition(daysAgo(3), {'waistCm': 80});
      expect(state.measurementsDue, isFalse);
      state.dispose();
    });
  });
}
