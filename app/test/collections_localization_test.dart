import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mymemory/account.dart';
import 'package:mymemory/economy.dart';
import 'package:mymemory/l10n/app_strings.dart';
import 'package:mymemory/ui/arena_picker.dart';
import 'package:mymemory/ui/profile_panel.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Secrets implements EconomySecrets {
  @override
  Future<String?> read(String key) async => null;
  @override
  Future<void> write(String key, String value) async {}
  @override
  Future<void> delete(String key) async {}
}

class _Guest extends EconomyController {
  _Guest(SharedPreferences prefs)
    : super(prefs: prefs, secrets: _Secrets(),
        client: MockClient((_) async => http.Response('{}', 200)));
  final data = ProfileData(id: 'english-guest', displayName: 'Animali',
    activated: false, gems: 100, ownedDecks: ProfileData.freeDecks, revision: 1);
  @override
  ProfileData get profile => data;
  @override
  int get gems => data.gems;
  @override
  Set<String> get ownedDecks => data.ownedDecks;
  @override
  Future<List<AccountProvider>> discoverAccountProviders() async => [];
  @override
  Future<List<AccountProfilePreview>> archivedAccountProfiles() async => [];
}

Widget _english(Widget child) => MaterialApp(
  locale: const Locale('en'), supportedLocales: supportedAppLocales,
  localizationsDelegates: GlobalMaterialLocalizations.delegates, home: child,
  builder: (context, child) => MediaQuery(
    data: MediaQuery.of(context).copyWith(disableAnimations: true),
    child: child!,
  ),
);

void main() {
  testWidgets('English journey translates nested arena and collection names', (tester) async {
    await tester.pumpWidget(_english(const ArenaPicker(selectedArenaId: 'wild_valley',
      unlockedArenaIds: {'wild_valley'}, crowns: 40)));
    await tester.pumpAndSettle();
    expect(find.text('Your journey'), findsOneWidget);
    expect(find.text('Next stop: Coral Bay · 60 crowns to go'), findsOneWidget);
    expect(find.text('Wild Valley'), findsOneWidget);
    expect(find.text('Animals'), findsOneWidget);
    expect(find.textContaining('Insects (200)'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('English profile preserves a nickname that is also a source key', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final guest = _Guest(await SharedPreferences.getInstance());
    await tester.pumpWidget(_english(ProfilePanel(economy: guest)));
    await tester.pumpAndSettle();
    expect(find.text('Profile'), findsOneWidget);
    expect(find.text('Player name'), findsOneWidget);
    expect(find.text('Animali'), findsWidgets);
    expect(find.text('Animals'), findsNothing);
    expect(find.text('Avatar and color'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    guest.dispose();
  });
}
