import 'models.dart';
import 'workout_engine.dart';

/// One day of values read from Health Connect. Null means "not available".
class HealthDay {
  const HealthDay({
    required this.date,
    this.steps,
    this.activeCalories,
    this.sleepHours,
    this.weightKg,
    this.composition = const {},
  });
  final String date;
  final int? steps;
  final int? activeCalories;
  final double? sleepHours;
  final double? weightKg;

  /// [BodyComposition] field name -> value.
  final Map<String, double> composition;
}

class ImportedWorkout {
  const ImportedWorkout({
    required this.uuid,
    required this.date,
    required this.activity,
    required this.minutes,
  });
  final String uuid;
  final String date;

  /// Health Connect activity name, e.g. RUNNING, WALKING, YOGA.
  final String activity;
  final double minutes;
}

class HealthImport {
  const HealthImport({
    required this.fromKey,
    required this.toKey,
    this.days = const [],
    this.workouts = const [],
  });

  /// Inclusive date-key window that was read. Imported workouts inside it
  /// are replaced, so a session deleted in Health Connect disappears too.
  final String fromKey;
  final String toKey;
  final List<HealthDay> days;
  final List<ImportedWorkout> workouts;

  bool covers(String key) =>
      key.compareTo(fromKey) >= 0 && key.compareTo(toKey) <= 0;
}

const healthConnectSource = 'health_connect';

/// Maps a Health Connect activity onto the app's MET table so imported
/// sessions use the same "active energy above rest" estimate as manual ones.
WorkoutType workoutTypeForActivity(String activity) {
  final a = activity.toUpperCase();
  String id;
  if (a.contains('WALK') || a.contains('HIK')) {
    id = 'walking_brisk';
  } else if (a.contains('RUN')) {
    id = 'running_easy';
  } else if (a.contains('BIK') || a.contains('CYCL')) {
    id = 'cycling_moderate';
  } else if (a.contains('STRENGTH') || a.contains('WEIGHT')) {
    id = 'strength_moderate';
  } else if (a.contains('YOGA') || a.contains('PILATES')) {
    id = 'yoga_general';
  } else if (a.contains('BADMINTON')) {
    id = 'badminton_social';
  } else if (a.contains('CRICKET')) {
    id = 'cricket_general';
  } else if (a.contains('SWIM')) {
    id = 'swimming_recreational';
  } else if (a.contains('HIGH_INTENSITY')) {
    id = 'hiit_moderate';
  } else if (a.contains('SOCCER') || a.contains('FOOTBALL')) {
    id = 'football_casual';
  } else if (a.contains('STAIR')) {
    id = 'stairs_general';
  } else if (a.contains('DANC')) {
    id = 'dance_general';
  } else {
    return const WorkoutType(
        id: 'imported_general', name: 'Workout', met: 4.0);
  }
  return WorkoutEngine.workoutTypes.firstWhere((t) => t.id == id,
      orElse: () =>
          const WorkoutType(id: 'imported_general', name: 'Workout', met: 4.0));
}

String prettyActivity(String activity) {
  final words = activity.toLowerCase().split('_').where((w) => w.isNotEmpty);
  final text = words.join(' ');
  return text.isEmpty ? 'Workout' : text[0].toUpperCase() + text.substring(1);
}

WorkoutEntry workoutFromImport(ImportedWorkout w, double weightKg) {
  final type = workoutTypeForActivity(w.activity);
  return WorkoutEntry(
    id: 'hc-${w.uuid}',
    date: w.date,
    typeId: type.id,
    typeName: '${prettyActivity(w.activity)} (Health Connect)',
    durationMinutes: w.minutes,
    met: type.met,
    caloriesBurned: WorkoutEngine.activeCalories(
        met: type.met, weightKg: weightKg, durationMinutes: w.minutes),
    source: healthConnectSource,
  );
}

/// Merges overlapping sleep intervals (several apps often record the same
/// night) and returns total hours per wake-up date.
Map<String, double> sleepHoursByWakeDate(
    List<(DateTime start, DateTime end)> sessions) {
  final sorted = sessions.where((s) => s.$2.isAfter(s.$1)).toList()
    ..sort((a, b) => a.$1.compareTo(b.$1));
  final merged = <(DateTime, DateTime)>[];
  for (final s in sorted) {
    if (merged.isNotEmpty && !s.$1.isAfter(merged.last.$2)) {
      final last = merged.removeLast();
      merged.add((last.$1, s.$2.isAfter(last.$2) ? s.$2 : last.$2));
    } else {
      merged.add(s);
    }
  }
  final result = <String, double>{};
  for (final s in merged) {
    final key = dateKey(s.$2.toLocal());
    result[key] =
        (result[key] ?? 0) + s.$2.difference(s.$1).inMinutes / 60.0;
  }
  return result.map((k, v) => MapEntry(k, (v * 10).round() / 10));
}
