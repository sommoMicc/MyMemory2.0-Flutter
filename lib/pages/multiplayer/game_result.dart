import 'package:flutter/material.dart';
import 'package:letsmemory/UI/main_button.dart';
import 'package:letsmemory/UI/background.dart';
import 'package:letsmemory/UI/theme.dart';

class LetsMemoryMultiplayerGameResult extends StatelessWidget {
  final String text;

  LetsMemoryMultiplayerGameResult(this.text);
    
  @override
  Widget build(BuildContext context) {
    return LetsMemoryBackground(
      children: <Widget>[
        Align(
          alignment: Alignment.bottomCenter,
          child: Column(
            mainAxisSize: MainAxisSize.max,
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
        ),
        LetsMemoryMainButton.getBackButton(context)
        
      ],
    );
  }

}