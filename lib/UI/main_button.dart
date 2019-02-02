import 'package:flutter/material.dart';
import './theme.dart';

class LetsMemoryMainButton extends StatefulWidget {
  final Color backgroundColor, shadowColor, textColor;
  final String text;
  final bool mini;
  final VoidCallback callback;

  LetsMemoryMainButton({this.backgroundColor, this.shadowColor, this.text, this.callback, this.textColor = Colors.white, this.mini=false});

  @override
  State<StatefulWidget> createState() {
    return LetsMemoryMainButtonState();
  }
}

class LetsMemoryMainButtonState extends State<LetsMemoryMainButton> {
  bool _pressed = false;

  void _onTapDown(TapDownDetails details) {
    setState(()  {
      _pressed = true;
    });
  }

  void _onTapUp(TapUpDetails details) {
    setState(() {
      _pressed = false;
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
      onTap: widget.callback,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          _LetsMemoryMainButtonContainer(
            backgroundColor: _pressed ? widget.shadowColor : widget.backgroundColor,
            shadowColor: widget.shadowColor,
            text: widget.text,
            textColor: widget.textColor,
            height: LetsMemoryDimensions.standardCard,
            mini: widget.mini
          )
        ]),
      );    
  }
}

class _LetsMemoryMainButtonContainer extends StatelessWidget {

  final Color backgroundColor, textColor, shadowColor;
  final String text;
  final double height;
  final bool mini;

  _LetsMemoryMainButtonContainer({this.backgroundColor, this.shadowColor, this.text, this.height, this.textColor = Colors.white, this.mini});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: mini ? this.height * 2 / 3 : this.height,
      decoration: BoxDecoration(
        color: this.backgroundColor,
        borderRadius: BorderRadius.circular(LetsMemoryDimensions.cardRadius),
        boxShadow: [
          BoxShadow(
            color: this.shadowColor,
            offset: Offset(0, 4.0),
            blurRadius: 0.0,
            spreadRadius: 0
          )
        ]
        //border: Border.all(color: this.textColor, width: LetsMemoryDimensions.cardBorder)
      ),
      child: Center(
        child: Padding(
          padding: EdgeInsets.only(left: LetsMemoryDimensions.cardFont, right: LetsMemoryDimensions.cardFont),
          child: Text(this.text,
            style: TextStyle(
              fontSize: mini ? LetsMemoryDimensions.cardFont * 2 / 3 
                : LetsMemoryDimensions.cardFont,
              fontWeight: mini ? FontWeight.w500 : FontWeight.w900,
              color: this.textColor
            )
          ),
        )
      )
    );
  }

}