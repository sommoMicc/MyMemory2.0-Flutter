import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mymemory/account.dart';
import 'package:mymemory/economy.dart';
import 'package:mymemory/ui/profile_appearance.dart';
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

ProfileData _profile({
  String id = 'guest-one',
  String name = 'Giocatore',
  bool saved = false,
  Set<String> linked = const {},
  String avatar = 'fox',
  String accent = 'forest',
}) => ProfileData(
  id: id,
  displayName: name,
  activated: saved,
  gems: 320,
  ownedDecks: const {'garden', 'cosmos', 'ocean', 'paola', 'food'},
  revision: 2,
  avatarId: avatar,
  accentId: accent,
  linkedProviders: linked,
);

class _Economy extends EconomyController {
  _Economy(SharedPreferences prefs)
    : super(
        prefs: prefs,
        secrets: _Secrets(),
        client: MockClient((_) async => http.Response('{}', 200)),
      );

  ProfileData? current = _profile();
  bool isOffline = false;
  List<AccountProvider> configuredProviders = [];
  int appearanceChanges = 0, codeCreations = 0, confirmations = 0;
  int deletionAttempts = 0, verifications = 0;
  bool requireVerification = false;
  final revoked = <String>[];
  AccountSignInPreview? preview;

  @override
  ProfileData? get profile => current;
  @override
  int get gems => current?.gems ?? 0;
  @override
  Set<String> get ownedDecks => current?.ownedDecks ?? ProfileData.freeDecks;
  @override
  bool get isSaved => current?.recoveryEnabled == true;
  @override
  bool get offline => isOffline;
  @override
  Future<List<AccountProvider>> discoverAccountProviders() async =>
      configuredProviders;
  @override
  Future<List<AccountProfilePreview>> archivedAccountProfiles() async => [];
  @override
  Future<List<AccountSession>> listAccountSessions() async => [
    AccountSession(
      id: 'this',
      name: 'Telefono',
      current: true,
      createdAt: DateTime.utc(2026),
      lastUsedAt: DateTime.utc(2026),
    ),
    AccountSession(
      id: 'other',
      name: 'Tablet',
      current: false,
      createdAt: DateTime.utc(2026),
      lastUsedAt: DateTime.utc(2026),
    ),
  ];
  @override
  Future<void> revokeAccountSession(String id) async {
    revoked.add(id);
  }

  @override
  Future<void> setAppearance({String? avatarId, String? accentId}) async {
    appearanceChanges++;
    current = _profile(
      avatar: avatarId ?? current!.avatarId,
      accent: accentId ?? current!.accentId,
    );
    notifyListeners();
  }

  @override
  Future<String> activateRecovery({String? displayName}) async {
    codeCreations++;
    current = _profile(saved: true);
    notifyListeners();
    return 'SMM-ABCD-EFGH-IJKL';
  }

  @override
  Future<AccountSignInPreview?> beginAccountSignIn(
    AccountProvider provider, {
    String operation = 'login',
  }) async => preview;
  @override
  Future<void> confirmAccountSignIn(AccountSignInPreview value) async {
    confirmations++;
    current = _profile(
      id: value.profile.id,
      name: value.profile.displayName,
      linked: {'google'},
    );
    notifyListeners();
  }

  @override
  Future<void> reauthenticateWithRecovery(String code) async {
    verifications++;
  }

  @override
  Future<void> deleteProfile() async {
    deletionAttempts++;
    if (requireVerification && verifications == 0) {
      throw const EconomyException(
        'Conferma il tuo accesso.',
        code: 'REAUTH_REQUIRED',
      );
    }
    current = null;
    notifyListeners();
  }
}

Future<_Economy> _economy() async {
  SharedPreferences.setMockInitialValues({});
  return _Economy(await SharedPreferences.getInstance());
}

