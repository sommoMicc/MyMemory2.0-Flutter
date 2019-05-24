import 'package:flutter/material.dart';
import 'package:letsmemory/UI/theme.dart';

class LetsMemoryBackground extends StatelessWidget {

  final List<Widget> children;
  LetsMemoryBackground({this.children = const <Widget> []});

  @override
  Widget build(BuildContext context) {
    final double bigCircleRadius = MediaQuery.of(context).size.width * 1.5;
    final double smallCircleRadius = MediaQuery.of(context).size.width;

    List<Widget> backgroundArts = <Widget>[
      Positioned(
        child: Container(
          width: bigCircleRadius,
          height: bigCircleRadius,
          decoration: new BoxDecoration(
            color: LetsMemoryColors.darkestBackground,
            shape: BoxShape.circle,
          )
        ),
        top: -bigCircleRadius/4,
        left: -bigCircleRadius/4,
      ),
      Positioned(
        child: Container(
          width: smallCircleRadius,
          height: smallCircleRadius,
          decoration: new BoxDecoration(
            color: LetsMemoryColors.darkerBackground,
            shape: BoxShape.circle,
          )
        ),
        bottom: 0,
        right: -smallCircleRadius/2,
      )
    ];

    backgroundArts.forEach((art)=> this.children.insert(0,art));
    
    return Material(
      color: LetsMemoryColors.background,
      child: Stack(
        children: this.children
      )
    );
  }

}