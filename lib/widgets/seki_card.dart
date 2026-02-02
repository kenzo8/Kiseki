import 'package:flutter/material.dart';

import '../models/seki_model.dart';
import 'device_icon_selector.dart';

/// Intelligent device icon matching based on device name keywords.
/// Analyzes the device name to determine the most appropriate icon.
IconData getIconByDeviceName(String deviceName) {
  final lowerName = deviceName.toLowerCase();
  
  // Mobile phones
  if (lowerName.contains('iphone') || 
      lowerName.contains('pixel') || 
      lowerName.contains('galaxy') || 
      lowerName.contains('phone') ||
      lowerName.contains('android')) {
    return Icons.smartphone;
  }
  
  // Tablets
  if (lowerName.contains('ipad') || 
      lowerName.contains('tab') || 
      lowerName.contains('surface pro') ||
      lowerName.contains('tablet')) {
    return Icons.tablet_mac;
  }
  
  // Laptops
  if (lowerName.contains('macbook') || 
      lowerName.contains('laptop') || 
      lowerName.contains('thinkpad') ||
      lowerName.contains('xps') ||
      lowerName.contains('zenbook')) {
    return Icons.laptop;
  }
  
  // Desktops
  if (lowerName.contains('imac') || 
      lowerName.contains('studio') || 
      lowerName.contains('desktop') || 
      lowerName.contains('pc') ||
      lowerName.contains('mac pro') ||
      lowerName.contains('mac mini')) {
    return Icons.desktop_windows;
  }
  
  // Watches
  if (lowerName.contains('watch') || 
      lowerName.contains('garmin') ||
      lowerName.contains('fitbit')) {
    return Icons.watch;
  }
  
  // Earbuds
  if (lowerName.contains('airpods') || 
      lowerName.contains('buds') || 
      lowerName.contains('ear') ||
      lowerName.contains('earbud')) {
    return Icons.hearing;
  }

  // VR/AR (before headphones so "vr headset" etc. match here)
  if (lowerName.contains('quest') ||
      lowerName.contains('vision pro') ||
      lowerName.contains(' vr') ||
      lowerName.contains('vr ') ||
      lowerName.contains('pico') ||
      lowerName.contains('valve index') ||
      lowerName.contains('hololens')) {
    return Icons.view_in_ar;
  }

  // Headphones
  if (lowerName.contains('sony xm') || 
      lowerName.contains('headphone') || 
      lowerName.contains('bose') ||
      lowerName.contains('audio') ||
      lowerName.contains('headset')) {
    return Icons.headphones;
  }

  // Gaming consoles
  if (lowerName.contains('switch') || 
      lowerName.contains('ps5') || 
      lowerName.contains('ps4') ||
      lowerName.contains('xbox') || 
      lowerName.contains('deck') ||
      lowerName.contains('steam deck') ||
      lowerName.contains('gaming') ||
      lowerName.contains('console')) {
    return Icons.videogame_asset;
  }
  
  // Cameras
  if (lowerName.contains('fuji') || 
      lowerName.contains('sony a') || 
      lowerName.contains('canon') ||
      lowerName.contains('camera') ||
      lowerName.contains('nikon') ||
      lowerName.contains('leica')) {
    return Icons.photo_camera;
  }

  // Smart home
  if (lowerName.contains('nest') ||
      lowerName.contains('echo') ||
      lowerName.contains('alexa') ||
      lowerName.contains('homepod') ||
      lowerName.contains('smart home') ||
      lowerName.contains('smarthome') ||
      lowerName.contains('thermostat') ||
      lowerName.contains('philips hue')) {
    return Icons.home;
  }

  // Drones
  if (lowerName.contains('drone') ||
      lowerName.contains('dji') ||
      lowerName.contains('mavic') ||
      lowerName.contains('phantom')) {
    return Icons.flight;
  }

  // e-Readers
  if (lowerName.contains('kindle') ||
      lowerName.contains('kobo') ||
      lowerName.contains('ereader') ||
      lowerName.contains('e-reader') ||
      lowerName.contains('nook') ||
      lowerName.contains('remarkable') ||
      lowerName.contains('boox')) {
    return Icons.menu_book;
  }

  // Accessories (keyboards, mice, etc.)
  if (lowerName.contains('keyboard') || 
      lowerName.contains('mouse') || 
      lowerName.contains('hhkb') ||
      lowerName.contains('trackpad')) {
    return Icons.keyboard;
  }

  // Fallback
  return Icons.devices;
}

