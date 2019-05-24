import 'package:flutter/material.dart';
import 'package:lets_memory/UI/styles/palette.dart';
import 'dart:math';

import 'package:lets_memory/UI/styles/style.dart';
import 'game_card/card_face.dart';

class AppLogo extends StatefulWidget {

  static final double LEFT_ROTATION_VALUE = -0.174533;
  static final double RIGHT_ROTATION_VALUE = LEFT_ROTATION_VALUE * -1;

  final Matrix4 leftRotation = Matrix4.rotationZ(LEFT_ROTATION_VALUE);
  final Matrix4 rightRotation = Matrix4.rotationZ(RIGHT_ROTATION_VALUE);

  @override
  State<StatefulWidget> createState() {
    return AppLogoState();
  }
}

class AppLogoState extends State<AppLogo>  with SingleTickerProviderStateMixin {
  _Style _s;

  bool pressed;

  Animation<double> animation;
  AnimationController controller;

  bool reverseAnimation;

  double leftRotationValue;
  double rightRotationValue;

  CurvedAnimation curve;
  void initState() {
    super.initState();
    reverseAnimation = false;

    leftRotationValue = AppLogo.LEFT_ROTATION_VALUE;
    rightRotationValue = AppLogo.RIGHT_ROTATION_VALUE;

    controller = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this
    );

    curve = CurvedAnimation(parent: controller, curve: Curves.bounceIn);

    animation = Tween(begin: -2*pi, end: 0.0)
      .animate(curve)
      ..addListener(() {
        setState(() {
          leftRotationValue = AppLogo.LEFT_ROTATION_VALUE + animation.value;
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
    if(!controller.isAnimating) {
      reverseAnimation ? controller.reverse() : controller.forward();
      reverseAnimation = !reverseAnimation;
    }
  }

  @override
  Widget build(BuildContext context) {
    AppDimensions d = AppDimensions(context);
    _s = _Style(d);

    return GestureDetector(
      onTapDown: _onTapDown,
      onTapUp: _onTapUp,
      onTapCancel: _onTapCancel,
      onTap: _onTap,
      child: Column(
        mainAxisAlignment: _s.d.orientation == Orientation.portrait ?
          MainAxisAlignment.end : MainAxisAlignment.center,
        children: <Widget>[
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              _generateCard("L","red",leftRotationValue),
              _generateCard("E","orange",rightRotationValue),
              _generateCard("T","yellow",leftRotationValue),
              _generateCard("'","green",rightRotationValue),
              Padding(padding: EdgeInsets.only(left: _s.cardSide * 1 / 2)),
              _generateCard("S","indigo",leftRotationValue),
            ],
          ),
          Padding(padding: EdgeInsets.only(top: d.scale(5,Measure.height))),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              _generateCard("M","lightGreen",leftRotationValue),
              _generateCard("E","amber",rightRotationValue),
              _generateCard("M","orange",leftRotationValue),
              _generateCard("O","deepOrange",rightRotationValue),
              _generateCard("R","brown",leftRotationValue),
              _generateCard("Y","blueGrey",rightRotationValue),
            ],
          )
        ],
      )
    );
  }

  CardFace _generateCard(String letter, String color, double rotationValue) {
    return CardFace(
      size: _s.cardSide,
      fontSize: _s.fontSize,
      text: letter,
      palette: Palette.colors[color],
      rotation: Matrix4.rotationZ(rotationValue),
      pressed: pressed
    );
  }
}

class _Style {
  final AppDimensions d;
  _Style(this.d);

  double get cardSide => d.logoCardSide;
  double get fontSize => d.logoFontSize;
}