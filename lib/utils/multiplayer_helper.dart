import 'package:flutter/material.dart';

import '../UI/theme.dart';
import '../UI/main_button.dart';

import 'socket_helper.dart';

class MultiplayerHelper {
  static final MultiplayerHelper _singleton = MultiplayerHelper._internal();
  factory MultiplayerHelper() {
    return _singleton;
  }
  MultiplayerHelper._internal();



  void processIncomingChallenge(BuildContext context, String username) async {
    bool challengeAccepted = await showIncomingChallengeDialog(context, username) ?? false;

    if(challengeAccepted) {
      SocketHelper().acceptChallenge(username);
    }
    else {
      SocketHelper().denyChallenge(username);
    }
  }

  Future<bool> showIncomingChallengeDialog(BuildContext context, String username) {
    return showDialog(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(LetsMemoryDimensions.cardRadius)
          ),
          title: new Text("Sfida in arrivo!"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(
                Icons.priority_high,
                size: LetsMemoryDimensions.standardCard *2,
              ),
              Padding(padding: EdgeInsets.only(top:LetsMemoryDimensions.standardCard/2)),
              Text(username+" ti sta sfidando. Vuoi accettare?")
            ],
          ),
          actions: <Widget>[
            LetsMemoryMainButton(
              textColor: Colors.black,
              backgroundColor: Colors.lightGreen[500],
              shadowColor: Colors.lightGreen[900],
              mini: true,
              text: "Si",
              callback: () {
                Navigator.pop(context,true);
              },
            ),
            LetsMemoryMainButton(
              textColor: Colors.white,
              backgroundColor: Colors.red[500],
              shadowColor: Colors.red[900],
              mini: true,
              text: "No",
              callback: () {
                Navigator.pop(context,false);
              },
            )
          ],
        );
      }
    );
  }

  void showChallengeDenidedDialog(BuildContext context, String username) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(LetsMemoryDimensions.cardRadius)
          ),
          title: new Text("Oh no!"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(username+" ha rifiutato la tua sfida 😓")
            ],
          ),
          actions: <Widget>[
            LetsMemoryMainButton(
              textColor: Colors.black,
              backgroundColor: Colors.lightGreen[500],
              shadowColor: Colors.lightGreen[900],
              mini: true,
              text: "Ho capito",
              callback: () {
                Navigator.pop(context);
              },
            ),
          ],
        );
      }
    );
  }
}