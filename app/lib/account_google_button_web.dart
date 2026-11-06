import 'l10n/app_strings.dart';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_sign_in_platform_interface/google_sign_in_platform_interface.dart';
import 'package:google_sign_in_web/google_sign_in_web.dart';

import 'account.dart';
import 'economy.dart';

/// An official GIS button bound to one server-generated attempt and nonce.
/// Each independent plugin instance is initialized once, avoiding nonce reuse.
class AccountGoogleWebButton extends StatefulWidget {
  const AccountGoogleWebButton({
    super.key,
    required this.economy,
    required this.provider,
    required this.onPreview,
    required this.onError,
    this.operation = 'login',
    this.enabled = true,
    this.width,
  });
  final EconomyController economy;
  final AccountProvider provider;
  final ValueChanged<AccountSignInPreview> onPreview;
  final ValueChanged<Object> onError;
  final String operation;
  final bool enabled;
  final double? width;
  @override
  State<AccountGoogleWebButton> createState() => _AccountGoogleWebButtonState();
}

class _AccountGoogleWebButtonState extends State<AccountGoogleWebButton> {
  GoogleSignInPlugin? _plugin;
  AccountAttempt? _attempt;
  StreamSubscription<AuthenticationEvent>? _events;
  int _generation = 0;
  bool _failed = false, _used = false, _processing = false;

  @override
  void initState() {
    super.initState();
    unawaited(_prepare());
  }

  @override
  void didUpdateWidget(AccountGoogleWebButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.operation != widget.operation ||
        oldWidget.provider.clientId != widget.provider.clientId ||
        oldWidget.economy != widget.economy ||
        (_attempt != null &&
            _attempt!.profileId != (widget.economy.profile?.id ?? ''))) {
      unawaited(_prepare());
    }
  }

  Future<void> _prepare() async {
    final generation = ++_generation;
    await _events?.cancel();
    if (!mounted) return;
    setState(() {
      _plugin = null;
      _attempt = null;
      _failed = false;
      _used = false;
      _processing = false;
    });
    try {
      final attempt = await widget.economy.prepareAccountSignIn(
        widget.provider,
        operation: widget.operation,
      );
      if (!mounted || generation != _generation) return;
      final plugin = GoogleSignInPlugin();
      await plugin.init(
        InitParameters(
          clientId: widget.provider.clientId,
          nonce: attempt.nonce,
        ),
      );
      if (!mounted || generation != _generation) return;
      _events = plugin.authenticationEvents.listen(
        (event) {
          if (event is AuthenticationEventSignIn) {
            unawaited(_signedIn(event, generation));
          }
        },
        onError: (Object _) {
          if (!mounted || generation != _generation) return;
          setState(() => _failed = true);
          widget.onError(
            const EconomyException('Accesso Google non completato.'),
          );
        },
      );
      setState(() {
        _plugin = plugin;
        _attempt = attempt;
      });
    } catch (error) {
      if (!mounted || generation != _generation) return;
      setState(() => _failed = true);
      widget.onError(error);
    }
  }

  Future<void> _signedIn(
    AuthenticationEventSignIn event,
    int generation,
  ) async {
    if (!mounted || generation != _generation || _used || !widget.enabled) {
      return;
    }
    final attempt = _attempt;
    final idToken = event.authenticationTokens.idToken;
    if (attempt == null || idToken == null) return;
    setState(() {
      _used = true;
      _processing = true;
    });
    try {
      final preview = await widget.economy.exchangeAccountCredential(
        attempt,
        AccountCredential(idToken: idToken, state: attempt.state),
      );
      if (mounted && generation == _generation) widget.onPreview(preview);
    } catch (error) {
      if (mounted && generation == _generation) widget.onError(error);
    } finally {
      if (mounted && generation == _generation) {
        setState(() => _processing = false);
      }
    }
  }

  @override
  void dispose() {
    ++_generation;
    unawaited(_events?.cancel());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_failed || (_used && !_processing)) {
      return TextButton.icon(
        onPressed: widget.enabled ? _prepare : null,
        icon: const Icon(Icons.refresh_rounded),
        label: Text(tr(context, 'Accedi con Google')),
      );
    }
    if (_plugin == null || _processing) {
      return const SizedBox(
        height: 44,
        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
      );
    }
    return IgnorePointer(
      ignoring: !widget.enabled,
      child: SizedBox(
        height: 44,
        width: widget.width ?? 280,
        child: _plugin!.renderButton(
          configuration: GSIButtonConfiguration(
            locale: Localizations.localeOf(context).languageCode,
            text: GSIButtonText.continueWith,
            size: GSIButtonSize.large,
            theme: GSIButtonTheme.outline,
          ),
        ),
      ),
    );
  }
}
