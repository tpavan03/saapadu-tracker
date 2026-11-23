import 'package:flutter/material.dart';

import '../app_state.dart';
import '../insights.dart';
import '../models.dart';
import '../theme.dart';

const _meals = ['Breakfast', 'Lunch', 'Dinner', 'Snacks'];

/// Saved combos ("my usual breakfast"): list, edit, delete.
class CombosScreen extends StatelessWidget {
  const CombosScreen({super.key, required this.state});
  final AppState state;

  static Future<void> open(BuildContext context, AppState state) =>
      Navigator.of(context).push(MaterialPageRoute<void>(
          builder: (_) => CombosScreen(state: state)));

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: state,
        builder: (context, _) => Scaffold(
          appBar: AppBar(title: const Text('My combos')),
          body: SafeArea(
            child: Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 720),
                child: ListView(
                  padding: const EdgeInsets.all(18),
                  children: [
                    const Text(
                        'Save a meal you repeat from the diary (⋮ → Save as combo). Log it in one tap from food search.',
                        style: TextStyle(color: AppColors.muted)),
                    const SizedBox(height: 16),
                    if (state.combos.isEmpty)
                      const Card(
                          child: Padding(
                              padding: EdgeInsets.all(20),
                              child: Text('No combos yet.'))),
                    for (final combo in state.combos)
                      Card(
                        child: ListTile(
                          title: Text(combo.name,
                              style:
                                  const TextStyle(fontWeight: FontWeight.w800)),
                          subtitle: Text(
                              '${combo.meal} • ${combo.items.map((i) => i.food.name).join(', ')}\n${combo.calories.round()} kcal • ${combo.protein.round()} g protein'),
                          isThreeLine: true,
                          onTap: () => ComboEditor.edit(context, state, combo),
                          trailing: IconButton(
                              tooltip: 'Delete combo',
                              onPressed: () async {
                                final ok = await showDialog<bool>(
                                    context: context,
                                    builder: (context) => AlertDialog(
                                            title: Text('Delete ${combo.name}?'),
                                            content: const Text(
                                                'Your diary entries stay as they are.'),
                                            actions: [
                                              TextButton(
                                                  onPressed: () =>
                                                      Navigator.pop(context, false),
                                                  child: const Text('Keep')),
                                              FilledButton(
                                                  onPressed: () =>
                                                      Navigator.pop(context, true),
                                                  child: const Text('Delete'))
                                            ]));
                                if (ok == true) await state.deleteCombo(combo.id);
                              },
                              icon: const Icon(Icons.delete_outline)),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
}

class ComboEditor extends StatefulWidget {
  const ComboEditor({super.key, required this.state, required this.combo});
  final AppState state;
  final MealCombo combo;

  static Future<void> create(BuildContext context, AppState state,
          {required String meal, required List<ComboItem> items}) =>
      Navigator.of(context).push(MaterialPageRoute<void>(
          fullscreenDialog: true,
          builder: (_) => ComboEditor(
              state: state,
              combo: MealCombo(
                  id: 'combo-${DateTime.now().microsecondsSinceEpoch}',
                  name: 'My usual ${meal.toLowerCase()}',
                  meal: meal,
                  items: items))));

  static Future<void> edit(
          BuildContext context, AppState state, MealCombo combo) =>
      Navigator.of(context).push(MaterialPageRoute<void>(
          fullscreenDialog: true,
          builder: (_) => ComboEditor(state: state, combo: combo)));

  @override
  State<ComboEditor> createState() => _ComboEditorState();
}

class _ComboEditorState extends State<ComboEditor> {
  late final name = TextEditingController(text: widget.combo.name);
  late String meal = widget.combo.meal;
  late final List<ComboItem> items = [...widget.combo.items];

  @override
  void dispose() {
    name.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (name.text.trim().isEmpty || items.isEmpty) return;
    await widget.state.saveCombo(widget.combo
        .copyWith(name: name.text.trim(), meal: meal, items: items));
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Combo'), actions: [
          TextButton(onPressed: _save, child: const Text('Save combo')),
          const SizedBox(width: 8),
        ]),
        body: SafeArea(
          child: Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 620),
              child: ListView(padding: const EdgeInsets.all(20), children: [
                TextField(
                    controller: name,
                    decoration: const InputDecoration(labelText: 'Combo name')),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: _meals.contains(meal) ? meal : 'Breakfast',
                  decoration: const InputDecoration(labelText: 'Usual meal'),
                  items: _meals
                      .map((m) => DropdownMenuItem(value: m, child: Text(m)))
                      .toList(),
                  onChanged: (v) => setState(() => meal = v!),
                ),
                const SizedBox(height: 16),
                for (var i = 0; i < items.length; i++)
                  Card(
                    key: ValueKey('${items[i].food.id}-$i-${items.length}'),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 4, 8),
                      child: Row(children: [
                        Expanded(
                            child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                              Text(items[i].food.name,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w700)),
                              Text(
                                  '${(items[i].food.calories * items[i].servings).round()} kcal',
                                  style: const TextStyle(
                                      color: AppColors.muted, fontSize: 12)),
                            ])),
                        SizedBox(
                          width: 84,
                          child: TextFormField(
                            initialValue: ServingMath.format(items[i].servings),
                            keyboardType: const TextInputType.numberWithOptions(
                                decimal: true),
                            decoration:
                                const InputDecoration(labelText: 'Servings'),
                            onChanged: (text) {
                              final v = ServingMath.parse(text);
                              if (v != null) {
                                setState(() => items[i] = ComboItem(
                                    food: items[i].food,
                                    servings: ServingMath.normalize(v)));
                              }
                            },
                          ),
                        ),
                        IconButton(
                            tooltip: 'Remove from combo',
                            onPressed: items.length <= 1
                                ? null
                                : () => setState(() => items.removeAt(i)),
                            icon: const Icon(Icons.close)),
                      ]),
                    ),
                  ),
                const SizedBox(height: 16),
                FilledButton(onPressed: _save, child: const Text('Save combo')),
              ]),
            ),
          ),
        ),
      );
}
