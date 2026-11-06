import 'package:flutter/widgets.dart';

import 'en_collections.dart';
import 'en_game.dart';
import 'en_home.dart';

const supportedAppLocales = [Locale('en'), Locale('it')];

Locale resolveAppLocale(Locale? locale) =>
    locale?.languageCode == 'it' ? const Locale('it') : const Locale('en');

/// Uses the device language when the saved preference is `auto`.
Locale? appLocaleForPreference(String preference) => switch (preference) {
  'it' => const Locale('it'),
  'en' => const Locale('en'),
  _ => null,
};

class AppLanguageScope extends InheritedWidget {
  const AppLanguageScope({
    super.key,
    required this.preference,
    required this.onChanged,
    required super.child,
  });

  final String preference;
  final ValueChanged<String> onChanged;

  static AppLanguageScope? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<AppLanguageScope>();

  @override
  bool updateShouldNotify(AppLanguageScope oldWidget) =>
      oldWidget.preference != preference;
}

/// Unmapped strings retain their Italian source until a translation is supplied.
/// Dynamic values stay outside the dictionary, for example `{count}` or `{name}`.
String tr(
  BuildContext context,
  String source, [
  Map<String, Object> args = const {},
]) => translateForLocale(Localizations.localeOf(context), source, args);

String translateForLocale(
  Locale locale,
  String source, [
  Map<String, Object> args = const {},
]) {
  var text = source;
  if (locale.languageCode == 'en') {
    final exact = _englishStrings[source];
    if (exact != null) {
      text = exact;
    } else {
      final rendered = _translateRenderedTemplate(source);
      if (rendered != null) return rendered;
    }
  }
  return text.replaceAllMapped(
    _placeholder,
    (placeholder) =>
        args[placeholder.group(1)]?.toString() ?? placeholder.group(0)!,
  );
}

final _englishStrings = <String, String>{
  ...enCollectionsStrings,
  ...enGameStrings,
  ...enHomeStrings,
};

final _placeholder = RegExp(r'\{([a-zA-Z][a-zA-Z0-9_]*)\}');
final _templates =
    _englishStrings.entries
        .where((entry) => _placeholder.hasMatch(entry.key))
        .map(_TemplateTranslation.new)
        .where((template) => template.literalLength >= 3)
        .toList()
      ..sort((a, b) => b.literalLength.compareTo(a.literalLength));

String? _translateRenderedTemplate(String source) {
  for (final template in _templates) {
    final translated = template.translate(source);
    if (translated != null) return translated;
  }
  return null;
}

class _TemplateTranslation {
  _TemplateTranslation(MapEntry<String, String> entry) : target = entry.value {
    final pattern = StringBuffer('^');
    var end = 0;
    for (final match in _placeholder.allMatches(entry.key)) {
      final literal = entry.key.substring(end, match.start);
      literalLength += literal.length;
      pattern.write(RegExp.escape(literal));
      pattern.write('(.*?)');
      names.add(match.group(1)!);
      end = match.end;
    }
    final tail = entry.key.substring(end);
    literalLength += tail.length;
    pattern.write('${RegExp.escape(tail)}\$');
    expression = RegExp(pattern.toString(), dotAll: true);
  }

  final String target;
  final names = <String>[];
  int literalLength = 0;
  late final RegExp expression;

  String? translate(String source) {
    final match = expression.firstMatch(source);
    if (match == null) return null;
    final values = <String, String>{};
    for (var index = 0; index < names.length; index++) {
      final value = match.group(index + 1)!;
      final previous = values[names[index]];
      if (previous != null && previous != value) return null;
      values[names[index]] = value;
    }
    return target.replaceAllMapped(
      _placeholder,
      (placeholder) => values[placeholder.group(1)!] ?? placeholder.group(0)!,
    );
  }
}
