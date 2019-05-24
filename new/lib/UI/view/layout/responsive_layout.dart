import 'package:flutter/material.dart';
import 'package:lets_memory/UI/view/app_background.dart';

class ResponsiveLayout extends StatelessWidget {
  final Widget titleArea, contentArea;

  const ResponsiveLayout({this.titleArea, this.contentArea});

  @override
  Widget build(BuildContext context) {
    return AppBackground(
        children: <Widget> [
          OrientationBuilder(
            builder: (_, Orientation o) {
              if(o == Orientation.portrait)
                return Column(
                  children: <Widget>[
                    Expanded(
                      flex: 1,
                      child: titleArea,
                    ),
                    Expanded(
                      flex: 2,
                      child: contentArea,
                    ),
                  ],
                );
              else
                return Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: <Widget>[
                    Expanded(
                      flex: 1,
                      child: titleArea,
                    ),
                    Expanded(
                      flex: 1,
                      child: contentArea,
                    ),
                  ],
                );
            },
          )
        ]
    );
  }
}