import 'package:flutter/material.dart';

import './theme.dart';
import './main_button.dart';

class LetsMemoryOverlay extends StatelessWidget {

  final List<Widget> children;
  final bool visible;

  final VoidCallback onTap;

  LetsMemoryOverlay({this.children,this.visible, this.onTap});

  factory LetsMemoryOverlay.simple({bool visible,String text, VoidCallback onTap}) {
    return LetsMemoryOverlay(
      visible: visible,
      onTap: onTap,
      children: <Widget>[
        Text(
          text??"",
          style: LetsmemoryStyles.mediumTitle,
          textAlign: TextAlign.center,
        )
      ],
    );
  }

  factory LetsMemoryOverlay.withTitle({bool visible,String title, String body, VoidCallback onTap}) {
    return LetsMemoryOverlay(
      visible: visible,
      onTap: onTap,
      children: <Widget>[
        Text(
          title??"",
          style: LetsmemoryStyles.mediumTitle,
          textAlign: TextAlign.center,
        ),
        Text(
          title??"",
          style: LetsmemoryStyles.smallTitle,
          textAlign: TextAlign.center,
        )
      ],
    );
  }


  factory LetsMemoryOverlay.withTitleAndButton({bool visible,String title, String body, String buttonText, VoidCallback onTap}) {
    return LetsMemoryOverlay(
      visible: visible,
      onTap: onTap,
      children: <Widget>[
        Text(
          title??"",
          style: LetsmemoryStyles.mediumTitle,
          textAlign: TextAlign.center,
        ),
        Padding(padding: EdgeInsets.only(top: 10)),
        Text(
          body??"",
          style: TextStyle(
            color: Colors.white,
            fontSize: LetsMemoryDimensions.mediumTitle * 2 / 3
          ),
          textAlign: TextAlign.center,
        ),
        Padding(padding: EdgeInsets.only(top: 10)),
        LetsMemoryMainButton(
          backgroundColor: Colors.indigo[500],
          shadowColor: Colors.indigo[900],
          textColor: Colors.white,
          text: buttonText,
          mini: true,
          callback: onTap,
        )

      ],
    );
  }

  factory LetsMemoryOverlay.withButton({
    bool visible,String text, String buttonText, VoidCallback callback}) {

    return LetsMemoryOverlay(
      visible: visible,
      onTap: callback,
      children: <Widget>[
        Text(
          text??"",
          style: LetsmemoryStyles.mediumTitle,
          textAlign: TextAlign.center,
        ),
        Padding(padding: EdgeInsets.only(top: 10)),
        LetsMemoryMainButton(
          backgroundColor: Colors.indigo[500],
          shadowColor: Colors.indigo[900],
          textColor: Colors.white,
          text: buttonText,
          mini: true,
          callback: callback,
        )
      ],
    );
  }

  void _onTap() {
    if(onTap != null) onTap();
  }
    

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _onTap,
      child:  Visibility(
        visible: this.visible,
        child: Container(
          padding: EdgeInsets.all(20),
          color: Color(0xBB000000),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: children
            )
          ),
        )
      )
    );
  }
}