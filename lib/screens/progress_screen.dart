import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../app_state.dart';
import '../calorie_engine.dart';
import '../models.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'plan_screen.dart';
import 'weight_check_in_screen.dart';

class ProgressScreen extends StatelessWidget {
  const ProgressScreen({super.key, required this.state});
  final AppState state;

  @override
  Widget build(BuildContext context) {
    final p = state.profile!;
    final start = state.weights.isEmpty
        ? p.currentWeightKg
        : state.weights.first.weightKg;
    final change = p.currentWeightKg - start;
    final remaining = (p.currentWeightKg - p.goalWeightKg).abs();
    return PageFrame(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('LONG VIEW',
              style: TextStyle(
                  fontSize: 11,
                  letterSpacing: 1.2,
                  fontWeight: FontWeight.w900,
                  color: AppColors.leaf)),
          const SizedBox(height: 4),
          Text('Progress, over perfection',
              style: Theme.of(context).textTheme.headlineMedium),
        ])),
        FilledButton.icon(
            onPressed: () => _logWeight(context),
            icon: const Icon(Icons.add),
            label: const Text('Log weight')),
      ]),
      const SizedBox(height: 24),
      LayoutBuilder(builder: (context, box) {
        final width =
            box.maxWidth > 720 ? (box.maxWidth - 24) / 3 : box.maxWidth;
        return Wrap(spacing: 12, runSpacing: 12, children: [
          _metric(
              width,
              'Current',
              '${p.currentWeightKg.toStringAsFixed(1)} kg',
              Icons.monitor_weight_outlined,
              AppColors.forest),
          _metric(
              width,
              'Since start',
              '${change >= 0 ? '+' : ''}${change.toStringAsFixed(1)} kg',
              Icons.trending_down,
              AppColors.terracotta),
          _metric(width, 'To goal', '${remaining.toStringAsFixed(1)} kg',
              Icons.flag_outlined, AppColors.sky),
        ]);
      }),
      const SizedBox(height: 18),
      _weeklySummaryCard(context),
      const SizedBox(height: 18),
      _checkInCard(context),
      const SizedBox(height: 18),
      Card(
          child: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(
                child: Text('Weight trend',
                    style: Theme.of(context).textTheme.titleLarge)),
            Text('${state.weights.length} check-ins',
                style: const TextStyle(color: AppColors.muted, fontSize: 12)),
          ]),
          const SizedBox(height: 20),
          SizedBox(
              height: 240,
              width: double.infinity,
              child: state.weights.length < 2
                  ? const Center(
                      child: Text('Log weight twice to see your trend.',
                          style: TextStyle(color: AppColors.muted)))
                  : CustomPaint(
                      painter: _WeightChart(
                          state.weights.map((e) => e.weightKg).toList(),
                          p.goalWeightKg))),
        ]),
      )),
      const SizedBox(height: 18),
      _bodyCard(context),
      const SizedBox(height: 18),
      _planCard(context),
      TextButton.icon(
          onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(
              builder: (_) => WeightHistoryScreen(state: state))),
          icon: const Icon(Icons.history_rounded),
          label: const Text('View and edit weight check-ins')),
      const SizedBox(height: 18),
      LayoutBuilder(builder: (context, box) {
        final bmi = CalorieEngine.bmi(p);
        final cardWidth =
            box.maxWidth > 720 ? (box.maxWidth - 12) / 2 : box.maxWidth;
        return Wrap(spacing: 12, runSpacing: 12, children: [
          SizedBox(
              width: cardWidth,
              child: Card(
                  child: Padding(
                padding: const EdgeInsets.all(22),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('BODY MASS INDEX',
                          style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1,
                              color: AppColors.muted)),
                      const SizedBox(height: 8),
                      Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(bmi.toStringAsFixed(1),
                                style: const TextStyle(
                                    fontSize: 38,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: -1)),
                            const SizedBox(width: 8),
                            Expanded(
                                child: Padding(
                                    padding: const EdgeInsets.only(bottom: 7),
                                    child: Text(CalorieEngine.bmiLabel(bmi),
                                        style: const TextStyle(
                                            color: AppColors.muted)))),
                          ]),
                      const SizedBox(height: 12),
                      const Text(
                          'BMI is a screening measure. Body composition and South Asian metabolic risk can make the full picture different.',
                          style:
                              TextStyle(fontSize: 12, color: AppColors.muted)),
                    ]),
              ))),
          SizedBox(
              width: cardWidth,
              child: Card(
                  child: Padding(
                padding: const EdgeInsets.all(22),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('YOUR PACE',
                          style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1,
                              color: AppColors.muted)),
                      const SizedBox(height: 11),
                      Text(
                          '${(state.weightForecast.weeklyChangeKg?.abs() ?? state.planRecommendation.projectedWeeklyRateKg).toStringAsFixed(2)} kg / week',
                          style: const TextStyle(
                              fontSize: 23, fontWeight: FontWeight.w900)),
                      const SizedBox(height: 10),
                      Text(
                          state.weightForecast.usesObservedTrend
                              ? 'Observed from your recent check-ins, rather than a promised weekly result.'
                              : state.planRecommendation.usesManualTarget
                                  ? 'Calculated from your custom calorie target. Change that target to move the forecast date.'
                                  : 'Daily scale changes are mostly water. Compare weekly averages and adjust after 2–3 consistent weeks.',
                          style: const TextStyle(
                              fontSize: 12, color: AppColors.muted)),
                    ]),
              ))),
        ]);
      }),
    ]));
  }

  Widget _metric(double width, String label, String value, IconData icon,
          Color color) =>
      SizedBox(
          width: width,
          child: Card(
              child: Padding(
            padding: const EdgeInsets.all(18),
            child: Row(children: [
              Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                      color: color.withValues(alpha: .14),
                      borderRadius: BorderRadius.circular(14)),
                  child: Icon(icon, color: color)),
              const SizedBox(width: 13),
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(label,
                    style:
                        const TextStyle(color: AppColors.muted, fontSize: 11)),
                Text(value,
                    style: const TextStyle(
                        fontSize: 20, fontWeight: FontWeight.w900))
              ]),
            ]),
          )));

  Widget _weeklySummaryCard(BuildContext context) {
    final w = state.weeklySummaryFor(DateTime.now());
    String fmtDate(String key) => DateFormat('d MMM').format(DateTime.parse(key));
    final change = w.weightChangeKg;
    final rows = <(String, String)>[
      ('Days logged', '${w.daysLogged} of 7'),
      (
        'Avg calories',
        w.daysLogged == 0
            ? '—'
            : '${w.avgCalories.round()} / ${w.avgTarget.round()} kcal'
      ),
      ('Avg protein', w.daysLogged == 0 ? '—' : '${w.avgProtein.round()} g'),
      (
        'Weight change',
        change == null
            ? '—'
            : '${change >= 0 ? '+' : ''}${change.toStringAsFixed(1)} kg'
      ),
      ('Steps', '${NumberFormat.decimalPattern().format(w.totalSteps)} total · ${NumberFormat.decimalPattern().format(w.avgSteps)} avg'),
      ('Logging streak', '${state.loggingStreakDays} days'),
    ];
    return Card(
        child: Padding(
      padding: const EdgeInsets.all(22),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('This week', style: Theme.of(context).textTheme.titleLarge),
        Text('${fmtDate(w.fromKey)} – ${fmtDate(w.toKey)} · averages use logged days',
            style: const TextStyle(color: AppColors.muted, fontSize: 12)),
        const SizedBox(height: 12),
        for (final r in rows)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 5),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded(
                  child: Text(r.$1,
                      style: const TextStyle(color: AppColors.muted))),
              const SizedBox(width: 12),
              Flexible(
                  child: Text(r.$2,
                      textAlign: TextAlign.end,
                      style: const TextStyle(fontWeight: FontWeight.w800))),
            ]),
          ),
      ]),
    ));
  }

  Widget _bodyCard(BuildContext context) {
    final records = state.bodyCompositionSorted;
    String trend(String field) {
      final points = [
        for (final r in records)
          if (r[field] != null) (r.date, r[field]!)
      ];
      if (points.isEmpty) return '—';
      final (_, unit) = BodyComposition.fields[field]!;
      final last = points.last.$2;
      final text = '${last.toStringAsFixed(1)} $unit';
      if (points.length < 2) return text;
      final first = points.length > 4 ? points[points.length - 5] : points.first;
      final delta = last - first.$2;
      return '$text (${delta >= 0 ? '+' : ''}${delta.toStringAsFixed(1)} since ${DateFormat('d MMM').format(DateTime.parse(first.$1))})';
    }

    final shown = ['waistCm', 'hipCm', 'chestCm', 'bodyFatPct', 'muscleKg']
        .where((f) => records.any((r) => r[f] != null))
        .toList();
    return Card(
        child: Padding(
      padding: const EdgeInsets.all(22),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Body measurements', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 6),
        Text(
            shown.isEmpty
                ? 'Optional: add waist, hip and chest, or smart-scale readings, on a weight check-in.'
                : state.measurementsDue
                    ? 'Tape measurements are due — every two weeks is plenty.'
                    : 'Latest reading, with the change across recent check-ins.',
            style: const TextStyle(color: AppColors.muted, fontSize: 12)),
        const SizedBox(height: 10),
        for (final f in shown)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 5),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded(
                  child: Text(BodyComposition.fields[f]!.$1,
                      style: const TextStyle(color: AppColors.muted))),
              const SizedBox(width: 12),
              Flexible(
                  child: Text(trend(f),
                      textAlign: TextAlign.end,
                      style: const TextStyle(fontWeight: FontWeight.w800))),
            ]),
          ),
        if (shown.any((f) => f == 'bodyFatPct' || f == 'muscleKg'))
          const Padding(
            padding: EdgeInsets.only(top: 8),
            child: Text(
                'Home scales vary from day to day with water and timing. Compare trends week to week, not single readings. These readings do not change your calorie target.',
                style: TextStyle(color: AppColors.muted, fontSize: 11)),
          ),
      ]),
    ));
  }

  Widget _checkInCard(BuildContext context) {
    final due = state.nextWeightCheckInDate;
    final isDue = state.weightCheckInDue;
    return Card(
        child: Padding(
            padding: const EdgeInsets.all(20),
            child: Row(children: [
              const Icon(Icons.calendar_month_outlined,
                  color: AppColors.forest),
              const SizedBox(width: 14),
              Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    Text(
                        isDue
                            ? 'Your weekly check-in is ready'
                            : 'Your next check-in',
                        style: Theme.of(context).textTheme.titleMedium),
                    Text(
                        isDue
                            ? 'A fresh reading helps keep your forecast current.'
                            : DateFormat('EEEE, d MMMM').format(due!),
                        style: const TextStyle(
                            color: AppColors.muted, fontSize: 12)),
                  ])),
              const SizedBox(width: 8),
              TextButton(
                  onPressed: () => _logWeight(context),
                  child: const Text('Check in')),
            ])));
  }

  Widget _planCard(BuildContext context) {
    final profile = state.profile!;
    final plan = state.planRecommendation;
    final forecast = state.weightForecast;
    final date = forecast.estimatedDate;
    return Card(
        child: Padding(
            padding: const EdgeInsets.all(22),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                const Icon(Icons.route_outlined, color: AppColors.forest),
                const SizedBox(width: 12),
                Expanded(
                    child: Text(
                        forecast.usesObservedTrend
                            ? 'Your updated trend estimate'
                            : 'Your goal estimate',
                        style: Theme.of(context).textTheme.titleMedium)),
              ]),
              const SizedBox(height: 16),
              Text(
                  date == null
                      ? 'More consistent readings needed'
                      : DateFormat('d MMMM y').format(date),
                  style: Theme.of(context).textTheme.headlineMedium),
              const SizedBox(height: 8),
              Text(
                  '${profile.goalWeightKg.toStringAsFixed(1)} kg goal · ${plan.effectiveTarget} kcal daily target',
                  style: const TextStyle(color: AppColors.muted)),
              const SizedBox(height: 12),
              Text(forecast.explanation,
                  style: const TextStyle(
                      color: AppColors.muted, fontSize: 12, height: 1.6)),
              if (profile.goalDate != null) ...[
                const SizedBox(height: 10),
                Text(
                    'Your requested date: ${DateFormat('d MMMM y').format(profile.goalDate!)}',
                    style: const TextStyle(fontSize: 12)),
              ],
              if (forecast.usesObservedTrend && forecast.modelDate != null) ...[
                const SizedBox(height: 6),
                Text(
                    'Calorie-plan estimate: ${DateFormat('d MMMM y').format(forecast.modelDate!)}',
                    style:
                        const TextStyle(color: AppColors.muted, fontSize: 12)),
              ],
              const SizedBox(height: 16),
              FilledButton.tonal(
                  onPressed: () => PlanScreen.open(context, state),
                  child: const Text('Adjust goal plan')),
            ])));
  }

  Future<void> _logWeight(BuildContext context) =>
      WeightCheckInScreen.open(context, state);
}

