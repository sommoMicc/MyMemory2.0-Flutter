import 'package:flutter/material.dart';
import '../../UI/theme.dart';
import '../../UI/background.dart';

class LetsMemoryFindMatch extends StatefulWidget {
  @override
  State<StatefulWidget> createState() {
    return _LetsMemoryFindMatchState();
  }

}

class _LetsMemoryFindMatchState extends State<LetsMemoryFindMatch> {
  @override
  Widget build(BuildContext context) {
    return LetsMemoryBackground(
      children: <Widget>[
        Text("Cerca avversario",style: LetsmemoryStyles.mainTitle),
      ]
    );
  }

}