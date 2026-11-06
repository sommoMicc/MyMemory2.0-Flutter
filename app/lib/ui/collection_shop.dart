import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../decks.dart';
import '../economy.dart';
import '../arenas.dart';
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
              if (economy.pendingChanges > 0)
                const Padding(
                  padding: EdgeInsets.only(left: 5),
                  child: Tooltip(
                    message:
                        'Progressi salvati sul dispositivo, da sincronizzare',
                    child: Icon(
                      Icons.cloud_upload_outlined,
                      size: 14,
                      color: ink,
                    ),
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

  bool owns(String id) =>
      widget.economy?.ownsDeck(id) == true ||
      (widget.economy == null && ProfileData.freeDecks.contains(id));

  bool accessible(ArenaDeck deck) {
    final profile = widget.economy?.profile;
    if (profile == null) return owns(deck.id);
    return ArenaProgress(
      crowns: profile.crowns,
      peakCrowns: profile.peakCrowns,
    ).canUseDeck(deck.id, ownedDecks: widget.economy!.ownedDecks);
  }

  bool canUnlock(ArenaDeck deck) =>
      deck.contentReady &&
      deck.price > 0 &&
      widget.economy?.profile != null &&
      !widget.economy!.busy &&
      widget.economy!.gems >= deck.price &&
      ArenaProgress(
        crowns: widget.economy!.profile!.crowns,
        peakCrowns: widget.economy!.profile!.peakCrowns,
      ).canUnlockDeck(deck.id);

  String? lockedReason(ArenaDeck deck) {
    if (!deck.contentReady) return 'Contenuto in arrivo';
    if (accessible(deck)) return null;
    final profile = widget.economy?.profile;
    final reached = profile?.unlockedArenaIds ?? const {'wild_valley'};
    if (deck.arenaId != null && !reached.contains(deck.arenaId)) {
      return 'Arena bloccata';
    }
    if (deck.price > 0) {
      if (profile == null) return 'Profilo richiesto';
      if (widget.economy!.gems < deck.price) return 'Gemme insufficienti';
    }
    return null;
  }

  Future<void> select(ArenaDeck deck) async {
    final id = deck.id;
    if (!deck.contentReady) return;
    if (accessible(deck)) {
      Navigator.pop(context, id);
      return;
    }
    final economy = widget.economy;
    if (deck.price == 0 || economy == null || unlocking != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            lockedReason(deck) ?? 'Sblocca prima l’arena con le corone.',
          ),
        ),
      );
      return;
    }
    if (!canUnlock(deck)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Raggiungi prima l’arena per sbloccare questa collezione.',
          ),
        ),
      );
      return;
    }
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
    final economy = widget.economy;
    final catalog = ArenaCatalog.instance;
    List<ArenaDeck> visibleIn(Arena arena) => catalog.decks
        .where(
          (deck) => deck.arenaId == arena.id && deckNames.containsKey(deck.id),
        )
        .toList();
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
                          final wide = c.maxWidth > 600;
                          return ListView(
                            padding: EdgeInsets.zero,
                            children: [
                              for (final arena in catalog.arenas) ...[
                                Padding(
                                  padding: const EdgeInsets.fromLTRB(
                                    2,
                                    8,
                                    2,
                                    6,
                                  ),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 8,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withValues(
                                        alpha: .94,
                                      ),
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                    child: Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            arena.name,
                                            style: const TextStyle(
                                              fontSize: 18,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                        ),
                                        Text(
                                          'Da ${arena.minCrowns} corone',
                                          style: const TextStyle(
                                            fontSize: 12,
                                            color: ink,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                if (visibleIn(arena).isEmpty)
                                  Padding(
                                    padding: const EdgeInsets.only(bottom: 10),
                                    child: Text(
                                      'Nessuna collezione pronta da mostrare.',
                                      style: TextStyle(color: muted),
                                    ),
                                  )
                                else if (wide)
                                  Wrap(
                                    spacing: 12,
                                    runSpacing: 12,
                                    children: [
                                      for (final deck in visibleIn(arena))
                                        SizedBox(
                                          width: (c.maxWidth - 12) / 2,
                                          height: 155,
                                          child: _offer(deck, wide: true),
                                        ),
                                    ],
                                  )
                                else
                                  Column(
                                    children: [
                                      for (final deck in visibleIn(arena))
                                        Padding(
                                          padding: const EdgeInsets.only(
                                            bottom: 10,
                                          ),
                                          child: SizedBox(
                                            height: 154,
                                            child: _offer(deck, wide: false),
                                          ),
                                        ),
                                    ],
                                  ),
                              ],
                              if (deckNames.containsKey('paola')) ...[
                                const Padding(
                                  padding: EdgeInsets.fromLTRB(2, 12, 2, 6),
                                  child: Text(
                                    'Allenamento',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                                SizedBox(
                                  height: 154,
                                  child: _offer(
                                    catalog.decks.singleWhere(
                                      (deck) => deck.id == 'paola',
                                    ),
                                    wide: wide,
                                  ),
                                ),
                              ],
                            ],
                          );
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
                                '100 gemme iniziali e 20 per ogni partita completata e verificata. In individuale guadagni e sblocchi anche offline: i progressi vengono salvati sul dispositivo e sincronizzati automaticamente quando torna Internet. Le collezioni sbloccate restano tue.\n\nNon è possibile acquistare gemme con denaro.',
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
                      ],
                    ),
                    if (economy?.offline == true ||
                        (economy?.pendingChanges ?? 0) > 0)
                      const Text(
                        'Progressi salvati sul dispositivo · sincronizzazione automatica al ritorno della rete',
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

  Widget _offer(ArenaDeck deck, {required bool wide}) {
    final isAccessible = accessible(deck);
    final status = lockedReason(deck);
    return _DeckOffer(
      key: ValueKey('deck-offer-${deck.id}'),
      id: deck.id,
      price: deck.price,
      owned: isAccessible,
      selected: deck.id == widget.selected,
      busy: unlocking == deck.id,
      wide: wide,
      status: status,
      enabled: unlocking == null && (isAccessible || canUnlock(deck)),
      onTap: () => select(deck),
    );
  }
}

class _DeckOffer extends StatelessWidget {
  const _DeckOffer({
    super.key,
    required this.id,
    required this.price,
    required this.owned,
    required this.selected,
    required this.busy,
    required this.enabled,
    required this.wide,
    this.status,
    required this.onTap,
  });
  final String id;
  final int price;
  final bool owned, selected, busy, enabled, wide;
  final String? status;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final accent = deckAccent(id);
    final tint = Color.lerp(accent, Colors.white, .7)!;
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
          : Text(
              owned
                  ? 'Usa'
                  : price == 0
                  ? status ?? 'Bloccata'
                  : 'Sblocca',
            ),
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
                              ? (price == 0 ? 'Inclusa' : 'Sbloccata')
                              : price == 0
                              ? status ?? 'Gratis'
                              : '$price gemme${status == null ? '' : ' · $status'}',
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
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
