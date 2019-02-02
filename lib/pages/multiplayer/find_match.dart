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
  String searchQuery;

  @override
  void initState() {
    super.initState();
  }
  @override
  Widget build(BuildContext context) {
    return LetsMemoryBackground(
      children: <Widget>[
        Container(
          padding: EdgeInsets.symmetric(
            horizontal: LetsMemoryDimensions.standardCard/2
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Text("Cerca avversario",
                style: LetsmemoryStyles.mainTitle,
                textAlign: TextAlign.center
              ),
              Padding(padding:EdgeInsets.only(top:10)),
              TextField(
                keyboardType: TextInputType.emailAddress,
                autocorrect: false,
                onChanged: (text) {
                  this.searchQuery = text.trim();
                },
                autofocus: false,
                decoration: InputDecoration(
                  contentPadding: const EdgeInsets.all(20.0),
                  fillColor: Colors.white,
                  filled: true,
                  border: OutlineInputBorder(
                    borderRadius:BorderRadius.circular(LetsMemoryDimensions.cardRadius)
                  ),
                  hintText: "Username...",
                  suffixIcon: Icon(
                    Icons.search,
                    size: LetsMemoryDimensions.standardCard,
                  ),
                ),
              ),
            ],
              
          ),
        ),
      ]
    );
  }

}