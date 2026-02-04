import 'package:flutter/material.dart';

/// Device category for UI (icon, label, deviceType).
class DeviceCategory {
  final IconData icon;
  final String label;
  final String deviceType;

  const DeviceCategory({
    required this.icon,
    required this.label,
    required this.deviceType,
  });
}

/// Full definition for one device type. Add new types here only.
/// Order in [deviceCategoryDefinitions] defines suggestion priority (first keyword match wins).
class DeviceCategoryDefinition {
  final IconData icon;
  final String label;
  final String deviceType;
  final Color color;
  final String hintExample;
  final List<String> nameKeywords;

  const DeviceCategoryDefinition({
    required this.icon,
    required this.label,
    required this.deviceType,
    required this.color,
    required this.hintExample,
    required this.nameKeywords,
  });

  DeviceCategory toCategory() => DeviceCategory(
        icon: icon,
        label: label,
        deviceType: deviceType,
      );
}

/// Single source of truth for device types. To add a type: add one entry here.
const List<DeviceCategoryDefinition> deviceCategoryDefinitions = [
  DeviceCategoryDefinition(
    icon: Icons.smartphone,
    label: 'Mobile',
    deviceType: 'Mobile',
    color: Colors.blue,
    hintExample: 'e.g., iPhone 15 Pro',
    nameKeywords: ['iphone', 'pixel', 'galaxy', 'phone', 'android'],
  ),
  DeviceCategoryDefinition(
    icon: Icons.tablet_mac,
    label: 'Tablet',
    deviceType: 'Tablet',
    color: Colors.green,
    hintExample: 'e.g., iPad Pro 12.9"',
    nameKeywords: ['ipad', 'tab', 'surface pro', 'tablet'],
  ),
  DeviceCategoryDefinition(
    icon: Icons.laptop,
    label: 'Laptop',
    deviceType: 'Laptop',
    color: Colors.purple,
    hintExample: 'e.g., MacBook Pro M1',
    nameKeywords: ['macbook', 'laptop', 'thinkpad', 'xps', 'zenbook'],
  ),
  DeviceCategoryDefinition(
    icon: Icons.desktop_windows,
    label: 'Desktop',
    deviceType: 'Desktop',
    color: Colors.purple,
    hintExample: 'e.g., iMac 24"',
    nameKeywords: ['imac', 'studio', 'desktop', 'pc', 'mac pro', 'mac mini'],
  ),
  DeviceCategoryDefinition(
    icon: Icons.watch,
    label: 'Watch',
    deviceType: 'Watch',
    color: Colors.orange,
    hintExample: 'e.g., Apple Watch Series 9',
    nameKeywords: ['watch', 'garmin', 'fitbit'],
  ),
  DeviceCategoryDefinition(
    icon: Icons.hearing,
    label: 'Earbuds',
    deviceType: 'Earbuds',
    color: Colors.cyan,
    hintExample: 'e.g., AirPods Pro 2',
    nameKeywords: ['airpods', 'buds', 'ear ', 'earbud'],
  ),
  DeviceCategoryDefinition(
    icon: Icons.headphones,
    label: 'Headphones',
    deviceType: 'Headphones',
    color: Colors.cyan,
    hintExample: 'e.g., Sony WH-1000XM5',
    nameKeywords: ['headphone', 'wh-1000', 'sony', 'bose', 'over-ear'],
  ),
  DeviceCategoryDefinition(
    icon: Icons.photo_camera,
    label: 'Camera',
    deviceType: 'Camera',
    color: Colors.amber,
    hintExample: 'e.g., Canon EOS R5',
    nameKeywords: ['camera', 'eos', 'canon', 'nikon', 'sony a7', 'mirrorless', 'dslr'],
  ),
  DeviceCategoryDefinition(
    icon: Icons.home,
    label: 'SmartHome',
    deviceType: 'SmartHome',
    color: Colors.brown,
    hintExample: 'e.g., HomePod mini',
    nameKeywords: [
      'nest', 'echo', 'alexa', 'homepod', 'smart home', 'smarthome',
      'hub', 'thermostat', 'ring ', 'philips hue',
    ],
  ),
  DeviceCategoryDefinition(
    icon: Icons.view_in_ar,
    label: 'VR/AR',
    deviceType: 'VR/AR',
    color: Colors.indigo,
    hintExample: 'e.g., Apple Vision Pro',
    nameKeywords: [
      'quest', 'vision pro', 'vr ', ' vr', 'metaverse', 'pico',
      'valve index', 'hololens',
    ],
  ),
  DeviceCategoryDefinition(
    icon: Icons.mouse,
    label: 'Mouse',
    deviceType: 'Mouse',
    color: Colors.pink,
    hintExample: 'e.g., Logitech MX Master 3',
    nameKeywords: [
      'mouse', 'keyboard', 'hhkb', 'mechanical', 'gaming mouse',
      'gaming keyboard', 'mx master', 'magic keyboard',
    ],
  ),
  DeviceCategoryDefinition(
    icon: Icons.videogame_asset,
    label: 'Gaming',
    deviceType: 'Gaming',
    color: Colors.red,
    hintExample: 'e.g., PlayStation 5',
    nameKeywords: ['playstation', 'xbox', 'nintendo', 'switch', 'steam deck', 'gaming console', 'ps5'],
  ),
  DeviceCategoryDefinition(
    icon: Icons.flight,
    label: 'Drone',
    deviceType: 'Drone',
    color: Colors.teal,
    hintExample: 'e.g., DJI Mavic 3',
    nameKeywords: ['drone', 'dji', 'mavic', 'phantom', 'mini 2', 'mini 3'],
  ),
  DeviceCategoryDefinition(
    icon: Icons.menu_book,
    label: 'e-Reader',
    deviceType: 'e-Reader',
    color: Colors.deepOrange,
    hintExample: 'e.g., Kindle Paperwhite',
    nameKeywords: ['kindle', 'kobo', 'ereader', 'e-reader', 'nook', 'remarkable', 'boox'],
  ),
  DeviceCategoryDefinition(
    icon: Icons.storage,
    label: 'NAS',
    deviceType: 'NAS',
    color: Colors.blueGrey,
    hintExample: 'e.g., Synology DS920+',
    nameKeywords: ['nas', 'synology', 'qnap', 'storage', 'server'],
  ),
  DeviceCategoryDefinition(
    icon: Icons.monitor,
    label: 'Monitor',
    deviceType: 'Monitor',
    color: Colors.deepPurple,
    hintExample: 'e.g., LG UltraWide 34"',
    nameKeywords: ['monitor', 'display', 'screen', 'lg ', 'dell ', 'benq', 'ultrawide'],
  ),
  DeviceCategoryDefinition(
    icon: Icons.battery_charging_full,
    label: 'Powerbank',
    deviceType: 'Powerbank',
    color: Colors.lime,
    hintExample: 'e.g., Anker PowerCore 20000',
    nameKeywords: [
      'powerbank', 'power bank', 'power pack', 'battery pack',
      'portable charger', 'anker', 'magsafe battery',
    ],
  ),
  DeviceCategoryDefinition(
    icon: Icons.keyboard,
    label: 'Keyboard',
    deviceType: 'Keyboard',
    color: Colors.grey,
    hintExample: 'e.g., Magic Keyboard',
    nameKeywords: ['vintage', 'old', 'retro'],
  ),
];

