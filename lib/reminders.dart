import 'dart:convert';

import 'models.dart';

/// One reminder toggle with a local time (minutes after midnight).
class ReminderToggle {
  const ReminderToggle({required this.enabled, required this.minutes});
  final bool enabled;
  final int minutes;
  ReminderToggle copyWith({bool? enabled, int? minutes}) => ReminderToggle(
      enabled: enabled ?? this.enabled, minutes: minutes ?? this.minutes);
  factory ReminderToggle.fromJson(Object? json, ReminderToggle fallback) {
    if (json is! Map) return fallback;
    return ReminderToggle(
        enabled: json['enabled'] as bool? ?? fallback.enabled,
        minutes:
            ((json['minutes'] as num?)?.round() ?? fallback.minutes).clamp(0, 1439));
  }
  Map<String, dynamic> toJson() => {'enabled': enabled, 'minutes': minutes};
}

/// Device-local reminder settings. They are not part of the diary backup:
/// each phone decides whether it may notify. Everything is off by default.
class ReminderSettings {
  const ReminderSettings({
    this.breakfast = const ReminderToggle(enabled: false, minutes: 9 * 60),
    this.lunch = const ReminderToggle(enabled: false, minutes: 13 * 60 + 30),
    this.dinner = const ReminderToggle(enabled: false, minutes: 20 * 60 + 30),
    this.evening = const ReminderToggle(enabled: false, minutes: 21 * 60 + 30),
    this.weighIn = const ReminderToggle(enabled: false, minutes: 7 * 60 + 30),
    this.fasting = const ReminderToggle(enabled: false, minutes: 20 * 60),
    this.supplements = false,
  });
  final ReminderToggle breakfast;
  final ReminderToggle lunch;
  final ReminderToggle dinner;

  /// "Fill today's log" nudge when the day looks incomplete.
  final ReminderToggle evening;
  final ReminderToggle weighIn;

  /// End-of-fast alert, plus a start reminder at [ReminderToggle.minutes]
  /// when no window is active.
  final ReminderToggle fasting;

  /// Master switch for per-supplement reminders.
  final bool supplements;

  bool get anyEnabled =>
      breakfast.enabled ||
      lunch.enabled ||
      dinner.enabled ||
      evening.enabled ||
      weighIn.enabled ||
      fasting.enabled ||
      supplements;

  ReminderToggle meal(String meal) => switch (meal) {
        'Breakfast' => breakfast,
        'Lunch' => lunch,
        _ => dinner,
      };

  ReminderSettings copyWith({
    ReminderToggle? breakfast,
    ReminderToggle? lunch,
    ReminderToggle? dinner,
    ReminderToggle? evening,
    ReminderToggle? weighIn,
    ReminderToggle? fasting,
    bool? supplements,
  }) =>
      ReminderSettings(
        breakfast: breakfast ?? this.breakfast,
        lunch: lunch ?? this.lunch,
        dinner: dinner ?? this.dinner,
        evening: evening ?? this.evening,
        weighIn: weighIn ?? this.weighIn,
        fasting: fasting ?? this.fasting,
        supplements: supplements ?? this.supplements,
      );

  /// The opt-in prompt turns on the three meal reminders and the evening nudge.
  ReminderSettings recommended() => copyWith(
        breakfast: breakfast.copyWith(enabled: true),
        lunch: lunch.copyWith(enabled: true),
        dinner: dinner.copyWith(enabled: true),
        evening: evening.copyWith(enabled: true),
        weighIn: weighIn.copyWith(enabled: true),
      );

  factory ReminderSettings.decode(String? raw) {
    const d = ReminderSettings();
    if (raw == null || raw.isEmpty) return d;
    try {
      final j = jsonDecode(raw) as Map<String, dynamic>;
      return ReminderSettings(
        breakfast: ReminderToggle.fromJson(j['breakfast'], d.breakfast),
        lunch: ReminderToggle.fromJson(j['lunch'], d.lunch),
        dinner: ReminderToggle.fromJson(j['dinner'], d.dinner),
        evening: ReminderToggle.fromJson(j['evening'], d.evening),
        weighIn: ReminderToggle.fromJson(j['weighIn'], d.weighIn),
        fasting: ReminderToggle.fromJson(j['fasting'], d.fasting),
        supplements: j['supplements'] as bool? ?? false,
      );
    } catch (_) {
      return d;
    }
  }

  String encode() => jsonEncode({
        'breakfast': breakfast.toJson(),
        'lunch': lunch.toJson(),
        'dinner': dinner.toJson(),
        'evening': evening.toJson(),
        'weighIn': weighIn.toJson(),
        'fasting': fasting.toJson(),
        'supplements': supplements,
      });
}

class PlannedReminder {
  const PlannedReminder({
    required this.id,
    required this.at,
    required this.title,
    required this.body,
  });
  final int id;
  final DateTime at;
  final String title;
  final String body;
  @override
  String toString() => 'PlannedReminder($id, $at, $title)';
}

