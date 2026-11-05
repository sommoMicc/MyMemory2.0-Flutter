import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'game.dart';
import 'online.dart';
import 'palette.dart';
import 'decks.dart';
import 'bluetooth/bluetooth_controller.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await registerDeckLicenses();
  final prefs = await SharedPreferences.getInstance();
  runApp(MyMemory(prefs: prefs));
}

class MyMemory extends StatelessWidget {
  const MyMemory({super.key, required this.prefs});
  final SharedPreferences prefs;
  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'MyMemory',
    debugShowCheckedModeBanner: false,
    theme: ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: paper,
      fontFamily: 'Outfit',
      colorScheme: ColorScheme.fromSeed(
        seedColor: teal,
        surface: paper,
        primary: teal,
        onSurface: ink,
      ),
      textTheme: const TextTheme(
        bodyLarge: TextStyle(color: ink),
        bodyMedium: TextStyle(color: ink),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(48, 56),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: line),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: line),
        ),
      ),
    ),
    home: Home(prefs: prefs),
  );
}

class Home extends StatefulWidget {
  const Home({super.key, required this.prefs});
  final SharedPreferences prefs;
  @override
  State<Home> createState() => _HomeState();
}

class _HomeState extends State<Home> {
  PlayMode mode = PlayMode.solo;
  int pairs = 8;
  String theme = 'garden';
  bool configuring = false;
  late final TextEditingController name;
  final room = TextEditingController();
  @override
  void initState() {
    super.initState();
    name = TextEditingController(text: widget.prefs.getString('name') ?? '');
    final savedPairs = widget.prefs.getInt('game.pairs');
    if ([6, 8, 12, 18].contains(savedPairs)) pairs = savedPairs!;
    final savedTheme = widget.prefs.getString('game.collection');
    if (deckNames.containsKey(savedTheme)) theme = savedTheme!;
    final invite = Uri.base.queryParameters['room'];
    if (invite != null) {
      mode = PlayMode.online;
      room.text = invite;
      configuring = true;
    }
  }

  @override
  void dispose() {
    name.dispose();
    room.dispose();
    super.dispose();
  }

