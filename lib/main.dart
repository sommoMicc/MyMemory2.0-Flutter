import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:letsmemory/pages/home_page.dart';

import 'package:letsmemory/pages/multiplayer/login.dart';
import 'package:letsmemory/pages/multiplayer/signup.dart';
import 'package:letsmemory/pages/multiplayer/find_match.dart';

import 'package:letsmemory/pages/singleplayer/game_arena.dart';
import 'package:letsmemory/pages/singleplayer/game_result.dart';

//import 'package:letsmemory/pages/provasocket.dart';

void main() {  
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp])
  .then((_) {
    runApp(  
      MaterialApp(
        debugShowCheckedModeBanner:false,
        title: "Let's Memory!",
        initialRoute: '/',
        routes: {
          '/': (context) => LetsMemoryHomePage(),
          '/multiplayer/login': (context) => LetsMemoryLoginPage(),
          '/multiplayer/signup': (context) => LetsMemorySignupPage(),
          '/multiplayer/findmatch': (context) => LetsMemoryFindMatch(),
          '/singleplayer': (context) => LetsMemoryGameArena(),
          '/singleplayer/gameresult': (context) => LetsMemoryGameResult()
        },
      )
    );
  });
}
