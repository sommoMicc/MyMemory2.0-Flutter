import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mymemory/main.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    final loader = FontLoader('Outfit')
      ..addFont(rootBundle.load('assets/fonts/Outfit.ttf'));
    await loader.load();
  });
  for (final width in [320.0, 390.0, 1024.0]) {
    testWidgets('Home and local board fit width $width', (tester) async {
      tester.view.physicalSize = Size(width, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      await tester.pumpWidget(MyMemory(prefs: prefs));
      await tester.pumpAndSettle();
      expect(find.text('Un momento per\nritrovarsi.'), findsOneWidget);
      expect(tester.takeException(), isNull);
      final play = find.widgetWithText(FilledButton, 'Giochiamo');
      await tester.ensureVisible(play);
      await tester.tap(play);
      await tester.pumpAndSettle();
      expect(find.byType(MemoryCard), findsNWidgets(16));
      expect(tester.takeException(), isNull);
      await tester.tap(find.byType(MemoryCard).first);
      await tester.pump();
      expect(find.bySemanticsLabel('Carta 1, coperta'), findsNothing);
      await tester.tap(find.byTooltip('Torna alla home'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Abbandona'));
      await tester.pumpAndSettle();
      expect(find.byType(Home), findsOneWidget);
      expect(find.byType(GameScreen), findsNothing);
      await tester.pumpWidget(const SizedBox());
    });
  }
}
