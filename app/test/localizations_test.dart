import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mymemory/l10n/app_strings.dart';
import 'package:mymemory/main.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    await (FontLoader(
      'Outfit',
    )..addFont(rootBundle.load('assets/fonts/Outfit.ttf'))).load();
  });
  setUp(() {
    TestWidgetsFlutterBinding
        .instance
        .platformDispatcher
        .accessibilityFeaturesTestValue = const FakeAccessibilityFeatures(
      disableAnimations: true,
    );
  });
  tearDown(() {
    TestWidgetsFlutterBinding.instance.platformDispatcher
        .clearAccessibilityFeaturesTestValue();
  });

  for (final example in [
    (const Locale('en', 'US'), 'auto', 'Solo', 'Game modes'),
    (const Locale('it', 'IT'), 'auto', 'Singolo', 'Modalità di gioco'),
    (const Locale('fr', 'FR'), 'auto', 'Solo', 'Game modes'),
    (const Locale('en', 'US'), 'it', 'Singolo', 'Modalità di gioco'),
    (const Locale('it', 'IT'), 'en', 'Solo', 'Game modes'),
  ]) {
    testWidgets('device ${example.$1} and preference ${example.$2}', (
      tester,
    ) async {
      tester.platformDispatcher.localeTestValue = example.$1;
      tester.platformDispatcher.localesTestValue = [example.$1];
      SharedPreferences.setMockInitialValues({'ui.language': example.$2});
      final prefs = await SharedPreferences.getInstance();
      await tester.pumpWidget(MyMemory(prefs: prefs));
      await tester.pumpAndSettle();
      expect(find.text(example.$3), findsOneWidget);
      expect(find.text(example.$4), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });
  }

  testWidgets(
    'language selector changes the active dialog and persists after reopening',
    (tester) async {
      tester.platformDispatcher.localeTestValue = const Locale('en', 'US');
      tester.platformDispatcher.localesTestValue = const [Locale('en', 'US')];
      SharedPreferences.setMockInitialValues({'ui.language': 'it'});
      final prefs = await SharedPreferences.getInstance();
      await tester.pumpWidget(MyMemory(prefs: prefs));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Come si gioca e impostazioni'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('app-language')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Inglese').last);
      await tester.pumpAndSettle();
      expect(find.text('Settings'), findsOneWidget);
      expect(find.text('Language'), findsOneWidget);
      expect(prefs.getString('ui.language'), 'en');
      await tester.tap(find.byTooltip('Close'));
      await tester.pumpAndSettle();
      expect(find.text('Game modes'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      tester.platformDispatcher.localeTestValue = const Locale('it', 'IT');
      tester.platformDispatcher.localesTestValue = const [Locale('it', 'IT')];
      await tester.pumpWidget(MyMemory(prefs: prefs));
      await tester.pumpAndSettle();
      expect(find.text('Game modes'), findsOneWidget);
      expect(find.text('Two players'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    },
  );

  for (final viewport in [const Size(320, 568), const Size(844, 390)]) {
    testWidgets('English native setup and board fit $viewport', (tester) async {
      tester.platformDispatcher.localeTestValue = const Locale('en', 'US');
      tester.platformDispatcher.localesTestValue = const [Locale('en', 'US')];
      tester.view.physicalSize = viewport;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      try {
        SharedPreferences.setMockInitialValues({
          'sound': false,
          'haptics': false,
          'ui.language': 'auto',
        });
        final prefs = await SharedPreferences.getInstance();
        await tester.pumpWidget(MyMemory(prefs: prefs));
        await tester.pumpAndSettle();
        expect(find.text('Two players'), findsOneWidget);
        expect(find.text('No Internet needed'), findsOneWidget);
        await tester.tap(find.text('Solo'));
        await tester.pumpAndSettle();
        expect(find.text('Start game').hitTestable(), findsOneWidget);
        await tester.tap(find.text('Pairs'));
        await tester.pumpAndSettle();
        expect(find.text('Number of pairs'), findsOneWidget);
        await tester.tap(find.text('12 pairs'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Start game'));
        await tester.pumpAndSettle();
        expect(find.byType(MemoryCard), findsNWidgets(24));
        expect(find.text('PAIRS'), findsOneWidget);
        for (var i = 0; i < 24; i++) {
          expect(find.byKey(ValueKey('card-$i')).hitTestable(), findsOneWidget);
        }
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    });
  }

  test(
    'placeholder values are preserved and rendered legacy templates translate',
    () {
      expect(
        translateForLocale(const Locale('en'), '{count} coppia', {'count': 1}),
        '1 pair',
      );
      expect(
        translateForLocale(const Locale('en'), '{count} coppie', {'count': 12}),
        '12 pairs',
      );
      expect(
        translateForLocale(const Locale('it'), '{count} coppia', {'count': 1}),
        '1 coppia',
      );
      expect(
        translateForLocale(
          const Locale('en'),
          'Stanza ABC123. La partita in corso verrà abbandonata.',
        ),
        'Room ABC123. You will leave the current game.',
      );
      expect(
        translateForLocale(
          const Locale('en'),
          'Stanza {code}. La partita in corso verrà abbandonata.',
          {'code': '{count}', 'count': 7},
        ),
        'Room {count}. You will leave the current game.',
      );
      expect(
        translateForLocale(const Locale('en'), 'nickname Mario 🦊'),
        'nickname Mario 🦊',
      );
    },
  );
}