/// Suggests a device type (label) based on device name keywords.
/// Returns one of the device category labels for the icon picker.
String suggestDeviceTypeFromName(String deviceName) {
  final lowerName = deviceName.toLowerCase();

  // Mobile
  if (lowerName.contains('iphone') ||
      lowerName.contains('pixel') ||
      lowerName.contains('galaxy') ||
      lowerName.contains('phone') ||
      lowerName.contains('android')) {
    return 'Mobile';
  }

  // Tablet
  if (lowerName.contains('ipad') ||
      lowerName.contains('tab') ||
      lowerName.contains('surface pro') ||
      lowerName.contains('tablet')) {
    return 'Tablet';
  }

  // Laptop
  if (lowerName.contains('macbook') ||
      lowerName.contains('laptop') ||
      lowerName.contains('thinkpad') ||
      lowerName.contains('xps') ||
      lowerName.contains('zenbook')) {
    return 'Laptop';
  }

  // Desktop
  if (lowerName.contains('imac') ||
      lowerName.contains('studio') ||
      lowerName.contains('desktop') ||
      lowerName.contains('pc') ||
      lowerName.contains('mac pro') ||
      lowerName.contains('mac mini')) {
    return 'Desktop';
  }

  // Watch
  if (lowerName.contains('watch') ||
      lowerName.contains('garmin') ||
      lowerName.contains('fitbit')) {
    return 'Watch';
  }

  // Earbuds
  if (lowerName.contains('airpods') ||
      lowerName.contains('buds') ||
      lowerName.contains('ear') ||
      lowerName.contains('earbud')) {
    return 'Earbuds';
  }

  // SmartHome
  if (lowerName.contains('nest') ||
      lowerName.contains('echo') ||
      lowerName.contains('alexa') ||
      lowerName.contains('homepod') ||
      lowerName.contains('smart home') ||
      lowerName.contains('smarthome') ||
      lowerName.contains('hub') ||
      lowerName.contains('thermostat') ||
      lowerName.contains('ring ') ||
      lowerName.contains('philips hue')) {
    return 'SmartHome';
  }

  // VR/AR
  if (lowerName.contains('quest') ||
      lowerName.contains('vision pro') ||
      lowerName.contains('vr ') ||
      lowerName.contains(' vr') ||
      lowerName.contains('metaverse') ||
      lowerName.contains('pico') ||
      lowerName.contains('valve index') ||
      lowerName.contains('hololens')) {
    return 'VR/AR';
  }

  // Mouse
  if (lowerName.contains('mouse') ||
      lowerName.contains('keyboard') ||
      lowerName.contains('hhkb') ||
      lowerName.contains('mechanical') ||
      lowerName.contains('gaming mouse') ||
      lowerName.contains('gaming keyboard')) {
    return 'Mouse';
  }

  // Drone
  if (lowerName.contains('drone') ||
      lowerName.contains('dji') ||
      lowerName.contains('mavic') ||
      lowerName.contains('phantom') ||
      lowerName.contains('mini 2') ||
      lowerName.contains('mini 3')) {
    return 'Drone';
  }

  // e-Reader
  if (lowerName.contains('kindle') ||
      lowerName.contains('kobo') ||
      lowerName.contains('ereader') ||
      lowerName.contains('e-reader') ||
      lowerName.contains('nook') ||
      lowerName.contains('remarkable') ||
      lowerName.contains('boox')) {
    return 'e-Reader';
  }

  // Vintage/old → Keyboard
  if (lowerName.contains('vintage') ||
      lowerName.contains('old') ||
      lowerName.contains('retro')) {
    return 'Keyboard';
  }

  return 'Laptop';
}

