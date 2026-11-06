import '../l10n/app_strings.dart';
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

import '../account.dart';
import '../account_apple_button.dart';
import '../account_google_button.dart';
import '../economy.dart';
import '../arenas.dart';
import '../palette.dart';
import 'collection_shop.dart';
import 'game_world.dart';
import 'profile_appearance.dart';

class ProfilePanel extends StatefulWidget {
  const ProfilePanel({
    super.key,
    required this.economy,
    this.initialSection = 0,
  });

  final EconomyController economy;
  final int initialSection;

  @override
  State<ProfilePanel> createState() => _ProfilePanelState();
}

class _ProfilePanelState extends State<ProfilePanel> {
  late int section = widget.initialSection.clamp(0, 2);
  bool working = false;
  int modalDepth = 0;
  bool discovering = true;
  bool discoveryFailed = false;
  bool loadingSessions = false;
  List<AccountProvider> providers = [];
  List<AccountSession>? sessions;
  List<AccountProfilePreview> archivedProfiles = [];
  final Set<String> linkingReady = {};
  EconomyController get economy => widget.economy;
  bool get unavailable => working || economy.busy;
  bool get onlineAction => !unavailable && !economy.offline;

  @override
  void initState() {
    super.initState();
    economy.addListener(changed);
    unawaited(discover());
    if (section == 2) unawaited(loadSessions());
  }

  @override
  void dispose() {
    economy.removeListener(changed);
    super.dispose();
  }

  void changed() {
    if (mounted) setState(() {});
  }

