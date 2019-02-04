import 'package:flutter/material.dart';
import 'package:letsmemory/models/online_user.dart';

import '../../UI/theme.dart';
import '../../UI/background.dart';
import '../../UI/main_button.dart';
import '../../UI/dialog.dart';

import '../../utils/socket_helper.dart';

import '../../models/socket_listener.dart';
import '../../models/online_user.dart';

class LetsMemoryFindMatch extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _LetsMemoryFindMatchInner()
    );
  }

  

}

class _LetsMemoryFindMatchInner extends StatefulWidget {
  @override
  State<StatefulWidget> createState() {
    return _LetsMemoryFindMatchInnerState();
  }
}
class _LetsMemoryFindMatchInnerState extends State<_LetsMemoryFindMatchInner> 
implements SocketListener {
  List<OnlineUser> searchResult;
  String searchQuery;

  @override
  void initState() {
    super.initState();
    searchQuery = "";
    searchResult = [];
    WidgetsBinding.instance
        .addPostFrameCallback((_) => SocketHelper().addSocketListener(this));
  }

  @override
  void dispose() {
    SocketHelper().removeSocketListener(this);
    super.dispose();
  }

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
                  suffixIcon: IconButton(
                    icon: Icon(Icons.search),
                    onPressed: () {
                      SocketHelper().searchUsers(searchQuery);
                    }
                  ),
                ),
              ),
              ListView.builder (
                itemCount: searchResult.length,
                shrinkWrap: true,
                itemBuilder: (BuildContext ctxt, int index) {
                  return _LetsMemorySearchResult(
                    searchResult[index].username,
                    searchResult[index].isOnline)
                  ;
                }
              )
            ],

          ),
        ),
      ]
    );
  }

  @override
  void onSearchResult(List<OnlineUser> users) {
    setState(() {
      this.searchResult = users;
    });
  }

  @override
  bool isMounted() {
    print("FindMatch mounted? "+ ((this.mounted) ? "Si" : "No"));
    return this.mounted;
  }

  @override
  void onLoginResult(bool success, String username) {
    // do nothing
  }

  @override
  void onChallengeReceived(String username) {
    //Ci pensa la homepage!
  }

  @override
  void onChallengeDenided(String username) {
    //Ci pensa la homepage!
  }

  @override
  void onBeginGame(int number, String adversary, List<dynamic> cards) {
    //Ci pensa la homepage!
  }

  @override
  void onAdversaryLeft() {
    // TODO: implement onAdversaryLeft
  }

  @override
  void onDisconnect() {
    // TODO: implement onDisconnect
  }

}

class _LetsMemorySearchResult extends StatefulWidget {
  final String username;
  final bool isOnline;

  _LetsMemorySearchResult(this.username,this.isOnline);

  State<StatefulWidget> createState() {
    return _LetsMemorySearchResultState();
  }
}

class _LetsMemorySearchResultState extends State<_LetsMemorySearchResult> {
  bool pressed;

  @override
  initState() {
    super.initState();
    pressed = false;
  }

  void _onTapDown(TapDownDetails details) {
    setState(()  {
      pressed = true;
    });
  }

  void _onTapUp(TapUpDetails details) {
    setState(() {
      pressed = false;
    });
  }

  void _onTapCancel() {
    this._onTapUp(null);
  }

  void _onTap() async {
    if(widget.isOnline) {
      bool confirm = await showDialog(
        barrierDismissible: true,
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(LetsMemoryDimensions.cardRadius)
            ),
            title: new Text("Conferma!"),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text("Vuoi veramente sfidare "+widget.username+"?")
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
      ) ?? false;

      if(confirm) {
        SocketHelper().sendChallenge(widget.username);
        Scaffold.of(context).showSnackBar(SnackBar(
          content: Text("In attesa che "+widget.username+" accetti la sfida"),
        ));
      }
    }
    else {
      showDialog(
        context: context,
        barrierDismissible: true,
        builder: (BuildContext context) {
          return LetsMemoryDialog.error(
            context: context,
            textContent: "Impossibile sfidare un utente offline!"
          );
        }
      );
    }
  }
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: _onTapDown,
      onTapUp: _onTapUp,
      onTapCancel: _onTapCancel,
      onTap: _onTap,
      child: Container(
        decoration: BoxDecoration(
          color: this.pressed ? Colors.grey : Colors.white,
          borderRadius: BorderRadius.circular(LetsMemoryDimensions.cardRadius),
          boxShadow: [
            BoxShadow(
              color: Colors.grey,
              offset: Offset(0, 4.0),
              blurRadius: 0.0,
              spreadRadius: 0
            )
          ]
          //border: Border.all(color: this.textColor, width: LetsMemoryDimensions.cardBorder)
        ),
        padding: EdgeInsets.all(15),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Container(
              height: 10,
              width: 10,
              decoration: BoxDecoration(
                color: widget.isOnline ? 
                  Colors.green : Colors.red,
                borderRadius: BorderRadius.circular(10),
              )
            ),
            Padding(padding: EdgeInsets.only(left: 10)),
            Text(widget.username, 
              style: TextStyle(
                fontSize: LetsMemoryDimensions.mainButtonFont * 2 / 3
              ),
              textAlign: TextAlign.center
            )
          ]
        )
      )
    );
  }
}