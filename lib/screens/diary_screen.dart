import 'package:flutter/material.dart';

import '../app_state.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'food_search_screen.dart';

class DiaryScreen extends StatelessWidget {
  const DiaryScreen({super.key, required this.state});
  final AppState state;

  @override
  Widget build(BuildContext context) => PageFrame(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  const Text('FOOD LOG',
                      style: TextStyle(
                          fontSize: 11,
                          letterSpacing: 1.2,
                          fontWeight: FontWeight.w900,
                          color: AppColors.leaf)),
                  const SizedBox(height: 4),
                  Text('Your diary',
                      style: Theme.of(context).textTheme.headlineMedium),
                ])),
            DateNavigator(state: state),
          ]),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
                color: AppColors.ink, borderRadius: BorderRadius.circular(22)),
            child: Row(children: [
              Expanded(
                  child: _total('Calories', '${state.caloriesEaten.round()}',
                      '${state.adjustedCalorieTarget} kcal')),
              _vline(),
              Expanded(
                  child: _total('Protein', '${state.proteinEaten.round()}g',
                      '${state.proteinTarget.round()}g goal')),
              _vline(),
              Expanded(
                  child: _total('Fiber', '${state.fiberEaten.round()}g',
                      '${state.fiberTarget.round()}g goal')),
            ]),
          ),
          const SizedBox(height: 20),
          for (final meal in const [
            'Breakfast',
            'Lunch',
            'Dinner',
            'Snacks'
          ]) ...[
            _mealCard(context, meal),
            const SizedBox(height: 12),
          ],
        ]),
      );

  Widget _total(String label, String value, String detail) => Column(children: [
        Text(label,
            style: TextStyle(
                color: Colors.white.withValues(alpha: .55), fontSize: 11)),
        const SizedBox(height: 4),
        Text(value,
            style: const TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.w900)),
        Text(detail,
            style: TextStyle(
                color: Colors.white.withValues(alpha: .55), fontSize: 10)),
      ]);
  Widget _vline() => Container(
      width: 1, height: 42, color: Colors.white.withValues(alpha: .15));

  Widget _mealCard(BuildContext context, String meal) {
    final entries = state.selectedLogs.where((e) => e.meal == meal).toList();
    final calories = entries.fold<double>(0, (s, e) => s + e.calories).round();
    return Card(
        child: Column(children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(18, 15, 10, 12),
        child: Row(children: [
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(meal, style: Theme.of(context).textTheme.titleMedium),
                Text('$calories kcal',
                    style:
                        const TextStyle(color: AppColors.muted, fontSize: 12)),
              ])),
          TextButton.icon(
              onPressed: () => FoodSearchScreen.open(context,
                  state: state, initialMeal: meal),
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Add food')),
          if (state.logs.any((entry) =>
              entry.meal == meal &&
              entry.date.compareTo(state.selectedKey) < 0))
            IconButton(
                tooltip: 'Repeat last $meal',
                onPressed: () => _repeatMeal(context, meal),
                icon: const Icon(Icons.history_rounded)),
        ]),
      ),
      if (entries.isEmpty)
        const Padding(
          padding: EdgeInsets.fromLTRB(18, 0, 18, 18),
          child: Align(
              alignment: Alignment.centerLeft,
              child: Text('Nothing logged',
                  style: TextStyle(color: AppColors.muted))),
        )
      else
        for (final entry in entries)
          Dismissible(
            key: ValueKey(entry.id),
            direction: DismissDirection.endToStart,
            confirmDismiss: (_) => _confirmDelete(context, entry.food.name),
            background: Container(
                color: AppColors.terracotta,
                alignment: Alignment.centerRight,
                padding: const EdgeInsets.only(right: 20),
                child: const Icon(Icons.delete_outline, color: Colors.white)),
            onDismissed: (_) => state.deleteFood(entry.id),
            child: Container(
              decoration: const BoxDecoration(
                  border: Border(top: BorderSide(color: AppColors.line))),
              child: ListTile(
                title: Text(entry.food.name,
                    style: const TextStyle(fontWeight: FontWeight.w700)),
                subtitle: Text(
                    '${entry.servings.toStringAsFixed(entry.servings % 1 == 0 ? 0 : 2)} × ${entry.food.servingLabel}'),
                trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                  Text('${entry.calories.round()} kcal',
                      style: const TextStyle(fontWeight: FontWeight.w800)),
                  IconButton(
                      tooltip: 'Delete',
                      onPressed: () async {
                        if (await _confirmDelete(context, entry.food.name)) {
                          await state.deleteFood(entry.id);
                        }
                      },
                      icon: const Icon(Icons.close, size: 18)),
                ]),
              ),
            ),
          ),
    ]));
  }

  Future<bool> _confirmDelete(BuildContext context, String name) async =>
      await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
                  title: Text('Remove $name?'),
                  content: const Text(
                      'This removes the entry from this day’s diary and updates its nutrition totals.'),
                  actions: [
                    TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: const Text('Keep entry')),
                    FilledButton(
                        onPressed: () => Navigator.pop(context, true),
                        child: const Text('Remove entry'))
                  ])) ??
      false;

  Future<void> _repeatMeal(BuildContext context, String meal) async {
    final previous = state.logs
        .where((entry) =>
            entry.meal == meal && entry.date.compareTo(state.selectedKey) < 0)
        .toList()
      ..sort((a, b) => b.date.compareTo(a.date));
    if (previous.isEmpty) return;
    final date = previous.first.date;
    final items = previous.where((entry) => entry.date == date).toList();
    final accepted = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
                title: Text('Repeat your last $meal?'),
                content: Text(
                    'Add ${items.length} food entries from $date to ${state.selectedKey}, keeping the same serving sizes.\n\n${items.map((entry) => entry.food.name).join(', ')}'),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('Cancel')),
                  FilledButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text('Repeat meal'))
                ]));
    if (accepted != true) return;
    if (state.fasting.isActive &&
        DateUtils.isSameDay(state.selectedDate, DateTime.now()) &&
        items.any((entry) => entry.calories > 0)) {
      if (!context.mounted) return;
      final end = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
                  title: const Text('End fast at this entry time?'),
                  content: const Text(
                      'This meal contains calories. You can end the window now or keep the timer and log the meal normally.'),
                  actions: [
                    TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: const Text('Keep timer & log')),
                    FilledButton(
                        onPressed: () => Navigator.pop(context, true),
                        child: const Text('End fast & log'))
                  ]));
      if (end == null) return;
      if (end) await state.stopFast();
    }
    for (final entry in items) {
      await state.addFood(entry.food, entry.servings, meal);
    }
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Repeated ${items.length} foods in $meal.')));
    }
  }
}
