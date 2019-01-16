import 'package:flutter/material.dart';
import '../UI/background.dart';
import '../utils/game_arena_utils.dart';

class LetsMemoryGameArena extends StatefulWidget {
  @override
  State<StatefulWidget> createState() {
    return _LetsMemoryGameArenaState();
  }

}

class _LetsMemoryGameArenaState extends State<LetsMemoryGameArena> {
  @override
  Widget build(BuildContext context) {
    return LetsMemoryBackground(
      children: <Widget>[
        Center(
          child: GridView.count(
            primary: true,
            crossAxisCount: 3,
            shrinkWrap:true,
            // Generate 100 Widgets that display their index in the List
            children: GameArenaUtils.generateCardList(3*4),
          )
        )
      ],
    );
  }
}