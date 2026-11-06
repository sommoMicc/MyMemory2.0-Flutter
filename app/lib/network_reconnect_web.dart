import 'dart:async';
import 'dart:js_interop';

import 'package:web/web.dart' as web;

Stream<void> networkReconnects() {
  late final StreamController<void> controller;
  final listener = ((web.Event _) => controller.add(null)).toJS;
  controller = StreamController<void>(
    onListen: () => web.window.addEventListener('online', listener),
    onCancel: () => web.window.removeEventListener('online', listener),
  );
  return controller.stream;
}
