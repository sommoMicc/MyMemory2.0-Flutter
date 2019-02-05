import 'package:flutter/material.dart';

import 'package:letsmemory/UI/theme.dart';
import 'package:letsmemory/UI/background.dart';
import 'package:letsmemory/UI/main_button.dart';
import 'package:letsmemory/UI/dialog.dart';

import 'package:letsmemory/utils/network_helper.dart';
import 'package:letsmemory/models/message.dart';

class LetsMemoryLoginPage extends StatefulWidget {
  @override
  State<StatefulWidget> createState() {
    return _LetsMemoryLoginPageState();
  }  
}
class _LetsMemoryLoginPageState extends State<LetsMemoryLoginPage> {
  static final _smallTextStyle = TextStyle(color: Colors.white);
  String emailValue;

  @override
  Widget build(BuildContext context) {
    return LetsMemoryBackground(
      children: <Widget>[
        Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: <Widget>[
              Text("Login", style: LetsmemoryStyles.mainTitle, textAlign: TextAlign.center),
              Container(
                padding: EdgeInsets.symmetric(vertical: LetsMemoryDimensions.standardCard, horizontal: LetsMemoryDimensions.standardCard),
                child: Column(children: <Widget>[
                  Text("Per effettuare il login, compila il seguente campo e poi premi su \"Avanti\"", textAlign: TextAlign.center, style: _smallTextStyle),
                  Padding(padding: EdgeInsets.only(top:10)),
                  TextField(
                    keyboardType: TextInputType.emailAddress,
                    autocorrect: false,
                    onChanged: (text) {
                      this.emailValue = text.trim();
                    },
                    autofocus: false,
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
                ])
              ),
              LetsMemoryMainButton(
                text: "Avanti",
                backgroundColor: Colors.lightGreenAccent,
                textColor: Colors.black,
                shadowColor: Colors.lightGreenAccent[700],
                callback: ()  {
                  showDialog(
                    context: context,
                    barrierDismissible: false,
                    builder: (BuildContext context) {
                      // return object of type Dialog
                      return LetsMemoryDialog.progress(
                          "Login in corso. Attendere",
                           "L'operazione dovrebbe concludersi in pochi secondi"
                        );
                    },
                  );
                  NetworkHelper.doLogin(emailValue??"").then((Message signupResult) async {
                    Navigator.of(context).pop();
                    if(signupResult.status == "success") {
                      await showDialog(
                        context: context,
                        barrierDismissible: true,
                        builder: (BuildContext context) {
                          return LetsMemoryDialog.success(
                            context: context,
                            textContent: "Un ultimo sforzo! "+
                                  "Per terminare il login, apri "+
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
                            textContent: "Errore nella procedura di login:\n\n"+
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
              Padding(padding: EdgeInsets.only(top: LetsMemoryDimensions.standardCard)),
              Text("Non hai un acccount?", textAlign: TextAlign.center, style: _smallTextStyle),
              Padding(padding: EdgeInsets.only(top: LetsMemoryDimensions.standardCard/2)),
              LetsMemoryMainButton(
                text: "Registrati",
                backgroundColor: Colors.cyan[600],
                shadowColor: Colors.cyan[900],
                callback: () {
                  Navigator.pushReplacementNamed(context, "/multiplayer/signup");
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