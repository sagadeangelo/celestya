import 'package:shared_preferences/shared_preferences.dart';

class SettingsService {
  static const _kWelcomeSoundEnabled = 'welcome_sound_enabled';

  Future<bool> getWelcomeSoundEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_kWelcomeSoundEnabled) ?? true; // default ON
  }

  Future<void> setWelcomeSoundEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kWelcomeSoundEnabled, enabled);
  }
}
