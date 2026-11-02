import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../app_state.dart';
import '../models.dart';
import '../theme.dart';

class WeightCheckInScreen extends StatefulWidget {
  const WeightCheckInScreen({super.key, required this.state, this.entry});
  final AppState state;
  final WeightEntry? entry;
  static Future<void> open(BuildContext context, AppState state,
          {WeightEntry? entry}) =>
      Navigator.of(context).push(MaterialPageRoute<void>(
          builder: (_) => WeightCheckInScreen(state: state, entry: entry)));
  @override
  State<WeightCheckInScreen> createState() => _WeightCheckInScreenState();
}

class _WeightCheckInScreenState extends State<WeightCheckInScreen> {
  final form = GlobalKey<FormState>();
  late final TextEditingController weight;
  late DateTime date;
  bool saving = false;
  String? error;
  @override
  void initState() {
    super.initState();
    weight = TextEditingController(
        text: (widget.entry?.weightKg ?? widget.state.profile!.currentWeightKg)
            .toStringAsFixed(1));
    date = widget.entry == null
        ? DateTime.now()
        : DateTime.parse(widget.entry!.date);
  }

  @override
  void dispose() {
    weight.dispose();
    super.dispose();
  }

  Future<void> save() async {
    if (saving || !form.currentState!.validate()) return;
    setState(() {
      saving = true;
      error = null;
    });
    try {
      await widget.state.logWeight(double.parse(weight.text), date: date);
      if (mounted) Navigator.pop(context);
    } catch (_) {
      if (mounted) {
        setState(() {
          saving = false;
          error =
              'Could not save this check-in. Your entry is kept here; try again.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
            title: Text(widget.entry == null
                ? 'Weekly weight check-in'
                : 'Edit weight check-in')),
        body: SafeArea(
            child: Center(
                child: SingleChildScrollView(
                    padding: const EdgeInsets.all(24),
                    child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 520),
                        child: Form(
                            key: form,
                            child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  const Icon(Icons.monitor_weight_outlined,
                                      color: AppColors.forest, size: 48),
                                  const SizedBox(height: 18),
                                  Text('One reading. A longer view.',
                                      style: Theme.of(context)
                                          .textTheme
                                          .headlineMedium),
                                  const SizedBox(height: 12),
                                  const Text(
                                      'Check in around the same time each week if that suits you. Your forecast updates as a trend forms; a single reading is not a verdict.',
                                      style: TextStyle(
                                          color: AppColors.muted, height: 1.6)),
                                  const SizedBox(height: 28),
                                  TextFormField(
                                      controller: weight,
                                      enabled: !saving,
                                      autofocus: true,
                                      keyboardType:
                                          const TextInputType.numberWithOptions(
                                              decimal: true),
                                      decoration: const InputDecoration(
                                          labelText: 'Weight',
                                          suffixText: 'kg'),
                                      validator: (value) {
                                        final n = double.tryParse(value ?? '');
                                        return n == null ||
                                                !n.isFinite ||
                                                n < 30 ||
                                                n > 350
                                            ? 'Enter a weight between 30 and 350 kg'
                                            : null;
                                      }),
                                  const SizedBox(height: 18),
                                  OutlinedButton.icon(
                                      onPressed: saving || widget.entry != null
                                          ? null
                                          : () async {
                                              final now = DateTime.now();
                                              final selected =
                                                  await showDatePicker(
                                                      context: context,
                                                      initialDate: date,
                                                      firstDate: DateTime(
                                                          now.year - 10,
                                                          now.month,
                                                          now.day),
                                                      lastDate: now);
                                              if (selected != null) {
                                                setState(() => date = selected);
                                              }
                                            },
                                      icon: const Icon(Icons.event_outlined),
                                      label: Text(DateFormat('EEEE, d MMMM y')
                                          .format(date))),
                                  const SizedBox(height: 12),
                                  const Text(
                                      'One saved reading per date. Saving again on the same date corrects that reading. Older diary targets are preserved.',
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
                                                    color: AppColors
                                                        .terracotta)))),
                                  const SizedBox(height: 24),
                                  FilledButton.icon(
                                      onPressed: saving ? null : save,
                                      icon: Icon(saving
                                          ? Icons.hourglass_top_rounded
                                          : Icons.check_rounded),
                                      label: Text(saving
                                          ? 'Saving check-in…'
                                          : 'Save check-in')),
                                ])))))),
      );
}

class WeightHistoryScreen extends StatefulWidget {
  const WeightHistoryScreen({super.key, required this.state});
  final AppState state;
  @override
  State<WeightHistoryScreen> createState() => _WeightHistoryScreenState();
}

class _WeightHistoryScreenState extends State<WeightHistoryScreen> {
  int limit = 30;
  @override
  Widget build(BuildContext context) => AnimatedBuilder(
      animation: widget.state,
      builder: (context, _) {
        final entries = widget.state.weights.reversed.toList();
        return Scaffold(
            appBar: AppBar(title: const Text('Weight check-ins')),
            body: SafeArea(
                child: ListView(padding: const EdgeInsets.all(20), children: [
              const Text(
                  'Tap a reading to correct it. Only the latest dated reading sets your current profile weight.',
                  style: TextStyle(color: AppColors.muted)),
              const SizedBox(height: 18),
              for (final entry in entries.take(limit))
                Card(
                    child: ListTile(
                        leading: const Icon(Icons.monitor_weight_outlined),
                        title: Text('${entry.weightKg.toStringAsFixed(1)} kg'),
                        subtitle: Text(DateFormat('d MMMM y')
                            .format(DateTime.parse(entry.date))),
                        trailing: const Icon(Icons.edit_outlined),
                        onTap: () => WeightCheckInScreen.open(
                            context, widget.state,
                            entry: entry))),
              if (entries.length > limit)
                TextButton(
                    onPressed: () => setState(() => limit += 30),
                    child: const Text('Load more check-ins')),
              if (entries.isEmpty)
                const Padding(
                    padding: EdgeInsets.all(24),
                    child: Text('Your first check-in will appear here.')),
            ])));
      });
}
