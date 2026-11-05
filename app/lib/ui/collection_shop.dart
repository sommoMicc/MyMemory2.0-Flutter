import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../decks.dart';
import '../economy.dart';
import '../palette.dart';
import 'game_world.dart';
import 'deck_art.dart';

class GemBalance extends StatelessWidget {
  const GemBalance({super.key, required this.economy, this.onTap});
  final EconomyController economy;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) => Semantics(
    label: economy.profile == null
        ? 'Saldo in caricamento'
        : '${economy.gems} gemme',
    child: Material(
      color: const Color(0xFFFFF4D8),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.diamond_rounded,
                color: Color(0xFF7561B4),
                size: 21,
              ),
              const SizedBox(width: 6),
              Text(
                economy.profile == null ? '…' : '${economy.gems}',
                style: const TextStyle(
                  color: ink,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (economy.pendingRewards > 0)
                const Padding(
                  padding: EdgeInsets.only(left: 5),
                  child: Icon(
                    Icons.cloud_upload_outlined,
                    size: 14,
                    color: ink,
                  ),
                ),
            ],
          ),
        ),
      ),
    ),
  );
}

class CollectionShop extends StatefulWidget {
  const CollectionShop({super.key, required this.selected, this.economy});
  final String selected;
  final EconomyController? economy;
  @override
  State<CollectionShop> createState() => _CollectionShopState();
}

class _CollectionShopState extends State<CollectionShop> {
  int page = 0;
  String? unlocking;
  @override
  void initState() {
    super.initState();
    widget.economy?.addListener(changed);
  }

  @override
  void dispose() {
    widget.economy?.removeListener(changed);
    super.dispose();
  }

  void changed() {
    if (mounted) setState(() {});
  }

