import 'dart:async';
import 'dart:js_interop';

import 'package:flutter/material.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:web/web.dart' as web;

import 'account.dart';
import 'economy.dart';

/// Uses the secure server callback's handoff protocol, keeping Apple tokens out
/// of browser return URLs. The popup opens synchronously from the user's tap.
class AccountAppleWebButton extends StatefulWidget {
  const AccountAppleWebButton({
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
  State<AccountAppleWebButton> createState() => _AccountAppleWebButtonState();
}

class _AccountAppleWebButtonState extends State<AccountAppleWebButton> {
  AccountAttempt? _attempt;
  web.Window? _popup;
  JSFunction? _listener;
  Timer? _watch;
  bool _failed = false, _processing = false, _used = false;
  int _generation = 0;

  @override
  void initState() {
    super.initState();
    unawaited(_prepare());
  }

  @override
  void didUpdateWidget(AccountAppleWebButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.operation != widget.operation ||
        oldWidget.provider.clientId != widget.provider.clientId ||
        oldWidget.economy != widget.economy ||
        (_attempt != null &&
            _attempt!.profileId != (widget.economy.profile?.id ?? ''))) {
      unawaited(_prepare());
    }
  }

  void _closePopup() {
    _watch?.cancel();
    _watch = null;
    if (_listener != null) web.window.removeEventListener('message', _listener);
    _listener = null;
    _popup?.close();
    _popup = null;
  }

  Future<void> _prepare() async {
    final generation = ++_generation;
    _closePopup();
    setState(() {
      _attempt = null;
      _failed = false;
      _processing = false;
      _used = false;
    });
    try {
      final attempt = await widget.economy.prepareAccountSignIn(
        widget.provider,
        operation: widget.operation,
      );
      if (mounted && generation == _generation) {
        setState(() => _attempt = attempt);
      }
    } catch (error) {
      if (!mounted || generation != _generation) return;
      setState(() => _failed = true);
      widget.onError(error);
    }
  }

  void _openPopup() {
    final attempt = _attempt;
    if (attempt == null || _processing || _used || !widget.enabled) return;
    if (!attempt.expiresAt.isAfter(DateTime.now())) {
      unawaited(_prepare());
      return;
    }
    final redirect = attempt.redirectUri ?? widget.provider.redirectUri;
    final clientId = attempt.clientId ?? widget.provider.clientId;
    if (redirect == null || clientId == null) return;
    final expectedOrigin = Uri.parse(redirect).origin;
    final authorization = Uri.https('appleid.apple.com', '/auth/authorize', {
      'client_id': clientId,
      'redirect_uri': redirect,
      'response_type': 'code id_token',
      'response_mode': 'form_post',
      'state': attempt.state,
      'nonce': attempt.nonce,
    });
    // Do not await network work before window.open: Safari requires user input.
    _popup = web.window.open(
      authorization.toString(),
      'sommomemory_apple_auth',
      'popup=yes,width=500,height=700',
    );
    if (_popup == null) {
      widget.onError(
        const EconomyException(
          'Consenti la finestra di accesso Apple nel browser e riprova.',
        ),
      );
      return;
    }
    setState(() => _processing = true);
    final generation = _generation;
    _listener = ((web.Event raw) {
      final event = raw as web.MessageEvent;
      if (!mounted ||
          generation != _generation ||
          _used ||
          event.origin != expectedOrigin ||
          event.source != _popup) {
        return;
      }
      final data = event.data.dartify();
      if (data is! Map ||
          data['type'] != 'sommomemory-auth' ||
          data['state'] != attempt.state ||
          data['authorizationCode'] is! String) {
        return;
      }
      _used = true;
      _closePopup();
      unawaited(
        _complete(attempt, data['authorizationCode'] as String, generation),
      );
    }).toJS;
    web.window.addEventListener('message', _listener);
    _watch = Timer.periodic(const Duration(milliseconds: 500), (_) {
      if (_popup?.closed == true ||
          !attempt.expiresAt.isAfter(DateTime.now())) {
        _closePopup();
        if (mounted && generation == _generation) {
          setState(() => _processing = false);
        }
      }
    });
  }

  Future<void> _complete(
    AccountAttempt attempt,
    String handoff,
    int generation,
  ) async {
    try {
      final preview = await widget.economy.exchangeAccountCredential(
        attempt,
        AccountCredential(authorizationCode: handoff, state: attempt.state),
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
    _closePopup();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_failed || (_used && !_processing)) {
      return TextButton.icon(
        onPressed: widget.enabled ? _prepare : null,
        icon: const Icon(Icons.refresh_rounded),
        label: const Text('Accedi con Apple'),
      );
    }
    if (_attempt == null || _processing) {
      return const SizedBox(
        height: 44,
        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
      );
    }
    return SizedBox(
      width: widget.width ?? 280,
      child: IgnorePointer(
        ignoring: !widget.enabled,
        child: SignInWithAppleButton(
          onPressed: _openPopup,
          text: 'Continua con Apple',
        ),
      ),
    );
  }
}
