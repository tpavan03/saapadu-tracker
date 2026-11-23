import 'package:flutter/material.dart';

import '../app_state.dart';
import '../insights.dart';
import '../models.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/serving_editor.dart';
import 'combos_screen.dart';
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
                color: AppColors.hero, borderRadius: BorderRadius.circular(22)),
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
    final protein = entries.fold<double>(0, (s, e) => s + e.protein);
    final yesterdayKey = dateKey(DateTime(state.selectedDate.year,
        state.selectedDate.month, state.selectedDate.day - 1));
    final yesterday = state.mealEntries(yesterdayKey, meal);
    final nudgeId = '${state.selectedKey}|protein|$meal';
    final nudge = state.dismissedNudges.contains(nudgeId)
        ? null
        : proteinNudge(meal, protein, hasEntries: entries.isNotEmpty);
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
                Text('$calories kcal • ${protein.round()} g protein',
                    style:
                        const TextStyle(color: AppColors.muted, fontSize: 12)),
              ])),
          TextButton.icon(
              onPressed: () => FoodSearchScreen.open(context,
                  state: state, initialMeal: meal),
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Add food')),
          if (yesterday.isNotEmpty || entries.isNotEmpty ||
              state.logs.any((entry) =>
                  entry.meal == meal &&
                  entry.date.compareTo(state.selectedKey) < 0))
            PopupMenuButton<String>(
              tooltip: '$meal options',
              icon: const Icon(Icons.more_vert_rounded),
              onSelected: (value) => switch (value) {
                'yesterday' => _copyEntries(context, meal, yesterday,
                    'yesterday'),
                'last' => _repeatMeal(context, meal),
                'combo' => _saveCombo(context, meal, entries),
                _ => null,
              },
              itemBuilder: (context) => [
                if (yesterday.isNotEmpty)
                  PopupMenuItem(
                      value: 'yesterday',
                      child: Text('Copy yesterday\'s $meal')),
                if (state.logs.any((entry) =>
                    entry.meal == meal &&
                    entry.date.compareTo(state.selectedKey) < 0))
                  PopupMenuItem(
                      value: 'last', child: Text('Repeat last $meal')),
                if (entries.isNotEmpty)
                  const PopupMenuItem(
                      value: 'combo', child: Text('Save as combo')),
              ],
            ),
        ]),
      ),
      if (nudge != null)
        Container(
          margin: const EdgeInsets.fromLTRB(14, 0, 14, 12),
          padding: const EdgeInsets.fromLTRB(14, 10, 4, 10),
          decoration: BoxDecoration(
              color: AppColors.terracotta.withValues(alpha: .1),
              borderRadius: BorderRadius.circular(14)),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Padding(
              padding: EdgeInsets.only(top: 2),
              child: Icon(Icons.egg_alt_outlined,
                  size: 18, color: AppColors.terracotta),
            ),
            const SizedBox(width: 10),
            Expanded(
                child: Text(nudge,
                    style: const TextStyle(fontSize: 12, height: 1.4))),
            IconButton(
                tooltip: 'Dismiss protein tip',
                visualDensity: VisualDensity.compact,
                onPressed: () => state.dismissNudge(nudgeId),
                icon: const Icon(Icons.close, size: 16)),
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
                color: AppColors.dangerSurface,
                alignment: Alignment.centerRight,
                padding: const EdgeInsets.only(right: 20),
                child: const Icon(Icons.delete_outline, color: AppColors.ink)),
            onDismissed: (_) => state.deleteFood(entry.id),
            child: Container(
              decoration: const BoxDecoration(
                  border: Border(top: BorderSide(color: AppColors.line))),
              child: ListTile(
                onTap: () => _editQuantity(context, entry),
                title: Text(entry.food.name,
                    style: const TextStyle(fontWeight: FontWeight.w700)),
                subtitle: Text(
                    '${entry.servings.toStringAsFixed(entry.servings % 1 == 0 ? 0 : 2)} × ${entry.food.servingLabel} • ${entry.protein.round()} g protein'),
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

  Future<void> _editQuantity(BuildContext context, FoodLog entry) async {
    final value = await editServingsSheet(context, entry);
    if (value != null && value != entry.servings) {
      await state.updateFoodServings(entry.id, value);
    }
  }

  Future<void> _saveCombo(
      BuildContext context, String meal, List<FoodLog> entries) async {
    await ComboEditor.create(context, state,
        meal: meal,
        items: [
          for (final e in entries) ComboItem(food: e.food, servings: e.servings)
        ]);
  }

  Future<void> _copyEntries(BuildContext context, String meal,
      List<FoodLog> items, String fromLabel) async {
    if (items.isEmpty) return;
    if (state.fasting.isActive &&
        DateUtils.isSameDay(state.selectedDate, DateTime.now()) &&
        items.any((entry) => entry.calories > 0)) {
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
    await state.addFoods(
        [for (final e in items) (e.food, e.servings)], meal);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Copied ${items.length} foods from $fromLabel to $meal.')));
    }
  }

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
