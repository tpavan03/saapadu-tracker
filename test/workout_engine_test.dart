import 'package:flutter_test/flutter_test.dart';
import 'package:saapadu/models.dart';
import 'package:saapadu/workout_engine.dart';

void main() {
  group('workout energy', () {
    test('calculates gross and active calories from MET', () {
      // 5 MET * 60 kg * 30/60 hour = 150 gross kcal.
      // Removing 1 resting MET leaves 120 active kcal.
      expect(
        WorkoutEngine.grossCalories(
          met: 5,
          weightKg: 60,
          durationMinutes: 30,
        ),
        150,
      );
      expect(
        WorkoutEngine.activeCalories(
          met: 5,
          weightKg: 60,
          durationMinutes: 30,
        ),
        120,
      );
      expect(
        WorkoutEngine.calorieCredit(
          met: 5,
          weightKg: 60,
          durationMinutes: 30,
        ),
        120,
      );
    });

    test('scales linearly with weight and duration', () {
      double calories(double weight, double minutes) =>
          WorkoutEngine.activeCalories(
            met: 7,
            weightKg: weight,
            durationMinutes: minutes,
          );

      expect(calories(80, 30), calories(40, 30) * 2);
      expect(calories(80, 60), calories(80, 30) * 2);
    });

    test('returns no credit for invalid values or activity below rest', () {
      expect(
        WorkoutEngine.activeCalories(
          met: double.nan,
          weightKg: 70,
          durationMinutes: 30,
        ),
        0,
      );
      expect(
        WorkoutEngine.activeCalories(
          met: 5,
          weightKg: double.infinity,
          durationMinutes: 30,
        ),
        0,
      );
      expect(
        WorkoutEngine.grossCalories(
          met: 5,
          weightKg: 70,
          durationMinutes: 0,
        ),
        0,
      );
      expect(
        WorkoutEngine.activeCalories(
          met: 0.8,
          weightKg: 70,
          durationMinutes: 30,
        ),
        0,
      );
      expect(
        WorkoutEngine.grossCalories(
          met: -2,
          weightKg: 70,
          durationMinutes: 30,
        ),
        0,
      );
    });
  });

  group('workout catalog', () {
    test('has unique stable IDs and all requested activity families', () {
      final ids = WorkoutEngine.workoutTypes.map((type) => type.id).toList();
      final families = ids.map((id) => id.split('_').first).toSet();

      expect(ids.toSet(), hasLength(ids.length));
      expect(
        families,
        containsAll({
          'walking',
          'running',
          'cycling',
          'strength',
          'yoga',
          'badminton',
          'cricket',
          'swimming',
          'hiit',
          'football',
          'stairs',
          'elliptical',
          'dance',
        }),
      );
      expect(
        WorkoutEngine.workoutTypes.every(
          (type) => type.id.isNotEmpty && type.name.isNotEmpty && type.met > 1,
        ),
        isTrue,
      );
    });
  });

  test('workout entries preserve active calorie data through JSON', () {
    const entry = WorkoutEntry(
      id: 'workout-1',
      date: '2026-09-17',
      typeId: 'walking_brisk',
      typeName: 'Walking — brisk',
      durationMinutes: 45,
      met: 4.8,
      caloriesBurned: 199.5,
    );

    final restored = WorkoutEntry.fromJson(entry.toJson());

    expect(restored.id, entry.id);
    expect(restored.date, entry.date);
    expect(restored.typeId, entry.typeId);
    expect(restored.typeName, entry.typeName);
    expect(restored.durationMinutes, entry.durationMinutes);
    expect(restored.met, entry.met);
    expect(restored.caloriesBurned, entry.caloriesBurned);
  });
}