class _WeightChart extends CustomPainter {
  _WeightChart(this.values, this.goal);
  final List<double> values;
  final double goal;
  @override
  void paint(Canvas canvas, Size size) {
    final all = [...values, goal];
    final minValue = all.reduce(math.min) - 1;
    final maxValue = all.reduce(math.max) + 1;
    final span = math.max(maxValue - minValue, 1);
    final chart = Rect.fromLTWH(8, 8, size.width - 16, size.height - 28);
    final grid = Paint()
      ..color = AppColors.line
      ..strokeWidth = 1;
    for (var i = 0; i <= 4; i++) {
      final y = chart.top + chart.height * i / 4;
      canvas.drawLine(Offset(chart.left, y), Offset(chart.right, y), grid);
    }
    double yFor(double value) =>
        chart.bottom - ((value - minValue) / span) * chart.height;
    final goalPaint = Paint()
      ..color = AppColors.terracotta.withValues(alpha: .55)
      ..strokeWidth = 1.5;
    canvas.drawLine(Offset(chart.left, yFor(goal)),
        Offset(chart.right, yFor(goal)), goalPaint);
    final path = Path();
    for (var i = 0; i < values.length; i++) {
      final x = chart.left + chart.width * i / math.max(values.length - 1, 1);
      final y = yFor(values[i]);
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    canvas.drawPath(
        path,
        Paint()
          ..color = AppColors.forest
          ..strokeWidth = 3
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round);
    for (var i = 0; i < values.length; i++) {
      final x = chart.left + chart.width * i / math.max(values.length - 1, 1);
      canvas.drawCircle(
          Offset(x, yFor(values[i])), 4.5, Paint()..color = AppColors.lime);
      canvas.drawCircle(
          Offset(x, yFor(values[i])),
          4.5,
          Paint()
            ..color = AppColors.forest
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2);
    }
  }

  @override
  bool shouldRepaint(covariant _WeightChart old) =>
      old.values != values || old.goal != goal;
}
