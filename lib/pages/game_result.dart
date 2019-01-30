import 'package:flutter/material.dart';
import '../UI/main_button.dart';
import '../UI/background.dart';
import '../UI/theme.dart';

class LetsMemoryGameResult extends StatelessWidget {
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
                "Match completato\n🤪", 
                style: LetsmemoryStyles.mainTitle,
                textAlign: TextAlign.center
              ),
              Padding(padding: EdgeInsets.only(top: LetsMemoryDimensions.standardCard*3/2)),
              LetsMemoryMainButton(
                text: "Nuova partita",
                backgroundColor: Colors.green[500],
                shadowColor: Colors.green[900],
                callback: () {
                  Navigator.pushReplacementNamed(context, "/singleplayer");
                }),
              Padding(padding: EdgeInsets.only(top: LetsMemoryDimensions.standardCard)),
              LetsMemoryMainButton(
                text: "Torna alla home",
                backgroundColor: Colors.purple[500],
                shadowColor: Colors.purple[900],
                callback: () {
                  Navigator.pushReplacementNamed(context, "/");
                },
              ),
            ],
          )
        )
      ],
    );
  }

}