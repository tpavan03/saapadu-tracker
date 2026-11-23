import 'package:flutter/material.dart';

import '../app_state.dart';
import '../models.dart';
import '../theme.dart';
import '../widgets/serving_editor.dart';

class FoodSearchScreen extends StatefulWidget {
  const FoodSearchScreen(
      {super.key, required this.state, required this.initialMeal});
  final AppState state;
  final String initialMeal;

  static Future<void> open(BuildContext context,
          {required AppState state, required String initialMeal}) =>
      Navigator.of(context).push(MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) =>
            FoodSearchScreen(state: state, initialMeal: initialMeal),
      ));

  @override
  State<FoodSearchScreen> createState() => _FoodSearchScreenState();
}

class _FoodSearchScreenState extends State<FoodSearchScreen> {
  final search = TextEditingController();
  String query = '';
  String category = 'All';
  final FocusNode searchFocus = FocusNode();

  @override
  void dispose() {
    search.dispose();
    searchFocus.dispose();
    super.dispose();
  }

  List<FoodItem> get results {
    final q = query.trim().toLowerCase();
    final list = widget.state.allFoods.where((food) {
      final categoryMatch = category == 'All' || food.category == category;
      final queryMatch = q.isEmpty ||
          food.name.toLowerCase().contains(q) ||
          food.aliases.any((a) => a.toLowerCase().contains(q));
      return categoryMatch && queryMatch;
    }).toList();
    if (q.isEmpty && category == 'All') {
      final frequency = <String, int>{};
      for (final log in widget.state.logs) {
        frequency[log.food.id] = (frequency[log.food.id] ?? 0) + 1;
      }
      list.sort((a, b) {
        if (a.isCustom != b.isCustom) return a.isCustom ? -1 : 1;
        final used = (frequency[b.id] ?? 0).compareTo(frequency[a.id] ?? 0);
        return used != 0 ? used : a.name.compareTo(b.name);
      });
      return list.take(80).toList();
    }
    if (q.isEmpty) return list.take(80).toList();
    list.sort((a, b) {
      final aStarts = a.name.toLowerCase().startsWith(q) ? 0 : 1;
      final bStarts = b.name.toLowerCase().startsWith(q) ? 0 : 1;
      return aStarts != bStarts
          ? aStarts.compareTo(bStarts)
          : a.name.compareTo(b.name);
    });
    return list;
  }

