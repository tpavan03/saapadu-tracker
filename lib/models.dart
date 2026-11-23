import 'dart:convert';

String dateKey(DateTime value) =>
    '${value.year.toString().padLeft(4, '0')}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';

class FoodItem {
  const FoodItem({
    required this.id,
    required this.name,
    required this.aliases,
    required this.category,
    required this.servingLabel,
    required this.servingGrams,
    required this.calories,
    required this.proteinG,
    required this.carbsG,
    required this.fatG,
    required this.fiberG,
    required this.sourceKey,
    this.isCustom = false,
  });

  final String id;
  final String name;
  final List<String> aliases;
  final String category;
  final String servingLabel;
  final double servingGrams;
  final double calories;
  final double proteinG;
  final double carbsG;
  final double fatG;
  final double fiberG;
  final String sourceKey;
  final bool isCustom;

  factory FoodItem.fromJson(Map<String, dynamic> json) => FoodItem(
        id: json['id'] as String,
        name: json['name'] as String,
        aliases: List<String>.from(json['aliases'] ?? const []),
        category: json['category'] as String? ?? 'Other',
        servingLabel: json['servingLabel'] as String? ?? '1 serving',
        servingGrams: (json['servingGrams'] as num?)?.toDouble() ?? 0,
        calories: (json['calories'] as num).toDouble(),
        proteinG: (json['proteinG'] as num?)?.toDouble() ?? 0,
        carbsG: (json['carbsG'] as num?)?.toDouble() ?? 0,
        fatG: (json['fatG'] as num?)?.toDouble() ?? 0,
        fiberG: (json['fiberG'] as num?)?.toDouble() ?? 0,
        sourceKey: json['sourceKey'] as String? ?? 'estimate',
        isCustom: json['isCustom'] as bool? ?? false,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'aliases': aliases,
        'category': category,
        'servingLabel': servingLabel,
        'servingGrams': servingGrams,
        'calories': calories,
        'proteinG': proteinG,
        'carbsG': carbsG,
        'fatG': fatG,
        'fiberG': fiberG,
        'sourceKey': sourceKey,
        'isCustom': isCustom,
      };
}

class FoodLog {
  const FoodLog({
    required this.id,
    required this.date,
    required this.meal,
    required this.food,
    required this.servings,
  });

  final String id;
  final String date;
  final String meal;
  final FoodItem food;
  final double servings;

  double get calories => food.calories * servings;
  double get protein => food.proteinG * servings;
  double get carbs => food.carbsG * servings;
  double get fat => food.fatG * servings;
  double get fiber => food.fiberG * servings;

  factory FoodLog.fromJson(Map<String, dynamic> json) => FoodLog(
        id: json['id'] as String,
        date: json['date'] as String,
        meal: json['meal'] as String,
        food: FoodItem.fromJson(json['food'] as Map<String, dynamic>),
        servings: (json['servings'] as num).toDouble(),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'date': date,
        'meal': meal,
        'food': food.toJson(),
        'servings': servings,
      };
}

class Profile {
  const Profile({
    required this.name,
    required this.sex,
    required this.birthYear,
    required this.heightCm,
    required this.currentWeightKg,
    required this.goalWeightKg,
    required this.activityLevel,
    required this.weeklyGoalKg,
    this.addExerciseCalories = true,
    this.manualCalorieTarget,
    this.goalDate,
  });

  final String name;
  final String sex;
  final int birthYear;
  final double heightCm;
  final double currentWeightKg;
  final double goalWeightKg;
  final String activityLevel;
  final double weeklyGoalKg;
  final bool addExerciseCalories;
  final int? manualCalorieTarget;
  final DateTime? goalDate;

