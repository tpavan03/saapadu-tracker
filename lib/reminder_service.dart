import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import 'reminders.dart';

/// Schedules local notifications. The default implementation does nothing,
/// which is what web and tests use.
class ReminderScheduler {
  const ReminderScheduler();
  bool get supported => false;
  Future<bool> requestPermission() async => false;
  Future<void> apply(List<PlannedReminder> reminders) async {}
}

/// Android notifications with inexact scheduling: no SCHEDULE_EXACT_ALARM.
class LocalNotificationScheduler extends ReminderScheduler {
  LocalNotificationScheduler();
  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  bool _ready = false;
  bool _failed = false;

  static ReminderScheduler platform() =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android
          ? LocalNotificationScheduler()
          : const ReminderScheduler();

  @override
  bool get supported => !_failed;

  Future<bool> _init() async {
    if (_ready) return true;
    if (_failed) return false;
    try {
      tzdata.initializeTimeZones();
      try {
        final zone = await FlutterTimezone.getLocalTimezone();
        tz.setLocalLocation(tz.getLocation(zone.identifier));
      } catch (_) {
        tz.setLocalLocation(tz.getLocation('Asia/Kolkata'));
      }
      await _plugin.initialize(
          settings: const InitializationSettings(
              android: AndroidInitializationSettings('@mipmap/ic_launcher')));
      _ready = true;
    } catch (error) {
      debugPrint('Reminders unavailable: $error');
      _failed = true;
    }
    return _ready;
  }

  @override
  Future<bool> requestPermission() async {
    if (!await _init()) return false;
    try {
      return await _plugin
              .resolvePlatformSpecificImplementation<
                  AndroidFlutterLocalNotificationsPlugin>()
              ?.requestNotificationsPermission() ??
          false;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<void> apply(List<PlannedReminder> reminders) async {
    if (!await _init()) return;
    try {
      await _plugin.cancelAllPendingNotifications();
      const details = NotificationDetails(
          android: AndroidNotificationDetails(
              'saapadu_reminders', 'Reminders',
              channelDescription: 'Meal, check-in, fasting and supplement reminders',
              importance: Importance.defaultImportance,
              priority: Priority.defaultPriority));
      for (final r in reminders) {
        await _plugin.zonedSchedule(
          id: r.id,
          scheduledDate: tz.TZDateTime.from(r.at, tz.local),
          notificationDetails: details,
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          title: r.title,
          body: r.body,
        );
      }
    } catch (error) {
      debugPrint('Could not schedule reminders: $error');
    }
  }
}
