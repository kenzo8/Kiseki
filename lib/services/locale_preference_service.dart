import 'package:shared_preferences/shared_preferences.dart';

class LocalePreferenceService {
  static const String _localeKey = 'selected_locale';
  
  /// Supported locale codes
  static const String localeEnglish = 'en';
  static const String localeChinese = 'zh';
  static const String localeJapanese = 'ja';
  
  /// Save the selected locale preference
  static Future<void> saveLocalePreference(String localeCode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_localeKey, localeCode);
  }
  
  /// Load the saved locale preference
  /// Returns the saved locale code, or null if not set (will use system default)
  static Future<String?> loadLocalePreference() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_localeKey);
  }
  
  /// Get locale display name
  static String getLocaleDisplayName(String localeCode) {
    switch (localeCode) {
      case localeEnglish:
        return 'English';
      case localeChinese:
        return '中文';
      case localeJapanese:
        return '日本語';
      default:
        return localeCode;
    }
  }
}
