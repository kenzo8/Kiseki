import 'package:flutter/material.dart';

import '../models/seki_model.dart';
import 'seki_card.dart';
import 'device_icon_selector.dart';

/// Borderless timeline item for Seki entries in profile pages.
/// Uses IntrinsicHeight to ensure proper vertical line rendering.
class TimelineSekiItem extends StatelessWidget {
  final Seki seki;
  final bool isDark;
  final bool isLast;
  final VoidCallback? onTap;
  final bool showYear;

  const TimelineSekiItem({
    super.key,
    required this.seki,
    required this.isDark,
    this.isLast = false,
    this.onTap,
    this.showYear = true,
  });

  String get _usageDurationText {
    final now = DateTime.now();
    DateTime startDate;
    DateTime? endDate;
    
    if (seki.isPreciseMode && seki.startTime != null) {
      startDate = seki.startTime!.toDate();
      endDate = seki.endTime?.toDate();
    } else {
      startDate = DateTime(seki.startYear, 1, 1);
      endDate = seki.endYear != null ? DateTime(seki.endYear!, 12, 31) : null;
    }
    
    final endDateTime = endDate ?? now;
    final duration = endDateTime.difference(startDate);
    final years = duration.inDays ~/ 365;
    final months = (duration.inDays % 365) ~/ 30;
    
    final isActive = endDate == null;
    
    if (seki.isPreciseMode && seki.startTime != null) {
      // Precise mode: show more detailed duration
      if (years == 0 && months == 0) {
        return isActive ? 'Using for less than a month' : 'Used for less than a month';
      } else if (years == 0) {
        return isActive 
            ? 'Using for $months ${months == 1 ? 'month' : 'months'}'
            : 'Used for $months ${months == 1 ? 'month' : 'months'}';
      } else if (months == 0) {
        return isActive
            ? 'Using for $years ${years == 1 ? 'year' : 'years'}'
            : 'Used for $years ${years == 1 ? 'year' : 'years'}';
      } else {
        return isActive
            ? 'Using for $years ${years == 1 ? 'year' : 'years'} $months ${months == 1 ? 'month' : 'months'}'
            : 'Used for $years ${years == 1 ? 'year' : 'years'} $months ${months == 1 ? 'month' : 'months'}';
      }
    } else {
      // Year mode: show years only
      final endYear = seki.endYear ?? now.year;
      final durationYears = endYear - seki.startYear;
      
      if (isActive) {
        // Still active - use "Using for X years"
        if (durationYears == 0) {
          return 'Using for less than a year';
        } else if (durationYears == 1) {
          return 'Using for 1 year';
        } else {
          return 'Using for $durationYears years';
        }
      } else {
        // Completed - use "Used for X years"
        if (durationYears == 0) {
          return 'Used for less than a year';
        } else if (durationYears == 1) {
          return 'Used for 1 year';
        } else {
          return 'Used for $durationYears years';
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final timelineColor = Colors.grey.withOpacity(0.2);
    final yearColor = Colors.grey[500]!;
    final categoryColor = getCategoryColor(seki.deviceType);
    final deviceIconColor = categoryColor;

    return IntrinsicHeight(
      child: GestureDetector(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.only(bottom: 32.0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Left side: Start Year/Date (Fixed width for 4-digit year or date)
              SizedBox(
                width: 50,
                child: Padding(
                  padding: const EdgeInsets.only(top: 0),
                  child: showYear
                      ? Text(
                          seki.isPreciseMode && seki.startTime != null
                              ? '${seki.startTime!.toDate().year}'
                              : '${seki.startYear}',
                          style: TextStyle(
                            color: yearColor,
                            fontSize: 12,
                            fontWeight: FontWeight.w400,
                            letterSpacing: 0.5,
                          ),
                          textAlign: TextAlign.right,
                        )
                      : const SizedBox.shrink(),
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
                      left: 19.25, // Center of 40px width (20 - 0.75)
                      top: 0,
                      bottom: 0,
                      child: Container(
                        width: 1.5,
                        color: isLast ? Colors.transparent : timelineColor,
                      ),
                    ),
                    // Dot (positioned at top, centered on line)
                    Positioned(
                      left: 8, // (40 - 24) / 2 = 8
                      top: 0,
                      child: Hero(
                        tag: 'device_icon_${seki.id}',
                        child: Container(
                          width: 24,
                          height: 24,
                          decoration: BoxDecoration(
                            color: categoryColor.withOpacity(0.15),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: deviceIconColor.withOpacity(0.6),
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
                      // Usage duration text (grey, small font)
                      Text(
                        _usageDurationText,
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
                          maxLines: 4,
                          overflow: TextOverflow.ellipsis,
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