  Profile copyWith({
    String? name,
    String? sex,
    int? birthYear,
    double? heightCm,
    double? currentWeightKg,
    double? goalWeightKg,
    String? activityLevel,
    double? weeklyGoalKg,
    bool? addExerciseCalories,
    Object? manualCalorieTarget = _notProvided,
    Object? goalDate = _notProvided,
  }) =>
      Profile(
        name: name ?? this.name,
        sex: sex ?? this.sex,
        birthYear: birthYear ?? this.birthYear,
        heightCm: heightCm ?? this.heightCm,
        currentWeightKg: currentWeightKg ?? this.currentWeightKg,
        goalWeightKg: goalWeightKg ?? this.goalWeightKg,
        activityLevel: activityLevel ?? this.activityLevel,
        weeklyGoalKg: weeklyGoalKg ?? this.weeklyGoalKg,
        addExerciseCalories: addExerciseCalories ?? this.addExerciseCalories,
        manualCalorieTarget: identical(manualCalorieTarget, _notProvided)
            ? this.manualCalorieTarget
            : manualCalorieTarget as int?,
        goalDate: identical(goalDate, _notProvided)
            ? this.goalDate
            : goalDate as DateTime?,
      );

  factory Profile.fromJson(Map<String, dynamic> j) => Profile(
        name: j['name'] as String,
        sex: j['sex'] as String,
        birthYear: j['birthYear'] as int,
        heightCm: (j['heightCm'] as num).toDouble(),
        currentWeightKg: (j['currentWeightKg'] as num).toDouble(),
        goalWeightKg: (j['goalWeightKg'] as num).toDouble(),
        activityLevel: j['activityLevel'] as String,
        weeklyGoalKg: (j['weeklyGoalKg'] as num).toDouble(),
        addExerciseCalories: j['addExerciseCalories'] as bool? ?? true,
        manualCalorieTarget: (j['manualCalorieTarget'] as num?)?.round(),
        goalDate: _tryParseDate(j['goalDate']),
      );

  Map<String, dynamic> toJson() => {
        'name': name,
        'sex': sex,
        'birthYear': birthYear,
        'heightCm': heightCm,
        'currentWeightKg': currentWeightKg,
        'goalWeightKg': goalWeightKg,
        'activityLevel': activityLevel,
        'weeklyGoalKg': weeklyGoalKg,
        'addExerciseCalories': addExerciseCalories,
        'manualCalorieTarget': manualCalorieTarget,
        'goalDate': goalDate == null ? null : dateKey(goalDate!),
      };
}

const Object _notProvided = Object();

DateTime? _tryParseDate(Object? value) {
  if (value is! String) return null;
  return DateTime.tryParse(value);
}

class DailyWellness {
  const DailyWellness({
    required this.date,
    this.waterMl = 0,
    this.sleepHours = 0,
    this.steps = 0,
    this.exerciseCalories = 0,
    this.note = '',
    this.baseCalorieTarget,
    this.proteinTarget,
    this.carbsTarget,
    this.fatTarget,
    this.fiberTarget,
    this.waterSet = false,
    this.importedSteps,
    this.importedActiveCalories,
    this.importedSleepHours,
  });

  final String date;

  /// Stored water. On days that use the 4 L default (see [WaterDefaults]) a
  /// value only counts when [waterSet] is true or it is above zero.
  final int waterMl;
  final double sleepHours;
  final int steps;
  final int exerciseCalories;
  final String note;
  final int? baseCalorieTarget;
  final double? proteinTarget;
  final double? carbsTarget;
  final double? fatTarget;
  final double? fiberTarget;

  /// True once the user edited water for this day in v2.1+. Older apps do not
  /// write this key, so its absence keeps every historical value unchanged.
  final bool waterSet;

  /// Values read from Health Connect. They are stored beside the manual
  /// fields and never overwrite them; a manual value above zero wins.
  final int? importedSteps;
  final int? importedActiveCalories;
  final double? importedSleepHours;

  int get effectiveSteps => steps > 0 ? steps : (importedSteps ?? 0);
  double get effectiveSleepHours =>
      sleepHours > 0 ? sleepHours : (importedSleepHours ?? 0);
  int get effectiveActiveCalories =>
      exerciseCalories > 0 ? exerciseCalories : (importedActiveCalories ?? 0);
  bool get stepsImported => steps <= 0 && (importedSteps ?? 0) > 0;
  bool get sleepImported => sleepHours <= 0 && (importedSleepHours ?? 0) > 0;
  bool get activeCaloriesImported =>
      exerciseCalories <= 0 && (importedActiveCalories ?? 0) > 0;

