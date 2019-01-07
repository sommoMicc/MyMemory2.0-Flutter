import 'package:flutter/material.dart';

import './theme.dart';

class LetsMemoryCard extends StatefulWidget {
  final String letter;
  final Color textColor;
  final Matrix4 rotation;

  final VoidCallback onTapCallback;

  LetsMemoryCard({this.letter, this.textColor = Colors.white, this.rotation, this.onTapCallback = null,});

  @override
  State<StatefulWidget> createState() {
    return LetsMemoryCardState();
  }
}

class LetsMemoryCardState extends State<LetsMemoryCard> {
  bool covered;
  bool tapable;

  @override
  void initState() {
    this.covered = true;
    this.tapable = false;
  }

  @override
  Widget build(BuildContext context) {
    // TODO: implement build
    return Transform(
      alignment: FractionalOffset.center, // set transform origin
      transform: widget.rotation,
      child: Stack(
        alignment: Alignment.topCenter,
        children: <Widget>[
          Container(
            height: LetsMemoryDimensions.standardCard + 4,
            width: LetsMemoryDimensions.standardCard,
            decoration: BoxDecoration(
              color: const Color(0xFFA9B8E1),
              borderRadius: BorderRadius.circular(LetsMemoryDimensions.cardRadius),
              //border: Border.all(color: this.textColor, width: LetsMemoryDimensions.cardBorder)
            )
          ),
          Container(
            height: LetsMemoryDimensions.standardCard,
            width: LetsMemoryDimensions.standardCard,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(LetsMemoryDimensions.cardRadius),
              //border: Border.all(color: this.textColor, width: LetsMemoryDimensions.cardBorder)
            ),
            child: Center(
              child: Text(widget.letter,
                style: TextStyle(
                  fontSize: LetsMemoryDimensions.cardFont,
                  fontWeight: FontWeight.bold,
                  color: widget.textColor
                )
              ),
            )
          ),
        ])
      );
  }
}