/// Legacy deviceType → icon for old Firestore data (snake_case or old labels).
const Map<String, IconData> _legacyDeviceTypeIcons = {
  'Mac': Icons.laptop_mac,
  'iPhone': Icons.smartphone,
  'iPad': Icons.smartphone,
  'iPod': Icons.smartphone,
  'Apple Watch': Icons.watch,
  'Vintage': Icons.devices_other,
  'smart_home': Icons.home,
  'vr': Icons.view_in_ar,
  'gaming_peripheral': Icons.mouse,
  'drone': Icons.flight,
  'ereader': Icons.menu_book,
  'nas': Icons.storage,
  'monitor': Icons.monitor,
  'powerbank': Icons.battery_charging_full,
};

/// Keyword fallback when deviceType string contains these (e.g. from old data).
bool _keywordMatch(String lowerType, List<String> keywords) {
  for (final k in keywords) {
    if (lowerType.contains(k)) return true;
  }
  return false;
}

final List<DeviceCategory> _deviceCategories = deviceCategoryDefinitions
    .map((d) => d.toCategory())
    .toList();

final Map<String, DeviceCategoryDefinition> _definitionsByType = {
  for (final d in deviceCategoryDefinitions) d.deviceType: d,
  for (final d in deviceCategoryDefinitions) d.deviceType.toLowerCase(): d,
};

