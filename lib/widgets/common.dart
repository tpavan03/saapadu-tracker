import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../app_state.dart';
import '../theme.dart';

class PageFrame extends StatefulWidget {
  const PageFrame({super.key, required this.child});
  final Widget child;
  @override
  State<PageFrame> createState() => _PageFrameState();
}

class _PageFrameState extends State<PageFrame> {
  final _scroll = ScrollController();

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: Scrollbar(
            controller: _scroll,
            thumbVisibility: true,
            child: SingleChildScrollView(
              controller: _scroll,
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 40),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1120),
                child: widget.child,
              ),
            ),
          ),
        ),
      );
}

/// Original bowl-and-rice mark, also usable for the native launcher identity.
class SaapaduMark extends StatelessWidget {
  const SaapaduMark({super.key, this.size = 40});
  final double size;
  @override
  Widget build(BuildContext context) => ExcludeSemantics(
      child: SizedBox(
          width: size,
          height: size,
          child: CustomPaint(
              size: Size.square(size), foregroundPainter: _BowlMarkPainter())));
}

class _BowlMarkPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.width / 40;
    canvas.save();
    canvas.scale(scale);
    canvas.drawRRect(
        RRect.fromRectAndRadius(
            const Rect.fromLTWH(0, 0, 40, 40), const Radius.circular(13)),
        Paint()..color = AppColors.hero);
    final bowl = Path()
      ..moveTo(7, 22)
      ..quadraticBezierTo(9, 34, 20, 34)
      ..quadraticBezierTo(31, 34, 33, 22)
      ..close();
    canvas.drawPath(bowl, Paint()..color = AppColors.lime);
    final line = Paint()
      ..color = AppColors.cream
      ..strokeWidth = 1.6
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(const Offset(12, 25), const Offset(16, 25), line);
    canvas.drawLine(const Offset(19, 27), const Offset(22, 27), line);
    canvas.drawLine(const Offset(25, 24), const Offset(28, 24), line);
    final steam = Paint()
      ..color = AppColors.forest
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.9
      ..strokeCap = StrokeCap.round;
    for (final x in [15.0, 22.0]) {
      canvas.drawPath(
          Path()
            ..moveTo(x, 17)
            ..cubicTo(x - 4, 13, x + 4, 12, x, 8),
          steam);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_BowlMarkPainter oldDelegate) => false;
}

class SectionEyebrow extends StatelessWidget {
  const SectionEyebrow({super.key, required this.icon, required this.label});
  final IconData icon;
  final String label;
  @override
  Widget build(BuildContext context) =>
      Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 16, color: AppColors.forest),
        const SizedBox(width: 8),
        Flexible(
            child: Text(label,
                style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.7,
                    color: AppColors.forest)))
      ]);
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
        TextButton(
          onPressed: () async {
            final value = await showDatePicker(
              context: context,
              initialDate: state.selectedDate,
              firstDate: DateTime(2020),
              lastDate: DateTime.now().add(const Duration(days: 30)),
            );
            if (value != null) state.setSelectedDate(value);
          },
          child: Text(
            isToday
                ? 'Today'
                : DateFormat('EEE, d MMM').format(state.selectedDate),
            style: const TextStyle(fontWeight: FontWeight.w800),
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
  const CalorieRing(
      {super.key,
      required this.eaten,
      required this.target,
      this.diameter = 198});
  final double eaten;
  final int target;
  final double diameter;
  @override
  Widget build(BuildContext context) {
    final remaining = target - eaten.round();
    return Semantics(
        label:
            'Estimated energy budget: ${eaten.round()} of $target kilocalories logged. ${remaining.abs()} kilocalories ${remaining >= 0 ? 'remaining' : 'above the estimate'}.',
        child: ExcludeSemantics(
            child: SizedBox(
          width: diameter,
          height: diameter,
          child: CustomPaint(
            painter: _RingPainter(progress: target == 0 ? 0 : eaten / target),
            child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text('${remaining.abs()}',
                            style: const TextStyle(
                              fontFamily: 'Sora',
                              color: AppColors.ink,
                              fontSize: 36,
                              height: 1,
                              fontWeight: FontWeight.w900,
                              letterSpacing: -1.4,
                            ))),
                    const SizedBox(height: 9),
                    Text(
                        remaining >= 0
                            ? 'kcal remaining'
                            : 'kcal above estimate',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                            color: AppColors.muted, fontSize: 11)),
                  ],
                )),
          ),
        )));
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter({required this.progress});
  final double progress;
  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.width / 2 - 9;
    final base = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 11
      ..strokeCap = StrokeCap.round
      ..color = AppColors.forest.withValues(alpha: .13);
    final active = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 11
      ..strokeCap = StrokeCap.round
      ..color = progress > 1 ? AppColors.terracotta : AppColors.lime;
    const start = math.pi * .72;
    const sweep = math.pi * 1.56;
    canvas.drawArc(Rect.fromCircle(center: center, radius: radius), start,
        sweep, false, base);
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      start,
      sweep * progress.clamp(0.0, 1.0),
      false,
      active,
    );
    final inner = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = AppColors.forest.withValues(alpha: .12);
    canvas.drawCircle(center, radius - 13, inner);
    // Three rice-grain marks complete the open plate without implying more data.
    final rice = Paint()
      ..color = AppColors.lime
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    for (final dx in [-8.0, 0.0, 8.0]) {
      canvas.drawLine(Offset(center.dx + dx - 1, size.height - 16),
          Offset(center.dx + dx + 1, size.height - 12), rice);
    }
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
