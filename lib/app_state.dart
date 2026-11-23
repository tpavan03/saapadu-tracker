import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'calorie_engine.dart';
import 'cloud_sync_service.dart';
import 'health_connect.dart';
import 'health_import.dart';
import 'insights.dart';
import 'models.dart';
import 'reminder_service.dart';
import 'reminders.dart';
import 'weight_trend.dart';

class AppState extends ChangeNotifier {
  AppState({
    required this.cloud,
    HealthBridge? health,
    ReminderScheduler? reminderScheduler,
  })  : health = health ?? const NoHealthBridge(),
        reminderScheduler = reminderScheduler ?? const ReminderScheduler() {
    cloud.addListener(_onCloudChanged);
  }

  final CloudSyncService cloud;

  /// Read-only Health Connect bridge (no-op on web and in tests).
  final HealthBridge health;

  /// Local notification scheduler (no-op on web and in tests).
  final ReminderScheduler reminderScheduler;
  SharedPreferences? _prefs;
  final Set<String> _reconcilingCloudUsers = {};
  String? _switchingCloudUserId;
  String? _restoringCloudUserId;
  String? _firstLinkPendingUserId;
  String? _retainedGuestBackup;
  bool _restoringLinkedBackup = false;
  bool get cloudRestoring => _restoringCloudUserId != null;
  String? get retainedGuestBackup => _retainedGuestBackup;
  bool get guestLinkPending =>
      _firstLinkPendingUserId == cloud.user?.id &&
      _firstLinkPendingUserId != null;
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

  // v2.1 additions. Each is stored under its own preference and backup key,
  // so older apps simply ignore them.
  List<MealCombo> combos = [];
  List<Supplement> supplements = [];
  List<SupplementIntake> supplementIntakes = [];
  Map<String, BodyComposition> bodyComposition = {};

  /// First day that counts 4 L water by default (first launch of v2.1 on
  /// this diary). Days before it keep exactly their stored water.
  String? waterDefaultStart;

  // Device-local settings (not in the diary backup).
  ReminderSettings reminderSettings = const ReminderSettings();
  bool reminderPromptDismissed = false;
  Set<String> dismissedNudges = {};
  bool healthConnectEnabled = false;
  DateTime? healthLastSync;
  bool healthSyncing = false;
  String? healthMessage;

