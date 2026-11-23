import 'package:flutter/material.dart';

import '../insights.dart';
import '../models.dart';
import '../theme.dart';

/// Continuous quantity control: a smooth slider plus editable servings and
/// grams fields that stay in sync, with live energy and macros.
class ServingEditor extends StatefulWidget {
  const ServingEditor({
    super.key,
    required this.food,
    required this.initial,
    required this.onChanged,
  });
  final FoodItem food;
  final double initial;
  final ValueChanged<double> onChanged;

  @override
  State<ServingEditor> createState() => _ServingEditorState();
}

class _ServingEditorState extends State<ServingEditor> {
  late double servings = ServingMath.normalize(widget.initial);
  late final TextEditingController servingText =
      TextEditingController(text: ServingMath.format(servings));
  late final TextEditingController gramText = TextEditingController(
      text: ServingMath.format(ServingMath.gramsFor(widget.food, servings),
          decimals: 0));
  final servingFocus = FocusNode();
  final gramFocus = FocusNode();

  bool get hasGrams => widget.food.servingGrams > 0;

  @override
  void dispose() {
    servingText.dispose();
    gramText.dispose();
    servingFocus.dispose();
    gramFocus.dispose();
    super.dispose();
  }

  void _set(double value, {bool fromServingField = false, bool fromGramField = false}) {
    final next = ServingMath.normalize(value);
    setState(() => servings = next);
    if (!fromServingField) servingText.text = ServingMath.format(next);
    if (!fromGramField && hasGrams) {
      gramText.text = ServingMath.format(
          ServingMath.gramsFor(widget.food, next),
          decimals: 0);
    }
    widget.onChanged(next);
  }

  @override
  Widget build(BuildContext context) {
    final food = widget.food;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Slider(
        value: servings.clamp(ServingMath.min, ServingMath.max),
        min: ServingMath.min,
        max: ServingMath.max,
        label: '${servings.toStringAsFixed(2)} servings',
        onChanged: (v) => _set(v),
      ),
      Wrap(spacing: 10, runSpacing: 10, children: [
        SizedBox(
          width: 150,
          child: TextField(
            key: const ValueKey('servings-field'),
            controller: servingText,
            focusNode: servingFocus,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
                labelText: 'Servings', helperText: '0.1 – 10'),
            onChanged: (text) {
              final v = ServingMath.parse(text);
              if (v != null) _set(v, fromServingField: true);
            },
          ),
        ),
        if (hasGrams)
          SizedBox(
            width: 150,
            child: TextField(
              key: const ValueKey('grams-field'),
              controller: gramText,
              focusNode: gramFocus,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration:
                  const InputDecoration(labelText: 'Grams / ml', suffixText: 'g'),
              onChanged: (text) {
                final g = ServingMath.parse(text);
                final v = g == null ? null : ServingMath.servingsFromGrams(food, g);
                if (v != null) _set(v, fromGramField: true);
              },
            ),
          ),
      ]),
      const SizedBox(height: 14),
      Wrap(
          alignment: WrapAlignment.spaceBetween,
          spacing: 14,
          runSpacing: 8,
          children: [
            _nutrient('kcal', food.calories * servings, unit: ''),
            _nutrient('Protein', food.proteinG * servings),
            _nutrient('Carbs', food.carbsG * servings),
            _nutrient('Fat', food.fatG * servings),
            _nutrient('Fiber', food.fiberG * servings),
          ]),
    ]);
  }

  Widget _nutrient(String label, double value, {String unit = 'g'}) =>
      Column(mainAxisSize: MainAxisSize.min, children: [
        Text('${value.round()}$unit',
            style: const TextStyle(fontWeight: FontWeight.w800)),
        Text(label,
            style: const TextStyle(fontSize: 11, color: AppColors.muted)),
      ]);
}

/// Bottom sheet to change an existing diary entry's quantity.
Future<double?> editServingsSheet(BuildContext context, FoodLog entry) {
  var servings = entry.servings;
  return showModalBottomSheet<double>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.paper,
    shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
    builder: (context) => SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
            24, 22, 24, 24 + MediaQuery.viewInsetsOf(context).bottom),
        child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(entry.food.name,
                  style: Theme.of(context).textTheme.headlineMedium),
              const SizedBox(height: 4),
              Text(
                  '${entry.meal} • ${entry.food.servingLabel} • ${entry.food.servingGrams.round()} g',
                  style: const TextStyle(color: AppColors.muted)),
              const SizedBox(height: 10),
              ServingEditor(
                  food: entry.food,
                  initial: entry.servings,
                  onChanged: (v) => servings = v),
              const SizedBox(height: 18),
              FilledButton(
                  onPressed: () => Navigator.pop(context, servings),
                  child: const Text('Save quantity')),
            ]),
      ),
    ),
  );
}
