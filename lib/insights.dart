import 'dart:math' as math;

import 'models.dart';

/// Continuous serving maths shared by the add-food sheet and diary edits.
class ServingMath {
  const ServingMath._();
  static const double min = 0.1;
  static const double max = 10;

  static double clamp(double servings) =>
      servings.isFinite ? servings.clamp(min, max).toDouble() : 1;

  /// Rounds to 2 decimals so stored values stay readable.
  static double normalize(double servings) =>
      (clamp(servings) * 100).round() / 100;

  static double gramsFor(FoodItem food, double servings) =>
      food.servingGrams <= 0 ? 0 : food.servingGrams * servings;

  /// Grams typed by the user -> servings, or null when the food has no gram
  /// weight or the text is not a positive number.
  static double? servingsFromGrams(FoodItem food, double grams) {
    if (food.servingGrams <= 0 || !grams.isFinite || grams <= 0) return null;
    return normalize(grams / food.servingGrams);
  }

  static double? parse(String text) {
    final v = double.tryParse(text.trim().replaceAll(',', '.'));
    return v == null || !v.isFinite || v <= 0 ? null : v;
  }

  static String format(double value, {int decimals = 2}) {
    final fixed = value.toStringAsFixed(decimals);
    return fixed.contains('.')
        ? fixed.replaceFirst(RegExp(r'0+$'), '').replaceFirst(RegExp(r'\.$'), '')
        : fixed;
  }
}

/// Consecutive days ending today that satisfy [hit]. If today has not been
/// logged yet the streak still counts up to yesterday, so a morning check
/// does not show a broken streak.
int streakEnding(DateTime today, bool Function(String key) hit,
    {int limit = 3650}) {
  var day = DateTime(today.year, today.month, today.day);
  if (!hit(dateKey(day))) day = DateTime(day.year, day.month, day.day - 1);
  var count = 0;
  while (count < limit && hit(dateKey(day))) {
    count++;
    day = DateTime(day.year, day.month, day.day - 1);
  }
  return count;
}

int loggingStreak(List<FoodLog> logs, DateTime today) {
  final days = {for (final l in logs) l.date};
  return streakEnding(today, days.contains);
}

class WeeklySummary {
  const WeeklySummary({
    required this.fromKey,
    required this.toKey,
    required this.daysLogged,
    required this.avgCalories,
    required this.avgTarget,
    required this.avgProtein,
    required this.totalSteps,
    required this.avgSteps,
    required this.weightChangeKg,
  });
  final String fromKey;
  final String toKey;
  final int daysLogged;

  /// Averages over logged days only, so an unlogged day is not read as 0 kcal.
  final double avgCalories;
  final double avgTarget;
  final double avgProtein;
  final int totalSteps;

  /// Average over days with a step value.
  final int avgSteps;

  /// Latest reading in the week minus the latest reading before it (or the
  /// first in the week). Null with fewer than two readings.
  final double? weightChangeKg;
}

class DayFacts {
  const DayFacts({
    required this.calories,
    required this.protein,
    required this.target,
    required this.steps,
    required this.logged,
  });
  final double calories;
  final double protein;
  final int target;
  final int steps;
  final bool logged;
}

WeeklySummary weeklySummary({
  required DateTime today,
  required DayFacts Function(String key) factsFor,
  required List<WeightEntry> weights,
  int days = 7,
}) {
  final end = DateTime(today.year, today.month, today.day);
  final start = DateTime(end.year, end.month, end.day - (days - 1));
  var logged = 0, stepDays = 0, totalSteps = 0;
  double calories = 0, protein = 0, target = 0;
  for (var i = 0; i < days; i++) {
    final key = dateKey(DateTime(start.year, start.month, start.day + i));
    final f = factsFor(key);
    if (f.logged) {
      logged++;
      calories += f.calories;
      protein += f.protein;
      target += f.target;
    }
    if (f.steps > 0) {
      stepDays++;
      totalSteps += f.steps;
    }
  }
  final fromKey = dateKey(start), toKey = dateKey(end);
  final sorted = [...weights]..sort((a, b) => a.date.compareTo(b.date));
  final inWeek = sorted
      .where((w) => w.date.compareTo(fromKey) >= 0 && w.date.compareTo(toKey) <= 0)
      .toList();
  final before = sorted.where((w) => w.date.compareTo(fromKey) < 0).toList();
  double? change;
  if (inWeek.isNotEmpty) {
    final reference = before.isNotEmpty ? before.last : inWeek.first;
    if (!identical(reference, inWeek.last)) {
      change = ((inWeek.last.weightKg - reference.weightKg) * 10).round() / 10;
    }
  }
  return WeeklySummary(
    fromKey: fromKey,
    toKey: toKey,
    daysLogged: logged,
    avgCalories: logged == 0 ? 0 : calories / logged,
    avgTarget: logged == 0 ? 0 : target / logged,
    avgProtein: logged == 0 ? 0 : protein / logged,
    totalSteps: totalSteps,
    avgSteps: stepDays == 0 ? 0 : (totalSteps / stepDays).round(),
    weightChangeKg: change,
  );
}

/// Supplement adherence for the current month up to [today].
class SupplementStats {
  const SupplementStats(
      {required this.streak, required this.takenDays, required this.monthDays});
  final int streak;
  final int takenDays;
  final int monthDays;
}

SupplementStats supplementStats(
    String supplementId, List<SupplementIntake> intakes, DateTime today) {
  final days = {
    for (final i in intakes)
      if (i.supplementId == supplementId) i.date
  };
  final monthStart = dateKey(DateTime(today.year, today.month, 1));
  final todayKey = dateKey(today);
  final taken = days
      .where((d) => d.compareTo(monthStart) >= 0 && d.compareTo(todayKey) <= 0)
      .length;
  return SupplementStats(
      streak: streakEnding(today, days.contains),
      takenDays: taken,
      monthDays: today.day);
}

const mainMeals = ['Breakfast', 'Lunch', 'Dinner'];
const lowProteinMealGrams = 20.0;

/// A gentle suggestion for a logged main meal under ~20 g protein.
String? proteinNudge(String meal, double protein, {required bool hasEntries}) {
  if (!mainMeals.contains(meal) || !hasEntries) return null;
  if (protein >= lowProteinMealGrams) return null;
  final gap = math.max(5, (lowProteinMealGrams - protein).round());
  return switch (meal) {
    'Breakfast' =>
      'About $gap g short of ~20 g protein. A boiled egg, a cup of curd, or sundal on the side would cover it.',
    'Lunch' =>
      'About $gap g short of ~20 g protein. Add a cup of curd, extra dal, paneer, or an egg.',
    _ =>
      'About $gap g short of ~20 g protein. Try paneer, an egg, chicken or fish, or a bowl of sundal.',
  };
}
