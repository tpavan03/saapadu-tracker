import 'package:flutter/material.dart';

import '../app_state.dart';
import '../models.dart';
import '../theme.dart';

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

  @override
  void dispose() {
    search.dispose();
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
                            },
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
              Expanded(
                child: results.isEmpty
                    ? _empty()
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(18, 0, 18, 30),
                        itemCount: results.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (context, index) => _FoodRow(
                          food: results[index],
                          onTap: () => _chooseServing(results[index]),
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
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
    final added = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.paper,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (context) => StatefulBuilder(builder: (context, setSheetState) {
        return SafeArea(
          child: Padding(
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
                    Wrap(
                        spacing: 8,
                        children: [.5, 1.0, 1.5, 2.0]
                            .map((v) => ChoiceChip(
                                  label: Text('${v}x'),
                                  selected: servings == v,
                                  onSelected: (_) =>
                                      setSheetState(() => servings = v),
                                ))
                            .toList()),
                    Slider(
                        value: servings,
                        min: .25,
                        max: 5,
                        divisions: 19,
                        label: '${servings.toStringAsFixed(2)} servings',
                        onChanged: (v) => setSheetState(() => servings = v)),
                    Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _nutrient('Protein', food.proteinG * servings),
                          _nutrient('Carbs', food.carbsG * servings),
                          _nutrient('Fat', food.fatG * servings),
                          _nutrient('Fiber', food.fiberG * servings),
                        ]),
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
                      onPressed: () async {
                        await widget.state.addFood(food, servings, meal);
                        if (context.mounted) Navigator.pop(context, true);
                      },
                      child: Text(
                          'Add ${(food.calories * servings).round()} kcal'),
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

  Widget _nutrient(String label, double value) => Column(children: [
        Text('${value.round()}g',
            style: const TextStyle(fontWeight: FontWeight.w800)),
        Text(label,
            style: const TextStyle(fontSize: 11, color: AppColors.muted)),
      ]);

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
