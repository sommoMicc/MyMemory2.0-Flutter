import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'decks.dart';
import 'account.dart';
import 'account_credentials.dart';
import 'arenas.dart';

class ProfileData {
  ProfileData({
    required this.id,
    required this.displayName,
    required this.activated,
    required this.gems,
    required Set<String> ownedDecks,
    required this.revision,
    this.recoveryVersion = 0,
    this.avatarId = 'fox',
    this.accentId = 'forest',
    Set<String> linkedProviders = const {},
    Set<String> legacyDecks = const {},
    bool? recoveryEnabled,
    this.crowns = 0,
    int? peakCrowns,
  }) : ownedDecks = Set.unmodifiable({...freeDecks, ...ownedDecks}),
       linkedProviders = Set.unmodifiable(linkedProviders),
       legacyDecks = Set.unmodifiable(legacyDecks),
       recoveryEnabled = recoveryEnabled ?? activated,
       peakCrowns = peakCrowns ?? crowns {
    ArenaProgress(crowns: crowns, peakCrowns: this.peakCrowns);
  }

  static const freeDecks = {'garden', 'farm', 'flora', 'paola'};
  final String id, displayName;
  final String avatarId, accentId;
  final bool activated;
  final bool recoveryEnabled;
  final int gems, revision, recoveryVersion;
  final int crowns, peakCrowns;
  final Set<String> ownedDecks, linkedProviders, legacyDecks;
  String get currentArenaId =>
      ArenaProgress(crowns: crowns, peakCrowns: peakCrowns).currentArenaId;
  Set<String> get unlockedArenaIds =>
      ArenaProgress(crowns: crowns, peakCrowns: peakCrowns).unlockedArenaIds;

