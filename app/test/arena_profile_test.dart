import 'package:flutter_test/flutter_test.dart';
import 'package:mymemory/economy.dart';

Map<String, dynamic> legacyProfile() => {
  'id': 'p1',
  'displayName': 'Giocatore',
  'activated': true,
  'gems': 125,
  'ownedDecks': ['food', 'garden'],
  'revision': 7,
};

void main() {
  test('legacy snapshot defaults crowns to 0 and derives starting arena', () {
    final profile = ProfileData.fromJson(legacyProfile());
    expect(profile.crowns, 0);
    expect(profile.peakCrowns, 0);
    expect(profile.currentArenaId, 'wild_valley');
    expect(profile.unlockedArenaIds, {'wild_valley'});
    expect(profile.gems, 125);
    expect(profile.ownedDecks, contains('food'));
  });

  test(
    'missing peak defaults to current crowns and retrogression keeps unlocks',
    () {
      final profile = ProfileData.fromJson({
        ...legacyProfile(),
        'crowns': 80,
        'currentArenaId': 'space_frontier',
        'unlockedArenaIds': ['space_frontier'],
      });
      expect(profile.peakCrowns, 80);
      expect(profile.currentArenaId, 'wild_valley');
      expect(profile.unlockedArenaIds, {'wild_valley'});

      final demoted = ProfileData.fromJson({
        ...legacyProfile(),
        'crowns': 80,
        'peakCrowns': 100,
      });
      expect(demoted.currentArenaId, 'wild_valley');
      expect(demoted.unlockedArenaIds, {'wild_valley', 'coral_bay'});
    },
  );

  test('new profile round trips crown balances and derived metadata', () {
    final original = ProfileData.fromJson({
      ...legacyProfile(),
      'crowns': 100,
      'peakCrowns': 600,
    });
    final json = original.toJson();
    expect(json['currentArenaId'], 'coral_bay');
    expect(json['unlockedArenaIds'], [
      'wild_valley',
      'coral_bay',
      'grand_city',
      'space_frontier',
    ]);
    final restored = ProfileData.fromJson(json);
    expect(restored.crowns, 100);
    expect(restored.peakCrowns, 600);
    expect(restored.currentArenaId, 'coral_bay');
    expect(restored.unlockedArenaIds, original.unlockedArenaIds);
    expect(restored.gems, original.gems);
    expect(restored.ownedDecks, original.ownedDecks);
  });

  test('rejects invalid balances without silently resetting them', () {
    expect(
      () => ProfileData.fromJson({...legacyProfile(), 'crowns': -1}),
      throwsFormatException,
    );
    expect(
      () => ProfileData.fromJson({...legacyProfile(), 'crowns': '100'}),
      throwsFormatException,
    );
    expect(
      () => ProfileData.fromJson({
        ...legacyProfile(),
        'crowns': 100,
        'peakCrowns': 99,
      }),
      throwsFormatException,
    );
  });
}
