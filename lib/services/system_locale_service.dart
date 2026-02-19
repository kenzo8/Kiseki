import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class SystemLocaleService {
  SystemLocaleService._();

  /// Returns the system-wide preferred locale list (language order from system settings).
  /// Android API 24+: [Resources.getSystem().configuration.locales] (including 33+).
  /// Other platforms: null; caller falls back to [PlatformDispatcher.instance.locales].
  static Future<List<Locale>?> getSystemLocaleList() async {
    if (!Platform.isAndroid) return null;
    try {
      const channel = MethodChannel('com.kenzo.kien/system_locales');
      final List<dynamic>? tags = await channel.invokeMethod<List<dynamic>>('getSystemLocales');
      if (tags == null || tags.isEmpty) return null;
      return tags
          .map((e) => _parseLocale(e is String ? e : e.toString()))
          .whereType<Locale>()
          .toList();
    } on PlatformException catch (_) {
      return null;
    } on Exception catch (_) {
      return null;
    }
  }

  static Locale? _parseLocale(String tag) {
    if (tag.isEmpty) return null;
    final parts = tag.replaceAll('-', '_').split('_');
    if (parts.isEmpty) return null;
    final language = parts[0].toLowerCase();
    if (language.isEmpty) return null;
    final country = parts.length >= 2 && parts.last.length == 2
        ? parts.last.toUpperCase()
        : null;
    return country != null ? Locale(language, country) : Locale(language);
  }
}
