import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mymemory/economy.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'economy_test.dart' show MemorySecrets, profile, response, token;

List<int> solution(GameTicket ticket) => [
  for (var card = 0; card < ticket.pairs; card++)
    for (var i = 0; i < ticket.board.length; i++)
      if (ticket.board[i] == card) i,
];

Future<void> settled(EconomyController controller) async {
  for (var i = 0; i < 1000 && controller.syncing; i++) {
    await Future<void>.delayed(Duration.zero);
  }
  expect(controller.syncing, isFalse);
}

class SoloApi {
  bool connected = false, loseNextReceipt = false;
  int balance = 100, revision = 1, creates = 0;
  final owned = {...ProfileData.freeDecks};
  final receipts = <String, Map<String, dynamic>>{};
  final best = <String, int>{};
  final completed = <String>{};
  final requestOrder = <String>[];
  String? bootstrap;
  Completer<http.Response>? holdCreation;

  Map<String, dynamic> snapshot({String id = 'server-guest'}) => {
    ...profile(id: id, gems: balance, revision: revision),
    'ownedDecks': owned.toList(),
    'legacyDecks': <String>[],
    'soloBestAttempts': {...best},
  };

  Future<http.Response> handle(http.Request request) async {
    requestOrder.add(request.url.path);
    if (holdCreation != null && request.url.path.endsWith('/profiles')) {
      return holdCreation!.future;
    }
    if (!connected) throw http.ClientException('offline');
    if (request.url.path.endsWith('/profiles')) {
      creates++;
      final body = jsonDecode(request.body) as Map;
      bootstrap ??= body['bootstrapToken'] as String;
      expect(body['bootstrapToken'], bootstrap);
      return response({'token': bootstrap, 'profile': snapshot()}, 201);
    }
    if (request.url.path.endsWith('/restore')) {
      return response({
        'token': token,
        'profile': {...snapshot(id: 'other-account'), 'gems': 900},
      });
    }
    if (request.url.path.endsWith('/operations')) {
      final operation = jsonDecode(request.body) as Map<String, dynamic>;
      final requestId = operation['requestId'] as String;
      var receipt = receipts[requestId];
      if (receipt == null) {
        if (operation['kind'] == 'unlock') {
          if (!owned.contains(operation['deckId'])) {
            if (balance < 200) {
              return response({
                'error': {
                  'code': 'INSUFFICIENT_GEMS',
                  'message': 'Gemme insufficienti.',
                },
              }, 409);
            }
            balance -= 200;
            owned.add(operation['deckId'] as String);
          }
        } else {
          if (!owned.contains(operation['theme'])) {
            return response({
              'error': {
                'code': 'DECK_LOCKED',
                'message': 'Collezione bloccata.',
              },
            }, 409);
          }
          if (completed.add(operation['gameId'] as String)) balance += 20;
          final key = '${operation['pairs']}';
          final attempts = (operation['moves'] as List).length ~/ 2;
          if (best[key] == null || attempts < best[key]!) best[key] = attempts;
        }
        revision++;
        receipt = {'requestId': requestId, 'kind': operation['kind']};
        receipts[requestId] = receipt;
        if (loseNextReceipt) {
          loseNextReceipt = false;
          throw http.ClientException('response lost after commit');
        }
      }
      return response({'profile': snapshot(), 'operation': receipt});
    }
    if (request.method == 'PATCH') revision++;
    return response({'profile': snapshot()});
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late SharedPreferences prefs;
  late MemorySecrets secrets;
  late SoloApi api;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    secrets = MemorySecrets();
    api = SoloApi();
  });

  EconomyController controller() => EconomyController(
    prefs: prefs,
    secrets: secrets,
    client: MockClient(api.handle),
  );

  Future<GameTicket> finish(
    EconomyController c, {
    String theme = 'garden',
  }) async {
    final ticket = (await c.takeTicket(mode: 'solo', pairs: 6, theme: theme))!;
    final result = await c.claimGame(ticket: ticket, moves: solution(ticket));
    expect(result?.granted, isTrue);
    return ticket;
  }

  test(
    'first launch can play and earn immediately while network startup stalls',
    () async {
      api.holdCreation = Completer<http.Response>();
      final c = controller();
      final initialization = c.initialize();
      await c.localReady.timeout(const Duration(seconds: 1));
      expect(c.profile!.id, startsWith('offline_'));
      expect(c.gems, 100);
      await finish(c).timeout(const Duration(seconds: 1));
      expect(c.gems, 120);
      expect(c.pendingRewards, 1);
      expect(prefs.getInt('best.6'), 6);
      expect(
        prefs.getString('profile.solo.v1'),
        isNot(contains('bootstrapToken')),
      );
      api.holdCreation!.completeError(http.ClientException('offline'));
      await initialization;
      c.dispose();
    },
  );

  test(
    'unlimited offline rewards and purchases survive restart and synchronize in order',
    () async {
      final first = controller();
      await first.initialize();
      final originalId = first.profile!.id;
      GameTicket? firstTicket;
      for (var i = 0; i < 135; i++) {
        firstTicket ??= await finish(first);
        if (i > 0) await finish(first);
      }
      await first.unlockDeck('insects');
      expect(first.gems, 2600);
      expect(first.ownsDeck('insects'), isTrue);
      expect(first.pendingRewards, 135);
      expect(first.pendingChanges, 136);
      first.dispose();

      await prefs.remove(
        'best.6',
      ); // Simulate interruption before the presentation record write.
      final reopened = controller();
      await reopened.initialize();
      expect(reopened.profile!.id, originalId);
      expect(reopened.gems, 2600);
      expect(reopened.ownsDeck('insects'), isTrue);
      expect(prefs.getInt('best.6'), 6);
      final duplicate = await reopened.claimGame(
        ticket: firstTicket!,
        moves: solution(firstTicket),
      );
      expect(duplicate!.granted, isFalse);
      expect(reopened.gems, 2600);
      api.connected = true;
      await reopened.sync();
      expect(reopened.profile!.id, 'server-guest');
      expect(reopened.pendingChanges, 0);
      expect(reopened.gems, 2600);
      expect(api.balance, 2600);
      expect(api.completed.length, 135);
      expect(reopened.profile!.crowns, 0);
      expect(reopened.profile!.soloBestAttempts, {'6': 6});
      expect(api.creates, 1);
      final afterBootstrap = await reopened.claimGame(
        ticket: firstTicket,
        moves: solution(firstTicket),
      );
      expect(afterBootstrap!.granted, isFalse);
      reopened.dispose();
    },
  );

  test(
    'a committed but lost receipt never doubles the wallet after refresh or reopening',
    () async {
      api.connected = true;
      final c = controller();
      await c.initialize();
      api.connected = false;
      await finish(c);
      await settled(c);
      expect(c.gems, 120);
      api.connected = true;
      api.loseNextReceipt = true;
      await c.sync();
      expect(api.balance, 120);
      expect(c.gems, 120);
      expect(c.pendingChanges, 1);
      // Appearance replies include the committed server wallet. They must not
      // reinterpret an ambiguous pending receipt as another local reward.
      await c.setAppearance(avatarId: 'owl');
      expect(c.gems, 120);
      c.dispose();
      api.connected = false;
      final reopened = controller();
      await reopened.initialize();
      expect(reopened.gems, 120);
      api.connected = true;
      final observed = <int>[];
      reopened.addListener(() => observed.add(reopened.gems));
      await reopened.sync();
      expect(observed.every((balance) => balance == 120), isTrue);
      expect(reopened.gems, 120);
      expect(reopened.pendingChanges, 0);
      expect(api.completed.length, 1);
      reopened.dispose();
    },
  );

  test(
    'another device spending cached gems does not strand later completions',
    () async {
      api.connected = true;
      api.balance = 200;
      final c = controller();
      await c.initialize();
      api.connected = false;
      await c.unlockDeck('insects');
      await settled(c);
      await finish(c, theme: 'insects');
      for (var i = 0; i < 5; i++) {
        await finish(c);
      }
      await settled(c);
      // A second device spent half the wallet before this device reconnected.
      api.balance = 100;
      api.connected = true;
      await c.sync();
      expect(c.pendingChanges, 0);
      expect(c.ownsDeck('insects'), isTrue);
      expect(c.gems, 20);
      expect(api.balance, 20);
      c.dispose();
    },
  );

  test(
    'switching accounts preserves the first offline guest and binds unfinished tickets to its owner',
    () async {
      final c = controller();
      await c.initialize();
      final localId = c.profile!.id;
      await finish(c);
      await settled(c);
      final unfinished = (await c.takeTicket(
        mode: 'solo',
        pairs: 6,
        theme: 'garden',
      ))!;
      api.connected = true;
      await c.restoreRecovery('other-account-code');
      expect(c.profile!.id, 'other-account');
      expect(c.gems, 900);
      expect(
        await c.claimGame(ticket: unfinished, moves: solution(unfinished)),
        isNull,
      );
      expect(
        (await c.archivedAccountProfiles()).map((p) => p.id),
        contains(localId),
      );
      await c.restoreArchivedAccount(localId);
      expect(c.profile!.id, 'server-guest');
      expect(c.gems, 120);
      await c.sync();
      expect(c.pendingChanges, 0);
      expect(c.gems, 120);
      await c.claimGame(ticket: unfinished, moves: solution(unfinished));
      expect(c.gems, 140);
      await settled(c);
      c.dispose();
    },
  );
}
