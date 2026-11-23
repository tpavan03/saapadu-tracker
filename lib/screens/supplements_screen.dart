import 'package:flutter/material.dart';

import '../app_state.dart';
import '../insights.dart';
import '../models.dart';
import '../theme.dart';
import 'reminder_settings_screen.dart';

class SupplementsScreen extends StatelessWidget {
  const SupplementsScreen({super.key, required this.state});
  final AppState state;

  static Future<void> open(BuildContext context, AppState state) =>
      Navigator.of(context).push(MaterialPageRoute<void>(
          builder: (_) => SupplementsScreen(state: state)));

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: state,
        builder: (context, _) {
          final today = DateTime.now();
          final items = state.activeSupplements;
          return Scaffold(
            appBar: AppBar(title: const Text('Supplements')),
            floatingActionButton: FloatingActionButton.extended(
                onPressed: () => _edit(context, null),
                icon: const Icon(Icons.add),
                label: const Text('Add')),
            body: SafeArea(
              child: Align(
                alignment: Alignment.topCenter,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 720),
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(18, 18, 18, 96),
                    children: [
                      const Text(
                          'Tick them off on Today. Items with calories or protein (whey, a protein bar) add to that day\'s totals, unless the same item is also logged as a food.',
                          style: TextStyle(color: AppColors.muted)),
                      const SizedBox(height: 16),
                      if (items.isEmpty)
                        const Card(
                            child: Padding(
                                padding: EdgeInsets.all(20),
                                child: Text('No supplements yet.'))),
                      for (final s in items)
                        Builder(builder: (context) {
                          final stats = supplementStats(
                              s.id, state.supplementIntakes, today);
                          return Card(
                            child: ListTile(
                              onTap: () => _edit(context, s),
                              title: Text(s.name,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w800)),
                              subtitle: Text([
                                s.slot,
                                if (s.dose.isNotEmpty) s.dose,
                                if (s.calories > 0 || s.proteinG > 0)
                                  '${s.calories.round()} kcal · ${s.proteinG.round()} g protein',
                                'Streak ${stats.streak} days · taken ${stats.takenDays} of ${stats.monthDays} days this month',
                                if (s.reminderEnabled)
                                  'Reminder ${_time(s.reminderMinutes)}',
                              ].join('\n')),
                              isThreeLine: true,
                              trailing: const Icon(Icons.edit_outlined),
                            ),
                          );
                        }),
                      if (items.any((s) => s.reminderEnabled) &&
                          !state.reminderSettings.supplements)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: TextButton.icon(
                              onPressed: () =>
                                  ReminderSettingsScreen.open(context, state),
                              icon: const Icon(Icons.notifications_none),
                              label: const Text(
                                  'Supplement reminders are off in Reminders')),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      );

  static String _time(int minutes) =>
      '${(minutes ~/ 60).toString().padLeft(2, '0')}:${(minutes % 60).toString().padLeft(2, '0')}';

  Future<void> _edit(BuildContext context, Supplement? existing) async {
    final name = TextEditingController(text: existing?.name ?? '');
    final dose = TextEditingController(text: existing?.dose ?? '');
    final kcal = TextEditingController(
        text: existing == null ? '0' : ServingMath.format(existing.calories));
    final protein = TextEditingController(
        text: existing == null ? '0' : ServingMath.format(existing.proteinG));
    var slot = existing?.slot ?? 'Morning';
    var reminder = existing?.reminderEnabled ?? false;
    var minutes = existing?.reminderMinutes ?? 8 * 60;
    final result = await showDialog<String>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialog) => AlertDialog(
          title: Text(existing == null ? 'Add supplement' : 'Edit supplement'),
          content: SizedBox(
            width: 480,
            child: SingleChildScrollView(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                TextField(
                    controller: name,
                    autofocus: existing == null,
                    decoration: const InputDecoration(labelText: 'Name')),
                const SizedBox(height: 10),
                TextField(
                    controller: dose,
                    decoration: const InputDecoration(
                        labelText: 'Dose', hintText: 'e.g. 1 tablet, 1 scoop')),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  initialValue: slot,
                  decoration: const InputDecoration(labelText: 'When'),
                  items: supplementSlots
                      .map((v) => DropdownMenuItem(value: v, child: Text(v)))
                      .toList(),
                  onChanged: (v) => setDialog(() => slot = v!),
                ),
                const SizedBox(height: 10),
                Row(children: [
                  Expanded(
                      child: TextField(
                          controller: kcal,
                          keyboardType: const TextInputType.numberWithOptions(
                              decimal: true),
                          decoration: const InputDecoration(
                              labelText: 'kcal per dose'))),
                  const SizedBox(width: 10),
                  Expanded(
                      child: TextField(
                          controller: protein,
                          keyboardType: const TextInputType.numberWithOptions(
                              decimal: true),
                          decoration: const InputDecoration(
                              labelText: 'Protein g'))),
                ]),
                const SizedBox(height: 6),
                const Text('Leave 0 for pills and vitamins.',
                    style: TextStyle(color: AppColors.muted, fontSize: 11)),
                SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Reminder'),
                    subtitle: Text(reminder ? _time(minutes) : 'Off'),
                    value: reminder,
                    onChanged: (v) => setDialog(() => reminder = v)),
                if (reminder)
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                        onPressed: () async {
                          final picked = await showTimePicker(
                              context: context,
                              initialTime: TimeOfDay(
                                  hour: minutes ~/ 60, minute: minutes % 60));
                          if (picked != null) {
                            setDialog(() =>
                                minutes = picked.hour * 60 + picked.minute);
                          }
                        },
                        icon: const Icon(Icons.schedule),
                        label: const Text('Change time')),
                  ),
              ]),
            ),
          ),
          actions: [
            if (existing != null)
              TextButton(
                  onPressed: () => Navigator.pop(context, 'delete'),
                  child: const Text('Remove')),
            TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel')),
            FilledButton(
                onPressed: () {
                  if (name.text.trim().isEmpty) return;
                  Navigator.pop(context, 'save');
                },
                child: const Text('Save')),
          ],
        ),
      ),
    );
    if (result == 'delete' && existing != null) {
      await state.removeSupplement(existing.id);
    } else if (result == 'save') {
      final value = (existing ??
              Supplement(
                  id: 'sup-${DateTime.now().microsecondsSinceEpoch}',
                  name: name.text.trim()))
          .copyWith(
        name: name.text.trim(),
        dose: dose.text.trim(),
        slot: slot,
        calories: (double.tryParse(kcal.text) ?? 0).clamp(0, 2000).toDouble(),
        proteinG:
            (double.tryParse(protein.text) ?? 0).clamp(0, 200).toDouble(),
        reminderEnabled: reminder,
        reminderMinutes: minutes,
      );
      await state.saveSupplement(value);
      if (reminder && !state.reminderSettings.supplements) {
        await state.reminderScheduler.requestPermission();
        await state.saveReminderSettings(
            state.reminderSettings.copyWith(supplements: true));
      }
    }
    // Controllers are left to GC: the dialog may still be animating out.
  }
}
