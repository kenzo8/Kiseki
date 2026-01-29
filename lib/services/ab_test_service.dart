import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:flutter/foundation.dart';

/// Unified A/B test switch for import/export feature.
/// Uses Firebase Remote Config (and Firebase A/B Testing when configured in console).
/// Default: off (false).
///
/// Firebase Console setup:
/// 1. Enable Remote Config in your project.
/// 2. Create parameter `import_export_ab_enabled` (Boolean). Optional default: false.
/// 3. For A/B tests: Engage → A/B Testing → create experiment → choose Remote Config,
///    add parameter `import_export_ab_enabled` and set variant values (e.g. true for test group).
class AbTestService {
  static const _keyImportExportEnabled = 'import_export_ab_enabled';

  static FirebaseRemoteConfig? _remoteConfig;
  static bool _initialized = false;

  static FirebaseRemoteConfig get _rc {
    _remoteConfig ??= FirebaseRemoteConfig.instance;
    return _remoteConfig!;
  }

  /// Initialize Remote Config. Call once after Firebase.initializeApp (e.g. in main).
  static Future<void> init() async {
    if (_initialized) return;
    try {
      await _rc.setConfigSettings(RemoteConfigSettings(
        fetchTimeout: const Duration(minutes: 1),
        minimumFetchInterval: kDebugMode
            ? const Duration(minutes: 5)
            : const Duration(hours: 12),
      ));
      await _rc.setDefaults(const {
        _keyImportExportEnabled: false,
      });
      await _rc.fetchAndActivate();
      _initialized = true;
    } catch (e) {
      debugPrint('AbTestService init error: $e');
      _initialized = true; // prevent retry loop; use defaults
    }
  }

  /// Whether import/export feature is enabled by the A/B test switch.
  /// Default false. Ensure [init] has been called (e.g. from main).
  static bool isImportExportEnabled() {
    try {
      return _rc.getBool(_keyImportExportEnabled);
    } catch (e) {
      debugPrint('AbTestService isImportExportEnabled error: $e');
      return false;
    }
  }

  /// Async variant: ensures init + fetch, then returns the value.
  static Future<bool> isImportExportEnabledAsync() async {
    await init();
    return isImportExportEnabled();
  }
}
