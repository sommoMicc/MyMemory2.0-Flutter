import 'package:flutter/material.dart';
import '../UI/theme.dart';

class LetsMemoryDialog {
  static AlertDialog success({String textContent}) {
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
    );
  } 
  static AlertDialog error({String textContent}) {
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