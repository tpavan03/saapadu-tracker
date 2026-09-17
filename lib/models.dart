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
  });

  final String date;
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
      );

  factory DailyWellness.fromJson(Map<String, dynamic> j) => DailyWellness(
        date: j['date'] as String,
        waterMl: j['waterMl'] as int? ?? 0,
        sleepHours: (j['sleepHours'] as num?)?.toDouble() ?? 0,
        steps: j['steps'] as int? ?? 0,
        exerciseCalories: j['exerciseCalories'] as int? ?? 0,
        note: j['note'] as String? ?? '',
        baseCalorieTarget: (j['baseCalorieTarget'] as num?)?.round(),
        proteinTarget: (j['proteinTarget'] as num?)?.toDouble(),
        carbsTarget: (j['carbsTarget'] as num?)?.toDouble(),
        fatTarget: (j['fatTarget'] as num?)?.toDouble(),
        fiberTarget: (j['fiberTarget'] as num?)?.toDouble(),
      );

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
      };
}

class WeightEntry {
  const WeightEntry({required this.date, required this.weightKg});
  final String date;
  final double weightKg;
  factory WeightEntry.fromJson(Map<String, dynamic> j) => WeightEntry(
        date: j['date'] as String,
        weightKg: (j['weightKg'] as num).toDouble(),
      );
  Map<String, dynamic> toJson() => {'date': date, 'weightKg': weightKg};
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
  });

  final String id;
  final String date;
  final String typeId;
  final String typeName;
  final double durationMinutes;
  final double met;

  /// Active calories, excluding the energy that would have been spent at rest.
  final double caloriesBurned;

  factory WorkoutEntry.fromJson(Map<String, dynamic> j) => WorkoutEntry(
        id: j['id'] as String,
        date: j['date'] as String,
        typeId: j['typeId'] as String,
        typeName: j['typeName'] as String,
        durationMinutes: (j['durationMinutes'] as num).toDouble(),
        met: (j['met'] as num).toDouble(),
        caloriesBurned: (j['caloriesBurned'] as num).toDouble(),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'date': date,
        'typeId': typeId,
        'typeName': typeName,
        'durationMinutes': durationMinutes,
        'met': met,
        'caloriesBurned': caloriesBurned,
      };
}

class FastingState {
  const FastingState({this.startedAt, this.targetHours = 16});
  final DateTime? startedAt;
  final int targetHours;
  bool get isActive => startedAt != null;
  factory FastingState.fromJson(Map<String, dynamic> j) => FastingState(
        startedAt: j['startedAt'] == null
            ? null
            : DateTime.parse(j['startedAt'] as String),
        targetHours: j['targetHours'] as int? ?? 16,
      );
  Map<String, dynamic> toJson() => {
        'startedAt': startedAt?.toIso8601String(),
        'targetHours': targetHours,
      };
}

List<T> decodeList<T>(String? value, T Function(Map<String, dynamic>) read) {
  if (value == null || value.isEmpty) return [];
  return (jsonDecode(value) as List)
      .map((e) => read(Map<String, dynamic>.from(e as Map)))
      .toList();
}