  Future<void> initialize() async {
    _prefs = await SharedPreferences.getInstance();
    _retainedGuestBackup = _prefs!.getString('pending_guest_backup');
    _firstLinkPendingUserId = _prefs!.getString('guest_link_pending_user_id');
    lastChangedAt = DateTime.tryParse(
          _prefs!.getString('last_changed_at') ?? '',
        )?.toUtc() ??
        DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
    // Decode on this isolate: loadString() hands files over 50 KB to
    // compute(), and the food table is now larger than that.
    final rawFoods = utf8.decode((await rootBundle.load(
      'assets/data/south_indian_foods.json',
    ))
        .buffer
        .asUint8List());
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
    _loadV21();
    await _ensureWaterDefaultStart();
    if (cloud.authorized) {
      // Local data opens immediately. A different owner is cleared inside the
      // switch before its first await; blank accounts expose cloudRestoring.
      unawaited(_switchCloudUserIfNeeded());
    }
    ready = true;
    notifyListeners();
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
      selectedLogs.fold<double>(0, (sum, entry) => sum + entry.calories) +
      countedIntakesFor(selectedKey)
          .fold<double>(0, (sum, intake) => sum + intake.calories);
  double get proteinEaten =>
      selectedLogs.fold<double>(0, (sum, entry) => sum + entry.protein) +
      countedIntakesFor(selectedKey)
          .fold<double>(0, (sum, intake) => sum + intake.proteinG);
  double get carbsEaten =>
      selectedLogs.fold(0, (sum, entry) => sum + entry.carbs);
  double get fatEaten => selectedLogs.fold(0, (sum, entry) => sum + entry.fat);
  double get fiberEaten =>
      selectedLogs.fold(0, (sum, entry) => sum + entry.fiber);

  int get _calculatedBaseTarget => profile == null
      ? 2000
      : CalorieEngine.dailyTarget(
          profile!.addExerciseCalories
              ? profile!.copyWith(activityLevel: 'Sedentary', goalDate: null)
              : profile!.copyWith(goalDate: null),
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
    // The requested deadline is an intention, not a reason to increase the
    // deficit after a slow week. Only an explicit plan edit changes the pace.
    final planningProfile = p.addExerciseCalories
        ? p.copyWith(activityLevel: 'Sedentary', goalDate: null)
        : p.copyWith(goalDate: null);
    return CalorieEngine.planRecommendation(planningProfile);
  }

  WeightForecast get weightForecast => WeightTrend.forecast(profile!, weights,
      modelDate: planRecommendation.projectedGoalDate);
  DateTime? get projectedGoalDate =>
      profile == null ? null : weightForecast.estimatedDate;
  DateTime? get nextWeightCheckInDate {
    final last = WeightTrend.latestReadingDate(weights);
    return last?.add(const Duration(days: 7));
  }

  bool get weightCheckInDue {
    final due = nextWeightCheckInDate;
    final now = DateTime.now();
    return due == null || !DateTime(now.year, now.month, now.day).isBefore(due);
  }

  int get baseCalorieTarget =>
      selectedWellness.baseCalorieTarget ?? _calculatedBaseTarget;
  int get workoutCalories => workoutCaloriesFor(selectedKey);

  /// Manual workouts win: imported Health Connect sessions only count on a
  /// day without manual workouts, so one session logged twice is not summed.
  int workoutCaloriesFor(String key) {
    final day = workouts.where((entry) => entry.date == key);
    final manual = day
        .where((e) => !e.imported)
        .fold<int>(0, (sum, entry) => sum + entry.caloriesBurned.round());
    if (manual > 0) return manual;
    return day
        .where((e) => e.imported)
        .fold<int>(0, (sum, entry) => sum + entry.caloriesBurned.round());
  }

  int get exerciseCalories => exerciseCaloriesFor(selectedKey);
  int exerciseCaloriesFor(String key) {
    if (profile == null || !profile!.addExerciseCalories) return 0;
    final day = wellness[key] ?? DailyWellness(date: key);
    final stepEstimate = CalorieEngine.stepCalories(
        day.effectiveSteps, profile!.currentWeightKg);
    // A watch total, workout estimate, and steps can describe the same movement.
    // Use the largest source instead of summing overlapping estimates.
    final activeEstimate = [
      day.effectiveActiveCalories,
      workoutCaloriesFor(key),
      stepEstimate
    ].reduce((a, b) => a > b ? a : b);
    return (activeEstimate * .5).round();
  }

  int get adjustedCalorieTarget => baseCalorieTarget + exerciseCalories;
  int get calorieRemaining => adjustedCalorieTarget - caloriesEaten.round();

  // ---- Per-day reads (computed, never stored copies) ----

  List<FoodLog> logsFor(String key) =>
      logs.where((entry) => entry.date == key).toList();

  /// Supplement tick-offs that add to a day's totals. An intake is skipped
  /// when the same item is also in that day's food log, so it is not counted
  /// twice.
  List<SupplementIntake> countedIntakesFor(String key) {
    final intakes = supplementIntakes.where((i) => i.date == key).toList();
    if (intakes.isEmpty) return intakes;
    final foodNames = {
      for (final log in logs)
        if (log.date == key) log.food.name.trim().toLowerCase()
    };
    return intakes
        .where((i) => !foodNames.contains(i.name.trim().toLowerCase()))
        .toList();
  }

  bool supplementAlsoLoggedAsFood(String key, Supplement s) =>
      logs.any((log) =>
          log.date == key &&
          log.food.name.trim().toLowerCase() == s.name.trim().toLowerCase());

  double caloriesFor(String key) =>
      logsFor(key).fold<double>(0, (s, e) => s + e.calories) +
      countedIntakesFor(key).fold<double>(0, (s, i) => s + i.calories);
  double proteinFor(String key) =>
      logsFor(key).fold<double>(0, (s, e) => s + e.protein) +
      countedIntakesFor(key).fold<double>(0, (s, i) => s + i.proteinG);
  int targetFor(String key) =>
      (wellness[key]?.baseCalorieTarget ?? _calculatedBaseTarget) +
      exerciseCaloriesFor(key);

  double mealProtein(String key, String meal) => logs
      .where((e) => e.date == key && e.meal == meal)
      .fold<double>(0, (s, e) => s + e.protein);

  int get loggingStreakDays => loggingStreak(logs, DateTime.now());

  WeeklySummary weeklySummaryFor(DateTime today) => weeklySummary(
        today: today,
        weights: weights,
        factsFor: (key) => DayFacts(
          calories: caloriesFor(key),
          protein: proteinFor(key),
          target: targetFor(key),
          steps: (wellness[key] ?? DailyWellness(date: key)).effectiveSteps,
          logged: logs.any((e) => e.date == key),
        ),
      );

  // ---- Water: 4 L default from the v2.1 start date ----

  int waterFor(String key) =>
      WaterDefaults.effective(wellness[key], key, startKey: waterDefaultStart);
  int get selectedWater => waterFor(selectedKey);
  bool get selectedWaterIsDefault => WaterDefaults.isDefault(
      wellness[selectedKey], selectedKey,
      startKey: waterDefaultStart);
  bool get selectedDayUsesWaterDefault =>
      waterDefaultStart != null &&
      selectedKey.compareTo(waterDefaultStart!) >= 0;

  Future<void> setWater(int ml) => updateWellness(selectedWellness.copyWith(
      waterMl: ml.clamp(0, 10000), waterSet: true));

  Future<void> adjustWater(int deltaMl) => setWater(selectedWater + deltaMl);

  /// Back to "unset": the default applies again on/after the start date.
  Future<void> resetWater() => updateWellness(
      _copyWater(selectedWellness, waterMl: 0, waterSet: false));

  DailyWellness _copyWater(DailyWellness d,
          {required int waterMl, required bool waterSet}) =>
      DailyWellness(
        date: d.date,
        waterMl: waterMl,
        sleepHours: d.sleepHours,
        steps: d.steps,
        exerciseCalories: d.exerciseCalories,
        note: d.note,
        baseCalorieTarget: d.baseCalorieTarget,
        proteinTarget: d.proteinTarget,
        carbsTarget: d.carbsTarget,
        fatTarget: d.fatTarget,
        fiberTarget: d.fiberTarget,
        waterSet: waterSet,
        importedSteps: d.importedSteps,
        importedActiveCalories: d.importedActiveCalories,
        importedSleepHours: d.importedSleepHours,
      );
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

  Future<void> saveProfile(Profile value, {DateTime? now}) async {
    final changedWeight =
        profile == null || profile!.currentWeightKg != value.currentWeightKg;
    profile = value;
    if (weights.isEmpty || changedWeight) {
      final today = dateKey(now ?? DateTime.now());
      weights.removeWhere((entry) => entry.date == today);
      weights.add(WeightEntry(date: today, weightKg: value.currentWeightKg));
      weights.sort((a, b) => a.date.compareTo(b.date));
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

  /// Edits the quantity of an existing entry; date, meal and food stay.
  Future<void> updateFoodServings(String id, double servings) async {
    final index = logs.indexWhere((entry) => entry.id == id);
    if (index < 0) return;
    final old = logs[index];
    logs[index] = FoodLog(
        id: old.id,
        date: old.date,
        meal: old.meal,
        food: old.food,
        servings: ServingMath.normalize(servings));
    await _persistLogs();
    await _recordChange();
  }

  /// Logs several foods to the selected day at once (combos, copied meals).
  Future<void> addFoods(List<(FoodItem, double)> items, String meal) async {
    if (items.isEmpty) return;
    await _ensureTargetSnapshot();
    final base = DateTime.now().microsecondsSinceEpoch;
    for (var i = 0; i < items.length; i++) {
      logs.add(FoodLog(
          id: '${base + i}',
          date: selectedKey,
          meal: meal,
          food: items[i].$1,
          servings: items[i].$2));
    }
    await _persistLogs();
    await _recordChange();
  }

  // ---- Quick logging ----

  /// Foods most recently logged, newest first, without repeats.
  List<FoodItem> recentFoods({int limit = 8}) {
    final sorted = [...logs]..sort((a, b) => b.id.compareTo(a.id));
    final seen = <String>{};
    final out = <FoodItem>[];
    for (final log in sorted) {
      if (seen.add(log.food.id)) out.add(log.food);
      if (out.length >= limit) break;
    }
    return out;
  }

  /// Foods logged most often over the last 60 days.
  List<FoodItem> frequentFoods({int limit = 8, DateTime? now}) {
    final today = now ?? DateTime.now();
    final since = dateKey(today.subtract(const Duration(days: 60)));
    final counts = <String, int>{};
    final byId = <String, FoodItem>{};
    for (final log in logs) {
      if (log.date.compareTo(since) < 0) continue;
      counts[log.food.id] = (counts[log.food.id] ?? 0) + 1;
      byId[log.food.id] = log.food;
    }
    final ids = counts.keys.where((id) => counts[id]! >= 2).toList()
      ..sort((a, b) {
        final c = counts[b]!.compareTo(counts[a]!);
        return c != 0 ? c : byId[a]!.name.compareTo(byId[b]!.name);
      });
    return ids.take(limit).map((id) => byId[id]!).toList();
  }

  List<FoodLog> mealEntries(String key, String meal) =>
      logs.where((e) => e.date == key && e.meal == meal).toList();

  Future<void> saveCombo(MealCombo combo) async {
    final i = combos.indexWhere((c) => c.id == combo.id);
    if (i >= 0) {
      combos[i] = combo;
    } else {
      combos.insert(0, combo);
    }
    await _persistList('combos', combos.map((e) => e.toJson()));
    await _recordChange();
  }

  Future<void> deleteCombo(String id) async {
    combos.removeWhere((c) => c.id == id);
    await _persistList('combos', combos.map((e) => e.toJson()));
    await _recordChange();
  }

  Future<void> logCombo(MealCombo combo, {String? meal}) => addFoods(
      [for (final item in combo.items) (item.food, item.servings)],
      meal ?? combo.meal);

  // ---- Supplements ----

  List<Supplement> get activeSupplements =>
      supplements.where((s) => !s.archived).toList();

  Future<void> saveSupplement(Supplement value) async {
    final i = supplements.indexWhere((s) => s.id == value.id);
    if (i >= 0) {
      supplements[i] = value;
    } else {
      supplements.add(value);
    }
    await _persistList('supplements', supplements.map((e) => e.toJson()));
    await _recordChange();
  }

  /// Archives instead of deleting so past tick-offs keep their meaning.
  Future<void> removeSupplement(String id) async {
    final i = supplements.indexWhere((s) => s.id == id);
    if (i < 0) return;
    await saveSupplement(supplements[i].copyWith(archived: true));
  }

  bool supplementTaken(String id, [String? key]) => supplementIntakes
      .any((i) => i.supplementId == id && i.date == (key ?? selectedKey));

  Future<void> toggleSupplement(String id, {String? key}) async {
    final day = key ?? selectedKey;
    if (supplementTaken(id, day)) {
      supplementIntakes
          .removeWhere((i) => i.supplementId == id && i.date == day);
    } else {
      final s = supplements.firstWhere((s) => s.id == id);
      supplementIntakes.add(SupplementIntake(
          date: day,
          supplementId: id,
          name: s.name,
          calories: s.calories,
          proteinG: s.proteinG));
    }
    await _persistList(
        'supplement_intakes', supplementIntakes.map((e) => e.toJson()));
    await _recordChange();
  }

  // ---- Body measurements and smart-scale readings ----

  List<BodyComposition> get bodyCompositionSorted =>
      bodyComposition.values.toList()..sort((a, b) => a.date.compareTo(b.date));

  bool get measurementsDue {
    final tape = bodyComposition.values.where((b) => b.hasTape).toList()
      ..sort((a, b) => a.date.compareTo(b.date));
    if (tape.isEmpty) return true;
    final last = DateTime.parse(tape.last.date);
    return DateTime.now().difference(last).inDays >= 14;
  }

  Future<void> saveBodyComposition(
      String key, Map<String, double?> changes) async {
    final current = bodyComposition[key] ?? BodyComposition(date: key);
    final next = current.withManual(changes);
    if (next.isEmpty) {
      bodyComposition.remove(key);
    } else {
      bodyComposition[key] = next;
    }
    await _persistBody();
    await _recordChange();
  }

  // ---- Health Connect (read-only import) ----

  /// Merges a Health Connect read. Imported values live in their own fields
  /// and records marked with [healthConnectSource]; manual values always win
  /// and are never modified. Days before [waterDefaultStart] (the v2.1
  /// start) are not touched, so pre-upgrade history keeps its values.
  Future<void> applyHealthImport(HealthImport data) async {
    final floor = waterDefaultStart;
    bool allowed(String key) => floor == null || key.compareTo(floor) >= 0;
    var weightChanged = false;
    for (final day in data.days) {
      if (!allowed(day.date)) continue;
      final current = wellness[day.date] ?? DailyWellness(date: day.date);
      wellness[day.date] = current.copyWith(
        importedSteps: day.steps,
        importedActiveCalories: day.activeCalories,
        importedSleepHours: day.sleepHours,
      );
      final kg = day.weightKg;
      if (kg != null && kg >= 30 && kg <= 350) {
        final existing = weights.where((w) => w.date == day.date).toList();
        if (existing.isEmpty || existing.every((w) => w.imported)) {
          weights.removeWhere((w) => w.date == day.date);
          weights.add(WeightEntry(
              date: day.date,
              weightKg: (kg * 10).round() / 10,
              source: healthConnectSource));
          weightChanged = true;
        }
      }
      if (day.composition.isNotEmpty) {
        final current =
            bodyComposition[day.date] ?? BodyComposition(date: day.date);
        bodyComposition[day.date] = current.withImported(day.composition);
      }
    }
    final weightKg = profile?.currentWeightKg ?? 70;
    workouts.removeWhere((w) => w.imported && data.covers(w.date) && allowed(w.date));
    final seen = <String>{};
    for (final w in data.workouts) {
      if (!allowed(w.date) || !data.covers(w.date) || !seen.add(w.uuid)) {
        continue;
      }
      workouts.add(workoutFromImport(w, weightKg));
    }
    if (weightChanged) {
      weights.sort((a, b) => a.date.compareTo(b.date));
      if (profile != null && weights.last.imported) {
        profile = profile!.copyWith(currentWeightKg: weights.last.weightKg);
        await _prefs!.setString('profile', jsonEncode(profile!.toJson()));
        await _refreshTodayTargetSnapshot();
      }
      await _persistWeights();
    }
    await Future.wait([
      _prefs!.setString('wellness',
          jsonEncode(wellness.values.map((e) => e.toJson()).toList())),
      _persistWorkouts(),
      _persistBody(),
    ]);
    await _recordChange();
  }

  Future<HealthConnectAvailability> healthAvailability() =>
      health.availability();

  Future<bool> connectHealthConnect() async {
    final granted = await health.requestAccess();
    healthConnectEnabled = granted;
    await _prefs!.setBool('health_connect_enabled', granted);
    healthMessage = granted
        ? null
        : 'Health Connect access was not granted. You can allow it from Health Connect settings.';
    notifyListeners();
    if (granted) await syncHealthConnect();
    return granted;
  }

  Future<void> disconnectHealthConnect() async {
    healthConnectEnabled = false;
    await _prefs!.setBool('health_connect_enabled', false);
    notifyListeners();
  }

  /// Reads the last 14 days (never earlier than the v2.1 start date).
  Future<void> syncHealthConnect({DateTime? now}) async {
    if (!healthConnectEnabled || healthSyncing || profile == null) return;
    healthSyncing = true;
    notifyListeners();
    try {
      final end = now ?? DateTime.now();
      var from = DateTime(end.year, end.month, end.day - 13);
      final floor = DateTime.tryParse(waterDefaultStart ?? '');
      if (floor != null && floor.isAfter(from)) from = floor;
      final data = await health.read(from, end);
      await applyHealthImport(data);
      healthLastSync = DateTime.now();
      healthMessage = null;
      await _prefs!
          .setString('health_last_sync', healthLastSync!.toIso8601String());
    } catch (_) {
      healthMessage =
          'Health Connect could not be read right now. Your diary is unchanged.';
    } finally {
      healthSyncing = false;
      notifyListeners();
    }
  }

  /// App opened or resumed: refresh imports and reminders.
  Future<void> onAppResumed() async {
    if (!ready) return;
    if (healthConnectEnabled) {
      // Import only after the cloud diary has been reconciled, so an
      // automatic import never makes a stale local copy look newer.
      if (await _waitForCloudIdle()) await syncHealthConnect();
    }
    await rescheduleReminders();
  }

  bool get _cloudBusy =>
      _switchingCloudUserId != null ||
      _reconcilingCloudUsers.isNotEmpty ||
      _restoringCloudUserId != null;

  Future<bool> _waitForCloudIdle() async {
    for (var i = 0; i < 40 && _cloudBusy; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 500));
    }
    return !_cloudBusy;
  }

  // ---- Reminders ----

  Future<void> saveReminderSettings(ReminderSettings value) async {
    reminderSettings = value;
    await _prefs!.setString('reminder_settings', value.encode());
    notifyListeners();
    await rescheduleReminders();
  }

  Future<void> dismissReminderPrompt() async {
    reminderPromptDismissed = true;
    await _prefs!.setBool('reminder_prompt_dismissed', true);
    notifyListeners();
  }

  bool get showReminderPrompt =>
      reminderScheduler.supported &&
      !reminderPromptDismissed &&
      !reminderSettings.anyEnabled;

  ReminderInputs reminderInputs() {
    final loggedMeals = <String, Set<String>>{};
    final calories = <String, double>{};
    final today = dateKey(DateTime.now());
    for (final log in logs) {
      if (log.date.compareTo(today) < 0) continue;
      loggedMeals.putIfAbsent(log.date, () => {}).add(log.meal);
      calories[log.date] = (calories[log.date] ?? 0) + log.calories;
    }
    final taken = <String, Set<String>>{};
    for (final i in supplementIntakes) {
      if (i.date.compareTo(today) < 0) continue;
      taken.putIfAbsent(i.date, () => {}).add(i.supplementId);
    }
    return ReminderInputs(
      loggedMeals: loggedMeals,
      caloriesByDate: calories,
      calorieTarget: targetFor(today),
      nextWeighIn: nextWeightCheckInDate,
      measurementsDue: measurementsDue,
      fastingActive: fasting.isActive,
      fastingTargetAt: fasting.targetAt,
      supplements: activeSupplements,
      supplementsTaken: taken,
    );
  }

  Timer? _reminderTimer;
  Future<void> rescheduleReminders() async {
    if (!reminderScheduler.supported || _prefs == null) return;
    final plan = reminderSettings.anyEnabled && profile != null
        ? planReminders(
            now: DateTime.now(),
            settings: reminderSettings,
            inputs: reminderInputs())
        : <PlannedReminder>[];
    await reminderScheduler.apply(plan);
  }

  void _scheduleReminderRefresh() {
    if (!reminderScheduler.supported) return;
    _reminderTimer?.cancel();
    _reminderTimer = Timer(const Duration(seconds: 2), rescheduleReminders);
  }

  Future<void> dismissNudge(String id) async {
    dismissedNudges.add(id);
    // Keep the list short: only the last few weeks matter.
    final cutoff = dateKey(DateTime.now().subtract(const Duration(days: 21)));
    dismissedNudges.removeWhere((n) => n.split('|').first.compareTo(cutoff) < 0);
    await _prefs!.setStringList('dismissed_nudges', dismissedNudges.toList());
    notifyListeners();
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

  Future<void> logWeight(double kg, {DateTime? date, DateTime? now}) async {
    final reference = now ?? DateTime.now();
    final readingDate = date ?? reference;
    final day = DateTime(readingDate.year, readingDate.month, readingDate.day);
    if (!kg.isFinite || kg < 30 || kg > 350) {
      throw const FormatException('Enter a weight between 30 and 350 kg.');
    }
    if (day.isAfter(DateTime(reference.year, reference.month, reference.day))) {
      throw const FormatException('A check-in cannot be dated in the future.');
    }
    final key = dateKey(day);
    weights.removeWhere((entry) => entry.date == key);
    weights.add(WeightEntry(date: key, weightKg: kg));
    weights.sort((a, b) => a.date.compareTo(b.date));
    if (profile != null) {
      profile = profile!.copyWith(currentWeightKg: weights.last.weightKg);
      await _prefs!.setString('profile', jsonEncode(profile!.toJson()));
      await _refreshTodayTargetSnapshot();
    }
    await _persistWeights();
    await _recordChange();
  }

  Future<void> startFast(int hours, {DateTime? now}) async {
    if (fasting.isActive) return;
    if (hours < 8 || hours > 20) {
      throw const FormatException('Choose a window between 8 and 20 hours.');
    }
    final p = profile;
    if (p != null &&
        ((DateTime.now().year - p.birthYear) < 18 ||
            CalorieEngine.bmi(p) < 18.5)) {
      throw const FormatException(
          'Ask a clinician before changing your meal timing.');
    }
    fasting = FastingState(
        startedAt: (now ?? DateTime.now()).toUtc(),
        targetHours: hours,
        history: fasting.history);
    await _persistFasting();
    await _recordChange();
  }

  Future<void> stopFast({DateTime? now}) async {
    if (!fasting.isActive) return;
    final end = (now ?? DateTime.now()).toUtc();
    final session = FastSession(
        startedAt: fasting.startedAt!,
        endedAt: end,
        targetHours: fasting.targetHours);
    fasting = FastingState(
        targetHours: fasting.targetHours,
        history: [session, ...fasting.history].take(200).toList());
    await _persistFasting();
    await _recordChange();
  }

  Future<void> setFastingTarget(int hours) async {
    if (fasting.isActive) return;
    if (hours < 8 || hours > 20) {
      throw const FormatException('Choose a window between 8 and 20 hours.');
    }
    fasting = FastingState(targetHours: hours, history: fasting.history);
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
    combos = [];
    supplements = [];
    supplementIntakes = [];
    bodyComposition = {};
    reminderSettings = const ReminderSettings();
    healthConnectEnabled = false;
    waterDefaultStart = null;
    await _ensureWaterDefaultStart();
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
        // v2.1 keys. Older apps ignore unknown keys; this format string stays
        // 'saapadu-backup-v1' because older apps reject any other value.
        'waterDefaultStart': waterDefaultStart,
        'combos': combos.map((e) => e.toJson()).toList(),
        'supplements': supplements.map((e) => e.toJson()).toList(),
        'supplementIntakes': supplementIntakes.map((e) => e.toJson()).toList(),
        'bodyComposition': bodyComposition.values.map((e) => e.toJson()).toList(),
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
    // A backup written by an older app has none of the v2.1 keys. Keep the
    // local values then, instead of wiping combos or supplements.
    List<T> readList<T>(String key, T Function(Map<String, dynamic>) read,
            List<T> keep) =>
        data.containsKey(key) && data[key] is List
            ? (data[key] as List)
                .map((e) => read(Map<String, dynamic>.from(e as Map)))
                .toList()
            : keep;
    combos = readList('combos', MealCombo.fromJson, combos);
    supplements = readList('supplements', Supplement.fromJson, supplements);
    supplementIntakes =
        readList('supplementIntakes', SupplementIntake.fromJson, supplementIntakes);
    if (data['bodyComposition'] is List) {
      bodyComposition = {
        for (final b in readList(
            'bodyComposition', BodyComposition.fromJson, <BodyComposition>[]))
          b.date: b
      };
    }
    final remoteStart = data['waterDefaultStart'];
    if (remoteStart is String &&
        DateTime.tryParse(remoteStart) != null &&
        (waterDefaultStart == null ||
            remoteStart.compareTo(waterDefaultStart!) < 0)) {
      waterDefaultStart = remoteStart;
      await _prefs!.setString('water_default_start', remoteStart);
    }
    await Future.wait([
      _persistList('combos', combos.map((e) => e.toJson())),
      _persistList('supplements', supplements.map((e) => e.toJson())),
      _persistList(
          'supplement_intakes', supplementIntakes.map((e) => e.toJson())),
      _persistBody(),
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
  Future<void> _persistList(String key, Iterable<Object?> items) =>
      _prefs!.setString(key, jsonEncode(items.toList()));
  Future<void> _persistBody() => _persistList(
      'body_composition', bodyComposition.values.map((e) => e.toJson()));

  void _loadV21() {
    final p = _prefs!;
    combos = decodeList(p.getString('combos'), MealCombo.fromJson);
    supplements = decodeList(p.getString('supplements'), Supplement.fromJson);
    supplementIntakes = decodeList(
        p.getString('supplement_intakes'), SupplementIntake.fromJson);
    bodyComposition = {
      for (final b
          in decodeList(p.getString('body_composition'), BodyComposition.fromJson))
        b.date: b
    };
    waterDefaultStart = p.getString('water_default_start');
    reminderSettings = ReminderSettings.decode(p.getString('reminder_settings'));
    reminderPromptDismissed = p.getBool('reminder_prompt_dismissed') ?? false;
    dismissedNudges = (p.getStringList('dismissed_nudges') ?? const []).toSet();
    healthConnectEnabled = p.getBool('health_connect_enabled') ?? false;
    healthLastSync = DateTime.tryParse(p.getString('health_last_sync') ?? '');
  }

  /// The first launch of v2.1 fixes the day the 4 L default starts. Saved
  /// once; never moved later, so a day that already used the default keeps it.
  Future<void> _ensureWaterDefaultStart({DateTime? now}) async {
    if (waterDefaultStart != null) return;
    waterDefaultStart = dateKey(now ?? DateTime.now());
    await _prefs!.setString('water_default_start', waterDefaultStart!);
  }

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
    if (guestLinkPending && profile != null && !_restoringLinkedBackup) {
      _retainedGuestBackup = exportBackup();
      await _prefs!.setString('pending_guest_backup', _retainedGuestBackup!);
    }
    notifyListeners();
    cloud.scheduleUpload(_uploadCloudNow);
    _scheduleReminderRefresh();
  }

  Future<void> _uploadCloudNow() async {
    if (!cloud.authorized || profile == null) return;
    // A newer anonymous diary is not permission to overwrite an existing
    // account. Keep changes locally until its first backup lookup succeeds.
    if (guestLinkPending) {
      if (!_restoringLinkedBackup) {
        _retainedGuestBackup = exportBackup();
        await _prefs!.setString('pending_guest_backup', _retainedGuestBackup!);
      }
      return;
    }
    _cloudRevision += 1;
    await cloud.uploadBackup(exportBackupMap(), revision: _cloudRevision);
  }

  void _onCloudChanged() {
    if (ready && cloud.authorized) {
      unawaited(_switchCloudUserIfNeeded());
    } else {
      notifyListeners();
    }
  }

  Future<void> _switchCloudUserIfNeeded() async {
    final userId = cloud.user?.id;
    if (userId == null || _prefs == null) return;
    if (_switchingCloudUserId == userId) return;
    _switchingCloudUserId = userId;
    try {
      final storedUserId = _prefs!.getString('cloud_user_id');
      if (storedUserId == null && profile != null && !guestLinkPending) {
        _firstLinkPendingUserId = userId;
        _retainedGuestBackup = exportBackup();
        _restoringCloudUserId = userId;
        // Hide the anonymous profile while resolving account ownership. Its
        // complete local payload is retained before any account data is loaded.
        profile = null;
        await _prefs!.setString('pending_guest_backup', _retainedGuestBackup!);
        await _prefs!.setString('guest_link_pending_user_id', userId);
      } else if (guestLinkPending) {
        profile = null;
        _restoringCloudUserId = userId;
      }
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
        combos = [];
        supplements = [];
        supplementIntakes = [];
        bodyComposition = {};
        selectedDate = DateTime.now();
        _cloudRevision = 0;
        lastChangedAt = DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
        _restoringCloudUserId = userId;
        await Future.wait([
          _prefs!.remove('profile'),
          _prefs!.remove('custom_foods'),
          _prefs!.remove('food_logs'),
          _prefs!.remove('workouts'),
          _prefs!.remove('weights'),
          _prefs!.remove('wellness'),
          _prefs!.remove('fasting'),
          _prefs!.remove('last_changed_at'),
          _prefs!.remove('combos'),
          _prefs!.remove('supplements'),
          _prefs!.remove('supplement_intakes'),
          _prefs!.remove('body_composition'),
        ]);
        // The new account's history starts its own default window; its cloud
        // backup can move this earlier on restore, never later.
        waterDefaultStart = dateKey(DateTime.now());
        await _prefs!.setString('water_default_start', waterDefaultStart!);
      }
      if (profile == null) _restoringCloudUserId = userId;
      await _prefs!.setString('cloud_user_id', userId);
      if (cloud.user?.id != userId) return;
      notifyListeners();
      await _reconcileCloud();
    } finally {
      if (_switchingCloudUserId == userId) _switchingCloudUserId = null;
      if (_restoringCloudUserId == userId) {
        _restoringCloudUserId = null;
        notifyListeners();
      }
    }
  }

  Future<void> _reconcileCloud() async {
    final owner = cloud.user?.id;
    if (!cloud.authorized ||
        owner == null ||
        _reconcilingCloudUsers.contains(owner)) {
      return;
    }
    _reconcilingCloudUsers.add(owner);
    try {
      final remote =
          await cloud.fetchBackup().timeout(const Duration(seconds: 12));
      if (!cloud.authorized || cloud.user?.id != owner) return;
      if (remote == null) {
        if (guestLinkPending) {
          await _restoreGuestDraftIfNeeded();
          await _completeFirstLink(owner);
        }
        if (profile != null) await _uploadCloudNow();
        return;
      }
      _cloudRevision = remote.revision;
      final remoteChangedAt = DateTime.tryParse(
            remote.payload['lastChangedAt'] as String? ?? '',
          )?.toUtc() ??
          remote.updatedAt;
      if (guestLinkPending ||
          profile == null ||
          remoteChangedAt.isAfter(lastChangedAt)) {
        _restoringLinkedBackup = guestLinkPending;
        try {
          await _restoreBackupMap(remote.payload, fromCloud: true);
          await _completeFirstLink(owner);
        } finally {
          _restoringLinkedBackup = false;
        }
      } else if (lastChangedAt.isAfter(remoteChangedAt)) {
        await _uploadCloudNow();
      }
    } catch (_) {
      // Local logging remains available; a later auth/network event retries.
      if (cloud.user?.id == owner && guestLinkPending) {
        await _restoreGuestDraftIfNeeded();
      }
    } finally {
      _reconcilingCloudUsers.remove(owner);
    }
  }

  Future<void> _restoreGuestDraftIfNeeded() async {
    if (profile != null || _retainedGuestBackup == null) return;
    _restoringLinkedBackup = true;
    try {
      final payload =
          Map<String, dynamic>.from(jsonDecode(_retainedGuestBackup!) as Map);
      await _restoreBackupMap(payload, fromCloud: true);
    } finally {
      _restoringLinkedBackup = false;
    }
  }

  Future<void> _completeFirstLink(String owner) async {
    if (_firstLinkPendingUserId != owner || cloud.user?.id != owner) return;
    await _prefs!.remove('guest_link_pending_user_id');
    _firstLinkPendingUserId = null;
  }

  @override
  void dispose() {
    _reminderTimer?.cancel();
    cloud.removeListener(_onCloudChanged);
    super.dispose();
  }
}
