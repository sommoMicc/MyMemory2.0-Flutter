import'package:flutter/material.dart';
import 'package:lets_memory/UI/styles/palette.dart';
import 'package:lets_memory/UI/view/layout/responsive_layout.dart';
import 'package:flutter_swiper/flutter_swiper.dart';

import 'package:lets_memory/UI/styles/style.dart';
import 'package:lets_memory/UI/view/main_button.dart';
import 'package:lets_memory/UI/view/pager_element.dart';

class SelezionaModalita extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    //final appState = Provider.of<AppState>(context);
    _Style cs = _Style(AppDimensions(context));

    return ResponsiveLayout(
      titleArea: Center(
        child: Text("Seleziona Modalità".toUpperCase(),
          style: cs.titleStyle,
          textAlign: TextAlign.center
        )
      ),
      contentArea: Padding(
        padding: EdgeInsets.only(
            left: cs.horizontalMargin,
            right: cs.horizontalMargin
        ),
        child: Swiper(
          itemBuilder: (BuildContext context, int index) {
            return PagerElement(
              palette: Palette.colors["blue"],
              child: SingleChildScrollView(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: <Widget>[
                    Text("ALLENAMENTO",
                      style: cs.titleStyle,
                      textAlign: TextAlign.center
                    ),
                    SizedBox(
                      height: cs.verticalSpace,
                    ),
                    Text("Arena: ",
                      style: cs.subtitleStyle,
                      textAlign: TextAlign.center
                    ),
                    SizedBox(
                      height: cs.verticalSpace,
                    ),
                    TextField(),
                    SizedBox(
                      height: cs.verticalSpace,
                    ),
                    Text("Dimensione",
                      style: cs.subtitleStyle,
                      textAlign: TextAlign.center
                    ),
                    SizedBox(
                      height: cs.verticalSpace,
                    ),
                    TextField(),
                    SizedBox(
                      height: cs.verticalSpace,
                    ),
                    MainButton(
                      text: "Gioca",
                      palette: Palette.colors["green"],
                    )
                  ],
                ),
              ),
            );
          },
          itemCount: 10,
          layout: SwiperLayout.TINDER,

          itemWidth: cs.itemPageWidth,
          itemHeight: cs.itemPageHeight,

          viewportFraction: 1
        )
      ),
    );
  }
}

class DropDownArena extends StatefulWidget {
  @override
  State<StatefulWidget> createState() => _DropDownArenaState();

}

class _DropDownArenaState extends State<DropDownArena> {
  @override
  Widget build(BuildContext context) {
    return Container(
      child: DropdownButton(
        items: null,
        onChanged: null
      ),
    );
  }

}

class _Style {
  final AppDimensions size;
  _Style(this.size);

  double get verticalSpace => size.scale(15,Measure.height);

  double get itemPageWidth {
    if(size.orientation == Orientation.portrait) {
      return size.sizes[1] - 2 * horizontalMargin;
    }
    return size.sizes[1] / 2 - 2 * horizontalMargin;
  }
  double get itemPageHeight {
    if(size.orientation == Orientation.portrait) {
      return size.sizes[0] * 2 / 3;
    }
    return size.sizes[0] - 2 * horizontalMargin;
  }

  double get horizontalMargin => size.defaultPageHorizontalMargin;

  TextStyle get titleStyle => TextStyle(
    color: Colors.white,
    fontSize: size.scale(30,Measure.width),
    fontWeight: FontWeight.w900,
  );

  TextStyle get subtitleStyle => TextStyle(
    color: Colors.white,
    fontSize: size.scale(25,Measure.width),
    fontWeight: FontWeight.w600,
  );
}