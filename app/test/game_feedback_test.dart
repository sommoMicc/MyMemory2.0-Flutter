import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/services.dart';
import 'package:mymemory/game_feedback.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FakeAudio implements GameFeedbackAudio {
  final events = <GameFeedbackEvent>[];
  Completer<void>? hold, unlockHold;
  final started = Completer<void>();
  int playing = 0, maxPlaying = 0, stops = 0, unlocks = 0;
  bool fail = false, disposed = false;
  @override
  Future<void> unlock() async {
    unlocks++;
    await unlockHold?.future;
  }

  @override
  Future<void> play(GameFeedbackEvent event) async {
    if (fail) throw StateError('Audio unavailable');
    events.add(event);
    playing++;
    if (playing > maxPlaying) maxPlaying = playing;
    if (!started.isCompleted) started.complete();
    await hold?.future;
    playing--;
  }

  @override
  Future<void> stop() async {
    stops++;
    if (hold != null && !hold!.isCompleted) hold!.complete();
    if (unlockHold != null && !unlockHold!.isCompleted) unlockHold!.complete();
  }

  @override
  Future<void> dispose() async {
    disposed = true;
    await stop();
  }
}

class FakeHaptics implements GameFeedbackHaptics {
  final events = <GameFeedbackEvent>[];
  bool fail = false;
  @override
  Future<void> play(GameFeedbackEvent event) async {
    if (fail) throw StateError('Haptics unavailable');
    events.add(event);
  }
}

