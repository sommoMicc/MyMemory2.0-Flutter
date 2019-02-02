import 'package:flutter/material.dart';

import '../utils/storage_helper.dart';
import '../utils/network_helper.dart';
import '../utils/socket_helper.dart';

import '../models/socket_listener.dart';

import '../UI/theme.dart';
import '../UI/logo.dart';
import '../UI/main_button.dart';
import '../UI/background.dart';
import '../UI/dialog.dart';

import 'dart:async';

import 'package:uni_links/uni_links.dart';
import 'package:flutter/services.dart' show PlatformException;


class LetsMemoryHomePage extends StatefulWidget {
  @override
  State<StatefulWidget> createState() {
    return _LetsMemoryHomePageState();
  }
  
}
class _LetsMemoryHomePageState extends State<LetsMemoryHomePage> implements SocketListener {
  StreamSubscription _sub;

  @override
  void initState() {
    super.initState();
    initUniLinks(context);
  }
  @override
  Widget build(BuildContext context) {
    SocketHelper.currentSocketListener = this;

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
                  StorageHelper().getUsername().then((String username) async {
                    Navigator.pushNamed(context,"/login");
                  });
                }
              ),
            ],
          ),
        )
      ],
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

  @override
  void onLoginResult(bool success, String username) {
    if(success) {
      print("Login effettuato con successo!!");
    }
    else {
      print("Errore nel login");
    }
  }

  

}


