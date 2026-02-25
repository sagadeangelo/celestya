import 'dart:ui';
import 'package:shared_preferences/shared_preferences.dart';

class LanguageService {
  static const String _languageKey = 'app_language';
  final SharedPreferences _prefs;

  LanguageService(this._prefs);

  String? getSavedLanguage() {
    return _prefs.getString(_languageKey);
  }

  Future<void> saveLanguage(String languageCode) async {
    await _prefs.setString(_languageKey, languageCode);
  }
}
