import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../app_state.dart';
import '../calorie_engine.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'plan_screen.dart';

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
      _planCard(context),
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
                            Padding(
                                padding: const EdgeInsets.only(bottom: 7),
                                child: Text(CalorieEngine.bmiLabel(bmi),
                                    style: const TextStyle(
                                        color: AppColors.muted))),
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
                      Text('${p.weeklyGoalKg.toStringAsFixed(2)} kg / week',
                          style: const TextStyle(
                              fontSize: 23, fontWeight: FontWeight.w900)),
                      const SizedBox(height: 10),
                      const Text(
                          'Daily scale changes are mostly water. Compare weekly averages and adjust after 2–3 consistent weeks.',
                          style:
                              TextStyle(fontSize: 12, color: AppColors.muted)),
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

  Widget _planCard(BuildContext context) {
    final profile = state.profile!;
    final plan = state.planRecommendation;
    final date = plan.projectedGoalDate;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Row(children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: AppColors.lime.withValues(alpha: .4),
              borderRadius: BorderRadius.circular(15),
            ),
            child: const Icon(Icons.route_outlined, color: AppColors.forest),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                    date == null
                        ? 'Goal plan'
                        : 'You will reach ${profile.goalWeightKg.toStringAsFixed(1)} kg by ${DateFormat('d MMMM y').format(date)}',
                    style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 3),
                Text(
                  plan.usesManualTarget
                      ? '${plan.effectiveTarget} kcal custom • ${plan.projectedWeeklyRateKg.toStringAsFixed(2)} kg/week'
                      : '${plan.recommendedTarget} kcal recommended • ${plan.projectedWeeklyRateKg.toStringAsFixed(2)} kg/week',
                  style: const TextStyle(color: AppColors.muted, fontSize: 12),
                ),
                if (date != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    'Estimated completion: ${DateFormat('d MMMM y').format(date)} • updates after each weigh-in',
                    style: const TextStyle(
                        color: AppColors.forest,
                        fontSize: 12,
                        fontWeight: FontWeight.w700),
                  ),
                ],
              ],
            ),
          ),
          FilledButton.tonal(
            onPressed: () => PlanScreen.open(context, state),
            child: const Text('Adjust plan'),
          ),
        ]),
      ),
    );
  }

  Future<void> _logWeight(BuildContext context) async {
    final value = await askNumber(context,
        title: 'Log weight',
        label: 'Weight (kg)',
        initial: state.profile!.currentWeightKg);
    if (value != null && value >= 25 && value <= 400) state.logWeight(value);
  }
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
