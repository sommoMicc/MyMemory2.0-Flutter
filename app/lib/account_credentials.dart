import 'package:flutter/foundation.dart';
import 'package:google_sign_in_platform_interface/google_sign_in_platform_interface.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

import 'account.dart';

class PlatformAccountCredentials implements AccountCredentialProvider {
  const PlatformAccountCredentials();

  @override
  Future<AccountCredential?> signIn(
    AccountProvider provider,
    AccountAttempt attempt,
  ) async {
    if (provider.id == 'google') {
      if (kIsWeb) {
        throw const AccountProviderException('Usa il pulsante Google.');
      }
      try {
        // The public platform interface supports configuring a fresh nonce for
        // each explicit sign-in. The higher-level singleton initializes once
        // and would reuse its initial nonce for subsequent account operations.
        final sdk = GoogleSignInPlatform.instance;
        await sdk.init(
          InitParameters(
            clientId: provider.clientId,
            serverClientId: provider.serverClientId,
            nonce: attempt.nonce,
          ),
        );
        final result = await sdk.authenticate(const AuthenticateParameters());
        final token = result.authenticationTokens.idToken;
        if (token == null || token.isEmpty) {
          throw const AccountProviderException(
            'Accesso Google non completato.',
          );
        }
        return AccountCredential(idToken: token, state: attempt.state);
      } on GoogleSignInException catch (error) {
        if (error.code == GoogleSignInExceptionCode.canceled) return null;
        // SDK error details may contain provider data; expose a fixed message.
        throw const AccountProviderException(
          'Accesso Google non disponibile. Riprova più tardi.',
        );
      }
    }
    if (provider.id != 'apple') {
      throw const AccountProviderException(
        'Metodo di accesso non disponibile.',
      );
    }
    if (kIsWeb) {
      throw const AccountProviderException('Usa il pulsante Apple.');
    }
    try {
      final useWeb = kIsWeb || defaultTargetPlatform == TargetPlatform.android;
      final clientId = attempt.clientId ?? provider.clientId;
      final redirect = attempt.redirectUri ?? provider.redirectUri;
      if (useWeb && (clientId == null || redirect == null)) {
        throw const AccountProviderException('Accesso Apple non configurato.');
      }
      final credential = await SignInWithApple.getAppleIDCredential(
        scopes: const [],
        nonce: attempt.nonce,
        state: attempt.state,
        webAuthenticationOptions: useWeb
            ? WebAuthenticationOptions(
                clientId: clientId!,
                redirectUri: Uri.parse(redirect!),
              )
            : null,
      );
      if (credential.state != null && credential.state != attempt.state) {
        throw const AccountProviderException(
          'La verifica di accesso è scaduta.',
        );
      }
      // Android's server callback returns an opaque one-use handoff in the
      // code field, rather than putting Apple's credentials into a return URL.
      return AccountCredential(
        idToken: credential.identityToken,
        authorizationCode: credential.authorizationCode,
        state: credential.state ?? attempt.state,
      );
    } on SignInWithAppleAuthorizationException catch (error) {
      if (error.code == AuthorizationErrorCode.canceled) return null;
      throw const AccountProviderException(
        'Accesso Apple non disponibile. Riprova più tardi.',
      );
    }
  }
}
