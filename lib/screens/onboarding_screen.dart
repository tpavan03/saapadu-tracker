import 'package:flutter/material.dart';

import '../app_state.dart';
import '../calorie_engine.dart';
import '../models.dart';
import '../theme.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key, required this.state});
  final AppState state;

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  int step = 0;
  final name = TextEditingController();
  final height = TextEditingController(text: '170');
  final weight = TextEditingController(text: '75');
  final goal = TextEditingController(text: '68');
  int birthYear = 1995;
  String sex = 'Male';
  String activity = 'Lightly active';
  double weeklyGoal = .5;

  @override
  void dispose() {
    name.dispose();
    height.dispose();
    weight.dispose();
    goal.dispose();
    super.dispose();
  }

  Profile get draft => Profile(
        name: name.text.trim().isEmpty ? 'Friend' : name.text.trim(),
        sex: sex,
        birthYear: birthYear,
        heightCm: double.tryParse(height.text) ?? 170,
        currentWeightKg: double.tryParse(weight.text) ?? 75,
        goalWeightKg: double.tryParse(goal.text) ?? 68,
        activityLevel: activity,
        weeklyGoalKg: weeklyGoal,
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 980),
              child: LayoutBuilder(
                builder: (context, box) {
                  final wide = box.maxWidth > 760;
                  final form = _form();
                  return wide
                      ? Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Expanded(child: _intro()),
                            const SizedBox(width: 64),
                            SizedBox(width: 430, child: form),
                          ],
                        )
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _intro(),
                            const SizedBox(height: 30),
                            form,
                          ],
                        );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _intro() => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: BoxDecoration(
              color: AppColors.lime,
              borderRadius: BorderRadius.circular(40),
            ),
            child: const Text(
              'PRIVATE • OFFLINE-FIRST',
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900),
            ),
          ),
          const SizedBox(height: 22),
          Text('Eat familiar.\nTrack clearly.',
              style: Theme.of(context).textTheme.displaySmall?.copyWith(
                    fontSize: 54,
                    letterSpacing: -2.5,
                  )),
          const SizedBox(height: 18),
          const Text(
            'A calm food and wellness tracker made around everyday South Indian meals—not a foreign-food database you have to fight.',
            style: TextStyle(fontSize: 17, height: 1.5, color: AppColors.muted),
          ),
          const SizedBox(height: 24),
          const Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _Pill(icon: Icons.rice_bowl_outlined, label: 'Local foods'),
              _Pill(icon: Icons.bolt_outlined, label: 'Smart targets'),
              _Pill(icon: Icons.timer_outlined, label: 'Fasting'),
            ],
          ),
        ],
      );

  Widget _form() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 250),
          child: step == 0 ? _identity() : _goal(),
        ),
      ),
    );
  }

  Widget _identity() => Column(
        key: const ValueKey('identity'),
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('First, the basics',
              style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 8),
          const Text('Used only to calculate your energy target.',
              style: TextStyle(color: AppColors.muted)),
          const SizedBox(height: 24),
          TextField(
            controller: name,
            decoration: const InputDecoration(labelText: 'Name (optional)'),
          ),
          const SizedBox(height: 14),
          DropdownButtonFormField<String>(
            initialValue: sex,
            decoration: const InputDecoration(
                labelText: 'Body reference for calorie equation'),
            items: const [
              DropdownMenuItem(value: 'Male', child: Text('Male')),
              DropdownMenuItem(value: 'Female', child: Text('Female')),
            ],
            onChanged: (value) => setState(() => sex = value!),
          ),
          const SizedBox(height: 14),
          DropdownButtonFormField<int>(
            initialValue: birthYear,
            decoration: const InputDecoration(labelText: 'Birth year'),
            items: [
              for (int year = DateTime.now().year - 18;
                  year >= DateTime.now().year - 100;
                  year--)
                DropdownMenuItem(value: year, child: Text('$year')),
            ],
            onChanged: (value) => setState(() => birthYear = value!),
          ),
          const SizedBox(height: 20),
          FilledButton(
            onPressed: () => setState(() => step = 1),
            child: const Text('Continue'),
          ),
        ],
      );

  Widget _goal() {
    final profile = draft;
    return Column(
      key: const ValueKey('goal'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            IconButton(
              onPressed: () => setState(() => step = 0),
              icon: const Icon(Icons.arrow_back),
            ),
            const SizedBox(width: 6),
            Text('Set your direction',
                style: Theme.of(context).textTheme.headlineMedium),
          ],
        ),
        const SizedBox(height: 18),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: height,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                    labelText: 'Height', suffixText: 'cm'),
                onChanged: (_) => setState(() {}),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextField(
                controller: weight,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                    labelText: 'Current', suffixText: 'kg'),
                onChanged: (_) => setState(() {}),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        TextField(
          controller: goal,
          keyboardType: TextInputType.number,
          decoration:
              const InputDecoration(labelText: 'Goal weight', suffixText: 'kg'),
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 14),
        DropdownButtonFormField<String>(
          initialValue: activity,
          decoration: const InputDecoration(labelText: 'Usual activity'),
          items: const [
            'Sedentary',
            'Lightly active',
            'Moderately active',
            'Very active',
          ].map((v) => DropdownMenuItem(value: v, child: Text(v))).toList(),
          onChanged: (value) => setState(() => activity = value!),
        ),
        const SizedBox(height: 18),
        const Text('Weekly pace',
            style: TextStyle(fontWeight: FontWeight.w700)),
        Slider(
          value: weeklyGoal,
          min: .25,
          max: .75,
          divisions: 2,
          label: '${weeklyGoal.toStringAsFixed(2)} kg/week',
          onChanged: (v) => setState(() => weeklyGoal = v),
        ),
        Text('${weeklyGoal.toStringAsFixed(2)} kg per week',
            textAlign: TextAlign.center),
        const SizedBox(height: 18),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.ink,
            borderRadius: BorderRadius.circular(18),
          ),
          child: Row(
            children: [
              const Icon(Icons.local_fire_department_outlined,
                  color: AppColors.lime),
              const SizedBox(width: 12),
              Expanded(
                child: Text('Starting target',
                    style:
                        TextStyle(color: Colors.white.withValues(alpha: .72))),
              ),
              Text(
                  '${CalorieEngine.dailyTarget(profile.copyWith(activityLevel: 'Sedentary'))} kcal',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  )),
            ],
          ),
        ),
        const SizedBox(height: 18),
        FilledButton(
          onPressed: _finish,
          child: const Text('Start tracking'),
        ),
        const SizedBox(height: 10),
        const Text(
          'Targets are estimates, not medical advice. Adjust them with a qualified professional if needed.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 11, color: AppColors.muted),
        ),
      ],
    );
  }

  Future<void> _finish() async {
    final profile = draft;
    final goalBmi = profile.goalWeightKg /
        ((profile.heightCm / 100) * (profile.heightCm / 100));
    if (profile.heightCm < 100 ||
        profile.heightCm > 250 ||
        profile.currentWeightKg < 30 ||
        profile.currentWeightKg > 350) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Please check the height and weight values.')),
      );
      return;
    }
    if (profile.goalWeightKg < profile.currentWeightKg && goalBmi < 18.5) {
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Choose a safer goal'),
          content: const Text(
            'That goal is below the standard healthy BMI screening range. Set a higher goal or ask a qualified clinician to set your calorie target.',
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Adjust goal'),
            ),
          ],
        ),
      );
      return;
    }
    await widget.state.saveProfile(profile);
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.icon, required this.label});
  final IconData icon;
  final String label;
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
        decoration: BoxDecoration(
          color: AppColors.paper,
          border: Border.all(color: AppColors.line),
          borderRadius: BorderRadius.circular(40),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 17, color: AppColors.forest),
          const SizedBox(width: 7),
          Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
        ]),
      );
}
