import 'package:flutter/material.dart';
import 'package:letsmemory/models/online_user.dart';

import 'package:letsmemory/utils/storage_helper.dart';
import 'package:letsmemory/utils/network_helper.dart';
import 'package:letsmemory/utils/socket_helper.dart';
import 'package:letsmemory/utils/multiplayer_helper.dart';

import 'package:letsmemory/models/socket_listener.dart';

import 'package:letsmemory/UI/theme.dart';
import 'package:letsmemory/UI/logo.dart';
import 'package:letsmemory/UI/main_button.dart';
import 'package:letsmemory/UI/background.dart';
import 'package:letsmemory/UI/dialog.dart';
import 'package:letsmemory/UI/overlay.dart';

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
    WidgetsBinding.instance.addPostFrameCallback((_) {
      initUniLinks(context);
    });

  }

  @override
  void dispose() {
    _sub.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {    
    return Scaffold(
      body: _LetsMemoryHomePageInner()
    );
  }


  void initUniLinks(BuildContext context) async {
    try {
      String initialLink = await getInitialLink();
      if(initialLink != null) {
        handleLink(initialLink, context);
      }
    }
     on PlatformException {
       print("Platform exception");
    }
    if(_sub == null)
      _sub = getLinksStream().listen((String link) {
        handleLink(link, context);
      }, onError: (err) {
        // Handle exception by warning the user their action did not succeed
      });
  }

  void handleLink(String link, BuildContext context) {
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

  bool tutorialVisible;
  bool logoutVisible;

  @override
  void initState() {
    super.initState();
    SocketHelper().addSocketListener(this);
    WidgetsBinding.instance
      .addPostFrameCallback((_) {
        SocketHelper().mightConnect();
      });
    tutorialVisible = false;
    checkTutorialVisible();
    logoutVisible = false;
    checkLogoutVisible();
  }

  void checkTutorialVisible() async {
    if(await StorageHelper().getFirstLaunch()) {
      setState(() {
        tutorialVisible = true;
      });
    }
  }

  Future<bool> checkLogoutVisible() async {
    if((await StorageHelper().getToken() ?? "").length > 0) {
      if(!logoutVisible)
        setState(() {
          logoutVisible = true;
        });
      return true;
    }
    else {
      if(logoutVisible)
      setState(() {
        logoutVisible = false;
      });
      return false;
    }
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
                      if(SocketHelper().isConnected)
                        Navigator.pushNamed(context,"/multiplayer/findmatch");
                      else
                        showDialog(
                          context: context,
                          barrierDismissible: true,
                          builder: (BuildContext context) {
                            return LetsMemoryDialog.error(
                              context: context,
                              textContent: "Connessione ad internet assente. Impossibile "+
                              "proseguire con la modalità multigiocatore!"
                            );
                          }
                        );
                    }
                    else {
                      Navigator.pushNamed(context,"/multiplayer/login");
                    }
                  });
                }
              ),
            ],
          ),
        ),
        _LetsMemoryLogoutButton(this.logoutVisible),
        LetsMemoryOverlay.withTitleAndButton(
          visible: this.tutorialVisible,
          title: "Benvenuto in LetsMemory!",
          body: "Il gioco prevede due modalità:"+
          " singleplayer, dove ti potrai esercitare e multiplayer, dove potrai "+
          "mettere in pratica le tue abilità per avvincenti sfide con gli amici!",
          buttonText: "Inziamo!",
          onTap: () {
            setState(() {
              tutorialVisible = false;
              StorageHelper().setFirstLaunch(false);
              Navigator.pushNamed(context, "/singleplayer");
            });
          },
        )
      ],
    );
  }

  @override
  void onLoginResult(bool success, String username) {
    print("ON LOGIN RESULT");
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
    checkLogoutVisible();
  }

  SnackBar _createSnackBar(String text, bool success) {
    return SnackBar(
      content: _LetsMemorySnackbar(text,success),
      duration: Duration(seconds: 2),
    );
  }

  @override
  bool isMounted() {
    return this.mounted;
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
  void onBeginGame(int number, String adversary, List<dynamic> cards) {
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(
        builder: (BuildContext context) => 
          LetsMemoryMultiplayerGameArena(number,adversary,cards)
        ),
      ModalRoute.withName('/')
    );
  }

  @override
  void onAdversaryLeft() {
    MultiplayerHelper().showAdversaryLeftDialog(context);
  }

  @override
  void onDisconnect() async {
    if(await checkLogoutVisible()) {
      Scaffold.of(context).showSnackBar(
        _createSnackBar("Connessione persa :(", false)
      );
    }
  }

  @override
  void onSearchResult(List<OnlineUser> users) {
    //Nothing to do here
  }

  @override
  void onReconnect() {
    Scaffold.of(context).showSnackBar(
      _createSnackBar("Riconnessione in corso", false)
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

class _LetsMemoryLogoutButton extends StatelessWidget {
  final bool visible;
  _LetsMemoryLogoutButton(this.visible);

  @override
  Widget build(BuildContext context) {
    return visible ? Positioned(
      top: 0,
      child: Padding(
        padding: EdgeInsets.only(
          top: LetsMemoryDimensions
            .scaleHeight(context,LetsMemoryDimensions.backButtonPaddingTop),
          left: 4
        ),
        child: LetsMemoryMainButton(
          icon: Icons.exit_to_app,
          mini: true,
          backgroundColor: Colors.red[700],
          shadowColor: Colors.red[900],
          callback: () async {
            bool shouldLogout = await showDialog(
              context: context,
              builder: (context) => AlertDialog(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(LetsMemoryDimensions.cardRadius)
                ),
                title: new Text("Conferma!"),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Text("Vuoi veramente effettuare il logout dal gioco?")
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
                    textColor: Colors.white,
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
            if(shouldLogout) {
              SocketHelper().logout();
            }
          },
        )
      ),
    ) : Container(width: 0,height: 0);
  }

}

