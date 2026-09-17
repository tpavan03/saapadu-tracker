import 'package:flutter/material.dart';

import '../app_state.dart';
import '../models.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../workout_engine.dart';

class WorkoutScreen extends StatelessWidget {
  const WorkoutScreen({super.key, required this.state});
  final AppState state;

  @override
  Widget build(BuildContext context) => PageFrame(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'MOVEMENT LOG',
                      style: TextStyle(
                        fontSize: 11,
                        letterSpacing: 1.2,
                        fontWeight: FontWeight.w900,
                        color: AppColors.leaf,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text('Workouts & activity',
                        style: Theme.of(context).textTheme.headlineMedium),
                  ],
                ),
              ),
              DateNavigator(state: state),
            ]),
            const SizedBox(height: 22),
            Container(
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                color: AppColors.ink,
                borderRadius: BorderRadius.circular(26),
              ),
              child: LayoutBuilder(builder: (context, box) {
                final compact = box.maxWidth < 600;
                final summary = Row(children: [
                  _summary(
                    'Workout estimate',
                    '${state.workoutCalories}',
                    'active kcal',
                  ),
                  _divider(),
                  _summary(
                    'Budget credit',
                    '${state.exerciseCalories}',
                    'kcal added',
                  ),
                  _divider(),
                  _summary(
                    'Sessions',
                    '${state.selectedWorkouts.length}',
                    'today',
                  ),
                ]);
                final button = FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.lime,
                    foregroundColor: AppColors.ink,
                  ),
                  onPressed: () => _addWorkout(context),
                  icon: const Icon(Icons.add),
                  label: const Text('Log workout'),
                );
                return compact
                    ? Column(children: [
                        summary,
                        const SizedBox(height: 18),
                        SizedBox(width: double.infinity, child: button),
                      ])
                    : Row(children: [
                        Expanded(child: summary),
                        const SizedBox(width: 24),
                        button,
                      ]);
              }),
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(15),
              decoration: BoxDecoration(
                color: AppColors.sky.withValues(alpha: .13),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: AppColors.sky.withValues(alpha: .4)),
              ),
              child: const Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.info_outline, color: AppColors.sky, size: 20),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Calories use your current weight, workout duration, and MET intensity. The diary credits 50% of the largest movement estimate from workouts, steps, or your watch so overlapping data is not counted twice.',
                      style: TextStyle(color: AppColors.muted, fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: () => _editWatchCalories(context),
                icon: const Icon(Icons.watch_outlined, size: 18),
                label: Text(
                  state.selectedWellness.exerciseCalories == 0
                      ? 'Enter watch active calories'
                      : 'Watch total: ${state.selectedWellness.exerciseCalories} kcal',
                ),
              ),
            ),
            const SizedBox(height: 22),
            Row(children: [
              Expanded(
                child: Text('Sessions',
                    style: Theme.of(context).textTheme.titleLarge),
              ),
              if (state.selectedWorkouts.isNotEmpty)
                Text(
                  '${state.selectedWorkouts.fold<double>(0, (sum, item) => sum + item.durationMinutes).round()} minutes',
                  style: const TextStyle(color: AppColors.muted),
                ),
            ]),
            const SizedBox(height: 10),
            if (state.selectedWorkouts.isEmpty)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(28),
                  child: Center(
                    child: Column(children: [
                      const Icon(Icons.fitness_center_outlined,
                          size: 38, color: AppColors.muted),
                      const SizedBox(height: 10),
                      const Text('No workout logged for this day.',
                          style: TextStyle(fontWeight: FontWeight.w800)),
                      const SizedBox(height: 12),
                      FilledButton.tonal(
                        onPressed: () => _addWorkout(context),
                        child: const Text('Add a session'),
                      ),
                    ]),
                  ),
                ),
              )
            else
              Card(
                child: Column(
                  children: [
                    for (var i = 0; i < state.selectedWorkouts.length; i++) ...[
                      _workoutRow(context, state.selectedWorkouts[i]),
                      if (i != state.selectedWorkouts.length - 1)
                        const Divider(height: 1, indent: 18, endIndent: 18),
                    ],
                  ],
                ),
              ),
          ],
        ),
      );

  Widget _summary(String label, String value, String unit) => Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style: TextStyle(
                    color: Colors.white.withValues(alpha: .55), fontSize: 10)),
            const SizedBox(height: 4),
            Text(value,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 25,
                    fontWeight: FontWeight.w900)),
            Text(unit,
                style: TextStyle(
                    color: Colors.white.withValues(alpha: .55), fontSize: 10)),
          ],
        ),
      );

  Widget _divider() => Container(
        width: 1,
        height: 48,
        margin: const EdgeInsets.symmetric(horizontal: 12),
        color: Colors.white.withValues(alpha: .14),
      );

  Widget _workoutRow(BuildContext context, WorkoutEntry entry) => ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 7),
        leading: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: AppColors.terracotta.withValues(alpha: .13),
            borderRadius: BorderRadius.circular(14),
          ),
          child: const Icon(Icons.sports_gymnastics_outlined,
              color: AppColors.terracotta),
        ),
        title: Text(entry.typeName,
            style: const TextStyle(fontWeight: FontWeight.w800)),
        subtitle: Text(
          '${entry.durationMinutes.round()} min • ${entry.met.toStringAsFixed(1)} MET',
        ),
        trailing: Row(mainAxisSize: MainAxisSize.min, children: [
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('${entry.caloriesBurned.round()}',
                  style: const TextStyle(
                      fontSize: 17, fontWeight: FontWeight.w900)),
              const Text('active kcal',
                  style: TextStyle(fontSize: 9, color: AppColors.muted)),
            ],
          ),
          IconButton(
            tooltip: 'Delete workout',
            onPressed: () => state.deleteWorkout(entry.id),
            icon: const Icon(Icons.close, size: 18),
          ),
        ]),
      );

  Future<void> _addWorkout(BuildContext context) async {
    var type = WorkoutEngine.workoutTypes.first;
    double minutes = 30;
    final entry = await showModalBottomSheet<WorkoutEntry>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.paper,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) => StatefulBuilder(
        builder: (context, setLocal) {
          final active = WorkoutEngine.activeCalories(
            met: type.met,
            weightKg: state.profile!.currentWeightKg,
            durationMinutes: minutes,
          );
          return SafeArea(
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                24,
                24,
                24,
                24 + MediaQuery.viewInsetsOf(context).bottom,
              ),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 620),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text('Log workout',
                        style: Theme.of(context).textTheme.headlineMedium),
                    const SizedBox(height: 18),
                    DropdownButtonFormField<WorkoutType>(
                      initialValue: type,
                      isExpanded: true,
                      decoration: const InputDecoration(
                          labelText: 'Activity & intensity'),
                      items: WorkoutEngine.workoutTypes
                          .map((item) => DropdownMenuItem(
                                value: item,
                                child: Text(item.name),
                              ))
                          .toList(),
                      onChanged: (value) => setLocal(() => type = value!),
                    ),
                    const SizedBox(height: 18),
                    Row(children: [
                      const Expanded(
                        child: Text('Duration',
                            style: TextStyle(fontWeight: FontWeight.w800)),
                      ),
                      Text('${minutes.round()} minutes'),
                    ]),
                    Slider(
                      value: minutes,
                      min: 5,
                      max: 180,
                      divisions: 35,
                      onChanged: (value) => setLocal(() => minutes = value),
                    ),
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.cream,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(children: [
                        const Icon(Icons.local_fire_department_outlined,
                            color: AppColors.terracotta),
                        const SizedBox(width: 10),
                        const Expanded(child: Text('Estimated active energy')),
                        Text('${active.round()} kcal',
                            style: const TextStyle(
                                fontSize: 19, fontWeight: FontWeight.w900)),
                      ]),
                    ),
                    const SizedBox(height: 16),
                    FilledButton(
                      onPressed: () => Navigator.pop(
                        context,
                        WorkoutEntry(
                          id: DateTime.now().microsecondsSinceEpoch.toString(),
                          date: state.selectedKey,
                          typeId: type.id,
                          typeName: type.name,
                          durationMinutes: minutes,
                          met: type.met,
                          caloriesBurned: active,
                        ),
                      ),
                      child: const Text('Save workout'),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'MET estimates vary by effort and fitness. Use this as a planning estimate, not an exact measurement.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 10, color: AppColors.muted),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
    if (entry != null) await state.addWorkout(entry);
  }

  Future<void> _editWatchCalories(BuildContext context) async {
    final value = await askNumber(
      context,
      title: 'Watch or fitness app',
      label: 'Active calories for the day',
      initial: state.selectedWellness.exerciseCalories.toDouble(),
      helper: 'Use active energy, not total daily calories',
    );
    if (value != null) {
      await state.updateWellness(
        state.selectedWellness.copyWith(
          exerciseCalories: value.round().clamp(0, 5000),
        ),
      );
    }
  }
}
