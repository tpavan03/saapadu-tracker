import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app_state.dart';
import '../calorie_engine.dart';
import '../cloud_sync_service.dart';
import '../models.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'plan_screen.dart';

class MoreScreen extends StatelessWidget {
  const MoreScreen({super.key, required this.state});
  final AppState state;

  @override
  Widget build(BuildContext context) => PageFrame(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('TOOLS & SETTINGS',
            style: TextStyle(
                fontSize: 11,
                letterSpacing: 1.2,
                fontWeight: FontWeight.w900,
                color: AppColors.leaf)),
        const SizedBox(height: 4),
        Text('More for your routine',
            style: Theme.of(context).textTheme.headlineMedium),
        const SizedBox(height: 24),
        _FastingCard(state: state),
        const SizedBox(height: 18),
        LayoutBuilder(builder: (context, box) {
          final w = box.maxWidth > 760 ? (box.maxWidth - 12) / 2 : box.maxWidth;
          return Wrap(spacing: 12, runSpacing: 12, children: [
            SizedBox(width: w, child: _cloudCard(context)),
            SizedBox(width: w, child: _profileCard(context)),
            SizedBox(width: w, child: _dataCard(context)),
            SizedBox(width: w, child: _targetCard(context)),
            SizedBox(width: w, child: _sourceCard(context)),
          ]);
        }),
      ]));

  Widget _profileCard(BuildContext context) {
    final p = state.profile!;
    return Card(
        child: Padding(
      padding: const EdgeInsets.all(20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                  color: AppColors.lime.withValues(alpha: .45),
                  borderRadius: BorderRadius.circular(14)),
              child: const Icon(Icons.person_outline, color: AppColors.forest)),
          const SizedBox(width: 12),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(p.name, style: Theme.of(context).textTheme.titleMedium),
                Text(
                    '${p.currentWeightKg.toStringAsFixed(1)} kg • ${p.heightCm.round()} cm',
                    style:
                        const TextStyle(color: AppColors.muted, fontSize: 12)),
              ])),
          TextButton(
              onPressed: () => _editProfile(context),
              child: const Text('Edit')),
        ]),
        const Divider(height: 28),
        Row(children: [
          Expanded(
              child: _mini('Goal', '${p.goalWeightKg.toStringAsFixed(1)} kg')),
          Expanded(
              child: _mini('BMI', CalorieEngine.bmi(p).toStringAsFixed(1))),
          Expanded(
              child: _mini('Activity',
                  p.addExerciseCalories ? 'Daily credit' : 'Fixed')),
        ]),
      ]),
    ));
  }

  Widget _cloudCard(BuildContext context) {
    final cloud = state.cloud;
    final configured = cloud.configured;
    final synced = cloud.status == CloudSyncStatus.synced;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: (synced ? AppColors.leaf : AppColors.sky)
                      .withValues(alpha: .14),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  synced ? Icons.cloud_done_outlined : Icons.cloud_outlined,
                  color: synced ? AppColors.leaf : AppColors.sky,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Cloud history',
                        style: Theme.of(context).textTheme.titleMedium),
                    Text(
                      configured
                          ? (cloud.email ?? 'Google sign-in')
                          : 'Local storage active',
                      style: const TextStyle(
                        color: AppColors.muted,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ]),
            const SizedBox(height: 12),
            Text(
              configured
                  ? _syncMessage(cloud.status)
                  : 'The app is ready for Google login and cloud sync. It needs a one-time connection to a free Supabase project; until then your browser copy and manual backups continue to work.',
              style: const TextStyle(color: AppColors.muted, fontSize: 12),
            ),
            if (configured && cloud.signedIn) ...[
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: cloud.signOut,
                icon: const Icon(Icons.logout, size: 18),
                label: const Text('Sign out'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _syncMessage(CloudSyncStatus status) => switch (status) {
        CloudSyncStatus.synced =>
          'Up to date. New logs are saved locally first and synchronized automatically.',
        CloudSyncStatus.syncing => 'Synchronizing your latest changes…',
        CloudSyncStatus.offline =>
          'Cloud is temporarily unavailable. Local logging continues and will retry later.',
        CloudSyncStatus.denied => 'This Google account is not approved.',
        CloudSyncStatus.signedOut =>
          'Sign in to continue cloud synchronization.',
        CloudSyncStatus.unavailable =>
          'Cloud synchronization is not configured.',
      };

  Widget _dataCard(BuildContext context) => Card(
          child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const Icon(Icons.shield_outlined, color: AppColors.forest),
            const SizedBox(width: 9),
            Text('Data & backup',
                style: Theme.of(context).textTheme.titleMedium),
          ]),
          const SizedBox(height: 10),
          const Text(
              'The browser copy is automatic. Keep an occasional manual backup as a second recovery path, especially before clearing browser data.',
              style: TextStyle(color: AppColors.muted, fontSize: 12)),
          const SizedBox(height: 16),
          Wrap(spacing: 8, runSpacing: 8, children: [
            FilledButton.tonalIcon(
                onPressed: () => _copyBackup(context),
                icon: const Icon(Icons.copy_all_outlined),
                label: const Text('Copy backup')),
            OutlinedButton.icon(
                onPressed: () => _restoreBackup(context),
                icon: const Icon(Icons.restore_outlined),
                label: const Text('Restore')),
          ]),
        ]),
      ));

  Widget _targetCard(BuildContext context) => Card(
          child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const Icon(Icons.track_changes_outlined,
                color: AppColors.terracotta),
            const SizedBox(width: 9),
            Text('How targets work',
                style: Theme.of(context).textTheme.titleMedium)
          ]),
          const SizedBox(height: 12),
          Text('${state.baseCalorieTarget} kcal base',
              style:
                  const TextStyle(fontSize: 24, fontWeight: FontWeight.w900)),
          const SizedBox(height: 5),
          Text(
              state.profile!.addExerciseCalories
                  ? 'Uses a sedentary baseline, then adds back 50% of logged step and activity estimates to reduce double-counting.'
                  : 'Uses your selected usual activity level as a fixed daily target. Logged movement is recorded but not added back.',
              style: const TextStyle(color: AppColors.muted, fontSize: 12)),
          const SizedBox(height: 13),
          const Text(
              'Protein uses body weight and goal direction. Carb and fat targets divide the remaining energy; fiber target is 25–30 g.',
              style: TextStyle(color: AppColors.muted, fontSize: 12)),
          const SizedBox(height: 14),
          FilledButton.tonalIcon(
              onPressed: () => PlanScreen.open(context, state),
              icon: const Icon(Icons.tune_outlined),
              label: const Text('Customize target & date')),
        ]),
      ));

  Widget _sourceCard(BuildContext context) => Card(
          child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const Icon(Icons.menu_book_outlined, color: AppColors.sky),
            const SizedBox(width: 9),
            Text('Food data & privacy',
                style: Theme.of(context).textTheme.titleMedium)
          ]),
          const SizedBox(height: 12),
          Text(
              '${state.foods.length} built-in foods • ${state.customFoods.length} custom',
              style: const TextStyle(fontWeight: FontWeight.w800)),
          const SizedBox(height: 7),
          const Text(
              'Seed values use Indian Food Composition Tables and recipe estimates. Oil, size, and home recipes vary, so edit the serving to match your plate. There are no ads or analytics.',
              style: TextStyle(color: AppColors.muted, fontSize: 12)),
          const SizedBox(height: 12),
          const Text('Saapadu v1.1 • Personal nutrition planning only',
              style: TextStyle(fontSize: 10, color: AppColors.muted)),
        ]),
      ));

  Widget _mini(String label, String value) =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label,
            style: const TextStyle(color: AppColors.muted, fontSize: 10)),
        const SizedBox(height: 3),
        Text(value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.w800)),
      ]);

  Future<void> _copyBackup(BuildContext context) async {
    await Clipboard.setData(ClipboardData(text: state.exportBackup()));
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content:
              Text('Backup copied. Paste it into a safe note or text file.')));
    }
  }

  Future<void> _restoreBackup(BuildContext context) async {
    final controller = TextEditingController();
    final value = await showDialog<String>(
        context: context,
        builder: (context) => AlertDialog(
              title: const Text('Restore backup'),
              content: SizedBox(
                  width: 560,
                  child: TextField(
                      controller: controller,
                      minLines: 6,
                      maxLines: 12,
                      decoration: const InputDecoration(
                          hintText: 'Paste your Saapadu backup text here'))),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancel')),
                FilledButton(
                    onPressed: () => Navigator.pop(context, controller.text),
                    child: const Text('Restore'))
              ],
            ));
    if (value == null || value.trim().isEmpty) return;
    try {
      await state.importBackup(value);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Backup restored successfully.')));
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text(
                'Could not read that backup. Check that the full text was pasted.')));
      }
    }
  }

  Future<void> _editProfile(BuildContext context) async {
    final p = state.profile!;
    final name = TextEditingController(text: p.name);
    final height = TextEditingController(text: '${p.heightCm}');
    final goal = TextEditingController(text: '${p.goalWeightKg}');
    var activity = p.activityLevel;
    var addExercise = p.addExerciseCalories;
    var pace = p.weeklyGoalKg.clamp(.25, .75);
    final saved = await showDialog<Profile>(
        context: context,
        builder: (context) => StatefulBuilder(
            builder: (context, setLocal) => AlertDialog(
                  title: const Text('Profile & targets'),
                  content: SizedBox(
                      width: 520,
                      child: SingleChildScrollView(
                          child: Column(children: [
                        TextField(
                            controller: name,
                            decoration:
                                const InputDecoration(labelText: 'Name')),
                        const SizedBox(height: 10),
                        Row(children: [
                          Expanded(
                              child: TextField(
                                  controller: height,
                                  keyboardType: TextInputType.number,
                                  decoration: const InputDecoration(
                                      labelText: 'Height', suffixText: 'cm'))),
                          const SizedBox(width: 10),
                          Expanded(
                              child: TextField(
                                  controller: goal,
                                  keyboardType: TextInputType.number,
                                  decoration: const InputDecoration(
                                      labelText: 'Goal weight',
                                      suffixText: 'kg'))),
                        ]),
                        const SizedBox(height: 10),
                        DropdownButtonFormField<String>(
                            initialValue: activity,
                            decoration: const InputDecoration(
                                labelText: 'Usual activity'),
                            items: const [
                              'Sedentary',
                              'Lightly active',
                              'Moderately active',
                              'Very active'
                            ]
                                .map((v) =>
                                    DropdownMenuItem(value: v, child: Text(v)))
                                .toList(),
                            onChanged: (v) => setLocal(() => activity = v!)),
                        const SizedBox(height: 12),
                        SwitchListTile(
                            contentPadding: EdgeInsets.zero,
                            title: const Text('Add movement calories'),
                            subtitle: const Text(
                                'Use sedentary base + 50% of logged activity'),
                            value: addExercise,
                            onChanged: (v) => setLocal(() => addExercise = v)),
                        const SizedBox(height: 5),
                        Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                                'Planned pace: ${pace.toStringAsFixed(2)} kg/week',
                                style: const TextStyle(
                                    fontWeight: FontWeight.w700))),
                        Slider(
                            value: pace,
                            min: .25,
                            max: .75,
                            divisions: 2,
                            onChanged: (v) => setLocal(() => pace = v)),
                      ]))),
                  actions: [
                    TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Cancel')),
                    FilledButton(
                        onPressed: () => Navigator.pop(
                            context,
                            p.copyWith(
                              name: name.text.trim().isEmpty
                                  ? p.name
                                  : name.text.trim(),
                              heightCm: double.tryParse(height.text),
                              goalWeightKg: double.tryParse(goal.text),
                              activityLevel: activity,
                              addExerciseCalories: addExercise,
                              weeklyGoalKg: pace,
                            )),
                        child: const Text('Save')),
                  ],
                )));
    if (saved != null) state.saveProfile(saved);
  }
}

