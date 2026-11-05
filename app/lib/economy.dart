import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'decks.dart';

class ProfileData {
  ProfileData({
    required this.id,
    required this.displayName,
    required this.activated,
    required this.gems,
    required Set<String> ownedDecks,
    required this.revision,
    this.recoveryVersion = 0,
  }) : ownedDecks = Set.unmodifiable({...freeDecks, ...ownedDecks});

  static const freeDecks = {'garden', 'cosmos', 'ocean', 'paola'};
  final String id, displayName;
  final bool activated;
  final int gems, revision, recoveryVersion;
  final Set<String> ownedDecks;

  factory ProfileData.fromJson(Map<String, dynamic> json) {
    final id = json['id'], gems = json['gems'], revision = json['revision'];
    if (id is! String || gems is! int || gems < 0 || revision is! int) {
      throw const FormatException('Invalid profile');
    }
    return ProfileData(
      id: id,
      displayName: json['displayName'] as String? ?? '',
      activated: json['activated'] == true,
      gems: gems,
      ownedDecks: (json['ownedDecks'] as List).cast<String>().toSet(),
      revision: revision,
      recoveryVersion: json['recoveryVersion'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'displayName': displayName,
    'activated': activated,
    'gems': gems,
    'ownedDecks': ownedDecks.toList(),
    'revision': revision,
    'recoveryVersion': recoveryVersion,
  };
}

class GameTicket {
  GameTicket({
    required this.id,
    required this.mode,
    required this.theme,
    required this.pairs,
    required List<int> board,
    required this.expiresAt,
    this.guestClaimToken,
  }) : board = List.unmodifiable(board);

  final String id, mode, theme;
  final int pairs;
  final List<int> board;
  final DateTime expiresAt;
  final String? guestClaimToken;

  factory GameTicket.fromJson(
    Map<String, dynamic> json, {
    String? mode,
    String? theme,
    int? pairs,
  }) => GameTicket(
    id: json['id'] as String,
    mode: json['mode'] as String? ?? mode!,
    theme: json['theme'] as String? ?? theme!,
    pairs: json['pairs'] as int? ?? pairs!,
    board: (json['board'] as List).map((value) => int.parse('$value')).toList(),
    expiresAt: json['expiresAt'] is num
        ? DateTime.fromMillisecondsSinceEpoch(
            (json['expiresAt'] as num).toInt(),
            isUtc: true,
          )
        : DateTime.parse(json['expiresAt'] as String),
    guestClaimToken: json['guestClaimToken'] as String?,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'mode': mode,
    'theme': theme,
    'pairs': pairs,
    'board': board,
    'expiresAt': expiresAt.toUtc().toIso8601String(),
    if (guestClaimToken != null) 'guestClaimToken': guestClaimToken,
  };
}

class RewardResult {
  const RewardResult({required this.gems, required this.granted});
  final int gems;
  final bool granted;
}

class UnlockResult {
  const UnlockResult({required this.unlocked, required this.alreadyOwned});
  final bool unlocked, alreadyOwned;
}

class EconomyException implements Exception {
  const EconomyException(this.message, {this.retryable = false, this.code});
  final String message;
  final bool retryable;
  final String? code;
  @override
  String toString() => message;
}

/// A credential store is injectable for tests; production uses platform secrets.
abstract interface class EconomySecrets {
  Future<String?> read(String key);
  Future<void> write(String key, String value);
  Future<void> delete(String key);
}

class SecureEconomySecrets implements EconomySecrets {
  const SecureEconomySecrets([this.storage = const FlutterSecureStorage()]);
  final FlutterSecureStorage storage;
  @override
  Future<String?> read(String key) => storage.read(key: key);
  @override
  Future<void> write(String key, String value) =>
      storage.write(key: key, value: value);
  @override
  Future<void> delete(String key) => storage.delete(key: key);
}

/// The displayed wallet is a cached server snapshot, never a local counter.
/// Only replay-safe game proofs are queued offline; profile credentials are not.
class EconomyController extends ChangeNotifier {
  EconomyController({
    required this.prefs,
    http.Client? client,
    EconomySecrets? secrets,
    String? baseUrl,
  }) : _client = client ?? http.Client(),
       _secrets = secrets ?? const SecureEconomySecrets(),
       _base = Uri.parse(
         baseUrl ??
             const String.fromEnvironment(
               'PROFILE_API_URL',
               defaultValue: 'https://sommomemory.sommomi.cc/api/v1',
             ),
       );

  static const _sessionKey = 'sommomemory.profile.session.v1';
  static const _cacheKey = 'profile.cache.v1';
  static const _claimsKey = 'profile.claims.v1';
  static const _ticketsKey = 'profile.tickets.v1';
  final SharedPreferences prefs;
  final http.Client _client;
  final EconomySecrets _secrets;
  final Uri _base;
  ProfileData? _profile;
  String? _token, _recoveryCode;
  int? _recoveryCodeVersion;
  bool _busy = false, _offline = false, _disposed = false, _syncing = false;
  int _generation = 0;
  String? _lastError;
  Future<void>? _initialization;
  Future<void> _storage = Future.value();
  Future<void> _secretStorage = Future.value();
  final Map<String, Future<void>> _prefetching = {};
  final List<Map<String, dynamic>> _claims = [];
  final List<Map<String, dynamic>> _tickets = [];
  Timer? _retry;

  ProfileData? get profile => _profile;
  int get gems => _profile?.gems ?? 0;
  Set<String> get ownedDecks => _profile?.ownedDecks ?? ProfileData.freeDecks;
  bool ownsDeck(String id) => ownedDecks.contains(id);
  bool get isSaved => _profile?.activated == true;
  bool get busy => _busy;
  bool get offline => _offline;
  String? get lastError => _lastError;
  String? get profileToken => _token;
  int get pendingRewards =>
      _claims.where((c) => c['profileId'] == _profile?.id).length;

  void _changed() {
    if (!_disposed) notifyListeners();
  }

  String _nonce() => base64UrlEncode(
    List.generate(18, (_) => Random.secure().nextInt(256)),
  ).replaceAll('=', '');

  Future<void> initialize() => _initialization ??= _initialize();
  Future<void> _initialize() async {
    try {
      final session = await _secrets.read(_sessionKey);
      if (_disposed) return;
      if (session != null) {
        final json = jsonDecode(session) as Map<String, dynamic>;
        _token = json['token'] as String;
        final cache = prefs.getString(_cacheKey);
        if (cache != null) {
          try {
            final cached = ProfileData.fromJson(
              jsonDecode(cache) as Map<String, dynamic>,
            );
            if (cached.id == json['profileId']) _profile = cached;
          } catch (_) {
            // A lost or corrupt presentation cache cannot invalidate Keychain.
          }
        }
        _recoveryCode = json['recoveryCode'] as String?;
        _recoveryCodeVersion = json['recoveryVersion'] as int?;
        if (_profile != null &&
            _recoveryCodeVersion != _profile!.recoveryVersion) {
          _recoveryCode = null;
          _recoveryCodeVersion = null;
        }
      }
      _loadList(_claimsKey, _claims);
      _loadList(_ticketsKey, _tickets);
      _changed();
      await sync();
    } catch (_) {
      _lastError =
          'Impossibile aprire il profilo salvato. Puoi usare il codice di recupero.';
      _changed();
    }
    if (!_disposed) {
      _retry = Timer.periodic(const Duration(seconds: 30), (_) {
        if (!_busy) unawaited(sync());
      });
    }
  }

  void _loadList(String key, List<Map<String, dynamic>> target) {
    try {
      final raw = prefs.getString(key);
      if (raw != null) {
        target.addAll(
          (jsonDecode(raw) as List)
              .take(256)
              .map((e) => Map<String, dynamic>.from(e as Map)),
        );
      }
    } catch (_) {
      /* A damaged noncredential cache must not block profile recovery. */
    }
  }

  Future<Map<String, dynamic>> _request(
    String method,
    String path, {
    Map<String, dynamic>? body,
    bool authenticated = true,
  }) async {
    if (_disposed) throw const EconomyException('Operazione annullata.');
    if (authenticated && _token == null) {
      throw const EconomyException(
        'Collegati per attivare il profilo e le gemme.',
      );
    }
    final uri = Uri.parse(
      '${_base.toString().replaceFirst(RegExp(r'/$'), '')}/$path',
    );
    if (uri.origin != _base.origin ||
        !['https', 'http'].contains(uri.scheme) ||
        (uri.scheme == 'http' &&
            !['localhost', '127.0.0.1'].contains(uri.host))) {
      throw const EconomyException('Indirizzo del servizio non valido.');
    }
    final request = http.Request(method, uri)..followRedirects = false;
    request.headers['Accept'] = 'application/json';
    if (authenticated) request.headers['Authorization'] = 'Bearer $_token';
    if (body != null) {
      request.headers['Content-Type'] = 'application/json';
      request.body = jsonEncode(body);
    }
    try {
      final response = await _client
          .send(request)
          .timeout(const Duration(seconds: 12));
      var length = 0;
      final bytes = <int>[];
      await for (final chunk in response.stream.timeout(
        const Duration(seconds: 12),
      )) {
        length += chunk.length;
        if (length > 128 * 1024) {
          throw const FormatException('Response too large');
        }
        bytes.addAll(chunk);
      }
      final json = jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>;
      if (response.statusCode < 200 || response.statusCode >= 300) {
        final error = json['error'];
        throw EconomyException(
          (error is Map ? error['message'] : json['message']) as String? ??
              'Operazione non riuscita. Riprova.',
          retryable: response.statusCode >= 500 || response.statusCode == 429,
          code: (error is Map ? error['code'] : json['code']) as String?,
        );
      }
      return json;
    } on EconomyException {
      rethrow;
    } catch (_) {
      throw const EconomyException(
        'Sei offline. Il profilo si sincronizzerà alla riconnessione.',
        retryable: true,
      );
    }
  }

  Future<void> _writeSecret(String key, String value) {
    _secretStorage = _secretStorage
        .catchError((Object _) {})
        .then((_) => _secrets.write(key, value));
    return _secretStorage;
  }

  Future<void> _deleteSecret(String key) {
    _secretStorage = _secretStorage
        .catchError((Object _) {})
        .then((_) => _secrets.delete(key));
    return _secretStorage;
  }

  Future<void> _persist() {
    final profile = _profile?.toJson();
    final claims = jsonEncode(_claims), tickets = jsonEncode(_tickets);
    _storage = _storage.catchError((Object _) {}).then((_) async {
      if (profile == null) {
        await prefs.remove(_cacheKey);
      } else {
        await prefs.setString(_cacheKey, jsonEncode(profile));
      }
      await prefs.setString(_claimsKey, claims);
      await prefs.setString(_ticketsKey, tickets);
    });
    return _storage;
  }

  Future<void> _accept(Map<String, dynamic> json, int generation) async {
    final next = ProfileData.fromJson(json['profile'] as Map<String, dynamic>);
    if (_disposed ||
        generation != _generation ||
        (_profile != null && next.id != _profile!.id) ||
        (_profile != null && next.revision < _profile!.revision)) {
      return;
    }
    _profile = next;
    if (_recoveryCode != null && _recoveryCodeVersion != next.recoveryVersion) {
      _recoveryCode = null;
      _recoveryCodeVersion = null;
      await _writeSecret(
        _sessionKey,
        jsonEncode({'token': _token, 'profileId': next.id}),
      );
    }
    _offline = false;
    _lastError = null;
    await _persist();
    _changed();
  }

  Future<void> _install(
    Map<String, dynamic> json, {
    String? recoveryCode,
  }) async {
    final next = ProfileData.fromJson(json['profile'] as Map<String, dynamic>);
    final token = json['token'];
    if (token is! String || token.length < 24) {
      throw const FormatException('Invalid session');
    }
    await _writeSecret(
      _sessionKey,
      jsonEncode({
        'token': token,
        'profileId': next.id,
        'recoveryCode': ?recoveryCode,
        if (recoveryCode != null) 'recoveryVersion': next.recoveryVersion,
      }),
    );
    ++_generation;
    _token = token;
    _profile = next;
    _recoveryCode = recoveryCode;
    _recoveryCodeVersion = recoveryCode == null ? null : next.recoveryVersion;
    _lastError = null;
    _offline = false;
    await _persist();
    _changed();
  }

  Future<void> sync() async {
    if (_disposed || _syncing || _busy) return;
    _syncing = true;
    final generation = _generation;
    try {
      if (_token == null) {
        final created = await _request(
          'POST',
          'profiles',
          body: {},
          authenticated: false,
        );
        if (_disposed || generation != _generation) return;
        await _install(created);
      } else {
        final json = await _request('GET', 'profile');
        await _accept(json, generation);
      }
      if (_disposed) return;
      final current = _generation;
      for (final claim in List<Map<String, dynamic>>.from(_claims)) {
        if (claim['profileId'] != _profile?.id) continue;
        try {
          final json = await _request(
            'POST',
            'games/claims',
            body: Map<String, dynamic>.from(claim)..remove('profileId'),
          );
          if (current != _generation) return;
          await _accept(json, current);
          _claims.removeWhere((c) => c['requestId'] == claim['requestId']);
          await _persist();
        } on EconomyException catch (e) {
          if (e.retryable) rethrow;
          if (current != _generation) return;
          // Expired, deleted or invalid proofs are never converted into local gems.
          _claims.removeWhere((c) => c['requestId'] == claim['requestId']);
          _lastError = e.message;
          await _persist();
        }
      }
    } on EconomyException catch (e) {
      _offline = e.retryable;
      _lastError = e.message;
    } catch (_) {
      _lastError =
          'Il profilo non è disponibile. Riprova o usa il codice di recupero.';
    } finally {
      _syncing = false;
      _changed();
    }
  }

  Future<void> refresh() => sync();

  Future<T> _action<T>(Future<T> Function() work) async {
    await initialize();
    if (_busy || _syncing) {
      throw const EconomyException('Attendi la sincronizzazione in corso.');
    }
    _busy = true;
    _lastError = null;
    _changed();
    try {
      return await work();
    } on EconomyException catch (e) {
      _lastError = e.message;
      _offline = e.retryable;
      rethrow;
    } catch (_) {
      _lastError =
          'Operazione non riuscita. Il profilo precedente è conservato.';
      throw EconomyException(_lastError!);
    } finally {
      _busy = false;
      _changed();
    }
  }

  Future<void> setDisplayName(String name) => _action(() async {
    final generation = _generation;
    await _accept(
      await _request('PATCH', 'profile', body: {'displayName': name.trim()}),
      generation,
    );
  });

  Future<UnlockResult> unlockDeck(String deckId) => _action(() async {
    if (!deckPrices.containsKey(deckId)) {
      throw const EconomyException('Collezione non valida.');
    }
    final generation = _generation;
    final json = await _request(
      'POST',
      'wallet/unlock',
      body: {'deckId': deckId, 'requestId': _nonce()},
    );
    await _accept(json, generation);
    return UnlockResult(
      unlocked: json['unlocked'] == true,
      alreadyOwned: json['alreadyOwned'] == true,
    );
  });

  Future<String> activateRecovery({String? displayName}) => _action(() async {
    if (_recoveryCode != null) return _recoveryCode!;
    if (isSaved) {
      throw const EconomyException(
        'Il codice originale non è su questo dispositivo. Puoi generarne uno nuovo da Gestisci.',
      );
    }
    final generation = _generation;
    final json = await _request(
      'POST',
      'profile/recovery',
      body: {'displayName': ?displayName},
    );
    final code = json['recoveryCode'] as String;
    if (generation != _generation) {
      throw const EconomyException('Il profilo è cambiato.');
    }
    final version =
        (json['profile'] as Map<String, dynamic>)['recoveryVersion'] as int? ??
        0;
    await _writeSecret(
      _sessionKey,
      jsonEncode({
        'token': _token,
        'profileId': _profile!.id,
        'recoveryCode': code,
        'recoveryVersion': version,
      }),
    );
    _recoveryCode = code;
    _recoveryCodeVersion = version;
    await _accept(json, generation);
    return code;
  });

  Future<String> rotateRecovery() => _action(() async {
    final generation = _generation;
    final json = await _request('POST', 'profile/recovery/rotate', body: {});
    final code = json['recoveryCode'] as String;
    if (generation != _generation) {
      throw const EconomyException('Il profilo è cambiato.');
    }
    final version =
        (json['profile'] as Map<String, dynamic>)['recoveryVersion'] as int? ??
        0;
    await _writeSecret(
      _sessionKey,
      jsonEncode({
        'token': _token,
        'profileId': _profile!.id,
        'recoveryCode': code,
        'recoveryVersion': version,
      }),
    );
    _recoveryCode = code;
    _recoveryCodeVersion = version;
    await _accept(json, generation);
    return code;
  });

  Future<ProfileData> previewRecovery(String code) => _action(() async {
    final json = await _request(
      'POST',
      'profiles/restore/preview',
      body: {'recoveryCode': code.trim()},
      authenticated: false,
    );
    return ProfileData.fromJson(json['profile'] as Map<String, dynamic>);
  });

  Future<void> restoreRecovery(String code) => _action(() async {
    final normalized = code.trim();
    final json = await _request(
      'POST',
      'profiles/restore',
      body: {'recoveryCode': normalized, 'confirmReplace': true},
      authenticated: false,
    );
    await _install(json, recoveryCode: normalized);
  });

  Future<void> logout() => _action(() async {
    // Revoke the actual server session before discarding the local credential.
    await _request('POST', 'profile/logout', body: {});
    await _clearSession();
  });

  Future<void> deleteProfile() => _action(() async {
    await _request('DELETE', 'profile', body: {'confirmDelete': true});
    final id = _profile?.id;
    if (id != null) {
      await _deleteSecret('profile.recovery.$id');
      _claims.removeWhere((c) => c['profileId'] == id);
      _tickets.removeWhere((c) => c['profileId'] == id);
    }
    await _clearSession();
  });

  Future<void> _clearSession() async {
    await _deleteSecret(_sessionKey);
    ++_generation;
    _token = null;
    _profile = null;
    _recoveryCode = null;
    _recoveryCodeVersion = null;
    _lastError = null;
    await _persist();
    // Creating a new guest remains an explicit UI action/next reconnect.
    _changed();
  }

  Future<GameTicket?> takeTicket({
    required String mode,
    required int pairs,
    required String theme,
  }) async {
    await initialize();
    final sessionGeneration = _generation;
    _tickets.removeWhere(
      (e) =>
          DateTime.tryParse('${e['expiresAt']}')?.isAfter(DateTime.now()) !=
          true,
    );
    final index = _tickets.indexWhere(
      (e) =>
          e['profileId'] == _profile?.id &&
          e['mode'] == mode &&
          e['pairs'] == pairs &&
          e['theme'] == theme,
    );
    if (index >= 0) {
      final json = _tickets.removeAt(index);
      await _persist();
      if (_disposed || sessionGeneration != _generation) return null;
      unawaited(prefetchTicket(mode: mode, pairs: pairs, theme: theme));
      return GameTicket.fromJson(json);
    }
    if (_token == null || !ownsDeck(theme)) return null;
    final generation = _generation;
    try {
      final json = await _request(
        'POST',
        'games/tickets',
        body: {
          'mode': mode,
          'pairs': pairs,
          'theme': theme,
          'requestId': _nonce(),
        },
      );
      if (generation != _generation) return null;
      _offline = false;
      return GameTicket.fromJson(
        json['ticket'] as Map<String, dynamic>,
        mode: mode,
        pairs: pairs,
        theme: theme,
      );
    } on EconomyException catch (e) {
      if (_disposed || generation != _generation) return null;
      _offline = e.retryable;
      _lastError = e.message;
      _changed();
      return null;
    }
  }

  Future<void> prefetchTicket({
    required String mode,
    required int pairs,
    required String theme,
  }) {
    final key = '$mode:$pairs:$theme';
    return _prefetching[key] ??=
        _prefetch(mode: mode, pairs: pairs, theme: theme).whenComplete(() {
          _prefetching.remove(key);
        });
  }

  Future<void> _prefetch({
    required String mode,
    required int pairs,
    required String theme,
  }) async {
    if (_disposed || _token == null || _profile == null || !ownsDeck(theme)) {
      return;
    }
    final generation = _generation, profileId = _profile!.id;
    try {
      for (var i = 0; i < 2; i++) {
        final count = _tickets
            .where(
              (e) =>
                  e['profileId'] == profileId &&
                  e['mode'] == mode &&
                  e['pairs'] == pairs &&
                  e['theme'] == theme &&
                  DateTime.parse(
                    e['expiresAt'] as String,
                  ).isAfter(DateTime.now()),
            )
            .length;
        if (count >= 2 || _tickets.length >= 128) break;
        final json = await _request(
          'POST',
          'games/tickets',
          body: {
            'mode': mode,
            'pairs': pairs,
            'theme': theme,
            'requestId': _nonce(),
          },
        );
        if (generation != _generation || _disposed) return;
        final ticket = GameTicket.fromJson(
          json['ticket'] as Map<String, dynamic>,
          mode: mode,
          pairs: pairs,
          theme: theme,
        );
        _tickets.add({...ticket.toJson(), 'profileId': profileId});
        await _persist();
      }
    } catch (_) {
      /* Cached decks and the free game always remain available. */
    }
  }

  Future<RewardResult?> claimGame({
    required GameTicket ticket,
    required List<int> moves,
  }) => claimProof(ticketId: ticket.id, moves: moves);

  Future<RewardResult?> claimProof({
    required String ticketId,
    required List<int> moves,
    String? guestClaimToken,
  }) async {
    final profileId = _profile?.id;
    final generation = _generation;
    if (profileId == null || moves.isEmpty || moves.length > 4000) return null;
    final existing = _claims.where(
      (c) => c['profileId'] == profileId && c['ticketId'] == ticketId,
    );
    final claim = existing.isNotEmpty
        ? existing.first
        : <String, dynamic>{
            'profileId': profileId,
            'ticketId': ticketId,
            'moves': List<int>.from(moves),
            'requestId': _nonce(),
            'guestClaimToken': ?guestClaimToken,
          };
    if (existing.isEmpty) {
      if (_claims.length >= 128) return null;
      _claims.add(claim);
      await _persist();
    }
    if (_disposed || generation != _generation || profileId != _profile?.id) {
      return null;
    }
    try {
      final json = await _request(
        'POST',
        'games/claims',
        body: Map<String, dynamic>.from(claim)..remove('profileId'),
      );
      if (generation != _generation) return null;
      await _accept(json, generation);
      _claims.removeWhere((c) => c['requestId'] == claim['requestId']);
      await _persist();
      final reward = json['reward'] as Map<String, dynamic>;
      return RewardResult(
        gems: reward['gems'] as int? ?? 0,
        granted: reward['granted'] == true,
      );
    } on EconomyException catch (e) {
      if (_disposed || generation != _generation) return null;
      if (!e.retryable && generation == _generation) {
        _claims.removeWhere((c) => c['requestId'] == claim['requestId']);
        await _persist();
      }
      _offline = e.retryable;
      _lastError = e.message;
      _changed();
      return null;
    }
  }

  @override
  void dispose() {
    _disposed = true;
    ++_generation;
    _retry?.cancel();
    _client.close();
    super.dispose();
  }
}