Future<void> settle() => Future<void>.delayed(Duration.zero);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'audio bundle includes only playable data and its notice, never scripts',
    () async {
      final manifest = await AssetManifest.loadFromAssetBundle(rootBundle);
      expect(
        manifest
            .listAssets()
            .where((path) => path.startsWith('assets/audio/'))
            .toSet(),
        {'assets/audio/game_feedback.wav', 'assets/audio/NOTICE.txt'},
      );
    },
  );
  late SharedPreferences prefs;
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
  });

  test('construction does no platform I/O; defaults enable both effects', () {
    final feedback = GameFeedback(prefs);
    expect(feedback.soundEnabled, true);
    expect(feedback.hapticsEnabled, true);
    feedback.dispose();
  });

  test('all four cues run in order with one active sound', () async {
    final audio = FakeAudio(), haptics = FakeHaptics();
    final feedback = GameFeedback(prefs, audio: audio, haptics: haptics);
    for (final event in GameFeedbackEvent.values) {
      feedback.play(event);
    }
    await feedback.settled;
    expect(audio.events, GameFeedbackEvent.values);
    expect(haptics.events, GameFeedbackEvent.values);
    expect(audio.maxPlaying, 1);
    feedback.dispose();
  });

  test(
    'sound and haptics preferences persist and are read on every cue',
    () async {
      final audio = FakeAudio(), haptics = FakeHaptics();
      final feedback = GameFeedback(prefs, audio: audio, haptics: haptics);
      await prefs.setBool('sound', false);
      feedback.play(GameFeedbackEvent.flip);
      await feedback.settled;
      expect(audio.events, isEmpty);
      expect(haptics.events, [GameFeedbackEvent.flip]);
      await prefs.setBool('haptics', false);
      await prefs.setBool('sound', true);
      feedback.play(GameFeedbackEvent.match);
      await feedback.settled;
      expect(audio.events, [GameFeedbackEvent.match]);
      expect(haptics.events, [GameFeedbackEvent.flip]);
      feedback.dispose();
      final reopened = GameFeedback(
        prefs,
        audio: FakeAudio(),
        haptics: FakeHaptics(),
      );
      expect(reopened.soundEnabled, true);
      expect(reopened.hapticsEnabled, false);
      reopened.dispose();
    },
  );

  test(
    'suspension cancels the playing cue and queued cues never replay',
    () async {
      final audio = FakeAudio()..hold = Completer<void>();
      final haptics = FakeHaptics();
      final feedback = GameFeedback(prefs, audio: audio, haptics: haptics);
      feedback.play(GameFeedbackEvent.flip);
      await audio.started.future;
      feedback.play(GameFeedbackEvent.match);
      feedback.play(GameFeedbackEvent.turn);
      feedback.setActive(false);
      feedback.play(GameFeedbackEvent.mismatch);
      feedback.setActive(true);
      feedback.play(GameFeedbackEvent.turn);
      await feedback.settled;
      expect(audio.events, [GameFeedbackEvent.flip, GameFeedbackEvent.turn]);
      expect(haptics.events, [GameFeedbackEvent.flip, GameFeedbackEvent.turn]);
      expect(audio.stops, greaterThanOrEqualTo(1));
      expect(audio.maxPlaying, 1);
      feedback.dispose();
    },
  );

  test(
    'late audio unlock cannot start stale playback after suspension',
    () async {
      final audio = FakeAudio()..unlockHold = Completer<void>();
      final feedback = GameFeedback(
        prefs,
        audio: audio,
        haptics: FakeHaptics(),
      );
      feedback.unlock();
      feedback.play(GameFeedbackEvent.flip);
      await settle();
      feedback.setActive(false);
      await feedback.settled;
      expect(audio.events, isEmpty);
      feedback.setActive(true);
      feedback.unlock();
      feedback.play(GameFeedbackEvent.turn);
      await feedback.settled;
      expect(audio.events, [GameFeedbackEvent.turn]);
      feedback.dispose();
    },
  );

  test(
    'audio and haptic errors are silent and do not poison later cues',
    () async {
      final audio = FakeAudio()..fail = true;
      final haptics = FakeHaptics()..fail = true;
      final feedback = GameFeedback(prefs, audio: audio, haptics: haptics);
      feedback.play(GameFeedbackEvent.mismatch);
      await feedback.settled;
      audio.fail = haptics.fail = false;
      feedback.play(GameFeedbackEvent.match);
      await feedback.settled;
      expect(audio.events, [GameFeedbackEvent.match]);
      expect(haptics.events, [GameFeedbackEvent.match]);
      feedback.dispose();
    },
  );

  test(
    'disposing drops queued effects and releases the audio player',
    () async {
      final audio = FakeAudio()..hold = Completer<void>();
      final feedback = GameFeedback(
        prefs,
        audio: audio,
        haptics: FakeHaptics(),
      );
      feedback.play(GameFeedbackEvent.flip);
      await audio.started.future;
      feedback.play(GameFeedbackEvent.match);
      feedback.dispose();
      feedback.unlock();
      feedback.play(GameFeedbackEvent.turn);
      await feedback.settled;
      expect(audio.events, [GameFeedbackEvent.flip]);
      expect(audio.disposed, true);
    },
  );

  test(
    'bundled original PCM has audible cues separated by at least a second',
    () {
      final data = File('assets/audio/game_feedback.wav').readAsBytesSync();
      final bytes = ByteData.sublistView(data);
      expect(String.fromCharCodes(data.sublist(0, 4)), 'RIFF');
      expect(String.fromCharCodes(data.sublist(8, 12)), 'WAVE');
      expect(bytes.getUint16(20, Endian.little), 1);
      expect(bytes.getUint16(22, Endian.little), 1);
      expect(bytes.getUint32(24, Endian.little), 22050);
      expect(bytes.getUint16(34, Endian.little), 16);
      final pcm = [
        for (var i = 44; i < data.length; i += 2)
          bytes.getInt16(i, Endian.little),
      ];
      final clips = AudioplayersGameAudio.clips.values.toList();
      for (var i = 0; i < clips.length; i++) {
        final (start, length) = clips[i];
        final begin = (start * 22.05).round(),
            end = ((start + length) * 22.05).round();
        expect(pcm.sublist(begin, end).any((v) => v != 0), true);
        if (i < clips.length - 1) {
          final next = clips[i + 1].$1;
          expect(next - start - length, greaterThanOrEqualTo(1000));
          expect(
            pcm.sublist(end + 1, (next * 22.05).round()).every((v) => v == 0),
            true,
          );
        }
      }
      expect(
        pcm.map((v) => v.abs()).reduce((a, b) => a > b ? a : b),
        lessThan(25000),
      );
    },
  );
}