class _FastingCard extends StatefulWidget {
  const _FastingCard({required this.state});
  final AppState state;
  @override
  State<_FastingCard> createState() => _FastingCardState();
}

class _FastingCardState extends State<_FastingCard> {
  Timer? timer;
  @override
  void initState() {
    super.initState();
    timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted && widget.state.fasting.isActive) setState(() {});
    });
  }

  @override
  void dispose() {
    timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final fast = widget.state.fasting;
    final elapsed = fast.startedAt == null
        ? Duration.zero
        : DateTime.now().difference(fast.startedAt!);
    final target = Duration(hours: fast.targetHours);
    final progress = (elapsed.inSeconds / target.inSeconds).clamp(0.0, 1.0);
    String two(int n) => n.toString().padLeft(2, '0');
    final display =
        '${two(elapsed.inHours)}:${two(elapsed.inMinutes % 60)}:${two(elapsed.inSeconds % 60)}';
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
          color: AppColors.ink, borderRadius: BorderRadius.circular(28)),
      child: LayoutBuilder(builder: (context, box) {
        final compact = box.maxWidth < 620;
        final info =
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(fast.isActive ? 'FAST IN PROGRESS' : 'INTERMITTENT FASTING',
              style: const TextStyle(
                  color: AppColors.lime,
                  fontSize: 11,
                  letterSpacing: 1.2,
                  fontWeight: FontWeight.w900)),
          const SizedBox(height: 8),
          Text(
              fast.isActive
                  ? display
                  : '${fast.targetHours}:${24 - fast.targetHours} schedule',
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 34,
                  letterSpacing: -1,
                  fontWeight: FontWeight.w900)),
          const SizedBox(height: 7),
          Text(
              fast.isActive
                  ? (progress >= 1
                      ? 'Target reached. End when you are ready.'
                      : '${(target - elapsed).inMinutes.clamp(0, 9999) ~/ 60}h ${(target - elapsed).inMinutes.clamp(0, 9999) % 60}m remaining')
                  : 'A simple timer; fasting does not change your calorie target.',
              style: TextStyle(color: Colors.white.withValues(alpha: .65))),
        ]);
        final controls =
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          if (!fast.isActive)
            Wrap(
                spacing: 7,
                children: [12, 14, 16, 18]
                    .map((h) => ChoiceChip(
                          label: Text('$h:${24 - h}'),
                          selected: fast.targetHours == h,
                          selectedColor: AppColors.lime,
                          onSelected: (_) => widget.state.setFastingTarget(h),
                        ))
                    .toList()),
          const SizedBox(height: 12),
          FilledButton.icon(
            style: FilledButton.styleFrom(
                backgroundColor:
                    fast.isActive ? AppColors.terracotta : AppColors.lime,
                foregroundColor: fast.isActive ? Colors.white : AppColors.ink),
            onPressed: () => fast.isActive
                ? widget.state.stopFast()
                : widget.state.startFast(fast.targetHours),
            icon: Icon(
                fast.isActive ? Icons.stop_rounded : Icons.play_arrow_rounded),
            label: Text(fast.isActive ? 'End fast' : 'Start fast'),
          ),
        ]);
        return Column(children: [
          if (compact) ...[info, const SizedBox(height: 18), controls] else
            Row(children: [
              Expanded(child: info),
              const SizedBox(width: 30),
              SizedBox(width: 300, child: controls)
            ]),
          if (fast.isActive) ...[
            const SizedBox(height: 18),
            ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 8,
                    backgroundColor: Colors.white12,
                    color: AppColors.lime))
          ],
          const SizedBox(height: 12),
          Text(
            'Fasting may not be suitable during pregnancy or breastfeeding, with an eating-disorder history, or when diabetes medicines can cause low blood sugar. Ask your clinician first.',
            style: TextStyle(
                color: Colors.white.withValues(alpha: .45),
                fontSize: 10,
                height: 1.35),
          ),
        ]);
      }),
    );
  }
}
