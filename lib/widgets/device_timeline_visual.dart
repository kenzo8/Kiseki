import 'dart:math';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/seki_model.dart';
import '../services/profile_data_service.dart';
import '../pages/device_detail_page.dart';
import 'device_icon_selector.dart';

/// Visual timeline view showing device usage as interactive timeline bars.
/// When [sekis] is provided (e.g. for other user profile), uses that list;
/// otherwise uses [ProfileDataService.instance.cachedSekis].
class DeviceTimelineVisual extends StatelessWidget {
  final ValueNotifier<bool>? exploreRefreshNotifier;
  /// When non-null, use this list instead of ProfileDataService (e.g. for other user profile).
  final List<Seki>? sekis;

  const DeviceTimelineVisual({super.key, this.exploreRefreshNotifier, this.sekis});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final data = sekis ?? ProfileDataService.instance.cachedSekis ?? <Seki>[];
    final isOtherUser = sekis != null;

    if (data.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primaryContainer.withOpacity(0.3),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.timeline_outlined,
                  size: 48,
                  color: theme.colorScheme.primary.withOpacity(0.7),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'No device timeline',
                style: theme.textTheme.titleLarge?.copyWith(
                  color: theme.colorScheme.onSurface,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                isOtherUser
                    ? 'No devices to show.'
                    : 'Add devices to see your usage timeline visualized here.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurface.withOpacity(0.6),
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Group by deviceType (same category merged)
    final grouped = <String, List<Seki>>{};
    for (final seki in data) {
      grouped.putIfAbsent(seki.deviceType, () => []).add(seki);
    }

    // Sort devices within each group by start date (oldest first)
    for (final list in grouped.values) {
      list.sort((a, b) {
        final aStart = a.isPreciseMode && a.startTime != null
            ? a.startTime!.toDate()
            : DateTime(a.startYear, 1, 1);
        final bStart = b.isPreciseMode && b.startTime != null
            ? b.startTime!.toDate()
            : DateTime(b.startYear, 1, 1);
        return aStart.compareTo(bStart);
      });
    }

    // Sort groups by earliest device start in that group (so categories appear in time order)
    final groupEntries = grouped.entries.toList();
    groupEntries.sort((a, b) {
      final aStart = _getStartDate(a.value.first);
      final bStart = _getStartDate(b.value.first);
      return aStart.compareTo(bStart);
    });

    // Calculate global time range: left from data, right end = today so "Present" bars reach the end
    final now = DateTime.now();
    DateTime minDate = _getStartDate(data.first);
    for (final seki in data) {
      final start = _getStartDate(seki);
      if (start.isBefore(minDate)) minDate = start;
    }
    // Right end is always today so active (present) device bars can reach the right end
    final DateTime maxDate = now;
    final rawDays = maxDate.difference(minDate).inDays;
    final totalDays = rawDays < 1 ? 1 : rawDays; // avoid zero for safe division
    final paddingDays = (totalDays * 0.1).round().clamp(0, 365);
    minDate = minDate.subtract(Duration(days: paddingDays));

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ...groupEntries.map((e) => _TimelineCategoryCard(
            deviceType: e.key,
            devices: e.value,
            minDate: minDate,
            maxDate: maxDate,
            theme: theme,
            isDark: isDark,
            onDeviceTap: (seki) {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => DeviceDetailPage(
                    seki: seki,
                    exploreRefreshNotifier: exploreRefreshNotifier,
                  ),
                ),
              );
            },
          )),
        ],
      ),
    );
  }

  static DateTime _getStartDate(Seki seki) {
    if (seki.isPreciseMode && seki.startTime != null) {
      return seki.startTime!.toDate();
    }
    return DateTime(seki.startYear, 1, 1);
  }
}

/// One card per device type (category), with all devices of that type inside.
class _TimelineCategoryCard extends StatelessWidget {
  final String deviceType;
  final List<Seki> devices;
  final DateTime minDate;
  final DateTime maxDate;
  final ThemeData theme;
  final bool isDark;
  final void Function(Seki seki) onDeviceTap;

  const _TimelineCategoryCard({
    required this.deviceType,
    required this.devices,
    required this.minDate,
    required this.maxDate,
    required this.theme,
    required this.isDark,
    required this.onDeviceTap,
  });

  String _formatDate(DateTime date) {
    return DateFormat('yyyy').format(date);
  }

