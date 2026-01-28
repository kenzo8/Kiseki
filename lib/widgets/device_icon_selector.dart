import 'package:flutter/material.dart';
import 'seki_card.dart';

/// Device category with icon and label
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

/// All available device categories.
/// [deviceType] equals [label] and is saved to Firestore when adding/editing a device.
const List<DeviceCategory> deviceCategories = [
  DeviceCategory(icon: Icons.smartphone, label: 'Mobile', deviceType: 'Mobile'),
  DeviceCategory(icon: Icons.tablet_mac, label: 'Tablet', deviceType: 'Tablet'),
  DeviceCategory(icon: Icons.laptop, label: 'Laptop', deviceType: 'Laptop'),
  DeviceCategory(icon: Icons.desktop_windows, label: 'Desktop', deviceType: 'Desktop'),
  DeviceCategory(icon: Icons.watch, label: 'Watch', deviceType: 'Watch'),
  DeviceCategory(icon: Icons.hearing, label: 'Earbuds', deviceType: 'Earbuds'),
  DeviceCategory(icon: Icons.headphones, label: 'Headphones', deviceType: 'Headphones'),
  DeviceCategory(icon: Icons.photo_camera, label: 'Camera', deviceType: 'Camera'),
  DeviceCategory(icon: Icons.videogame_asset, label: 'Gaming', deviceType: 'Gaming'),
  DeviceCategory(icon: Icons.keyboard, label: 'Accessory', deviceType: 'Accessory'),
  DeviceCategory(icon: Icons.home, label: 'Smart Home', deviceType: 'Smart Home'),
  DeviceCategory(icon: Icons.view_in_ar, label: 'VR/AR', deviceType: 'VR/AR'),
  DeviceCategory(icon: Icons.mouse, label: 'Gaming Peripherals', deviceType: 'Gaming Peripherals'),
  DeviceCategory(icon: Icons.flight_takeoff, label: 'Drone', deviceType: 'Drone'),
  DeviceCategory(icon: Icons.menu_book, label: 'e-Reader', deviceType: 'e-Reader'),
];

/// Get the category color for a given deviceType
Color getCategoryColor(String deviceType) {
  switch (deviceType) {
    case 'Mobile':
      return Colors.blue;
    case 'Tablet':
      return Colors.green;
    case 'Laptop':
    case 'Desktop':
      return Colors.purple;
    case 'Watch':
      return Colors.orange;
    case 'Earbuds':
    case 'Headphones':
      return Colors.cyan;
    case 'Camera':
      return Colors.amber;
    case 'Gaming':
      return Colors.red;
    case 'Drone':
      return Colors.teal;
    case 'VR/AR':
      return Colors.indigo;
    case 'Smart Home':
      return Colors.brown;
    case 'Gaming Peripherals':
      return Colors.pink;
    case 'e-Reader':
      return Colors.deepOrange;
    case 'Accessory':
      return Colors.grey;
    default:
      return Colors.grey;
  }
}

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

  IconData _getIconForDeviceType(String deviceType) {
    // Use the centralized deviceTypeToIcon function for consistency
    return deviceTypeToIcon(deviceType);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final selectedIcon = _getIconForDeviceType(selectedDeviceType);

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
