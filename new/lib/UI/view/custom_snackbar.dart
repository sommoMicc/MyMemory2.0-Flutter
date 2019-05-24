import 'package:flutter/material.dart';

class CustomSnackBarBuilder {
  static SnackBar buildSnackbar(Widget content) {
    return SnackBar(
      content: content,
      backgroundColor: Colors.black,
      duration: Duration(seconds: 3),
    );
  }
}