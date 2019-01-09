import 'package:flutter/material.dart';
import './../UI/theme.dart';

class LetsMemoryBackground extends StatelessWidget {

  final List<Widget> children;
  LetsMemoryBackground({this.children = const <Widget> []});

  @override
  Widget build(BuildContext context) {
    final double bigCircleRadius = MediaQuery.of(context).size.width * 1.5;
    final double smallCircleRadius = MediaQuery.of(context).size.width;

    Widget background = Positioned(
      child: Container(
        width: bigCircleRadius,
        height: bigCircleRadius,
        decoration: new BoxDecoration(
          color: const Color(0xFF143DA5),
          shape: BoxShape.circle,
        )
      ),
      top: -bigCircleRadius/4,
      left: -bigCircleRadius/4,
    );

    Widget background2 = Positioned(
      child: Container(
        width: smallCircleRadius,
        height: smallCircleRadius,
        decoration: new BoxDecoration(
          color: const Color(0xFF2A4DA5),
          shape: BoxShape.circle,
        )
      ),
      bottom: 0,
      right: -smallCircleRadius/2,
    );

    this.children.insert(0,background2);
    this.children.insert(1,background);

    return Material(
      color: LetsMemoryColors.background,
      child: Stack(
        children: this.children
      )
    );
  }

}