import 'arena_catalog_data.g.dart';

class Arena {
  const Arena({required this.id, required this.name, required this.minCrowns});
  final String id;
  final String name;
  final int minCrowns;
}

class ArenaDeck {
  const ArenaDeck({
    required this.id,
    required this.name,
    required this.arenaId,
    required this.price,
    required this.contentReady,
  });
  final String id;
  final String name;
  final String? arenaId;
  final int price;
  final bool contentReady;
  bool get isFree => price == 0;
  bool get isPlayable => contentReady;
}

class ArenaRules {
  const ArenaRules({
    required this.friendlyRounds,
    required this.rankedRounds,
    required this.crownsWin,
    required this.crownsLoss,
    required this.crownsDraw,
    required this.crownsFloor,
  });
  final int friendlyRounds, rankedRounds;
  final int crownsWin, crownsLoss, crownsDraw, crownsFloor;
}

class ArenaCatalog {
  ArenaCatalog._(
    this.schemaVersion,
    this.rankedEnabled,
    this.rules,
    this.arenas,
    this.decks,
  );
  final int schemaVersion;
  final bool rankedEnabled;
  final ArenaRules rules;
  final List<Arena> arenas;
  final List<ArenaDeck> decks;

  static final ArenaCatalog instance = ArenaCatalog.fromJson(arenaCatalogData);
  factory ArenaCatalog.fromJson(Map<String, Object?> json) {
    if (json['schemaVersion'] != 1 || json['rankedEnabled'] is! bool) {
      throw const FormatException('Invalid arena catalog header');
    }
    final rawRules = _object(json['rules'], 'rules');
    final rules = ArenaRules(
      friendlyRounds: _integer(rawRules, 'friendlyRounds', min: 1),
      rankedRounds: _integer(rawRules, 'rankedRounds', min: 1),
      crownsWin: _integer(rawRules, 'crownsWin', min: 0),
      crownsLoss: _integer(rawRules, 'crownsLoss', max: 0),
      crownsDraw: _integer(rawRules, 'crownsDraw'),
      crownsFloor: _integer(rawRules, 'crownsFloor', min: 0),
    );
    final arenas = (json['arenas'] as List)
        .map((raw) {
          final item = Map<String, Object?>.from(raw as Map);
          return Arena(
            id: item['id'] as String,
            name: item['name'] as String,
            minCrowns: item['minCrowns'] as int,
          );
        })
        .toList(growable: false);
    final decks = (json['decks'] as List)
        .map((raw) {
          final item = Map<String, Object?>.from(raw as Map);
          return ArenaDeck(
            id: item['id'] as String,
            name: item['name'] as String,
            arenaId: item['arenaId'] as String?,
            price: item['price'] as int,
            contentReady: item['contentReady'] as bool,
          );
        })
        .toList(growable: false);
    if (arenas.isEmpty ||
        arenas.first.minCrowns != 0 ||
        arenas.any((a) => a.id.isEmpty || a.name.isEmpty || a.minCrowns < 0) ||
        arenas.map((a) => a.id).toSet().length != arenas.length ||
        arenas.asMap().entries.any(
          (e) => e.key > 0 && e.value.minCrowns <= arenas[e.key - 1].minCrowns,
        )) {
      throw const FormatException('Invalid arena thresholds');
    }
    if (decks.map((d) => d.id).toSet().length != decks.length ||
        decks.any(
          (d) =>
              d.id.isEmpty ||
              d.name.isEmpty ||
              d.price < 0 ||
              (d.arenaId != null && !arenas.any((a) => a.id == d.arenaId)),
        )) {
      throw const FormatException('Invalid arena decks');
    }
    if (decks.where((d) => d.id == 'paola' && d.arenaId == null).length != 1 ||
        arenas.any(
          (arena) =>
              decks.where((d) => d.arenaId == arena.id && d.isFree).length < 3,
        )) {
      throw const FormatException('Invalid arena deck assignments');
    }
    return ArenaCatalog._(
      json['schemaVersion'] as int,
      json['rankedEnabled'] as bool,
      rules,
      List.unmodifiable(arenas),
      List.unmodifiable(decks),
    );
  }

  Arena arenaForCrowns(int crowns) {
    _nonNegative(crowns, 'crowns');
    return arenas.lastWhere((arena) => crowns >= arena.minCrowns);
  }

  List<Arena> unlockedBy(int peakCrowns) {
    _nonNegative(peakCrowns, 'peakCrowns');
    return List.unmodifiable(
      arenas.where((arena) => arena.minCrowns <= peakCrowns),
    );
  }

  List<ArenaDeck> freeDecksFor(String arenaId) => List.unmodifiable(
    decks.where(
      (deck) => deck.arenaId == arenaId && deck.isFree && deck.isPlayable,
    ),
  );
}

class ArenaProgress {
  ArenaProgress({
    required this.crowns,
    required this.peakCrowns,
    ArenaCatalog? catalog,
  }) : catalog = catalog ?? ArenaCatalog.instance {
    _nonNegative(crowns, 'crowns');
    _nonNegative(peakCrowns, 'peakCrowns');
    if (peakCrowns < crowns) {
      throw const FormatException('peakCrowns must be >= crowns');
    }
  }
  final int crowns;
  final int peakCrowns;
  final ArenaCatalog catalog;
  String get currentArenaId => catalog.arenaForCrowns(crowns).id;
  Set<String> get unlockedArenaIds =>
      Set.unmodifiable(catalog.unlockedBy(peakCrowns).map((a) => a.id));

  bool canUseDeck(String id, {required Set<String> ownedDecks}) {
    final matching = catalog.decks.where((deck) => deck.id == id);
    if (matching.isEmpty) return false;
    final deck = matching.first;
    if (!deck.isPlayable) return false;
    if (ownedDecks.contains(id)) return true;
    return deck.isFree && deck.arenaId != null && unlockedArenaIds.contains(deck.arenaId);
  }

  bool canUnlockDeck(String id) {
    final matching = catalog.decks.where((deck) => deck.id == id);
    if (matching.isEmpty) return false;
    final deck = matching.first;
    return deck.isPlayable && deck.price > 0 &&
        deck.arenaId != null && unlockedArenaIds.contains(deck.arenaId);
  }

  List<ArenaDeck> friendlyDecks(Set<String> ownedDecks) => List.unmodifiable(
    catalog.decks.where(
      (deck) => canUseDeck(deck.id, ownedDecks: ownedDecks),
    ),
  );
}

void _nonNegative(int value, String field) {
  if (value < 0) throw FormatException('$field must be a non-negative integer');
}

Map<String, Object?> _object(Object? value, String field) {
  if (value is! Map) throw FormatException('Invalid $field');
  return Map<String, Object?>.from(value);
}

int _integer(Map<String, Object?> values, String field, {int? min, int? max}) {
  final value = values[field];
  if (value is! int ||
      (min != null && value < min) ||
      (max != null && value > max)) {
    throw FormatException('Invalid $field');
  }
  return value;
}
