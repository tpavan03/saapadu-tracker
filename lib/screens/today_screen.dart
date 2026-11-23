import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../app_state.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'food_search_screen.dart';
import 'reminder_settings_screen.dart';
import 'supplements_screen.dart';

class TodayScreen extends StatelessWidget {
  const TodayScreen({
    super.key,
    required this.state,
    required this.onDiary,
    required this.onActivity,
    required this.onFasting,
    this.onProgress,
  });
  final AppState state;
  final VoidCallback onDiary;
  final VoidCallback onActivity;
  final VoidCallback onFasting;
  final VoidCallback? onProgress;

  @override
  Widget build(BuildContext context) {
    final p = state.profile!;
    final firstName = p.name.split(' ').first;
    return PageFrame(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const SaapaduMark(),
            const SizedBox(width: 11),
            const Expanded(
                child: Align(
                    alignment: Alignment.centerLeft,
                    child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text('saapadu.',
                            style: TextStyle(
                                fontFamily: 'Sora',
                                fontSize: 25,
                                fontWeight: FontWeight.w700,
                                letterSpacing: -1.2))))),
            if (MediaQuery.sizeOf(context).width >= 360 &&
                MediaQuery.textScalerOf(context).scale(1) <= 1.15)
              Tooltip(
                  message:
                      'Your diary is stored on this device; see More for cloud sync.',
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                    decoration: BoxDecoration(
                        color: AppColors.paper,
                        border: Border.all(color: AppColors.line),
                        borderRadius: BorderRadius.circular(20)),
                    child: const Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Icons.phone_android_rounded,
                          size: 13, color: AppColors.forest),
                      SizedBox(width: 6),
                      Text('Your diary',
                          style:
                              TextStyle(fontSize: 10, color: AppColors.muted))
                    ]),
                  )),
          ]),
          const SizedBox(height: 26),
          Text('Namaskaram, $firstName',
              style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 6),
          const Text('A little balance, on your own terms.',
              style: TextStyle(color: AppColors.muted)),
          if (state.loggingStreakDays > 0)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Wrap(children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                      color: AppColors.lime.withValues(alpha: .18),
                      borderRadius: BorderRadius.circular(20)),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    const Icon(Icons.local_fire_department_outlined,
                        size: 16, color: AppColors.forest),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                          '${state.loggingStreakDays}-day logging streak',
                          style: const TextStyle(
                              fontWeight: FontWeight.w700, fontSize: 12)),
                    ),
                  ]),
                ),
              ]),
            ),
          const SizedBox(height: 10),
          LayoutBuilder(builder: (context, box) {
            final date = Text(
                DateFormat('EEE, d MMM')
                    .format(state.selectedDate)
                    .toUpperCase(),
                style: const TextStyle(
                    fontSize: 10,
                    letterSpacing: 1.3,
                    color: AppColors.muted,
                    fontWeight: FontWeight.w700));
            return box.maxWidth >= 300 &&
                    MediaQuery.textScalerOf(context).scale(1) <= 1.3
                ? Row(children: [
                    Expanded(child: date),
                    DateNavigator(state: state)
                  ])
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                        date,
                        Align(
                            alignment: Alignment.centerRight,
                            child: DateNavigator(state: state))
                      ]);
          }),
          if (state.projectedGoalDate != null)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                  'Estimated goal · ${p.goalWeightKg.toStringAsFixed(1)} kg by ${DateFormat('d MMM y').format(state.projectedGoalDate!)}',
                  style: const TextStyle(
                      color: AppColors.forest, fontSize: 12, height: 1.5)),
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
          if (state.showReminderPrompt) ...[
            _reminderPrompt(context),
            const SizedBox(height: 16),
          ],
          _checkInCard(context),
          const SizedBox(height: 16),
          _rhythmCard(context),
          const SizedBox(height: 16),
          _supplementCard(context),
          const SizedBox(height: 16),
          _suggestionCard(context),
          const SizedBox(height: 12),
          _mealGuideCard(context),
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
              final regularText =
                  MediaQuery.textScalerOf(context).scale(1) <= 1.2;
              final cardWidth = box.maxWidth > 760 && regularText
                  ? (box.maxWidth - 36) / 4
                  : box.maxWidth >= 340 && regularText
                      ? (box.maxWidth - 12) / 2
                      : box.maxWidth;
              return Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  _signal(context,
                      width: cardWidth,
                      icon: Icons.water_drop_outlined,
                      color: AppColors.sky,
                      value: '${state.selectedWater}',
                      unit: state.selectedWaterIsDefault
                          ? 'ml water (default)'
                          : 'ml water',
                      onTap: () => _editWater(context)),
                  _signal(context,
                      width: cardWidth,
                      icon: Icons.bedtime_outlined,
                      color: AppColors.lavender,
                      value: state.selectedWellness.effectiveSleepHours
                          .toStringAsFixed(1),
                      unit: state.selectedWellness.sleepImported
                          ? 'hours sleep · imported'
                          : 'hours sleep',
                      onTap: () => _editSleep(context)),
                  _signal(context,
                      width: cardWidth,
                      icon: Icons.directions_walk_outlined,
                      color: AppColors.leaf,
                      value: '${state.selectedWellness.effectiveSteps}',
                      unit: state.selectedWellness.stepsImported
                          ? 'steps · imported'
                          : 'steps',
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

  Widget _checkInCard(BuildContext context) => Card(
          child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
              padding: const EdgeInsets.all(11),
              decoration: BoxDecoration(
                  color: AppColors.hero,
                  borderRadius: BorderRadius.circular(15)),
              child: const Icon(Icons.monitor_weight_outlined,
                  color: AppColors.lime, size: 24)),
          const SizedBox(width: 12),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                const Text('Your weekly check-in',
                    style: TextStyle(fontWeight: FontWeight.w700)),
                const SizedBox(height: 5),
                Text(
                    state.weightCheckInDue
                        ? 'Add a weight reading to refresh your estimated goal timeline.'
                        : 'Next check-in ${DateFormat('d MMM').format(state.nextWeightCheckInDate!)}. Your trend matters more than one reading.',
                    style: const TextStyle(
                        color: AppColors.muted, fontSize: 12, height: 1.5)),
                if (onProgress != null)
                  TextButton.icon(
                      onPressed: onProgress,
                      icon: const Icon(Icons.arrow_forward_rounded, size: 17),
                      label: Text(state.weightCheckInDue
                          ? 'Check in'
                          : 'View progress')),
              ])),
        ]),
      ));

  Widget _rhythmCard(BuildContext context) =>
      LayoutBuilder(builder: (context, box) {
        final hydration = Card(
            child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        const Icon(Icons.water_drop_rounded,
                            color: AppColors.sky),
                        const SizedBox(width: 9),
                        Expanded(
                            child: Text('A moment to hydrate',
                                style:
                                    Theme.of(context).textTheme.titleMedium)),
                        Text('${state.selectedWater} ml',
                            style: const TextStyle(
                                fontWeight: FontWeight.w800,
                                color: AppColors.sky))
                      ]),
                      const SizedBox(height: 10),
                      Text(
                          state.selectedWaterIsDefault
                              ? 'Counted as 4 L by default. Adjust only if you drank less or more.'
                              : state.selectedDayUsesWaterDefault
                                  ? 'Edited for this day. Reset to use the 4 L default again.'
                                  : 'Keep a simple record, one glass at a time.',
                          style: const TextStyle(
                              color: AppColors.muted, fontSize: 12)),
                      const SizedBox(height: 14),
                      Wrap(spacing: 8, runSpacing: 6, children: [
                        for (final ml in const [-250, 250, 500])
                          OutlinedButton.icon(
                              onPressed: ml < 0 && state.selectedWater <= 0
                                  ? null
                                  : () async {
                                      await state.adjustWater(ml);
                                      if (context.mounted) {
                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(SnackBar(
                                                content: Text(ml > 0
                                                    ? 'Added $ml ml water'
                                                    : 'Removed ${-ml} ml water'),
                                                duration: const Duration(
                                                    seconds: 2)));
                                      }
                                    },
                              icon: Icon(ml > 0 ? Icons.add : Icons.remove,
                                  size: 16),
                              label: Text('${ml.abs()} ml')),
                        if (state.selectedDayUsesWaterDefault &&
                            !state.selectedWaterIsDefault)
                          TextButton.icon(
                              onPressed: state.resetWater,
                              icon: const Icon(Icons.restart_alt, size: 16),
                              label: const Text('Reset to 4 L')),
                      ]),
                    ])));
        final fasting = Card(
            child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        const Icon(Icons.nights_stay_outlined,
                            color: AppColors.forest),
                        const SizedBox(width: 9),
                        Expanded(
                            child: Text('Your meal rhythm',
                                style: Theme.of(context).textTheme.titleMedium))
                      ]),
                      const SizedBox(height: 10),
                      Text(
                          state.fasting.isActive
                              ? 'A fasting window is active. Your timer stays with you.'
                              : 'Optional fasting windows, with a timer and your own history.',
                          style: const TextStyle(
                              color: AppColors.muted, fontSize: 12)),
                      const SizedBox(height: 14),
                      TextButton.icon(
                          onPressed: onFasting,
                          icon:
                              const Icon(Icons.arrow_forward_rounded, size: 17),
                          label: Text(state.fasting.isActive
                              ? 'Open active timer'
                              : 'Explore fasting')),
                    ])));
        return box.maxWidth >= 720
            ? Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Expanded(child: hydration),
                const SizedBox(width: 16),
                Expanded(child: fasting)
              ])
            : Column(
                children: [hydration, const SizedBox(height: 12), fasting]);
      });

  Widget _calorieCard(BuildContext context) => Container(
        width: double.infinity,
        constraints: const BoxConstraints(minHeight: 270),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: AppColors.hero,
          borderRadius: BorderRadius.circular(28),
        ),
        child: LayoutBuilder(builder: (context, box) {
          final inline = box.maxWidth >= 290 &&
              MediaQuery.textScalerOf(context).scale(1) <= 1.15;
          final ring = CalorieRing(
              eaten: state.caloriesEaten,
              target: state.adjustedCalorieTarget,
              diameter: box.maxWidth < 470 ? 136 : 198);
          final text = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('YOUR DAILY PLATE',
                  style: TextStyle(
                    color: AppColors.muted,
                    fontSize: 11,
                    letterSpacing: 1.2,
                    fontWeight: FontWeight.w800,
                  )),
              const SizedBox(height: 10),
              Text('${state.caloriesEaten.round()} eaten',
                  style: const TextStyle(
                      color: AppColors.ink,
                      fontSize: 24,
                      fontWeight: FontWeight.w800)),
              const SizedBox(height: 8),
              Text(
                  '${state.baseCalorieTarget} goal  +  ${state.exerciseCalories} activity',
                  style: const TextStyle(color: AppColors.muted)),
              const SizedBox(height: 20),
              FilledButton.icon(
                style: FilledButton.styleFrom(
                    backgroundColor: AppColors.lime,
                    foregroundColor: AppColors.onAccent),
                onPressed: () => FoodSearchScreen.open(context,
                    state: state, initialMeal: _mealForNow()),
                icon: const Icon(Icons.add),
                label: const Text('Log food'),
              ),
            ],
          );
          if (!inline) {
            return Column(children: [
              CalorieRing(
                  eaten: state.caloriesEaten,
                  target: state.adjustedCalorieTarget),
              const SizedBox(height: 18),
              text
            ]);
          }
          return Row(children: [
            ring,
            const SizedBox(width: 20),
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
                  color: AppColors.lime),
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
      title = 'Make room for protein';
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
        color: AppColors.hero,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.line),
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

  Widget _mealGuideCard(BuildContext context) {
    final proteinGap = (state.proteinTarget - state.proteinEaten).clamp(0, 999);
    final fiberGap = (state.fiberTarget - state.fiberEaten).clamp(0, 999);
    final remaining = state.calorieRemaining.clamp(0, 9999);
    final suggestions = <String>[
      if (proteinGap >= 15)
        'Next meal: add a protein anchor such as dal, curd, eggs, paneer, fish, chicken, sprouts, or sundal.',
      if (fiberGap >= 5)
        'Add one vegetable poriyal or a whole fruit to move fiber toward ${state.fiberTarget.round()}g.',
      if (remaining > 0)
        'You have about $remaining kcal left. Build the plate with half vegetables, a protein serving, and a measured rice or roti portion.',
    ];
    if (suggestions.isEmpty) {
      suggestions.add(
          'Targets are covered well today. Keep oil portions measured and repeat meals you can sustain.');
    }
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const Icon(Icons.restaurant_menu_outlined, color: AppColors.forest),
            const SizedBox(width: 10),
            Expanded(
                child: Text('Next best choices',
                    style: Theme.of(context).textTheme.titleMedium)),
          ]),
          const SizedBox(height: 10),
          for (final suggestion in suggestions.take(3))
            Padding(
              padding: const EdgeInsets.only(bottom: 7),
              child:
                  Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('•  ', style: TextStyle(color: AppColors.leaf)),
                Expanded(
                    child: Text(suggestion,
                        style: const TextStyle(
                            color: AppColors.muted, height: 1.35))),
              ]),
            ),
        ]),
      ),
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
        initial: state.selectedWater.toDouble(),
        helper: state.selectedDayUsesWaterDefault
            ? 'Each day counts 4000 ml unless you change it'
            : null);
    if (value != null) {
      await state.setWater(value.round().clamp(0, 10000));
    }
  }

  Future<void> _editSleep(BuildContext context) async {
    final value = await askNumber(context,
        title: 'Sleep',
        label: 'Hours slept',
        initial: state.selectedWellness.effectiveSleepHours,
        helper: state.selectedWellness.sleepImported
            ? 'Imported from Health Connect; your entry wins'
            : null);
    if (value != null) {
      state.updateWellness(
          state.selectedWellness.copyWith(sleepHours: value.clamp(0, 24)));
    }
  }

  Future<void> _editSteps(BuildContext context) async {
    final value = await askNumber(context,
        title: 'Steps',
        label: 'Steps today',
        initial: state.selectedWellness.effectiveSteps.toDouble(),
        helper: state.selectedWellness.stepsImported
            ? 'Imported from Health Connect; your entry wins'
            : 'Manual total from your phone or watch');
    if (value != null) {
      state.updateWellness(state.selectedWellness
          .copyWith(steps: value.round().clamp(0, 100000)));
    }
  }

  Widget _reminderPrompt(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              const Icon(Icons.notifications_none_rounded,
                  color: AppColors.forest),
              const SizedBox(width: 10),
              Expanded(
                  child: Text('Gentle reminders?',
                      style: Theme.of(context).textTheme.titleMedium)),
            ]),
            const SizedBox(height: 8),
            const Text(
                'A nudge at meal times only when that meal is not logged yet, an evening reminder if the day looks incomplete, and a weekly check-in. Change times any time in More.',
                style: TextStyle(color: AppColors.muted, fontSize: 12)),
            const SizedBox(height: 12),
            Wrap(spacing: 8, runSpacing: 8, children: [
              FilledButton.tonal(
                  onPressed: () async {
                    final granted =
                        await state.reminderScheduler.requestPermission();
                    await state.dismissReminderPrompt();
                    if (granted) {
                      await state.saveReminderSettings(
                          state.reminderSettings.recommended());
                    } else if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                          content: Text(
                              'Notifications are off for Saapadu. You can allow them in Android settings.')));
                    }
                  },
                  child: const Text('Turn on')),
              TextButton(
                  onPressed: () => ReminderSettingsScreen.open(context, state),
                  child: const Text('Choose')),
              TextButton(
                  onPressed: state.dismissReminderPrompt,
                  child: const Text('Not now')),
            ]),
          ]),
        ),
      );

  Widget _supplementCard(BuildContext context) {
    final items = state.activeSupplements;
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 12, 12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const Icon(Icons.medication_outlined, color: AppColors.lavender),
            const SizedBox(width: 9),
            Expanded(
                child: Text('Supplements',
                    style: Theme.of(context).textTheme.titleMedium)),
            TextButton(
                onPressed: () => SupplementsScreen.open(context, state),
                child: Text(items.isEmpty ? 'Add' : 'Manage')),
          ]),
          if (items.isEmpty)
            const Padding(
              padding: EdgeInsets.only(bottom: 6),
              child: Text(
                  'Track vitamins, whey or anything you take daily. Optional.',
                  style: TextStyle(color: AppColors.muted, fontSize: 12)),
            )
          else
            for (final slot in const ['Morning', 'After workout', 'Night'])
              for (final s in items.where((s) => s.slot == slot))
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  controlAffinity: ListTileControlAffinity.leading,
                  value: state.supplementTaken(s.id),
                  onChanged: (_) => state.toggleSupplement(s.id),
                  title: Text(s.name,
                      style: const TextStyle(fontWeight: FontWeight.w700)),
                  subtitle: Text([
                    slot,
                    if (s.dose.isNotEmpty) s.dose,
                    if (s.calories > 0 || s.proteinG > 0)
                      state.supplementAlsoLoggedAsFood(state.selectedKey, s)
                          ? 'already in food log'
                          : '${s.calories.round()} kcal · ${s.proteinG.round()} g protein',
                  ].join(' • ')),
                ),
        ]),
      ),
    );
  }

  String _mealForNow() {
    final hour = DateTime.now().hour;
    if (hour < 11) return 'Breakfast';
    if (hour < 16) return 'Lunch';
    if (hour < 19) return 'Snacks';
    return 'Dinner';
  }
}
