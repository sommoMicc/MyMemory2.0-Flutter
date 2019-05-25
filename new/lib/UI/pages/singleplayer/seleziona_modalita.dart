import'package:flutter/material.dart';
import 'package:lets_memory/UI/styles/palette.dart';
import 'package:lets_memory/UI/view/layout/responsive_layout.dart';
import 'package:flutter_swiper/flutter_swiper.dart';

import 'package:lets_memory/UI/styles/style.dart';
import 'package:lets_memory/UI/view/main_button.dart';
import 'package:lets_memory/UI/view/pager_element.dart';
import 'package:lets_memory/model/pojo/arena.dart';

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
                    DropDownArena(style: cs),
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
          itemCount: 2,
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

  final _Style style;

  DropDownArena({@required this.style});

  final List<Arena> arenas = <Arena> [
    Arena(id: 1, name: "Alfabeto"),
    Arena(id: 1, name: "Arena del matematico")
  ];

  @override
  State<StatefulWidget> createState() => _DropDownArenaState();

}

class _DropDownArenaState extends State<DropDownArena> {
  Arena currentArena;
  List<DropdownMenuItem<Arena>> dropdownArenas = [];

  @override
  void initState() {
    widget.arenas.forEach((arena) => dropdownArenas.add(
        DropdownMenuItem(
            value: arena,
            child: Container(
              decoration: BoxDecoration(
                color: Palette.colors["orange"].primary,
                border: Border.all(
                  color: Palette.colors["orange"].dark,
                  width: widget.style.dropdownBorder,
                ),
                borderRadius: BorderRadius.circular(widget.style.radius)
              ),
              alignment: Alignment.center,
              child: Row(
                mainAxisSize: MainAxisSize.max,
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Text(arena.name, style: TextStyle(
                    color: Colors.black,
                    fontWeight: FontWeight.normal
                  ), textAlign: TextAlign.center),
                ]
              ),
            )
        )
    ));

    currentArena = widget.arenas[0];

    super.initState();
  }

  @override
  Widget build(BuildContext context) {

    return Container(
      child: DropdownButton(
        isExpanded: true,
        iconSize: 0,
        value: currentArena,
        items: dropdownArenas,
        onChanged: changeDropdownItem,
        underline: Container(),
      ),
    );
  }

  void changeDropdownItem(Arena selected) => setState(() {
    currentArena = selected;
  });
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

  double get dropdownBorder => size.scale(10,size.minSide);
  double get radius => size.radius;
}