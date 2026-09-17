import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../app_state.dart';
import '../calorie_engine.dart';
import '../models.dart';
import '../theme.dart';

enum _PlanMode { pace, date }

class PlanScreen extends StatefulWidget {
  const PlanScreen({super.key, required this.state});
  final AppState state;

  static Future<void> open(BuildContext context, AppState state) =>
      Navigator.of(context).push(
        MaterialPageRoute(
          fullscreenDialog: true,
          builder: (_) => PlanScreen(state: state),
        ),
      );

  @override
  State<PlanScreen> createState() => _PlanScreenState();
}

class _PlanScreenState extends State<PlanScreen> {
  late final TextEditingController goalWeight;
  late final TextEditingController manualTarget;
  late _PlanMode mode;
  late double pace;
  late DateTime goalDate;
  late bool useCustomTarget;

  Profile get profile => widget.state.profile!;

  @override
  void initState() {
    super.initState();
    goalWeight = TextEditingController(text: '${profile.goalWeightKg}');
    manualTarget = TextEditingController(
      text: profile.manualCalorieTarget?.toString() ?? '',
    );
    mode = profile.goalDate == null ? _PlanMode.pace : _PlanMode.date;
    pace = profile.weeklyGoalKg.clamp(.25, .75);
    goalDate = profile.goalDate ?? DateTime.now().add(const Duration(days: 90));
    useCustomTarget = profile.manualCalorieTarget != null;
  }

  @override
  void dispose() {
    goalWeight.dispose();
    manualTarget.dispose();
    super.dispose();
  }

  Profile get draft => profile.copyWith(
        goalWeightKg: double.tryParse(goalWeight.text) ?? profile.goalWeightKg,
        weeklyGoalKg: pace,
        goalDate: mode == _PlanMode.date ? goalDate : null,
        manualCalorieTarget:
            useCustomTarget ? int.tryParse(manualTarget.text) : null,
      );

  CaloriePlanRecommendation get recommendation {
    final value = draft;
    return CalorieEngine.planRecommendation(
      value.addExerciseCalories
          ? value.copyWith(activityLevel: 'Sedentary')
          : value,
    );
  }