  DailyWellness copyWith({
    int? waterMl,
    double? sleepHours,
    int? steps,
    int? exerciseCalories,
    String? note,
    int? baseCalorieTarget,
    double? proteinTarget,
    double? carbsTarget,
    double? fatTarget,
    double? fiberTarget,
    bool? waterSet,
    int? importedSteps,
    int? importedActiveCalories,
    double? importedSleepHours,
  }) =>
      DailyWellness(
        date: date,
        waterMl: waterMl ?? this.waterMl,
        sleepHours: sleepHours ?? this.sleepHours,
        steps: steps ?? this.steps,
        exerciseCalories: exerciseCalories ?? this.exerciseCalories,
        note: note ?? this.note,
        baseCalorieTarget: baseCalorieTarget ?? this.baseCalorieTarget,
        proteinTarget: proteinTarget ?? this.proteinTarget,
        carbsTarget: carbsTarget ?? this.carbsTarget,
        fatTarget: fatTarget ?? this.fatTarget,
        fiberTarget: fiberTarget ?? this.fiberTarget,
        waterSet: waterSet ?? this.waterSet,
        importedSteps: importedSteps ?? this.importedSteps,
        importedActiveCalories:
            importedActiveCalories ?? this.importedActiveCalories,
        importedSleepHours: importedSleepHours ?? this.importedSleepHours,
      );

  factory DailyWellness.fromJson(Map<String, dynamic> j) => DailyWellness(
        date: j['date'] as String,
        waterMl: (j['waterMl'] as num?)?.round() ?? 0,
        sleepHours: (j['sleepHours'] as num?)?.toDouble() ?? 0,
        steps: (j['steps'] as num?)?.round() ?? 0,
        exerciseCalories: (j['exerciseCalories'] as num?)?.round() ?? 0,
        note: j['note'] as String? ?? '',
        baseCalorieTarget: (j['baseCalorieTarget'] as num?)?.round(),
        proteinTarget: (j['proteinTarget'] as num?)?.toDouble(),
        carbsTarget: (j['carbsTarget'] as num?)?.toDouble(),
        fatTarget: (j['fatTarget'] as num?)?.toDouble(),
        fiberTarget: (j['fiberTarget'] as num?)?.toDouble(),
        waterSet: j['waterSet'] as bool? ?? false,
        importedSteps: (j['importedSteps'] as num?)?.round(),
        importedActiveCalories: (j['importedActiveCalories'] as num?)?.round(),
        importedSleepHours: (j['importedSleepHours'] as num?)?.toDouble(),
      );

  // Older apps read waterMl/steps/exerciseCalories with `as int?`, so these
  // stay integers. New keys are only written when they carry information.
  Map<String, dynamic> toJson() => {
        'date': date,
        'waterMl': waterMl,
        'sleepHours': sleepHours,
        'steps': steps,
        'exerciseCalories': exerciseCalories,
        'note': note,
        'baseCalorieTarget': baseCalorieTarget,
        'proteinTarget': proteinTarget,
        'carbsTarget': carbsTarget,
        'fatTarget': fatTarget,
        'fiberTarget': fiberTarget,
        if (waterSet) 'waterSet': true,
        if (importedSteps != null) 'importedSteps': importedSteps,
        if (importedActiveCalories != null)
          'importedActiveCalories': importedActiveCalories,
        if (importedSleepHours != null)
          'importedSleepHours': importedSleepHours,
      };
}

/// Water defaults to 4 L only on days on/after the first launch of v2.1
/// ([startKey]). Earlier days always show exactly what was stored.
class WaterDefaults {
  const WaterDefaults._();
  static const int defaultMl = 4000;

  static int effective(DailyWellness? day, String dateKeyValue,
      {required String? startKey}) {
    final stored = day?.waterMl ?? 0;
    final usesDefault =
        startKey != null && dateKeyValue.compareTo(startKey) >= 0;
    if (!usesDefault) return stored;
    if (day != null && (day.waterSet || stored > 0)) return stored;
    return defaultMl;
  }

