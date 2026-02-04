import 'package:flutter/material.dart';

import '../data/device_catalog.dart';
import 'seki_card.dart';

// Re-export so callers only need to import device_icon_selector
export '../data/device_catalog.dart' show DeviceCategory, deviceCategories, getCategoryColor, getHintForDeviceType, deviceTypeToIcon, suggestDeviceTypeFromName;

/// Widget that displays a live icon preview based on device name
class DeviceIconPreview extends StatelessWidget {
  final String deviceName;
  final bool isDark;
  final double size;
  final String? deviceType; // Optional deviceType for color mapping

  const DeviceIconPreview({
    super.key,
    required this.deviceName,
    required this.isDark,
    this.size = 32,
    this.deviceType,
  });

  @override
  Widget build(BuildContext context) {
    final icon = deviceName.trim().isEmpty
        ? Icons.devices
        : getIconByDeviceName(deviceName);
    
    // Determine deviceType: use provided one, or infer from deviceName
    final String categoryType = deviceType ?? suggestDeviceTypeFromName(deviceName);
    final categoryColor = getCategoryColor(categoryType);
    
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: categoryColor.withOpacity(0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(
        icon,
        size: size * 0.7,
        color: categoryColor,
      ),
    );
  }
}

/// Horizontal scrolling icon grid for device category selection
class DeviceCategorySelector extends StatelessWidget {
  final String selectedDeviceType;
  final ValueChanged<String> onCategorySelected;
  final bool isDark;

  const DeviceCategorySelector({
    super.key,
    required this.selectedDeviceType,
    required this.onCategorySelected,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final selectedIcon = deviceTypeToIcon(selectedDeviceType);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      child: SizedBox(
          height: 80,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: deviceCategories.length,
            itemBuilder: (context, index) {
              final category = deviceCategories[index];
              final isSelected = category.icon == selectedIcon;

              return Padding(
                padding: EdgeInsets.only(
                  right: index < deviceCategories.length - 1 ? 12 : 0,
                ),
                child: GestureDetector(
                  onTap: () {
                    onCategorySelected(category.deviceType);
                  },
                  child: Container(
                    width: 70,
                    decoration: BoxDecoration(
                      color: isSelected
                          ? (isDark ? Colors.white : theme.colorScheme.primary).withOpacity(0.2)
                          : (isDark ? Colors.white : Colors.black).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isSelected
                            ? (isDark ? Colors.white : theme.colorScheme.primary).withOpacity(0.5)
                            : Colors.transparent,
                        width: 2,
                      ),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          category.icon,
                          size: 28,
                          color: isSelected
                              ? (isDark ? Colors.white : theme.colorScheme.primary)
                              : (isDark ? Colors.white : theme.colorScheme.onSurface).withOpacity(0.7),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          category.label,
                          style: TextStyle(
                            fontSize: 10,
                            color: isSelected
                                ? (isDark ? Colors.white : theme.colorScheme.primary)
                                : (isDark ? Colors.white : theme.colorScheme.onSurface).withOpacity(0.6),
                            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                          ),
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
    );
  }
}
