import 'package:shared_preferences/shared_preferences.dart';

class SettingsPreferenceService {
  static const String _proModeKey = 'settings_pro_mode';

  Future<bool> isProMode() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_proModeKey) ?? false;
  }

  Future<void> setProMode(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_proModeKey, value);
  }
}
