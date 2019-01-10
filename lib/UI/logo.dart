import 'package:flutter/material.dart';
import 'package:flutter/src/scheduler/ticker.dart';
import './lets_memory_static_card.dart';
import './theme.dart';

class LetsMemoryLogo extends StatefulWidget {

  static final double LEFT_ROTATION_VALUE = -0.174533;
  static final double RIGHT_ROTATION_VALUE = LEFT_ROTATION_VALUE * -1;

  final Matrix4 leftRotation = Matrix4.rotationZ(LEFT_ROTATION_VALUE);
  final Matrix4 rightRotation = Matrix4.rotationZ(RIGHT_ROTATION_VALUE);
  final Color yellow = const Color(0xFFFFC107);

  @override
  State<StatefulWidget> createState() {
    return LetsMemoryLogoState();
  }
}

class LetsMemoryLogoState extends State<LetsMemoryLogo>  with SingleTickerProviderStateMixin {
  
  bool pressed;

  Animation<double> animation;
  AnimationController controller;

  bool reverseAnimation;

  double leftRotationValue;
  double rightRotationValue;

  @override
  void initState() {
    super.initState();
    reverseAnimation = false;

    leftRotationValue = LetsMemoryLogo.LEFT_ROTATION_VALUE;
    rightRotationValue = LetsMemoryLogo.RIGHT_ROTATION_VALUE;

    controller = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this
    );
    animation = Tween(begin: LetsMemoryLogo.LEFT_ROTATION_VALUE, end: LetsMemoryLogo.RIGHT_ROTATION_VALUE)
      .animate(controller)
      ..addListener(() {
        setState(() {
          leftRotationValue = animation.value;
          rightRotationValue = -1*leftRotationValue;
        });
      });

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

  void _onTap() {
    reverseAnimation ? controller.reverse() : controller.forward();
    reverseAnimation = !reverseAnimation;
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: _onTapDown,
      onTapUp: _onTapUp,
      onTapCancel: _onTapCancel,
      onTap: _onTap,
      child: Column(
          children: <Widget>[
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                LetsMemoryStaticCard(letter: "L",textColor: Colors.red, rotation: Matrix4.rotationZ(leftRotationValue), pressed: pressed),
                LetsMemoryStaticCard(letter: "E",textColor: Colors.orange, rotation: Matrix4.rotationZ(rightRotationValue), pressed: pressed),
                LetsMemoryStaticCard(letter: "T'",textColor: widget.yellow, rotation: Matrix4.rotationZ(leftRotationValue), pressed: pressed),
                Padding(padding: EdgeInsets.only(left: LetsMemoryDimensions.standardCard * 1 / 2)),
                LetsMemoryStaticCard(letter: "S",textColor: Colors.green, rotation: Matrix4.rotationZ(rightRotationValue), pressed: pressed),
              ],
            ),
            Padding(padding: EdgeInsets.only(top: LetsMemoryDimensions.standardCard/3)),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                LetsMemoryStaticCard(letter: "M",textColor: Colors.red, rotation: Matrix4.rotationZ(leftRotationValue), pressed: pressed),
                LetsMemoryStaticCard(letter: "E",textColor: Colors.orange, rotation: Matrix4.rotationZ(rightRotationValue), pressed: pressed),
                LetsMemoryStaticCard(letter: "M",textColor: widget.yellow, rotation: Matrix4.rotationZ(leftRotationValue), pressed: pressed),
                LetsMemoryStaticCard(letter: "O",textColor: Colors.green, rotation: Matrix4.rotationZ(rightRotationValue), pressed: pressed),
                LetsMemoryStaticCard(letter: "R",textColor: Colors.indigo, rotation: Matrix4.rotationZ(leftRotationValue), pressed: pressed),
                LetsMemoryStaticCard(letter: "Y",textColor: Colors.deepPurple, rotation: Matrix4.rotationZ(rightRotationValue), pressed: pressed),
              ],
            )
          ],
      )
    );
  }

}