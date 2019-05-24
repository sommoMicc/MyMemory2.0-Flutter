import 'package:flutter/material.dart';
import 'package:lets_memory/UI/styles/palette.dart';


class AppBackground extends StatelessWidget {
  final List<Widget> children;
  AppBackground({this.children = const <Widget>[]});

  @override
  Widget build(BuildContext context) {
    List<Widget> backgroundArts = <Widget>[
      Opacity(
        opacity: .2,
        child: Container(
          decoration: BoxDecoration(
            image: DecorationImage(
              image: AssetImage("assets/raw_pattern.jpg"),
              repeat: ImageRepeat.repeat
            )
          ),
        ),
      ),
      Container(
        decoration: BoxDecoration(
          // Box decoration takes a gradient
          gradient: RadialGradient(
            colors: Palette.backgroundColors
          ),
        ),
      )
    ];

    backgroundArts.forEach((art) => this.children.insert(0, art));

    return Stack(children: this.children);
  }
}
