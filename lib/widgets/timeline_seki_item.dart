import 'package:flutter/material.dart';

import '../models/seki_model.dart';
import 'seki_card.dart';

/// Borderless timeline item for Seki entries in profile pages.
/// Uses IntrinsicHeight to ensure proper vertical line rendering.
class TimelineSekiItem extends StatelessWidget {
  final Seki seki;
  final bool isDark;
  final bool isLast;
  final VoidCallback? onTap;

  const TimelineSekiItem({
    super.key,
    required this.seki,
    required this.isDark,
    this.isLast = false,
    this.onTap,
  });

  String get _yearRangeText {
    if (seki.endYear == null) {
      return '${seki.startYear} - 至今';
    }
    return '${seki.startYear} - ${seki.endYear}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final timelineColor = Colors.grey.withOpacity(0.3);
    final yearColor = Colors.grey[500]!;
    final deviceIconColor = theme.colorScheme.onSurface.withOpacity(0.7);

    return IntrinsicHeight(
      child: GestureDetector(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.only(bottom: 32.0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Left side: Start Year (Fixed width for 4-digit year)
              SizedBox(
                width: 50,
                child: Padding(
                  padding: const EdgeInsets.only(top: 0),
                  child: Text(
                    '${seki.startYear}',
                    style: TextStyle(
                      color: yearColor,
                      fontSize: 12,
                      fontWeight: FontWeight.w400,
                      letterSpacing: 0.5,
                    ),
                    textAlign: TextAlign.right,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              // Middle: Timeline (Width 40)
              SizedBox(
                width: 40,
                child: Stack(
                  children: [
                    // Vertical line (full height, continuous)
                    Positioned(
                      left: 19.5, // Center of 40px width (20 - 0.5)
                      top: 0,
                      bottom: 0,
                      child: Container(
                        width: 1,
                        color: isLast ? Colors.transparent : timelineColor,
                      ),
                    ),
                    // Dot (positioned at top, centered on line)
                    Positioned(
                      left: 8, // (40 - 24) / 2 = 8
                      top: 0,
                      child: Container(
                        width: 24,
                        height: 24,
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surface,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: deviceIconColor,
                            width: 2,
                          ),
                        ),
                        child: Icon(
                          deviceTypeToIcon(seki.deviceType),
                          size: 14,
                          color: deviceIconColor,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              // Right side: Content (Expanded)
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(top: 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Full duration text (grey, small font)
                      Text(
                        _yearRangeText,
                        style: TextStyle(
                          color: yearColor,
                          fontSize: 12,
                          fontWeight: FontWeight.w400,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 6),
                      // Device Name (bold, larger font)
                      Text(
                        seki.deviceName,
                        style: TextStyle(
                          color: theme.colorScheme.onSurface,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          height: 1.3,
                        ),
                      ),
                      // Note (regular font, subtle grey)
                      if (seki.note.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Text(
                          seki.note,
                          style: TextStyle(
                            color: theme.colorScheme.onSurface.withOpacity(0.7),
                            fontSize: 15,
                            height: 1.5,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                      ],
                    ],
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
