import 'package:flutter/material.dart';

import './pages/home_page.dart';

import './pages/multiplayer/login.dart';
import './pages/multiplayer/signup.dart';
import './pages/multiplayer/find_match.dart';

import './pages/singleplayer/game_arena.dart';
import './pages/singleplayer/game_result.dart';


void main() {  
  runApp(  
    MaterialApp(
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
}
