import 'package:flutter/material.dart';
import '../UI/theme.dart';
import '../UI/main_button.dart';

class LetsMemoryDialog {
  static AlertDialog success({BuildContext context, String textContent}) {
    return AlertDialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(LetsMemoryDimensions.cardRadius)
      ),
      title: new Text("Successo!"),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(
            Icons.done_outline,
            color: Colors.green[500],
            size: LetsMemoryDimensions.standardCard *2,
          ),
          Padding(padding: EdgeInsets.only(top:LetsMemoryDimensions.standardCard/2)),
          Text(textContent)
        ],
      ),
      actions: <Widget>[
        LetsMemoryMainButton(
          textColor: Colors.black,
          backgroundColor: Colors.lightGreen[500],
          shadowColor: Colors.lightGreen[900],
          mini: true,
          text: "OK",
          callback: () {
            Navigator.pop(context);
          },
        )
      ],
    );
  } 
  static AlertDialog error({BuildContext context, String textContent}) {
    return AlertDialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(LetsMemoryDimensions.cardRadius)
      ),
      title: new Text("Errore :("),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(
            Icons.error_outline,
            color: Colors.red[500],
            size: LetsMemoryDimensions.standardCard *2,
          ),
          Padding(padding: EdgeInsets.only(top:LetsMemoryDimensions.standardCard/2)),
          Text(textContent)
        ],
      ),
      actions: <Widget>[
        LetsMemoryMainButton(
          textColor: Colors.black,
          backgroundColor: Colors.lightGreen[500],
          shadowColor: Colors.lightGreen[900],
          text: "OK",
          mini: true,
          callback: () {
            Navigator.pop(context);
          },
        )
      ],

    );
  } 

  static AlertDialog progress(String title, String content) {
    return AlertDialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(LetsMemoryDimensions.cardRadius)
      ),
      title: new Text(title),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          CircularProgressIndicator(
            strokeWidth: 10,
            backgroundColor: Colors.purple[500]
          ),
          Padding(padding: EdgeInsets.only(top:LetsMemoryDimensions.standardCard/2)),
          Text(content)
        ],
      ),
    );
  }
}