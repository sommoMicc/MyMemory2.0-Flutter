import 'package:flutter/material.dart';
import 'package:letsmemory/UI/theme.dart';
import 'package:letsmemory/UI/main_button.dart';
import 'package:letsmemory/UI/background.dart';

class ProvaSocket extends StatefulWidget {
  @override
  State<StatefulWidget> createState() {
    return ProvaSocketState();
  }
}

class ProvaSocketState extends State<ProvaSocket> {
  Future<bool> _onWillPop() async {
    bool shoudQuit = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(LetsMemoryDimensions.cardRadius)
        ),
        title: new Text("Conferma!"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text("Vuoi veramente sfidare abbandonare la sfida?")
          ],
        ),
        actions: <Widget>[
          LetsMemoryMainButton(
            textColor: Colors.white,
            backgroundColor: Colors.red[500],
            shadowColor: Colors.red[900],
            mini: true,
            text: "Si",
            callback: () {
              Navigator.pop(context,true);
            },
          ),
          Padding(
            padding: EdgeInsets.only(
              left: LetsMemoryDimensions
                .scaleWidth(context, 15)
              ),
          ),
          LetsMemoryMainButton(
            textColor: Colors.black,
            backgroundColor: Colors.lightGreen[500],
            shadowColor: Colors.lightGreen[900],
            mini: true,
            text: "No",
            callback: () {
              Navigator.pop(context,false);
            },
          )
        ],
      ),
    ) ?? false;

    return shoudQuit;
  }


  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: _onWillPop,
      child: LetsMemoryBackground(
        children: <Widget>[ 
          LetsMemoryMainButton.getBackButton(context,_onWillPop),
          Padding(padding: EdgeInsets.only(top: 10)),
          Text("Ciao 2")
        ]
      )
    );
  }
}