/// Returns the appropriate device icon for the given [deviceType].
/// [deviceType] matches category labels. Supports legacy types (Mac, iPhone, etc.) for old Firestore data.
IconData deviceTypeToIcon(String deviceType) {
  final lowerType = deviceType.toLowerCase();

  // Label-based matches (deviceType == label)
  switch (deviceType) {
    case 'Mobile':
      return Icons.smartphone;
    case 'Tablet':
      return Icons.tablet_mac;
    case 'Laptop':
      return Icons.laptop;
    case 'Desktop':
      return Icons.desktop_windows;
    case 'Watch':
      return Icons.watch;
    case 'Earbuds':
      return Icons.hearing;
    case 'Headphones':
      return Icons.headphones;
    case 'Camera':
      return Icons.photo_camera;
    case 'Gaming':
      return Icons.videogame_asset;
    case 'Keyboard':
      return Icons.keyboard;
    case 'SmartHome':
      return Icons.home;
    case 'VR/AR':
      return Icons.view_in_ar;
    case 'Mouse':
      return Icons.mouse;
    case 'Drone':
      return Icons.flight;
    case 'e-Reader':
      return Icons.menu_book;
    default:
      break;
  }

  // Legacy types (old Firestore data)
  switch (deviceType) {
    case 'Mac':
      return Icons.laptop_mac;
    case 'iPhone':
    case 'iPad':
    case 'iPod':
      return Icons.smartphone;
    case 'Apple Watch':
      return Icons.watch;
    case 'Vintage':
      return Icons.devices_other;
    case 'smart_home':
      return Icons.home;
    case 'vr':
      return Icons.view_in_ar;
    case 'gaming_peripheral':
      return Icons.mouse;
    case 'drone':
      return Icons.flight;
    case 'ereader':
      return Icons.menu_book;
    default:
      break;
  }

  // Keyword fallback (order matters: more specific matches first)
  // Check Mouse before Gaming to avoid false matches
  if (lowerType.contains('peripheral') || 
      (lowerType.contains('gaming') && (lowerType.contains('mouse') || lowerType.contains('keyboard'))) ||
      lowerType.contains('mouse') || 
      lowerType.contains('keyboard')) {
    return Icons.mouse;
  }
  if (lowerType.contains('headphone') || lowerType.contains('audio')) {
    return Icons.headphones;
  }
  if (lowerType.contains('earbud')) {
    return Icons.hearing;
  }
  if (lowerType.contains('smartwatch') || lowerType.contains('watch')) {
    return Icons.watch;
  }
  if (lowerType.contains('tablet')) {
    return Icons.tablet_mac;
  }
  if (lowerType.contains('gaming') || lowerType.contains('console') || lowerType.contains('game')) {
    return Icons.videogame_asset;
  }
  if (lowerType.contains('camera') || lowerType.contains('photo')) {
    return Icons.photo_camera;
  }
  if (lowerType.contains('smart') && lowerType.contains('home')) {
    return Icons.home;
  }
  if (lowerType.contains('vr') || lowerType.contains('ar')) {
    return Icons.view_in_ar;
  }
  if (lowerType.contains('drone')) {
    return Icons.flight;
  }
  if (lowerType.contains('ereader') || lowerType.contains('e-reader')) {
    return Icons.menu_book;
  }

  return Icons.devices;
}

