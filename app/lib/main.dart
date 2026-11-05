import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'game.dart';
import 'online.dart';
import 'palette.dart';
import 'bluetooth/bluetooth_controller.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
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
  late final TextEditingController name;
  final room = TextEditingController();
  @override
  void initState() {
    super.initState();
    name = TextEditingController(text: widget.prefs.getString('name') ?? '');
    final invite = Uri.base.queryParameters['room'];
    if (invite != null) {
      mode = PlayMode.online;
      room.text = invite;
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

  void settings() => showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (context) => StatefulBuilder(
      builder: (context, change) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 30),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Il tuo piccolo rituale',
                style: TextStyle(fontSize: 25, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 14),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Feedback tattile'),
                subtitle: const Text(
                  'Una piccola vibrazione quando giri le carte',
                ),
                value: widget.prefs.getBool('haptics') ?? true,
                onChanged: (v) {
                  widget.prefs.setBool('haptics', v);
                  change(() {});
                },
              ),
              const Divider(),
              const Text(
                'Come si gioca',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 18),
              ),
              const SizedBox(height: 8),
              const Text(
                'Gira due carte e trova le coppie. Se trovi una coppia, giochi ancora. In due, un errore passa il turno all’altro giocatore.\n\nOnline puoi condividere il codice con chiunque, anche da un altro tipo di telefono. Per giocare senza Internet scegli Bluetooth nelle app Android e iOS.',
              ),
              const SizedBox(height: 16),
              TextButton(
                onPressed: () => showAboutDialog(
                  context: context,
                  applicationName: 'MyMemory',
                  applicationVersion: '3.0.0',
                  children: [
                    const Text(
                      'Un gioco di Michele Tagliabue.\n\nLe partite locali restano sul dispositivo. Online condividiamo solo nome scelto, mosse e stato della stanza. Nessuna pubblicità o analisi di utilizzo. Le stanze inattive vengono eliminate.\n\nPrivacy e assistenza: mymemory.sommomi.cc/privacy\nContatto: mikitg.michele@gmail.com',
                    ),
                  ],
                ),
                child: const Text('Informazioni, privacy e licenze'),
              ),
            ],
          ),
        ),
      ),
    ),
  );
  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1100),
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const BrandMark(),
                    const SizedBox(width: 10),
                    const Text(
                      'my memory',
                      style: TextStyle(
                        fontSize: 25,
                        fontWeight: FontWeight.w600,
                        letterSpacing: -1,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      tooltip: 'Come si gioca e impostazioni',
                      onPressed: settings,
                      icon: const Icon(Icons.tune_rounded, color: ink),
                    ),
                  ],
                ),
                const SizedBox(height: 36),
                LayoutBuilder(
                  builder: (context, c) {
                    final wide = c.maxWidth > 760;
                    final intro = Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Capsule(
                          label: 'PICCOLE COPPIE. GRANDI SORRISI.',
                          color: teal,
                        ),
                        const SizedBox(height: 18),
                        Text(
                          'Un momento per\nritrovarsi.',
                          style: TextStyle(
                            fontSize: wide ? 66 : 43,
                            height: 1.04,
                            fontWeight: FontWeight.w600,
                            letterSpacing: -2.4,
                            color: ink,
                          ),
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'Allena la memoria, segui l’intuito.\nE sfida qualcuno a fare lo stesso.',
                          style: TextStyle(
                            fontSize: 18,
                            height: 1.5,
                            color: muted,
                          ),
                        ),
                        const SizedBox(height: 22),
                        const Row(
                          children: [
                            Icon(
                              Icons.favorite_outline_rounded,
                              size: 16,
                              color: coral,
                            ),
                            SizedBox(width: 7),
                            Expanded(
                              child: Text(
                                'Il classico memory, di nuovo insieme.',
                                style: TextStyle(color: muted, fontSize: 13),
                              ),
                            ),
                          ],
                        ),
                      ],
                    );
                    return wide
                        ? Row(
                            children: [
                              Expanded(child: intro),
                              const Expanded(child: HeroCards()),
                            ],
                          )
                        : Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              intro,
                              const SizedBox(height: 8),
                              const SizedBox(height: 190, child: HeroCards()),
                            ],
                          );
                  },
                ),
                const SizedBox(height: 28),
                Container(
                  padding: const EdgeInsets.all(22),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(28),
                    border: Border.all(color: line),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Scegli il tuo momento',
                              style: TextStyle(
                                fontSize: 23,
                                fontWeight: FontWeight.w600,
                                letterSpacing: -.5,
                              ),
                            ),
                          ),
                          Icon(Icons.more_horiz_rounded, color: muted),
                        ],
                      ),
                      const SizedBox(height: 18),
                      LayoutBuilder(
                        builder: (context, c) {
                          final modes = [
                            (
                              PlayMode.solo,
                              Icons.self_improvement_rounded,
                              'Solo tu',
                              'Al tuo ritmo',
                            ),
                            (
                              PlayMode.local,
                              Icons.people_outline_rounded,
                              'In due',
                              'Un dispositivo',
                            ),
                            (
                              PlayMode.online,
                              Icons.public_rounded,
                              'Online',
                              'Vicini, ovunque',
                            ),
                            if (BluetoothController.supported)
                              (
                                PlayMode.bluetooth,
                                Icons.bluetooth_rounded,
                                'Bluetooth',
                                'Senza Internet',
                              ),
                          ];
                          final columns = c.maxWidth > 650 ? modes.length : 2;
                          return Wrap(
                            spacing: 10,
                            runSpacing: 10,
                            children: [
                              for (final m in modes)
                                SizedBox(
                                  width:
                                      (c.maxWidth - 10 * (columns - 1)) /
                                      columns,
                                  child: ModeTile(
                                    icon: m.$2,
                                    title: m.$3,
                                    subtitle: m.$4,
                                    selected: mode == m.$1,
                                    onTap: () => setState(() => mode = m.$1),
                                  ),
                                ),
                            ],
                          );
                        },
                      ),
                      const SizedBox(height: 24),
                      const Text(
                        'QUANTE COPPIE?',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 1.6,
                          color: muted,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final p in [6, 8, 12, 18])
                            ChoiceChip(
                              label: Text(
                                '$p  ${switch (p) {
                                  6 => 'Facile',
                                  8 => 'Classico',
                                  12 => 'Sfida',
                                  _ => 'Esperto',
                                }}',
                              ),
                              selected: pairs == p,
                              onSelected: (_) => setState(() => pairs = p),
                              showCheckmark: false,
                            ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      const Text(
                        'UN MONDO DA SCOPRIRE',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 1.6,
                          color: muted,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final t in themeNames.keys)
                            ChoiceChip(
                              avatar: Icon(
                                themeIcons[t],
                                size: 18,
                                color: theme == t ? teal : muted,
                              ),
                              label: Text(themeNames[t]!),
                              selected: theme == t,
                              onSelected: (_) => setState(() => theme = t),
                              showCheckmark: false,
                            ),
                        ],
                      ),
                      if (mode == PlayMode.online ||
                          mode == PlayMode.bluetooth) ...[
                        const SizedBox(height: 22),
                        TextField(
                          controller: name,
                          maxLength: 20,
                          textCapitalization: TextCapitalization.words,
                          decoration: const InputDecoration(
                            labelText: 'Come ti chiami?',
                            hintText: 'Il tuo nome per la partita',
                            counterText: '',
                          ),
                        ),
                      ],
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton(
                          onPressed: () => start(),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(switch (mode) {
                                PlayMode.online => 'Crea una stanza',
                                PlayMode.bluetooth => 'Trova un amico',
                                _ => 'Giochiamo',
                              }),
                              const SizedBox(width: 10),
                              const Icon(Icons.arrow_forward_rounded, size: 20),
                            ],
                          ),
                        ),
                      ),
                      if (mode == PlayMode.online) ...[
                        const SizedBox(height: 18),
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: room,
                                maxLength: 6,
                                textCapitalization:
                                    TextCapitalization.characters,
                                decoration: const InputDecoration(
                                  labelText: 'Hai già un codice?',
                                  hintText: 'ABC123',
                                  counterText: '',
                                ),
                                onSubmitted: (_) => start(join: true),
                              ),
                            ),
                            const SizedBox(width: 10),
                            IconButton.filledTonal(
                              tooltip: 'Entra nella stanza',
                              onPressed: () => start(join: true),
                              icon: const Icon(Icons.login_rounded),
                            ),
                          ],
                        ),
                        if (widget.prefs.getString('room.token') != null)
                          TextButton.icon(
                            onPressed: () => start(resume: true),
                            icon: const Icon(Icons.restore_rounded),
                            label: Text(
                              'Riprendi la stanza ${widget.prefs.getString('room.code')}',
                            ),
                          ),
                      ],
                      if (mode == PlayMode.solo &&
                          widget.prefs.getInt('best.$pairs') != null) ...[
                        const SizedBox(height: 12),
                        Center(
                          child: Text(
                            'Il tuo record: ${widget.prefs.getInt('best.$pairs')} tentativi',
                            style: const TextStyle(color: muted),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                const Center(
                  child: Text(
                    'Fatto per giocare. Senza fretta.',
                    style: TextStyle(fontSize: 13, color: muted),
                  ),
                ),
                const SizedBox(height: 14),
              ],
            ),
          ),
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

