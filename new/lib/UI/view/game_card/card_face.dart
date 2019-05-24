import 'package:flutter/material.dart';
import 'package:lets_memory/UI/styles/palette.dart';

import 'package:lets_memory/UI/styles/style.dart';

import "dart:math";

class CardFace extends StatelessWidget {
  final String text;
  final Matrix4 rotation;

  final bool pressed, shadow;
  final Color shadowColor;

  final ColorPalette palette;

  final double size, fontSize;

  CardFace({
    @required this.palette,
    this.shadowColor,
    this.text = "",
    this.shadow = true,
    this.rotation,
    this.pressed = false,
    this.size = 0,
    this.fontSize = 0
  });

  @override
  Widget build(BuildContext context) {
    Color _shadowColor = this.shadowColor ?? _Style.defaultShadowColor;


    final _Style s = _Style(context);
    if(size != 0) s.cardSide = size;

    final List<BoxShadow> boxShadow = <BoxShadow> [
      BoxShadow(
        color: _shadowColor,
        offset: Offset(-3.0, 5.0),
        blurRadius: 0,
        spreadRadius: 0
      )
    ];

    return Transform(
      alignment: FractionalOffset.center, // set transform origin
      transform: this.rotation == null ? Matrix4.identity() : this.rotation,
      child: Container(
        constraints: BoxConstraints(
          minHeight: s.cardSide,
          minWidth: s.cardSide,
          maxHeight: s.cardSide,
          maxWidth: s.cardSide
        ),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(s.radius),
          boxShadow: (this.shadow && !this.pressed) ? boxShadow : [],
          color: this.pressed ? palette.dark : palette.primary,
          border: Border.all(color: palette.dark, width: s.cardBorder)
        ),
        child: Center(
          child: Text(this.text,
            style: TextStyle(
              fontSize: fontSize != 0 ? fontSize : s.cardFont,
              fontWeight: FontWeight.w900,
              color: Colors.white//palette.text
            )
          ),
        )
      ),
    );
  }
}

class _Style {
  final AppDimensions _d;
  double cardSide;

  _Style(BuildContext context) : _d = AppDimensions(context) {
    cardSide = MediaQuery.of(context).size.width / 4 - 10;
  }

  double get radius => _d.radius;
  double get cardFont => _d.cardFont;

  double get cardBorder => cardSide / 8;

  double get shadowBlur => cardBorder;

  static final Color defaultBackgroundColor = Color(0xffffffff);
  static final Color defaultShadowColor = Palette.defaultShadowColor;
  static final Color defaultBorderColor = Color(0xff000000);

}