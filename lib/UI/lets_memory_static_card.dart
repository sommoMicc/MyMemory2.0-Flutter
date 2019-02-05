import 'package:flutter/material.dart';
import 'package:letsmemory/UI/theme.dart';

class LetsMemoryStaticCard extends StatelessWidget {
  final String letter;
  final Color textColor;
  final Matrix4 rotation;

  final bool pressed;
  final Color backgroundColor, shadowColor;

  LetsMemoryStaticCard({this.backgroundColor, this.shadowColor, this.letter, this.textColor = Colors.white, this.rotation, this.pressed = false});
    
  @override
  Widget build(BuildContext context) {
    //Così posso fare un override semplice dei colori senza violare la regola
    //che tutti i campi di uno StatelessWidget devono essere final
    //L'espressione "a = b ?? c" equivale a "a = (b == null) ? c : b"
    Color background = this.backgroundColor ?? LetsMemoryColors.standardCardBackground;
    Color shadow = this.shadowColor ?? LetsMemoryColors.standardCardShadow;

    return Transform(
      alignment: FractionalOffset.center, // set transform origin
      transform: this.rotation == null ? Matrix4.identity() : this.rotation,
      child: Container(
        constraints: new BoxConstraints(
          minHeight: LetsMemoryDimensions.standardCard,
          minWidth: LetsMemoryDimensions.standardCard,
        ),
        decoration: BoxDecoration(
          color: this.pressed ?
            shadow : background,
          borderRadius: BorderRadius.circular(LetsMemoryDimensions.cardRadius),
          boxShadow: [
            BoxShadow(
              color: shadow,
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