  @override
  Widget build(BuildContext context) {
    final categories = [
      'All',
      ...widget.state.allFoods.map((e) => e.category).toSet().toList()..sort()
    ];
    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.cream,
        title: Text('Add to ${widget.initialMeal}'),
        actions: [
          TextButton.icon(
              onPressed: _newFood,
              icon: const Icon(Icons.add),
              label: const Text('Custom food')),
          const SizedBox(width: 10),
        ],
      ),
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 820),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 14, 18, 10),
                child: TextField(
                  controller: search,
                  focusNode: searchFocus,
                  autofocus: true,
                  decoration: InputDecoration(
                    hintText: 'Search idli, dosa, rice, sambar, egg…',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: query.isEmpty
                        ? null
                        : IconButton(
                            onPressed: () {
                              search.clear();
                              setState(() => query = '');
                              searchFocus.requestFocus();
                            },
                            tooltip: 'Clear food search',
                            icon: const Icon(Icons.close),
                          ),
                  ),
                  onChanged: (value) => setState(() => query = value),
                ),
              ),
              SizedBox(
                height: 48,
                child: ListView.separated(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 18, vertical: 4),
                  scrollDirection: Axis.horizontal,
                  itemCount: categories.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 7),
                  itemBuilder: (context, index) => ChoiceChip(
                    label: Text(categories[index]),
                    selected: category == categories[index],
                    onSelected: (_) =>
                        setState(() => category = categories[index]),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
                child: Row(children: [
                  Text('${results.length} foods',
                      style: const TextStyle(
                          color: AppColors.muted, fontSize: 12)),
                  const Spacer(),
                  const Icon(Icons.verified_outlined,
                      size: 14, color: AppColors.leaf),
                  const SizedBox(width: 4),
                  const Text('Values are estimates',
                      style: TextStyle(color: AppColors.muted, fontSize: 11)),
                ]),
              ),
              Expanded(child: Builder(builder: (context) {
                final list = results;
                final quick = query.trim().isEmpty && category == 'All'
                    ? _quickSections()
                    : const <Widget>[];
                if (list.isEmpty && quick.isEmpty) return _empty();
                return ListView(
                  padding: const EdgeInsets.fromLTRB(18, 0, 18, 30),
                  children: [
                    ...quick,
                    if (quick.isNotEmpty) _sectionLabel('All foods'),
                    for (final food in list) ...[
                      _FoodRow(food: food, onTap: () => _chooseServing(food)),
                      const SizedBox(height: 8),
                    ],
                  ],
                );
              })),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sectionLabel(String text) => Padding(
        padding: const EdgeInsets.fromLTRB(4, 10, 4, 8),
        child: Text(text.toUpperCase(),
            style: const TextStyle(
                fontSize: 11,
                letterSpacing: 1.2,
                fontWeight: FontWeight.w900,
                color: AppColors.leaf)),
      );

  /// Saved combos, then recent and frequent foods, above the full list.
  List<Widget> _quickSections() {
    final state = widget.state;
    final combos = state.combos;
    final recent = state.recentFoods(limit: 6);
    final recentIds = {for (final f in recent) f.id};
    final frequent = state
        .frequentFoods(limit: 8)
        .where((f) => !recentIds.contains(f.id))
        .take(6)
        .toList();
    return [
      if (combos.isNotEmpty) ...[
        _sectionLabel('My combos'),
        for (final combo in combos) ...[
          Card(
            child: ListTile(
              leading: const Icon(Icons.bookmarks_outlined,
                  color: AppColors.forest),
              title: Text(combo.name,
                  style: const TextStyle(fontWeight: FontWeight.w800)),
              subtitle: Text(
                  '${combo.items.length} items • ${combo.calories.round()} kcal • ${combo.protein.round()} g protein',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis),
              trailing: FilledButton.tonal(
                  onPressed: () => _logCombo(combo),
                  child: const Text('Log')),
            ),
          ),
          const SizedBox(height: 8),
        ],
      ],
      if (recent.isNotEmpty) ...[
        _sectionLabel('Recent'),
        for (final food in recent) ...[
          _FoodRow(food: food, onTap: () => _chooseServing(food)),
          const SizedBox(height: 8),
        ],
      ],
      if (frequent.isNotEmpty) ...[
        _sectionLabel('Frequent'),
        for (final food in frequent) ...[
          _FoodRow(food: food, onTap: () => _chooseServing(food)),
          const SizedBox(height: 8),
        ],
      ],
    ];
  }

  Future<void> _logCombo(MealCombo combo) async {
    final state = widget.state;
    if (state.fasting.isActive &&
        DateUtils.isSameDay(state.selectedDate, DateTime.now()) &&
        combo.calories > 0) {
      final end = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
                  title: const Text('End fast at this entry time?'),
                  content: const Text(
                      'This combo contains calories. End the window now, or keep the timer and log normally.'),
                  actions: [
                    TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: const Text('Keep timer & log')),
                    FilledButton(
                        onPressed: () => Navigator.pop(context, true),
                        child: const Text('End fast & log'))
                  ]));
      if (end == null) return;
      if (end) await state.stopFast();
    }
    await state.logCombo(combo, meal: widget.initialMeal);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(
            'Logged ${combo.items.length} items from ${combo.name} to ${widget.initialMeal}.')));
    Navigator.pop(context);
  }

  Widget _empty() => Center(
          child: Padding(
        padding: const EdgeInsets.all(30),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.search_off_rounded,
              size: 50, color: AppColors.muted),
          const SizedBox(height: 14),
          const Text('No matching food',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
          const SizedBox(height: 6),
          const Text('Create it once and it will appear at the top next time.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.muted)),
          const SizedBox(height: 18),
          FilledButton.icon(
              onPressed: _newFood,
              icon: const Icon(Icons.add),
              label: const Text('Create custom food')),
        ]),
      ));

  Future<void> _chooseServing(FoodItem food) async {
    double servings = 1;
    String meal = widget.initialMeal;
    bool saving = false;
    final added = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.paper,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (context) => StatefulBuilder(builder: (context, setSheetState) {
        return SafeArea(
          child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(
                24, 22, 24, 24 + MediaQuery.viewInsetsOf(context).bottom),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 620),
              child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                              child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                Text(food.name,
                                    style: Theme.of(context)
                                        .textTheme
                                        .headlineMedium),
                                const SizedBox(height: 4),
                                Text(
                                    '${food.servingLabel} • ${food.servingGrams.round()} g',
                                    style: const TextStyle(
                                        color: AppColors.muted)),
                              ])),
                          Text('${(food.calories * servings).round()} kcal',
                              style: const TextStyle(
                                  fontSize: 20, fontWeight: FontWeight.w900)),
                        ]),
                    const SizedBox(height: 18),
                    Text('${servings.toStringAsFixed(2)} servings',
                        style: const TextStyle(
                            color: AppColors.muted, fontSize: 12)),
                    // Continuous quantity: smooth slider plus servings and
                    // grams fields kept in sync (0.1–10 servings).
                    ServingEditor(
                        food: food,
                        initial: servings,
                        onChanged: (v) => setSheetState(() => servings = v)),
                    const SizedBox(height: 18),
                    DropdownButtonFormField<String>(
                      initialValue: meal,
                      decoration: const InputDecoration(labelText: 'Meal'),
                      items: const ['Breakfast', 'Lunch', 'Dinner', 'Snacks']
                          .map(
                              (m) => DropdownMenuItem(value: m, child: Text(m)))
                          .toList(),
                      onChanged: (v) => setSheetState(() => meal = v!),
                    ),
                    const SizedBox(height: 18),
                    FilledButton(
                      onPressed: saving
                          ? null
                          : () async {
                              setSheetState(() => saving = true);
                              try {
                                if (food.calories > 0 &&
                                    widget.state.fasting.isActive &&
                                    DateUtils.isSameDay(
                                        widget.state.selectedDate,
                                        DateTime.now())) {
                                  final endFast = await showDialog<bool>(
                                      context: context,
                                      builder: (context) => AlertDialog(
                                              title: const Text(
                                                  'End fast at this entry time?'),
                                              content: const Text(
                                                  'This food contains calories. Save your fasting window now, or keep your timer running and log the food normally.'),
                                              actions: [
                                                TextButton(
                                                    onPressed: () =>
                                                        Navigator.pop(
                                                            context, false),
                                                    child: const Text(
                                                        'Keep timer & log')),
                                                FilledButton(
                                                    onPressed: () =>
                                                        Navigator.pop(
                                                            context, true),
                                                    child: const Text(
                                                        'End fast & log'))
                                              ]));
                                  if (endFast == null) {
                                    setSheetState(() => saving = false);
                                    return;
                                  }
                                  if (endFast) await widget.state.stopFast();
                                }
                                await widget.state
                                    .addFood(food, servings, meal);
                                if (context.mounted) {
                                  Navigator.pop(context, true);
                                }
                              } catch (_) {
                                if (context.mounted) {
                                  setSheetState(() => saving = false);
                                  ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                          content: Text(
                                              'Food could not be saved. Please try again.')));
                                }
                              }
                            },
                      child: Text(saving
                          ? 'Saving food…'
                          : 'Add ${(food.calories * servings).round()} kcal'),
                    ),
                    const SizedBox(height: 8),
                    Text(
                        'Source: ${food.sourceKey} • Homemade recipes vary; adjust the serving to match yours.',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                            fontSize: 10, color: AppColors.muted)),
                  ]),
            ),
          ),
        );
      }),
    );
    if (added == true && mounted) Navigator.pop(context);
  }

  Future<void> _newFood() async {
    final name = TextEditingController(text: query);
    final serving = TextEditingController(text: '1 serving');
    final grams = TextEditingController(text: '100');
    final calories = TextEditingController();
    final protein = TextEditingController(text: '0');
    final carbs = TextEditingController(text: '0');
    final fat = TextEditingController(text: '0');
    final fiber = TextEditingController(text: '0');
    final created = await showDialog<FoodItem>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Create custom food'),
        content: SizedBox(
            width: 520,
            child: SingleChildScrollView(
                child: Column(children: [
              TextField(
                  controller: name,
                  autofocus: true,
                  decoration: const InputDecoration(labelText: 'Food name')),
              const SizedBox(height: 10),
              Row(children: [
                Expanded(
                    child: TextField(
                        controller: serving,
                        decoration:
                            const InputDecoration(labelText: 'Serving label'))),
                const SizedBox(width: 10),
                Expanded(
                    child: TextField(
                        controller: grams,
                        keyboardType: TextInputType.number,
                        decoration:
                            const InputDecoration(labelText: 'Serving grams'))),
              ]),
              const SizedBox(height: 10),
              TextField(
                  controller: calories,
                  keyboardType: TextInputType.number,
                  decoration:
                      const InputDecoration(labelText: 'Calories per serving')),
              const SizedBox(height: 10),
              Row(children: [
                Expanded(
                    child: TextField(
                        controller: protein,
                        keyboardType: TextInputType.number,
                        decoration:
                            const InputDecoration(labelText: 'Protein g'))),
                const SizedBox(width: 8),
                Expanded(
                    child: TextField(
                        controller: carbs,
                        keyboardType: TextInputType.number,
                        decoration:
                            const InputDecoration(labelText: 'Carbs g'))),
              ]),
              const SizedBox(height: 10),
              Row(children: [
                Expanded(
                    child: TextField(
                        controller: fat,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: 'Fat g'))),
                const SizedBox(width: 8),
                Expanded(
                    child: TextField(
                        controller: fiber,
                        keyboardType: TextInputType.number,
                        decoration:
                            const InputDecoration(labelText: 'Fiber g'))),
              ]),
            ]))),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () {
                if (name.text.trim().isEmpty ||
                    double.tryParse(calories.text) == null) {
                  return;
                }
                Navigator.pop(
                    context,
                    FoodItem(
                      id: 'custom-${DateTime.now().microsecondsSinceEpoch}',
                      name: name.text.trim(),
                      aliases: const [],
                      category: 'My foods',
                      servingLabel: serving.text.trim().isEmpty
                          ? '1 serving'
                          : serving.text.trim(),
                      servingGrams: double.tryParse(grams.text) ?? 0,
                      calories: double.parse(calories.text),
                      proteinG: double.tryParse(protein.text) ?? 0,
                      carbsG: double.tryParse(carbs.text) ?? 0,
                      fatG: double.tryParse(fat.text) ?? 0,
                      fiberG: double.tryParse(fiber.text) ?? 0,
                      sourceKey: 'user',
                      isCustom: true,
                    ));
              },
              child: const Text('Save food')),
        ],
      ),
    );
    if (created != null) {
      await widget.state.addCustomFood(created);
      setState(() {
        query = '';
        search.clear();
        category = 'All';
      });
    }
  }
}

