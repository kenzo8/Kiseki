import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Service for managing system UI overlay styles (status bar, navigation bar)
class SystemUIService {
  /// Sets the status bar style based on background color brightness
  /// 
  /// [backgroundColor] - The background color to determine status bar style
  /// [isDark] - Optional parameter to explicitly set dark/light mode
  static void setStatusBarStyle({
    required Color backgroundColor,
    bool? isDark,
  }) {
    // Calculate brightness from background color if not explicitly provided
    final brightness = isDark ?? 
        (ThemeData.estimateBrightnessForColor(backgroundColor) == Brightness.dark);
    
    SystemChrome.setSystemUIOverlayStyle(
      SystemUiOverlayStyle(
        // Status bar color - transparent for immersive effect
        statusBarColor: Colors.transparent,
        // Status bar icon brightness (light icons on dark background, dark icons on light background)
        statusBarIconBrightness: brightness ? Brightness.light : Brightness.dark,
        // Status bar brightness (for iOS)
        statusBarBrightness: brightness ? Brightness.dark : Brightness.light,
        // System navigation bar color
        systemNavigationBarColor: backgroundColor,
        // System navigation bar icon brightness
        systemNavigationBarIconBrightness: brightness ? Brightness.light : Brightness.dark,
        // System navigation bar divider color (Android 11+)
        systemNavigationBarDividerColor: Colors.transparent,
      ),
    );
  }

  /// Sets immersive status bar with automatic color detection
  /// 
  /// [context] - BuildContext to get theme
  /// [backgroundColor] - Optional background color, defaults to scaffold background
  static void setImmersiveStatusBar(
    BuildContext context, {
    Color? backgroundColor,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final bgColor = backgroundColor ?? 
        (isDark ? const Color(0xFF02081A) : const Color(0xFFF5F5F5));
    
    setStatusBarStyle(
      backgroundColor: bgColor,
      isDark: isDark,
    );
  }

  /// Sets status bar for light backgrounds (dark icons)
  static void setLightStatusBar() {
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light,
        systemNavigationBarColor: Colors.white,
        systemNavigationBarIconBrightness: Brightness.dark,
        systemNavigationBarDividerColor: Colors.transparent,
      ),
    );
  }

  /// Sets status bar for dark backgrounds (light icons)
  static void setDarkStatusBar() {
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
        systemNavigationBarColor: Color(0xFF02081A),
        systemNavigationBarIconBrightness: Brightness.light,
        systemNavigationBarDividerColor: Colors.transparent,
      ),
    );
  }
}
