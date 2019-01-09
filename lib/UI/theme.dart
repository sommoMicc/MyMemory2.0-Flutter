import 'package:flutter/material.dart';

class LetsMemoryColors {
  LetsMemoryColors._(); //Per evitare che la classe venga istanziata

  static const Color background = const Color(0xFF1B4DCA);
  static const Color textOnPrimary = Colors.white;

  static const Color backgroundGradientEnd = const Color(0xFFF9683A);
  static const Color backgroundGradientStart = const Color(0xFF9E51B5);

  static const Color standardCardShadow = const Color(0xFFA9B8E1);
  static const Color standardCardBackground = Colors.white;
}

class LetsMemoryDimensions {
  static const double bigTitle = 50.0;

  static const double cardFont = 35.0;
  static const double standardCard = cardFont * 1.5;
  static const double cardRadius = standardCard / 3;
  static const double cardBorder = cardFont / 10;

  static const mainButtonFont = cardFont/2 + 10;
}

class LetsmemoryStyles {
  static const TextStyle mainTitle = const TextStyle(
    color: LetsMemoryColors.textOnPrimary,
    fontSize: LetsMemoryDimensions.bigTitle,
    fontWeight: FontWeight.bold
  );

}