  static bool isDefault(DailyWellness? day, String dateKeyValue,
          {required String? startKey}) =>
      startKey != null &&
      dateKeyValue.compareTo(startKey) >= 0 &&
      !(day != null && (day.waterSet || day.waterMl > 0));
}

class WeightEntry {
  const WeightEntry({required this.date, required this.weightKg, this.source});
  final String date;
  final double weightKg;

  /// null for manual entries; 'health_connect' for imported readings.
  final String? source;
  bool get imported => source != null;
  factory WeightEntry.fromJson(Map<String, dynamic> j) => WeightEntry(
        date: j['date'] as String,
        weightKg: (j['weightKg'] as num).toDouble(),
        source: j['source'] as String?,
      );
  Map<String, dynamic> toJson() => {
        'date': date,
        'weightKg': weightKg,
        if (source != null) 'source': source,
      };
}

class WorkoutEntry {
  const WorkoutEntry({
    required this.id,
    required this.date,
    required this.typeId,
    required this.typeName,
    required this.durationMinutes,
    required this.met,
    required this.caloriesBurned,
    this.source,
  });

  final String id;
  final String date;
  final String typeId;
  final String typeName;
  final double durationMinutes;
  final double met;

  /// Active calories, excluding the energy that would have been spent at rest.
  final double caloriesBurned;

  /// null for manual workouts; 'health_connect' for imported sessions.
  final String? source;
  bool get imported => source != null;

  factory WorkoutEntry.fromJson(Map<String, dynamic> j) => WorkoutEntry(
        id: j['id'] as String,
        date: j['date'] as String,
        typeId: j['typeId'] as String,
        typeName: j['typeName'] as String,
        durationMinutes: (j['durationMinutes'] as num).toDouble(),
        met: (j['met'] as num).toDouble(),
        caloriesBurned: (j['caloriesBurned'] as num).toDouble(),
        source: j['source'] as String?,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'date': date,
        'typeId': typeId,
        'typeName': typeName,
        'durationMinutes': durationMinutes,
        'met': met,
        'caloriesBurned': caloriesBurned,
        if (source != null) 'source': source,
      };
}

class FastingState {
  const FastingState(
      {this.startedAt, this.targetHours = 12, this.history = const []});
  final DateTime? startedAt;
  final int targetHours;
  final List<FastSession> history;
  bool get isActive => startedAt != null;
  DateTime? get targetAt => startedAt?.add(Duration(hours: targetHours));
  Duration elapsedAt(DateTime now) =>
      startedAt == null || now.isBefore(startedAt!)
          ? Duration.zero
          : now.difference(startedAt!);
  factory FastingState.fromJson(Map<String, dynamic> j) => FastingState(
        startedAt: j['startedAt'] == null
            ? null
            : DateTime.parse(j['startedAt'] as String),
        targetHours: ((j['targetHours'] as num?)?.toInt() ?? 12).clamp(8, 20),
        history: (j['history'] as List? ?? const [])
            .map((item) =>
                FastSession.fromJson(Map<String, dynamic>.from(item as Map)))
            .toList(),
      );
  Map<String, dynamic> toJson() => {
        'startedAt': startedAt?.toIso8601String(),
        'targetHours': targetHours,
        'history': history.map((session) => session.toJson()).toList(),
      };
}

class FastSession {
  const FastSession(
      {required this.startedAt,
      required this.endedAt,
      required this.targetHours});
  final DateTime startedAt;
  final DateTime endedAt;
  final int targetHours;
  Duration get duration => endedAt.isBefore(startedAt)
      ? Duration.zero
      : endedAt.difference(startedAt);
  bool get targetReached => duration >= Duration(hours: targetHours);
  factory FastSession.fromJson(Map<String, dynamic> data) => FastSession(
      startedAt: DateTime.parse(data['startedAt'] as String),
      endedAt: DateTime.parse(data['endedAt'] as String),
      targetHours: (data['targetHours'] as num).toInt());
  Map<String, dynamic> toJson() => {
        'startedAt': startedAt.toUtc().toIso8601String(),
        'endedAt': endedAt.toUtc().toIso8601String(),
        'targetHours': targetHours
      };
}

