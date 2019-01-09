import 'package:flutter/material.dart';
import './lets_memory_static_card.dart';

class LetsMemoryCard extends StatefulWidget {
  final String letter;
  final Color textColor;
  final Matrix4 rotation;

  final bool pressed;

  LetsMemoryCard({this.letter, this.textColor = Colors.white, this.rotation, this.pressed = false});

  @override
  State<StatefulWidget> createState() {
    return LetsMemoryCardState(pressed: this.pressed);
  }
}

class LetsMemoryCardState extends State<LetsMemoryCard> {
  bool covered;
  bool tapable;
  bool pressed;

  LetsMemoryCardState({this.tapable=true,this.covered=false,this.pressed=false});


  void _onTapDown(TapDownDetails details) {
    setState(()  {
      pressed = true;
    });
  }

  void _onTapUp(TapUpDetails details) {
    setState(() {
      pressed = false;
    });
  }

  void _onTapCancel() {
    this._onTapUp(null);
  }

 @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: _onTapDown,
      onTapUp: _onTapUp,
      onTapCancel: _onTapCancel,
      child: LetsMemoryStaticCard(
        letter: widget.letter,
        textColor: widget.textColor,
        rotation: widget.rotation,
        pressed: widget.pressed
      )
    );
  }
}
