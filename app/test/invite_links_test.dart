import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mymemory/invite_links.dart';

Uri invite(String code) =>
    Uri.parse('https://sommomemory.sommomi.cc/invite/$code');
Future<void> settle() => Future<void>.delayed(Duration.zero);

void main() {
  group('invitation routes', () {
    test(
      'canonical URLs normalize codes and support legacy host and query',
      () {
        for (final url in [
          'https://sommomemory.sommomi.cc/invite/ABC234',
          'https://sommomemory.sommomi.cc/invite/abc234/',
          'https://mymemory.sommomi.cc/invite/ABC234',
          'https://sommomemory.sommomi.cc/?room=abc234',
          'https://mymemory.sommomi.cc?room=ABC234',
          'http://mymemory.sommomi.cc/?room=ABC234',
          'https://sommomemory.sommomi.cc:443/invite/ABC234',
        ]) {
          expect(roomCodeFromInviteString(url), 'ABC234', reason: url);
        }
        expect(
          inviteUriForRoom(' abc234 ').toString(),
          'https://sommomemory.sommomi.cc/invite/ABC234',
        );
        expect(() => inviteUriForRoom('INVALID'), throwsArgumentError);
      },
    );

    test('ignores unrelated routes, invalid codes and conflicting queries', () {
      for (final path in [
        '/',
        '/privacy?room=ABC234',
        '/support?room=ABC234',
        '/invite/ABC234/extra',
        '/invite/ABC234?room=DEF567',
        '/invite/ABC234?room=ABC234&room=ABC234',
        '/?room=ABC234&room=DEF567',
        '/?room=ABC01Z',
        '/?room=ABC2345',
        '/?room=%FF',
        '/invite/AB%2FC23',
      ]) {
        expect(
          roomCodeFromInviteString('https://sommomemory.sommomi.cc$path'),
          isNull,
          reason: path,
        );
      }
    });

    test('accepts only exact trusted HTTP hosts and standard ports', () {
      for (final url in [
        'https://sommomemory.sommomi.cc.evil.example/invite/ABC234',
        'https://evil.example/invite/ABC234',
        'https://user@sommomemory.sommomi.cc/invite/ABC234',
        'https://sommomemory.sommomi.cc:8443/invite/ABC234',
        'http://sommomemory.sommomi.cc:443/invite/ABC234',
        'file://sommomemory.sommomi.cc/invite/ABC234',
        '/invite/ABC234',
        'ABC234',
      ]) {
        expect(roomCodeFromInviteString(url), isNull, reason: url);
      }
    });

    test(
      'explicit app fallback contains only a room and validates strictly',
      () {
        expect(
          inviteAppUriForRoom(' abc234 ').toString(),
          'sommomemory://invite/ABC234',
        );
        expect(
          roomCodeFromInviteString('sommomemory://invite/abc234'),
          'ABC234',
        );
        expect(() => inviteAppUriForRoom('INVALID'), throwsArgumentError);
        for (final url in [
          'sommomemory://profile/ABC234',
          'sommomemory://invite/ABC234/',
          'sommomemory://invite/ABC234/extra',
          'sommomemory://invite/ABC234?room=ABC234',
          'sommomemory://invite/ABC234?profileToken=secret',
          'sommomemory://invite/ABC234?recoveryCode=secret',
          'sommomemory://invite/ABC234?',
          'sommomemory://invite/ABC234#secret',
          'sommomemory://user@invite/ABC234',
          'sommomemory://invite:443/ABC234',
          'sommomemory://invite/%20ABC234%20',
          'sommomemory://invite/ABC01Z',
          'sommomemory://invite/ABC2345',
          'sommomemory:invite/ABC234',
        ]) {
          expect(roomCodeFromInviteString(url), isNull, reason: url);
        }
      },
    );
  });

  group('invitation lifecycle', () {
    test(
      'retains cold invite until UI can consume it and starts once',
      () async {
        var loads = 0;
        final links = InviteLinks(
          incomingUris: const Stream.empty(),
          initialLinkLoader: () async {
            loads++;
            return invite('ABC234');
          },
        );
        await Future.wait([links.start(), links.start()]);
        expect(loads, 1);
        expect(links.pendingRoomCode, 'ABC234');
        expect(links.takePendingRoomCode(), 'ABC234');
        expect(links.takePendingRoomCode(), isNull);
        await links.dispose();
      },
    );

    test('cold and stream delivery dedupe but later taps work again', () async {
      var now = DateTime.utc(2026, 11, 5);
      final incoming = StreamController<Uri>();
      final initial = Completer<Uri?>();
      final links = InviteLinks(
        incomingUris: incoming.stream,
        initialLinkLoader: () => initial.future,
        clock: () => now,
      );
      final codes = <String>[];
      final subscription = links.roomCodes.listen(codes.add);
      final started = links.start();
      incoming.add(invite('ABC234'));
      await settle();
      initial.complete(invite('ABC234'));
      await started;
      incoming.add(invite('ABC234'));
      await settle();
      expect(codes, ['ABC234']);
      now = now.add(const Duration(seconds: 3));
      incoming.add(invite('ABC234'));
      await settle();
      expect(codes, ['ABC234', 'ABC234']);
      await subscription.cancel();
      await links.dispose();
      await incoming.close();
    });

    test('new warm invitation wins over an out-of-order cold result', () async {
      final incoming = StreamController<Uri>();
      final initial = Completer<Uri?>();
      final links = InviteLinks(
        incomingUris: incoming.stream,
        initialLinkLoader: () => initial.future,
      );
      final started = links.start();
      incoming.add(invite('DEF567'));
      await settle();
      initial.complete(invite('ABC234'));
      await started;
      expect(links.pendingRoomCode, 'DEF567');
      await links.dispose();
      await incoming.close();
    });

    test(
      'invalid links and platform errors keep manual entry available',
      () async {
        final incoming = StreamController<Uri>();
        final links = InviteLinks(
          incomingUris: incoming.stream,
          initialLinkLoader: () async => throw StateError('Unavailable'),
        );
        await links.start();
        incoming.add(Uri.parse('https://sommomemory.sommomi.cc/privacy'));
        incoming.addError(StateError('Invalid platform event'));
        incoming.add(invite('ABC234'));
        await settle();
        expect(links.takePendingRoomCode(), 'ABC234');
        await links.dispose();
        await incoming.close();
      },
    );

    test(
      'explicit web URI prefills room and disposal ignores late initial result',
      () async {
        final initial = Completer<Uri?>();
        final links = InviteLinks(
          incomingUris: const Stream.empty(),
          initialUri: invite('ABC234'),
          initialLinkLoader: () => initial.future,
        );
        final started = links.start();
        expect(links.pendingRoomCode, 'ABC234');
        await links.dispose();
        initial.complete(invite('DEF567'));
        await started;
        expect(links.pendingRoomCode, 'ABC234');
        await links.dispose();
      },
    );
  });
}
