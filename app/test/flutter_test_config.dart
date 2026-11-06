import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  // Existing interface tests use Italian labels as their deterministic baseline.
  // Locale tests override this simulated device locale in their own test body;
  // production still resolves the real device language with no test override.
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() {
    TestWidgetsFlutterBinding.instance.platformDispatcher.localeTestValue =
        const Locale('it', 'IT');
    TestWidgetsFlutterBinding.instance.platformDispatcher.localesTestValue =
        const [Locale('it', 'IT')];
  });
  tearDown(() {
    TestWidgetsFlutterBinding.instance.platformDispatcher
        .clearLocaleTestValue();
    TestWidgetsFlutterBinding.instance.platformDispatcher
        .clearLocalesTestValue();
  });
  await testMain();
}