  bool owned(String id) =>
      (deckPrices[id] ?? 0) == 0 || widget.economy?.ownsDeck(id) == true;
  Future<void> select(String id) async {
    if (owned(id)) {
      Navigator.pop(context, id);
      return;
    }
    final economy = widget.economy;
    if (economy == null || unlocking != null) return;
    setState(() => unlocking = id);
    try {
      final result = await economy.unlockDeck(id);
      if (!mounted) return;
      if (result.unlocked || result.alreadyOwned || economy.ownsDeck(id)) {
        Navigator.pop(context, id);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              economy.lastError ?? 'Sblocco non completato. Riprova.',
            ),
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              economy.lastError ??
                  'Impossibile sbloccare la collezione. Riprova.',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => unlocking = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ids = deckNames.keys.toList();
    final pages = (ids.length / 3).ceil();
    final visible = ids.skip(page * 3).take(3).toList();
    final economy = widget.economy;
    return GameWorld(
      collection: widget.selected,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 950),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: Column(
                  children: [
                    Row(
                      children: [
                        IconButton(
                          tooltip: 'Chiudi collezioni',
                          onPressed: () => Navigator.pop(context),
                          icon: const Icon(Icons.arrow_back_rounded),
                        ),
                        const Expanded(
                          child: Text(
                            'Collezioni',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        if (economy != null) GemBalance(economy: economy),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Expanded(
                      child: LayoutBuilder(
                        builder: (context, c) {
                          final wide = c.maxWidth > 540;
                          final tiles = [
                            for (final id in visible)
                              Expanded(
                                child: _DeckOffer(
                                  id: id,
                                  owned: owned(id),
                                  selected: id == widget.selected,
                                  busy: unlocking == id,
                                  wide: wide,
                                  enabled:
                                      unlocking == null &&
                                      (owned(id) ||
                                          economy != null &&
                                              !economy.busy &&
                                              !economy.offline &&
                                              economy.profile != null &&
                                              economy.gems >=
                                                  (deckPrices[id] ?? 0)),
                                  onTap: () => select(id),
                                ),
                              ),
                          ];
                          final separated = <Widget>[];
                          for (final tile in tiles) {
                            if (separated.isNotEmpty) {
                              separated.add(
                                SizedBox(
                                  width: wide ? 12 : 0,
                                  height: wide ? 0 : 12,
                                ),
                              );
                            }
                            separated.add(tile);
                          }
                          return wide
                              ? Row(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: separated,
                                )
                              : Column(children: separated);
                        },
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        IconButton(
                          tooltip: 'Come ottenere gemme',
                          onPressed: () => showDialog<void>(
                            context: context,
                            builder: (context) => AlertDialog(
                              title: const Text('Gemme'),
                              content: const Text(
                                '100 gemme iniziali e 20 per ogni partita completata e verificata. Le collezioni sbloccate restano tue.\n\nNon è possibile acquistare gemme con denaro.',
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(context),
                                  child: const Text('Chiudi'),
                                ),
                              ],
                            ),
                          ),
                          icon: const Icon(Icons.info_outline_rounded),
                        ),
                        const Spacer(),
                        IconButton(
                          tooltip: 'Collezioni precedenti',
                          onPressed: page == 0
                              ? null
                              : () => setState(() => page--),
                          icon: const Icon(Icons.chevron_left_rounded),
                        ),
                        Text(
                          '${page + 1} / $pages',
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        IconButton(
                          tooltip: 'Altre collezioni',
                          onPressed: page + 1 >= pages
                              ? null
                              : () => setState(() => page++),
                          icon: const Icon(Icons.chevron_right_rounded),
                        ),
                      ],
                    ),
                    if (economy?.offline == true)
                      const Text(
                        'Offline · sblocchi disponibili alla riconnessione',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 12, color: ink),
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

class _DeckOffer extends StatelessWidget {
  const _DeckOffer({
    required this.id,
    required this.owned,
    required this.selected,
    required this.busy,
    required this.enabled,
    required this.wide,
    required this.onTap,
  });
  final String id;
  final bool owned, selected, busy, enabled, wide;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final accent = switch (id) {
      'cosmos' => const Color(0xFF7561B4),
      'ocean' => const Color(0xFF2686A5),
      'food' => const Color(0xFFC87837),
      'sports' => const Color(0xFF468A54),
      'travel' => const Color(0xFF6879B9),
      'paola' => const Color(0xFF9B6FAD),
      _ => teal,
    };
    final tint = switch (id) {
      'cosmos' => const Color(0xFFD9CFF0),
      'ocean' => const Color(0xFFBCE5ED),
      'food' => const Color(0xFFF5D3AF),
      'sports' => const Color(0xFFCFE5AB),
      'travel' => const Color(0xFFD2DDF3),
      'paola' => const Color(0xFFF1D2E4),
      _ => const Color(0xFFCCE7C4),
    };
    Widget illustration(
      int value,
      double size, {
      double opacity = 1,
      double angle = 0,
    }) => ExcludeSemantics(
      child: IgnorePointer(
        child: Opacity(
          opacity: opacity,
          child: Transform.rotate(
            angle: angle,
            child: SizedBox(
              width: size,
              height: size,
              child: id == 'paola'
                  ? FittedBox(
                      fit: BoxFit.contain,
                      child: Text(
                        deckLabel(id, value)!,
                        style: const TextStyle(
                          fontFamily: 'Outfit',
                          fontSize: 64,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF604D91),
                        ),
                      ),
                    )
                  : DeckArtwork(collection: id, value: value),
            ),
          ),
        ),
      ),
    );
    final button = FilledButton(
      style: FilledButton.styleFrom(
        backgroundColor: accent,
        foregroundColor: Colors.white,
        disabledBackgroundColor: ink.withValues(alpha: .12),
        disabledForegroundColor: ink.withValues(alpha: .65),
        minimumSize: const Size(80, 42),
        padding: const EdgeInsets.symmetric(horizontal: 14),
      ),
      onPressed: enabled ? onTap : null,
      child: busy
          ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : Text(owned ? 'Usa' : 'Sblocca'),
    );
    return GestureDetector(
      onTap: owned && enabled ? onTap : null,
      child: Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color.lerp(tint, Colors.white, .35)!,
              tint,
              Color.lerp(tint, accent, .12)!,
            ],
          ),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: selected ? accent : accent.withValues(alpha: .28),
            width: selected ? 2 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: accent.withValues(alpha: .19),
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: LayoutBuilder(
          builder: (context, c) {
            final hero = c.maxHeight > c.maxWidth * 1.1;
            final artSize = hero
                ? math.min(c.maxHeight * .48, c.maxWidth * .72)
                : math.min(c.maxHeight * .84, c.maxWidth * (wide ? .55 : .48));
            return Stack(
              fit: StackFit.expand,
              children: [
                if (id == 'paola')
                  for (double y = 32; y < c.maxHeight; y += 32)
                    Positioned(
                      left: 0,
                      right: 0,
                      top: y,
                      child: Divider(
                        height: 1,
                        color: accent.withValues(alpha: .13),
                      ),
                    ),
                Positioned(
                  right: -20,
                  top: -22,
                  child: Container(
                    width: artSize * 1.35,
                    height: artSize * 1.35,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: .25),
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
                Positioned(
                  right: hero ? c.maxWidth - artSize * .65 : artSize * .49,
                  top: hero ? c.maxHeight * .06 : 4,
                  child: illustration(
                    id == 'paola' ? 5 : 1,
                    artSize * .48,
                    opacity: .63,
                    angle: -.22,
                  ),
                ),
                Positioned(
                  right: hero ? (c.maxWidth - artSize) / 2 : 5,
                  top: hero ? c.maxHeight * .20 : (c.maxHeight - artSize) / 2,
                  child: illustration(0, artSize, angle: .08),
                ),
                Positioned(
                  right: hero ? 16 : -4,
                  bottom: hero ? c.maxHeight * .23 : -5,
                  child: illustration(
                    id == 'paola' ? 10 : 2,
                    artSize * .50,
                    opacity: .66,
                    angle: .18,
                  ),
                ),
                Positioned(
                  left: 12,
                  top: hero ? null : 4,
                  bottom: hero ? 24 : 4,
                  width: c.maxWidth * (hero ? .65 : .51) - 12,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        deckNames[id]!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: ink,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 7,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: .64),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          owned
                              ? ((deckPrices[id] ?? 0) == 0
                                    ? 'Inclusa'
                                    : 'Sbloccata')
                              : '${deckPrices[id]} gemme',
                          maxLines: 1,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: ink,
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      button,
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
