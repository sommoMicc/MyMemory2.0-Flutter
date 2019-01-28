import 'package:flutter/material.dart';

import '../utils/storage_helper.dart';

import '../UI/theme.dart';
import '../UI/logo.dart';
import '../UI/main_button.dart';
import '../UI/background.dart';

import './game_arena.dart';

class LetsMemoryHomePage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {

    return LetsMemoryBackground(
      children: <Widget>[
        Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: <Widget>[
              LetsMemoryLogo(),
              Padding(padding: EdgeInsets.only(top: LetsMemoryDimensions.standardCard*3/2)),
              LetsMemoryMainButton(
                text: "Singleplayer",
                backgroundColor: Colors.green[500],
                shadowColor: Colors.green[900],
                callback: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => LetsMemoryGameArena()),
                  );
                }
              ),
              Padding(padding: EdgeInsets.only(top: LetsMemoryDimensions.standardCard)),
              LetsMemoryMainButton(
                text: "Multiplayer",
                backgroundColor: Colors.purple[500],
                shadowColor: Colors.purple[900],
                callback: () {
                  StorageHelper().getUsername().then((String username) {
                    print(username);
                  });
                }
              ),
            ],
          ),
        )
      ],
    ); 
    
  }
}

