import 'package:flutter/material.dart';

import '../arenas.dart';
import '../palette.dart';

class ArenaPicker extends StatelessWidget {
  const ArenaPicker({
    super.key,
    required this.selectedArenaId,
    required this.unlockedArenaIds,
  });
  final String selectedArenaId;
  final Set<String> unlockedArenaIds;

  static Future<String?> show(
    BuildContext context, {
    required String selectedArenaId,
    required Set<String> unlockedArenaIds,
  }) => Navigator.push<String>(
    context,
    MaterialPageRoute(
      builder: (_) => ArenaPicker(
        selectedArenaId: selectedArenaId,
        unlockedArenaIds: unlockedArenaIds,
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final catalog = ArenaCatalog.instance;
    return Scaffold(
      backgroundColor: paper,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 8, 16, 8),
                  child: Row(
                    children: [
                      IconButton(
                        tooltip: 'Indietro',
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.arrow_back_rounded),
                      ),
                      const Expanded(
                        child: Text(
                          'Scegli un’arena',
                          style: TextStyle(
                            fontSize: 23,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
                    children: [
                      for (final arena in catalog.arenas)
                        _ArenaPanel(
                          arena: arena,
                          decks: catalog.decks
                              .where((deck) => deck.arenaId == arena.id)
                              .toList(),
                          unlocked: unlockedArenaIds.contains(arena.id),
                          selected: selectedArenaId == arena.id,
                          onSelect: () => Navigator.pop(context, arena.id),
                        ),
                    ],
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

class _ArenaPanel extends StatelessWidget {
  const _ArenaPanel({
    required this.arena,
    required this.decks,
    required this.unlocked,
    required this.selected,
    required this.onSelect,
  });
  final Arena arena;
  final List<ArenaDeck> decks;
  final bool unlocked, selected;
  final VoidCallback onSelect;

  @override
  Widget build(BuildContext context) {
    final free = decks.where((deck) => deck.isFree).toList();
    final premium = decks.where((deck) => !deck.isFree).toList();
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: unlocked ? Colors.white : const Color(0xFFF0EFEB),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(
          color: selected ? teal : line,
          width: selected ? 2 : 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
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
                  style: const TextStyle(color: muted, fontSize: 12),
                ),
                if (!unlocked)
                  const Padding(
                    padding: EdgeInsets.only(left: 8),
                    child: Icon(Icons.lock_rounded, size: 18, color: muted),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'GRATIS  ·  ${free.map((deck) => '${deck.name}${deck.contentReady ? '' : ' · in arrivo'}').join(' · ')}',
              style: const TextStyle(fontSize: 12, color: ink),
            ),
            const SizedBox(height: 4),
            Text(
              'CON GEMME  ·  ${premium.isEmpty ? 'Nessuna' : premium.map((deck) => '${deck.name} (${deck.price} gemme)${deck.contentReady ? '' : ' · in arrivo'}').join(' · ')}',
              style: const TextStyle(fontSize: 12, color: muted),
            ),
            if (!unlocked)
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: Text(
                  'Arena bloccata: raggiungi la soglia con le corone.',
                  style: TextStyle(color: muted, fontSize: 12),
                ),
              ),
            if (unlocked)
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: onSelect,
                  child: Text(selected ? 'Selezionata' : 'Scegli arena'),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