  @override
  Widget build(BuildContext context) {
    final plan = recommendation;
    final required = plan.requiredWeeklyRateKg;
    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.cream,
        title: const Text('Calorie & goal plan'),
      ),
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 40),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 760),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Plan from the date, or set your own number.',
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'The recommendation stays visible even when you choose a custom calorie target.',
                    style: TextStyle(color: AppColors.muted),
                  ),
                  const SizedBox(height: 22),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          TextField(
                            controller: goalWeight,
                            keyboardType: const TextInputType.numberWithOptions(
                                decimal: true),
                            decoration: const InputDecoration(
                              labelText: 'Desired weight',
                              suffixText: 'kg',
                            ),
                            onChanged: (_) => setState(() {}),
                          ),
                          const SizedBox(height: 16),
                          SegmentedButton<_PlanMode>(
                            segments: const [
                              ButtonSegment(
                                value: _PlanMode.pace,
                                icon: Icon(Icons.speed_outlined),
                                label: Text('Choose pace'),
                              ),
                              ButtonSegment(
                                value: _PlanMode.date,
                                icon: Icon(Icons.event_outlined),
                                label: Text('Choose date'),
                              ),
                            ],
                            selected: {mode},
                            onSelectionChanged: (value) =>
                                setState(() => mode = value.first),
                          ),
                          const SizedBox(height: 18),
                          if (mode == _PlanMode.pace) ...[
                            Row(children: [
                              const Expanded(
                                child: Text('Weekly change',
                                    style:
                                        TextStyle(fontWeight: FontWeight.w800)),
                              ),
                              Text(useCustomTarget
                                  ? '${recommendation.projectedWeeklyRateKg.toStringAsFixed(2)} kg/week'
                                  : '${pace.toStringAsFixed(2)} kg/week'),
                            ]),
                            if (useCustomTarget)
                              const Padding(
                                padding: EdgeInsets.only(top: 8),
                                child: Text(
                                  'Calculated from your custom calorie target. Change that number to change the forecast date.',
                                  style: TextStyle(color: AppColors.muted),
                                ),
                              )
                            else
                              Slider(
                                value: pace,
                                min: .10,
                                max: CalorieEngine.maxAutomaticWeeklyLossKg,
                                divisions: 8,
                                label: '${pace.toStringAsFixed(2)} kg/week',
                                onChanged: (value) =>
                                    setState(() => pace = value),
                              ),
                          ] else
                            ListTile(
                              contentPadding: EdgeInsets.zero,
                              leading:
                                  const Icon(Icons.calendar_month_outlined),
                              title: const Text('Reach goal by'),
                              subtitle:
                                  Text(DateFormat('d MMMM y').format(goalDate)),
                              trailing:
                                  const Icon(Icons.edit_calendar_outlined),
                              onTap: _pickDate,
                            ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.all(22),
                    decoration: BoxDecoration(
                      color: AppColors.ink,
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'RECOMMENDATION',
                          style: TextStyle(
                            color: AppColors.lime,
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.1,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '${plan.recommendedTarget} kcal/day',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 34,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -1,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          mode == _PlanMode.date && required != null
                              ? 'Your selected date requires about ${required.toStringAsFixed(2)} kg per week.'
                              : plan.usesManualTarget
                                  ? 'Your custom target implies ${plan.projectedWeeklyRateKg.toStringAsFixed(2)} kg per week from your current maintenance estimate.'
                                  : 'Based on ${plan.plannedWeeklyRateKg.toStringAsFixed(2)} kg per week and your current body data.',
                          style: TextStyle(
                              color: Colors.white.withValues(alpha: .68)),
                        ),
                        if (plan.projectedGoalDate != null) ...[
                          const SizedBox(height: 8),
                          Text(
                            'At ${plan.effectiveTarget} kcal/day, estimated completion is ${DateFormat('d MMMM y').format(plan.projectedGoalDate!)} (${plan.projectedWeeklyRateKg.toStringAsFixed(2)} kg/week).',
                            style: TextStyle(
                                color: Colors.white.withValues(alpha: .82),
                                fontWeight: FontWeight.w700),
                          ),
                        ],
                        if (mode == _PlanMode.date &&
                            plan.projectedGoalDate != null &&
                            !_sameDate(goalDate, plan.projectedGoalDate!)) ...[
                          const SizedBox(height: 5),
                          Text(
                            'Your selected date is ${DateFormat('d MMMM y').format(goalDate)}. Change the calorie target or date to bring them into line.',
                            style: TextStyle(
                                color: Colors.white.withValues(alpha: .6),
                                fontSize: 12),
                          ),
                        ],
                        if (plan.usesManualTarget && !plan.targetSupportsGoal) ...[
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppColors.terracotta.withValues(alpha: .22),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: const Text(
                              'This custom target is at or above your maintenance estimate, so it will not move you toward the selected goal. Lower the target or choose maintenance as your goal.',
                              style: TextStyle(color: Colors.white, fontSize: 12),
                            ),
                          ),
                        ] else if (!plan.isSafe && plan.earliestSafeDate != null) ...[
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color:
                                  AppColors.terracotta.withValues(alpha: .22),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Text(
                              plan.usesManualTarget
                                  ? 'This custom target implies ${plan.projectedWeeklyRateKg.toStringAsFixed(2)} kg per week, above the automatic safety limit. The earliest supported date is ${DateFormat('d MMMM y').format(plan.earliestSafeDate!)}.'
                                  : 'That date is faster than the automatic plan limit. The earliest supported date is ${DateFormat('d MMMM y').format(plan.earliestSafeDate!)}; the calorie recommendation uses the guarded pace.',
                              style: const TextStyle(
                                  color: Colors.white, fontSize: 12),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        children: [
                          SwitchListTile(
                            contentPadding: EdgeInsets.zero,
                            title: const Text('Use my own calorie target'),
                            subtitle: const Text(
                                'The recommendation remains visible for comparison.'),
                            value: useCustomTarget,
                            onChanged: (value) =>
                                setState(() => useCustomTarget = value),
                          ),
                          if (useCustomTarget) ...[
                            const SizedBox(height: 8),
                            TextField(
                              controller: manualTarget,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                labelText: 'Custom daily target',
                                suffixText: 'kcal',
                              ),
                              onChanged: (_) => setState(() {}),
                            ),
                            if ((int.tryParse(manualTarget.text) ?? 9999) <
                                (profile.sex == 'Male' ? 1500 : 1200))
                              const Padding(
                                padding: EdgeInsets.only(top: 10),
                                child: Text(
                                  'This is below the app’s automatic planning floor. Consider reviewing it with a qualified professional.',
                                  style: TextStyle(
                                      color: AppColors.terracotta,
                                      fontSize: 12),
                                ),
                              ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  FilledButton(
                    onPressed: _save,
                    child: Text(
                      useCustomTarget
                          ? 'Use ${plan.effectiveTarget} kcal target'
                          : 'Use recommended target',
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _pickDate() async {
    final value = await showDatePicker(
      context: context,
      initialDate: goalDate.isAfter(DateTime.now())
          ? goalDate
          : DateTime.now().add(const Duration(days: 1)),
      firstDate: DateTime.now().add(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 3650)),
    );
    if (value != null) setState(() => goalDate = value);
  }

  Future<void> _save() async {
    final value = draft;
    final custom = value.manualCalorieTarget;
    if (value.goalWeightKg < 30 || value.goalWeightKg > 350) {
      _message('Enter a goal weight between 30 and 350 kg.');
      return;
    }
    if (useCustomTarget && (custom == null || custom < 800 || custom > 6000)) {
      _message('Enter a custom target between 800 and 6000 kcal.');
      return;
    }
    await widget.state.saveProfile(value);
    if (mounted) Navigator.pop(context);
  }

  void _message(String value) => ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(value)),
      );

  bool _sameDate(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
}
