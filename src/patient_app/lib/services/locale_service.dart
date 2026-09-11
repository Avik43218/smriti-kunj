import 'package:flutter/foundation.dart';

/// Supported UI language codes for the patient app.
enum AppLang { english, assamese, bengali, bodo }

extension AppLangExt on AppLang {
  String get code {
    switch (this) {
      case AppLang.assamese:
        return 'as';
      case AppLang.bengali:
        return 'bn';
      case AppLang.bodo:
        return 'brx';
      case AppLang.english:
        return 'en';
    }
  }

  String get label {
    switch (this) {
      case AppLang.assamese:
        return 'অ';
      case AppLang.bengali:
        return 'বাং';
      case AppLang.bodo:
        return 'ब';
      case AppLang.english:
        return 'EN';
    }
  }

  static AppLang fromCode(String? code) {
    switch (code) {
      case 'as':
      case 'assamese':
        return AppLang.assamese;
      case 'bn':
      case 'bengali':
        return AppLang.bengali;
      case 'brx':
      case 'bodo':
        return AppLang.bodo;
      default:
        return AppLang.english;
    }
  }

  String get fullLabel {
    switch (this) {
      case AppLang.assamese:
        return 'অসমীয়া';
      case AppLang.bengali:
        return 'বাংলা';
      case AppLang.bodo:
        return 'बड़ो';
      case AppLang.english:
        return 'English';
    }
  }
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
