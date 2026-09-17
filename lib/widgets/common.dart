import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../app_state.dart';
import '../theme.dart';

class PageFrame extends StatelessWidget {
  const PageFrame({super.key, required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 26, 20, 40),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1120),
              child: child,
            ),
          ),
        ),
      );
}

class DateNavigator extends StatelessWidget {
  const DateNavigator({super.key, required this.state});
  final AppState state;
  @override
  Widget build(BuildContext context) {
    final isToday = DateUtils.isSameDay(state.selectedDate, DateTime.now());
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          tooltip: 'Previous day',
          onPressed: () => state.setSelectedDate(
              state.selectedDate.subtract(const Duration(days: 1))),
          icon: const Icon(Icons.chevron_left),
        ),
        InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () async {
            final value = await showDatePicker(
              context: context,
              initialDate: state.selectedDate,
              firstDate: DateTime(2020),
              lastDate: DateTime.now().add(const Duration(days: 30)),
            );
            if (value != null) state.setSelectedDate(value);
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            child: Text(
              isToday
                  ? 'Today'
                  : DateFormat('EEE, d MMM').format(state.selectedDate),
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
        ),
        IconButton(
          tooltip: 'Next day',
          onPressed: DateUtils.isSameDay(state.selectedDate, DateTime.now())
              ? null
              : () => state.setSelectedDate(
                  state.selectedDate.add(const Duration(days: 1))),
          icon: const Icon(Icons.chevron_right),
        ),
      ],
    );
  }
}

class MacroBar extends StatelessWidget {
  const MacroBar({
    super.key,
    required this.name,
    required this.value,
    required this.target,
    required this.color,
  });
  final String name;
  final double value;
  final double target;
  final Color color;
  @override
  Widget build(BuildContext context) {
    final progress = target == 0 ? 0.0 : (value / target).clamp(0.0, 1.0);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          Expanded(
              child: Text(name,
                  style: const TextStyle(fontWeight: FontWeight.w700))),
          Text('${value.round()} / ${target.round()}g',
              style: const TextStyle(color: AppColors.muted, fontSize: 12)),
        ]),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: LinearProgressIndicator(
            value: progress,
            minHeight: 8,
            backgroundColor: AppColors.line,
            color: color,
          ),
        ),
      ],
    );
  }
}

class CalorieRing extends StatelessWidget {
  const CalorieRing({super.key, required this.eaten, required this.target});
  final double eaten;
  final int target;
  @override
  Widget build(BuildContext context) {
    final remaining = target - eaten.round();
    return SizedBox(
      width: 176,
      height: 176,
      child: CustomPaint(
        painter: _RingPainter(progress: target == 0 ? 0 : eaten / target),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('${remaining.abs()}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 36,
                  height: 1,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -1.4,
                )),
            const SizedBox(height: 5),
            Text(remaining >= 0 ? 'kcal left' : 'kcal over',
                style: TextStyle(
                    color: Colors.white.withValues(alpha: .7), fontSize: 12)),
          ],
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter({required this.progress});
  final double progress;
  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.width / 2 - 8;
    final base = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 10
      ..strokeCap = StrokeCap.round
      ..color = Colors.white.withValues(alpha: .12);
    final active = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 10
      ..strokeCap = StrokeCap.round
      ..color = progress > 1 ? AppColors.terracotta : AppColors.lime;
    canvas.drawCircle(center, radius, base);
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      math.pi * 2 * progress.clamp(0.0, 1.0),
      false,
      active,
    );
  }

  @override
  bool shouldRepaint(covariant _RingPainter oldDelegate) =>
      oldDelegate.progress != progress;
}

Future<double?> askNumber(
  BuildContext context, {
  required String title,
  required String label,
  required double initial,
  String? helper,
}) async {
  final controller =
      TextEditingController(text: initial == 0 ? '' : '$initial');
  return showDialog<double>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            autofocus: true,
            controller: controller,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(labelText: label, helperText: helper),
            onSubmitted: (_) =>
                Navigator.pop(context, double.tryParse(controller.text)),
          ),
        ],
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel')),
        FilledButton(
          onPressed: () =>
              Navigator.pop(context, double.tryParse(controller.text)),
          child: const Text('Save'),
        ),
      ],
    ),
  );
}
