import 'package:flutter/material.dart';

import './pages/home_page.dart';
import './UI/theme.dart';

void main() => runApp(MaterialApp(
  title: "Let's Memory!",
  color: LetsMemoryColors.primary,
  home: LetsMemoryHomePage()
));
