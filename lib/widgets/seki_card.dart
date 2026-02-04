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
