import 'package:flutter/material.dart';

import './pages/home_page.dart';
import './pages/login.dart';
import './pages/signup.dart';
import './pages/game_arena.dart';
import './pages/game_result.dart';

void main() => runApp(
  MaterialApp(
    title: "Let's Memory!",
    initialRoute: '/',
    routes: {
      '/': (context) => LetsMemoryHomePage(),
      '/login': (context) => LetsMemoryLoginPage(),
      '/signup': (context) => LetsMemorySignupPage(),
      '/singleplayer': (context) => LetsMemoryGameArena(),
      '/gameresult': (context) => LetsMemoryGameResult()
    },
  )
);
