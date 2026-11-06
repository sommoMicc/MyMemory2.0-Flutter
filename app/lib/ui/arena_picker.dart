import '../l10n/app_strings.dart';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../arenas.dart';
import '../palette.dart';
import 'arena_landscape.dart';
import 'deck_art.dart';

class ArenaPicker extends StatelessWidget {
  const ArenaPicker({
    super.key,
    required this.selectedArenaId,
    required this.unlockedArenaIds,
    this.crowns = 0,
  });
  final String selectedArenaId;
  final Set<String> unlockedArenaIds;
  final int crowns;

  static Future<String?> show(
    BuildContext context, {
    required String selectedArenaId,
    required Set<String> unlockedArenaIds,
    int crowns = 0,
  }) => Navigator.push<String>(
    context,
    MaterialPageRoute(
      builder: (_) => ArenaPicker(
        selectedArenaId: selectedArenaId,
        unlockedArenaIds: unlockedArenaIds,
        crowns: crowns,
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final catalog = ArenaCatalog.instance;
    final reached = catalog.arenas
        .where((a) => unlockedArenaIds.contains(a.id))
        .length;
    final future = catalog.arenas.where(
      (a) => !unlockedArenaIds.contains(a.id),
    );
    final next = future.isEmpty ? null : future.first;
    return Scaffold(
      backgroundColor: paper,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 8, 20, 8),
                  child: Row(
                    children: [
                      IconButton(
                        tooltip: tr(context, 'Indietro'),
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.arrow_back_rounded),
                      ),
                      Expanded(
                        child: Text(
                          tr(context, 'Il tuo viaggio'),
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w700,
                            color: ink,
                          ),
                        ),
                      ),
                      const Icon(Icons.explore_outlined, color: teal, size: 26),
                    ],
                  ),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    key: const ValueKey('arena-journey-scroll'),
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
                    child: Column(
                      children: [
                        _JourneyPassport(
                          reached: reached,
                          total: catalog.arenas.length,
                          crowns: crowns,
                          next: next,
                        ),
                        const SizedBox(height: 12),
                        for (final entry in catalog.arenas.asMap().entries)
                          _JourneyStop(
                            arena: entry.value,
                            index: entry.key,
                            isLast: entry.key == catalog.arenas.length - 1,
                            decks: catalog.decks
                                .where((d) => d.arenaId == entry.value.id)
                                .toList(),
                            unlocked: unlockedArenaIds.contains(entry.value.id),
                            selected: selectedArenaId == entry.value.id,
                            onSelect: () =>
                                Navigator.pop(context, entry.value.id),
                          ),
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 8,
                          ),
                          child: Text(
                            tr(
                              context,
                              'Le arene raggiunte restano disponibili, anche se le corone scendono.',
                            ),
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 12,
                              height: 1.5,
                              color: ink.withValues(alpha: .6),
                            ),
                          ),
                        ),
                      ],
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
}

class _JourneyPassport extends StatelessWidget {
  const _JourneyPassport({
    required this.reached,
    required this.total,
    required this.crowns,
    required this.next,
  });
  final int reached, total, crowns;
  final Arena? next;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      color: popYellow,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: ink, width: 2),
      boxShadow: const [BoxShadow(color: ink, offset: Offset(0, 4))],
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.map_outlined, size: 20, color: teal),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                tr(context, '$reached di $total arene raggiunte'),
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: ink,
                ),
              ),
            ),
            const Icon(
              Icons.emoji_events_rounded,
              color: Color(0xFFB68A31),
              size: 19,
            ),
            const SizedBox(width: 4),
            Text(
              tr(context, '$crowns'),
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: ink,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            for (var i = 0; i < total; i++) ...[
              if (i > 0) const SizedBox(width: 6),
              Expanded(
                child: Container(
                  height: 5,
                  decoration: BoxDecoration(
                    color: i < reached ? teal : const Color(0xFFD7D6C8),
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 10),
        Text(
          tr(
            context,
            next == null
                ? 'Tutte le destinazioni sono sbloccate.'
                : 'Prossima tappa: ${tr(context, next!.name)} · ${math.max(0, next!.minCrowns - crowns)} corone mancanti',
          ),
          style: const TextStyle(color: muted, fontSize: 12, height: 1.4),
        ),
      ],
    ),
  );
}

