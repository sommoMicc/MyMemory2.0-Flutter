import 'package:flutter/material.dart';

import '../../UI/background.dart';

class LetsMemoryMultiplayerGameArena extends StatefulWidget {
  final String adversaryUsername;

  LetsMemoryMultiplayerGameArena(this.adversaryUsername);
  
  @override
  State<StatefulWidget> createState() {
    return _LetsMemoryMultiplayerGameArenaState();
  }
}

class _LetsMemoryMultiplayerGameArenaState extends State<LetsMemoryMultiplayerGameArena> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: LetsMemoryBackground(
        children: <Widget>[
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Text(widget.adversaryUsername)
            ],
          )
        ],
      )
    );
  }
}