Future<void> _mount(
  WidgetTester tester,
  _Economy economy, {
  int section = 0,
  Size size = const Size(390, 844),
  double scale = 1,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(economy.dispose);
  await tester.pumpWidget(
    MaterialApp(
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
          disableAnimations: true,
          textScaler: TextScaler.linear(scale),
        ),
        child: child!,
      ),
      home: ProfilePanel(economy: economy, initialSection: section),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _tap(WidgetTester tester, String text) async {
  final textFinder = find.text(text);
  if (textFinder.evaluate().isEmpty) {
    await tester.scrollUntilVisible(
      textFinder,
      140,
      scrollable: find.byType(Scrollable).last,
    );
  }
  final finder = textFinder.last;
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'Guest appearance is explicit, survives short viewport and large text',
    (tester) async {
      final economy = await _economy();
      await _mount(tester, economy, size: const Size(320, 420), scale: 1.5);
      await _tap(tester, 'Avatar e colore');
      await _tap(tester, '🚀 Razzo');
      await _tap(tester, 'Oceano');
      expect(economy.appearanceChanges, 0);
      await _tap(tester, 'Salva');
      expect(economy.appearanceChanges, 1);
      expect(economy.profile!.avatarId, 'rocket');
      expect(economy.profile!.accentId, 'ocean');
      await tester.drag(find.byType(Scrollable).first, const Offset(0, 900));
      await tester.pumpAndSettle();
      expect(find.byType(ProfileAvatar), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('Canceling customization never saves the selection', (
    tester,
  ) async {
    final economy = await _economy();
    await _mount(tester, economy);
    await _tap(tester, 'Avatar e colore');
    await _tap(tester, '🐼 Panda');
    await _tap(tester, 'Annulla');
    expect(economy.appearanceChanges, 0);
    expect(economy.profile!.avatarId, 'fox');
  });

  testWidgets(
    'Configured provider buttons fit large text and cancellation keeps the guest',
    (tester) async {
      final economy = await _economy();
      economy.configuredProviders = const [
        AccountProvider(id: 'apple'),
        AccountProvider(id: 'google'),
      ];
      await _mount(
        tester,
        economy,
        section: 1,
        size: const Size(320, 568),
        scale: 1.7,
      );
      await _tap(tester, 'Continua con Apple');
      await _tap(tester, 'Continua con Google');
      expect(economy.profile!.id, 'guest-one');
      expect(economy.confirmations, 0);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Unconfigured providers stay hidden and recovery remains available',
    (tester) async {
      final economy = await _economy();
      await _mount(tester, economy, section: 1);
      expect(find.text('Continua con Apple'), findsNothing);
      expect(find.text('Continua con Google'), findsNothing);
      await _tap(tester, 'Crea codice di recupero');
      expect(economy.codeCreations, 1);
      expect(find.text('SMM-ABCD-EFGH-IJKL'), findsOneWidget);
      await _tap(tester, 'Fatto');
      expect(find.text('Mostra codice'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Switching accounts asks to preserve the guest and confirms preview',
    (tester) async {
      final economy = await _economy();
      economy.configuredProviders = [const AccountProvider(id: 'google')];
      economy.preview = AccountSignInPreview(
        confirmationId: 'confirmation',
        initialProfileId: 'guest-one',
        action: 'switch',
        requestId: 'request',
        expiresAt: DateTime.now().add(const Duration(minutes: 5)),
        profile: AccountProfilePreview(
          id: 'saved-two',
          displayName: 'Luna',
          gems: 700,
          ownedDecks: {'garden', 'cosmos', 'ocean', 'paola'},
        ),
      );
      await _mount(tester, economy, section: 1);
      await _tap(tester, 'Continua con Google');
      expect(find.text('Conserva il profilo attuale'), findsOneWidget);
      await _tap(tester, 'Continua senza codice');
      expect(find.text('Usa questo profilo?'), findsOneWidget);
      expect(find.textContaining('700 gemme'), findsOneWidget);
      await _tap(tester, 'Annulla');
      expect(economy.confirmations, 0);
      expect(economy.profile!.id, 'guest-one');
      await _tap(tester, 'Continua con Google');
      await _tap(tester, 'Continua senza codice');
      await _tap(tester, 'Usa profilo');
      expect(economy.confirmations, 1);
      expect(economy.profile!.id, 'saved-two');
      expect(find.text('Account collegato'), findsOneWidget);
    },
  );

  testWidgets(
    'Deletion asks for fresh recovery verification and retries once',
    (tester) async {
      final economy = await _economy();
      economy.current = _profile(saved: true, linked: {'google'});
      economy.requireVerification = true;
      await _mount(tester, economy, section: 2, size: const Size(568, 320));
      await _tap(tester, 'Elimina profilo');
      await _tap(tester, 'Elimina');
      expect(find.text('Verifica il tuo accesso'), findsOneWidget);
      await _tap(tester, 'Usa il codice di recupero');
      await tester.enterText(find.byType(TextField), 'SMM-secret');
      await _tap(tester, 'Verifica');
      expect(economy.verifications, 1);
      expect(economy.deletionAttempts, 2);
      expect(economy.profile, isNull);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('Revoking a different device requires confirmation', (
    tester,
  ) async {
    final economy = await _economy();
    await _mount(tester, economy, section: 2);
    await _tap(tester, 'Tablet');
    await _tap(tester, 'Annulla');
    expect(economy.revoked, isEmpty);
    await _tap(tester, 'Tablet');
    await _tap(tester, 'Scollega');
    expect(economy.revoked, ['other']);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Offline profile keeps identity visible and disables mutations', (
    tester,
  ) async {
    final economy = await _economy();
    economy.isOffline = true;
    await _mount(tester, economy);
    final appearance = tester.widget<ListTile>(
      find.ancestor(
        of: find.text('Avatar e colore'),
        matching: find.byType(ListTile),
      ),
    );
    expect(appearance.onTap, isNull);
    expect(find.text('Profilo ospite'), findsOneWidget);
    await tester.ensureVisible(find.text('Offline'));
    expect(find.text('Offline'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