class Capsule extends StatelessWidget {
  const Capsule({super.key, required this.label, required this.color});
  final String label;
  final Color color;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
    decoration: BoxDecoration(
      color: color.withValues(alpha: .09),
      borderRadius: BorderRadius.circular(30),
    ),
    child: Text(
      label,
      style: TextStyle(
        color: color,
        fontSize: 10,
        letterSpacing: 1.1,
        fontWeight: FontWeight.w600,
      ),
    ),
  );
}

class HeroCards extends StatelessWidget {
  const HeroCards({super.key});
  @override
  Widget build(BuildContext context) => SizedBox(
    height: 290,
    child: LayoutBuilder(
      builder: (context, c) => Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: 230,
            height: 230,
            decoration: const BoxDecoration(
              color: Color(0xFFF0EDE2),
              shape: BoxShape.circle,
            ),
          ),
          Transform.translate(
            offset: const Offset(-65, 2),
            child: Transform.rotate(
              angle: -.19,
              child: const SizedBox(
                width: 110,
                height: 145,
                child: MemoryCard(
                  index: 0,
                  value: null,
                  theme: 'garden',
                  matched: false,
                ),
              ),
            ),
          ),
          Transform.translate(
            offset: const Offset(37, -16),
            child: Transform.rotate(
              angle: .14,
              child: const SizedBox(
                width: 110,
                height: 145,
                child: MemoryCard(
                  index: 1,
                  value: 0,
                  theme: 'garden',
                  matched: false,
                ),
              ),
            ),
          ),
          const Positioned(
            right: 25,
            top: 28,
            child: Icon(Icons.auto_awesome_rounded, color: coral, size: 26),
          ),
          const Positioned(
            left: 30,
            bottom: 40,
            child: Icon(Icons.more_horiz_rounded, color: teal, size: 28),
          ),
          Positioned(
            bottom: 16,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(30),
              ),
              child: const Row(
                children: [
                  Icon(Icons.check_circle_rounded, color: teal, size: 16),
                  SizedBox(width: 7),
                  Text(
                    'Una coppia alla volta.',
                    style: TextStyle(fontSize: 12, color: ink),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

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
  Widget build(BuildContext context) => Semantics(
    selected: selected,
    button: true,
    child: Material(
      color: selected ? teal.withValues(alpha: .07) : paper,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.all(15),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: selected ? teal : line,
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(icon, color: selected ? teal : ink, size: 25),
                  const Spacer(),
                  if (selected)
                    const Icon(
                      Icons.check_circle_rounded,
                      color: teal,
                      size: 16,
                    ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                title,
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                  color: selected ? teal : ink,
                ),
              ),
              Text(
                subtitle,
                style: const TextStyle(fontSize: 12, color: muted),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class MemoryCard extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final shown = value != null;
    final color = shown ? symbolColors[value! % symbolColors.length] : teal;
    return Semantics(
      label: matched
          ? 'Coppia trovata'
          : shown
          ? 'Carta ${index + 1}, simbolo ${value! + 1}'
          : 'Carta ${index + 1}, coperta',
      button: onTap != null,
      child: AnimatedOpacity(
        opacity: matched ? 0.45 : 1,
        duration: const Duration(milliseconds: 250),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(16),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              decoration: BoxDecoration(
                color: shown ? Colors.white : teal,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: shown ? color.withValues(alpha: .3) : teal,
                  width: 1.5,
                ),
                boxShadow: [
                  if (!matched)
                    BoxShadow(
                      color: ink.withValues(alpha: .06),
                      offset: const Offset(0, 5),
                      blurRadius: 12,
                    ),
                ],
              ),
              child: LayoutBuilder(
                builder: (context, c) {
                  final side = math.min(c.maxWidth, c.maxHeight);
                  if (shown) {
                    return Center(
                      child: Icon(
                        symbols[theme]![value! % 18],
                        color: color,
                        size: side * .49,
                      ),
                    );
                  }
                  return ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: CustomPaint(
                      painter: BackPattern(),
                      child: Center(
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: teal,
                            border: Border.all(
                              color: paper.withValues(alpha: .5),
                            ),
                            borderRadius: BorderRadius.circular(13),
                          ),
                          child: Icon(
                            Icons.spa_outlined,
                            color: paper.withValues(alpha: .9),
                            size: side * .29,
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
  }
}

class BackPattern extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = paper.withValues(alpha: .13)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    for (double x = -size.height; x < size.width + size.height; x += 19) {
      canvas.drawLine(Offset(x, 0), Offset(x + size.height, size.height), p);
      canvas.drawLine(Offset(x, 0), Offset(x - size.height, size.height), p);
    }
  }

  @override
  bool shouldRepaint(BackPattern oldDelegate) => false;
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
    String result = 'Ben fatto!';
    if (finished && network) {
      result = s?['winnerId'] == null
          ? 'Una bella parità.'
          : s?['winnerId'] == playerId
          ? 'Hai vinto!'
          : 'Bella sfida!';
    }
    if (finished && local?.twoPlayers == true) {
      result = local!.scores[0] == local!.scores[1]
          ? 'Una bella parità.'
          : 'Vince Giocatore ${local!.scores[0] > local!.scores[1] ? 1 : 2}!';
    }
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) exit();
      },
      child: Scaffold(
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 850),
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 30),
                child: Column(
                  children: [
                    Row(
                      children: [
                        IconButton(
                          onPressed: exit,
                          tooltip: 'Torna alla home',
                          icon: const Icon(Icons.arrow_back_rounded),
                        ),
                        const SizedBox(width: 8),
                        const BrandMark(size: 27),
                        const SizedBox(width: 8),
                        const Text(
                          'my memory',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const Spacer(),
                        if (!network)
                          Text(
                            clockText(local!.seconds),
                            style: const TextStyle(color: muted, fontSize: 16),
                          ),
                        if (network)
                          Icon(
                            widget.mode == PlayMode.bluetooth
                                ? Icons.bluetooth_rounded
                                : Icons.public_rounded,
                            color: connected ? teal : coral,
                            size: 21,
                          ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    Text(
                      themeNames[gameTheme]!,
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w600,
                        letterSpacing: -.7,
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (code != null && widget.online != null)
                      TextButton.icon(
                        onPressed: () async {
                          await Clipboard.setData(
                            ClipboardData(
                              text: 'https://mymemory.sommomi.cc/?room=$code',
                            ),
                          );
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Invito copiato. Mandalo a un amico!',
                                ),
                              ),
                            );
                          }
                        },
                        icon: const Icon(Icons.copy_rounded, size: 15),
                        label: Text('Stanza $code · copia invito'),
                      ),
                    if (error != null)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Text(
                          error,
                          style: const TextStyle(color: coral),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    if (!connected && network) ...[
                      Text(
                        widget.online?.status ??
                            widget.bluetooth?.status ??
                            'Connessione…',
                        style: const TextStyle(color: coral),
                      ),
                      if (widget.online != null)
                        TextButton(
                          onPressed: () => widget.online!.open(null),
                          child: const Text('Riprova connessione'),
                        ),
                    ],
                    if (waiting) ...[
                      const SizedBox(height: 30),
                      const Icon(
                        Icons.people_outline_rounded,
                        size: 65,
                        color: teal,
                      ),
                      const SizedBox(height: 20),
                      Text(
                        s == null
                            ? 'Prepariamo la partita…'
                            : 'Aspettando un amico',
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        widget.mode == PlayMode.bluetooth
                            ? 'Sul secondo telefono apri MyMemory → Bluetooth e cerca questa partita. Tieni le due app aperte.'
                            : 'Condividi il codice della stanza.\nIl tuo amico può entrare da Android, iPhone o browser.',
                        style: const TextStyle(
                          fontSize: 16,
                          height: 1.5,
                          color: muted,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      if (code != null) ...[
                        const SizedBox(height: 22),
                        SelectableText(
                          code,
                          style: const TextStyle(
                            fontSize: 42,
                            letterSpacing: 8,
                            fontWeight: FontWeight.w600,
                            color: teal,
                          ),
                        ),
                      ],
                      const SizedBox(height: 24),
                      const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                      const SizedBox(height: 50),
                    ] else ...[
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          if (local != null &&
                              widget.mode == PlayMode.solo) ...[
                            Expanded(
                              child: StatBox(
                                label: 'COPPIE',
                                value:
                                    '${matched.length ~/ 2} / ${widget.pairs}',
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: StatBox(
                                label: 'TENTATIVI',
                                value: '${local!.moves}',
                              ),
                            ),
                          ] else if (local != null) ...[
                            for (var p = 0; p < 2; p++) ...[
                              if (p > 0) const SizedBox(width: 10),
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
                              if (p > 0) const SizedBox(width: 10),
                              Expanded(
                                child: StatBox(
                                  label:
                                      '${players[p]['name']}${players[p]['id'] == playerId ? ' · TU' : ''}',
                                  value: '${players[p]['score']}',
                                  active:
                                      !finished &&
                                      players[p]['id'] == s?['turn'],
                                ),
                              ),
                            ],
                          ],
                        ],
                      ),
                      const SizedBox(height: 16),
                      if (!finished)
                        Text(
                          network
                              ? (paused
                                    ? 'In attesa della riconnessione…'
                                    : active
                                    ? 'Tocca a te. Trova una coppia!'
                                    : 'Tocca a ${players.where((p) => p['id'] == s?['turn']).firstOrNull?['name'] ?? 'un amico'}.')
                              : widget.mode == PlayMode.local
                              ? 'Tocca al Giocatore ${local!.turn + 1}'
                              : 'Gira due carte. Segui l’intuito.',
                          style: TextStyle(
                            color: active ? teal : muted,
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      if (finished)
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(20),
                          margin: const EdgeInsets.only(bottom: 18),
                          decoration: BoxDecoration(
                            color: teal.withValues(alpha: .08),
                            borderRadius: BorderRadius.circular(22),
                          ),
                          child: Column(
                            children: [
                              const Icon(
                                Icons.celebration_rounded,
                                color: coral,
                                size: 34,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                result,
                                style: const TextStyle(
                                  fontSize: 27,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 5),
                              Text(
                                local != null
                                    ? '${clockText(local!.seconds)} di concentrazione${widget.mode == PlayMode.solo ? ' · ${local!.moves} tentativi' : ''}'
                                    : s?['finishReason'] == 'forfeit'
                                    ? 'L’altro giocatore ha lasciato la partita.'
                                    : 'Ogni coppia conta. Ne facciamo un’altra?',
                                style: const TextStyle(color: muted),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 15),
                              FilledButton.icon(
                                onPressed:
                                    vote ||
                                        network &&
                                            players.any(
                                              (p) => p['connected'] != true,
                                            )
                                    ? null
                                    : replay,
                                icon: const Icon(Icons.replay_rounded),
                                label: Text(
                                  vote
                                      ? 'Aspettando la rivincita…'
                                      : 'Un’altra partita',
                                ),
                              ),
                              if (network &&
                                  (s?['rematch'] as List? ?? []).isNotEmpty &&
                                  !vote)
                                const Padding(
                                  padding: EdgeInsets.only(top: 10),
                                  child: Text(
                                    'Il tuo amico chiede la rivincita!',
                                    style: TextStyle(color: teal),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      const SizedBox(height: 12),
                      LayoutBuilder(
                        builder: (context, c) {
                          final count = cards.length > 24 ? 6 : 4;
                          final cardWidth =
                              (c.maxWidth - (count - 1) * 10) / count;
                          return GridView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: cards.length,
                            gridDelegate:
                                SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: count,
                                  crossAxisSpacing: 10,
                                  mainAxisSpacing: 10,
                                  mainAxisExtent: math.min(
                                    cardWidth * 1.15,
                                    130,
                                  ),
                                ),
                            itemBuilder: (context, i) => MemoryCard(
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
                          );
                        },
                      ),
                      const SizedBox(height: 22),
                      Text(
                        '${matched.length ~/ 2} coppie ritrovate',
                        style: const TextStyle(color: muted, fontSize: 13),
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
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
    decoration: BoxDecoration(
      color: active ? teal.withValues(alpha: .08) : Colors.white,
      border: Border.all(color: active ? teal : line),
      borderRadius: BorderRadius.circular(18),
    ),
    child: Column(
      children: [
        Text(
          label.toUpperCase(),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 10,
            letterSpacing: 1,
            color: active ? teal : muted,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          value,
          style: const TextStyle(fontSize: 25, fontWeight: FontWeight.w600),
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
    appBar: AppBar(title: const Text('Vicini, anche offline')),
    body: SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              const Icon(Icons.bluetooth_rounded, size: 70, color: teal),
              const SizedBox(height: 20),
              const Text(
                'Un amico, due telefoni.',
                style: TextStyle(fontSize: 30, fontWeight: FontWeight.w600),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              const Text(
                'Attiva il Bluetooth e tieni le app aperte. Uno crea la partita, l’altro la cerca. Funziona senza Internet.',
                textAlign: TextAlign.center,
                style: TextStyle(color: muted, fontSize: 16, height: 1.5),
              ),
              const SizedBox(height: 28),
              FilledButton.icon(
                onPressed: busy ? null : () => connect(),
                icon: const Icon(Icons.add_rounded),
                label: const Text('Ospita una partita'),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: busy ? null : () => ble.scan(),
                icon: const Icon(Icons.radar_rounded),
                label: Text(
                  ble.scanning
                      ? 'Aggiorna la ricerca'
                      : 'Cerca una partita vicina',
                ),
              ),
              const SizedBox(height: 20),
              Text(
                ble.status,
                textAlign: TextAlign.center,
                style: const TextStyle(color: teal),
              ),
              if (ble.error != null)
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text(
                    ble.error!,
                    style: const TextStyle(color: coral),
                    textAlign: TextAlign.center,
                  ),
                ),
              if (ble.scanning)
                const Padding(
                  padding: EdgeInsets.all(18),
                  child: Center(
                    child: SizedBox(
                      height: 22,
                      width: 22,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                ),
              for (final peer in ble.peers)
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.smartphone_rounded, color: teal),
                    title: Text(peer.name),
                    subtitle: const Text('Partita nelle vicinanze'),
                    trailing: const Icon(Icons.arrow_forward_rounded),
                    onTap: busy ? null : () => connect(peer: peer),
                  ),
                ),
              const SizedBox(height: 20),
              const Text(
                'Non trovi l’amico? Scambiate i ruoli: alcuni telefoni Android non possono ospitare partite Bluetooth. Su Android meno recenti può essere richiesto anche il permesso di posizione.',
                style: TextStyle(fontSize: 13, color: muted, height: 1.5),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
