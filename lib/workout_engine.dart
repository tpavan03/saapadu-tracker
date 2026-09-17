import 'dart:math' as math;

class WorkoutType {
  const WorkoutType({
    required this.id,
    required this.name,
    required this.met,
  });

  final String id;
  final String name;
  final double met;
}

class WorkoutEngine {
  const WorkoutEngine._();

  /// Common activities from the 2024 Adult Compendium of Physical Activities.
  ///
  /// The comments contain the source activity code from pacompendium.com.
  /// Semantic IDs stay stable if the external catalog changes its codes later.
  static const List<WorkoutType> workoutTypes = [
    WorkoutType(
      id: 'walking_moderate',
      name: 'Walking — moderate',
      met: 3.8, // 17190
    ),
    WorkoutType(
      id: 'walking_brisk',
      name: 'Walking — brisk',
      met: 4.8, // 17200
    ),
    WorkoutType(
      id: 'running_easy',
      name: 'Running — easy (5 mph)',
      met: 8.5, // 12030
    ),
    WorkoutType(
      id: 'running_moderate',
      name: 'Running — moderate (6 mph)',
      met: 9.3, // 12050
    ),
    WorkoutType(
      id: 'cycling_moderate',
      name: 'Cycling — moderate',
      met: 7.0, // 01016
    ),
    WorkoutType(
      id: 'cycling_vigorous',
      name: 'Cycling — vigorous',
      met: 9.0, // 01017
    ),
    WorkoutType(
      id: 'strength_moderate',
      name: 'Strength training — moderate',
      met: 3.5, // 02054
    ),
    WorkoutType(
      id: 'strength_vigorous',
      name: 'Strength training — vigorous',
      met: 6.0, // 02050
    ),
    WorkoutType(
      id: 'yoga_general',
      name: 'Yoga — general',
      met: 2.3, // 02175
    ),
    WorkoutType(
      id: 'yoga_surya_namaskar',
      name: 'Yoga — Surya Namaskar',
      met: 3.5, // 02180
    ),
    WorkoutType(
      id: 'badminton_social',
      name: 'Badminton — social',
      met: 5.5, // 15030
    ),
    WorkoutType(
      id: 'badminton_competitive',
      name: 'Badminton — competitive',
      met: 9.0, // 15025
    ),
    WorkoutType(
      id: 'cricket_general',
      name: 'Cricket — batting, bowling or fielding',
      met: 4.8, // 15150
    ),
    WorkoutType(
      id: 'swimming_recreational',
      name: 'Swimming — recreational laps',
      met: 5.8, // 18240
    ),
    WorkoutType(
      id: 'swimming_vigorous',
      name: 'Swimming — vigorous freestyle',
      met: 9.8, // 18230
    ),
    WorkoutType(
      id: 'hiit_moderate',
      name: 'HIIT — moderate',
      met: 7.0, // 02210
    ),
    WorkoutType(
      id: 'hiit_vigorous',
      name: 'HIIT — vigorous',
      met: 11.0, // 02214
    ),
    WorkoutType(
      id: 'football_casual',
      name: 'Football — casual',
      met: 7.0, // Soccer, 15610
    ),
    WorkoutType(
      id: 'football_competitive',
      name: 'Football — competitive',
      met: 9.5, // Soccer, 15605
    ),
    WorkoutType(
      id: 'stairs_general',
      name: 'Stair climbing — general',
      met: 6.8, // 17131
    ),
    WorkoutType(
      id: 'stairs_fast',
      name: 'Stair climbing — fast',
      met: 9.3, // 17134
    ),
    WorkoutType(
      id: 'elliptical_moderate',
      name: 'Elliptical — moderate',
      met: 5.0, // 02048
    ),
    WorkoutType(
      id: 'elliptical_vigorous',
      name: 'Elliptical — vigorous',
      met: 9.0, // 02049
    ),
    WorkoutType(
      id: 'dance_general',
      name: 'Dance — general',
      met: 3.8, // Contemporary dancing, 03070
    ),
    WorkoutType(
      id: 'dance_vigorous',
      name: 'Dance — vigorous',
      met: 9.8, // Nightclub or folk dancing, 03031
    ),
  ];

  /// Total energy during an activity, including resting energy.
  static double grossCalories({
    required double met,
    required double weightKg,
    required double durationMinutes,
  }) {
    if (!_validInputs(
      met: met,
      weightKg: weightKg,
      durationMinutes: durationMinutes,
    )) {
      return 0;
    }
    return met * weightKg * durationMinutes / 60;
  }

  /// Energy above rest. Use this value for calorie-budget credit so resting
  /// energy already included in the daily target is not counted twice.
  static double activeCalories({
    required double met,
    required double weightKg,
    required double durationMinutes,
  }) {
    if (!_validInputs(
      met: met,
      weightKg: weightKg,
      durationMinutes: durationMinutes,
    )) {
      return 0;
    }
    return math.max(0, met - 1) * weightKg * durationMinutes / 60;
  }

  static double calorieCredit({
    required double met,
    required double weightKg,
    required double durationMinutes,
  }) =>
      activeCalories(
        met: met,
        weightKg: weightKg,
        durationMinutes: durationMinutes,
      );

  static bool _validInputs({
    required double met,
    required double weightKg,
    required double durationMinutes,
  }) =>
      met.isFinite &&
      weightKg.isFinite &&
      durationMinutes.isFinite &&
      met > 0 &&
      weightKg > 0 &&
      durationMinutes > 0;
}
