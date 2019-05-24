import 'package:flutter/material.dart';
import 'package:lets_memory/UI/styles/palette.dart';
import 'package:lets_memory/UI/styles/style.dart';

class PagerElement extends StatelessWidget {
  final Widget child;
  final ColorPalette palette;

  PagerElement({this.child,this.palette});

  @override
  Widget build(BuildContext context) {
    final _Style s = _Style(AppDimensions(context));
    return SizedBox(
      width: double.infinity,
      height: double.infinity,
      child: Container(
        decoration: BoxDecoration(
          color: palette.primary,
          borderRadius: BorderRadius.all(
              Radius.circular(s.radius)
          ),
          border: Border.all(color: palette.dark, width: s.border),
          boxShadow: [
            BoxShadow(
              color: s.shadowColor,
              offset: Offset(-3.0, 5.0),
              blurRadius: 0,
              spreadRadius: 0
            )
          ]
        ),
        child: Padding(
            padding: EdgeInsets.all(s.internalPadding),
            child: child
        )

      ),
    );
  }
}

class _Style {
  final AppDimensions d;
  _Style(this.d);

  Color get shadowColor => Palette.defaultShadowColor;
  double get radius => d.radius;
  double get border => d.scale(15, Measure.width);

  double get internalPadding => d.scale(10,Measure.width);
}