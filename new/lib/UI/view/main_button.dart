import 'package:flutter/material.dart';
import 'package:lets_memory/UI/styles/palette.dart';
import 'package:lets_memory/UI/styles/style.dart';
import 'dart:math' as math;

class MainButton extends StatefulWidget {
  static final double leftRotation = - math.pi / 180;
  static final double rightRotation = 2 * math.pi - MainButton.leftRotation;

  final ColorPalette palette;

  final Widget child;
  final String text;

  final VoidCallback callback;

  const MainButton({
    this.palette,
    this.child,
    this.text,
    this.callback
  });

  @override
  State<StatefulWidget> createState() => _MainButtonState();
}

class _MainButtonState extends State<MainButton> {
  _Style s;

  bool pressed;

  @override
  void initState() {
    // TODO: implement initState
    super.initState();
    pressed = false;
  }

  @override
  Widget build(BuildContext context) {
    s = _Style(AppDimensions(context));

    Widget child = widget.child;
    if (child == null)
      child = Center(
        child: Text(widget.text.toUpperCase(),
          style: s.getTextStyle(color: widget.palette.text)
        )
      );

    final List<BoxShadow> boxShadow = <BoxShadow> [
      BoxShadow(
          color: s.shadowColor,
          offset: Offset(-3.0, 5.0),
          blurRadius: 0,
          spreadRadius: 0
      )
    ];

    return GestureDetector(
      onTapDown: _onTapDown,
      onTapUp: _onTapUp,
      onTapCancel: () => _onTapUp(null),
      onTap: widget.callback ?? () => "Ciao",

      child: SizedBox(
        width: double.maxFinite,
        child: Container(
          decoration: BoxDecoration(
            color: pressed ? widget.palette.dark : widget.palette.primary,
            borderRadius: BorderRadius.all(
              Radius.circular(s.radius)
            ),
            border: Border.all(color: widget.palette.dark, width: s.border),
            boxShadow: pressed ? [] : boxShadow
          ),
          child: Padding(
            padding: EdgeInsets.all(s.internalPadding),
            child: child
          )
        ),
      ),
    );
  }

  void _onTapDown(_) {
    setState(() {
      pressed = true;
    });
  }

  void _onTapUp(_) {
    setState(() {
      pressed = false;
    });
  }
}

class _Style {
  final AppDimensions size;
  _Style(this.size);

  Color get defaultBackground => Color(0xffff0000);
  Color get shadowColor => Palette.defaultShadowColor;

  TextStyle getTextStyle({Color color}) => TextStyle(
    fontWeight: FontWeight.bold,
    color: color,
    fontSize: size.mainButtonFontSize
  );

  double get radius => size.radius;
  double get border => size.scale(15, Measure.width);

  double get internalPadding => size.scale(10,Measure.width);
}