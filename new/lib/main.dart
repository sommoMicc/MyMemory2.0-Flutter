import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'UI/app_frame.dart';
import 'model/state/app_state.dart';
void main() => runApp(LoginSignupApp());

class LoginSignupApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: "Login Signup test",
      theme: ThemeData(
        primarySwatch: Colors.blueGrey,
      ),
      home: ChangeNotifierProvider<AppState>(
        builder: (_) => AppState(),
        child: AppFrame()
      )
    );
  }
}
