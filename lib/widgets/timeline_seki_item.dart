import 'package:flutter/material.dart';

import '../models/seki_model.dart';
import 'seki_card.dart';
import 'device_icon_selector.dart';

/// Timeline item for Seki entries in profile List view.
/// Uses IntrinsicHeight for vertical line alignment.
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
      final endYear = seki.endYear ?? now.year;
      final durationYears = endYear - seki.startYear;

      if (isActive) {
        if (durationYears == 0) return 'Using for less than a year';
        if (durationYears == 1) return 'Using for 1 year';
        return 'Using for $durationYears years';
      } else {
        if (durationYears == 0) return 'Used for less than a year';
        if (durationYears == 1) return 'Used for 1 year';
        return 'Used for $durationYears years';
      }
    }
  }

  String get _dateLabel {
    if (!showYear) return '';
    if (seki.isPreciseMode && seki.startTime != null) {
      return '${seki.startTime!.toDate().year}';
    }
    return '${seki.startYear}';
  }

  bool get _isActive {
    if (seki.isPreciseMode) return seki.endTime == null;
    return seki.endYear == null;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final onSurface = theme.colorScheme.onSurface;
    final onSurfaceVariant = theme.colorScheme.onSurface.withOpacity(0.6);
    final outline = theme.colorScheme.outline.withOpacity(0.2);
    final categoryColor = getCategoryColor(seki.deviceType);

    return IntrinsicHeight(
      child: Padding(
        padding: const EdgeInsets.only(bottom: 24),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Left: date label
            SizedBox(
              width: 56,
              child: Padding(
                padding: const EdgeInsets.only(top: 2),
                child: _dateLabel.isEmpty
                    ? const SizedBox.shrink()
                    : Text(
                        _dateLabel,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: onSurfaceVariant,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          letterSpacing: 0.3,
                        ),
                        textAlign: TextAlign.right,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
              ),
            ),
            const SizedBox(width: 12),
            // Middle: timeline node + line (line centered under 28px icon)
            SizedBox(
              width: 44,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  // Vertical line (center at 22px = icon center in 44px width)
                  Positioned(
                    left: 21,
                    top: 28,
                    bottom: -24,
                    child: Container(
                      width: 2,
                      decoration: BoxDecoration(
                        color: isLast ? Colors.transparent : outline,
                        borderRadius: BorderRadius.circular(1),
                      ),
                    ),
                  ),
                  // Node with icon (28px, centered in 44px: left = (44-28)/2 = 8)
                  Positioned(
                    left: 8,
                    top: 0,
                    child: Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: categoryColor.withOpacity(0.12),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: categoryColor.withOpacity(0.5),
                          width: 2,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: categoryColor.withOpacity(0.15),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Icon(
                        deviceTypeToIcon(seki.deviceType),
                        size: 15,
                        color: categoryColor,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 14),
            // Right: content
            Expanded(
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: onTap,
                  borderRadius: BorderRadius.circular(12),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.baseline,
                          textBaseline: TextBaseline.alphabetic,
                          children: [
                            Expanded(
                              child: Text(
                                seki.deviceName,
                                style: theme.textTheme.titleMedium?.copyWith(
                                  color: onSurface,
                                  fontWeight: FontWeight.w600,
                                  height: 1.25,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (_isActive) ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.green.withOpacity(0.12),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Container(
                                      width: 5,
                                      height: 5,
                                      decoration: const BoxDecoration(
                                        color: Colors.green,
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      'Active',
                                      style: theme.textTheme.labelSmall?.copyWith(
                                        color: Colors.green.shade700,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _usageDurationText,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: onSurfaceVariant,
                            fontSize: 12,
                            height: 1.3,
                          ),
                        ),
                        if (seki.note.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Text(
                            seki.note,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: onSurface.withOpacity(0.7),
                              height: 1.45,
                              fontWeight: FontWeight.w400,
                            ),
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
