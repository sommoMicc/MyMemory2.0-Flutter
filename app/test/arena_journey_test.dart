import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mymemory/ui/arena_picker.dart';

void main() {
  setUpAll(() async {
    final loader = FontLoader('Outfit')
      ..addFont(rootBundle.load('assets/fonts/Outfit.ttf'));
    await loader.load();
    await (FontLoader(
      'MaterialIcons',
    )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
  });

  for (final size in [
    const Size(320, 568),
    const Size(568, 320),
    const Size(760, 1024),
  ]) {
    testWidgets('journey fits $size and keeps future arenas locked', (
      tester,
    ) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        const MaterialApp(
          themeMode: ThemeMode.light,
          home: ArenaPicker(
            selectedArenaId: 'wild_valley',
            unlockedArenaIds: {'wild_valley'},
            crowns: 40,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('1 di 4 arene raggiunte'), findsOneWidget);
      expect(
        find.text('Prossima tappa: Baia Corallina · 60 corone mancanti'),
        findsOneWidget,
      );
      for (final id in [
        'wild_valley',
        'coral_bay',
        'grand_city',
        'space_frontier',
      ]) {
        await tester.scrollUntilVisible(
          find.byKey(ValueKey('arena-stop-$id')),
          150,
        );
        expect(tester.takeException(), isNull);
      }
      expect(find.text('Scegli arena'), findsNothing);
      expect(
        find.text('Arena bloccata: raggiungi la soglia con le corone.'),
        findsNWidgets(3),
      );
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }

  testWidgets('reached destination returns its arena id', (tester) async {
    String? selected;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () async => selected = await ArenaPicker.show(
                context,
                selectedArenaId: 'wild_valley',
                unlockedArenaIds: {'wild_valley', 'coral_bay'},
                crowns: 120,
              ),
              child: const Text('Apri viaggio'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Apri viaggio'));
    await tester.pumpAndSettle();
    final bay = find.byKey(const ValueKey('arena-stop-coral_bay'));
    final choose = find.descendant(
      of: bay,
      matching: find.text('Scegli arena'),
    );
    await tester.scrollUntilVisible(choose, 200);
    await tester.tap(choose);
    await tester.pumpAndSettle();
    expect(selected, 'coral_bay');
  });

  testWidgets('journey supports large text and optional visual preview', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final preview = Platform.environment['ARENA_JOURNEY_PREVIEW'];
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(
          fontFamily: 'Outfit',
          colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF207B73)),
        ),
        home: MediaQuery(
          data: MediaQueryData(
            size: const Size(390, 844),
            textScaler: TextScaler.linear(preview == null ? 1.6 : 1),
          ),
          child: RepaintBoundary(
            key: const ValueKey('journey-preview'),
            child: const ArenaPicker(
              selectedArenaId: 'wild_valley',
              unlockedArenaIds: {'wild_valley'},
              crowns: 40,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    if (preview != null) {
      final boundary = tester.renderObject<RenderRepaintBoundary>(
        find.byKey(const ValueKey('journey-preview')),
      );
      await tester.runAsync(() async {
        final image = await boundary.toImage(pixelRatio: 2);
        final data = await image.toByteData(format: ui.ImageByteFormat.png);
        await File(preview).writeAsBytes(data!.buffer.asUint8List());
        image.dispose();
      });
    }
    await tester.scrollUntilVisible(find.text('Frontiera Spaziale'), 200);
    expect(tester.takeException(), isNull);
  });
}