  void start({bool join = false, bool resume = false}) async {
    widget.prefs.setString('name', name.text.trim());
    if (mode == PlayMode.solo || mode == PlayMode.local) {
      await Navigator.push(
        context,
        MaterialPageRoute<void>(
          builder: (_) => GameScreen(
            prefs: widget.prefs,
            pairs: pairs,
            theme: theme,
            mode: mode,
          ),
        ),
      );
    } else if (mode == PlayMode.online) {
      if (join && room.text.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Inserisci il codice della stanza')),
        );
        return;
      }
      final online = OnlineGame(widget.prefs);
      unawaited(
        online.open(
          resume
              ? null
              : join
              ? {
                  'type': 'join',
                  'code': room.text.trim().toUpperCase(),
                  'name': name.text.trim().isEmpty
                      ? 'Ospite'
                      : name.text.trim(),
                }
              : {
                  'type': 'create',
                  'name': name.text.trim().isEmpty
                      ? 'Giocatore'
                      : name.text.trim(),
                  'pairs': pairs,
                  'theme': theme,
                },
        ),
      );
      if (!mounted) return;
      await Navigator.push(
        context,
        MaterialPageRoute<void>(
          builder: (_) => GameScreen(
            prefs: widget.prefs,
            pairs: pairs,
            theme: theme,
            mode: mode,
            online: online,
          ),
        ),
      );
      online.dispose();
    } else {
      await Navigator.push(
        context,
        MaterialPageRoute<void>(
          builder: (_) => BluetoothLobby(
            prefs: widget.prefs,
            name: name.text.trim().isEmpty ? 'Giocatore' : name.text.trim(),
            pairs: pairs,
            theme: theme,
          ),
        ),
      );
    }
    if (mounted) setState(() {});
  }

  Future<void> editName() async {
    final previousName = name.text;
    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => _TextEntryDialog(
        title: 'Nome giocatore',
        controller: name,
        action: 'Salva',
        hint: 'Giocatore',
        maxLength: 20,
        capitalization: TextCapitalization.words,
      ),
    );
    if (saved != true) name.text = previousName;
    widget.prefs.setString('name', name.text.trim());
    if (mounted) setState(() {});
  }

  Future<void> joinRoom() async {
    final join = await showDialog<bool>(
      context: context,
      builder: (context) => _TextEntryDialog(
        title: 'Codice stanza',
        controller: room,
        action: 'Entra',
        hint: 'ABC123',
        maxLength: 6,
        capitalization: TextCapitalization.characters,
      ),
    );
    if (join == true && mounted) start(join: true);
  }

  void choosePairs() => showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Numero di coppie'),
      content: SizedBox(
        width: 320,
        child: Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final p in [6, 8, 12, 18])
              ChoiceChip(
                label: Text('$p coppie'),
                selected: pairs == p,
                onSelected: (_) {
                  setState(() => pairs = p);
                  widget.prefs.setInt('game.pairs', p);
                  Navigator.pop(context);
                },
              ),
          ],
        ),
      ),
    ),
  );

  void chooseTheme() => showDialog<void>(
    context: context,
    builder: (context) => Dialog(
      insetPadding: const EdgeInsets.all(16),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Collezioni',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Chiudi collezioni',
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
              for (final t in deckNames.keys) ...[
                const SizedBox(height: 8),
                _CollectionTile(
                  theme: t,
                  selected: theme == t,
                  onTap: () {
                    setState(() => theme = t);
                    widget.prefs.setString('game.collection', t);
                    Navigator.pop(context);
                  },
                ),
              ],
            ],
          ),
        ),
      ),
    ),
  );

  void settings() => showDialog<void>(
    context: context,
    builder: (_) => _SettingsDialog(prefs: widget.prefs),
  );

  @override
  Widget build(BuildContext context) {
    final modes = [
      (PlayMode.solo, Icons.person_outline_rounded, 'Singolo', 'Un giocatore'),
      (
        PlayMode.local,
        Icons.people_outline_rounded,
        'In due',
        'Un dispositivo',
      ),
      (PlayMode.online, Icons.public_rounded, 'Online', 'Due dispositivi'),
      if (BluetoothController.supported)
        (
          PlayMode.bluetooth,
          Icons.bluetooth_rounded,
          'Bluetooth',
          'Senza Internet',
        ),
    ];
    final modeTitle = switch (mode) {
      PlayMode.solo => 'Singolo',
      PlayMode.local => 'In due',
      PlayMode.online => 'Online',
      PlayMode.bluetooth => 'Bluetooth',
    };
    return PopScope(
      canPop: !configuring,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) setState(() => configuring = false);
      },
      child: Scaffold(
        resizeToAvoidBottomInset: false,
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 900),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                child: Column(
                  children: [
                    Row(
                      children: [
                        if (configuring)
                          IconButton(
                            tooltip: 'Scegli modalità',
                            onPressed: () =>
                                setState(() => configuring = false),
                            icon: const Icon(Icons.arrow_back_rounded),
                          )
                        else ...[
                          const BrandMark(),
                          const SizedBox(width: 10),
                        ],
                        Expanded(
                          child: Text(
                            configuring ? modeTitle : 'my memory',
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.w600,
                              letterSpacing: -.6,
                            ),
                          ),
                        ),
                        IconButton(
                          tooltip: 'Come si gioca e impostazioni',
                          onPressed: settings,
                          icon: const Icon(Icons.tune_rounded),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    if (!configuring) ...[
                      const Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'Modalità di gioco',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Expanded(
                        child: LayoutBuilder(
                          builder: (context, c) {
                            final wide = c.maxWidth > c.maxHeight * 1.5;
                            final columns = wide ? modes.length : 2;
                            final rows = (modes.length / columns).ceil();
                            final tileWidth =
                                (c.maxWidth - (columns - 1) * 12) / columns;
                            final tileHeight = math.min(
                              180.0,
                              (c.maxHeight - (rows - 1) * 12) / rows,
                            );
                            return Center(
                              child: Wrap(
                                spacing: 12,
                                runSpacing: 12,
                                children: [
                                  for (final m in modes)
                                    SizedBox(
                                      width: tileWidth,
                                      height: tileHeight,
                                      child: ModeTile(
                                        icon: m.$2,
                                        title: m.$3,
                                        subtitle: m.$4,
                                        selected: false,
                                        onTap: () => setState(() {
                                          mode = m.$1;
                                          configuring = true;
                                        }),
                                      ),
                                    ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                    ] else
                      Expanded(
                        child: LayoutBuilder(
                          builder: (context, c) {
                            final options = Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                _OptionRow(
                                  icon: Icons.grid_view_rounded,
                                  label: 'Coppie',
                                  value: '$pairs',
                                  onTap: choosePairs,
                                ),
                                const SizedBox(height: 8),
                                _CollectionTile(
                                  theme: theme,
                                  onTap: chooseTheme,
                                ),
                                if (mode == PlayMode.online ||
                                    mode == PlayMode.bluetooth) ...[
                                  const SizedBox(height: 8),
                                  _OptionRow(
                                    icon: Icons.person_outline_rounded,
                                    label: 'Nome',
                                    value: name.text.trim().isEmpty
                                        ? 'Giocatore'
                                        : name.text.trim(),
                                    onTap: editName,
                                  ),
                                ],
                                if (mode == PlayMode.solo &&
                                    widget.prefs.getInt('best.$pairs') != null)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 12),
                                    child: Text(
                                      'Record: ${widget.prefs.getInt('best.$pairs')} tentativi',
                                      style: const TextStyle(color: muted),
                                    ),
                                  ),
                              ],
                            );
                            final actions = Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                FilledButton.icon(
                                  onPressed: () => start(),
                                  icon: const Icon(Icons.play_arrow_rounded),
                                  label: Text(switch (mode) {
                                    PlayMode.online => 'Crea stanza',
                                    PlayMode.bluetooth => 'Continua',
                                    _ => 'Inizia partita',
                                  }),
                                ),
                                if (mode == PlayMode.online) ...[
                                  const SizedBox(height: 8),
                                  OutlinedButton.icon(
                                    onPressed: joinRoom,
                                    icon: const Icon(Icons.login_rounded),
                                    label: const Text('Entra con un codice'),
                                  ),
                                  if (widget.prefs.getString('room.token') !=
                                      null)
                                    TextButton.icon(
                                      onPressed: () => start(resume: true),
                                      icon: const Icon(Icons.restore_rounded),
                                      label: const Text('Riprendi la stanza'),
                                    ),
                                ],
                              ],
                            );
                            if (c.maxWidth > 540 && c.maxHeight < 430) {
                              return Row(
                                children: [
                                  Expanded(child: Center(child: options)),
                                  const SizedBox(width: 32),
                                  Expanded(child: Center(child: actions)),
                                ],
                              );
                            }
                            return Column(
                              children: [
                                Expanded(child: Center(child: options)),
                                const SizedBox(height: 16),
                                actions,
                              ],
                            );
                          },
                        ),
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

class _TextEntryDialog extends StatelessWidget {
  const _TextEntryDialog({
    required this.title,
    required this.controller,
    required this.action,
    required this.hint,
    required this.maxLength,
    required this.capitalization,
  });
  final String title, action, hint;
  final TextEditingController controller;
  final int maxLength;
  final TextCapitalization capitalization;
  @override
  Widget build(BuildContext context) => Dialog(
    insetPadding: const EdgeInsets.all(16),
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 440),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Annulla'),
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
                    maxLength: maxLength,
                    textCapitalization: capitalization,
                    decoration: InputDecoration(
                      counterText: '',
                      hintText: hint,
                    ),
                    onSubmitted: (_) => Navigator.pop(context, true),
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: Text(action),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}

class _OptionRow extends StatelessWidget {
  const _OptionRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.onTap,
  });
  final IconData icon;
  final String label, value;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Material(
    color: Colors.white,
    borderRadius: BorderRadius.circular(18),
    child: ListTile(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: const BorderSide(color: line),
      ),
      leading: Icon(icon, color: teal),
      title: Text(label, style: const TextStyle(fontSize: 12, color: muted)),
      subtitle: Text(
        value,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          fontSize: 17,
          color: ink,
          fontWeight: FontWeight.w600,
        ),
      ),
      trailing: const Icon(Icons.chevron_right_rounded, size: 20),
      onTap: onTap,
    ),
  );
}

class _SettingsDialog extends StatefulWidget {
  const _SettingsDialog({required this.prefs});
  final SharedPreferences prefs;
  @override
  State<_SettingsDialog> createState() => _SettingsDialogState();
}

class _SettingsDialogState extends State<_SettingsDialog> {
  int section = 0;
  @override
  Widget build(BuildContext context) => Dialog(
    insetPadding: const EdgeInsets.all(16),
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 480),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Impostazioni',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.w600),
                  ),
                ),
                IconButton(
                  tooltip: 'Chiudi',
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
            SegmentedButton<int>(
              segments: const [
                ButtonSegment(value: 0, label: Text('Preferenze')),
                ButtonSegment(value: 1, label: Text('Regole')),
                ButtonSegment(value: 2, label: Text('Info')),
              ],
              selected: {section},
              showSelectedIcon: false,
              onSelectionChanged: (v) => setState(() => section = v.first),
            ),
            const SizedBox(height: 16),
            if (section == 0)
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Feedback tattile'),
                value: widget.prefs.getBool('haptics') ?? true,
                onChanged: (v) {
                  widget.prefs.setBool('haptics', v);
                  setState(() {});
                },
              ),
            if (section == 1)
              const Text(
                'Gira due carte e trova le coppie. Una coppia ti dà un altro turno; un errore passa il turno all’altro giocatore.\n\nOnline: condividi il codice stanza. Bluetooth: un telefono ospita, l’altro cerca la partita.',
              ),
            if (section == 2) ...[
              const Text(
                'MyMemory · Michele Tagliabue\nLe partite locali restano sul dispositivo. Online vengono condivisi nome, mosse e stato stanza. Nessuna pubblicità o analisi di utilizzo.',
                style: TextStyle(fontSize: 14),
              ),
              const SizedBox(height: 10),
              const SelectableText(
                'mymemory.sommomi.cc/privacy\nmikitg.michele@gmail.com',
                style: TextStyle(fontSize: 13, color: teal),
              ),
              TextButton(
                onPressed: () => showLicensePage(
                  context: context,
                  applicationName: 'MyMemory',
                ),
                child: const Text('Licenze'),
              ),
            ],
          ],
        ),
      ),
    ),
  );
}

