import 'package:flutter/material.dart';
import './theme.dart';

class LetsMemoryMainButton extends StatefulWidget {
  final Color backgroundColor, shadowColor, textColor;
  final String text;

  final VoidCallback callback;

  LetsMemoryMainButton({this.backgroundColor, this.shadowColor, this.text, this.callback, this.textColor = Colors.white});

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
          Stack(
            alignment: Alignment.topCenter,
            children: <Widget>[
              _LetsMemoryMainButtonContainer(
                backgroundColor: widget.shadowColor, 
                text: widget.text, 
                height: LetsMemoryDimensions.standardCard + 4
              ),
              _LetsMemoryMainButtonContainer(
                backgroundColor: _pressed ? widget.shadowColor : widget.backgroundColor,
                text: widget.text,
                height: LetsMemoryDimensions.standardCard
              )
          ])
        ]),
      );    
  }
}

class _LetsMemoryMainButtonContainer extends StatelessWidget {

  final Color backgroundColor, textColor;
  final String text;
  final double height;

  _LetsMemoryMainButtonContainer({this.backgroundColor, this.text, this.height, this.textColor = Colors.white});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: this.height,
      decoration: BoxDecoration(
        color: this.backgroundColor,
        borderRadius: BorderRadius.circular(LetsMemoryDimensions.cardRadius),
        //border: Border.all(color: this.textColor, width: LetsMemoryDimensions.cardBorder)
      ),
      child: Center(
        child: Padding(
          padding: EdgeInsets.only(left: LetsMemoryDimensions.cardFont, right: LetsMemoryDimensions.cardFont),
          child: Text(this.text,
            style: TextStyle(
              fontSize: LetsMemoryDimensions.cardFont,
              fontWeight: FontWeight.w900,
              color: this.textColor
            )
          ),
        )
      )
    );
  }

}