import 'package:flutter/material.dart';
import 'package:lets_memory/UI/pages/home.dart';

class AppFrame extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Navigator(
        initialRoute: '/',
        onGenerateRoute: (RouteSettings settings) {
          WidgetBuilder builder;
          switch (settings.name) {
            case '/':
            default:
              builder = (_) => HomePage();
          }
          return MaterialPageRoute(builder: builder, settings: settings);
        }
      )
    );
  }
}