  @override
  Widget build(BuildContext context) {
    final categoryColor = getCategoryColor(deviceType);
    final totalDays = max(1, maxDate.difference(minDate).inDays);

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark
              ? theme.colorScheme.surfaceContainerHighest.withOpacity(0.5)
              : Colors.white.withOpacity(0.7),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: theme.colorScheme.outline.withOpacity(0.1),
            width: 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Category header: icon + name + count
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: categoryColor.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    deviceTypeToIcon(deviceType),
                    size: 24,
                    color: categoryColor,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    deviceType,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: categoryColor.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${devices.length} ${devices.length == 1 ? 'device' : 'devices'}',
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: categoryColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // One row per device in this category
            ...devices.asMap().entries.map((entry) {
              final index = entry.key;
              final seki = entry.value;
              final isLast = index == devices.length - 1;
              return _DeviceTimelineRow(
                seki: seki,
                minDate: minDate,
                maxDate: maxDate,
                totalDays: totalDays,
                categoryColor: categoryColor,
                theme: theme,
                formatDate: _formatDate,
                onTap: () => onDeviceTap(seki),
                showDivider: !isLast,
              );
            }),
          ],
        ),
      ),
    );
  }
}

/// Single device row with timeline bar inside a category card.
class _DeviceTimelineRow extends StatelessWidget {
  final Seki seki;
  final DateTime minDate;
  final DateTime maxDate;
  final int totalDays;
  final Color categoryColor;
  final ThemeData theme;
  final String Function(DateTime) formatDate;
  final VoidCallback onTap;
  final bool showDivider;

  const _DeviceTimelineRow({
    required this.seki,
    required this.minDate,
    required this.maxDate,
    required this.totalDays,
    required this.categoryColor,
    required this.theme,
    required this.formatDate,
    required this.onTap,
    required this.showDivider,
  });

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    DateTime startDate;
    DateTime endDate;
    bool isActive;

    if (seki.isPreciseMode && seki.startTime != null) {
      startDate = seki.startTime!.toDate();
      endDate = seki.endTime?.toDate() ?? now;
      isActive = seki.endTime == null;
    } else {
      startDate = DateTime(seki.startYear, 1, 1);
      endDate = seki.endYear != null ? DateTime(seki.endYear!, 12, 31) : now;
      isActive = seki.endYear == null;
    }

    final startOffset = startDate.difference(minDate).inDays;
    final durationDays = endDate.difference(startDate).inDays;
    final startPercent = totalDays > 0 ? (startOffset / totalDays).clamp(0.0, 1.0) : 0.0;
    final widthPercent = totalDays > 0 ? (durationDays / totalDays).clamp(0.01, 1.0) : 0.01;

    String durationText;
    final endDateTime = endDate;
    final d = endDateTime.difference(startDate);
    final y = d.inDays ~/ 365;
    final m = (d.inDays % 365) ~/ 30;
    if (y > 0 && m > 0) {
      durationText = '${y}y ${m}m';
    } else if (y > 0) {
      durationText = '${y}y';
    } else if (m > 0) {
      durationText = '${m}m';
    } else {
      durationText = '<1m';
    }
    if (isActive) durationText = 'Using $durationText';
    else durationText = 'Used $durationText';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          seki.deviceName,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w500,
                            color: theme.colorScheme.onSurface,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (isActive)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.green.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            'Active',
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: Colors.green.shade700,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        )
                      else
                        Text(
                          durationText,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurface.withOpacity(0.6),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final barWidth = constraints.maxWidth;
                      final barLeft = barWidth * startPercent;
                      final barWidthActual = barWidth * widthPercent;

                      return Container(
                        height: 6,
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(3),
                        ),
                        child: Stack(
                          children: [
                            Positioned(
                              left: barLeft,
                              child: Container(
                                width: barWidthActual.clamp(4.0, double.infinity),
                                height: 6,
                                decoration: BoxDecoration(
                                  color: categoryColor.withOpacity(0.85),
                                  borderRadius: BorderRadius.circular(3),
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        formatDate(startDate),
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.onSurface.withOpacity(0.5),
                        ),
                      ),
                      Text(
                        isActive ? 'Present' : formatDate(endDate),
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: isActive
                              ? Colors.green.shade700
                              : theme.colorScheme.onSurface.withOpacity(0.5),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
        if (showDivider)
          Divider(
            height: 1,
            thickness: 1,
            color: theme.colorScheme.outline.withOpacity(0.08),
          ),
      ],
    );
  }
}