class _FoodRow extends StatelessWidget {
  const _FoodRow({required this.food, required this.onTap});
  final FoodItem food;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Card(
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(22),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(children: [
              Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                      color:
                          _categoryColor(food.category).withValues(alpha: .15),
                      borderRadius: BorderRadius.circular(14)),
                  child: Icon(_categoryIcon(food.category),
                      color: _categoryColor(food.category), size: 21)),
              const SizedBox(width: 13),
              Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    Row(children: [
                      Flexible(
                          child: Text(food.name,
                              style: const TextStyle(
                                  fontWeight: FontWeight.w800))),
                      if (food.isCustom) ...[
                        const SizedBox(width: 6),
                        const Icon(Icons.person_outline,
                            size: 14, color: AppColors.leaf)
                      ],
                    ]),
                    const SizedBox(height: 3),
                    Text(
                        '${food.servingLabel} • P ${food.proteinG.round()}g  C ${food.carbsG.round()}g  F ${food.fatG.round()}g',
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 11, color: AppColors.muted)),
                  ])),
              const SizedBox(width: 10),
              Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                Text('${food.calories.round()}',
                    style: const TextStyle(
                        fontSize: 17, fontWeight: FontWeight.w900)),
                const Text('kcal',
                    style: TextStyle(fontSize: 10, color: AppColors.muted)),
              ]),
              const SizedBox(width: 5),
              const Icon(Icons.chevron_right, color: AppColors.muted),
            ]),
          ),
        ),
      );

  Color _categoryColor(String category) {
    if (category.toLowerCase().contains('breakfast')) {
      return AppColors.terracotta;
    }
    if (category.toLowerCase().contains('beverage')) return AppColors.sky;
    if (category.toLowerCase().contains('fruit') ||
        category.toLowerCase().contains('vegetable')) {
      return AppColors.leaf;
    }
    return const Color(0xFF9A7B3F);
  }

  IconData _categoryIcon(String category) {
    if (category.toLowerCase().contains('beverage')) {
      return Icons.local_cafe_outlined;
    }
    if (category.toLowerCase().contains('fruit')) return Icons.apple_outlined;
    if (category.toLowerCase().contains('snack')) return Icons.cookie_outlined;
    return Icons.rice_bowl_outlined;
  }
}
