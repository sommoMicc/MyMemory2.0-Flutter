/// Public account metadata. Provider tokens never enter this presentation model.
class AccountProvider {
  const AccountProvider({
    required this.id,
    this.clientId,
    this.serverClientId,
    this.redirectUri,
  });

  final String id;
  final String? clientId, serverClientId, redirectUri;
  String get label => id == 'apple' ? 'Apple' : 'Google';

  factory AccountProvider.fromJson(Map<String, dynamic> json) =>
      AccountProvider(
        id: json['id'] as String,
        clientId: json['clientId'] as String?,
        serverClientId: json['serverClientId'] as String?,
        redirectUri: json['redirectUri'] as String?,
      );
}

class AccountAttempt {
  const AccountAttempt({
    required this.id,
    required this.nonce,
    required this.state,
    required this.profileId,
    required this.expiresAt,
    this.clientId,
    this.redirectUri,
    this.contextToken,
  });

  final String id, nonce, state, profileId;
  final DateTime expiresAt;
  final String? clientId, redirectUri;
  final String? contextToken;
}

class AccountCredential {
  const AccountCredential({this.idToken, this.authorizationCode, this.state});
  final String? idToken, authorizationCode, state;
}

class AccountProfilePreview {
  AccountProfilePreview({
    required this.id,
    required this.displayName,
    required this.gems,
    required Set<String> ownedDecks,
    this.avatarId = 'fox',
    this.accentId = 'forest',
  }) : ownedDecks = Set.unmodifiable(ownedDecks);

  final String id, displayName, avatarId, accentId;
  final int gems;
  final Set<String> ownedDecks;

  factory AccountProfilePreview.fromJson(Map<String, dynamic> json) =>
      AccountProfilePreview(
        id: json['id'] as String,
        displayName: json['displayName'] as String? ?? '',
        gems: json['gems'] as int,
        ownedDecks: (json['ownedDecks'] as List).cast<String>().toSet(),
        avatarId: json['avatarId'] as String? ?? 'fox',
        accentId: json['accentId'] as String? ?? 'forest',
      );
}

class AccountSignInPreview {
  const AccountSignInPreview({
    required this.confirmationId,
    required this.profile,
    required this.action,
    required this.expiresAt,
    required this.initialProfileId,
    required this.requestId,
    this.contextToken,
  });
  final String confirmationId, action, initialProfileId, requestId;
  final String? contextToken;
  final AccountProfilePreview profile;
  final DateTime expiresAt;
  bool get switchesProfile => action == 'switch';
}

class AccountIdentity {
  const AccountIdentity({required this.provider, required this.createdAt});
  final String provider;
  final DateTime createdAt;
  factory AccountIdentity.fromJson(Map<String, dynamic> json) =>
      AccountIdentity(
        provider: json['provider'] as String,
        createdAt: accountDate(json['createdAt']),
      );
}

class AccountSession {
  const AccountSession({
    required this.id,
    required this.name,
    required this.current,
    required this.createdAt,
    required this.lastUsedAt,
  });
  final String id, name;
  final bool current;
  final DateTime createdAt, lastUsedAt;
  factory AccountSession.fromJson(Map<String, dynamic> json) => AccountSession(
    id: json['id'] as String,
    name: json['deviceName'] as String? ?? 'Dispositivo',
    current: json['current'] == true,
    createdAt: accountDate(json['createdAt']),
    lastUsedAt: accountDate(json['lastUsedAt']),
  );
}

DateTime accountDate(Object? value) => value is num
    ? DateTime.fromMillisecondsSinceEpoch(value.toInt(), isUtc: true)
    : DateTime.parse(value as String).toUtc();

/// Injectable so cancellation and identity boundaries can be tested without SDKs.
abstract interface class AccountCredentialProvider {
  Future<AccountCredential?> signIn(
    AccountProvider provider,
    AccountAttempt attempt,
  );
}

class AccountProviderException implements Exception {
  const AccountProviderException(this.message);
  final String message;
  @override
  String toString() => message;
}
