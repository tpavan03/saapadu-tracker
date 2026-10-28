import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../app_state.dart';
import '../calorie_engine.dart';
import '../theme.dart';
import '../widgets/common.dart';

class FastingScreen extends StatefulWidget {
  const FastingScreen({super.key, required this.state});
  final AppState state;
  @override
  State<FastingScreen> createState() => _FastingScreenState();
}

class _FastingScreenState extends State<FastingScreen> {
  Timer? timer;
  int visibleHistory = 7;
  @override
  void initState() {
    super.initState();
    timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    timer?.cancel();
    super.dispose();
  }

  Future<void> _start() async {
    final profile = widget.state.profile!;
    if (DateTime.now().year - profile.birthYear < 18 ||
        CalorieEngine.bmi(profile) < 18.5) {
      await showDialog<void>(
          context: context,
          builder: (context) => AlertDialog(
                  title: const Text('Choose your timing with a clinician'),
                  content: const Text(
                      'Automatic fasting timers are not available for under-18 or underweight profiles. Food, hydration, activity and sleep tracking remain available.'),
                  actions: [
                    TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Got it'))
                  ]));
      return;
    }
    bool checked = false;
    final accepted = await showDialog<bool>(
        context: context,
        builder: (context) => StatefulBuilder(
            builder: (context, update) => AlertDialog(
                  title: const Text('Before you start'),
                  content: SizedBox(
                      width: 440,
                      child: SingleChildScrollView(
                          child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                            const Text(
                                'Fasting is optional. Ask your clinician first if you are pregnant or breastfeeding, have an eating-disorder history, frailty, use insulin or medicines that can cause low blood sugar, or follow a medically prescribed meal schedule.'),
                            const SizedBox(height: 16),
                            CheckboxListTile(
                                contentPadding: EdgeInsets.zero,
                                title: const Text(
                                    'None of these apply to me, and I choose to track a fasting window.'),
                                value: checked,
                                onChanged: (value) =>
                                    update(() => checked = value ?? false)),
                            const Text(
                                'Stop if you feel unwell. Never delay medication to keep a timer running.',
                                style: TextStyle(
                                    color: AppColors.muted, fontSize: 12)),
                          ]))),
                  actions: [
                    TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: const Text('Not now')),
                    FilledButton(
                        onPressed:
                            checked ? () => Navigator.pop(context, true) : null,
                        child: const Text('Start my timer'))
                  ],
                )));
    if (accepted == true) {
      await widget.state.startFast(widget.state.fasting.targetHours);
    }
  }

  Future<void> _custom() async {
    int hours = widget.state.fasting.targetHours;
    final chosen = await showDialog<int>(
        context: context,
        builder: (context) => StatefulBuilder(
            builder: (context, update) => AlertDialog(
                    title: const Text('Your own window'),
                    content: SizedBox(
                        width: 360,
                        child:
                            Column(mainAxisSize: MainAxisSize.min, children: [
                          Text(
                              '$hours hours fasting · ${24 - hours} hours eating',
                              style: Theme.of(context).textTheme.titleMedium),
                          Slider(
                              value: hours.toDouble(),
                              min: 8,
                              max: 20,
                              divisions: 12,
                              label: '$hours hours',
                              onChanged: (value) =>
                                  update(() => hours = value.round())),
                          const Text(
                              'A personal tracking preference, not a recommended meal schedule.',
                              style: TextStyle(color: AppColors.muted))
                        ])),
                    actions: [
                      TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('Cancel')),
                      FilledButton(
                          onPressed: () => Navigator.pop(context, hours),
                          child: const Text('Save window'))
                    ])));
    if (chosen != null) await widget.state.setFastingTarget(chosen);
  }

  Future<void> _end() async {
    final finish = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
                title: const Text('End this fasting window?'),
                content: const Text(
                    'Your elapsed time will be saved to history. Ending earlier is fine; every session is simply a record.'),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('Keep timer')),
                  FilledButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text('End & save'))
                ]));
    if (finish == true) await widget.state.stopFast();
  }

  @override
  Widget build(BuildContext context) {
    final fast = widget.state.fasting;
    final elapsed = fast.elapsedAt(DateTime.now());
    final target = Duration(hours: fast.targetHours);
    final progress = (elapsed.inSeconds / target.inSeconds).clamp(0.0, 1.0);
    final remaining = target - elapsed;
    final history = fast.history;
    final totalHours = history.fold<int>(
            0, (total, session) => total + session.duration.inMinutes) /
        60;
    String two(int value) => value.toString().padLeft(2, '0');
    final clock =
        '${two(elapsed.inHours)}:${two(elapsed.inMinutes % 60)}:${two(elapsed.inSeconds % 60)}';
    return PageFrame(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const SectionEyebrow(
          icon: Icons.timelapse_rounded, label: 'YOUR MEAL RHYTHM'),
      const SizedBox(height: 8),
      Text('Make space for your routine.',
          style: Theme.of(context).textTheme.headlineMedium),
      const SizedBox(height: 8),
      const Text(
          'An optional timer. No streak pressure. No changes to your calorie target.',
          style: TextStyle(color: AppColors.muted)),
      const SizedBox(height: 24),
      Container(
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
              color: AppColors.forest, borderRadius: BorderRadius.circular(32)),
          child: LayoutBuilder(builder: (context, box) {
            final dial = Semantics(
                label: fast.isActive
                    ? 'Fasting elapsed $clock'
                    : 'Fasting timer not started',
                child: SizedBox(
                    width: 236,
                    height: 236,
                    child: Stack(alignment: Alignment.center, children: [
                      SizedBox.expand(
                          child: CircularProgressIndicator(
                              value: fast.isActive ? progress : 0,
                              strokeWidth: 11,
                              backgroundColor:
                                  Colors.white.withValues(alpha: .14),
                              color: AppColors.lime,
                              strokeCap: StrokeCap.round)),
                      Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                                fast.isActive
                                    ? Icons.nights_stay_rounded
                                    : Icons.spa_rounded,
                                color: AppColors.lime,
                                size: 30),
                            const SizedBox(height: 14),
                            Text(
                                fast.isActive
                                    ? clock
                                    : '${fast.targetHours}:${24 - fast.targetHours}',
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontFamily: 'Sora',
                                    fontSize: 30,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: -1)),
                            const SizedBox(height: 6),
                            Text(
                                fast.isActive
                                    ? 'elapsed'
                                    : 'your fasting window',
                                style: TextStyle(
                                    color: Colors.white.withValues(alpha: .7),
                                    fontSize: 12))
                          ]),
                    ])));
            final info =
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(fast.isActive ? 'TIMER IS RUNNING' : 'SET YOUR OWN PACE',
                  style: const TextStyle(
                      color: AppColors.lime,
                      fontSize: 11,
                      letterSpacing: 1.8,
                      fontWeight: FontWeight.w800)),
              const SizedBox(height: 12),
              Text(
                  fast.isActive
                      ? progress >= 1
                          ? 'Your window is complete.'
                          : '${remaining.inHours}h ${remaining.inMinutes % 60}m to your target.'
                      : 'A little structure.\nYour choice of timing.',
                  style: const TextStyle(
                      fontFamily: 'Sora',
                      color: Colors.white,
                      fontSize: 27,
                      height: 1.3,
                      fontWeight: FontWeight.w600)),
              const SizedBox(height: 14),
              Text(
                  fast.isActive
                      ? 'Started ${DateFormat('EEE, h:mm a').format(fast.startedAt!.toLocal())}\nTarget ${DateFormat('EEE, h:mm a').format(fast.targetAt!.toLocal())}\nYour timer keeps running when you close the app.'
                      : '${fast.targetHours} hours fasting · ${24 - fast.targetHours} hours eating.\nStart when you are ready. Water tracking stays separate.',
                  style: TextStyle(
                      color: Colors.white.withValues(alpha: .75), height: 1.6)),
              const SizedBox(height: 22),
              FilledButton.icon(
                  style: FilledButton.styleFrom(
                      backgroundColor: AppColors.lime,
                      foregroundColor: AppColors.ink),
                  onPressed: fast.isActive ? _end : _start,
                  icon: Icon(fast.isActive
                      ? Icons.stop_circle_outlined
                      : Icons.play_arrow_rounded),
                  label: Text(fast.isActive
                      ? 'End & save window'
                      : 'Start fasting timer')),
            ]);
            return box.maxWidth >= 650
                ? Row(children: [
                    dial,
                    const SizedBox(width: 42),
                    Expanded(child: info)
                  ])
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                        Center(child: dial),
                        const SizedBox(height: 28),
                        info
                      ]);
          })),
      const SizedBox(height: 24),
      Row(children: [
        Expanded(
            child: Text('Choose a window',
                style: Theme.of(context).textTheme.titleLarge)),
        if (!fast.isActive)
          TextButton.icon(
              onPressed: _custom,
              icon: const Icon(Icons.tune_rounded, size: 18),
              label: const Text('Custom'))
      ]),
      const SizedBox(height: 12),
      Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [12, 14, 16]
              .map((hours) => SizedBox(
                  width: 150,
                  child: ChoiceChip(
                      showCheckmark: true,
                      selected: fast.targetHours == hours,
                      onSelected: fast.isActive
                          ? null
                          : (_) => widget.state.setFastingTarget(hours),
                      label: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Text('$hours:${24 - hours} window')))))
              .toList()),
      if (fast.isActive)
        const Padding(
            padding: EdgeInsets.only(top: 8),
            child: Text('End the active window before changing your plan.',
                style: TextStyle(color: AppColors.muted, fontSize: 12))),
      const SizedBox(height: 24),
      Card(
          child: Padding(
              padding: const EdgeInsets.all(22),
              child: Row(children: [
                _stat('${history.length}', 'sessions recorded',
                    Icons.history_rounded),
                _stat(totalHours.toStringAsFixed(1), 'hours recorded',
                    Icons.schedule_rounded),
                _stat(
                    '${history.where((session) => session.targetReached).length}',
                    'target windows',
                    Icons.check_circle_outline)
              ]))),
      const SizedBox(height: 26),
      Text('Your window history',
          style: Theme.of(context).textTheme.titleLarge),
      const SizedBox(height: 12),
      if (history.isEmpty)
        Card(
            child: Padding(
                padding: const EdgeInsets.all(28),
                child: Row(children: [
                  const Icon(Icons.hourglass_empty_rounded,
                      color: AppColors.leaf, size: 32),
                  const SizedBox(width: 18),
                  Expanded(
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                        Text('A fresh start, whenever you choose.',
                            style: Theme.of(context).textTheme.titleMedium),
                        const SizedBox(height: 5),
                        const Text(
                            'Completed and ended-early sessions appear here. No session is a failure.',
                            style: TextStyle(color: AppColors.muted))
                      ]))
                ])))
      else
        Card(
            child: Column(
                children: history
                    .take(visibleHistory)
                    .map((session) => ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 22, vertical: 8),
                        leading: const CircleAvatar(
                            backgroundColor: AppColors.cream,
                            child: Icon(Icons.nights_stay_outlined,
                                color: AppColors.forest)),
                        title: Text(
                            DateFormat('EEEE, d MMM')
                                .format(session.startedAt.toLocal()),
                            style:
                                const TextStyle(fontWeight: FontWeight.w700)),
                        subtitle: Text(
                            '${DateFormat.jm().format(session.startedAt.toLocal())} → ${DateFormat.jm().format(session.endedAt.toLocal())} · ${session.targetHours}h target'),
                        trailing: Text(
                            '${session.duration.inHours}h ${session.duration.inMinutes % 60}m',
                            style: const TextStyle(
                                fontFamily: 'Sora',
                                fontWeight: FontWeight.w600))))
                    .toList())),
      if (history.length > visibleHistory)
        TextButton(
            onPressed: () => setState(() => visibleHistory += 10),
            child: const Text('Show more sessions')),
      const SizedBox(height: 22),
      const Text(
          'Fasting is optional and may not suit everyone. It does not replace a balanced diet or change your calorie target. Stop if you feel unwell. If you use diabetes medicine or have a medical condition, ask your clinician before changing meal timing.',
          style: TextStyle(color: AppColors.muted, fontSize: 12, height: 1.6)),
    ]));
  }

  Widget _stat(String value, String label, IconData icon) => Expanded(
          child: Column(children: [
        Icon(icon, color: AppColors.forest, size: 22),
        const SizedBox(height: 10),
        Text(value,
            style: const TextStyle(
                fontFamily: 'Sora', fontSize: 23, fontWeight: FontWeight.w600)),
        const SizedBox(height: 3),
        Text(label,
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.muted, fontSize: 11))
      ]));
}