  void showError([Object? error]) {
    if (!mounted) return;
    final message = error is EconomyException
        ? error.message
        : error is AccountProviderException
        ? error.message
        : economy.lastError ?? 'Operazione non completata. Riprova.';
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(tr(context, message))));
  }

  Future<void> discover() async {
    try {
      final result = await economy.discoverAccountProviders();
      if (!mounted) return;
      setState(() {
        providers = result;
        discoveryFailed = false;
      });
    } catch (_) {
      if (mounted) setState(() => discoveryFailed = true);
    } finally {
      if (mounted) setState(() => discovering = false);
    }
  }

  Future<void> loadSessions() async {
    if (loadingSessions || economy.offline || economy.profile == null) return;
    setState(() => loadingSessions = true);
    try {
      final archived = await economy.archivedAccountProfiles();
      if (mounted) setState(() => archivedProfiles = archived);
      final result = await economy.listAccountSessions();
      if (mounted) setState(() => sessions = result);
    } catch (_) {
      // Older services can still manage guests and recovery codes.
      if (mounted) setState(() => sessions = null);
    } finally {
      if (mounted) setState(() => loadingSessions = false);
    }
  }

  Future<void> run(Future<void> Function() action) async {
    if (working) return;
    setState(() => working = true);
    try {
      try {
        await action();
      } on EconomyException catch (error) {
        if (!{
          'REAUTH_REQUIRED',
          'RECENT_AUTH_REQUIRED',
          'FRESH_AUTH_REQUIRED',
        }.contains(error.code)) {
          rethrow;
        }
        if (await verifyAccess() && mounted) await action();
      }
    } catch (error) {
      showError(error);
    } finally {
      if (mounted) setState(() => working = false);
    }
  }

  Future<T?> present<T>({required WidgetBuilder builder}) async {
    if (!mounted) return null;
    setState(() => modalDepth++);
    try {
      return await showDialog<T>(context: context, builder: builder);
    } finally {
      if (mounted) setState(() => modalDepth--);
    }
  }

  Future<bool> confirm(String title, String body, String action) async =>
      await present<bool>(
        builder: (context) => AlertDialog(
          scrollable: true,
          title: Text(tr(context, title)),
          content: Text(tr(context, body)),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(tr(context, 'Annulla')),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(tr(context, action)),
            ),
          ],
        ),
      ) ??
      false;

  Future<String?> input({
    required String title,
    required String action,
    String initial = '',
    bool secret = false,
  }) => present<String>(
    builder: (_) => _ProfileInputDialog(
      title: title,
      action: action,
      initial: initial,
      secret: secret,
    ),
  );

  Future<bool> verifyAccess() async {
    if (!mounted) return false;
    final linked = economy.profile?.linkedProviders ?? <String>{};
    final method = await present<String>(
      builder: (context) => SimpleDialog(
        title: Text(tr(context, 'Verifica il tuo accesso')),
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(24, 0, 24, 12),
            child: Text(
              tr(
                context,
                'Per questa modifica, conferma di poter accedere al profilo.',
              ),
            ),
          ),
          for (final provider in providers.where((p) => linked.contains(p.id)))
            SimpleDialogOption(
              onPressed: () => Navigator.pop(context, provider.id),
              child: Text(
                tr(context, 'Continua con ${providerName(provider.id)}'),
              ),
            ),
          if (economy.profile?.recoveryEnabled == true)
            SimpleDialogOption(
              onPressed: () => Navigator.pop(context, 'recovery'),
              child: Text(tr(context, 'Usa il codice di recupero')),
            ),
          SimpleDialogOption(
            onPressed: () => Navigator.pop(context),
            child: Text(tr(context, 'Annulla')),
          ),
        ],
      ),
    );
    if (method == null || !mounted) return false;
    if (method == 'recovery') {
      final code = await input(
        title: 'Codice di recupero',
        action: 'Verifica',
        secret: true,
      );
      if (code == null || code.isEmpty) return false;
      await economy.reauthenticateWithRecovery(code);
      return true;
    }
    final provider = providers.firstWhere((p) => p.id == method);
    if (kIsWeb) {
      return await present<bool>(
            builder: (dialogContext) {
              Future<void> verified(AccountSignInPreview preview) async {
                try {
                  await economy.confirmAccountSignIn(preview);
                  if (dialogContext.mounted) Navigator.pop(dialogContext, true);
                } catch (error) {
                  showError(error);
                }
              }

              return AlertDialog(
                scrollable: true,
                title: Text(
                  tr(context, 'Verifica con ${providerName(provider.id)}'),
                ),
                content: provider.id == 'apple'
                    ? AccountAppleWebButton(
                        economy: economy,
                        provider: provider,
                        operation: 'reauth',
                        onPreview: verified,
                        onError: showError,
                      )
                    : AccountGoogleWebButton(
                        economy: economy,
                        provider: provider,
                        operation: 'reauth',
                        onPreview: verified,
                        onError: showError,
                      ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(dialogContext, false),
                    child: Text(tr(context, 'Annulla')),
                  ),
                ],
              );
            },
          ) ??
          false;
    }
    final preview = await economy.beginAccountSignIn(
      provider,
      operation: 'reauth',
    );
    if (preview == null) return false;
    await economy.confirmAccountSignIn(preview);
    return true;
  }

  Future<void> showCode(String code) async {
    if (!mounted) return;
    await present<void>(
      builder: (context) => AlertDialog(
        scrollable: true,
        title: Text(tr(context, 'Codice di recupero')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              tr(
                context,
                'Chi possiede questo codice può accedere al tuo profilo. Conservalo in un posto sicuro.',
              ),
            ),
            const SizedBox(height: 16),
            SelectableText(
              code,
              style: const TextStyle(
                fontSize: 15,
                fontFamily: 'monospace',
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        actions: [
          TextButton.icon(
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: code));
              if (mounted) {
                ScaffoldMessenger.of(this.context).showSnackBar(
                  SnackBar(content: Text(tr(this.context, 'Codice copiato'))),
                );
              }
            },
            icon: const Icon(Icons.copy_rounded, size: 18),
            label: Text(tr(context, 'Copia codice')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context),
            child: Text(tr(context, 'Fatto')),
          ),
        ],
      ),
    );
  }

  Future<void> createCode({bool rotate = false}) async {
    if (rotate &&
        !await confirm(
          'Nuovo codice di recupero?',
          'Il codice precedente non funzionerà più. I dispositivi già collegati resteranno collegati.',
          'Crea codice',
        )) {
      return;
    }
    await run(() async {
      final code = rotate
          ? await economy.rotateRecovery()
          : await economy.activateRecovery();
      await showCode(code);
    });
  }

  Future<bool> preserveCurrentProfile() async {
    if (economy.profile == null ||
        economy.profile!.recoveryEnabled ||
        economy.profile!.linkedProviders.isNotEmpty) {
      return true;
    }
    final decision = await present<String>(
      builder: (context) => AlertDialog(
        scrollable: true,
        title: Text(tr(context, 'Conserva il profilo attuale')),
        content: Text(
          tr(
            context,
            'Prima di cambiarlo puoi creare un codice per ritrovare le sue gemme e collezioni. I due profili non verranno uniti.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(tr(context, 'Annulla')),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, 'skip'),
            child: Text(tr(context, 'Continua senza codice')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, 'save'),
            child: Text(tr(context, 'Crea codice')),
          ),
        ],
      ),
    );
    if (decision == null) return false;
    if (decision == 'save') await showCode(await economy.activateRecovery());
    return true;
  }

  Future<void> finishSignIn(AccountSignInPreview preview) async {
    if (preview.switchesProfile) {
      if (!await preserveCurrentProfile() || !mounted) return;
      final found = preview.profile;
      if (!await confirm(
        'Usa questo profilo?',
        '${found.displayName.isEmpty ? tr(context, 'Giocatore') : found.displayName}\n'
            '${found.gems} gemme · ${found.ownedDecks.length} collezioni\n\n'
            'Sostituirà il profilo su questo dispositivo. Gemme e collezioni dei due profili restano separate.',
        'Usa profilo',
      )) {
        return;
      }
    }
    await economy.confirmAccountSignIn(preview);
    if (!mounted) return;
    setState(() {
      section = 0;
      sessions = null;
      linkingReady.clear();
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          tr(
            context,
            preview.switchesProfile ? 'Profilo collegato' : 'Accesso salvato',
          ),
        ),
      ),
    );
  }

  Future<void> signIn(AccountProvider provider) => run(() async {
    final linked = economy.profile?.linkedProviders ?? <String>{};
    final operation = linked.isEmpty || linked.contains(provider.id)
        ? 'login'
        : 'link';
    final preview = await economy.beginAccountSignIn(
      provider,
      operation: operation,
    );
    if (preview != null) await finishSignIn(preview);
  });

  Future<void> unlink(String provider) => run(() async {
    final profile = economy.profile;
    if (profile == null) return;
    if (profile.linkedProviders.length == 1 && !profile.recoveryEnabled) {
      if (!await confirm(
        'Conserva un metodo di accesso',
        'Prima di scollegare l’ultimo accesso, crea un codice di recupero per poter ritrovare questo profilo.',
        'Crea codice',
      )) {
        return;
      }
      await showCode(await economy.activateRecovery());
    }
    if (!mounted ||
        !await confirm(
          'Scollegare ${providerName(provider)}?',
          'Per rientrare servirà un altro metodo collegato o il codice di recupero. Uscire dal dispositivo è un’azione separata.',
          'Scollega',
        )) {
      return;
    }
    await economy.unlinkAccountProvider(provider);
  });

  Future<void> restore() async {
    final code = await input(
      title: 'Codice di recupero',
      action: 'Verifica',
      secret: true,
    );
    if (code == null || code.isEmpty || !mounted) return;
    await run(() async {
      final preview = await economy.previewRecovery(code);
      if (preview.id != economy.profile?.id &&
          !await preserveCurrentProfile()) {
        return;
      }
      if (!mounted ||
          !await confirm(
            'Collega questo profilo?',
            '${preview.displayName.isEmpty ? tr(context, 'Giocatore') : preview.displayName}\n'
                '${preview.gems} gemme · ${preview.ownedDecks.length} collezioni\n\n'
                'Sostituirà il profilo su questo dispositivo. Gemme e collezioni non vengono unite.',
            'Collega',
          )) {
        return;
      }
      await economy.restoreRecovery(code);
      if (mounted) {
        setState(() {
          section = 0;
          sessions = null;
        });
      }
    });
  }

  Future<void> customize() async {
    final profile = economy.profile;
    if (profile == null) return;
    final value = await present<({String avatarId, String accentId})>(
      builder: (_) => _AppearanceDialog(
        avatarId: profile.avatarId,
        accentId: profile.accentId,
      ),
    );
    if (value != null) {
      await run(
        () => economy.setAppearance(
          avatarId: value.avatarId,
          accentId: value.accentId,
        ),
      );
    }
  }

  String providerName(String id) => switch (id) {
    'apple' => 'Apple',
    'google' => 'Google',
    _ => id,
  };

  Widget nativeProviderButton(AccountProvider provider) => Opacity(
    opacity: onlineAction ? 1 : .5,
    child: provider.id == 'apple'
        ? IgnorePointer(
            ignoring: !onlineAction,
            child: MediaQuery.withNoTextScaling(
              child: SignInWithAppleButton(
                onPressed: () => signIn(provider),
                text: tr(context, 'Continua con Apple'),
                height: 48,
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          )
        : SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: onlineAction ? () => signIn(provider) : null,
              style: OutlinedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: const Color(0xFF1F1F1F),
                minimumSize: const Size(0, 48),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                side: const BorderSide(color: Color(0xFF747775)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              icon: Image.asset(
                'assets/account/google_g.png',
                width: 20,
                height: 20,
                excludeFromSemantics: true,
              ),
              label: Text(
                tr(context, 'Continua con Google'),
                style: TextStyle(
                  fontFamily: 'GoogleSignIn',
                  fontWeight: FontWeight.w500,
                  fontSize: 14,
                ),
              ),
            ),
          ),
  );

  void webProviderError(AccountProvider provider, Object error) {
    if (!mounted) return;
    if (error is EconomyException && error.code == 'REAUTH_REQUIRED') {
      setState(() => linkingReady.remove(provider.id));
    }
    showError(error);
  }

  List<Widget> profileContents() {
    final profile = economy.profile;
    return [
      _ProfileAction(
        icon: Icons.edit_rounded,
        title: 'Nome giocatore',
        translateSubtitle: profile?.displayName.isNotEmpty != true,
        subtitle: profile?.displayName.isNotEmpty == true
            ? profile!.displayName
            : 'Scegli un nickname',
        onTap: onlineAction && profile != null
            ? () async {
                final value = await input(
                  title: 'Nome giocatore',
                  action: 'Salva',
                  initial: profile.displayName,
                );
                if (value != null) {
                  await run(() => economy.setDisplayName(value));
                }
              }
            : null,
      ),
      _ProfileAction(
        icon: Icons.palette_outlined,
        title: 'Avatar e colore',
        subtitle: 'Personalizza anche il tuo profilo ospite',
        onTap: onlineAction && profile != null ? customize : null,
      ),
      _ProfileAction(
        icon: Icons.collections_rounded,
        title: '${economy.ownedDecks.length} collezioni',
        subtitle: '${economy.gems} gemme disponibili',
      ),
      _ProfileAction(
        icon: Icons.emoji_events_rounded,
        title:
            '${profile?.crowns ?? 0} corone · ${tr(context, ArenaCatalog.instance.arenas.firstWhere((arena) => arena.id == (profile?.currentArenaId ?? 'wild_valley')).name)}',
        subtitle: 'Record personale: ${profile?.peakCrowns ?? 0} corone',
      ),
      if (economy.pendingRewards > 0)
        _ProfileAction(
          icon: Icons.cloud_upload_outlined,
          title: '${economy.pendingRewards} premi da sincronizzare',
          subtitle: 'Restano associati a questo profilo',
          onTap: unavailable ? null : () => run(economy.sync),
        ),
      _ProfileAction(
        icon: economy.offline ? Icons.cloud_off_outlined : Icons.sync_rounded,
        title: economy.offline ? 'Offline' : 'Sincronizza',
        subtitle: economy.offline
            ? 'Puoi continuare a giocare. Le modifiche al profilo richiedono una connessione.'
            : 'Aggiorna gemme e collezioni',
        onTap: unavailable ? null : () => run(economy.sync),
      ),
      const _ProfileNote(
        'I record delle partite e le preferenze di gioco restano su questo dispositivo.',
      ),
    ];
  }

  List<Widget> connectContents() {
    final linked = economy.profile?.linkedProviders ?? <String>{};
    return [
      const _ProfileNote(
        'Ritrova gemme e collezioni su altri dispositivi. Puoi sempre giocare come ospite.',
      ),
      if (discovering) const LinearProgressIndicator(),
      for (final provider in providers)
        if (kIsWeb && modalDepth > 0)
          const SizedBox.shrink()
        else if (kIsWeb &&
            linked.isNotEmpty &&
            !linked.contains(provider.id) &&
            !linkingReady.contains(provider.id))
          _ProfileAction(
            icon: Icons.link_rounded,
            title: 'Collega ${providerName(provider.id)}',
            subtitle: 'Aggiungi un altro modo per ritrovare il tuo profilo',
            onTap: onlineAction
                ? () => run(() async {
                    if (await verifyAccess() && mounted) {
                      setState(() => linkingReady.add(provider.id));
                    }
                  })
                : null,
          )
        else if (kIsWeb && provider.id == 'apple')
          AccountAppleWebButton(
            economy: economy,
            provider: provider,
            operation: linked.isEmpty || linked.contains(provider.id)
                ? 'login'
                : 'link',
            enabled: onlineAction,
            onPreview: (preview) => run(() => finishSignIn(preview)),
            onError: (error) => webProviderError(provider, error),
          )
        else if (kIsWeb && provider.id == 'google')
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: AccountGoogleWebButton(
              economy: economy,
              provider: provider,
              operation: linked.isEmpty || linked.contains(provider.id)
                  ? 'login'
                  : 'link',
              enabled: onlineAction,
              onPreview: (preview) => run(() => finishSignIn(preview)),
              onError: (error) => webProviderError(provider, error),
            ),
          )
        else
          nativeProviderButton(provider),
      if (discoveryFailed)
        _ProfileAction(
          icon: Icons.refresh_rounded,
          title: 'Riprova a caricare gli accessi',
          subtitle: 'Il codice di recupero resta disponibile',
          onTap: onlineAction
              ? () async {
                  setState(() => discovering = true);
                  await discover();
                }
              : null,
        ),
      _ProfileAction(
        icon: Icons.key_rounded,
        title: economy.isSaved ? 'Mostra codice' : 'Crea codice di recupero',
        subtitle: 'Un modo alternativo per ritrovare gemme e collezioni',
        onTap: unavailable || (!economy.isSaved && economy.offline)
            ? null
            : createCode,
      ),
      _ProfileAction(
        icon: Icons.devices_rounded,
        title: 'Ho già un codice',
        subtitle: 'Collega un profilo salvato su un altro dispositivo',
        onTap: onlineAction ? restore : null,
      ),
    ];
  }

  List<Widget> manageContents() {
    final linked = economy.profile?.linkedProviders ?? <String>{};
    return [
      if (widget.initialSection == 2 && linked.isEmpty)
        _ProfileNote(
          'Tu stai gestendo ${economy.profile?.displayName.isNotEmpty == true ? economy.profile!.displayName : 'il profilo ospite'} su questo dispositivo. Per eliminare un account salvato altrove, ritrovalo prima da Salva e collega.',
        ),
      for (final provider in linked)
        _ProfileAction(
          icon: provider == 'apple'
              ? Icons.apple
              : Icons.account_circle_outlined,
          title: '${providerName(provider)} collegato',
          subtitle: 'Gestisci questo metodo di accesso',
          onTap: onlineAction ? () => unlink(provider) : null,
        ),
      if (economy.isSaved)
        _ProfileAction(
          icon: Icons.published_with_changes_rounded,
          title: 'Crea nuovo codice',
          subtitle: 'Invalida il codice precedente',
          onTap: onlineAction ? () => createCode(rotate: true) : null,
        ),
      _ProfileAction(
        icon: Icons.devices_other_rounded,
        title: 'Dispositivi collegati',
        subtitle: loadingSessions
            ? 'Caricamento…'
            : sessions == null
            ? 'Visualizza e scollega le sessioni del profilo'
            : '${sessions!.length} sessioni attive',
        onTap: onlineAction && !loadingSessions ? loadSessions : null,
      ),
      if (sessions != null)
        for (final session in sessions!)
          _ProfileAction(
            icon: session.current
                ? Icons.smartphone_rounded
                : Icons.devices_rounded,
            title: session.current
                ? 'Questo dispositivo'
                : session.name.isEmpty
                ? 'Altro dispositivo'
                : session.name,
            subtitle: session.current
                ? 'La sessione che stai usando'
                : 'Tocca per scollegare questo dispositivo',
            onTap: onlineAction && !session.current
                ? () async {
                    if (await confirm(
                      'Scollegare il dispositivo?',
                      'Dovrà accedere di nuovo. Il profilo, le gemme e le collezioni restano salvati.',
                      'Scollega',
                    )) {
                      await run(() async {
                        await economy.revokeAccountSession(session.id);
                        await loadSessions();
                      });
                    }
                  }
                : null,
          ),
      for (final archived in archivedProfiles)
        _ProfileAction(
          icon: Icons.switch_account_outlined,
          translateTitle: archived.displayName.isEmpty,
          title: archived.displayName.isEmpty
              ? 'Altro profilo sul dispositivo'
              : archived.displayName,
          subtitle:
              '${archived.gems} gemme · ${archived.ownedDecks.length} collezioni · Riprendi profilo',
          onTap: onlineAction
              ? () => run(() async {
                  if (!await preserveCurrentProfile() || !mounted) return;
                  if (!await confirm(
                    'Riprendere questo profilo?',
                    'Il profilo corrente rimane separato. Gemme e collezioni non vengono unite.',
                    'Riprendi',
                  )) {
                    return;
                  }
                  await economy.restoreArchivedAccount(archived.id);
                  if (mounted) {
                    setState(() {
                      section = 0;
                      sessions = null;
                      archivedProfiles = [];
                    });
                  }
                })
              : null,
        ),
      _ProfileAction(
        icon: Icons.logout_rounded,
        title: 'Esci dal profilo',
        subtitle: 'Scollega solo questo dispositivo',
        onTap: onlineAction
            ? () => run(() async {
                if (!await preserveCurrentProfile() || !mounted) return;
                if (await confirm(
                  'Uscire dal profilo?',
                  'Il profilo non viene eliminato. Per rientrare servirà Apple, Google o il suo codice di recupero. Potrai continuare come ospite.',
                  'Esci',
                )) {
                  await economy.logout();
                  if (mounted) {
                    setState(() {
                      sessions = null;
                      section = 0;
                    });
                  }
                }
              })
            : null,
      ),
      _ProfileAction(
        icon: Icons.delete_outline_rounded,
        title: 'Elimina profilo',
        subtitle: 'Elimina definitivamente gemme, collezioni e accessi',
        destructive: true,
        onTap: onlineAction
            ? () async {
                if (await confirm(
                  'Eliminare definitivamente?',
                  '${economy.profile?.displayName.isNotEmpty == true ? economy.profile!.displayName : tr(context, 'Giocatore')}\n'
                      '${economy.gems} gemme · ${economy.ownedDecks.length} collezioni\n\n'
                      'Il profilo e i suoi accessi saranno eliminati dal servizio. I dispositivi offline riceveranno la revoca alla riconnessione. Questa azione non può essere annullata.',
                  'Elimina',
                )) {
                  await run(() async {
                    await economy.deleteProfile();
                    if (mounted) {
                      setState(() {
                        sessions = null;
                        section = 0;
                      });
                    }
                  });
                }
              }
            : null,
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final profile = economy.profile;
    final linked = profile?.linkedProviders ?? <String>{};
    final contents = switch (section) {
      0 => profileContents(),
      1 => connectContents(),
      _ => manageContents(),
    };
    return GameWorld(
      collection: 'cosmos',
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(8, 8, 16, 0),
                    child: Row(
                      children: [
                        IconButton(
                          tooltip: tr(context, 'Chiudi profilo'),
                          onPressed: () => Navigator.pop(context),
                          icon: const Icon(Icons.arrow_back_rounded),
                        ),
                        Expanded(
                          child: Text(
                            tr(context, 'Profilo'),
                            style: TextStyle(
                              color: paper,
                              fontSize: 24,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        GemBalance(economy: economy),
                      ],
                    ),
                  ),
                  if (working && modalDepth == 0)
                    const LinearProgressIndicator(minHeight: 3),
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                      children: [
                        _ProfileSurface(
                          child: Row(
                            children: [
                              ProfileAvatar(
                                avatarId: profile?.avatarId ?? 'fox',
                                accentId: profile?.accentId ?? 'forest',
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      profile?.displayName.isNotEmpty == true
                                          ? profile!.displayName
                                          : tr(context, 'Giocatore'),
                                      style: const TextStyle(
                                        fontSize: 21,
                                        color: ink,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      tr(
                                        context,
                                        linked.isEmpty
                                            ? 'Profilo ospite'
                                            : 'Account collegato',
                                      ),
                                      style: const TextStyle(color: ink),
                                    ),
                                    if (profile?.recoveryEnabled == true)
                                      Text(
                                        tr(
                                          context,
                                          'Codice di recupero attivo',
                                        ),
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: ink,
                                        ),
                                      ),
                                    if (linked.isNotEmpty)
                                      Text(
                                        tr(
                                          context,
                                          linked.map(providerName).join(' · '),
                                        ),
                                        style: const TextStyle(
                                          fontSize: 12,
                                          color: ink,
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 14),
                        if (profile == null)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: _ProfileAction(
                              icon: Icons.person_add_alt_1_rounded,
                              title: 'Continua come ospite',
                              subtitle:
                                  'Crea un nuovo profilo per ricominciare a giocare',
                              onTap: unavailable
                                  ? null
                                  : () => run(economy.startGuestProfile),
                            ),
                          ),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            for (final (value, label) in [
                              (0, 'Il mio profilo'),
                              (1, 'Salva e collega'),
                              (2, 'Gestisci'),
                            ])
                              ChoiceChip(
                                label: Text(tr(context, label)),
                                selected: section == value,
                                onSelected: unavailable
                                    ? null
                                    : (_) {
                                        setState(() => section = value);
                                        if (value == 2) {
                                          unawaited(loadSessions());
                                        }
                                      },
                              ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        for (final content in contents)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: content,
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ProfileSurface extends StatelessWidget {
  const _ProfileSurface({required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => Material(
    color: paper,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(16),
      side: const BorderSide(color: ink, width: 2),
    ),
    child: Padding(padding: const EdgeInsets.all(16), child: child),
  );
}

class _ProfileNote extends StatelessWidget {
  const _ProfileNote(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => _ProfileSurface(
    child: Text(
      tr(context, text),
      style: const TextStyle(color: ink, height: 1.45),
    ),
  );
}

class _ProfileAction extends StatelessWidget {
  const _ProfileAction({
    required this.icon,
    required this.title,
    this.subtitle,
    this.onTap,
    this.destructive = false,
    this.translateTitle = true,
    this.translateSubtitle = true,
  });
  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback? onTap;
  final bool destructive, translateTitle, translateSubtitle;
  @override
  Widget build(BuildContext context) => Material(
    color: paper,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(14),
      side: const BorderSide(color: ink, width: 1.5),
    ),
    child: ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
      leading: Icon(icon, color: destructive ? const Color(0xFFA84432) : teal),
      title: Text(
        translateTitle ? tr(context, title) : title,
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: destructive ? const Color(0xFFA84432) : ink,
        ),
      ),
      subtitle: subtitle == null
          ? null
          : Text(
              translateSubtitle ? tr(context, subtitle!) : subtitle!,
              style: const TextStyle(fontSize: 13, color: ink),
            ),
      trailing: onTap == null
          ? null
          : const Icon(Icons.chevron_right_rounded, size: 20),
      onTap: onTap,
    ),
  );
}

class _ProfileInputDialog extends StatefulWidget {
  const _ProfileInputDialog({
    required this.title,
    required this.action,
    required this.initial,
    required this.secret,
  });
  final String title, action, initial;
  final bool secret;
  @override
  State<_ProfileInputDialog> createState() => _ProfileInputDialogState();
}

class _ProfileInputDialogState extends State<_ProfileInputDialog> {
  late final TextEditingController controller = TextEditingController(
    text: widget.initial,
  );
  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    scrollable: true,
    title: Text(tr(context, widget.title)),
    content: TextField(
      controller: controller,
      autofocus: true,
      obscureText: widget.secret,
      autocorrect: !widget.secret,
      enableSuggestions: !widget.secret,
      maxLength: widget.secret ? 100 : 24,
      decoration: InputDecoration(
        labelText: tr(context, widget.secret ? 'Codice personale' : 'Nickname'),
        counterText: '',
      ),
      onSubmitted: (value) => Navigator.pop(context, value.trim()),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: Text(tr(context, 'Annulla')),
      ),
      FilledButton(
        onPressed: () => Navigator.pop(context, controller.text.trim()),
        child: Text(tr(context, widget.action)),
      ),
    ],
  );
}

class _AppearanceDialog extends StatefulWidget {
  const _AppearanceDialog({required this.avatarId, required this.accentId});
  final String avatarId, accentId;
  @override
  State<_AppearanceDialog> createState() => _AppearanceDialogState();
}

class _AppearanceDialogState extends State<_AppearanceDialog> {
  late String avatarId = widget.avatarId;
  late String accentId = widget.accentId;
  @override
  Widget build(BuildContext context) => AlertDialog(
    scrollable: true,
    title: Text(tr(context, 'Avatar e colore')),
    content: SizedBox(
      width: 450,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: ProfileAvatar(
              avatarId: avatarId,
              accentId: accentId,
              size: 84,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            tr(context, 'Avatar'),
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final entry in profileAvatars.entries)
                ChoiceChip(
                  label: Text(
                    tr(
                      context,
                      '${entry.value.symbol} ${tr(context, entry.value.label)}',
                    ),
                  ),
                  selected: avatarId == entry.key,
                  onSelected: (_) => setState(() => avatarId = entry.key),
                ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            tr(context, 'Colore'),
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final entry in profileAccents.entries)
                ChoiceChip(
                  avatar: Icon(
                    Icons.circle,
                    size: 18,
                    color: entry.value.color,
                  ),
                  label: Text(tr(context, entry.value.label)),
                  selected: accentId == entry.key,
                  onSelected: (_) => setState(() => accentId = entry.key),
                ),
            ],
          ),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: Text(tr(context, 'Annulla')),
      ),
      FilledButton(
        onPressed: () =>
            Navigator.pop(context, (avatarId: avatarId, accentId: accentId)),
        child: Text(tr(context, 'Salva')),
      ),
    ],
  );
}
