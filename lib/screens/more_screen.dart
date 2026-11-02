import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../app_state.dart';
import '../calorie_engine.dart';
import '../cloud_sync_service.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'plan_screen.dart';
import 'fasting_screen.dart';
import 'profile_screen.dart';
import 'login_screen.dart';

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
        Card(
            child: ListTile(
                contentPadding: const EdgeInsets.all(20),
                leading: const Icon(Icons.timelapse_rounded,
                    color: AppColors.forest, size: 32),
                title: const Text('Your fasting windows'),
                subtitle: const Text(
                    'Open your timer, choose a window and revisit your history.'),
                trailing: const Icon(Icons.arrow_forward_rounded),
                onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute<void>(
                        builder: (_) => FastingScreen(state: state))))),
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
                    '${p.currentWeightKg.toStringAsFixed(1)} kg • ${p.heightCm.round()} cm • ${CalorieEngine.age(p)} years',
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
        const SizedBox(height: 14),
        if (state.projectedGoalDate != null)
          Text(
            'Estimated goal date: ${DateFormat('d MMMM y').format(state.projectedGoalDate!)}',
            style: const TextStyle(
                color: AppColors.forest, fontWeight: FontWeight.w700),
          ),
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
                          ? (cloud.email ?? 'Sign in to sync')
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
                  : 'Your diary is saved on this device. Manual backups remain available while cloud sync is not connected.',
              style: const TextStyle(color: AppColors.muted, fontSize: 12),
            ),
            if (configured && !cloud.signedIn) ...[
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: () async {
                  if (kIsWeb) {
                    await cloud.signInWithGoogle();
                  } else if (context.mounted) {
                    await Navigator.of(context).push(MaterialPageRoute<void>(
                        builder: (routeContext) => LoginScreen(
                            cloud: cloud,
                            onContinueLocally: () =>
                                Navigator.pop(routeContext))));
                  }
                },
                icon: const Icon(Icons.login_rounded),
                label: const Text('Sign in to sync'),
              ),
            ],
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
        CloudSyncStatus.denied => 'This account is not approved.',
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
            Expanded(
                child: Text('Data & backup',
                    style: Theme.of(context).textTheme.titleMedium)),
          ]),
          const SizedBox(height: 10),
          const Text(
              'Your device copy is automatic. Keep an occasional manual backup as a second recovery path, especially before clearing app data.',
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
          if (state.retainedGuestBackup != null) ...[
            const Divider(height: 28),
            Text('Saved offline diary',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(
                state.guestLinkPending
                    ? 'Your account backup has not been checked yet. Your offline diary is retained and will not overwrite account history automatically.'
                    : 'Your offline diary was kept separately when you connected this account. Copy it for safekeeping or review before an explicit restore.',
                style: const TextStyle(color: AppColors.muted, fontSize: 12)),
            const SizedBox(height: 12),
            OutlinedButton.icon(
                onPressed: () => _copyRetainedGuestBackup(context),
                icon: const Icon(Icons.inventory_2_outlined),
                label: const Text('Copy saved offline diary')),
          ],
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
            Expanded(
                child: Text('How targets work',
                    style: Theme.of(context).textTheme.titleMedium))
          ]),
          const SizedBox(height: 12),
          Text('${state.baseCalorieTarget} kcal base',
              style:
                  const TextStyle(fontSize: 24, fontWeight: FontWeight.w900)),
          if (state.projectedGoalDate != null) ...[
            const SizedBox(height: 5),
            Text(
              'Estimated goal: ${DateFormat('d MMMM y').format(state.projectedGoalDate!)} • ${state.planRecommendation.projectedWeeklyRateKg.toStringAsFixed(2)} kg/week',
              style: const TextStyle(
                  color: AppColors.forest, fontWeight: FontWeight.w700),
            ),
          ],
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
            Expanded(
                child: Text('Food data & privacy',
                    style: Theme.of(context).textTheme.titleMedium))
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
          const Text('Saapadu • Personal nutrition estimates',
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

  Future<void> _copyRetainedGuestBackup(BuildContext context) async {
    final backup = state.retainedGuestBackup;
    if (backup == null) return;
    await Clipboard.setData(ClipboardData(text: backup));
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text(
              'Saved offline diary copied. Account history was not changed.')));
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

  Future<void> _editProfile(BuildContext context) =>
      ProfileScreen.open(context, state);
}
