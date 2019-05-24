import 'package:flutter/cupertino.dart';

enum Measure {
  height,
  width
}

class AppDimensions {
  static final double referenceHeight = 683;
  static final double referenceWidth = 411;

  Orientation orientation;
  List<double> sizes;

  BuildContext context;

  AppDimensions(this.context) {
    MediaQueryData mediaQueryData = MediaQuery.of(context);
    orientation = mediaQueryData.orientation;
    sizes = [mediaQueryData.size.height,mediaQueryData.size.width];
  }

  Measure get minSide {
    return orientation == Orientation.portrait ?
    Measure.width : Measure.height;
  }

  Measure get maxSide {
    return orientation == Orientation.portrait ?
    Measure.height : Measure.width;
  }

  double get radius => scale(12,Measure.width);
  double get hPadding => orientation == Orientation.portrait ?
    scale(15,Measure.height) : scale(40,Measure.width);

  double get cardSide => percentage(21,minSide);
  double get cardFont => cardSide - scale(10,minSide);

  double get logoCardSide => percentage(
      100 /
      (7 * (1 + ((Orientation.landscape == orientation) ? 1 : 0))),
      Measure.width
  );
  double get logoFontSize => logoCardSide / 1.7;
  double get mainButtonFontSize => logoCardSide / 2;

  double get defaultPageHorizontalMargin => scale(40,Measure.width);

  double scale(double n, Measure m) {
    if(sizes == null)
      return n;

    double availableHeight = sizes[0];
    double availableWidth = sizes[1];

    if(orientation == Orientation.portrait) {
      return (m == Measure.height) ?
        n * availableHeight / referenceHeight :
        n * availableWidth / referenceWidth;
    }
    return (m == Measure.height) ?
      n * availableWidth / referenceWidth:
      n * availableHeight / referenceHeight;
  }

  double percentage(double x, Measure m) {
    if(sizes == null)
      return x;

    return x * sizes[m.index] / 100.0;
  }
}
