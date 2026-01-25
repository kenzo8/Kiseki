import 'package:flutter/material.dart';

import '../models/seki_model.dart';

/// Returns the appropriate device icon for the given [deviceType].
IconData deviceTypeToIcon(String deviceType) {
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
    default:
      return Icons.devices;
  }
}

/// Reusable Seki card with device icon, title, subtitle, note, and footer.
/// Used in Explore feed and Profile timeline for consistent styling.
class SekiCard extends StatelessWidget {
  final Seki seki;
  final bool isDark;
  final VoidCallback? onTap;

  const SekiCard({
    super.key,
    required this.seki,
    required this.isDark,
    this.onTap,
  });

  String get _yearRangeText =>
      seki.endYear == null ? '${seki.startYear} – 至今' : '${seki.startYear} – ${seki.endYear}';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final greyColor = isDark
        ? theme.colorScheme.onSurface.withOpacity(0.6)
        : Colors.grey.shade600;
    final cardColor = isDark
        ? theme.colorScheme.surface.withOpacity(0.5)
        : Colors.white;

    return Card(
      color: cardColor,
      elevation: isDark ? 0 : 2,
      shadowColor: Colors.black.withOpacity(0.08),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Left: device icon
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: (isDark ? Colors.white : Colors.grey.shade200)
                      .withOpacity(isDark ? 0.15 : 1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  deviceTypeToIcon(seki.deviceType),
                  size: 24,
                  color: isDark
                      ? theme.colorScheme.onSurface.withOpacity(0.8)
                      : Colors.grey.shade700,
                ),
              ),
              const SizedBox(width: 14),
              // Right: title, subtitle, note, footer
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
                    const SizedBox(height: 12),
                    // Divider
                    Divider(
                      height: 1,
                      thickness: 1,
                      color: theme.colorScheme.onSurface.withOpacity(0.1),
                    ),
                    const SizedBox(height: 10),
                    // Footer: by [username]
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
            ],
          ),
        ),
      ),
    );
  }
}
