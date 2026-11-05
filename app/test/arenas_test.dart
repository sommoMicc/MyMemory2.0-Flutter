import 'package:flutter_test/flutter_test.dart';
import 'package:mymemory/arenas.dart';

void main() {
  final catalog = ArenaCatalog.instance;

  test('catalog contains 21 decks and keeps Paola external', () {
    expect(catalog.decks, hasLength(22)); // 21 arena decks plus Paola.
    expect(catalog.decks.where((deck) => deck.arenaId != null), hasLength(21));
    expect(
      catalog.decks.singleWhere((deck) => deck.id == 'paola').arenaId,
      isNull,
    );
    expect(catalog.arenas, hasLength(4));
    expect(catalog.rules.friendlyRounds, 1);
    expect(catalog.rules.rankedRounds, 3);
    expect(catalog.rules.crownsWin, 20);
    expect(catalog.rules.crownsLoss, -20);
    expect(catalog.rules.crownsDraw, 0);
    expect(catalog.rules.crownsFloor, 0);
  });

  test(
    'every arena has at least three free decks and readiness is respected',
    () {
      for (final arena in catalog.arenas) {
        expect(
          catalog.decks.where((d) => d.arenaId == arena.id && d.isFree),
          hasLength(greaterThanOrEqualTo(3)),
        );
        expect(
          catalog.freeDecksFor(arena.id).every((deck) => deck.contentReady),
          isTrue,
        );
      }
    },
  );

  test('planned free decks stay non-playable without ready content', () {
    final fixture = ArenaCatalog.fromJson({
      'schemaVersion': 1,
      'rankedEnabled': false,
      'rules': {
        'friendlyRounds': 1,
        'rankedRounds': 3,
        'crownsWin': 20,
        'crownsLoss': -20,
        'crownsDraw': 0,
        'crownsFloor': 0,
      },
      'arenas': [
        {'id': 'wild_valley', 'name': 'Valle Selvaggia', 'minCrowns': 0},
      ],
      'decks': [
        {
          'id': 'ready',
          'name': 'Pronto',
          'arenaId': 'wild_valley',
          'price': 0,
          'contentReady': true,
        },
        {
          'id': 'planned_a',
          'name': 'Previsto A',
          'arenaId': 'wild_valley',
          'price': 0,
          'contentReady': false,
        },
        {
          'id': 'planned_b',
          'name': 'Previsto B',
          'arenaId': 'wild_valley',
          'price': 0,
          'contentReady': false,
        },
        {
          'id': 'paola',
          'name': 'Paola',
          'arenaId': null,
          'price': 0,
          'contentReady': true,
        },
      ],
    });
    expect(fixture.freeDecksFor('wild_valley').map((deck) => deck.id), [
      'ready',
    ]);
  });

  test('thresholds are inclusive', () {
    for (final (crowns, id) in <(int, String)>[
      (0, 'wild_valley'),
      (99, 'wild_valley'),
      (100, 'coral_bay'),
      (299, 'coral_bay'),
      (300, 'grand_city'),
      (599, 'grand_city'),
      (600, 'space_frontier'),
    ]) {
      expect(catalog.arenaForCrowns(crowns).id, id);
    }
  });

  test('friendly arenas use peak while current arena uses current crowns', () {
    final progress = ArenaProgress(crowns: 80, peakCrowns: 100);
    expect(progress.currentArenaId, 'wild_valley');
    expect(progress.unlockedArenaIds, {'wild_valley', 'coral_bay'});
  });

  test('ranked activation agrees with three ready free decks per arena', () {
    final playable = catalog.arenas.every(
      (arena) => catalog.freeDecksFor(arena.id).length >= 3,
    );
    expect(catalog.rankedEnabled, playable);
  });

  test('friendly decks include free decks and only owned ready purchases', () {
    final progress = ArenaProgress(crowns: 0, peakCrowns: 300);
    final withoutPurchase = progress.friendlyDecks({
      'garden',
      'cosmos',
      'ocean',
    });
    expect(withoutPurchase.map((deck) => deck.id), contains('garden'));
    expect(withoutPurchase.map((deck) => deck.id), isNot(contains('food')));
    final withPurchase = progress.friendlyDecks({'garden', 'food'});
    expect(withPurchase.map((deck) => deck.id), contains('food'));
    expect(withPurchase.map((deck) => deck.id), isNot(contains('sports')));
    expect(withPurchase.map((deck) => deck.id), isNot(contains('paola')));
  });

  test('owned legacy decks stay usable and purchases remain arena-gated', () {
    final progress = ArenaProgress(crowns: 0, peakCrowns: 0);
    expect(progress.canUseDeck('food', ownedDecks: {'food'}), isTrue);
    expect(progress.canUseDeck('ocean', ownedDecks: {'ocean'}), isTrue);
    expect(progress.canUseDeck('ocean', ownedDecks: const {}), isFalse);
    expect(progress.canUnlockDeck('food'), isFalse);
  });
}
