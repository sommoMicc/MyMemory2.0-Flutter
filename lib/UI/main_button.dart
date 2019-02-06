import 'package:flutter/material.dart';
import 'package:letsmemory/UI/theme.dart';
import 'dart:io' show Platform;

class LetsMemoryMainButton extends StatefulWidget {
  final Color backgroundColor, shadowColor, textColor;
  final String text;
  final bool mini;
  final VoidCallback callback;
  final IconData icon;

  LetsMemoryMainButton({this.icon,this.backgroundColor, this.shadowColor, this.text, this.callback, this.textColor = Colors.white, this.mini=false});

  @override
  State<StatefulWidget> createState() {
    return LetsMemoryMainButtonState();
  }

  static Widget getBackButton(BuildContext context) {
    return Positioned(
      top: 0,
      left: 0,
      child: Padding(
        padding: EdgeInsets.only(
          top: LetsMemoryDimensions
            .scaleHeight(context,LetsMemoryDimensions.backButtonPaddingTop),
          left: 4
        ),
        child: LetsMemoryMainButton(
          icon: Platform.isAndroid ? Icons.arrow_back :
            Icons.arrow_back_ios,
          mini: true,
          backgroundColor: Colors.red[700],
          shadowColor: Colors.red[900],
          callback: () {
            Navigator.of(context).pop();
          },
        )
      ),
    );
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
            mini: widget.mini,
            icon: widget.icon
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
  final IconData icon;

  _LetsMemoryMainButtonContainer({this.icon,this.backgroundColor, this.shadowColor, this.text, this.height, this.textColor = Colors.white, this.mini});

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
          padding: EdgeInsets.symmetric(
            horizontal: LetsMemoryDimensions.cardFont
          ),
          child: icon == null ? Text(this.text,
            style: TextStyle(
              fontSize: mini ? LetsMemoryDimensions.cardFont * 
                LetsMemoryDimensions.miniButtonScaleFactor 
                : LetsMemoryDimensions.cardFont,
              fontWeight: mini ? FontWeight.w500 : FontWeight.w900,
              color: this.textColor
            )
          ) : Icon(
            this.icon,
            color: this.textColor,
            size: mini ? LetsMemoryDimensions.cardFont * 
              LetsMemoryDimensions.miniButtonScaleFactor 
                : LetsMemoryDimensions.cardFont,
          )
        )
      )
    );
  }

}