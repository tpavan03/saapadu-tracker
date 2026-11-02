import 'package:flutter/material.dart';

import '../app_state.dart';
import '../calorie_engine.dart';
import '../models.dart';
import '../theme.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key, required this.state});
  final AppState state;
  static Future<void> open(BuildContext context, AppState state) =>
      Navigator.of(context).push(
          MaterialPageRoute<void>(builder: (_) => ProfileScreen(state: state)));
  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final form = GlobalKey<FormState>();
  late final TextEditingController name, height, weight, age, goal;
  late String sex, activity;
  late bool addExercise;
  bool saving = false;
  String? error;
  Profile get original => widget.state.profile!;

  @override
  void initState() {
    super.initState();
    name = TextEditingController(text: original.name);
    height = TextEditingController(text: original.heightCm.toStringAsFixed(1));
    weight = TextEditingController(
        text: original.currentWeightKg.toStringAsFixed(1));
    goal =
        TextEditingController(text: original.goalWeightKg.toStringAsFixed(1));
    age = TextEditingController(text: CalorieEngine.age(original).toString());
    sex = original.sex;
    activity = switch (original.activityLevel) {
      'Inactive' => 'Sedentary',
      'Low active' => 'Lightly active',
      'Active' => 'Moderately active',
      _ => original.activityLevel
    };
    addExercise = original.addExerciseCalories;
  }

  @override
  void dispose() {
    for (final controller in [name, height, weight, goal, age]) {
      controller.dispose();
    }
    super.dispose();
  }

  String? number(String? value, double minimum, double maximum, String unit) {
    final parsed = double.tryParse(value ?? '');
    return parsed == null ||
            !parsed.isFinite ||
            parsed < minimum ||
            parsed > maximum
        ? 'Enter $minimum–$maximum $unit'
        : null;
  }

  Future<void> save() async {
    if (saving || !form.currentState!.validate()) return;
    final value = original.copyWith(
        name: name.text.trim(),
        birthYear: DateTime.now().year - int.parse(age.text),
        heightCm: double.parse(height.text),
        currentWeightKg: double.parse(weight.text),
        goalWeightKg: double.parse(goal.text),
        sex: sex,
        activityLevel: activity,
        addExerciseCalories: addExercise);
    final targetBmi =
        value.goalWeightKg / ((value.heightCm / 100) * (value.heightCm / 100));
    if (value.goalWeightKg < value.currentWeightKg &&
        (targetBmi < 18.5 || CalorieEngine.bmi(value) < 18.5)) {
      setState(() => error =
          'This weight-loss goal is below the app’s adult planning range. Review the goal weight or choose maintenance.');
      return;
    }
    setState(() {
      saving = true;
      error = null;
    });
    try {
      await widget.state.saveProfile(value);
      if (mounted) Navigator.pop(context);
    } catch (_) {
      if (mounted) {
        setState(() {
          saving = false;
          error =
              'Could not finish saving. Your entries are kept here; try again.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Your body & routine')),
        body: SafeArea(
            child: Align(
                alignment: Alignment.topCenter,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
                  child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 640),
                      child: Form(
                          key: form,
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                const Text('PROFILE',
                                    style: TextStyle(
                                        color: AppColors.leaf,
                                        fontWeight: FontWeight.w800,
                                        letterSpacing: 1.5,
                                        fontSize: 11)),
                                const SizedBox(height: 10),
                                Text('Keep your numbers current.',
                                    style: Theme.of(context)
                                        .textTheme
                                        .headlineMedium),
                                const SizedBox(height: 10),
                                const Text(
                                    'Changes update your current calorie estimate and goal forecast. Previous diary days keep their original targets.',
                                    style: TextStyle(
                                        color: AppColors.muted, height: 1.6)),
                                const SizedBox(height: 24),
                                TextFormField(
                                    controller: name,
                                    enabled: !saving,
                                    textCapitalization:
                                        TextCapitalization.words,
                                    maxLength: 80,
                                    decoration: const InputDecoration(
                                        labelText: 'Name'),
                                    validator: (value) =>
                                        value == null || value.trim().isEmpty
                                            ? 'Enter your name'
                                            : null),
                                const SizedBox(height: 14),
                                Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Expanded(
                                          child: TextFormField(
                                              controller: weight,
                                              enabled: !saving,
                                              keyboardType: const TextInputType
                                                  .numberWithOptions(
                                                  decimal: true),
                                              decoration: const InputDecoration(
                                                  labelText: 'Current weight',
                                                  suffixText: 'kg'),
                                              validator: (v) =>
                                                  number(v, 30, 350, 'kg'))),
                                      const SizedBox(width: 12),
                                      Expanded(
                                          child: TextFormField(
                                              controller: height,
                                              enabled: !saving,
                                              keyboardType: const TextInputType
                                                  .numberWithOptions(
                                                  decimal: true),
                                              decoration: const InputDecoration(
                                                  labelText: 'Height',
                                                  suffixText: 'cm'),
                                              validator: (v) =>
                                                  number(v, 100, 250, 'cm'))),
                                    ]),
                                const SizedBox(height: 16),
                                TextFormField(
                                    controller: age,
                                    enabled: !saving,
                                    keyboardType: TextInputType.number,
                                    decoration: const InputDecoration(
                                        labelText: 'Age', suffixText: 'years'),
                                    validator: (v) =>
                                        int.tryParse(v ?? '') == null
                                            ? 'Enter a whole age'
                                            : number(v, 18, 120, 'years')),
                                const SizedBox(height: 16),
                                DropdownButtonFormField<String>(
                                    initialValue: sex,
                                    isExpanded: true,
                                    decoration: const InputDecoration(
                                        labelText:
                                            'Body reference for calorie equation'),
                                    items: const [
                                      DropdownMenuItem(
                                          value: 'Male',
                                          child: Text('Male reference')),
                                      DropdownMenuItem(
                                          value: 'Female',
                                          child: Text('Female reference'))
                                    ],
                                    onChanged: saving
                                        ? null
                                        : (v) => setState(() => sex = v!)),
                                const SizedBox(height: 10),
                                const Text(
                                    'The energy equation uses a body-reference coefficient. It is an estimate, not a measurement of your metabolism.',
                                    style: TextStyle(
                                        color: AppColors.muted, fontSize: 12)),
                                const SizedBox(height: 22),
                                TextFormField(
                                    controller: goal,
                                    enabled: !saving,
                                    keyboardType:
                                        const TextInputType.numberWithOptions(
                                            decimal: true),
                                    decoration: const InputDecoration(
                                        labelText: 'Goal weight',
                                        suffixText: 'kg'),
                                    validator: (v) => number(v, 30, 350, 'kg')),
                                const SizedBox(height: 16),
                                DropdownButtonFormField<String>(
                                    initialValue: activity,
                                    isExpanded: true,
                                    decoration: const InputDecoration(
                                        labelText: 'Usual activity'),
                                    items: [
                                      'Sedentary',
                                      'Lightly active',
                                      'Moderately active',
                                      'Very active'
                                    ]
                                        .map((v) => DropdownMenuItem(
                                            value: v, child: Text(v)))
                                        .toList(),
                                    onChanged: saving
                                        ? null
                                        : (v) => setState(() => activity = v!)),
                                const SizedBox(height: 10),
                                SwitchListTile.adaptive(
                                    contentPadding: EdgeInsets.zero,
                                    value: addExercise,
                                    title: const Text('Daily movement credit'),
                                    subtitle: const Text(
                                        'Use an inactive base and credit 50% of logged movement. Turn off to use the usual activity level as a fixed estimate.'),
                                    onChanged: saving
                                        ? null
                                        : (v) =>
                                            setState(() => addExercise = v)),
                                const SizedBox(height: 12),
                                const Text(
                                    'Changing current weight also saves a check-in for today. Edit pace, calorie target and your requested date in Goal plan.',
                                    style: TextStyle(
                                        color: AppColors.muted,
                                        fontSize: 12,
                                        height: 1.6)),
                                if (error != null)
                                  Padding(
                                      padding: const EdgeInsets.only(top: 16),
                                      child: Semantics(
                                          liveRegion: true,
                                          child: Text(error!,
                                              style: const TextStyle(
                                                  color:
                                                      AppColors.terracotta)))),
                                const SizedBox(height: 24),
                                FilledButton.icon(
                                    onPressed: saving ? null : save,
                                    icon: Icon(saving
                                        ? Icons.hourglass_top_rounded
                                        : Icons.check_rounded),
                                    label: Text(saving
                                        ? 'Saving profile…'
                                        : 'Save profile')),
                              ]))),
                ))),
      );
}