/// Reusable Seki card with device icon, title, subtitle, note, and footer.
/// Used in Explore feed and Profile timeline for consistent styling.
/// Supports split tap areas: body area (icon + device name) and bottom bar (username).
class SekiCard extends StatelessWidget {
  final Seki seki;
  final bool isDark;
  final VoidCallback? onTap; // Legacy callback for backward compatibility
  final VoidCallback? onBodyTap; // Taps on body area (icon + device name + note)
  final VoidCallback? onBottomBarTap; // Taps on bottom bar (username area)

  const SekiCard({
    super.key,
    required this.seki,
    required this.isDark,
    this.onTap,
    this.onBodyTap,
    this.onBottomBarTap,
  });

  String get _yearRangeText {
    if (seki.isPreciseMode && seki.startTime != null) {
      // Precise mode: show dates
      final startDate = seki.startTime!.toDate();
      if (seki.endTime == null) {
        return '${startDate.year}/${startDate.month}/${startDate.day} – Present';
      } else {
        final endDate = seki.endTime!.toDate();
        return '${startDate.year}/${startDate.month}/${startDate.day} – ${endDate.year}/${endDate.month}/${endDate.day}';
      }
    } else {
      // Year mode: show years
      return seki.endYear == null ? '${seki.startYear} – Present' : '${seki.startYear} – ${seki.endYear}';
    }
  }

  /// Get background color for icon container based on deviceType
  Color _getIconBackgroundColor() {
    return getCategoryColor(seki.deviceType).withOpacity(0.12);
  }

  /// Get icon color based on deviceType for consistent tinted look
  Color _getIconColor() {
    return getCategoryColor(seki.deviceType);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cardColor = isDark
        ? theme.colorScheme.surface.withOpacity(0.5)
        : Colors.white;

    // Determine which callbacks to use (prefer new split callbacks, fallback to legacy)
    final bodyTapCallback = onBodyTap ?? onTap;
    final bottomBarTapCallback = onBottomBarTap ?? onTap;

    final secondaryGreyColor = isDark
        ? theme.colorScheme.onSurface.withOpacity(0.5)
        : Colors.grey.shade500;
    final lightGreyColor = isDark
        ? theme.colorScheme.onSurface.withOpacity(0.4)
        : Colors.grey.shade400;

    final categoryColor = _getIconColor();

    return Card(
      color: cardColor,
      elevation: isDark ? 0 : 2,
      shadowColor: Colors.black.withOpacity(0.06),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: isDark
            ? BorderSide(color: theme.colorScheme.outline.withOpacity(0.08), width: 1)
            : BorderSide.none,
      ),
      child: InkWell(
        onTap: bodyTapCallback,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Hero(
                    tag: 'device_icon_${seki.id}',
                    child: Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: _getIconBackgroundColor(),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: categoryColor.withOpacity(0.25),
                          width: 1,
                        ),
                      ),
                      child: Icon(
                        deviceTypeToIcon(seki.deviceType),
                        size: 26,
                        color: categoryColor,
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          seki.deviceName,
                          style: theme.textTheme.titleMedium?.copyWith(
                            color: theme.colorScheme.onSurface,
                            fontWeight: FontWeight.w600,
                            height: 1.25,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 6),
                        Text(
                          _yearRangeText,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: secondaryGreyColor,
                            fontSize: 12,
                          ),
                        ),
                        if (seki.note.isNotEmpty) ...[
                          const SizedBox(height: 10),
                          Text(
                            seki.note,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.onSurface.withOpacity(0.8),
                              height: 1.45,
                              fontStyle: FontStyle.italic,
                            ),
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Divider(height: 1, color: theme.colorScheme.outline.withOpacity(0.08)),
              const SizedBox(height: 10),
              Align(
                alignment: Alignment.centerRight,
                child: InkWell(
                  onTap: bottomBarTapCallback,
                  borderRadius: BorderRadius.circular(8),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.person_outline,
                          size: 14,
                          color: lightGreyColor,
                        ),
                        const SizedBox(width: 5),
                        Text(
                          seki.username,
                          style: theme.textTheme.labelMedium?.copyWith(
                            color: lightGreyColor,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
