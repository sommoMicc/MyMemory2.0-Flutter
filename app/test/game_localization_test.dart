import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mymemory/game.dart';
import 'package:mymemory/main.dart';
import 'package:mymemory/online.dart';
import 'package:shared_preferences/shared_preferences.dart';

Widget localized(Widget child, {String language = 'en'}) => MaterialApp(
  locale: Locale(language),
  supportedLocales: const [Locale('it'), Locale('en')],
  localizationsDelegates: GlobalMaterialLocalizations.delegates,
  home: child,
);

void main() {
  setUp(() {
    TestWidgetsFlutterBinding
        .instance
        .platformDispatcher
        .accessibilityFeaturesTestValue = const FakeAccessibilityFeatures(
      disableAnimations: true,
    );
    SharedPreferences.setMockInitialValues({'sound': false, 'haptics': false});
  });

  tearDown(() {
    TestWidgetsFlutterBinding.instance.platformDispatcher
        .clearAccessibilityFeaturesTestValue();
  });

  testWidgets('Card accessibility changes language without changing the card', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();

    const card = Scaffold(
      body: Center(
        child: SizedBox(
          width: 100,
          height: 100,
          child: MemoryCard(
            index: 2,
            value: null,
            theme: 'garden',
            matched: false,
          ),
        ),
      ),
    );
    await tester.pumpWidget(localized(card));
    await tester.pumpAndSettle();
    expect(find.bySemanticsLabel('Card 3, face down'), findsOneWidget);
    await tester.pumpWidget(localized(card, language: 'it'));
    await tester.pumpAndSettle();
    expect(find.bySemanticsLabel('Carta 3, coperta'), findsOneWidget);
    semantics.dispose();
  });

  testWidgets('English solo board fits 36 cards on a small phone', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(320, 568);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final prefs = await SharedPreferences.getInstance();
    await tester.pumpWidget(
      localized(
        GameScreen(
          prefs: prefs,
          pairs: 18,
          theme: 'garden',
          mode: PlayMode.solo,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('PAIRS'), findsOneWidget);
    expect(find.text('ATTEMPTS'), findsOneWidget);
    expect(find.text('0 / 18 pairs'), findsOneWidget);
    expect(find.byType(MemoryCard), findsNWidgets(36));
    for (final element in find.byType(MemoryCard).evaluate()) {
      final rect = tester.getRect(find.byWidget(element.widget));
      expect(rect.top, greaterThanOrEqualTo(0));
      expect(rect.bottom, lessThanOrEqualTo(568));
    }
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('Server errors translate only at display and preserve source', (
    tester,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final online = _TerminalOnline(prefs)
      ..errorCode = 'UPDATE_REQUIRED'
      ..error = 'Aggiorna SommoMemory per giocare con questa collezione.';
    await tester.pumpWidget(
      localized(
        GameScreen(
          prefs: prefs,
          pairs: 6,
          theme: 'garden',
          mode: PlayMode.online,
          online: online,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Update required'), findsOneWidget);
    expect(
      find.text('Update SommoMemory to play with this collection.'),
      findsOneWidget,
    );
    expect(
      online.error,
      'Aggiorna SommoMemory per giocare con questa collezione.',
    );
    expect(online.errorCode, 'UPDATE_REQUIRED');
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    online.dispose();
  });

  testWidgets('Bluetooth translates dynamic status, errors and help', (
    tester,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    await tester.pumpWidget(
      localized(BluetoothLobby.search(prefs: prefs, name: 'Paola')),
    );
    await tester.pumpAndSettle();
    expect(find.text('Find a game'), findsOneWidget);
    final dynamic lobby = tester.state(find.byType(BluetoothLobby));
    lobby.ble.error = null;
    lobby.ble.status = 'Visibile come SommoMemory ABC123';
    lobby.update();
    await tester.pumpAndSettle();
    expect(find.text('Visible as SommoMemory ABC123'), findsOneWidget);
    expect(lobby.ble.status, 'Visibile come SommoMemory ABC123');
    lobby.ble.error = 'Bluetooth spento o permesso rimosso.';
    lobby.update();
    await tester.pumpAndSettle();
    expect(
      find.text('Bluetooth is off or permission was removed.'),
      findsOneWidget,
    );
    await tester.tap(find.byTooltip('Bluetooth help'));
    await tester.pumpAndSettle();
    expect(find.text('Bluetooth connection'), findsOneWidget);
    expect(
      find.textContaining('One player hosts and the other searches.'),
      findsOneWidget,
    );
    expect(find.text('Close'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('Room preview translates scores and preserves player names', (
    tester,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final online = _TerminalOnline(prefs)
      ..errorCode = 'ROOM_FULL'
      ..error = 'La stanza è già al completo.'
      ..preview = RoomPreview(
        code: 'ABC234',
        phase: 'finished',
        players: [
          {'id': 'one', 'name': 'Pronto', 'score': 4, 'connected': true},
          {'id': 'two', 'name': 'Paola', 'score': 2, 'connected': true},
        ],
        winnerId: 'one',
        finishReason: 'completed',
      );
    await tester.pumpWidget(
      localized(
        GameScreen(
          prefs: prefs,
          pairs: 6,
          theme: 'garden',
          mode: PlayMode.online,
          online: online,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Room full'), findsOneWidget);
    expect(find.text('Pronto'), findsOneWidget);
    expect(find.text('4 pairs'), findsOneWidget);
    expect(find.text('Final result · Pronto wins'), findsOneWidget);
    expect(find.text('Change room'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    online.dispose();
  });
}

class _TerminalOnline extends OnlineGame {
  _TerminalOnline(super.prefs);
  RoomPreview? preview;
  @override
  bool get terminalError => true;
  @override
  bool get canRetry => false;
  @override
  RoomPreview? get roomPreview => preview;
}
