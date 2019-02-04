import 'package:flutter/material.dart';
import '../../UI/main_button.dart';
import '../../UI/background.dart';
import '../../UI/theme.dart';

class LetsMemoryMultiplayerGameResult extends StatelessWidget {
  final String text;

  LetsMemoryMultiplayerGameResult(this.text);
    
  @override
  Widget build(BuildContext context) {
    return LetsMemoryBackground(
      children: <Widget>[
        Container(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: <Widget>[
              Text(
                text, 
                style: LetsmemoryStyles.mediumTitle,
                textAlign: TextAlign.center
              ),
              Padding(padding: EdgeInsets.only(top: LetsMemoryDimensions.standardCard*3/2)),
              Padding(padding: EdgeInsets.only(top: LetsMemoryDimensions.standardCard)),
              LetsMemoryMainButton(
                text: "Torna alla home",
                backgroundColor: Colors.purple[500],
                shadowColor: Colors.purple[900],
                callback: () {
                  Navigator.popUntil
                    (context, ModalRoute.withName(Navigator.defaultRouteName));
                },
              ),
            ],
          )
        )
      ],
    );
  }

}