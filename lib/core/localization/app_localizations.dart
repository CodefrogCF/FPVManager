import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import 'app_messages.dart';

enum AppLanguage {
  german('de', 'Deutsch'),
  english('en', 'English');

  const AppLanguage(this.code, this.nameInLanguage);

  final String code;
  final String nameInLanguage;

  Locale get locale => Locale(code);

  static AppLanguage fromCode(String? code) =>
      code == english.code ? english : german;
}

class AppLocalizations {
  const AppLocalizations(this.language);

  final AppLanguage language;

  static const delegate = _AppLocalizationsDelegate();
  static const supportedLocales = [Locale('de'), Locale('en')];

  static AppLocalizations? maybeOf(BuildContext context) =>
      Localizations.of<AppLocalizations>(context, AppLocalizations);

  static final _placeholder = RegExp(r'\{(\d+)\}');

  static String message(
    AppLanguage? language,
    String source,
    List<Object?> arguments,
  ) {
    final template = switch (language) {
      AppLanguage.german => germanMessages[source] ?? source,
      AppLanguage.english => englishMessages[source] ?? source,
      null => source,
    };
    if (arguments.isEmpty) return template;
    return template.replaceAllMapped(_placeholder, (match) {
      final index = int.parse(match[1]!);
      return index < arguments.length ? '${arguments[index]}' : match[0]!;
    });
  }
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) => AppLocalizations.supportedLocales.any(
    (supported) => supported.languageCode == locale.languageCode,
  );

  @override
  Future<AppLocalizations> load(Locale locale) => SynchronousFuture(
    AppLocalizations(AppLanguage.fromCode(locale.languageCode)),
  );

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

extension AppLocalizedContext on BuildContext {
  String translate(String source, [List<Object?> arguments = const []]) =>
      AppLocalizations.message(
        AppLocalizations.maybeOf(this)?.language,
        source,
        arguments,
      );
}