List<T> decodeList<T>(String? value, T Function(Map<String, dynamic>) read) {
  if (value == null || value.isEmpty) return [];
  return (jsonDecode(value) as List)
      .map((e) => read(Map<String, dynamic>.from(e as Map)))
      .toList();
}

/// A saved set of foods ("my usual breakfast") logged together.
class MealCombo {
  const MealCombo({
    required this.id,
    required this.name,
    required this.meal,
    required this.items,
  });
  final String id;
  final String name;
  final String meal;
  final List<ComboItem> items;

  double get calories => items.fold(0, (s, i) => s + i.food.calories * i.servings);
  double get protein => items.fold(0, (s, i) => s + i.food.proteinG * i.servings);

  MealCombo copyWith({String? name, String? meal, List<ComboItem>? items}) =>
      MealCombo(
          id: id,
          name: name ?? this.name,
          meal: meal ?? this.meal,
          items: items ?? this.items);

  factory MealCombo.fromJson(Map<String, dynamic> j) => MealCombo(
        id: j['id'] as String,
        name: j['name'] as String? ?? 'My combo',
        meal: j['meal'] as String? ?? 'Breakfast',
        items: (j['items'] as List? ?? const [])
            .map((e) => ComboItem.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList(),
      );
  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'meal': meal,
        'items': items.map((e) => e.toJson()).toList(),
      };
}

class ComboItem {
  const ComboItem({required this.food, required this.servings});
  final FoodItem food;
  final double servings;
  factory ComboItem.fromJson(Map<String, dynamic> j) => ComboItem(
        food: FoodItem.fromJson(Map<String, dynamic>.from(j['food'] as Map)),
        servings: (j['servings'] as num?)?.toDouble() ?? 1,
      );
  Map<String, dynamic> toJson() => {'food': food.toJson(), 'servings': servings};
}

const supplementSlots = ['Morning', 'After workout', 'Night'];

class Supplement {
  const Supplement({
    required this.id,
    required this.name,
    this.dose = '',
    this.slot = 'Morning',
    this.calories = 0,
    this.proteinG = 0,
    this.reminderEnabled = false,
    this.reminderMinutes = 8 * 60,
    this.archived = false,
  });
  final String id;
  final String name;
  final String dose;
  final String slot;
  final double calories;
  final double proteinG;
  final bool reminderEnabled;

  /// Minutes after local midnight.
  final int reminderMinutes;

  /// Deleted supplements are archived so past tick-offs keep their name.
  final bool archived;

  Supplement copyWith({
    String? name,
    String? dose,
    String? slot,
    double? calories,
    double? proteinG,
    bool? reminderEnabled,
    int? reminderMinutes,
    bool? archived,
  }) =>
      Supplement(
        id: id,
        name: name ?? this.name,
        dose: dose ?? this.dose,
        slot: slot ?? this.slot,
        calories: calories ?? this.calories,
        proteinG: proteinG ?? this.proteinG,
        reminderEnabled: reminderEnabled ?? this.reminderEnabled,
        reminderMinutes: reminderMinutes ?? this.reminderMinutes,
        archived: archived ?? this.archived,
      );

  factory Supplement.fromJson(Map<String, dynamic> j) => Supplement(
        id: j['id'] as String,
        name: j['name'] as String? ?? 'Supplement',
        dose: j['dose'] as String? ?? '',
        slot: j['slot'] as String? ?? 'Morning',
        calories: (j['calories'] as num?)?.toDouble() ?? 0,
        proteinG: (j['proteinG'] as num?)?.toDouble() ?? 0,
        reminderEnabled: j['reminderEnabled'] as bool? ?? false,
        reminderMinutes: (j['reminderMinutes'] as num?)?.round() ?? 8 * 60,
        archived: j['archived'] as bool? ?? false,
      );
  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'dose': dose,
        'slot': slot,
        'calories': calories,
        'proteinG': proteinG,
        'reminderEnabled': reminderEnabled,
        'reminderMinutes': reminderMinutes,
        'archived': archived,
      };
}

