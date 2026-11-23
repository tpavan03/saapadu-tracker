import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:health/health.dart';

import '../health_connect.dart';
import '../health_import.dart';
import '../models.dart';

HealthBridge createHealthBridge() =>
    !kIsWeb && Platform.isAndroid ? _AndroidHealthBridge() : const NoHealthBridge();

const _types = <HealthDataType>[
  HealthDataType.STEPS,
  HealthDataType.ACTIVE_ENERGY_BURNED,
  HealthDataType.WORKOUT,
  HealthDataType.SLEEP_SESSION,
  HealthDataType.WEIGHT,
  HealthDataType.BODY_FAT_PERCENTAGE,
  HealthDataType.LEAN_BODY_MASS,
  HealthDataType.BODY_WATER_MASS,
  HealthDataType.BASAL_ENERGY_BURNED,
];

class _AndroidHealthBridge extends HealthBridge {
  final Health _health = Health();
  bool _configured = false;

  Future<void> _configure() async {
    if (_configured) return;
    await _health.configure();
    _configured = true;
  }

  @override
  Future<HealthConnectAvailability> availability() async {
    try {
      await _configure();
      final status = await _health.getHealthConnectSdkStatus();
      return switch (status) {
        HealthConnectSdkStatus.sdkAvailable =>
          HealthConnectAvailability.available,
        HealthConnectSdkStatus.sdkUnavailableProviderUpdateRequired =>
          HealthConnectAvailability.needsInstall,
        _ => HealthConnectAvailability.unsupported,
      };
    } catch (_) {
      return HealthConnectAvailability.unsupported;
    }
  }

  @override
  Future<bool> requestAccess() async {
    try {
      await _configure();
      final all = await _health.requestAuthorization(_types,
          permissions: List.filled(_types.length, HealthDataAccess.READ));
      if (all) return true;
      // The user may allow only some types; sync whatever was granted.
      for (final type in _types) {
        if (await _health.hasPermissions([type],
                permissions: const [HealthDataAccess.READ]) ==
            true) {
          return true;
        }
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<bool> hasAccess() async {
    try {
      await _configure();
      return await _health.hasPermissions(_types,
              permissions: List.filled(_types.length, HealthDataAccess.READ)) ??
          false;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<void> openInstall() async {
    try {
      await _configure();
      await _health.installHealthConnect();
    } catch (_) {}
  }

  @override
  Future<HealthImport> read(DateTime from, DateTime to) async {
    await _configure();
    final start = DateTime(from.year, from.month, from.day);
    final end = to;
    final days = <String, _DayBuilder>{};
    _DayBuilder day(String key) => days.putIfAbsent(key, () => _DayBuilder());

    // Steps and active energy: daily aggregates, which Health Connect already
    // de-duplicates across apps by the user's priority list.
    for (var d = start; d.isBefore(end); d = d.add(const Duration(days: 1))) {
      final next = DateTime(d.year, d.month, d.day + 1);
      final key = dateKey(d);
      try {
        day(key).steps = await _health.getTotalStepsInInterval(
            d, next.isAfter(end) ? end : next);
      } catch (_) {}
    }
    await _safe(() async {
      final points = await _health.getHealthIntervalDataFromTypes(
          startDate: start,
          endDate: end,
          types: const [HealthDataType.ACTIVE_ENERGY_BURNED],
          interval: 86400);
      for (final p in points) {
        final v = _num(p);
        if (v == null) continue;
        final key = dateKey(p.dateFrom.toLocal());
        final b = day(key);
        b.active = (b.active ?? 0) + v.round();
      }
    });

    final sleepSessions = <(DateTime, DateTime)>[];
    final workouts = <ImportedWorkout>[];
    // Sleep sessions that end today can start the evening before.
    await _safe(() async {
      final points = await _health.getHealthDataFromTypes(
          types: const [HealthDataType.SLEEP_SESSION],
          startTime: start.subtract(const Duration(hours: 18)),
          endTime: end);
      for (final p in points) {
        sleepSessions.add((p.dateFrom, p.dateTo));
      }
    });
    await _safe(() async {
      final points = await _health.getHealthDataFromTypes(
          types: const [HealthDataType.WORKOUT], startTime: start, endTime: end);
      for (final p in _health.removeDuplicates(points)) {
        final v = p.value;
        final activity = v is WorkoutHealthValue
            ? v.workoutActivityType.name
            : 'OTHER';
        final minutes = p.dateTo.difference(p.dateFrom).inSeconds / 60.0;
        if (minutes <= 0) continue;
        workouts.add(ImportedWorkout(
            uuid: p.uuid,
            date: dateKey(p.dateFrom.toLocal()),
            activity: activity,
            minutes: minutes));
      }
    });
    // Body readings: keep the latest reading of each type per day.
    const bodyTypes = {
      HealthDataType.WEIGHT: 'weight',
      HealthDataType.BODY_FAT_PERCENTAGE: 'bodyFatPct',
      HealthDataType.LEAN_BODY_MASS: 'leanKg',
      HealthDataType.BODY_WATER_MASS: '_waterKg',
      HealthDataType.BASAL_ENERGY_BURNED: 'bmrKcal',
    };
    for (final entry in bodyTypes.entries) {
      await _safe(() async {
        final points = await _health.getHealthDataFromTypes(
            types: [entry.key], startTime: start, endTime: end);
        points.sort((a, b) => a.dateFrom.compareTo(b.dateFrom));
        for (final p in points) {
          final v = _num(p);
          if (v == null || v <= 0) continue;
          final b = day(dateKey(p.dateFrom.toLocal()));
          if (entry.value == 'weight') {
            b.weight = v.toDouble();
          } else {
            b.body[entry.value] = v.toDouble();
          }
        }
      });
    }

    final sleep = sleepHoursByWakeDate(sleepSessions);
    final startKey = dateKey(start);
    final endKey = dateKey(end);
    sleep.forEach((key, hours) {
      if (key.compareTo(startKey) >= 0 && key.compareTo(endKey) <= 0) {
        day(key).sleep = hours;
      }
    });
    return HealthImport(
      fromKey: startKey,
      toKey: endKey,
      days: [
        for (final e in days.entries)
          HealthDay(
            date: e.key,
            steps: e.value.steps,
            activeCalories: e.value.active,
            sleepHours: e.value.sleep,
            weightKg: e.value.weight,
            composition: e.value.composition(),
          )
      ],
      workouts: workouts,
    );
  }

  num? _num(HealthDataPoint p) {
    final v = p.value;
    return v is NumericHealthValue ? v.numericValue : null;
  }

  Future<void> _safe(Future<void> Function() body) async {
    try {
      await body();
    } catch (error) {
      // A missing permission for one type must not stop the others.
      debugPrint('Health Connect read skipped: $error');
    }
  }
}

class _DayBuilder {
  int? steps;
  int? active;
  double? sleep;
  double? weight;
  final Map<String, double> body = {};

  Map<String, double> composition() {
    final result = Map<String, double>.from(body)..remove('_waterKg');
    final waterKg = body['_waterKg'];
    if (waterKg != null && weight != null && weight! > 0) {
      result['waterPct'] = (waterKg / weight! * 1000).round() / 10;
    }
    return result;
  }
}
