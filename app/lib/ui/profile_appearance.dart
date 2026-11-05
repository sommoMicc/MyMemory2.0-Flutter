import 'package:flutter/material.dart';

import '../palette.dart';

/// Bundled choices; their IDs are validated by the profile service.
const profileAvatars = <String, ({String label, String symbol})>{
  'fox': (label: 'Volpe', symbol: '🦊'),
  'cat': (label: 'Gatto', symbol: '🐱'),
  'dog': (label: 'Cane', symbol: '🐶'),
  'panda': (label: 'Panda', symbol: '🐼'),
  'owl': (label: 'Gufo', symbol: '🦉'),
  'rocket': (label: 'Razzo', symbol: '🚀'),
  'star': (label: 'Stella', symbol: '⭐'),
  'flower': (label: 'Fiore', symbol: '🌼'),
};

const profileAccents = <String, ({String label, Color color})>{
  'forest': (label: 'Foresta', color: teal),
  'ocean': (label: 'Oceano', color: Color(0xFF226B99)),
  'cosmos': (label: 'Cosmo', color: Color(0xFF7153A0)),
  'sunset': (label: 'Tramonto', color: Color(0xFFA84D27)),
  'rose': (label: 'Rosa', color: Color(0xFFA5436B)),
};

class ProfileAvatar extends StatelessWidget {
  const ProfileAvatar({
    super.key,
    this.avatarId = 'fox',
    this.accentId = 'forest',
    this.size = 64,
  });

  final String avatarId, accentId;
  final double size;

  @override
  Widget build(BuildContext context) {
    final avatar = profileAvatars[avatarId] ?? profileAvatars['fox']!;
    final accent = profileAccents[accentId] ?? profileAccents['forest']!;
    return Semantics(
      label: 'Avatar ${avatar.label}, colore ${accent.label}',
      image: true,
      child: ExcludeSemantics(
        child: Container(
          width: size,
          height: size,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Color.alphaBlend(
              accent.color.withValues(alpha: .12),
              paper,
            ),
            border: Border.all(color: accent.color, width: 2),
          ),
          child: Text(
            avatar.symbol,
            textScaler: TextScaler.noScaling,
            style: TextStyle(fontSize: size * .53, height: 1.1),
          ),
        ),
      ),
    );
  }
}