  factory ProfileData.fromJson(Map<String, dynamic> json) {
    final id = json['id'], gems = json['gems'], revision = json['revision'];
    if (id is! String || gems is! int || gems < 0 || revision is! int) {
      throw const FormatException('Invalid profile');
    }
    final crowns = _profileCounter(json, 'crowns');
    final peakCrowns = _profileCounter(json, 'peakCrowns', fallback: crowns);
    ArenaProgress(crowns: crowns, peakCrowns: peakCrowns);
    final legacyDecks =
        (json['legacyDecks'] as List?)?.cast<String>().toSet() ??
        (json.containsKey('legacyDecks')
            ? <String>{}
            : <String>{'cosmos', 'ocean'});
    return ProfileData(
      id: id,
      displayName: json['displayName'] as String? ?? '',
      activated: json['activated'] == true,
      gems: gems,
      ownedDecks: {
        ...(json['ownedDecks'] as List).cast<String>(),
        ...legacyDecks,
      },
      revision: revision,
      recoveryVersion: json['recoveryVersion'] as int? ?? 0,
      recoveryEnabled: json['recoveryEnabled'] as bool?,
      linkedProviders:
          (json['linkedProviders'] as List?)?.cast<String>().toSet() ?? {},
      legacyDecks: legacyDecks,
      avatarId: json['avatarId'] as String? ?? 'fox',
      accentId: json['accentId'] as String? ?? 'forest',
      crowns: crowns,
      peakCrowns: peakCrowns,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'displayName': displayName,
    'activated': activated,
    'gems': gems,
    'ownedDecks': ownedDecks.toList(),
    'legacyDecks': legacyDecks.toList(),
    'revision': revision,
    'recoveryVersion': recoveryVersion,
    'recoveryEnabled': recoveryEnabled,
    'linkedProviders': linkedProviders.toList(),
    'avatarId': avatarId,
    'accentId': accentId,
    'crowns': crowns,
    'peakCrowns': peakCrowns,
    'currentArenaId': currentArenaId,
    'unlockedArenaIds': unlockedArenaIds.toList(),
  };

  static int _profileCounter(
    Map<String, dynamic> json,
    String key, {
    int fallback = 0,
  }) {
    if (!json.containsKey(key)) return fallback;
    final value = json[key];
    if (value is! int || value < 0) {
      throw FormatException('Invalid profile $key');
    }
    return value;
  }
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
    AccountCredentialProvider? accountCredentials,
    String? baseUrl,
  }) : _client = client ?? http.Client(),
       _secrets = secrets ?? const SecureEconomySecrets(),
       _accountCredentials =
           accountCredentials ?? const PlatformAccountCredentials(),
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
  static const _archivedIdsKey = 'profile.archivedIds.v1';
  static const _sessionEndedKey = 'profile.sessionEnded.v1';
  final SharedPreferences prefs;
  final http.Client _client;
  final EconomySecrets _secrets;
  final AccountCredentialProvider _accountCredentials;
  final Uri _base;
  ProfileData? _profile;
  String? _token, _recoveryCode;
  int? _recoveryCodeVersion;
  bool _busy = false, _offline = false, _disposed = false, _syncing = false;
  bool _sessionEnded = false;
  int _generation = 0;
  String? _lastError;
  Future<void>? _initialization;
  Future<void> _storage = Future.value();
  Future<void> _secretStorage = Future.value();
  final Map<String, Future<void>> _prefetching = {};
  final List<Map<String, dynamic>> _claims = [];
  final List<Map<String, dynamic>> _tickets = [];
  Timer? _retry;
  List<AccountProvider> _accountProviders = const [];

  ProfileData? get profile => _profile;
  int get gems => _profile?.gems ?? 0;
  Set<String> get ownedDecks => _profile?.ownedDecks ?? ProfileData.freeDecks;
  bool ownsDeck(String id) => ownedDecks.contains(id);
  bool get isSaved => _profile?.activated == true;
  bool get hasAccount => _profile?.linkedProviders.isNotEmpty == true;
  bool get sessionEnded => _sessionEnded;
  List<AccountProvider> get accountProviders => _accountProviders;
  String get accountPlatform => kIsWeb
      ? 'web'
      : switch (defaultTargetPlatform) {
          TargetPlatform.iOS => 'ios',
          TargetPlatform.android => 'android',
          _ => 'unsupported',
        };
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
      _sessionEnded = prefs.getBool(_sessionEndedKey) ?? false;
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
    String? sessionToken,
  }) async {
    if (_disposed) throw const EconomyException('Operazione annullata.');
    if (authenticated && (sessionToken ?? _token) == null) {
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
    final requestGeneration = _generation;
    final requestToken = sessionToken ?? _token;
    request.headers['Accept'] = 'application/json';
    if (authenticated) {
      request.headers['Authorization'] = 'Bearer ${sessionToken ?? _token}';
    }
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
        final code = (error is Map ? error['code'] : json['code']) as String?;
        if (code == 'PROFILE_DELETED' &&
            authenticated &&
            requestGeneration == _generation &&
            requestToken == _token) {
          await _purgeDeletedProfile();
        }
        throw EconomyException(
          (error is Map ? error['message'] : json['message']) as String? ??
              'Operazione non riuscita. Riprova.',
          retryable: response.statusCode >= 500 || response.statusCode == 429,
          code: code,
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
    final sessionEnded = _sessionEnded;
    final claims = jsonEncode(_claims), tickets = jsonEncode(_tickets);
    _storage = _storage.catchError((Object _) {}).then((_) async {
      if (profile == null) {
        await prefs.remove(_cacheKey);
      } else {
        await prefs.setString(_cacheKey, jsonEncode(profile));
      }
      await prefs.setString(_claimsKey, claims);
      await prefs.setString(_ticketsKey, tickets);
      await prefs.setBool(_sessionEndedKey, sessionEnded);
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
    _sessionEnded = false;
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
    if (_profile != null && _profile!.id != next.id) {
      await _clearProfileName(_profile!.id);
    }
    ++_generation;
    _token = token;
    _profile = next;
    _recoveryCode = recoveryCode;
    _recoveryCodeVersion = recoveryCode == null ? null : next.recoveryVersion;
    await _removeAccountArchive(next.id);
    _lastError = null;
    _offline = false;
    _sessionEnded = false;
    await _persist();
    _changed();
  }

  Future<void> sync() async {
    if (_disposed || _syncing || _busy || _sessionEnded) return;
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
    } on AccountProviderException catch (e) {
      _lastError = e.message;
      throw EconomyException(e.message);
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

  Future<void> setAppearance({String? avatarId, String? accentId}) =>
      _action(() async {
        final generation = _generation;
        await _accept(
          await _request(
            'PATCH',
            'profile',
            body: {'avatarId': ?avatarId, 'accentId': ?accentId},
          ),
          generation,
        );
      });

  Future<List<AccountProvider>> discoverAccountProviders() async {
    if (accountPlatform == 'unsupported') return const [];
    final json = await _request(
      'GET',
      'auth/providers?platform=$accountPlatform',
      authenticated: false,
    );
    _accountProviders = List.unmodifiable(
      (json['providers'] as List)
          .map(
            (value) => AccountProvider.fromJson(value as Map<String, dynamic>),
          )
          .where((provider) {
            if (!['apple', 'google'].contains(provider.id)) return false;
            if (accountPlatform == 'ios') {
              return provider.id == 'apple'
                  ? const bool.fromEnvironment('ACCOUNT_APPLE_IOS_ENABLED')
                  : const bool.fromEnvironment('ACCOUNT_GOOGLE_IOS_ENABLED');
            }
            return true;
          }),
    );
    _changed();
    return _accountProviders;
  }

  Future<AccountAttempt> _createAccountAttempt(
    AccountProvider provider,
    String operation,
  ) async {
    final profileId = _profile?.id ?? '';
    final generation = _generation;
    if (profileId.isEmpty && operation != 'login') {
      throw const EconomyException('Collegati per salvare il profilo.');
    }
    final input = {
      'provider': provider.id,
      'platform': accountPlatform,
      'operation': operation,
      'requestId': _nonce(),
    };
    String? contextToken;
    Future<void> createContext() async {
      final provisional = await _request(
        'POST',
        'profiles',
        body: {},
        authenticated: false,
      );
      contextToken = provisional['token'] as String;
    }

    if (_token == null) await createContext();
    Map<String, dynamic> json;
    try {
      json = await _request(
        'POST',
        'auth/attempts',
        body: input,
        sessionToken: contextToken,
      );
    } on EconomyException catch (error) {
      if (operation != 'login' ||
          error.code != 'INVALID_TOKEN' ||
          contextToken != null) {
        rethrow;
      }
      // Expired/revoked sessions may still hold valuable cached progress. A
      // provisional login context never replaces it before user confirmation.
      await createContext();
      json = await _request(
        'POST',
        'auth/attempts',
        body: input,
        sessionToken: contextToken,
      );
    }
    if (_disposed ||
        generation != _generation ||
        (_profile?.id ?? '') != profileId) {
      throw const EconomyException('Il profilo è cambiato. Riprova.');
    }
    return AccountAttempt(
      id: json['attemptId'] as String,
      nonce: json['nonce'] as String,
      state: json['state'] as String,
      profileId: profileId,
      expiresAt: accountDate(json['expiresAt']),
      clientId: json['clientId'] as String?,
      redirectUri: json['redirectUri'] as String?,
      contextToken: contextToken,
    );
  }

  /// The web Google SDK must render its own button after this attempt exists.
  Future<AccountAttempt> prepareAccountSignIn(
    AccountProvider provider, {
    String operation = 'login',
  }) async {
    await initialize();
    return _createAccountAttempt(provider, operation);
  }

  Future<AccountSignInPreview> _exchangeAccountCredential(
    AccountAttempt attempt,
    AccountCredential credential,
  ) async {
    if ((_profile?.id ?? '') != attempt.profileId ||
        !attempt.expiresAt.isAfter(DateTime.now())) {
      throw const EconomyException(
        'La verifica di accesso è scaduta. Riprova.',
      );
    }
    final json = await _request(
      'POST',
      'auth/exchange',
      body: {
        'attemptId': attempt.id,
        'idToken': ?credential.idToken,
        'authorizationCode': ?credential.authorizationCode,
        'state': ?credential.state,
      },
      sessionToken: attempt.contextToken,
    );
    return AccountSignInPreview(
      confirmationId: json['confirmationId'] as String,
      profile: AccountProfilePreview.fromJson(
        json['profile'] as Map<String, dynamic>,
      ),
      action:
          attempt.contextToken != null &&
              (json['profile'] as Map)['id'] != _profile?.id
          ? 'switch'
          : json['action'] as String,
      expiresAt: accountDate(json['expiresAt']),
      initialProfileId: attempt.profileId,
      requestId: _nonce(),
      contextToken: attempt.contextToken,
    );
  }

  Future<AccountSignInPreview> exchangeAccountCredential(
    AccountAttempt attempt,
    AccountCredential credential,
  ) => _action(() => _exchangeAccountCredential(attempt, credential));

  Future<AccountSignInPreview?> beginAccountSignIn(
    AccountProvider provider, {
    String operation = 'login',
  }) => _action(() async {
    final attempt = await _createAccountAttempt(provider, operation);
    final credential = await _accountCredentials.signIn(provider, attempt);
    if (credential == null) return null;
    return _exchangeAccountCredential(attempt, credential);
  });

  Future<void> confirmAccountSignIn(AccountSignInPreview preview) async {
    // Give pending rewards a chance to finish before changing their owner scope.
    if (preview.switchesProfile) await sync();
    return _action(() async {
      if ((_profile?.id ?? '') != preview.initialProfileId ||
          !preview.expiresAt.isAfter(DateTime.now())) {
        throw const EconomyException(
          'La verifica di accesso è scaduta. Riprova.',
        );
      }
      if (preview.switchesProfile) await _archiveCurrentAccount();
      final generation = _generation;
      final json = await _request(
        'POST',
        'auth/confirm',
        body: {
          'confirmationId': preview.confirmationId,
          'confirmReplace': true,
          'requestId': preview.requestId,
        },
        sessionToken: preview.contextToken,
      );
      if (generation != _generation || _disposed) return;
      if (json['token'] != null || preview.contextToken != null) {
        final nextId = (json['profile'] as Map)['id'];
        await _install({
          ...json,
          'token': json['token'] ?? preview.contextToken,
        }, recoveryCode: nextId == _profile?.id ? _recoveryCode : null);
      } else {
        await _accept(json, generation);
      }
    });
  }

  Future<void> reauthenticateWithRecovery(String code) => _action(() async {
    await _request(
      'POST',
      'auth/reauth/recovery',
      body: {'recoveryCode': code.trim()},
    );
  });

  Future<List<AccountIdentity>> listAccountIdentities() => _action(() async {
    final json = await _request('GET', 'profile/identities');
    return (json['identities'] as List)
        .map((value) => AccountIdentity.fromJson(value as Map<String, dynamic>))
        .toList(growable: false);
  });

  Future<List<AccountSession>> listAccountSessions() => _action(() async {
    final json = await _request('GET', 'profile/sessions');
    return (json['sessions'] as List)
        .map((value) => AccountSession.fromJson(value as Map<String, dynamic>))
        .toList(growable: false);
  });

  Future<void> revokeAccountSession(String id) => _action(() async {
    final result = await _request(
      'DELETE',
      'profile/sessions/${Uri.encodeComponent(id)}',
      body: {},
    );
    if (result['loggedOut'] == true || result['current'] == true) {
      await _clearSession();
    }
  });

  Future<void> unlinkAccountProvider(String provider) => _action(() async {
    final generation = _generation;
    final result = await _request(
      'DELETE',
      'profile/identities/${Uri.encodeComponent(provider)}',
      body: {},
    );
    if (result['profile'] != null) {
      await _accept(result, generation);
    } else {
      await _accept(await _request('GET', 'profile'), generation);
    }
  });

  Future<void> _archiveCurrentAccount() async {
    final current = _profile;
    if (current == null || _token == null) return;
    await _writeSecret(
      'profile.archive.${current.id}',
      jsonEncode({
        'token': _token,
        'profile': current.toJson(),
        'recoveryCode': ?_recoveryCode,
        'recoveryVersion': ?_recoveryCodeVersion,
      }),
    );
    final ids = {...?prefs.getStringList(_archivedIdsKey), current.id};
    await prefs.setStringList(_archivedIdsKey, ids.toList());
  }

  Future<List<AccountProfilePreview>> archivedAccountProfiles() async {
    final result = <AccountProfilePreview>[];
    for (final id in prefs.getStringList(_archivedIdsKey) ?? <String>[]) {
      if (id == _profile?.id) continue;
      final raw = await _secrets.read('profile.archive.$id');
      if (raw == null) continue;
      try {
        final json = jsonDecode(raw) as Map<String, dynamic>;
        result.add(
          AccountProfilePreview.fromJson(
            json['profile'] as Map<String, dynamic>,
          ),
        );
      } catch (_) {
        // An unrelated damaged archive must not block the active profile.
      }
    }
    return result;
  }

  Future<void> _removeAccountArchive(String id) async {
    final ids = prefs.getStringList(_archivedIdsKey) ?? <String>[];
    if (!ids.contains(id)) return;
    await _deleteSecret('profile.archive.$id');
    await prefs.setStringList(
      _archivedIdsKey,
      ids.where((value) => value != id).toList(),
    );
  }

  Future<void> restoreArchivedAccount(String id) async {
    await sync();
    return _action(() async {
      final raw = await _secrets.read('profile.archive.$id');
      if (raw == null) throw const EconomyException('Profilo non disponibile.');
      final saved = jsonDecode(raw) as Map<String, dynamic>;
      final token = saved['token'] as String;
      Map<String, dynamic> json;
      try {
        json = await _request('GET', 'profile', sessionToken: token);
      } on EconomyException catch (error) {
        if (error.code == 'PROFILE_DELETED') {
          await _removeAccountArchive(id);
          await _deleteSecret('profile.recovery.$id');
          await _clearProfileName(id, allowUnscoped: false);
          _claims.removeWhere((value) => value['profileId'] == id);
          _tickets.removeWhere((value) => value['profileId'] == id);
          await _persist();
        }
        rethrow;
      }
      if ((json['profile'] as Map)['id'] != id) {
        throw const EconomyException('Profilo non disponibile.');
      }
      await _archiveCurrentAccount();
      await _install(
        {...json, 'token': token},
        recoveryCode:
            saved['recoveryVersion'] ==
                (json['profile'] as Map)['recoveryVersion']
            ? saved['recoveryCode'] as String?
            : null,
      );
    });
  }

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
    if ((json['profile'] as Map)['id'] != _profile?.id) {
      await _archiveCurrentAccount();
    }
    await _install(json, recoveryCode: normalized);
  });

  Future<void> logout() => _action(() async {
    // Revoke the actual server session before discarding the local credential.
    if (_token != null) {
      try {
        await _request('POST', 'profile/logout', body: {});
      } on EconomyException catch (error) {
        if (!['INVALID_TOKEN', 'PROFILE_DELETED'].contains(error.code)) rethrow;
      }
    }
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
    await _clearSession(ended: true);
  });

  Future<void> _purgeDeletedProfile() async {
    final id = _profile?.id;
    if (id != null) {
      await _deleteSecret('profile.recovery.$id');
      _claims.removeWhere((value) => value['profileId'] == id);
      _tickets.removeWhere((value) => value['profileId'] == id);
    }
    await _clearSession(ended: true);
  }

  Future<void> startGuestProfile() async {
    await initialize();
    if (_busy || _syncing) {
      throw const EconomyException('Attendi la sincronizzazione in corso.');
    }
    _sessionEnded = false;
    await _persist();
    await sync();
  }

  Future<void> _clearSession({bool ended = false}) async {
    final id = _profile?.id;
    if (id != null) await _removeAccountArchive(id);
    await _clearProfileName(id);
    await _deleteSecret(_sessionKey);
    ++_generation;
    _token = null;
    _profile = null;
    _recoveryCode = null;
    _recoveryCodeVersion = null;
    _sessionEnded = ended;
    _lastError = null;
    await _persist();
    // Creating a new guest remains an explicit UI action/next reconnect.
    _changed();
  }

  Future<void> _clearProfileName(
    String? id, {
    bool allowUnscoped = true,
  }) async {
    final owner = prefs.getString('name.localProfile');
    if ((owner == null && allowUnscoped) || (id != null && owner == id)) {
      await prefs.remove('name');
      await prefs.remove('name.localProfile');
      await prefs.remove('name.localPending');
    }
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
