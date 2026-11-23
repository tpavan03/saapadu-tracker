import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:saapadu/models.dart';
import 'package:saapadu/theme.dart';
import 'package:saapadu/widgets/serving_editor.dart';

void main() {
  const idli = FoodItem(
      id: 'idli',
      name: 'Idli',
      aliases: [],
      category: 'Breakfast',
      servingLabel: '1 idli',
      servingGrams: 50,
      calories: 58,
      proteinG: 2,
      carbsG: 12,
      fatG: .2,
      fiberG: .6,
      sourceKey: 'IFCT_2017');

  testWidgets('servings and grams fields stay in sync with live kcal',
      (tester) async {
    double? last;
    await tester.pumpWidget(MaterialApp(
        theme: buildTheme(),
        home: Scaffold(
            body: ServingEditor(
                food: idli, initial: 1, onChanged: (v) => last = v))));
    await tester.enterText(find.byKey(const ValueKey('grams-field')), '125');
    await tester.pump();
    expect(last, 2.5);
    expect(
        tester
            .widget<TextField>(find.byKey(const ValueKey('servings-field')))
            .controller!
            .text,
        '2.5');
    expect(find.text('145'), findsOneWidget); // 58 × 2.5 kcal
    await tester.enterText(find.byKey(const ValueKey('servings-field')), '0.3');
    await tester.pump();
    expect(last, .3);
    expect(
        tester
            .widget<TextField>(find.byKey(const ValueKey('grams-field')))
            .controller!
            .text,
        '15');
    final slider = tester.widget<Slider>(find.byType(Slider));
    expect(slider.divisions, isNull, reason: 'continuous, no fixed steps');
    expect(slider.min, .1);
    expect(slider.max, 10);
  });
}
