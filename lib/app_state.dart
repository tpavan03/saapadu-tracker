import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'calorie_engine.dart';
import 'cloud_sync_service.dart';
import 'models.dart';

class AppState extends ChangeNotifier {
  AppState({required this.cloud}) {
    cloud.addListener(_onCloudChanged);
  }

  final CloudSyncService cloud;
  SharedPreferences? _prefs;
  bool _reconcilingCloud = false;
  int _cloudRevision = 0;
  DateTime lastChangedAt = DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
  bool ready = false;
  Profile? profile;
  List<FoodItem> foods = [];
  List<FoodItem> customFoods = [];
  List<FoodLog> logs = [];
  List<WorkoutEntry> workouts = [];
  List<WeightEntry> weights = [];
  Map<String, DailyWellness> wellness = {};
  FastingState fasting = const FastingState();
  DateTime selectedDate = DateTime.now();

  Future<void> initialize() async {
    _prefs = await SharedPreferences.getInstance();
    lastChangedAt = DateTime.tryParse(
          _prefs!.getString('last_changed_at') ?? '',
        )?.toUtc() ??
        DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
    final rawFoods = await rootBundle.loadString(
      'assets/data/south_indian_foods.json',
    );
    foods = (jsonDecode(rawFoods) as List)
        .map((e) => FoodItem.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
    final rawProfile = _prefs!.getString('profile');
    if (rawProfile != null) {
      profile =
          Profile.fromJson(jsonDecode(rawProfile) as Map<String, dynamic>);
    }
    logs = decodeList(_prefs!.getString('food_logs'), FoodLog.fromJson);
    workouts = decodeList(
      _prefs!.getString('workouts'),
      WorkoutEntry.fromJson,
    );
    customFoods = decodeList(
      _prefs!.getString('custom_foods'),
      FoodItem.fromJson,
    );
    weights = decodeList(_prefs!.getString('weights'), WeightEntry.fromJson);
    final dayList = decodeList(
      _prefs!.getString('wellness'),
      DailyWellness.fromJson,
    );
    wellness = {for (final day in dayList) day.date: day};
    final rawFasting = _prefs!.getString('fasting');
    if (rawFasting != null) {
      fasting = FastingState.fromJson(
        jsonDecode(rawFasting) as Map<String, dynamic>,
      );
    }
    ready = true;
    notifyListeners();
    if (cloud.authorized) {
      await _switchCloudUserIfNeeded();
      await _reconcileCloud();
    }
  }

  List<FoodItem> get allFoods => [...customFoods, ...foods];
  String get selectedKey => dateKey(selectedDate);
  List<FoodLog> get selectedLogs =>
      logs.where((entry) => entry.date == selectedKey).toList();
  List<WorkoutEntry> get selectedWorkouts =>
      workouts.where((entry) => entry.date == selectedKey).toList();
  DailyWellness get selectedWellness =>
      wellness[selectedKey] ?? DailyWellness(date: selectedKey);

  double get caloriesEaten =>
      selectedLogs.fold(0, (sum, entry) => sum + entry.calories);
  double get proteinEaten =>
      selectedLogs.fold(0, (sum, entry) => sum + entry.protein);
  double get carbsEaten =>
      selectedLogs.fold(0, (sum, entry) => sum + entry.carbs);
  double get fatEaten => selectedLogs.fold(0, (sum, entry) => sum + entry.fat);
  double get fiberEaten =>
      selectedLogs.fold(0, (sum, entry) => sum + entry.fiber);

  int get _calculatedBaseTarget => profile == null
      ? 2000
      : CalorieEngine.dailyTarget(
          profile!.addExerciseCalories
              ? profile!.copyWith(activityLevel: 'Sedentary')
              : profile!,
        );
  CaloriePlanRecommendation get planRecommendation {
    final p = profile;
    if (p == null) {
      return CalorieEngine.planRecommendation(
        const Profile(
          name: 'Guest',
          sex: 'Male',
          birthYear: 1990,
          heightCm: 170,
          currentWeightKg: 70,
          goalWeightKg: 70,
          activityLevel: 'Sedentary',
          weeklyGoalKg: 0,
        ),
      );
    }
    final planningProfile = p.addExerciseCalories
        ? p.copyWith(activityLevel: 'Sedentary')
        : p;
    return CalorieEngine.planRecommendation(planningProfile);
  }

  DateTime? get projectedGoalDate => planRecommendation.projectedGoalDate;

  int get baseCalorieTarget =>
      selectedWellness.baseCalorieTarget ?? _calculatedBaseTarget;
  int get workoutCalories => selectedWorkouts.fold(
      0, (sum, entry) => sum + entry.caloriesBurned.round());
  int get exerciseCalories {
    if (profile == null || !profile!.addExerciseCalories) return 0;
    final day = selectedWellness;
    final stepEstimate =
        CalorieEngine.stepCalories(day.steps, profile!.currentWeightKg);
    // A watch total, workout estimate, and steps can describe the same movement.
    // Use the largest source instead of summing overlapping estimates.
    final activeEstimate = [day.exerciseCalories, workoutCalories, stepEstimate]
        .reduce((a, b) => a > b ? a : b);
    return (activeEstimate * .5).round();
  }

  int get adjustedCalorieTarget => baseCalorieTarget + exerciseCalories;
  int get calorieRemaining => adjustedCalorieTarget - caloriesEaten.round();
  double get _calculatedProteinTarget => profile == null
      ? 90
      : (profile!.currentWeightKg *
          (profile!.goalWeightKg < profile!.currentWeightKg ? 1.6 : 1.3));
  double get proteinTarget =>
      selectedWellness.proteinTarget ?? _calculatedProteinTarget;
  double get _calculatedFatTarget => adjustedCalorieTarget * .28 / 9;
  double get fatTarget => selectedWellness.fatTarget ?? _calculatedFatTarget;
  double get _calculatedCarbsTarget => ((adjustedCalorieTarget -
              _calculatedProteinTarget * 4 -
              _calculatedFatTarget * 9) /
          4)
      .clamp(50, 500);
  double get carbsTarget =>
      selectedWellness.carbsTarget ?? _calculatedCarbsTarget;
  double get _calculatedFiberTarget => profile?.sex == 'Male' ? 30 : 25;
  double get fiberTarget =>
      selectedWellness.fiberTarget ?? _calculatedFiberTarget;

  Future<void> saveProfile(Profile value) async {
    profile = value;
    if (weights.isEmpty) {
      weights.add(
        WeightEntry(
            date: dateKey(DateTime.now()), weightKg: value.currentWeightKg),
      );
      await _persistWeights();
    }
    await _refreshTodayTargetSnapshot();
    await _prefs!.setString('profile', jsonEncode(value.toJson()));
    await _recordChange();
  }

  void setSelectedDate(DateTime value) {
    selectedDate = DateTime(value.year, value.month, value.day);
    notifyListeners();
  }

  Future<void> addFood(FoodItem food, double servings, String meal) async {
    await _ensureTargetSnapshot();
    logs.add(
      FoodLog(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        date: selectedKey,
        meal: meal,
        food: food,
        servings: servings,
      ),
    );
    await _persistLogs();
    await _recordChange();
  }

  Future<void> deleteFood(String id) async {
    logs.removeWhere((entry) => entry.id == id);
    await _persistLogs();
    await _recordChange();
  }

  Future<void> addCustomFood(FoodItem food) async {
    customFoods.insert(0, food);
    await _prefs!.setString(
      'custom_foods',
      jsonEncode(customFoods.map((e) => e.toJson()).toList()),
    );
    await _recordChange();
  }

  Future<void> updateWellness(DailyWellness value) async {
    wellness[value.date] = _withTargetSnapshot(value);
    await _prefs!.setString(
      'wellness',
      jsonEncode(wellness.values.map((e) => e.toJson()).toList()),
    );
    await _recordChange();
  }

  Future<void> logWeight(double kg) async {
    final today = dateKey(DateTime.now());
    weights.removeWhere((entry) => entry.date == today);
    weights.add(WeightEntry(date: today, weightKg: kg));
    weights.sort((a, b) => a.date.compareTo(b.date));
    if (profile != null) {
      profile = profile!.copyWith(currentWeightKg: kg);
      await _prefs!.setString('profile', jsonEncode(profile!.toJson()));
      await _refreshTodayTargetSnapshot();
    }
    await _persistWeights();
    await _recordChange();
  }

  Future<void> startFast(int hours) async {
    fasting = FastingState(startedAt: DateTime.now(), targetHours: hours);
    await _persistFasting();
    await _recordChange();
  }

  Future<void> stopFast() async {
    fasting = FastingState(targetHours: fasting.targetHours);
    await _persistFasting();
    await _recordChange();
  }

  Future<void> setFastingTarget(int hours) async {
    fasting = FastingState(startedAt: fasting.startedAt, targetHours: hours);
    await _persistFasting();
    await _recordChange();
  }

  Future<void> addWorkout(WorkoutEntry entry) async {
    workouts.add(entry);
    await _ensureTargetSnapshot();
    await _persistWorkouts();
    await _recordChange();
  }

  Future<void> deleteWorkout(String id) async {
    workouts.removeWhere((entry) => entry.id == id);
    await _persistWorkouts();
    await _recordChange();
  }

  Future<void> clearAllData() async {
    await _prefs!.clear();
    profile = null;
    customFoods = [];
    logs = [];
    workouts = [];
    weights = [];
    wellness = {};
    fasting = const FastingState();
    selectedDate = DateTime.now();
    notifyListeners();
  }

  Map<String, dynamic> exportBackupMap() => {
        'format': 'saapadu-backup-v1',
        'exportedAt': DateTime.now().toUtc().toIso8601String(),
        'lastChangedAt': lastChangedAt.toIso8601String(),
        'profile': profile?.toJson(),
        'foodLogs': logs.map((e) => e.toJson()).toList(),
        'workouts': workouts.map((e) => e.toJson()).toList(),
        'customFoods': customFoods.map((e) => e.toJson()).toList(),
        'weights': weights.map((e) => e.toJson()).toList(),
        'wellness': wellness.values.map((e) => e.toJson()).toList(),
        'fasting': fasting.toJson(),
      };

  String exportBackup() =>
      const JsonEncoder.withIndent('  ').convert(exportBackupMap());

  Future<void> importBackup(String value) async {
    final data = Map<String, dynamic>.from(jsonDecode(value) as Map);
    if (data['format'] != 'saapadu-backup-v1') {
      throw const FormatException('This is not a Saapadu backup.');
    }
    await _restoreBackupMap(data, fromCloud: false);
  }

  Future<void> _restoreBackupMap(
    Map<String, dynamic> data, {
    required bool fromCloud,
  }) async {
    final restoredProfile = Profile.fromJson(
      Map<String, dynamic>.from(data['profile'] as Map),
    );
    final restoredLogs = (data['foodLogs'] as List? ?? const [])
        .map((e) => FoodLog.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
    final restoredCustom = (data['customFoods'] as List? ?? const [])
        .map((e) => FoodItem.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
    final restoredWorkouts = (data['workouts'] as List? ?? const [])
        .map((e) => WorkoutEntry.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
    final restoredWeights = (data['weights'] as List? ?? const [])
        .map((e) => WeightEntry.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
    final restoredWellness = (data['wellness'] as List? ?? const [])
        .map((e) => DailyWellness.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
    profile = restoredProfile;
    logs = restoredLogs;
    customFoods = restoredCustom;
    workouts = restoredWorkouts;
    weights = restoredWeights;
    wellness = {for (final day in restoredWellness) day.date: day};
    fasting = FastingState.fromJson(
      Map<String, dynamic>.from(data['fasting'] as Map? ?? const {}),
    );
    await Future.wait([
      _prefs!.setString('profile', jsonEncode(profile!.toJson())),
      _persistLogs(),
      _persistWeights(),
      _persistWorkouts(),
      _persistFasting(),
      _prefs!.setString('custom_foods',
          jsonEncode(customFoods.map((e) => e.toJson()).toList())),
      _prefs!.setString('wellness',
          jsonEncode(wellness.values.map((e) => e.toJson()).toList())),
    ]);
    if (fromCloud) {
      lastChangedAt = DateTime.tryParse(
            data['lastChangedAt'] as String? ?? '',
          )?.toUtc() ??
          DateTime.now().toUtc();
      await _prefs!.setString(
        'last_changed_at',
        lastChangedAt.toIso8601String(),
      );
      notifyListeners();
    } else {
      await _recordChange();
    }
  }

  Future<void> _persistLogs() => _prefs!.setString(
        'food_logs',
        jsonEncode(logs.map((e) => e.toJson()).toList()),
      );
  Future<void> _persistWeights() => _prefs!.setString(
        'weights',
        jsonEncode(weights.map((e) => e.toJson()).toList()),
      );
  Future<void> _persistWorkouts() => _prefs!.setString(
        'workouts',
        jsonEncode(workouts.map((e) => e.toJson()).toList()),
      );
  Future<void> _persistFasting() =>
      _prefs!.setString('fasting', jsonEncode(fasting.toJson()));

  DailyWellness _withTargetSnapshot(DailyWellness value) {
    if (value.baseCalorieTarget != null) return value;
    return value.copyWith(
      baseCalorieTarget: _calculatedBaseTarget,
      proteinTarget: _calculatedProteinTarget,
      carbsTarget: _calculatedCarbsTarget,
      fatTarget: _calculatedFatTarget,
      fiberTarget: _calculatedFiberTarget,
    );
  }

  /// Recalculate today's live plan after a profile or weight change while
  /// leaving older diary days frozen for honest historical comparisons.
  Future<void> _refreshTodayTargetSnapshot() async {
    if (profile == null || _prefs == null) return;
    final today = dateKey(DateTime.now());
    final current = wellness[today] ?? DailyWellness(date: today);
    wellness[today] = current.copyWith(
      baseCalorieTarget: _calculatedBaseTarget,
      proteinTarget: _calculatedProteinTarget,
      carbsTarget: _calculatedCarbsTarget,
      fatTarget: _calculatedFatTarget,
      fiberTarget: _calculatedFiberTarget,
    );
    await _prefs!.setString(
      'wellness',
      jsonEncode(wellness.values.map((e) => e.toJson()).toList()),
    );
  }

  Future<void> _ensureTargetSnapshot() async {
    final current = selectedWellness;
    if (current.baseCalorieTarget != null) return;
    wellness[selectedKey] = _withTargetSnapshot(current);
    await _prefs!.setString(
      'wellness',
      jsonEncode(wellness.values.map((e) => e.toJson()).toList()),
    );
  }

  Future<void> _recordChange() async {
    lastChangedAt = DateTime.now().toUtc();
    await _prefs!.setString(
      'last_changed_at',
      lastChangedAt.toIso8601String(),
    );
    notifyListeners();
    cloud.scheduleUpload(_uploadCloudNow);
  }

  Future<void> _uploadCloudNow() async {
    if (!cloud.authorized || profile == null) return;
    _cloudRevision += 1;
    await cloud.uploadBackup(exportBackupMap(), revision: _cloudRevision);
  }

  void _onCloudChanged() {
    notifyListeners();
    if (ready && cloud.authorized) {
      unawaited(_switchCloudUserIfNeeded());
    }
  }

  Future<void> _switchCloudUserIfNeeded() async {
    final userId = cloud.user?.id;
    if (userId == null || _prefs == null) return;
    final storedUserId = _prefs!.getString('cloud_user_id');
    if (storedUserId != null && storedUserId != userId) {
      // A second account on the same browser must never inherit the first
      // account's local diary while its cloud backup is being restored.
      profile = null;
      customFoods = [];
      logs = [];
      workouts = [];
      weights = [];
      wellness = {};
      fasting = const FastingState();
      selectedDate = DateTime.now();
      await Future.wait([
        _prefs!.remove('profile'),
        _prefs!.remove('custom_foods'),
        _prefs!.remove('food_logs'),
        _prefs!.remove('workouts'),
        _prefs!.remove('weights'),
        _prefs!.remove('wellness'),
        _prefs!.remove('fasting'),
      ]);
    }
    await _prefs!.setString('cloud_user_id', userId);
    notifyListeners();
    await _reconcileCloud();
  }

  Future<void> _reconcileCloud() async {
    if (_reconcilingCloud || !cloud.authorized) return;
    _reconcilingCloud = true;
    try {
      final remote = await cloud.fetchBackup();
      if (remote == null) {
        if (profile != null) await _uploadCloudNow();
        return;
      }
      _cloudRevision = remote.revision;
      final remoteChangedAt = DateTime.tryParse(
            remote.payload['lastChangedAt'] as String? ?? '',
          )?.toUtc() ??
          remote.updatedAt;
      if (profile == null || remoteChangedAt.isAfter(lastChangedAt)) {
        await _restoreBackupMap(remote.payload, fromCloud: true);
      } else if (lastChangedAt.isAfter(remoteChangedAt)) {
        await _uploadCloudNow();
      }
    } catch (_) {
      // Local logging remains available; a later auth/network event retries.
    } finally {
      _reconcilingCloud = false;
    }
  }

  @override
  void dispose() {
    cloud.removeListener(_onCloudChanged);
    super.dispose();
  }
}
