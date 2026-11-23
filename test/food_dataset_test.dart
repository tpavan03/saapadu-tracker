import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:saapadu/models.dart';

const datasetPath = 'assets/data/south_indian_foods.json';
const sourcesDocPath = 'docs/nutrition_sources.md';

/// Items whose stated calories intentionally differ from 4P + 4C + 9F by
/// more than the tolerance (for example because of organic acids or a
/// published energy value). Currently none; add an id here only with a
/// comment explaining why.
const macroEnergyExceptions = <String>{};

const requiredFields = <String, Type>{
  'id': String,
  'name': String,
  'aliases': List,
  'category': String,
  'servingLabel': String,
  'servingGrams': num,
  'calories': num,
  'proteinG': num,
  'carbsG': num,
  'fatG': num,
  'fiberG': num,
  'sourceKey': String,
};

bool _hasType(Object? value, Type type) {
  if (type == String) return value is String && value.trim().isNotEmpty;
  if (type == num) return value is num;
  if (type == List) return value is List && value.every((a) => a is String);
  return false;
}

String _norm(String s) => s.toLowerCase().trim().replaceAll(RegExp(r'\s+'), ' ');

void main() {
  final raw = jsonDecode(File(datasetPath).readAsStringSync()) as List<dynamic>;
  final entries = raw.cast<Map<String, dynamic>>();
  final documentedKeys = RegExp(r'^\| `([A-Z0-9_]+)` \|', multiLine: true)
      .allMatches(File(sourcesDocPath).readAsStringSync())
      .map((m) => m.group(1)!)
      .toSet();

  test('dataset has at least 235 foods', () {
    expect(entries.length, greaterThanOrEqualTo(235));
  });

  test('every entry has required fields with correct types', () {
    for (final e in entries) {
      requiredFields.forEach((field, type) {
        expect(_hasType(e[field], type), isTrue,
            reason: '${e['id']}: field "$field" missing or not $type');
      });
    }
  });

  test('every entry parses through FoodItem.fromJson', () {
    for (final e in entries) {
      final item = FoodItem.fromJson(e);
      expect(item.id, e['id']);
      expect(item.name, e['name']);
      expect(item.calories, (e['calories'] as num).toDouble());
    }
  });

  test('ids are unique and names are unique (case-insensitive)', () {
    final ids = <String>{};
    final names = <String>{};
    for (final e in entries) {
      expect(ids.add(e['id'] as String), isTrue, reason: 'duplicate id ${e['id']}');
      expect(names.add(_norm(e['name'] as String)), isTrue,
          reason: 'duplicate name ${e['name']}');
    }
  });

  test('nutrient values are sane', () {
    for (final e in entries) {
      final id = e['id'];
      final kcal = (e['calories'] as num).toDouble();
      final p = (e['proteinG'] as num).toDouble();
      final c = (e['carbsG'] as num).toDouble();
      final f = (e['fatG'] as num).toDouble();
      final fiber = (e['fiberG'] as num).toDouble();
      expect((e['servingGrams'] as num) > 0, isTrue, reason: '$id servingGrams');
      // Black/green tea and similar may be ~0-2 kcal, so allow >= 0.
      expect(kcal >= 0, isTrue, reason: '$id calories');
      for (final v in [p, c, f, fiber]) {
        expect(v >= 0, isTrue, reason: '$id negative macro');
      }
      expect(fiber <= c, isTrue, reason: '$id fiber > carbs');
    }
  });

  test('macro energy roughly matches calories', () {
    final failures = <String>[];
    for (final e in entries) {
      final id = e['id'] as String;
      if (macroEnergyExceptions.contains(id)) continue;
      final kcal = (e['calories'] as num).toDouble();
      final energy = 4 * (e['proteinG'] as num) +
          4 * (e['carbsG'] as num) +
          9 * (e['fatG'] as num);
      final diff = (energy - kcal).abs();
      final ok = kcal < 30 ? diff <= 8 : diff <= 0.15 * kcal;
      if (!ok) failures.add('$id: calories $kcal vs macros $energy');
    }
    expect(failures, isEmpty);
  });

  test('sourceKey is documented in docs/nutrition_sources.md', () {
    expect(documentedKeys, isNotEmpty);
    for (final e in entries) {
      expect(documentedKeys, contains(e['sourceKey']), reason: '${e['id']}');
    }
  });

  test('commonly searched foods can be found by name or alias', () {
    bool found(String query) {
      final q = _norm(query);
      return entries.any((e) =>
          _norm(e['name'] as String).contains(q) ||
          (e['aliases'] as List).any((a) => _norm(a as String).contains(q)));
    }

    for (final q in [
      'pani puri',
      'rose milk',
      'jigarthanda',
      'falooda',
      'chicken 65',
      'parotta',
      'shawarma',
      'vada pav',
      'gulab jamun',
      'whey',
    ]) {
      expect(found(q), isTrue, reason: 'no food found for "$q"');
    }
  });
}
