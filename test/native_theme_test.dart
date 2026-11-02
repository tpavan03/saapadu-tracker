import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:saapadu/app_state.dart';
import 'package:saapadu/cloud_sync_service.dart';
import 'package:saapadu/models.dart';
import 'package:saapadu/screens/home_shell.dart';
import 'package:saapadu/theme.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    for (final font in [
      ('DM Sans', 'assets/fonts/DMSans.ttf'),
      ('Sora', 'assets/fonts/Sora.ttf'),
      ('MaterialIcons', 'fonts/MaterialIcons-Regular.otf'),
    ]) {
      final loader = FontLoader(font.$1)..addFont(rootBundle.load(font.$2));
      await loader.load();
    }
  });

  for (final (width, scale) in [(390.0, 1.0), (320.0, 1.3), (390.0, 2.0)]) {
    testWidgets(
        'native night workspace remains usable at $width and text $scale',
        (tester) async {
      tester.view.physicalSize = Size(width, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      SharedPreferences.setMockInitialValues({});
      final cloud = CloudSyncService();
      final state = AppState(cloud: cloud);
      await tester.runAsync(() async {
        await cloud.initialize();
        await state.initialize();
        await state.saveProfile(const Profile(
            name: 'Pavan',
            sex: 'Male',
            birthYear: 1995,
            heightCm: 175,
            currentWeightKg: 75,
            goalWeightKg: 70,
            activityLevel: 'Sedentary',
            weeklyGoalKg: .5));
      });
      final capture = GlobalKey();
      await tester.pumpWidget(MaterialApp(
        theme: buildTheme(),
        builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: TextScaler.linear(scale)),
            child: child!),
        home: RepaintBoundary(key: capture, child: HomeShell(state: state)),
      ));
      await tester.pumpAndSettle();
      expect(Theme.of(tester.element(find.byType(HomeShell))).brightness,
          Brightness.dark);
      expect(tester.takeException(), isNull);
      if (width == 390 && scale == 1) {
        final boundary = capture.currentContext!.findRenderObject()!
            as RenderRepaintBoundary;
        await tester.runAsync(() async {
          final image = await boundary.toImage(pixelRatio: 2);
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          await Directory('/tmp/saapadu-native-review').create(recursive: true);
          await File('/tmp/saapadu-native-review/today-night.png')
              .writeAsBytes(bytes!.buffer.asUint8List());
          image.dispose();
        });
      }
      for (final destination in [
        'Diary',
        'Activity',
        'Fasting',
        'Progress',
        'More',
        'Today'
      ]) {
        await tester.tap(find.text(destination).last);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull,
            reason: '$destination at $width and text $scale');
      }
      await tester.pumpWidget(const SizedBox());
      state.dispose();
      cloud.dispose();
    });
  }
}
