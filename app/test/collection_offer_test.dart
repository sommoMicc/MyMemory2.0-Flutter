import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mymemory/economy.dart';
import 'package:mymemory/ui/collection_shop.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _OfferEconomy extends EconomyController {
  _OfferEconomy(
    SharedPreferences prefs, {
    required int balance,
    this.isOffline = false,
  }) : data = ProfileData(
         id: 'offer-player',
         displayName: 'Giocatore',
         activated: false,
         gems: balance,
         ownedDecks: ProfileData.freeDecks,
         revision: 1,
       ),
       super(prefs: prefs);
  final ProfileData data;
  final bool isOffline;
  @override
  ProfileData get profile => data;
  @override
  int get gems => data.gems;
  @override
  bool get offline => isOffline;
  @override
  bool ownsDeck(String id) => data.ownedDecks.contains(id);
  @override
  Set<String> get ownedDecks => data.ownedDecks;
}

void main() {
  setUpAll(() async {
    final font = FontLoader('Outfit')
      ..addFont(rootBundle.load('assets/fonts/Outfit.ttf'));
    await font.load();
  });
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    TestWidgetsFlutterBinding
        .instance
        .platformDispatcher
        .accessibilityFeaturesTestValue = const FakeAccessibilityFeatures(
      disableAnimations: true,
    );
  });
  tearDown(
    () => TestWidgetsFlutterBinding.instance.platformDispatcher
        .clearAccessibilityFeaturesTestValue(),
  );

  for (final example in [
    (500, false, null, true),
    (100, false, 'Gemme insufficienti', false),
    (500, true, null, true),
  ]) {
    testWidgets(
      'reached arena offer separates ownership from wallet: $example',
      (tester) async {
        tester.view.physicalSize = const Size(320, 568);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final prefs = await SharedPreferences.getInstance();
        final economy = _OfferEconomy(
          prefs,
          balance: example.$1,
          isOffline: example.$2,
        );
        await tester.pumpWidget(
          MaterialApp(
            locale: const Locale('it'),
            supportedLocales: const [Locale('it'), Locale('en')],
            localizationsDelegates: GlobalMaterialLocalizations.delegates,
            theme: ThemeData(fontFamily: 'Outfit'),
            home: CollectionShop(selected: 'garden', economy: economy),
          ),
        );
        await tester.pumpAndSettle();
        final offer = find.byKey(const ValueKey('deck-offer-insects'));
        await tester.scrollUntilVisible(
          offer,
          140,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.pumpAndSettle();
        expect(
          find.descendant(
            of: offer,
            matching: find.textContaining('Arena bloccata'),
          ),
          findsNothing,
        );
        if (example.$3 != null) {
          final explanation = find.descendant(
            of: offer,
            matching: find.textContaining(example.$3!),
          );
          expect(explanation, findsOneWidget);
          expect(
            tester.renderObject<RenderParagraph>(explanation).didExceedMaxLines,
            isFalse,
            reason: 'La ragione del blocco deve essere leggibile per intero.',
          );
        }
        final button = find.descendant(
          of: offer,
          matching: find.byWidgetPredicate((w) => w is FilledButton),
        );
        expect(
          tester.widget<FilledButton>(button).onPressed != null,
          example.$4,
        );
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
        economy.dispose();
      },
    );
  }
}
