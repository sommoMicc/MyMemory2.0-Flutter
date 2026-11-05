import 'package:flutter/material.dart';
import '../decks.dart';

/// Shared illustrated/text face; the Paola collection uses real, scalable text.
class DeckArtwork extends StatelessWidget {
  const DeckArtwork({super.key, required this.collection, required this.value});
  final String collection;
  final int value;
  @override
  Widget build(BuildContext context) {
    final asset = deckAsset(collection, value);
    final text = Center(
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Text(
          deckLabel(collection, value) ?? '?',
          maxLines: 1,
          style: const TextStyle(
            inherit: false,
            fontFamily: 'Outfit',
            fontSize: 64,
            fontWeight: FontWeight.w800,
            color: Color(0xFF604D91),
            letterSpacing: 1,
            decoration: TextDecoration.none,
          ),
        ),
      ),
    );
    return asset == null
        ? text
        : Image.asset(
            asset,
            fit: BoxFit.contain,
            errorBuilder: (context, error, stack) => text,
          );
  }
}
