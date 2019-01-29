import 'package:flutter/material.dart';

import '../UI/theme.dart';
import '../UI/background.dart';
import '../UI/main_button.dart';

import './login.dart';

class LetsMemorySignupPage extends StatelessWidget {
  static final _smallTextStyle = TextStyle(color: Colors.white);
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
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => LetsMemoryLoginPage()),
                  );
                }
              ),
            ],
          ),
        )
      ],
    ); 
  }
}