/// All categories for UI. [deviceType] equals [label] and is saved to Firestore.
List<DeviceCategory> get deviceCategories => _deviceCategories;

/// Color for a device type. Unknown types return grey.
Color getCategoryColor(String deviceType) {
  final def = _definitionsByType[deviceType];
  return def?.color ?? Colors.grey;
}

/// Hint text for the device name field (e.g. "e.g., MacBook Pro M1").
String getHintForDeviceType(String deviceType) {
  final def = _definitionsByType[deviceType];
  return def?.hintExample ?? 'e.g., MacBook Pro M1';
}

/// Icon for a device type. Supports legacy types and keyword fallback for old data.
IconData deviceTypeToIcon(String deviceType) {
  final def = _definitionsByType[deviceType];
  if (def != null) return def.icon;

  final legacy = _legacyDeviceTypeIcons[deviceType];
  if (legacy != null) return legacy;

  final lowerType = deviceType.toLowerCase();
  if (_legacyDeviceTypeIcons.containsKey(lowerType)) {
    return _legacyDeviceTypeIcons[lowerType]!;
  }

  // Keyword fallback for unknown deviceType strings (e.g. from Firestore)
  if (_keywordMatch(lowerType, ['peripheral', 'mouse', 'keyboard']) ||
      (lowerType.contains('gaming') && (lowerType.contains('mouse') || lowerType.contains('keyboard')))) {
    return Icons.mouse;
  }
  if (_keywordMatch(lowerType, ['headphone', 'audio'])) return Icons.headphones;
  if (lowerType.contains('earbud')) return Icons.hearing;
  if (_keywordMatch(lowerType, ['smartwatch', 'watch'])) return Icons.watch;
  if (lowerType.contains('tablet')) return Icons.tablet_mac;
  if (_keywordMatch(lowerType, ['gaming', 'console', 'game'])) return Icons.videogame_asset;
  if (_keywordMatch(lowerType, ['camera', 'photo'])) return Icons.photo_camera;
  if (lowerType.contains('smart') && lowerType.contains('home')) return Icons.home;
  if (_keywordMatch(lowerType, ['vr', 'ar'])) return Icons.view_in_ar;
  if (lowerType.contains('drone')) return Icons.flight;
  if (_keywordMatch(lowerType, ['ereader', 'e-reader'])) return Icons.menu_book;
  if (lowerType.contains('nas') || lowerType.contains('storage')) return Icons.storage;
  if (_keywordMatch(lowerType, ['monitor', 'display'])) return Icons.monitor;
  if (_keywordMatch(lowerType, ['powerbank', 'power bank', 'battery pack'])) return Icons.battery_charging_full;

  return Icons.devices;
}

/// Suggests device type from device name. Order of [deviceCategoryDefinitions] = priority.
String suggestDeviceTypeFromName(String deviceName) {
  final lowerName = deviceName.toLowerCase();
  for (final def in deviceCategoryDefinitions) {
    for (final keyword in def.nameKeywords) {
      if (lowerName.contains(keyword)) return def.deviceType;
    }
  }
  return 'Laptop';
}