/// A tick-off fact. Energy and protein are copied at the time it was taken so
/// later edits to the supplement never change a past day's totals.
class SupplementIntake {
  const SupplementIntake({
    required this.date,
    required this.supplementId,
    required this.name,
    this.calories = 0,
    this.proteinG = 0,
  });
  final String date;
  final String supplementId;
  final String name;
  final double calories;
  final double proteinG;
  factory SupplementIntake.fromJson(Map<String, dynamic> j) => SupplementIntake(
        date: j['date'] as String,
        supplementId: j['supplementId'] as String,
        name: j['name'] as String? ?? '',
        calories: (j['calories'] as num?)?.toDouble() ?? 0,
        proteinG: (j['proteinG'] as num?)?.toDouble() ?? 0,
      );
  Map<String, dynamic> toJson() => {
        'date': date,
        'supplementId': supplementId,
        'name': name,
        'calories': calories,
        'proteinG': proteinG,
      };
}

/// Optional tape measurements and smart-scale readings for one date. This is
/// a parallel record so older apps, which only know [WeightEntry], keep
/// reading weights unchanged. Health Connect values are listed in
/// [importedFields]; a manual edit removes a field from that set and wins.
class BodyComposition {
  const BodyComposition({
    required this.date,
    this.values = const {},
    this.importedFields = const {},
  });
  final String date;
  final Map<String, double> values;
  final Set<String> importedFields;

  static const fields = <String, (String label, String unit)>{
    'waistCm': ('Waist', 'cm'),
    'hipCm': ('Hip', 'cm'),
    'chestCm': ('Chest', 'cm'),
    'bodyFatPct': ('Body fat', '%'),
    'muscleKg': ('Muscle mass', 'kg'),
    'boneKg': ('Bone mass', 'kg'),
    'waterPct': ('Body water', '%'),
    'visceralFat': ('Visceral fat', 'rating'),
    'bmrKcal': ('BMR', 'kcal'),
    'metabolicAge': ('Metabolic age', 'years'),
    'leanKg': ('Lean body mass', 'kg'),
  };
  static const tapeFields = {'waistCm', 'hipCm', 'chestCm'};

  double? operator [](String field) => values[field];
  bool get isEmpty => values.isEmpty;
  bool get hasTape => values.keys.any(tapeFields.contains);

  BodyComposition withManual(Map<String, double?> changes) {
    final next = Map<String, double>.from(values);
    final imported = Set<String>.from(importedFields);
    changes.forEach((field, value) {
      if (!fields.containsKey(field)) return;
      imported.remove(field);
      if (value == null || !value.isFinite || value <= 0) {
        next.remove(field);
      } else {
        next[field] = value;
      }
    });
    return BodyComposition(date: date, values: next, importedFields: imported);
  }

  /// Imported values fill empty fields or replace earlier imports only.
  BodyComposition withImported(Map<String, double> changes) {
    final next = Map<String, double>.from(values);
    final imported = Set<String>.from(importedFields);
    changes.forEach((field, value) {
      if (!fields.containsKey(field) || !value.isFinite || value <= 0) return;
      if (next.containsKey(field) && !imported.contains(field)) return;
      next[field] = value;
      imported.add(field);
    });
    return BodyComposition(date: date, values: next, importedFields: imported);
  }

  factory BodyComposition.fromJson(Map<String, dynamic> j) {
    final values = <String, double>{};
    for (final field in fields.keys) {
      final v = (j[field] as num?)?.toDouble();
      if (v != null) values[field] = v;
    }
    return BodyComposition(
      date: j['date'] as String,
      values: values,
      importedFields: {
        for (final f in (j['importedFields'] as List? ?? const []))
          if (f is String) f
      },
    );
  }
  Map<String, dynamic> toJson() => {
        'date': date,
        ...values,
        if (importedFields.isNotEmpty)
          'importedFields': (importedFields.toList()..sort()),
      };
}
