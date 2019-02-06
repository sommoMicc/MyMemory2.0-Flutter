import 'package:flutter/material.dart';

class LetsMemoryColors {
  LetsMemoryColors._(); //Per evitare che la classe venga istanziata

  static const Color background = const Color(0xFF1B4DCA);
  static const Color darkerBackground = const Color(0xFF2A4DA5);
  static const Color darkestBackground = const Color(0xFF143DA5);

  static const Color textOnPrimary = Colors.white;

  static const Color standardCardShadow = const Color(0xFFA9B8E1);
  static const Color standardCardBackground = Colors.white;
}

class LetsMemoryDimensions {
  static const double bigTitle = 50.0;
  static const double mediumTitle = 40.0;
  static const double smallTitle = 30.0;

  static const double cardFont = 35.0;
  static const double standardCard = cardFont * 1.5;
  static const double cardRadius = standardCard / 3;
  static const double cardBorder = cardFont / 10;

  static const double mainButtonFont = cardFont/2 + 10;
  static const double miniButtonScaleFactor = 0.75;
  static const double backButtonPaddingTop = 26;

  static double scaleHeight(BuildContext context, double dimension) {
    return dimension * MediaQuery.of(context).size.height / 592.0;
  }

  static double scaleWidth(BuildContext context, double dimension) {
    return dimension * MediaQuery.of(context).size.height / 360.0;
  }
}

class LetsmemoryStyles {
  static const TextStyle mainTitle = const TextStyle(
    color: LetsMemoryColors.textOnPrimary,
    fontSize: LetsMemoryDimensions.bigTitle,
    fontWeight: FontWeight.bold,
  );

  static const TextStyle mediumTitle = const TextStyle(
    color: LetsMemoryColors.textOnPrimary,
    fontSize: LetsMemoryDimensions.smallTitle,
    fontWeight: FontWeight.bold,
  );

  static const TextStyle smallTitle = const TextStyle(
    color: LetsMemoryColors.textOnPrimary,
    fontSize: LetsMemoryDimensions.smallTitle,
    fontWeight: FontWeight.bold,
  );

}