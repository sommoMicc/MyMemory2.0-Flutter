import 'dart:ui';

class Palette {
  static final Map<String,ColorPalette>_darkPalette = {
    "red": TextColorPalette(primary: "d32f2f",dark: "9a0007"),
    "pink": TextColorPalette(primary: "c2185b",dark: "8c0032"),
    "purple": TextColorPalette(primary: "7b1fa2",dark: "4a0072"),
    "deepPurple": TextColorPalette(primary: "512da8",dark: "140078"),
    "indigo": TextColorPalette(primary: "303f9f",dark: "001970"),
    "blue": TextColorPalette(primary: "1976d2",dark: "004ba0"),
    "lightBlue": TextColorPalette(primary: "0277bd",dark: "004c8c"),
    "cyan": TextColorPalette(primary: "00838f",dark: "005662"),
    "teal": TextColorPalette(primary: "00796b",dark: "004c40"),
    "green": TextColorPalette(primary: "2e7d32",dark: "005005"),
    "lightGreen": TextColorPalette(primary: "689f38",dark: "387002",text: "000000"),
    "lime": TextColorPalette(primary: "afb42b",dark: "7c8500",text: "000000"),
    "yellow": TextColorPalette(primary: "fbc02d",dark: "c49000",text: "000000"),
    "amber": TextColorPalette(primary: "ffa000",dark: "c67100",text: "000000"),
    "orange": TextColorPalette(primary: "f57c00",dark: "bb4d00",text: "000000"),
    "deepOrange": TextColorPalette(primary: "e64a19",dark: "ac0800"),
    "brown": TextColorPalette(primary: "795548",dark: "4b2c20"),
    "grey": TextColorPalette(primary: "757575",dark: "494949"),
    "blueGrey": TextColorPalette(primary: "546e7a",dark: "29434e"),
  };

  static final List<Color> _backgroundGradient = <Color> [
    const Color(0xff8e24aa),
    const Color(0xff38006b),
  ];

  static final Color _text = const Color(0xffffffff);
  static final Color _textSecondary = const Color(0xffababab);

  static Map<String,ColorPalette> get colors => Palette._darkPalette;
  static List<Color> get backgroundColors => _backgroundGradient;

  static Color get text => _text;
  static Color get textSecondary => _textSecondary;

  static final Color defaultShadowColor = Color(0x88000000);
}

class ColorPalette {
  final Color primary, dark, text;

  ColorPalette({this.primary, this.dark, this.text});
}

class TextColorPalette extends ColorPalette {
  TextColorPalette({String primary,String dark,String text = "ffffff"}) : super(
    primary: Color(int.parse("0xff"+primary)),
    dark: Color(int.parse("0xff"+dark)),
    text: Color(int.parse("0xff"+text)) //Bianco se non specificato
  );
}