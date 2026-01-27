import 'package:shared_preferences/shared_preferences.dart';

class ThemePreferenceService {
  static const String _themeKey = 'isDarkMode';

  /// Save the theme preference (true for dark mode, false for light mode)
  static Future<void> saveThemePreference(bool isDarkMode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_themeKey, isDarkMode);
  }

  /// Load the saved theme preference
  /// Returns true for dark mode, false for light mode
  /// Defaults to false (light mode) if no preference is saved
  static Future<bool> loadThemePreference() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_themeKey) ?? false; // Default to light mode
  }
}
