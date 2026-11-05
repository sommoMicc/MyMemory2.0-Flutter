import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter/foundation.dart';

const _inviteHosts = {'sommomemory.sommomi.cc', 'mymemory.sommomi.cc'};
final _roomCodePattern = RegExp(r'^[A-Z2-9]{6}$');

String? _validRoomCode(String? value) {
  final code = value?.trim().toUpperCase();
  return code != null && _roomCodePattern.hasMatch(code) ? code : null;
}

/// Reads only our invitation routes; account credentials never belong in links.
String? roomCodeFromInviteUri(Uri uri) {
  try {
    return _roomCodeFromInviteUri(uri);
  } on FormatException {
    return null;
  }
}

String? _roomCodeFromInviteUri(Uri uri) {
  final scheme = uri.scheme.toLowerCase();
  if (scheme == 'sommomemory') {
    if (uri.host.toLowerCase() != 'invite' ||
        uri.userInfo.isNotEmpty ||
        uri.hasPort ||
        uri.hasQuery ||
        uri.hasFragment ||
        uri.pathSegments.length != 1) {
      return null;
    }
    final code = uri.pathSegments.single.toUpperCase();
    return _roomCodePattern.hasMatch(code) ? code : null;
  }
  if (!_inviteHosts.contains(uri.host.toLowerCase()) ||
      uri.userInfo.isNotEmpty ||
      !{'https', 'http'}.contains(scheme) ||
      (uri.hasPort && uri.port != (scheme == 'https' ? 443 : 80))) {
    return null;
  }

  final roomValues = uri.queryParametersAll['room'];
  if (roomValues != null && roomValues.length != 1) return null;
  final queryCode = _validRoomCode(roomValues?.single);
  final segments = uri.pathSegments.toList();
  if (segments.isNotEmpty && segments.last.isEmpty) segments.removeLast();
  if (segments.length == 2 && segments.first == 'invite') {
    final code = _validRoomCode(segments.last);
    if (roomValues != null && queryCode != code) return null;
    return code;
  }
  if (uri.path.isEmpty || uri.path == '/') return queryCode;
  return null;
}

String? roomCodeFromInviteString(String value) {
  final uri = Uri.tryParse(value.trim());
  return uri == null ? null : roomCodeFromInviteUri(uri);
}

Uri inviteUriForRoom(String roomCode) {
  final code = _validRoomCode(roomCode);
  if (code == null) throw ArgumentError.value(roomCode, 'roomCode');
  return Uri.https('sommomemory.sommomi.cc', '/invite/$code');
}

/// An explicit browser action may open the app; shared links remain HTTPS.
Uri inviteAppUriForRoom(String roomCode) {
  final code = _validRoomCode(roomCode);
  if (code == null) throw ArgumentError.value(roomCode, 'roomCode');
  return Uri(scheme: 'sommomemory', host: 'invite', path: '/$code');
}

/// Captures cold starts and invitations received while the app is running.
///
/// Start early. [pendingRoomCode] retains the latest invitation until the UI
/// can consume it; events do not join rooms or interrupt a current game.
class InviteLinks {
  InviteLinks({
    Stream<Uri>? incomingUris,
    Future<Uri?> Function()? initialLinkLoader,
    Uri? initialUri,
    DateTime Function()? clock,
  }) : _incomingUris = incomingUris,
       _initialLinkLoader = initialLinkLoader,
       _initialUri = initialUri,
       _clock = clock ?? DateTime.now;

  final Stream<Uri>? _incomingUris;
  final Future<Uri?> Function()? _initialLinkLoader;
  final Uri? _initialUri;
  final DateTime Function() _clock;
  final _codes = StreamController<String>.broadcast();
  StreamSubscription<Uri>? _subscription;
  Future<void>? _startFuture;
  bool _disposed = false;
  bool _receivedIncoming = false;
  String? _pendingRoomCode;
  String? _lastRoomCode;
  DateTime? _lastReceivedAt;

  Stream<String> get roomCodes => _codes.stream;
  String? get pendingRoomCode => _pendingRoomCode;

  String? takePendingRoomCode() {
    final code = _pendingRoomCode;
    _pendingRoomCode = null;
    return code;
  }

  Future<void> start() => _startFuture ??= _start();

  Future<void> _start() async {
    if (_disposed) return;
    final native =
        !kIsWeb &&
        {
          TargetPlatform.iOS,
          TargetPlatform.android,
        }.contains(defaultTargetPlatform);
    final appLinks = native ? AppLinks() : null;
    final incoming = _incomingUris ?? appLinks?.uriLinkStream;
    _subscription = incoming?.listen(
      (uri) {
        if (roomCodeFromInviteUri(uri) == null) return;
        _receivedIncoming = true;
        _receive(uri);
      },
      // A malformed platform event must not prevent manual room entry.
      onError: (Object error, StackTrace stack) {},
    );

    if (_initialUri != null) _receive(_initialUri);
    if (kIsWeb && _initialUri == null) _receive(Uri.base);
    final load =
        _initialLinkLoader ??
        (_initialUri == null ? appLinks?.getInitialLink : null);
    if (load == null) return;
    try {
      final initial = await load();
      // An asynchronous cold-start result must not replace a newer warm link.
      if (!_disposed && !_receivedIncoming && initial != null) {
        _receive(initial);
      }
    } catch (_) {
      // The invitation field and web fallback remain available.
    }
  }

  void _receive(Uri uri) {
    if (_disposed) return;
    final code = roomCodeFromInviteUri(uri);
    if (code == null) return;
    final now = _clock();
    if (code == _lastRoomCode &&
        _lastReceivedAt != null &&
        now.difference(_lastReceivedAt!) < const Duration(seconds: 2)) {
      return;
    }
    _lastRoomCode = code;
    _lastReceivedAt = now;
    _pendingRoomCode = code;
    _codes.add(code);
  }

  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    await _subscription?.cancel();
    await _codes.close();
  }
}
