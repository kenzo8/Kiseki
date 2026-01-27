import 'package:flutter/material.dart';

import '../models/seki_model.dart';

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
    return Icons.flight_takeoff;
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

  // Smart Home
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
    return 'Smart Home';
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

  // Gaming Peripherals
  if (lowerName.contains('mouse') ||
      lowerName.contains('keyboard') ||
      lowerName.contains('hhkb') ||
      lowerName.contains('mechanical') ||
      lowerName.contains('gaming mouse') ||
      lowerName.contains('gaming keyboard')) {
    return 'Gaming Peripherals';
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

  // Vintage/old → Accessory
  if (lowerName.contains('vintage') ||
      lowerName.contains('old') ||
      lowerName.contains('retro')) {
    return 'Accessory';
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
    case 'Accessory':
      return Icons.keyboard;
    case 'Smart Home':
      return Icons.home;
    case 'VR/AR':
      return Icons.view_in_ar;
    case 'Gaming Peripherals':
      return Icons.mouse;
    case 'Drone':
      return Icons.flight_takeoff;
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
      return Icons.flight_takeoff;
    case 'ereader':
      return Icons.menu_book;
    default:
      break;
  }

  // Keyword fallback
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
  if (lowerType.contains('peripheral') || lowerType.contains('mouse') || lowerType.contains('keyboard')) {
    return Icons.mouse;
  }
  if (lowerType.contains('drone')) {
    return Icons.flight_takeoff;
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final greyColor = isDark
        ? theme.colorScheme.onSurface.withOpacity(0.6)
        : Colors.grey.shade600;
    final cardColor = isDark
        ? theme.colorScheme.surface.withOpacity(0.5)
        : Colors.white;

    // Determine which callbacks to use (prefer new split callbacks, fallback to legacy)
    final bodyTapCallback = onBodyTap ?? onTap;
    final bottomBarTapCallback = onBottomBarTap ?? onTap;

    return Card(
      color: cardColor,
      elevation: isDark ? 0 : 2,
      shadowColor: Colors.black.withOpacity(0.08),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Column(
        children: [
          // Body Area: Icon + Device Name + Year Range + Note
          InkWell(
            onTap: bodyTapCallback,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(12),
              topRight: Radius.circular(12),
            ),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Left: device icon with Hero animation
                  Hero(
                    tag: 'device_icon_${seki.id}',
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: (isDark ? Colors.white : Colors.grey.shade200)
                            .withOpacity(isDark ? 0.15 : 1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        getIconByDeviceName(seki.deviceName),
                        size: 24,
                        color: isDark
                            ? theme.colorScheme.onSurface.withOpacity(0.8)
                            : Colors.grey.shade700,
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  // Right: title, subtitle, note
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Title: bold device name
                        Text(
                          seki.deviceName,
                          style: TextStyle(
                            color: theme.colorScheme.onSurface,
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                            height: 1.3,
                          ),
                        ),
                        const SizedBox(height: 4),
                        // Subtitle: year range (grey)
                        Text(
                          _yearRangeText,
                          style: TextStyle(
                            color: greyColor,
                            fontSize: 14,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                        // Note: wrapped in quotation marks
                        if (seki.note.isNotEmpty) ...[
                          const SizedBox(height: 10),
                          Text(
                            '"${seki.note}"',
                            style: TextStyle(
                              color: theme.colorScheme.onSurface.withOpacity(0.85),
                              fontSize: 15,
                              height: 1.45,
                            ),
                            maxLines: 4,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Divider for visual separation
          Divider(
            height: 1,
            thickness: 1,
            color: theme.colorScheme.onSurface.withOpacity(0.1),
            indent: 0,
            endIndent: 0,
          ),
          // Bottom Bar: Username area
          InkWell(
            onTap: bottomBarTapCallback,
            borderRadius: const BorderRadius.only(
              bottomLeft: Radius.circular(12),
              bottomRight: Radius.circular(12),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              child: Row(
                children: [
                  Text(
                    'by ${seki.username}',
                    style: TextStyle(
                      color: greyColor,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
