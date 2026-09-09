import 'package:flutter/foundation.dart';

/// Supported UI language codes for the patient app (v1).
enum AppLang { english, assamese }

extension AppLangExt on AppLang {
  String get code => this == AppLang.assamese ? 'as' : 'en';
  String get label => this == AppLang.assamese ? 'অ' : 'EN';
  String get fullLabel => this == AppLang.assamese ? 'অসমীয়া' : 'English';
}

/// Lightweight ChangeNotifier that owns the current UI language.
/// Injected at the root via MultiProvider — read anywhere with context.watch<LocaleService>().
class LocaleService extends ChangeNotifier {
  static final LocaleService instance = LocaleService._internal();
  LocaleService._internal();
  factory LocaleService() => instance;

  AppLang _lang = AppLang.english;

  AppLang get lang => _lang;
  String get code => _lang.code;

  void setLang(AppLang lang) {
    if (_lang == lang) return;
    _lang = lang;
    notifyListeners();
  }

  void toggle() {
    setLang(_lang == AppLang.english ? AppLang.assamese : AppLang.english);
  }
}
