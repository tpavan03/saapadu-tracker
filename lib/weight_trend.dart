import 'dart:math' as math;

import 'calorie_engine.dart';
import 'models.dart';

enum WeightForecastBasis {
  caloriePlan,
  checkInTrend,
  maintenance,
  insufficientProgress,
  rapidChange
}

class WeightForecast {
  const WeightForecast(
      {required this.estimatedDate,
      required this.modelDate,
      required this.basis,
      required this.readingCount,
      required this.explanation,
      this.weeklyChangeKg});
  final DateTime? estimatedDate;
  final DateTime? modelDate;
  final WeightForecastBasis basis;
  final int readingCount;
  final double? weeklyChangeKg;
  final String explanation;
  bool get usesObservedTrend => basis == WeightForecastBasis.checkInTrend;
}

/// A descriptive rolling trend, not a prescription or the NIH dynamic model.
/// Weekly check-ins work without encouraging daily weighing. Pairwise slopes
/// use readings at least seven days apart, reducing same-day water noise.
class WeightTrend {
  const WeightTrend._();

  static WeightForecast forecast(Profile profile, List<WeightEntry> entries,
      {required DateTime? modelDate, DateTime? today}) {
    final now = _day(today ?? DateTime.now());
    final byDate = <String, WeightEntry>{};
    for (final entry in entries) {
      final date = DateTime.tryParse(entry.date);
      if (date == null ||
          !entry.weightKg.isFinite ||
          entry.weightKg < 30 ||
          entry.weightKg > 350) {
        continue;
      }
      final age = now.difference(_day(date)).inDays;
      if (age >= 0 && age <= 28) byDate[dateKey(date)] = entry;
    }
    final readings = byDate.values.toList()
      ..sort((a, b) => a.date.compareTo(b.date));
    final remaining = profile.goalWeightKg - profile.currentWeightKg;
    if (remaining.abs() < .05) {
      return WeightForecast(
          estimatedDate: now,
          modelDate: modelDate,
          basis: WeightForecastBasis.maintenance,
          readingCount: readings.length,
          explanation:
              'You are at your selected goal. Keep checking in at a comfortable pace.');
    }
    final span = readings.length < 2
        ? 0
        : DateTime.parse(readings.last.date)
            .difference(DateTime.parse(readings.first.date))
            .inDays;
    if (readings.length < 3 || span < 14) {
      return WeightForecast(
          estimatedDate: modelDate,
          modelDate: modelDate,
          basis: WeightForecastBasis.caloriePlan,
          readingCount: readings.length,
          explanation:
              'Based on your current calorie plan. Three check-ins spanning at least two weeks can provide a personal trend estimate.');
    }
    final slopes = <double>[];
    for (var i = 0; i < readings.length; i++) {
      for (var j = i + 1; j < readings.length; j++) {
        final days = DateTime.parse(readings[j].date)
            .difference(DateTime.parse(readings[i].date))
            .inDays;
        if (days >= 7) {
          slopes.add((readings[j].weightKg - readings[i].weightKg) * 7 / days);
        }
      }
    }
    slopes.sort();
    final rate = slopes.length.isOdd
        ? slopes[slopes.length ~/ 2]
        : (slopes[slopes.length ~/ 2 - 1] + slopes[slopes.length ~/ 2]) / 2;
    if (rate.abs() < .05 || remaining * rate <= 0) {
      return WeightForecast(
          estimatedDate: null,
          modelDate: modelDate,
          basis: WeightForecastBasis.insufficientProgress,
          readingCount: readings.length,
          weeklyChangeKg: rate,
          explanation:
              'Recent check-ins do not show a consistent move toward this goal, so there is no reliable trend date yet. Your calorie target has not been reduced.');
    }
    if (remaining < 0 && rate.abs() > CalorieEngine.maxAutomaticWeeklyLossKg) {
      return WeightForecast(
          estimatedDate: null,
          modelDate: modelDate,
          basis: WeightForecastBasis.rapidChange,
          readingCount: readings.length,
          weeklyChangeKg: rate,
          explanation:
              'Recent weight change is faster than the app’s gradual-loss planning range. A short-term change may be fluid; no faster deadline or lower target is set automatically.');
    }
    final days = (remaining.abs() / rate.abs() * 7).ceil();
    if (days > 3650) {
      return WeightForecast(
          estimatedDate: null,
          modelDate: modelDate,
          basis: WeightForecastBasis.insufficientProgress,
          readingCount: readings.length,
          weeklyChangeKg: rate,
          explanation:
              'Recent progress is too gradual for a useful date estimate. Continue weekly check-ins; your calorie target stays unchanged.');
    }
    final estimate = DateTime.parse(readings.last.date)
        .add(Duration(days: math.max(1, days)));
    if (estimate.isBefore(now)) {
      return WeightForecast(
          estimatedDate: null,
          modelDate: modelDate,
          basis: WeightForecastBasis.insufficientProgress,
          readingCount: readings.length,
          weeklyChangeKg: rate,
          explanation:
              'The previous trend date has passed. Add a fresh check-in to update the estimate; no calorie reduction is applied automatically.');
    }
    return WeightForecast(
        estimatedDate: estimate,
        modelDate: modelDate,
        basis: WeightForecastBasis.checkInTrend,
        readingCount: readings.length,
        weeklyChangeKg: rate,
        explanation:
            'Updated from your recent check-in trend. This estimate can move as new readings arrive; it does not promise an outcome or change your selected deadline.');
  }

  static DateTime? latestReadingDate(List<WeightEntry> entries,
      {DateTime? today}) {
    final now = _day(today ?? DateTime.now());
    final dates = entries
        .map((entry) => DateTime.tryParse(entry.date))
        .whereType<DateTime>()
        .map(_day)
        .where((date) => !date.isAfter(now))
        .toList()
      ..sort();
    return dates.isEmpty ? null : dates.last;
  }

  static DateTime _day(DateTime value) =>
      DateTime(value.year, value.month, value.day);
}
