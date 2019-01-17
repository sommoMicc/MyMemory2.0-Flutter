import 'package:flutter/material.dart';
import './theme.dart';

class LetsMemoryStaticCard extends StatelessWidget {
  final String letter;
  final Color textColor;
  Matrix4 rotation;

  final bool pressed;

  LetsMemoryStaticCard({this.letter, this.textColor = Colors.white, this.rotation, this.pressed = false}) {
    if(this.rotation == null) {
      this.rotation = Matrix4.identity();
    }
  }

 @override
  Widget build(BuildContext context) {
    return Transform(
      alignment: FractionalOffset.center, // set transform origin
      transform: this.rotation,
      child: Container(
        height: LetsMemoryDimensions.standardCard,
        width: LetsMemoryDimensions.standardCard,
        decoration: BoxDecoration(
          color: this.pressed ?
            LetsMemoryColors.standardCardShadow : LetsMemoryColors.standardCardBackground,
          borderRadius: BorderRadius.circular(LetsMemoryDimensions.cardRadius),
          boxShadow: [
            BoxShadow(
              color: LetsMemoryColors.standardCardShadow,
              offset: Offset(0, 4.0),
              blurRadius: 0.0,
              spreadRadius: 0
            )
          ]
          //border: Border.all(color: this.textColor, width: LetsMemoryDimensions.cardBorder)
        ),
        child: Center(
          child: Text(this.letter,
            style: TextStyle(
              fontSize: LetsMemoryDimensions.cardFont,
              fontWeight: FontWeight.bold,
              color: this.textColor
            )
          ),
        )
      ),
    );
  }
}