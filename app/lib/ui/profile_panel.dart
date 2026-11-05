import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../economy.dart';
import '../palette.dart';
import 'collection_shop.dart';
import 'game_world.dart';

class ProfilePanel extends StatefulWidget {
  const ProfilePanel({super.key, required this.economy});
  final EconomyController economy;
  @override
  State<ProfilePanel> createState() => _ProfilePanelState();
}

class _ProfilePanelState extends State<ProfilePanel> {
  int section = 0;
  bool working = false;
  EconomyController get economy => widget.economy;
  @override
  void initState() {
    super.initState();
    economy.addListener(changed);
  }

  @override
  void dispose() {
    economy.removeListener(changed);
    super.dispose();
  }

  void changed() {
    if (mounted) setState(() {});
  }

  Future<void> run(Future<void> Function() action) async {
    if (working) return;
    setState(() => working = true);
    try {
      await action();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              economy.lastError ?? 'Operazione non completata. Riprova.',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => working = false);
    }
  }

  Future<bool> confirm(String title, String body, String action) async =>
      await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(title),
          content: Text(body),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Annulla'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(action),
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
  }) => showDialog<String>(
    context: context,
    builder: (_) => _ProfileInputDialog(
      title: title,
      action: action,
      initial: initial,
      secret: secret,
    ),
  );

  Future<void> createCode({bool rotate = false}) async {
    if (rotate &&
        economy.isSaved &&
        !await confirm(
          'Nuovo codice di recupero?',
          'Il codice precedente non funzionerà più. Conserva il nuovo codice in un posto sicuro.',
          'Crea codice',
        )) {
      return;
    }
    await run(() async {
      final code = rotate
          ? await economy.rotateRecovery()
          : await economy.activateRecovery();
      if (!mounted) return;
      setState(() => working = false);
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Codice di recupero'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Chi possiede questo codice può accedere al tuo profilo. Conservalo per collegare un altro dispositivo.',
              ),
              const SizedBox(height: 16),
              SelectableText(
                code,
                style: const TextStyle(
                  fontSize: 14,
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
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Codice copiato')),
                  );
                }
              },
              icon: const Icon(Icons.copy_rounded, size: 18),
              label: const Text('Copia codice'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Fatto'),
            ),
          ],
        ),
      );
    });
  }

  Future<void> restore() async {
    final code = await input(
      title: 'Codice di recupero',
      action: 'Verifica',
      secret: true,
    );
    if (code == null || code.isEmpty || !mounted) return;
    await run(() async {
      final preview = await economy.previewRecovery(code);
      if (!mounted) return;
      setState(() => working = false);
      final accepted = await confirm(
        'Collega questo profilo?',
        '${preview.displayName.isEmpty ? 'Giocatore' : preview.displayName}\n${preview.gems} gemme · ${preview.ownedDecks.length} collezioni\n\nSostituirà il profilo su questo dispositivo. Quello attuale non viene eliminato; per recuperarlo ti servirà il suo codice.',
        'Collega',
      );
      if (!accepted || !mounted) return;
      setState(() => working = true);
      await economy.restoreRecovery(code);
      if (mounted) setState(() => section = 0);
    });
  }

  @override
  Widget build(BuildContext context) {
    final profile = economy.profile;
    final unavailable = working || economy.busy;
    final contents = switch (section) {
      0 => [
        _ProfileAction(
          icon: Icons.person_outline_rounded,
          title: profile?.displayName.isNotEmpty == true
              ? profile!.displayName
              : 'Giocatore',
          subtitle: economy.isSaved ? 'Profilo salvato' : 'Profilo ospite',
          onTap: unavailable
              ? null
              : () async {
                  final value = await input(
                    title: 'Nome giocatore',
                    action: 'Salva',
                    initial: profile?.displayName ?? '',
                  );
                  if (value != null) {
                    await run(() => economy.setDisplayName(value));
                  }
                },
        ),
        _ProfileAction(
          icon: Icons.collections_rounded,
          title: '${economy.ownedDecks.length} collezioni',
          subtitle: '${economy.gems} gemme disponibili',
        ),
        if (economy.pendingRewards > 0)
          _ProfileAction(
            icon: Icons.cloud_upload_outlined,
            title: '${economy.pendingRewards} premi da sincronizzare',
            onTap: unavailable ? null : () => run(economy.sync),
          ),
        _ProfileAction(
          icon: economy.offline ? Icons.cloud_off_outlined : Icons.sync_rounded,
          title: economy.offline ? 'Offline' : 'Sincronizza',
          subtitle: economy.offline
              ? 'Puoi continuare a giocare'
              : 'Aggiorna gemme e collezioni',
          onTap: unavailable ? null : () => run(economy.sync),
        ),
      ],
      1 => [
        _ProfileAction(
          icon: Icons.key_rounded,
          title: economy.isSaved ? 'Mostra codice' : 'Salva il profilo',
          subtitle: 'Conserva il codice per ritrovare gemme e collezioni',
          onTap: unavailable || (!economy.isSaved && economy.offline)
              ? null
              : createCode,
        ),
        _ProfileAction(
          icon: Icons.devices_rounded,
          title: 'Ho già un codice',
          subtitle:
              'Usa il codice anche tra browser e app: i profili restano separati finché non li colleghi',
          onTap: unavailable || economy.offline ? null : restore,
        ),
      ],
      _ => [
        if (economy.isSaved)
          _ProfileAction(
            icon: Icons.published_with_changes_rounded,
            title: 'Crea nuovo codice',
            subtitle: 'Invalida il codice precedente',
            onTap: unavailable || economy.offline
                ? null
                : () => createCode(rotate: true),
          ),
        _ProfileAction(
          icon: Icons.logout_rounded,
          title: 'Nuovo profilo ospite',
          subtitle: 'Scollega questo dispositivo',
          onTap: unavailable
              ? null
              : () async {
                  if (await confirm(
                    'Scollegare il profilo?',
                    'Il profilo attuale non viene eliminato. Se non conservi un codice di recupero, non potrai ricollegarlo. Su questo dispositivo verrà creato un nuovo profilo ospite.',
                    'Scollega',
                  )) {
                    await run(economy.logout);
                  }
                },
        ),
        _ProfileAction(
          icon: Icons.delete_outline_rounded,
          title: 'Elimina profilo',
          subtitle: 'Elimina definitivamente gemme e collezioni',
          destructive: true,
          onTap: unavailable || economy.offline
              ? null
              : () async {
                  if (await confirm(
                    'Eliminare definitivamente?',
                    'Il profilo, le gemme e le collezioni sbloccate saranno eliminati. Questa azione non può essere annullata.',
                    'Elimina',
                  )) {
                    await run(economy.deleteProfile);
                  }
                },
        ),
      ],
    };
    return GameWorld(
      collection: 'cosmos',
      child: Scaffold(
        backgroundColor: Colors.transparent,
        resizeToAvoidBottomInset: false,
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 800),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                child: Column(
                  children: [
                    Row(
                      children: [
                        IconButton(
                          tooltip: 'Chiudi profilo',
                          onPressed: () => Navigator.pop(context),
                          icon: const Icon(Icons.arrow_back_rounded),
                        ),
                        const Expanded(
                          child: Text(
                            'Profilo',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        GemBalance(economy: economy),
                      ],
                    ),
                    const SizedBox(height: 8),
                    SegmentedButton<int>(
                      segments: const [
                        ButtonSegment(value: 0, label: Text('Profilo')),
                        ButtonSegment(value: 1, label: Text('Collega')),
                        ButtonSegment(value: 2, label: Text('Gestisci')),
                      ],
                      selected: {section},
                      showSelectedIcon: false,
                      onSelectionChanged: (v) =>
                          setState(() => section = v.first),
                    ),
                    const SizedBox(height: 12),
                    Expanded(
                      child: LayoutBuilder(
                        builder: (context, c) {
                          final wide = c.maxWidth > 540;
                          if (wide) {
                            return Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                Expanded(
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      for (
                                        var i = 0;
                                        i < contents.length;
                                        i += 2
                                      )
                                        Padding(
                                          padding: const EdgeInsets.only(
                                            bottom: 8,
                                          ),
                                          child: contents[i],
                                        ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      for (
                                        var i = 1;
                                        i < contents.length;
                                        i += 2
                                      )
                                        Padding(
                                          padding: const EdgeInsets.only(
                                            bottom: 8,
                                          ),
                                          child: contents[i],
                                        ),
                                    ],
                                  ),
                                ),
                              ],
                            );
                          }
                          return Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              for (final item in contents)
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 10),
                                  child: item,
                                ),
                            ],
                          );
                        },
                      ),
                    ),
                    if (working)
                      const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ProfileAction extends StatelessWidget {
  const _ProfileAction({
    required this.icon,
    required this.title,
    this.subtitle,
    this.onTap,
    this.destructive = false,
  });
  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback? onTap;
  final bool destructive;
  @override
  Widget build(BuildContext context) => Material(
    color: const Color(0xFFFFF8E8),
    borderRadius: BorderRadius.circular(18),
    child: ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
      leading: Icon(icon, color: destructive ? coral : teal),
      title: Text(
        title,
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: destructive ? const Color(0xFFA84432) : ink,
        ),
      ),
      subtitle: subtitle == null
          ? null
          : Text(subtitle!, style: const TextStyle(fontSize: 12, color: ink)),
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
  Widget build(BuildContext context) => Dialog(
    insetPadding: const EdgeInsets.all(16),
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 450),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    widget.title,
                    style: const TextStyle(
                      fontSize: 19,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Annulla',
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: controller,
                    autofocus: true,
                    obscureText: widget.secret,
                    autocorrect: !widget.secret,
                    enableSuggestions: !widget.secret,
                    maxLength: widget.secret ? null : 20,
                    decoration: const InputDecoration(counterText: ''),
                    onSubmitted: (v) => Navigator.pop(context, v.trim()),
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: () =>
                      Navigator.pop(context, controller.text.trim()),
                  child: Text(widget.action),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}
