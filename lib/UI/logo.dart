import 'package:flutter/material.dart';
import './lets_memory_static_card.dart';
import './theme.dart';

class LetsMemoryLogo extends StatefulWidget {

  final Matrix4 leftRotation = Matrix4.rotationZ(-0.174533);
  final Matrix4 rightRotation = Matrix4.rotationZ(0.174533);
  final Color yellow = const Color(0xFFFFC107);

  @override
  State<StatefulWidget> createState() {
    return LetsMemoryLogoState();
  }
}

class LetsMemoryLogoState extends State<LetsMemoryLogo> {
  
  bool pressed;


  @override
  void initState() {
    super.initState();
    pressed = false;
  }

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
      child: Column(
          children: <Widget>[
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                LetsMemoryStaticCard(letter: "L",textColor: Colors.red, rotation: widget.leftRotation, pressed: pressed),
                LetsMemoryStaticCard(letter: "E",textColor: Colors.orange, rotation: widget.rightRotation, pressed: pressed),
                LetsMemoryStaticCard(letter: "T'",textColor: widget.yellow, rotation: widget.leftRotation, pressed: pressed),
                Padding(padding: EdgeInsets.only(left: LetsMemoryDimensions.standardCard * 1 / 2)),
                LetsMemoryStaticCard(letter: "S",textColor: Colors.green, rotation: widget.rightRotation, pressed: pressed),
              ],
            ),
            Padding(padding: EdgeInsets.only(top: LetsMemoryDimensions.standardCard/3)),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                LetsMemoryStaticCard(letter: "M",textColor: Colors.red, rotation: widget.leftRotation, pressed: pressed),
                LetsMemoryStaticCard(letter: "E",textColor: Colors.orange, rotation: widget.rightRotation, pressed: pressed),
                LetsMemoryStaticCard(letter: "M",textColor: widget.yellow, rotation: widget.leftRotation, pressed: pressed),
                LetsMemoryStaticCard(letter: "O",textColor: Colors.green, rotation: widget.rightRotation, pressed: pressed),
                LetsMemoryStaticCard(letter: "R",textColor: Colors.indigo, rotation: widget.leftRotation, pressed: pressed),
                LetsMemoryStaticCard(letter: "Y",textColor: Colors.deepPurple, rotation: widget.rightRotation, pressed: pressed),
              ],
            )
          ],
      )
    );
  }

}