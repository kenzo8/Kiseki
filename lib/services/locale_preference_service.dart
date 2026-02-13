import 'package:shared_preferences/shared_preferences.dart';

class LocalePreferenceService {
  static const String _localeKey = 'selected_locale';
  
  /// Supported locale codes
  static const String localeEnglish = 'en';
  static const String localeChinese = 'zh';
  static const String localeJapanese = 'ja';
  
  /// Save the selected locale preference
  /// Pass empty string or null to clear preference and use system default
  static Future<void> saveLocalePreference(String? localeCode) async {
    final prefs = await SharedPreferences.getInstance();
    if (localeCode == null || localeCode.isEmpty) {
      // Remove the preference to use system default
      await prefs.remove(_localeKey);
    } else {
      await prefs.setString(_localeKey, localeCode);
    }
  }
  
  /// Load the saved locale preference
  /// Returns the saved locale code, or null if not set (will use system default)
  static Future<String?> loadLocalePreference() async {
    final prefs = await SharedPreferences.getInstance();
    final locale = prefs.getString(_localeKey);
    // Return null if empty string (shouldn't happen, but handle it)
    return locale != null && locale.isNotEmpty ? locale : null;
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