class BrandMark extends StatelessWidget {
  const BrandMark({super.key, this.size = 34});
  final double size;
  @override
  Widget build(BuildContext context) => SizedBox(
    width: size,
    height: size,
    child: Stack(
      children: [
        Positioned(
          left: 2,
          top: 1,
          child: Transform.rotate(
            angle: -.2,
            child: Container(
              width: size * .6,
              height: size * .8,
              decoration: BoxDecoration(
                color: coral,
                borderRadius: BorderRadius.circular(7),
              ),
            ),
          ),
        ),
        Positioned(
          right: 1,
          bottom: 1,
          child: Transform.rotate(
            angle: .16,
            child: Container(
              width: size * .6,
              height: size * .8,
              decoration: BoxDecoration(
                color: teal,
                borderRadius: BorderRadius.circular(7),
              ),
              child: Icon(Icons.spa_rounded, color: paper, size: size * .42),
            ),
          ),
        ),
      ],
    ),
  );
}

Color collectionColor(String theme) => switch (theme) {
  'cosmos' => const Color(0xFF7661B5),
  'ocean' => const Color(0xFF2589B2),
  _ => teal,
};

class ModeTile extends StatelessWidget {
  const ModeTile({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.onTap,
  });
  final IconData icon;
  final String title, subtitle;
  final bool selected;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final accent = switch (title) {
      'In due' => coral,
      'Online' => const Color(0xFF7661B5),
      'Bluetooth' => const Color(0xFF2589B2),
      _ => teal,
    };
    return Semantics(
      selected: selected,
      button: true,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: accent.withValues(alpha: .20),
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Material(
          color: Color.lerp(paper, accent, .10),
          borderRadius: BorderRadius.circular(24),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(24),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: accent.withValues(alpha: .25),
                  width: 1.5,
                ),
              ),
              child: LayoutBuilder(
                builder: (context, c) => Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Center(
                        child: _ModeEmblem(
                          icon: icon,
                          color: accent,
                          compact: c.maxHeight < 110,
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            title,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        Icon(
                          Icons.arrow_forward_rounded,
                          color: accent,
                          size: 18,
                        ),
                      ],
                    ),
                    Text(
                      subtitle,
                      style: const TextStyle(fontSize: 12, color: ink),
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

class _ModeEmblem extends StatelessWidget {
  const _ModeEmblem({
    required this.icon,
    required this.color,
    required this.compact,
  });
  final IconData icon;
  final Color color;
  final bool compact;
  @override
  Widget build(BuildContext context) => FittedBox(
    fit: BoxFit.scaleDown,
    child: SizedBox(
      width: 110,
      height: compact ? 48 : 88,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned(
            left: 12,
            top: compact ? 1 : 9,
            child: Transform.rotate(
              angle: -.20,
              child: Container(
                width: compact ? 33 : 49,
                height: compact ? 40 : 65,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: .28),
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
          Transform.rotate(
            angle: .12,
            child: Container(
              width: compact ? 40 : 57,
              height: compact ? 44 : 73,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: Colors.white.withValues(alpha: .7),
                  width: 2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: color.withValues(alpha: .25),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              padding: const EdgeInsets.all(4),
              child: _CollectionSymbol(
                theme: icon == Icons.public_rounded
                    ? 'cosmos'
                    : icon == Icons.bluetooth_rounded
                    ? 'ocean'
                    : 'garden',
                value: icon == Icons.people_outline_rounded ? 1 : 0,
                size: compact ? 30 : 46,
              ),
            ),
          ),
          Positioned(
            right: 5,
            top: 1,
            child: Icon(
              Icons.star_rounded,
              size: compact ? 15 : 20,
              color: coral,
            ),
          ),
          Positioned(
            left: 4,
            bottom: 6,
            child: Container(
              width: 7,
              height: 7,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
          ),
        ],
      ),
    ),
  );
}

class MemoryCard extends StatefulWidget {
  const MemoryCard({
    super.key,
    required this.index,
    required this.value,
    required this.theme,
    required this.matched,
    this.onTap,
  });
  final int index;
  final int? value;
  final String theme;
  final bool matched;
  final VoidCallback? onTap;
  @override
  State<MemoryCard> createState() => _MemoryCardState();
}

class _MemoryCardState extends State<MemoryCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController flip;
  int? faceValue;
  bool reduceMotion = false;
  @override
  void initState() {
    super.initState();
    faceValue = widget.value;
    flip = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 320),
      value: widget.value == null ? 0 : 1,
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    reduceMotion = MediaQuery.disableAnimationsOf(context);
    if (reduceMotion) flip.value = widget.value == null ? 0 : 1;
  }

  @override
  void didUpdateWidget(MemoryCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.value != null) faceValue = widget.value;
    if ((oldWidget.value == null) != (widget.value == null)) {
      final target = widget.value == null ? 0.0 : 1.0;
      if (reduceMotion) {
        flip.value = target;
      } else {
        flip.animateTo(target, curve: Curves.easeInOutCubic);
      }
    }
  }

  @override
  void dispose() {
    flip.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Semantics(
    label: widget.matched
        ? 'Coppia trovata'
        : widget.value != null
        ? 'Carta ${widget.index + 1}, ${deckLabel(widget.theme, widget.value!) ?? 'simbolo ${widget.value! + 1}'}'
        : 'Carta ${widget.index + 1}, coperta',
    button: widget.onTap != null,
    child: AnimatedBuilder(
      animation: flip,
      builder: (context, _) {
        final front = flip.value >= .5;
        final angle = flip.value * math.pi;
        return Transform(
          key: ValueKey('flip-${widget.index}'),
          alignment: Alignment.center,
          transform: Matrix4.identity()
            ..setEntry(3, 2, .0015)
            ..rotateY(angle),
          child: Transform(
            alignment: Alignment.center,
            transform: Matrix4.rotationY(front ? math.pi : 0),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: widget.onTap == null || flip.isAnimating
                    ? null
                    : widget.onTap,
                borderRadius: BorderRadius.circular(13),
                child: AnimatedContainer(
                  duration: reduceMotion
                      ? Duration.zero
                      : const Duration(milliseconds: 220),
                  decoration: BoxDecoration(
                    color: front
                        ? (widget.matched
                              ? const Color(0xFFE5F3DC)
                              : Colors.white)
                        : collectionColor(widget.theme),
                    borderRadius: BorderRadius.circular(13),
                    border: Border.all(
                      color: widget.matched
                          ? const Color(0xFF83B66B)
                          : front
                          ? collectionColor(widget.theme).withValues(alpha: .25)
                          : Colors.white.withValues(alpha: .5),
                      width: widget.matched ? 2 : 1.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: collectionColor(
                          widget.theme,
                        ).withValues(alpha: widget.matched ? .06 : .19),
                        offset: const Offset(0, 3),
                        blurRadius: 1,
                      ),
                    ],
                  ),
                  child: LayoutBuilder(
                    builder: (context, c) {
                      final side = math.min(c.maxWidth, c.maxHeight);
                      if (front && faceValue != null) {
                        return Stack(
                          fit: StackFit.expand,
                          children: [
                            Padding(
                              padding: EdgeInsets.all(side * .12),
                              child: _CollectionSymbol(
                                theme: widget.theme,
                                value: faceValue!,
                                size: side * .66,
                              ),
                            ),
                            if (widget.matched)
                              Positioned(
                                right: 2,
                                bottom: 2,
                                child: Icon(
                                  Icons.check_circle_rounded,
                                  color: const Color(0xFF65974E),
                                  size: math.max(11, side * .19),
                                ),
                              ),
                          ],
                        );
                      }
                      return ClipRRect(
                        borderRadius: BorderRadius.circular(11),
                        child: CustomPaint(
                          painter: BackPattern(theme: widget.theme),
                          child: Center(
                            child: Container(
                              width: side * .56,
                              height: side * .56,
                              decoration: BoxDecoration(
                                color: paper.withValues(alpha: .13),
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: paper.withValues(alpha: .55),
                                ),
                              ),
                              child: Icon(
                                switch (widget.theme) {
                                  'cosmos' => Icons.auto_awesome_rounded,
                                  'ocean' => Icons.water_rounded,
                                  _ => Icons.pets_rounded,
                                },
                                color: paper,
                                size: side * .32,
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
          ),
        );
      },
    ),
  );
}

class _CollectionSymbol extends StatelessWidget {
  const _CollectionSymbol({
    required this.theme,
    required this.value,
    required this.size,
  });
  final String theme;
  final int value;
  final double size;
  @override
  Widget build(BuildContext context) {
    final path = deckAsset(theme, value);
    if (path != null) {
      return Image.asset(
        path,
        width: size,
        height: size,
        fit: BoxFit.contain,
        filterQuality: FilterQuality.medium,
        excludeFromSemantics: true,
      );
    }
    return Icon(
      symbols[theme]![value % 18],
      color: symbolColors[value % symbolColors.length],
      size: size,
    );
  }
}

class _CollectionTile extends StatelessWidget {
  const _CollectionTile({
    required this.theme,
    required this.onTap,
    this.selected = false,
  });
  final String theme;
  final VoidCallback onTap;
  final bool selected;
  @override
  Widget build(BuildContext context) {
    final color = collectionColor(theme);
    return Material(
      color: Color.lerp(paper, color, .09),
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          height: 76,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: color.withValues(alpha: selected ? .7 : .23),
              width: selected ? 2 : 1,
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text(
                      'Collezione',
                      style: TextStyle(fontSize: 11, color: muted),
                    ),
                    Text(
                      deckNames[theme]!,
                      style: const TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(
                width: 112,
                height: 58,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    for (var i = 0; i < 3; i++)
                      Positioned(
                        left: i * 31.0,
                        top: i == 1 ? 0 : 7,
                        child: Transform.rotate(
                          angle: (i - 1) * .16,
                          child: Container(
                            width: 44,
                            height: 49,
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: color.withValues(alpha: .2),
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: color.withValues(alpha: .13),
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: _CollectionSymbol(
                              theme: theme,
                              value: i,
                              size: 35,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 4),
              Icon(
                selected
                    ? Icons.check_circle_rounded
                    : Icons.chevron_right_rounded,
                color: color,
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class BackPattern extends CustomPainter {
  const BackPattern({this.theme = 'garden'});
  final String theme;
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = paper.withValues(alpha: .18)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    for (double x = 8; x < size.width; x += 19) {
      for (double y = 8; y < size.height; y += 20) {
        if (theme == 'cosmos') {
          canvas.drawLine(Offset(x - 2, y), Offset(x + 2, y), paint);
          canvas.drawLine(Offset(x, y - 2), Offset(x, y + 2), paint);
        } else if (theme == 'ocean') {
          canvas.drawArc(
            Rect.fromCircle(center: Offset(x, y), radius: 5),
            0,
            math.pi,
            false,
            paint,
          );
        } else {
          canvas.drawOval(
            Rect.fromCenter(center: Offset(x, y), width: 4, height: 7),
            paint,
          );
        }
      }
    }
  }

  @override
  bool shouldRepaint(BackPattern oldDelegate) => oldDelegate.theme != theme;
}

class GameScreen extends StatefulWidget {
  const GameScreen({
    super.key,
    required this.prefs,
    required this.pairs,
    required this.theme,
    required this.mode,
    this.online,
    this.bluetooth,
  });
  final SharedPreferences prefs;
  final int pairs;
  final String theme;
  final PlayMode mode;
  final OnlineGame? online;
  final BluetoothController? bluetooth;
  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> with WidgetsBindingObserver {
  LocalGame? local;
  bool recorded = false;
  Map<String, dynamic>? get net =>
      widget.online?.state ?? widget.bluetooth?.state;
  String? get playerId => widget.online?.playerId ?? widget.bluetooth?.playerId;
  bool get network => widget.online != null || widget.bluetooth != null;
  bool get connected =>
      widget.online?.connected ?? widget.bluetooth?.connected ?? true;
  String get gameTheme => net?['theme'] as String? ?? widget.theme;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    if (!network) _startLocal();
    widget.online?.addListener(update);
    widget.bluetooth?.addListener(update);
  }

  void _startLocal() {
    local?.removeListener(update);
    local?.dispose();
    local = LocalGame(
      pairs: widget.pairs,
      twoPlayers: widget.mode == PlayMode.local,
    )..addListener(update);
    recorded = false;
  }

  void update() {
    if (!mounted) return;
    if (local?.finished == true && !recorded) {
      recorded = true;
      if (widget.mode == PlayMode.solo) {
        final key = 'best.${widget.pairs}';
        final best = widget.prefs.getInt(key);
        if (best == null || local!.moves < best) {
          widget.prefs.setInt(key, local!.moves);
        }
      }
    }
    setState(() {});
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed &&
        widget.online != null &&
        !widget.online!.connected) {
      widget.online!.open(null);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    local?.dispose();
    widget.online?.removeListener(update);
    widget.bluetooth?.removeListener(update);
    super.dispose();
  }

  Future<void> exit() async {
    if (!network && local!.finished) {
      if (mounted) Navigator.pop(context);
      return;
    }
    final choice = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Una pausa?'),
        content: Text(
          network
              ? 'Se abbandoni, l’altro giocatore vince la partita. Online puoi anche chiudere e riconnetterti entro 90 secondi.'
              : 'La partita in corso non verrà salvata.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Resta'),
          ),
          if (widget.online != null)
            TextButton(
              onPressed: () => Navigator.pop(context, 'pause'),
              child: const Text('Pausa'),
            ),
          TextButton(
            onPressed: () => Navigator.pop(context, 'leave'),
            child: const Text('Abbandona'),
          ),
        ],
      ),
    );
    if (choice == null) return;
    if (choice == 'leave') {
      await widget.online?.leave();
      await widget.bluetooth?.leave();
    }
    if (mounted) Navigator.pop(context);
  }

  void flip(int i) {
    if (widget.prefs.getBool('haptics') ?? true) {
      HapticFeedback.selectionClick();
    }
    if (local != null) {
      local!.flip(i);
    } else if (widget.online != null) {
      widget.online!.flip(i);
    } else {
      widget.bluetooth!.flip(i);
    }
  }

  void replay() {
    if (local != null) {
      setState(_startLocal);
    } else if (widget.online != null) {
      widget.online!.rematch();
    } else {
      widget.bluetooth!.rematch();
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = net;
    final waiting = network && (s == null || s['phase'] == 'waiting');
    final finished = local?.finished ?? s?['phase'] == 'finished';
    final players =
        (s?['players'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    final active = network ? (s?['turn'] == playerId) : true;
    final paused = network && players.any((p) => p['connected'] != true);
    final cards = local != null
        ? [
            for (var i = 0; i < local!.deck.length; i++)
              if (local!.matched.contains(i) || local!.selected.contains(i))
                local!.deck[i]
              else
                null,
          ]
        : (s?['cards'] as List? ?? [])
              .map((v) => v == null ? null : int.parse(v.toString()))
              .toList();
    final matched =
        local?.matched ?? (s?['matched'] as List? ?? []).cast<int>().toSet();
    final error = widget.online?.error ?? widget.bluetooth?.error;
    final code = s?['code']?.toString() ?? widget.online?.code;
    final vote = (s?['rematch'] as List? ?? []).contains(playerId);
    String result = 'Partita completata';
    if (finished && network) {
      result = s?['winnerId'] == null
          ? 'Pareggio'
          : s?['winnerId'] == playerId
          ? 'Hai vinto!'
          : 'Hai perso';
    }
    if (finished && local?.twoPlayers == true) {
      result = local!.scores[0] == local!.scores[1]
          ? 'Pareggio'
          : 'Vince Giocatore ${local!.scores[0] > local!.scores[1] ? 1 : 2}!';
    }
    final status = network
        ? paused
              ? 'In attesa della riconnessione…'
              : active
              ? 'Il tuo turno'
              : 'Turno di ${players.where((p) => p['id'] == s?['turn']).firstOrNull?['name'] ?? 'un amico'}'
        : widget.mode == PlayMode.local
        ? 'Turno del Giocatore ${local!.turn + 1}'
        : '${matched.length ~/ 2} / ${widget.pairs} coppie';
    Future<void> copyInvite() async {
      await Clipboard.setData(
        ClipboardData(text: 'https://mymemory.sommomi.cc/?room=$code'),
      );
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Invito copiato')));
      }
    }

    final scores = Row(
      children: [
        if (local != null && widget.mode == PlayMode.solo) ...[
          Expanded(
            child: StatBox(
              label: 'COPPIE',
              value: '${matched.length ~/ 2} / ${widget.pairs}',
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: StatBox(label: 'TENTATIVI', value: '${local!.moves}'),
          ),
        ] else if (local != null) ...[
          for (var p = 0; p < 2; p++) ...[
            if (p > 0) const SizedBox(width: 8),
            Expanded(
              child: StatBox(
                label: 'GIOCATORE ${p + 1}',
                value: '${local!.scores[p]}',
                active: !finished && local!.turn == p,
              ),
            ),
          ],
        ] else ...[
          for (var p = 0; p < players.length; p++) ...[
            if (p > 0) const SizedBox(width: 8),
            Expanded(
              child: StatBox(
                label:
                    '${players[p]['name']}${players[p]['id'] == playerId ? ' · TU' : ''}',
                value: '${players[p]['score']}',
                active: !finished && players[p]['id'] == s?['turn'],
              ),
            ),
          ],
        ],
      ],
    );
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) exit();
      },
      child: Scaffold(
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1100),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 4, 12, 10),
                child: Column(
                  children: [
                    Row(
                      children: [
                        IconButton(
                          onPressed: exit,
                          tooltip: 'Torna alla home',
                          icon: const Icon(Icons.arrow_back_rounded),
                        ),
                        Container(
                          width: 32,
                          height: 32,
                          padding: const EdgeInsets.all(3),
                          decoration: BoxDecoration(
                            color: collectionColor(
                              gameTheme,
                            ).withValues(alpha: .12),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: _CollectionSymbol(
                            theme: gameTheme,
                            value: 0,
                            size: 26,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            deckNames[gameTheme]!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        if (!network)
                          Text(
                            clockText(local!.seconds),
                            style: const TextStyle(color: muted),
                          ),
                        if (network)
                          Icon(
                            widget.mode == PlayMode.bluetooth
                                ? Icons.bluetooth_rounded
                                : Icons.public_rounded,
                            color: connected ? teal : coral,
                            size: 20,
                          ),
                        if (code != null && widget.online != null)
                          IconButton(
                            tooltip: 'Copia invito · $code',
                            onPressed: copyInvite,
                            icon: const Icon(Icons.ios_share_rounded, size: 20),
                          ),
                      ],
                    ),
                    if (error != null || !connected && network)
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              error ??
                                  widget.online?.status ??
                                  widget.bluetooth?.status ??
                                  'Connessione…',
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: coral,
                                fontSize: 13,
                              ),
                            ),
                          ),
                          if (widget.online != null && !connected)
                            IconButton(
                              tooltip: 'Riprova connessione',
                              onPressed: () => widget.online!.open(null),
                              icon: const Icon(Icons.refresh_rounded),
                            ),
                        ],
                      ),
                    if (waiting)
                      Expanded(
                        child: LayoutBuilder(
                          builder: (context, c) => Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (c.maxHeight > 300) ...[
                                  const Icon(
                                    Icons.people_outline_rounded,
                                    size: 56,
                                    color: teal,
                                  ),
                                  const SizedBox(height: 20),
                                ],
                                Text(
                                  s == null
                                      ? 'Connessione alla partita…'
                                      : 'In attesa del secondo giocatore',
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    fontSize: 21,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  widget.mode == PlayMode.bluetooth
                                      ? 'Sul secondo telefono scegli Bluetooth e cerca la partita.'
                                      : 'Condividi il codice per entrare nella stanza.',
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(color: muted),
                                ),
                                if (code != null) ...[
                                  const SizedBox(height: 12),
                                  SelectableText(
                                    code,
                                    style: const TextStyle(
                                      fontSize: 34,
                                      letterSpacing: 5,
                                      fontWeight: FontWeight.w600,
                                      color: teal,
                                    ),
                                  ),
                                  if (widget.online != null)
                                    TextButton.icon(
                                      onPressed: copyInvite,
                                      icon: const Icon(
                                        Icons.copy_rounded,
                                        size: 18,
                                      ),
                                      label: const Text('Copia invito'),
                                    ),
                                ],
                              ],
                            ),
                          ),
                        ),
                      ),
                    if (!waiting) ...[
                      const SizedBox(height: 4),
                      scores,
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Text(
                          finished ? 'Partita terminata' : status,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: teal, fontSize: 13),
                        ),
                      ),
                      Expanded(
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            _FittedBoard(
                              count: cards.length,
                              itemBuilder: (i) => MemoryCard(
                                key: ValueKey('card-$i'),
                                index: i,
                                value: cards[i],
                                theme: gameTheme,
                                matched: matched.contains(i),
                                onTap:
                                    finished ||
                                        matched.contains(i) ||
                                        cards[i] != null ||
                                        network &&
                                            (!active ||
                                                !connected ||
                                                paused ||
                                                s?['lockedUntil'] != null)
                                    ? null
                                    : () => flip(i),
                              ),
                            ),
                            if (finished)
                              Center(
                                child: Container(
                                  constraints: const BoxConstraints(
                                    maxWidth: 380,
                                  ),
                                  padding: const EdgeInsets.all(18),
                                  decoration: BoxDecoration(
                                    color: paper,
                                    borderRadius: BorderRadius.circular(24),
                                    border: Border.all(color: line),
                                    boxShadow: [
                                      BoxShadow(
                                        color: ink.withValues(alpha: .18),
                                        blurRadius: 24,
                                      ),
                                    ],
                                  ),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Row(
                                        children: [
                                          const Icon(
                                            Icons.stars_rounded,
                                            color: Color(0xFFDAA12D),
                                            size: 32,
                                          ),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: Text(
                                              result,
                                              textAlign: TextAlign.center,
                                              style: const TextStyle(
                                                fontSize: 23,
                                                fontWeight: FontWeight.w700,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        local != null
                                            ? '${clockText(local!.seconds)} · ${local!.moves} tentativi'
                                            : s?['finishReason'] == 'forfeit'
                                            ? 'L’altro giocatore ha lasciato.'
                                            : 'Partita completata.',
                                        textAlign: TextAlign.center,
                                        style: const TextStyle(color: muted),
                                      ),
                                      const SizedBox(height: 12),
                                      FilledButton.icon(
                                        onPressed:
                                            vote ||
                                                network &&
                                                    players.any(
                                                      (p) =>
                                                          p['connected'] !=
                                                          true,
                                                    )
                                            ? null
                                            : replay,
                                        icon: const Icon(Icons.replay_rounded),
                                        label: Text(
                                          vote
                                              ? 'In attesa…'
                                              : 'Un’altra partita',
                                        ),
                                      ),
                                      if (network &&
                                          (s?['rematch'] as List? ?? [])
                                              .isNotEmpty &&
                                          !vote)
                                        const Padding(
                                          padding: EdgeInsets.only(top: 8),
                                          child: Text(
                                            'Rivincita richiesta',
                                            style: TextStyle(color: teal),
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
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

/// Fits every card inside the remaining viewport; the board has no scroll axis.
class _FittedBoard extends StatelessWidget {
  const _FittedBoard({required this.count, required this.itemBuilder});
  final int count;
  final Widget Function(int) itemBuilder;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, c) {
      if (count == 0) return const SizedBox.shrink();
      const gap = 6.0;
      var columns = 2;
      var cardWidth = 0.0;
      var cardHeight = 0.0;
      var area = 0.0;
      for (var n = 2; n <= math.min(count, 12); n++) {
        if (count % n != 0) continue;
        final rows = count ~/ n;
        final w = math.min(120.0, (c.maxWidth - gap * (n - 1)) / n);
        final h = math.min(138.0, (c.maxHeight - gap * (rows - 1)) / rows);
        final fitWidth = math.min(w, h * .9);
        final fitHeight = math.min(h, w / .9);
        final candidate = fitWidth * fitHeight;
        if (candidate > area) {
          area = candidate;
          columns = n;
          cardWidth = fitWidth;
          cardHeight = fitHeight;
        }
      }
      final rows = count ~/ columns;
      return Center(
        child: SizedBox(
          width: columns * cardWidth + (columns - 1) * gap,
          height: rows * cardHeight + (rows - 1) * gap,
          child: Column(
            children: [
              for (var row = 0; row < rows; row++) ...[
                if (row > 0) const SizedBox(height: gap),
                Row(
                  children: [
                    for (var column = 0; column < columns; column++) ...[
                      if (column > 0) const SizedBox(width: gap),
                      SizedBox(
                        width: cardWidth,
                        height: cardHeight,
                        child: itemBuilder(row * columns + column),
                      ),
                    ],
                  ],
                ),
              ],
            ],
          ),
        ),
      );
    },
  );
}

class StatBox extends StatelessWidget {
  const StatBox({
    super.key,
    required this.label,
    required this.value,
    this.active = false,
  });
  final String label, value;
  final bool active;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    decoration: BoxDecoration(
      color: active ? teal.withValues(alpha: .08) : Colors.white,
      border: Border.all(color: active ? teal : line),
      borderRadius: BorderRadius.circular(14),
    ),
    child: Row(
      children: [
        Expanded(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 11,
              color: active ? teal : muted,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          value,
          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w600),
        ),
      ],
    ),
  );
}

class BluetoothLobby extends StatefulWidget {
  const BluetoothLobby({
    super.key,
    required this.prefs,
    required this.name,
    required this.pairs,
    required this.theme,
  });
  final SharedPreferences prefs;
  final String name, theme;
  final int pairs;
  @override
  State<BluetoothLobby> createState() => _BluetoothLobbyState();
}

class _BluetoothLobbyState extends State<BluetoothLobby> {
  final ble = BluetoothController();
  bool busy = false;
  @override
  void initState() {
    super.initState();
    ble.addListener(update);
  }

  void update() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    ble.removeListener(update);
    ble.dispose();
    super.dispose();
  }

  Future<void> connect({BluetoothPeer? peer}) async {
    setState(() => busy = true);
    try {
      if (peer == null) {
        await ble.host(widget.name, widget.pairs, widget.theme);
      } else {
        await ble.join(peer, widget.name);
      }
      if (!mounted || ble.error != null) return;
      await Navigator.push(
        context,
        MaterialPageRoute<void>(
          builder: (_) => GameScreen(
            prefs: widget.prefs,
            pairs: widget.pairs,
            theme: widget.theme,
            mode: PlayMode.bluetooth,
            bluetooth: ble,
          ),
        ),
      );
      await ble.leave();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Bluetooth non disponibile. Controlla permessi e connessione.',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Partita Bluetooth'),
      actions: [
        IconButton(
          tooltip: 'Aiuto Bluetooth',
          icon: const Icon(Icons.help_outline_rounded),
          onPressed: () => showDialog<void>(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Connessione Bluetooth'),
              content: const Text(
                'Attiva il Bluetooth e tieni le due app aperte. Un giocatore ospita, l’altro cerca.\n\nSe la partita non compare, scambiate i ruoli: alcuni Android non possono ospitare. Sui modelli meno recenti può servire il permesso di posizione.',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Chiudi'),
                ),
              ],
            ),
          ),
        ),
      ],
    ),
    body: SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 800),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: Column(
              children: [
                const Text(
                  'Un telefono ospita, l’altro cerca la partita.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: muted),
                ),
                const SizedBox(height: 12),
                LayoutBuilder(
                  builder: (context, c) {
                    final host = FilledButton.icon(
                      onPressed: busy ? null : () => connect(),
                      icon: const Icon(Icons.add_rounded),
                      label: const Text('Ospita partita'),
                    );
                    final scan = OutlinedButton.icon(
                      onPressed: busy ? null : () => ble.scan(),
                      icon: const Icon(Icons.radar_rounded),
                      label: Text(
                        ble.scanning ? 'Aggiorna ricerca' : 'Cerca partita',
                      ),
                    );
                    if (c.maxWidth > 500) {
                      return Row(
                        children: [
                          Expanded(child: host),
                          const SizedBox(width: 12),
                          Expanded(child: scan),
                        ],
                      );
                    }
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [host, const SizedBox(height: 8), scan],
                    );
                  },
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    if (ble.scanning)
                      const Padding(
                        padding: EdgeInsets.only(right: 10),
                        child: SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      ),
                    Expanded(
                      child: Text(
                        ble.error ?? ble.status,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: ble.error == null ? teal : coral,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: _NearbyPeers(
                    peers: ble.peers,
                    onJoin: busy ? null : (peer) => connect(peer: peer),
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

class _NearbyPeers extends StatefulWidget {
  const _NearbyPeers({required this.peers, required this.onJoin});
  final List<BluetoothPeer> peers;
  final void Function(BluetoothPeer)? onJoin;
  @override
  State<_NearbyPeers> createState() => _NearbyPeersState();
}

class _NearbyPeersState extends State<_NearbyPeers> {
  int page = 0;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, c) {
      if (widget.peers.isEmpty) {
        return const Center(
          child: Text(
            'Nessuna partita trovata',
            style: TextStyle(color: muted),
          ),
        );
      }
      final perPage = math.max(1, ((c.maxHeight - 48) / 64).floor());
      final pages = (widget.peers.length / perPage).ceil();
      final current = math.min(page, pages - 1);
      final peers = widget.peers.skip(current * perPage).take(perPage);
      return Column(
        children: [
          Expanded(
            child: Column(
              children: [
                for (final peer in peers)
                  SizedBox(
                    height: 64,
                    child: ListTile(
                      leading: const Icon(
                        Icons.smartphone_rounded,
                        color: teal,
                      ),
                      title: Text(
                        peer.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      trailing: const Icon(Icons.arrow_forward_rounded),
                      onTap: widget.onJoin == null
                          ? null
                          : () => widget.onJoin!(peer),
                    ),
                  ),
              ],
            ),
          ),
          if (pages > 1)
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  tooltip: 'Precedenti',
                  onPressed: current == 0
                      ? null
                      : () => setState(() => page = current - 1),
                  icon: const Icon(Icons.chevron_left_rounded),
                ),
                Text('${current + 1} / $pages'),
                IconButton(
                  tooltip: 'Successive',
                  onPressed: current + 1 == pages
                      ? null
                      : () => setState(() => page = current + 1),
                  icon: const Icon(Icons.chevron_right_rounded),
                ),
              ],
            ),
        ],
      );
    },
  );
}
