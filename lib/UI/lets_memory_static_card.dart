import 'package:flutter/material.dart';
import './theme.dart';

class LetsMemoryStaticCard extends StatelessWidget {
  final String letter;
  final Color textColor;
  final Matrix4 rotation;

  final bool pressed;

  LetsMemoryStaticCard({this.letter, this.textColor = Colors.white, this.rotation, this.pressed = false});

 @override
  Widget build(BuildContext context) {
    return Transform(
      alignment: FractionalOffset.center, // set transform origin
      transform: this.rotation,
      child: Stack(
        alignment: Alignment.topCenter,
        children: <Widget>[
          Container(
            height: LetsMemoryDimensions.standardCard + 4,
            width: LetsMemoryDimensions.standardCard,
            decoration: BoxDecoration(
              color: LetsMemoryColors.standardCardShadow,
              borderRadius: BorderRadius.circular(LetsMemoryDimensions.cardRadius),
              //border: Border.all(color: this.textColor, width: LetsMemoryDimensions.cardBorder)
            )
          ),
          Container(
            height: LetsMemoryDimensions.standardCard,
            width: LetsMemoryDimensions.standardCard,
            decoration: BoxDecoration(
              color: this.pressed ?
                LetsMemoryColors.standardCardShadow : LetsMemoryColors.standardCardBackground,
              borderRadius: BorderRadius.circular(LetsMemoryDimensions.cardRadius),
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
        ])
      );
    
  }
}