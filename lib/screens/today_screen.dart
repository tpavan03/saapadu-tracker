import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../app_state.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'food_search_screen.dart';

class TodayScreen extends StatelessWidget {
  const TodayScreen({
    super.key,
    required this.state,
    required this.onDiary,
    required this.onActivity,
  });
  final AppState state;
  final VoidCallback onDiary;
  final VoidCallback onActivity;

  @override
  Widget build(BuildContext context) {
    final p = state.profile!;
    final firstName = p.name.split(' ').first;
    return PageFrame(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(DateFormat('EEEE, d MMMM').format(state.selectedDate),
                        style: const TextStyle(
                            color: AppColors.muted,
                            fontWeight: FontWeight.w700)),
                    const SizedBox(height: 4),
                    Text('Vanakkam, $firstName',
                        style: Theme.of(context).textTheme.headlineMedium),
                  ],
                ),
              ),
              DateNavigator(state: state),
            ],
          ),
          const SizedBox(height: 24),
          LayoutBuilder(
            builder: (context, box) {
              final wide = box.maxWidth > 780;
              final calories = _calorieCard(context);
              final macros = _macroCard(context);
              return wide
                  ? Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                          Expanded(flex: 5, child: calories),
                          const SizedBox(width: 16),
                          Expanded(flex: 4, child: macros),
                        ])
                  : Column(
                      children: [calories, const SizedBox(height: 16), macros]);
            },
          ),
          const SizedBox(height: 16),
          _suggestionCard(context),
          const SizedBox(height: 28),
          Row(children: [
            Expanded(
                child: Text('Daily signals',
                    style: Theme.of(context).textTheme.titleLarge)),
            const Text('Tap to update',
                style: TextStyle(color: AppColors.muted, fontSize: 12)),
          ]),
          const SizedBox(height: 12),
          LayoutBuilder(
            builder: (context, box) {
              final cardWidth = box.maxWidth > 700
                  ? (box.maxWidth - 36) / 4
                  : (box.maxWidth - 12) / 2;
              return Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  _signal(context,
                      width: cardWidth,
                      icon: Icons.water_drop_outlined,
                      color: AppColors.sky,
                      value: '${state.selectedWellness.waterMl}',
                      unit: 'ml water',
                      onTap: () => _editWater(context)),
                  _signal(context,
                      width: cardWidth,
                      icon: Icons.bedtime_outlined,
                      color: const Color(0xFF8C7CB7),
                      value:
                          state.selectedWellness.sleepHours.toStringAsFixed(1),
                      unit: 'hours sleep',
                      onTap: () => _editSleep(context)),
                  _signal(context,
                      width: cardWidth,
                      icon: Icons.directions_walk_outlined,
                      color: AppColors.leaf,
                      value: '${state.selectedWellness.steps}',
                      unit: 'steps',
                      onTap: () => _editSteps(context)),
                  _signal(context,
                      width: cardWidth,
                      icon: Icons.sports_gymnastics_outlined,
                      color: AppColors.terracotta,
                      value: '${state.workoutCalories}',
                      unit: 'workout kcal',
                      onTap: onActivity),
                ],
              );
            },
          ),
          const SizedBox(height: 28),
          Row(children: [
            Expanded(
                child: Text('Meals today',
                    style: Theme.of(context).textTheme.titleLarge)),
            TextButton(onPressed: onDiary, child: const Text('Open diary')),
          ]),
          const SizedBox(height: 10),
          _meals(context),
        ],
      ),
    );
  }

  Widget _calorieCard(BuildContext context) => Container(
        constraints: const BoxConstraints(minHeight: 270),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: AppColors.ink,
          borderRadius: BorderRadius.circular(28),
        ),
        child: LayoutBuilder(builder: (context, box) {
          final compact = box.maxWidth < 470;
          final text = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('ENERGY BUDGET',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: .58),
                    fontSize: 11,
                    letterSpacing: 1.2,
                    fontWeight: FontWeight.w800,
                  )),
              const SizedBox(height: 10),
              Text('${state.caloriesEaten.round()} eaten',
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.w800)),
              const SizedBox(height: 8),
              Text(
                  '${state.baseCalorieTarget} goal  +  ${state.exerciseCalories} activity',
                  style: TextStyle(color: Colors.white.withValues(alpha: .65))),
              const SizedBox(height: 20),
              FilledButton.icon(
                style: FilledButton.styleFrom(
                    backgroundColor: AppColors.lime,
                    foregroundColor: AppColors.ink),
                onPressed: () => FoodSearchScreen.open(context,
                    state: state, initialMeal: _mealForNow()),
                icon: const Icon(Icons.add),
                label: const Text('Log food'),
              ),
            ],
          );
          if (compact) {
            return Column(children: [
              CalorieRing(
                  eaten: state.caloriesEaten,
                  target: state.adjustedCalorieTarget),
              const SizedBox(height: 18),
              text
            ]);
          }
          return Row(children: [
            CalorieRing(
                eaten: state.caloriesEaten,
                target: state.adjustedCalorieTarget),
            const SizedBox(width: 28),
            Expanded(child: text),
          ]);
        }),
      );

  Widget _macroCard(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Expanded(
                    child: Text('Macros',
                        style: Theme.of(context).textTheme.titleLarge)),
                const Text('eaten / goal',
                    style: TextStyle(color: AppColors.muted, fontSize: 11)),
              ]),
              const SizedBox(height: 22),
              MacroBar(
                  name: 'Protein',
                  value: state.proteinEaten,
                  target: state.proteinTarget,
                  color: AppColors.terracotta),
              const SizedBox(height: 18),
              MacroBar(
                  name: 'Carbs',
                  value: state.carbsEaten,
                  target: state.carbsTarget,
                  color: AppColors.sky),
              const SizedBox(height: 18),
              MacroBar(
                  name: 'Fat',
                  value: state.fatEaten,
                  target: state.fatTarget,
                  color: const Color(0xFFD5A43D)),
              const SizedBox(height: 18),
              MacroBar(
                  name: 'Fiber',
                  value: state.fiberEaten,
                  target: state.fiberTarget,
                  color: AppColors.leaf),
            ],
          ),
        ),
      );

  Widget _suggestionCard(BuildContext context) {
    String title;
    String body;
    IconData icon;
    if (state.caloriesEaten == 0) {
      title = 'Start with your next meal';
      body =
          'Search dosa, idli, rice, sambar, eggs, fruit, or any custom food. Your targets update instantly.';
      icon = Icons.auto_awesome_outlined;
    } else if (state.proteinEaten < state.proteinTarget * .55) {
      title = 'Protein needs attention';
      body =
          'Good familiar options: extra dal or sambar, curd, eggs, paneer, fish, chicken, sprouts, or sundal.';
      icon = Icons.egg_alt_outlined;
    } else if (state.fiberEaten < state.fiberTarget * .55) {
      title = 'Make room for fiber';
      body =
          'Add a vegetable poriyal, greens, beans, guava, papaya, or a whole-grain serving.';
      icon = Icons.eco_outlined;
    } else if (state.calorieRemaining < 0) {
      title = 'You are over today’s estimate';
      body =
          'No need to compensate aggressively. Log honestly, keep the next meal balanced, and look at the weekly trend.';
      icon = Icons.insights_outlined;
    } else {
      title = 'Your day is balanced so far';
      body =
          'Keep portions steady and choose foods you can repeat. Consistency across weeks matters more than one perfect day.';
      icon = Icons.check_circle_outline;
    }
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.lime.withValues(alpha: .28),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.lime),
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icon, color: AppColors.forest),
        const SizedBox(width: 13),
        Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          Text(body,
              style: const TextStyle(color: AppColors.muted, height: 1.4)),
        ])),
      ]),
    );
  }

  Widget _signal(BuildContext context,
          {required double width,
          required IconData icon,
          required Color color,
          required String value,
          required String unit,
          required VoidCallback onTap}) =>
      SizedBox(
        width: width,
        child: Card(
          child: InkWell(
            borderRadius: BorderRadius.circular(22),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.all(17),
              child: Row(children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                      color: color.withValues(alpha: .16),
                      borderRadius: BorderRadius.circular(13)),
                  child: Icon(icon, color: color, size: 21),
                ),
                const SizedBox(width: 12),
                Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      Text(value,
                          maxLines: 1,
                          style: const TextStyle(
                              fontSize: 19, fontWeight: FontWeight.w900)),
                      Text(unit,
                          style: const TextStyle(
                              fontSize: 11, color: AppColors.muted)),
                    ])),
              ]),
            ),
          ),
        ),
      );

  Widget _meals(BuildContext context) {
    const meals = ['Breakfast', 'Lunch', 'Dinner', 'Snacks'];
    return Card(
      child: Column(
        children: [
          for (var i = 0; i < meals.length; i++) ...[
            ListTile(
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 18, vertical: 5),
              title: Text(meals[i],
                  style: const TextStyle(fontWeight: FontWeight.w800)),
              subtitle: Text(
                  '${state.selectedLogs.where((e) => e.meal == meals[i]).length} items'),
              trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                Text(
                    '${state.selectedLogs.where((e) => e.meal == meals[i]).fold<double>(0, (s, e) => s + e.calories).round()} kcal',
                    style: const TextStyle(fontWeight: FontWeight.w700)),
                IconButton(
                  onPressed: () => FoodSearchScreen.open(context,
                      state: state, initialMeal: meals[i]),
                  icon: const Icon(Icons.add_circle_outline),
                  tooltip: 'Add to ${meals[i]}',
                ),
              ]),
            ),
            if (i != meals.length - 1)
              const Divider(height: 1, indent: 18, endIndent: 18),
          ],
        ],
      ),
    );
  }

  Future<void> _editWater(BuildContext context) async {
    final value = await askNumber(context,
        title: 'Water',
        label: 'Total water (ml)',
        initial: state.selectedWellness.waterMl.toDouble());
    if (value != null) {
      state.updateWellness(state.selectedWellness
          .copyWith(waterMl: value.round().clamp(0, 10000)));
    }
  }

  Future<void> _editSleep(BuildContext context) async {
    final value = await askNumber(context,
        title: 'Sleep',
        label: 'Hours slept',
        initial: state.selectedWellness.sleepHours);
    if (value != null) {
      state.updateWellness(
          state.selectedWellness.copyWith(sleepHours: value.clamp(0, 24)));
    }
  }

  Future<void> _editSteps(BuildContext context) async {
    final value = await askNumber(context,
        title: 'Steps',
        label: 'Steps today',
        initial: state.selectedWellness.steps.toDouble(),
        helper: 'Manual total from your phone or watch');
    if (value != null) {
      state.updateWellness(state.selectedWellness
          .copyWith(steps: value.round().clamp(0, 100000)));
    }
  }

  String _mealForNow() {
    final hour = DateTime.now().hour;
    if (hour < 11) return 'Breakfast';
    if (hour < 16) return 'Lunch';
    if (hour < 19) return 'Snacks';
    return 'Dinner';
  }
}
