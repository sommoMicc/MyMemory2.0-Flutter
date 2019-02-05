import 'package:flutter/material.dart';

import 'package:letsmemory/UI/theme.dart';
import 'package:letsmemory/UI/background.dart';
import 'package:letsmemory/UI/main_button.dart';
import 'package:letsmemory/UI/dialog.dart';

import 'package:letsmemory/utils/network_helper.dart';
import 'package:letsmemory/models/message.dart';



class LetsMemorySignupPage extends StatefulWidget {
  @override
  State<StatefulWidget> createState() {
    return _LetsMemorySignupState();
  }
}
class _LetsMemorySignupState extends State<LetsMemorySignupPage> {
  static final _smallTextStyle = TextStyle(color: Colors.white);

  String emailValue;
  String usernameValue;

  @override
  Widget build(BuildContext context) {
    return LetsMemoryBackground(
      children: <Widget>[
        Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: <Widget>[
              Text("Registrazione", style: LetsmemoryStyles.mainTitle, textAlign: TextAlign.center),
              Container(
                padding: EdgeInsets.symmetric(vertical: 17, horizontal: LetsMemoryDimensions.standardCard),
                child: Column(children: <Widget>[
                  Text("Per registrarti, compila i seguenti campi e poi premi su \"Avanti\"", textAlign: TextAlign.center, style: _smallTextStyle),
                  Padding(padding: EdgeInsets.only(top:10)),
                  TextField(
                    keyboardType: TextInputType.emailAddress,
                    autofocus: false,
                    onChanged: (text) {
                      this.emailValue = text.trim();
                    },
                    decoration: InputDecoration(
                      contentPadding: const EdgeInsets.all(20.0),
                      fillColor: Colors.white,
                      filled: true,
                      border: OutlineInputBorder(
                        borderRadius:BorderRadius.circular(LetsMemoryDimensions.cardRadius)
                      ),
                      hintText: "Email"
                    ),
                  ),
                  Padding(padding: EdgeInsets.only(top:10)),
                  TextField(
                    keyboardType: TextInputType.text,
                    autofocus: false,
                    onChanged: (text) {
                      this.usernameValue = text.trim();
                    },
                    decoration: InputDecoration(
                      contentPadding: const EdgeInsets.all(20.0),
                      fillColor: Colors.white,
                      filled: true,
                      border: OutlineInputBorder(
                        borderRadius:BorderRadius.circular(LetsMemoryDimensions.cardRadius)
                      ),
                      hintText: "Username"
                    ),
                  ),
                ])
              ),
              LetsMemoryMainButton(
                text: "Avanti",
                backgroundColor: Colors.lightGreenAccent,
                textColor: Colors.black,
                shadowColor: Colors.lightGreenAccent[700],
                callback: () {
                  showDialog(
                    context: context,
                    barrierDismissible: false,
                    builder: (BuildContext context) {
                      return LetsMemoryDialog.progress("Registrazione in corso", 
                        "L'operazione di registrazione è in corso e terminerà tra " +
                        "qualche secondo...");
                    },
                  );
                    NetworkHelper.doSignUp(usernameValue??"", emailValue??"").then((Message signupResult) async {
                    Navigator.of(context).pop();
                    if(signupResult.status == "success") {
                      await showDialog(
                        context: context,
                        barrierDismissible: true,
                        builder: (BuildContext context) {
                          return LetsMemoryDialog.success(
                            context: context,
                            textContent: "Registrazione completata con succcesso. "+
                                  "Per effettuare il login, apri "+
                                  "il link che ti è appena stato inviato via mail"
                          );
                        },
                      );
                    }
                    else {
                      await showDialog(
                        context: context,
                        barrierDismissible: true,
                        builder: (BuildContext context) {
                          return LetsMemoryDialog.error(
                            context: context,
                            textContent: "Errore nella procedura di registrazione:\n\n"+
                              signupResult.message
                          );
                        }
                      );
                    }
                    Navigator.popUntil
                      (context, ModalRoute.withName(Navigator.defaultRouteName));
                  }).catchError((e) async {
                    Navigator.of(context).pop();
                    await showDialog(
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
                    Navigator.popUntil
                      (context, ModalRoute.withName(Navigator.defaultRouteName));
                  });
                }
              ),
              Padding(padding: EdgeInsets.only(top: 30)),
              Text("Hai gia un account?", textAlign: TextAlign.center, style: _smallTextStyle),
              Padding(padding: EdgeInsets.only(top: 10)),
              LetsMemoryMainButton(
                text: "Vai al login",
                backgroundColor: Colors.cyan[600],
                shadowColor: Colors.cyan[900],
                callback: () {
                  Navigator.pushReplacementNamed(context, "/multiplayer/login");
                  /*Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => LetsMemoryLoginPage()),
                  );*/
                }
              ),
            ],
          ),
        ),
        LetsMemoryMainButton.getBackButton(context)
      ],
    ); 
  }
}