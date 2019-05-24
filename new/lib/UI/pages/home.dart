import'package:flutter/material.dart';
import 'package:lets_memory/UI/pages/singleplayer/seleziona_modalita.dart';
import 'package:lets_memory/UI/styles/palette.dart';
import 'package:lets_memory/UI/view/layout/responsive_layout.dart';
import 'package:lets_memory/UI/view/logo.dart';
import 'package:lets_memory/UI/view/main_button.dart';


import 'package:lets_memory/UI/styles/style.dart';

class HomePage extends StatelessWidget {
  _Style cs;
  @override
  Widget build(BuildContext context) {
    //final appState = Provider.of<AppState>(context);
    cs = _Style(AppDimensions(context));
    return ResponsiveLayout(
      titleArea: AppLogo(),
      contentArea: Padding(
        padding: EdgeInsets.only(
            left: cs.horizontalMargin,
            right: cs.horizontalMargin
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            MainButton(
              text: "Singleplayer",
              palette: Palette.colors["green"],
              callback: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_)=>SelezionaModalita()
                )
              ),
            ),
            SizedBox(
              height: cs.size.mainButtonFontSize,
            ),
            MainButton(
              text: "Multiplayer",
              palette: Palette.colors["blue"],
            ),
            SizedBox(
              height: cs.size.mainButtonFontSize,
            ),
            MainButton(
              text: "Impostazioni",
              palette: Palette.colors["deepOrange"],
            ),
          ],
        ),
      ),
    );
  }
}

class _Style {
  final AppDimensions size;
  _Style(this.size);

  double get inputSpace => size.scale(15,Measure.height);

  double get logoTopPadding => size.scale(50,Measure.height);
  double get logoBottomPadding => size.scale(100,Measure.height);

  double get horizontalMargin => size.scale(70,Measure.width);
}