class _JourneyStop extends StatelessWidget {
  const _JourneyStop({
    required this.arena,
    required this.index,
    required this.isLast,
    required this.decks,
    required this.unlocked,
    required this.selected,
    required this.onSelect,
  });
  final Arena arena;
  final int index;
  final bool isLast;
  final List<ArenaDeck> decks;
  final bool unlocked, selected;
  final VoidCallback onSelect;

  @override
  Widget build(BuildContext context) {
    final color = arenaColor(arena.id);
    final right = index.isOdd;
    final free = decks.where((d) => d.isFree).toList();
    final premium = decks.where((d) => !d.isFree).toList();
    return Card(
      key: ValueKey('arena-stop-${arena.id}'),
      elevation: 0,
      color: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      margin: EdgeInsets.zero,
      child: CustomPaint(
        painter: _TrailPainter(right: right, last: isLast, unlocked: unlocked),
        child: Padding(
          padding: const EdgeInsets.only(top: 22, bottom: 30),
          child: Column(
            crossAxisAlignment: right
                ? CrossAxisAlignment.end
                : CrossAxisAlignment.start,
            children: [
              Align(
                alignment: right ? Alignment.centerRight : Alignment.centerLeft,
                child: SizedBox(
                  width: 244,
                  height: 190,
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Positioned.fill(child: ArenaLandscape(arenaId: arena.id)),
                      Positioned(
                        top: 6,
                        left: right ? null : 8,
                        right: right ? 8 : null,
                        child: Container(
                          width: 36,
                          height: 36,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: color,
                            shape: BoxShape.circle,
                            border: Border.all(color: ink, width: 2),
                          ),
                          child: Text(
                            tr(context, '${index + 1}'.padLeft(2, '0')),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        bottom: 0,
                        left: 25,
                        right: 25,
                        child: Center(
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: selected ? popYellow : paper,
                              borderRadius: BorderRadius.circular(30),
                              border: Border.all(color: ink, width: 1.5),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  selected
                                      ? Icons.location_on_rounded
                                      : unlocked
                                      ? Icons.check_rounded
                                      : Icons.lock_outline_rounded,
                                  size: 14,
                                  color: ink,
                                ),
                                const SizedBox(width: 4),
                                Flexible(
                                  child: Text(
                                    tr(
                                      context,
                                      selected
                                          ? 'Sei qui'
                                          : unlocked
                                          ? 'Raggiunta'
                                          : '${arena.minCrowns} corone',
                                    ),
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w800,
                                      color: ink,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
                decoration: BoxDecoration(
                  color: paper,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: ink, width: selected ? 2.5 : 1.5),
                  boxShadow: const [
                    BoxShadow(color: ink, offset: Offset(0, 4)),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            tr(context, arena.name),
                            style: const TextStyle(
                              fontSize: 21,
                              height: 1.15,
                              fontWeight: FontWeight.w800,
                              color: ink,
                            ),
                          ),
                        ),
                        if (unlocked)
                          Padding(
                            padding: const EdgeInsets.only(left: 8, top: 2),
                            child: Icon(
                              Icons.verified_rounded,
                              color: color,
                              size: 20,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        for (final deck in free)
                          _DeckStamp(deck: deck, color: color),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      tr(
                        context,
                        'CON GEMME  ·  ${premium.map((d) => '${tr(context, d.name)} (${d.price})').join(' · ')}',
                      ),
                      style: const TextStyle(
                        fontSize: 11,
                        height: 1.5,
                        color: muted,
                      ),
                    ),
                    if (!unlocked) ...[
                      const SizedBox(height: 9),
                      Text(
                        tr(
                          context,
                          'Arena bloccata: raggiungi la soglia con le corone.',
                        ),
                        style: TextStyle(
                          fontSize: 12,
                          height: 1.4,
                          color: muted,
                        ),
                      ),
                    ],
                    if (unlocked)
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton.icon(
                          style: TextButton.styleFrom(
                            foregroundColor: color,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 0,
                              vertical: 8,
                            ),
                          ),
                          onPressed: onSelect,
                          iconAlignment: IconAlignment.end,
                          icon: Icon(
                            selected
                                ? Icons.check_rounded
                                : Icons.arrow_forward_rounded,
                            size: 18,
                          ),
                          label: Text(
                            tr(
                              context,
                              selected ? 'Selezionata' : 'Scegli arena',
                            ),
                            style: const TextStyle(fontWeight: FontWeight.w800),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DeckStamp extends StatelessWidget {
  const _DeckStamp({required this.deck, required this.color});
  final ArenaDeck deck;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.fromLTRB(4, 4, 8, 4),
    decoration: BoxDecoration(
      color: color.withValues(alpha: .065),
      borderRadius: BorderRadius.circular(10),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 25,
          height: 25,
          child: DeckArtwork(collection: deck.id, value: 0),
        ),
        const SizedBox(width: 4),
        Text(
          tr(context, deck.name),
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: ink,
          ),
        ),
      ],
    ),
  );
}

class _TrailPainter extends CustomPainter {
  const _TrailPainter({
    required this.right,
    required this.last,
    required this.unlocked,
  });
  final bool right, last, unlocked;

  @override
  void paint(Canvas canvas, Size size) {
    final x = right ? size.width - 122 : 122.0;
    final previous = right ? 122.0 : size.width - 122;
    final path = Path()
      ..moveTo(previous, 0)
      ..cubicTo(previous, 26, x, 12, x, 70)
      ..lineTo(x, 195);
    if (!last) {
      path.moveTo(x, size.height - 45);
      path.cubicTo(x, size.height - 18, x, size.height - 12, x, size.height);
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = ink.withValues(alpha: .15)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 12
        ..strokeCap = StrokeCap.round,
    );
    for (final metric in path.computeMetrics()) {
      for (var distance = 0.0; distance < metric.length; distance += 13) {
        canvas.drawPath(
          metric.extractPath(distance, math.min(distance + 4, metric.length)),
          Paint()
            ..color = unlocked ? popCobalt : muted
            ..style = PaintingStyle.stroke
            ..strokeWidth = 3
            ..strokeCap = StrokeCap.round,
        );
      }
    }
  }

  @override
  bool shouldRepaint(_TrailPainter old) =>
      old.right != right || old.last != last || old.unlocked != unlocked;
}

/// Entry to the map, with the selected destination visible before opening it.
class ArenaJourneyTile extends StatelessWidget {
  const ArenaJourneyTile({
    super.key,
    required this.arenaId,
    required this.onTap,
    this.label = 'Il tuo viaggio',
    this.crowns = 0,
  });
  final String arenaId, label;
  final int crowns;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final catalog = ArenaCatalog.instance;
    final arena = catalog.arenas.firstWhere(
      (a) => a.id == arenaId,
      orElse: () => catalog.arenas.first,
    );
    final color = arenaColor(arena.id);
    return Material(
      color: paper,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: ink, width: 1.5),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
          child: Row(
            children: [
              SizedBox(
                width: 100,
                height: 90,
                child: ArenaLandscape(arenaId: arena.id),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      tr(context, label),
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: color,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      tr(context, arena.name),
                      style: const TextStyle(
                        fontSize: 17,
                        height: 1.15,
                        fontWeight: FontWeight.w800,
                        color: ink,
                      ),
                    ),
                    const SizedBox(height: 7),
                    Text(
                      tr(context, 'Esplora le arene'),
                      style: TextStyle(
                        fontSize: 11,
                        color: color,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 4),
              Icon(Icons.chevron_right_rounded, color: color, size: 22),
            ],
          ),
        ),
      ),
    );
  }
}
