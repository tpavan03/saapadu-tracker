import 'package:flutter_test/flutter_test.dart';
import 'package:saapadu/calorie_engine.dart';
import 'package:saapadu/models.dart';

Profile profile({
  String sex = 'Male',
  int birthYear = 1990,
  double heightCm = 175,
  double currentWeightKg = 70,
  double goalWeightKg = 65,
  String activityLevel = 'Sedentary',
  double weeklyGoalKg = 0.5,
  int? manualCalorieTarget,
  DateTime? goalDate,
}) =>
    Profile(
      name: 'Test',
      sex: sex,
      birthYear: birthYear,
      heightCm: heightCm,
      currentWeightKg: currentWeightKg,
      goalWeightKg: goalWeightKg,
      activityLevel: activityLevel,
      weeklyGoalKg: weeklyGoalKg,
      manualCalorieTarget: manualCalorieTarget,
      goalDate: goalDate,
    );

void main() {
  final referenceDate = DateTime(2025, 6, 1);

  group('Mifflin-St Jeor resting energy', () {
    test('uses the male-reference coefficient', () {
      final result = CalorieEngine.bmr(
        profile(birthYear: 1990),
        today: referenceDate,
      );

      expect(result, 1623.75);
    });

    test('uses the female-reference coefficient', () {
      final result = CalorieEngine.bmr(
        profile(sex: 'Female', birthYear: 1990),
        today: referenceDate,
      );

      expect(result, 1457.75);
    });
  });

  group('daily target', () {
    test('a loss goal subtracts its deficit from maintenance', () {
      final losing = profile(
        currentWeightKg: 100,
        goalWeightKg: 90,
        weeklyGoalKg: 0.5,
      );
      final maintaining = profile(
        currentWeightKg: 100,
        goalWeightKg: 100,
        weeklyGoalKg: 0.5,
      );

      expect(
        CalorieEngine.dailyTarget(losing, today: referenceDate),
        lessThan(CalorieEngine.dailyTarget(maintaining, today: referenceDate)),
      );
    });

    test('a gain goal adds its surplus to maintenance', () {
      final gaining = profile(
        currentWeightKg: 70,
        goalWeightKg: 75,
        weeklyGoalKg: 0.25,
      );
      final maintaining = profile(
        currentWeightKg: 70,
        goalWeightKg: 70,
        weeklyGoalKg: 0.25,
      );

      expect(
        CalorieEngine.dailyTarget(gaining, today: referenceDate),
        greaterThan(
          CalorieEngine.dailyTarget(maintaining, today: referenceDate),
        ),
      );
    });

    test('applies the male-reference automatic target floor', () {
      final result = CalorieEngine.dailyTarget(
        profile(currentWeightKg: 50, goalWeightKg: 40, weeklyGoalKg: 0.9),
        today: referenceDate,
      );

      expect(result, 1500);
    });

    test('applies the female-reference automatic target floor', () {
      final result = CalorieEngine.dailyTarget(
        profile(
          sex: 'Female',
          currentWeightKg: 45,
          goalWeightKg: 40,
          weeklyGoalKg: 0.9,
        ),
        today: referenceDate,
      );

      expect(result, 1200);
    });

    test('caps restored loss rates at the automatic safety limit', () {
      final atLimit = profile(
        currentWeightKg: 120,
        goalWeightKg: 90,
        weeklyGoalKg: 0.9,
      );
      final aboveLimit = profile(
        currentWeightKg: 120,
        goalWeightKg: 90,
        weeklyGoalKg: 2,
      );

      expect(
        CalorieEngine.dailyTarget(aboveLimit, today: referenceDate),
        CalorieEngine.dailyTarget(atLimit, today: referenceDate),
      );
    });
  });

  group('goal-date plan recommendation', () {
    test('calculates the weekly rate and calorie target for a safe date', () {
      final result = CalorieEngine.planRecommendation(
        profile(
          currentWeightKg: 80,
          goalWeightKg: 76,
          goalDate: DateTime(2025, 7, 27),
        ),
        today: referenceDate,
      );

      expect(result.requiredWeeklyRateKg, closeTo(0.5, 0.0001));
      expect(result.plannedWeeklyRateKg, closeTo(0.5, 0.0001));
      expect(result.safety, GoalPlanSafety.safe);
      expect(result.isSafe, isTrue);
      expect(result.effectiveTarget, result.recommendedTarget);
      expect(result.usesManualTarget, isFalse);
    });

    test('flags an aggressive date and recommends the guarded safe rate', () {
      final result = CalorieEngine.planRecommendation(
        profile(
          currentWeightKg: 80,
          goalWeightKg: 70,
          goalDate: DateTime(2025, 7, 6),
        ),
        today: referenceDate,
      );

      expect(result.requiredWeeklyRateKg, closeTo(2, 0.0001));
      expect(result.plannedWeeklyRateKg, 0.9);
      expect(result.safety, GoalPlanSafety.unsafe);
      expect(result.earliestSafeDate, DateTime(2025, 8, 18));
    });

    test('treats a past date with an unfinished goal as unsafe', () {
      final result = CalorieEngine.planRecommendation(
        profile(
          currentWeightKg: 80,
          goalWeightKg: 75,
          goalDate: DateTime(2025, 5, 31),
        ),
        today: referenceDate,
      );

      expect(result.requiredWeeklyRateKg, isNull);
      expect(result.safety, GoalPlanSafety.unsafe);
      expect(result.plannedWeeklyRateKg, 0.5);
    });

    test('uses a positive manual calorie target without changing advice', () {
      final automatic = CalorieEngine.planRecommendation(
        profile(currentWeightKg: 80, goalWeightKg: 75),
        today: referenceDate,
      );
      final overridden = CalorieEngine.planRecommendation(
        profile(
          currentWeightKg: 80,
          goalWeightKg: 75,
          manualCalorieTarget: 1875,
        ),
        today: referenceDate,
      );

      expect(overridden.recommendedTarget, automatic.recommendedTarget);
      expect(overridden.effectiveTarget, 1875);
      expect(overridden.usesManualTarget, isTrue);
      expect(
        CalorieEngine.dailyTarget(
          profile(manualCalorieTarget: 1875),
          today: referenceDate,
        ),
        1875,
      );
    });
  });

  group('profile plan persistence', () {
    test('loads an old profile backup with unset plan options', () {
      final oldBackup = profile().toJson()
        ..remove('manualCalorieTarget')
        ..remove('goalDate');

      final restored = Profile.fromJson(oldBackup);

      expect(restored.manualCalorieTarget, isNull);
      expect(restored.goalDate, isNull);
    });

    test('round trips and can clear optional plan options', () {
      final original = profile(
        manualCalorieTarget: 1900,
        goalDate: DateTime(2025, 12, 25, 18, 30),
      );

      final restored = Profile.fromJson(original.toJson());
      final cleared = restored.copyWith(
        manualCalorieTarget: null,
        goalDate: null,
      );

      expect(restored.manualCalorieTarget, 1900);
      expect(restored.goalDate, DateTime(2025, 12, 25));
      expect(cleared.manualCalorieTarget, isNull);
      expect(cleared.goalDate, isNull);
    });
  });

  group('step energy', () {
    test('returns conservative active energy for a walking fallback', () {
      // 10,000 steps / 100 steps per minute = 100 minutes.
      // (3 MET - 1 resting MET) * 70 kg * 100 / 60 = 233.3 kcal.
      expect(CalorieEngine.stepCalories(10000, 70), 233);
    });

    test('does not return calories for invalid or empty readings', () {
      expect(CalorieEngine.stepCalories(0, 70), 0);
      expect(CalorieEngine.stepCalories(-100, 70), 0);
      expect(CalorieEngine.stepCalories(1000, 0), 0);
      expect(CalorieEngine.stepCalories(1000, double.nan), 0);
    });
  });

  group('BMI', () {
    test('uses kilograms divided by squared height in metres', () {
      final result = CalorieEngine.bmi(
        profile(heightCm: 175, currentWeightKg: 70),
      );

      expect(result, closeTo(22.8571, 0.0001));
      expect(CalorieEngine.bmiLabel(result), 'Healthy range');
    });

    test('labels standard category boundaries deterministically', () {
      expect(CalorieEngine.bmiLabel(18.49), 'Below range');
      expect(CalorieEngine.bmiLabel(18.5), 'Healthy range');
      expect(CalorieEngine.bmiLabel(25), 'Above range');
      expect(CalorieEngine.bmiLabel(30), 'High range');
    });
  });
}
