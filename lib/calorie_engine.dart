import 'dart:math' as math;

import 'models.dart';

enum GoalPlanSafety { safe, unsafe }

class CaloriePlanRecommendation {
  const CaloriePlanRecommendation({
    required this.recommendedTarget,
    required this.effectiveTarget,
    required this.plannedWeeklyRateKg,
    required this.requiredWeeklyRateKg,
    required this.safety,
    required this.earliestSafeDate,
    required this.usesManualTarget,
    required this.projectedGoalDate,
    required this.projectedWeeklyRateKg,
    required this.targetSupportsGoal,
  });

  /// The guarded, automatically calculated calorie target.
  final int recommendedTarget;

  /// The target the diary should use, including a valid manual override.
  final int effectiveTarget;

  /// The weekly weight-change magnitude used for the recommendation.
  final double plannedWeeklyRateKg;

  /// The weekly change needed for [Profile.goalDate], or null without a
  /// future dated goal that requires a weight change.
  final double? requiredWeeklyRateKg;
  final GoalPlanSafety safety;
  final DateTime? earliestSafeDate;
  final bool usesManualTarget;

  /// The date implied by the active calorie target and current weight.
  /// This is recalculated whenever the profile weight or target changes.
  final DateTime? projectedGoalDate;

  /// Weekly change implied by the active calorie target.
  final double projectedWeeklyRateKg;

  /// False when a custom target is at maintenance or points away from the goal.
  final bool targetSupportsGoal;

  bool get isSafe => safety == GoalPlanSafety.safe;
}

class CalorieEngine {
  const CalorieEngine._();

  static const double maxAutomaticWeeklyLossKg = 0.9;

  static int age(Profile profile, {DateTime? today}) {
    return (today ?? DateTime.now()).year - profile.birthYear;
  }

  /// Mifflin-St Jeor resting energy equation.
  static double bmr(Profile profile, {DateTime? today}) {
    final base = 10 * profile.currentWeightKg +
        6.25 * profile.heightCm -
        5 * age(profile, today: today);
    return base + (profile.sex == 'Male' ? 5 : -161);
  }

  static double activityFactor(String level) => switch (level) {
        // Keep the original labels for saved profiles while using the
        // National Academies PAL category midpoints.
        'Lightly active' || 'Low active' => 1.60,
        'Moderately active' || 'Active' => 1.75,
        'Very active' => 2.05,
        'Sedentary' || 'Inactive' => 1.40,
        _ => 1.40,
      };

  static double maintenance(Profile profile, {DateTime? today}) =>
      bmr(profile, today: today) * activityFactor(profile.activityLevel);

  static CaloriePlanRecommendation planRecommendation(
    Profile profile, {
    DateTime? today,
  }) {
    final referenceDate = _dateOnly(today ?? DateTime.now());
    final direction = profile.goalWeightKg < profile.currentWeightKg
        ? -1
        : profile.goalWeightKg > profile.currentWeightKg
            ? 1
            : 0;
    final weightDifferenceKg =
        (profile.goalWeightKg - profile.currentWeightKg).abs();
    final goalDate =
        profile.goalDate == null ? null : _dateOnly(profile.goalDate!);
    final daysAvailable = goalDate?.difference(referenceDate).inDays;
    final requiredWeeklyRate = direction == 0
        ? 0.0
        : daysAvailable != null && daysAvailable > 0
            ? weightDifferenceKg * 7 / daysAvailable
            : null;

    final requestedWeeklyRate = requiredWeeklyRate ??
        math.max(
            0.0, profile.weeklyGoalKg.isFinite ? profile.weeklyGoalKg : 0.0);
    final hasUnreachableDate =
        direction != 0 && goalDate != null && (daysAvailable ?? 0) <= 0;
    final exceedsSafeLossRate =
        direction < 0 && requestedWeeklyRate > maxAutomaticWeeklyLossKg;
    final safety = hasUnreachableDate || exceedsSafeLossRate
        ? GoalPlanSafety.unsafe
        : GoalPlanSafety.safe;

    // The UI should reject a faster loss target and explain why. This clamp is
    // a final engine guardrail for profiles restored from older app versions.
    final plannedWeeklyChange = direction < 0
        ? math.min(requestedWeeklyRate, maxAutomaticWeeklyLossKg)
        : requestedWeeklyRate;
    final adjustment = direction * plannedWeeklyChange * 7700 / 7;
    final raw = maintenance(profile, today: today) + adjustment;
    // General planning floor; individual clinical needs may differ.
    final floor = profile.sex == 'Male' ? 1500.0 : 1200.0;
    final guarded = math.max(raw, floor);
    final recommendedTarget = (guarded / 10).round() * 10;
    final hasManualTarget =
        profile.manualCalorieTarget != null && profile.manualCalorieTarget! > 0;
    final effectiveTarget =
        hasManualTarget ? profile.manualCalorieTarget! : recommendedTarget;
    final maintenanceCalories = maintenance(profile, today: today);
    final targetDelta = maintenanceCalories - effectiveTarget;
    final targetSupportsGoal = direction == 0 ||
        (direction < 0 && targetDelta > 0) ||
        (direction > 0 && targetDelta < 0);
    final rawProjectedRate = targetSupportsGoal && direction != 0
        ? targetDelta.abs() * 7 / 7700
        : plannedWeeklyChange;
    final projectedRate = direction < 0
        ? math.min(rawProjectedRate, maxAutomaticWeeklyLossKg)
        : rawProjectedRate;
    final projectedGoalDate = direction == 0
        ? referenceDate
        : projectedRate > 0
            ? referenceDate.add(Duration(
                days: (weightDifferenceKg / projectedRate * 7).ceil(),
              ))
            : null;

    return CaloriePlanRecommendation(
      recommendedTarget: recommendedTarget,
      effectiveTarget: effectiveTarget,
      plannedWeeklyRateKg: plannedWeeklyChange,
      requiredWeeklyRateKg: requiredWeeklyRate,
      safety: safety,
      earliestSafeDate: direction < 0
          ? referenceDate.add(
              Duration(
                days:
                    (weightDifferenceKg / maxAutomaticWeeklyLossKg * 7).ceil(),
              ),
            )
          : null,
      usesManualTarget: hasManualTarget,
      projectedGoalDate: projectedGoalDate,
      projectedWeeklyRateKg: projectedRate,
      targetSupportsGoal: targetSupportsGoal,
    );
  }

  static int dailyTarget(Profile profile, {DateTime? today}) =>
      planRecommendation(profile, today: today).effectiveTarget;

  static int stepCalories(int steps, double weightKg) {
    if (steps <= 0 || weightKg <= 0 || !weightKg.isFinite) return 0;

    // Step count alone cannot reveal pace or terrain. Use a conservative
    // fallback of 100 steps/min at 3 MET and return active energy only by
    // subtracting the 1 MET resting component already included in TDEE.
    const assumedCadenceStepsPerMinute = 100.0;
    const assumedWalkingMet = 3.0;
    final durationMinutes = steps / assumedCadenceStepsPerMinute;
    final activeKcal =
        (assumedWalkingMet - 1) * weightKg * durationMinutes / 60;
    return activeKcal.round();
  }

  static double bmi(Profile profile) =>
      profile.currentWeightKg / math.pow(profile.heightCm / 100, 2);

  static String bmiLabel(double bmi) {
    if (bmi < 18.5) return 'Below range';
    if (bmi < 25) return 'Healthy range';
    if (bmi < 30) return 'Above range';
    return 'High range';
  }

  static DateTime _dateOnly(DateTime value) =>
      DateTime(value.year, value.month, value.day);
}
