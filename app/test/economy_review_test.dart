import 'dart:async';
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mymemory/economy.dart';
import 'package:shared_preferences/shared_preferences.dart';
// Test-only platform fake models a delayed disk write in shared_preferences.
// ignore: depend_on_referenced_packages
import 'package:shared_preferences_platform_interface/shared_preferences_platform_interface.dart';

class Secrets implements EconomySecrets {
  final values = <String, String>{};
  @override
  Future<String?> read(String key) async => values[key];
  @override
  Future<void> write(String key, String value) async {
    values[key] = value;
  }

  @override
  Future<void> delete(String key) async {
    values.remove(key);
  }
}

class BlockingStore extends InMemorySharedPreferencesStore {
  BlockingStore() : super.empty();
  bool block = false;
  final entered = Completer<void>();
  final released = Completer<void>();
  @override
  Future<bool> setValue(String type, String key, Object value) async {
    if (block) {
      block = false;
      entered.complete();
      await released.future;
    }
    return super.setValue(type, key, value);
  }
}

Map<String, dynamic> profile(String id) => {
  'id': id,
  'displayName': '',
  'gems': 100,
  'activated': false,
  'ownedDecks': ['garden', 'cosmos', 'ocean'],
  'revision': 1,
};
http.Response reply(Map<String, dynamic> body) =>
    http.Response(jsonEncode(body), 200);
const firstToken = 'first-test-token-that-is-long-enough-for-controller';
const secondToken = 'second-test-token-that-is-long-enough-for-controller';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'saved session without profile cache can safely prefetch while GET pending',
    () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final secrets = Secrets()
        ..values['sommomemory.profile.session.v1'] = jsonEncode({
          'token': firstToken,
          'profileId': 'first',
        });
      final got = Completer<void>(), pending = Completer<http.Response>();
      final c = EconomyController(
        prefs: prefs,
        secrets: secrets,
        client: MockClient((req) async {
          got.complete();
          return pending.future;
        }),
      );
      final init = c.initialize();
      addTearDown(() async {
        if (!pending.isCompleted) {
          pending.complete(reply({'profile': profile('first')}));
        }
        await init;
        c.dispose();
      });
      await got.future;
      await expectLater(
        c
            .prefetchTicket(mode: 'solo', pairs: 6, theme: 'garden')
            .timeout(const Duration(seconds: 2)),
        completes,
      );
      pending.complete(reply({'profile': profile('first')}));
      await init;
    },
  );
  test(
    'queued proof must not be sent as newly restored profile after persistence yield',
    () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final store = BlockingStore();
      SharedPreferencesStorePlatform.instance = store;
      String? claimAuth;
      final c = EconomyController(
        prefs: prefs,
        secrets: Secrets(),
        client: MockClient((req) async {
          if (req.url.path.endsWith('/profiles')) {
            return reply({'token': firstToken, 'profile': profile('first')});
          }
          if (req.url.path.endsWith('/restore')) {
            return reply({'token': secondToken, 'profile': profile('second')});
          }
          if (req.url.path.endsWith('/claims')) {
            claimAuth = req.headers['Authorization'];
            return reply({
              'profile': profile('second'),
              'reward': {'gems': 20, 'granted': true},
            });
          }
          return reply({'profile': profile('first')});
        }),
      );
      addTearDown(c.dispose);
      await c.initialize();
      store.block = true;
      final claim = c.claimProof(
        ticketId: 'game-under-first',
        moves: [0, 1],
        guestClaimToken: 'bluetooth-capability',
      );
      await store.entered.future;
      final restore = c.restoreRecovery('recovery-second');
      for (var n = 0; n < 30 && c.profile?.id != 'second'; n++) {
        await Future<void>.delayed(Duration.zero);
      }
      expect(c.profile?.id, 'second');
      store.released.complete();
      await restore;
      await claim;
      expect(claimAuth, anyOf(isNull, 'Bearer $firstToken'));
    },
  );
  test(
    'corrupt display cache must not erase durable pending claims on refresh',
    () async {
      SharedPreferences.setMockInitialValues({
        'profile.cache.v1': 'invalid-json',
        'profile.claims.v1': jsonEncode([
          {
            'profileId': 'first',
            'ticketId': 'pending-first',
            'moves': [0, 1],
            'requestId': 'request-first',
          },
        ]),
      });
      final prefs = await SharedPreferences.getInstance();
      final secrets = Secrets()
        ..values['sommomemory.profile.session.v1'] = jsonEncode({
          'token': firstToken,
          'profileId': 'first',
        });
      var claims = 0;
      final c = EconomyController(
        prefs: prefs,
        secrets: secrets,
        client: MockClient((req) async {
          if (req.url.path.endsWith('/claims')) {
            claims++;
            throw http.ClientException('offline');
          }
          return reply({'profile': profile('first')});
        }),
      );
      addTearDown(c.dispose);
      await c.initialize();
      await c.refresh();
      expect(c.pendingRewards, 1);
      expect(claims, greaterThanOrEqualTo(1));
    },
  );
}
