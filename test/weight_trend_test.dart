import 'package:flutter_test/flutter_test.dart';
import 'package:saapadu/models.dart';
import 'package:saapadu/weight_trend.dart';

const profile = Profile(
    name: 'Test',
    sex: 'Male',
    birthYear: 1990,
    heightCm: 175,
    currentWeightKg: 78.5,
    goalWeightKg: 75,
    activityLevel: 'Sedentary',
    weeklyGoalKg: .5);
final today = DateTime(2026, 11, 2);
final modelDate = DateTime(2027, 1, 1);
List<WeightEntry> readings(List<double> weights) => [
      for (var i = 0; i < weights.length; i++)
        WeightEntry(
            date: dateKey(
                today.subtract(Duration(days: (weights.length - 1 - i) * 7))),
            weightKg: weights[i])
    ];

void main() {
  test(
      'weekly check-ins produce a revised date while the requested deadline remains unchanged',
      () {
    final requested = profile.copyWith(goalDate: DateTime(2026, 12, 15));
    final forecast = WeightTrend.forecast(requested, readings([79.5, 79, 78.5]),
        modelDate: modelDate, today: today);
    expect(forecast.basis, WeightForecastBasis.checkInTrend);
    expect(forecast.weeklyChangeKg, -.5);
    expect(forecast.estimatedDate, today.add(const Duration(days: 49)));
    expect(requested.goalDate, DateTime(2026, 12, 15));
  });
  test(
      'insufficient or stale measurements retain the model estimate without inventing a trend',
      () {
    final two = WeightTrend.forecast(profile, readings([79, 78.5]),
        modelDate: modelDate, today: today);
    expect(two.basis, WeightForecastBasis.caloriePlan);
    expect(two.estimatedDate, modelDate);
    final stale = WeightTrend.forecast(
        profile,
        [
          const WeightEntry(date: '2026-01-01', weightKg: 90),
          ...readings([79, 78.5])
        ],
        modelDate: modelDate,
        today: today);
    expect(stale.readingCount, 2);
    expect(stale.usesObservedTrend, false);
  });
  test('flat or contrary progress has no unsupported arrival date', () {
    for (final values in [
      [79.0, 79.0, 79.0],
      [78.0, 78.5, 79.0]
    ]) {
      final forecast = WeightTrend.forecast(profile, readings(values),
          modelDate: modelDate, today: today);
      expect(forecast.basis, WeightForecastBasis.insufficientProgress);
      expect(forecast.estimatedDate, isNull);
    }
  });
  test('one outlying weigh-in does not dominate the robust trend', () {
    final forecast = WeightTrend.forecast(
        profile, readings([80, 79.5, 85, 78.5]),
        modelDate: modelDate, today: today);
    expect(forecast.weeklyChangeKg, -.5);
    expect(forecast.basis, WeightForecastBasis.checkInTrend);
  });
  test(
      'a forecast does not drift forward just because the app is reopened later',
      () {
    final entries = readings([79.5, 79, 78.5]);
    final first = WeightTrend.forecast(profile, entries,
        modelDate: modelDate, today: today);
    final later = WeightTrend.forecast(profile, entries,
        modelDate: modelDate, today: today.add(const Duration(days: 2)));
    expect(later.estimatedDate, first.estimatedDate);
  });
  test('rapid loss is reported without setting a faster deadline', () {
    final forecast = WeightTrend.forecast(profile, readings([82, 80, 78]),
        modelDate: modelDate, today: today);
    expect(forecast.basis, WeightForecastBasis.rapidChange);
    expect(forecast.estimatedDate, isNull);
    expect(forecast.explanation, contains('no faster deadline'));
  });
  test('future and invalid records cannot manufacture a current trend', () {
    final forecast = WeightTrend.forecast(
        profile,
        [
          const WeightEntry(date: '2027-01-01', weightKg: 70),
          const WeightEntry(date: 'not-a-date', weightKg: 80),
          const WeightEntry(date: '2026-11-01', weightKg: 0)
        ],
        modelDate: modelDate,
        today: today);
    expect(forecast.readingCount, 0);
    expect(forecast.estimatedDate, modelDate);
  });
}
