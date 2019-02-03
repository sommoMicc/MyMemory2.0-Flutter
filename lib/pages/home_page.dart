import 'package:flutter/material.dart';
import 'package:letsmemory/models/online_user.dart';

import '../utils/storage_helper.dart';
import '../utils/network_helper.dart';
import '../utils/socket_helper.dart';
import '../utils/multiplayer_helper.dart';

import '../models/socket_listener.dart';

import '../UI/theme.dart';
import '../UI/logo.dart';
import '../UI/main_button.dart';
import '../UI/background.dart';
import '../UI/dialog.dart';

import './multiplayer/game_arena.dart';

import 'dart:async';

import 'package:uni_links/uni_links.dart';
import 'package:flutter/services.dart' show PlatformException;


class LetsMemoryHomePage extends StatefulWidget {
  @override
  State<StatefulWidget> createState() {
    return _LetsMemoryHomePageState();
  }
  
}
class _LetsMemoryHomePageState extends State<LetsMemoryHomePage> {
  StreamSubscription _sub;

  @override
  void initState() {
    super.initState();
    initUniLinks(context);
  }

  @override
  void dispose() {
    super.dispose();
    _sub.cancel();
  }

  @override
  Widget build(BuildContext context) {    
    return Scaffold(
      body: _LetsMemoryHomePageInner()
    );
  }


  Future<Null> initUniLinks(BuildContext context) async {
    // ... check initialLink
    try {
      String initialLink = await getInitialLink();
      if(initialLink != null)
        handleLink(initialLink, context);
      // Parse the link and warn the user, if it is not correct,
      // but keep in mind it could be `null`.
    } on PlatformException {
      // Handle exception by warning the user their action did not succeed
      // return?
    }
    // Attach a listener to the stream
    _sub = getLinksStream().listen((String link) {
      handleLink(link, context);
    }, onError: (err) {
      // Handle exception by warning the user their action did not succeed
    });

    // NOTE: Don't forget to call _sub.cancel() in dispose()
  }

  void handleLink(String link, BuildContext context) {
    print(link);
    Navigator.of(context).pushNamedAndRemoveUntil(
      "/",
      (route) => route.isCurrent
        ? route.settings.name == "/"
          ? false
          : true
        : true);
    if(link != null) {
      List<String> linkPieces = link.split("/login/do?t=");
      if(linkPieces.length < 2) {
        showDialog(
          context: context,
          barrierDismissible: true,
          builder: (BuildContext context) {
            return LetsMemoryDialog.error(
              context: context,
              textContent: "Il link che hai premuto non è valido"
            );
          }
        );
        return;
      }
      
      String token = linkPieces[1];
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext context) {
          // return object of type Dialog
          return LetsMemoryDialog.progress(
              "Completamento del login in corso. Attendere",
                "L'operazione dovrebbe concludersi in pochi secondi"
            );
        },
      );
      NetworkHelper.finishLogin(token).then((message) {
        Navigator.of(context).pop();
        if(message.status == "success") {
          showDialog(
            context: context,
            barrierDismissible: true,
            builder: (BuildContext context) {
              return LetsMemoryDialog.success(
                context: context,
                textContent: "Congratulazioni! "+
                      "Login completato con successo. "+
                      "Sei pronto a giocare!"
              );
            },
          );
        }
        else {
          showDialog(
            context: context,
            barrierDismissible: true,
            builder: (BuildContext context) {
              return LetsMemoryDialog.error(
                context: context,
                textContent: "Errore nella procedura di login:\n\n"+
                  message.message
              );
            }
          );

        }
      }).catchError((e) {
        Navigator.of(context).pop();
        showDialog(
          context: context,
          barrierDismissible: true,
          builder: (BuildContext context) {
            return LetsMemoryDialog.error(
              context: context,
              textContent: "Errore nella procedura di login:\n\n"+
                e.toString()
            );
          }
        );
      });
    }
  }

}

class _LetsMemoryHomePageInner extends StatefulWidget {
  @override
  State<StatefulWidget> createState() {
    return _LetsMemoryHomePageInnerState();
  }

} 
class _LetsMemoryHomePageInnerState extends State<_LetsMemoryHomePageInner>
  implements SocketListener {


  @override
  void initState() {
    super.initState();
    SocketHelper().addSocketListener(this);

    WidgetsBinding.instance
        .addPostFrameCallback((_) => SocketHelper().mightConnect());

  }

  @override
  void dispose() {
    SocketHelper().removeSocketListener(this);
    super.dispose();
  }

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
                  Navigator.pushNamed(context, "/singleplayer");
                }
              ),
              Padding(padding: EdgeInsets.only(top: LetsMemoryDimensions.standardCard)),
              LetsMemoryMainButton(
                text: "Multiplayer",
                backgroundColor: Colors.purple[500],
                shadowColor: Colors.purple[900],
                callback: () {
                  StorageHelper().getToken().then((String token) async {
                    if(token != null && token.length > 0) {
                      Navigator.pushNamed(context,"/multiplayer/findmatch");
                    }
                    else {
                      Navigator.pushNamed(context,"/multiplayer/login");
                    }
                  });
                }
              ),
            ],
          ),
        )
      ],
    );
  }

  @override
  void onLoginResult(bool success, String username) {
    if(success) {
      Scaffold.of(context).showSnackBar(
        _createSnackBar("Bentornato "+username, success) 
      );
    }
    else {
      Scaffold.of(context).showSnackBar(
       _createSnackBar("Impossibile effettuare il login. Credenziali errate.", success) 
      );
    }
  }

  SnackBar _createSnackBar(String text, bool success) {
    return SnackBar(
      content: _LetsMemorySnackbar(text,success),
      duration: Duration(seconds: 3),
    );
  }

  @override
  bool isMounted() {
    print("HomePage mounted? "+ ((this.mounted) ? "Si" : "No"));
    return this.mounted;
  }

  @override
  void onSearchResult(List<OnlineUser> users) {
    // do nothing
  }

  @override
  void onChallengeReceived(String username) {
    MultiplayerHelper().processIncomingChallenge(context, username);
  }

  @override
  void onChallengeDenided(String username) {
    MultiplayerHelper().showChallengeDenidedDialog(context, username);
  }

  @override
  void onBeginGame(String username) {
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(
        builder: (BuildContext context) => 
          LetsMemoryMultiplayerGameArena(username)
        ),
      ModalRoute.withName('/')
    );
  }
}

class _LetsMemorySnackbar extends StatelessWidget {
  final String _text;
  final bool _success;

  _LetsMemorySnackbar(this._text,this._success);

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      mainAxisAlignment: MainAxisAlignment.center,
      children: <Widget>[
        Container(
          height: 10,
          width: 10,
          decoration: BoxDecoration(
            color: this._success ? Colors.green : Colors.red,
            borderRadius: BorderRadius.circular(10),
          )
        ),
        Padding(padding: EdgeInsets.only(left: 10)),
        Text(_text, 
          style: TextStyle(
            fontSize: LetsMemoryDimensions.mainButtonFont * 2 / 3
          ),
          textAlign: TextAlign.center
        )
      ]
    );
  }
}