/// Facts the planner needs. Built from AppState; kept plain for tests.
class ReminderInputs {
  const ReminderInputs({
    this.loggedMeals = const {},
    this.caloriesByDate = const {},
    this.calorieTarget = 2000,
    this.nextWeighIn,
    this.measurementsDue = false,
    this.fastingActive = false,
    this.fastingTargetAt,
    this.supplements = const [],
    this.supplementsTaken = const {},
  });

  /// dateKey -> meals with at least one entry.
  final Map<String, Set<String>> loggedMeals;
  final Map<String, double> caloriesByDate;
  final int calorieTarget;
  final DateTime? nextWeighIn;
  final bool measurementsDue;
  final bool fastingActive;
  final DateTime? fastingTargetAt;
  final List<Supplement> supplements;

  /// dateKey -> supplement ids ticked that day.
  final Map<String, Set<String>> supplementsTaken;
}

const _mealIds = {'Breakfast': 1, 'Lunch': 2, 'Dinner': 3};

/// True when the evening nudge should fire: fewer than two main meals or
/// under 40% of the calorie target logged.
bool dayLooksIncomplete(Set<String> meals, double calories, int target) {
  final mains = meals.where(_mealIds.containsKey).length;
  return mains < 2 || calories < target * .4;
}

/// Plans the next [days] days of reminders. Conditional reminders for today
/// are skipped once their condition is met (meal logged, supplement taken);
/// future days are planned optimistically and re-planned whenever the diary
/// changes or the app opens, so a missed app launch still gets reminders.
List<PlannedReminder> planReminders({
  required DateTime now,
  required ReminderSettings settings,
  required ReminderInputs inputs,
  int days = 3,
}) {
  final out = <PlannedReminder>[];
  final today = DateTime(now.year, now.month, now.day);
  DateTime at(DateTime day, int minutes) =>
      DateTime(day.year, day.month, day.day, minutes ~/ 60, minutes % 60);
  void add(int id, DateTime when, String title, String body) {
    if (when.isAfter(now)) {
      out.add(PlannedReminder(id: id, at: when, title: title, body: body));
    }
  }

  for (var offset = 0; offset < days; offset++) {
    final day = DateTime(today.year, today.month, today.day + offset);
    final key = dateKey(day);
    final logged = inputs.loggedMeals[key] ?? const <String>{};
    final base = 1000 + offset * 100;
    for (final meal in _mealIds.keys) {
      final toggle = settings.meal(meal);
      if (!toggle.enabled || logged.contains(meal)) continue;
      add(base + _mealIds[meal]!, at(day, toggle.minutes), 'Log your $meal',
          'A quick entry keeps today\'s plate honest. Tap to add $meal.');
    }
    if (settings.evening.enabled &&
        dayLooksIncomplete(
            logged, inputs.caloriesByDate[key] ?? 0, inputs.calorieTarget)) {
      add(base + 10, at(day, settings.evening.minutes), 'Fill in today\'s log',
          'Today looks incomplete. Add what you ate while you remember.');
    }
    if (settings.fasting.enabled && !inputs.fastingActive) {
      add(base + 20, at(day, settings.fasting.minutes), 'Start your fasting window?',
          'Your usual fasting start time. Open Saapadu to start the timer.');
    }
    if (settings.supplements) {
      final taken = inputs.supplementsTaken[key] ?? const <String>{};
      var i = 0;
      for (final s in inputs.supplements) {
        i++;
        if (s.archived || !s.reminderEnabled || taken.contains(s.id) || i > 40) {
          continue;
        }
        add(base + 50 + i, at(day, s.reminderMinutes), 'Time for ${s.name}',
            s.dose.isEmpty ? 'Tick it off on Today.' : '${s.dose} • tick it off on Today.');
      }
    }
  }

  if (settings.weighIn.enabled) {
    final due = inputs.nextWeighIn;
    var day = due == null || !due.isAfter(today) ? today : due;
    var when = at(day, settings.weighIn.minutes);
    if (!when.isAfter(now)) {
      day = DateTime(today.year, today.month, today.day + 1);
      when = at(day, settings.weighIn.minutes);
    }
    add(
        900,
        when,
        'Weekly check-in',
        inputs.measurementsDue
            ? 'Step on the scale, and measure waist, hip and chest too (every two weeks).'
            : 'Step on the scale to refresh your trend.');
  }
  if (settings.fasting.enabled &&
      inputs.fastingActive &&
      inputs.fastingTargetAt != null) {
    add(901, inputs.fastingTargetAt!.toLocal(), 'Fasting window complete',
        'You reached your target. End and save the window when you eat.');
  }
  out.sort((a, b) => a.at.compareTo(b.at));
  return out;
}
