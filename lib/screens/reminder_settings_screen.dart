import 'package:flutter/material.dart';

import '../app_state.dart';
import '../reminders.dart';
import '../theme.dart';

class ReminderSettingsScreen extends StatelessWidget {
  const ReminderSettingsScreen({super.key, required this.state});
  final AppState state;

  static Future<void> open(BuildContext context, AppState state) =>
      Navigator.of(context).push(MaterialPageRoute<void>(
          builder: (_) => ReminderSettingsScreen(state: state)));

  static String timeLabel(int minutes) =>
      '${(minutes ~/ 60).toString().padLeft(2, '0')}:${(minutes % 60).toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: state,
        builder: (context, _) {
          final r = state.reminderSettings;
          final supported = state.reminderScheduler.supported;
          return Scaffold(
            appBar: AppBar(title: const Text('Reminders')),
            body: SafeArea(
              child: Align(
                alignment: Alignment.topCenter,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 720),
                  child: ListView(padding: const EdgeInsets.all(18), children: [
                    Text(
                        supported
                            ? 'Reminders are gentle and skip themselves: a meal reminder does not fire once that meal is logged. Times are approximate so your battery is spared.'
                            : 'Reminders are available in the Android app.',
                        style: const TextStyle(color: AppColors.muted)),
                    const SizedBox(height: 14),
                    Card(
                      child: Column(children: [
                        _row(context, 'Breakfast', 'Only if breakfast is not logged',
                            r.breakfast, (v) => r.copyWith(breakfast: v)),
                        _row(context, 'Lunch', 'Only if lunch is not logged',
                            r.lunch, (v) => r.copyWith(lunch: v)),
                        _row(context, 'Dinner', 'Only if dinner is not logged',
                            r.dinner, (v) => r.copyWith(dinner: v)),
                        _row(
                            context,
                            'Evening check',
                            'If today\'s log looks incomplete',
                            r.evening,
                            (v) => r.copyWith(evening: v)),
                        _row(
                            context,
                            'Weekly weigh-in',
                            'On your check-in day; tape measurements every two weeks',
                            r.weighIn,
                            (v) => r.copyWith(weighIn: v)),
                        _row(
                            context,
                            'Fasting',
                            'Start reminder at this time, and an alert when the window completes',
                            r.fasting,
                            (v) => r.copyWith(fasting: v)),
                        SwitchListTile(
                          title: const Text('Supplements'),
                          subtitle: const Text(
                              'Uses each supplement\'s own reminder time; skipped once ticked'),
                          value: r.supplements,
                          onChanged: supported
                              ? (v) => _save(context, r.copyWith(supplements: v),
                                  enabling: v)
                              : null,
                        ),
                      ]),
                    ),
                  ]),
                ),
              ),
            ),
          );
        },
      );

  Widget _row(
          BuildContext context,
          String title,
          String subtitle,
          ReminderToggle toggle,
          ReminderSettings Function(ReminderToggle) apply) =>
      Column(children: [
        SwitchListTile(
          title: Text(title),
          subtitle: Text(subtitle),
          value: toggle.enabled,
          onChanged: state.reminderScheduler.supported
              ? (v) => _save(context, apply(toggle.copyWith(enabled: v)),
                  enabling: v)
              : null,
        ),
        if (toggle.enabled)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Align(
              alignment: Alignment.centerLeft,
              child: OutlinedButton.icon(
                onPressed: () async {
                  final picked = await showTimePicker(
                      context: context,
                      initialTime: TimeOfDay(
                          hour: toggle.minutes ~/ 60,
                          minute: toggle.minutes % 60));
                  if (picked != null) {
                    await state.saveReminderSettings(apply(toggle.copyWith(
                        minutes: picked.hour * 60 + picked.minute)));
                  }
                },
                icon: const Icon(Icons.schedule, size: 18),
                label: Text('Around ${timeLabel(toggle.minutes)}'),
              ),
            ),
          ),
        const Divider(height: 1),
      ]);

  Future<void> _save(BuildContext context, ReminderSettings next,
      {required bool enabling}) async {
    if (enabling) {
      final granted = await state.reminderScheduler.requestPermission();
      if (!granted && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text(
                'Notifications are blocked for Saapadu. Allow them in Android settings to receive reminders.')));
      }
    }
    await state.dismissReminderPrompt();
    await state.saveReminderSettings(next);
  }
}
