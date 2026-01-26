import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../models/seki_model.dart';
import '../widgets/device_icon_selector.dart';
import '../widgets/seki_card.dart';
import '../services/auth_service.dart';

class AddDevicePage extends StatefulWidget {
  final Seki? seki;
  final String? preFilledDeviceName;
  final bool? preFilledStillUsing;
  final bool? overrideStillUsing; // Overrides "Still using" even in Edit mode

  const AddDevicePage({
    super.key,
    this.seki,
    this.preFilledDeviceName,
    this.preFilledStillUsing,
    this.overrideStillUsing,
  });

  @override
  State<AddDevicePage> createState() => _AddDevicePageState();
}

class _AddDevicePageState extends State<AddDevicePage> {
  late TextEditingController _nameController;
  late TextEditingController _noteController;
  late String _deviceType;
  late RangeValues _yearRange;
  late bool _stillUsing;
  bool _isLoading = false;
  bool _showCategoryPicker = false;
  bool _isManualCategorySelection = false;
  late IconData _selectedIcon;
  final FocusNode _deviceNameFocusNode = FocusNode();
  final FocusNode _noteFocusNode = FocusNode();

  bool get isEditMode => widget.seki != null;

  @override
  void initState() {
    super.initState();
    
    // Initialize controllers and state from existing device if in edit mode
    if (isEditMode && widget.seki != null) {
      _nameController = TextEditingController(text: widget.seki!.deviceName);
      _noteController = TextEditingController(text: widget.seki!.note);
      _deviceType = widget.seki!.deviceType;
      // Use override if provided, otherwise use saved value
      _stillUsing = widget.overrideStillUsing ?? (widget.seki!.endYear == null);
      // Adjust year range based on stillUsing state
      _yearRange = RangeValues(
        widget.seki!.startYear.toDouble(),
        _stillUsing ? 2026.0 : (widget.seki!.endYear?.toDouble() ?? 2026.0),
      );
    } else {
      // Initialize with default values for add mode, or use pre-filled values
      _nameController = TextEditingController(text: widget.preFilledDeviceName ?? '');
      _noteController = TextEditingController();
      _deviceType = 'Mac';
      // Use override if provided, otherwise use pre-filled or default
      _stillUsing = widget.overrideStillUsing ?? widget.preFilledStillUsing ?? false;
      _yearRange = const RangeValues(2010, 2026);
    }
    
    // Initialize selected icon from current deviceType
    _selectedIcon = _getIconForDeviceType(_deviceType);
    
    // Auto-focus the device name field when the page opens
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _deviceNameFocusNode.requestFocus();
    });
    
    // Listen to text changes to update button state and suggest device type
    _nameController.addListener(_onDeviceNameChanged);
    _noteController.addListener(_onTextChanged);
  }

  void _onDeviceNameChanged() {
    // Auto-suggest device type only when user has NOT manually picked a category
    if (!_isManualCategorySelection) {
      final deviceName = _nameController.text.trim();
      if (deviceName.isNotEmpty) {
        final suggestedType = suggestDeviceTypeFromName(deviceName);
        if (suggestedType != _deviceType) {
          setState(() {
            _deviceType = suggestedType;
            _selectedIcon = _getIconForDeviceType(suggestedType);
          });
        }
      }
    }
    setState(() {});
  }

  void _onTextChanged() {
    setState(() {});
  }

  @override
  void dispose() {
    _nameController.removeListener(_onDeviceNameChanged);
    _noteController.removeListener(_onTextChanged);
    _nameController.dispose();
    _noteController.dispose();
    _deviceNameFocusNode.dispose();
    _noteFocusNode.dispose();
    super.dispose();
  }

  IconData _getIconForDeviceType(String deviceType) {
    // Map device type to icon using deviceCategories
    for (final category in deviceCategories) {
      if (category.deviceType == deviceType) {
        return category.icon;
      }
    }
    return Icons.devices; // Default fallback
  }

  String _getDeviceTypeForIcon(IconData icon) {
    // Map icon to device type using deviceCategories
    for (final category in deviceCategories) {
      if (category.icon == icon) {
        return category.deviceType;
      }
    }
    return 'Mac'; // Default fallback
  }

  void _handleSubmit() {
    // Smart validation with focus management
    if (_nameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a device name')),
      );
      _deviceNameFocusNode.requestFocus();
      return;
    }
    
    if (_noteController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please add a short note')),
      );
      _noteFocusNode.requestFocus();
      return;
    }
    
    // Call the appropriate function based on mode
    if (isEditMode) {
      _updateDevice();
    } else {
      _addDevice();
    }
  }

  Future<void> _addDevice() async {
    setState(() {
      _isLoading = true;
    });

    final currentUser = FirebaseAuth.instance.currentUser;
    final uid = currentUser?.uid;
    
    if (uid == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error: Not signed in')),
        );
      }
      setState(() {
        _isLoading = false;
      });
      return;
    }

    try {
      String username;
      final authService = AuthService();
      
      try {
        final userProfile = await authService.getUserProfile(uid);
        if (userProfile != null && userProfile['username'] != null) {
          username = userProfile['username'] as String;
        } else {
          final userEmail = currentUser?.email;
          if (userEmail != null) {
            username = authService.generateDefaultUsername(userEmail);
          } else {
            username = 'user${uid.substring(0, 4)}';
          }
        }
      } catch (e) {
        final userEmail = currentUser?.email;
        if (userEmail != null) {
          username = authService.generateDefaultUsername(userEmail);
        } else {
          username = 'user${uid.substring(0, 4)}';
        }
      }

      await FirebaseFirestore.instance.collection('seki').add({
        'uid': uid,
        'username': username,
        'deviceName': _nameController.text.trim(),
        'deviceType': _deviceType,
        'startYear': _yearRange.start.toInt(),
        'endYear': _stillUsing ? null : _yearRange.end.toInt(),
        'createdAt': FieldValue.serverTimestamp(),
        'note': _noteController.text.trim(),
      });
      
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Device added successfully!'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to add device: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _updateDevice() async {
    if (widget.seki == null) return;

    setState(() {
      _isLoading = true;
    });

    try {
      await FirebaseFirestore.instance.collection('seki').doc(widget.seki!.id).update({
        'deviceName': _nameController.text.trim(),
        'deviceType': _deviceType,
        'startYear': _yearRange.start.toInt(),
        'endYear': _stillUsing ? null : _yearRange.end.toInt(),
        'note': _noteController.text.trim(),
      });
      
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Device updated successfully!'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update device: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    
    // Check if button should be enabled
    final isButtonEnabled = _nameController.text.trim().isNotEmpty &&
        _noteController.text.trim().isNotEmpty;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A1F35) : theme.colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: DraggableScrollableSheet(
        initialChildSize: 0.9,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scrollController) {
          return Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom,
            ),
            child: SingleChildScrollView(
              controller: scrollController,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Top Header
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                    child: Row(
                      children: [
                        // Cancel button
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: Text(
                            'Cancel',
                            style: TextStyle(
                              color: (isDark ? Colors.white : theme.colorScheme.onSurface).withOpacity(0.7),
                              fontSize: 16,
                            ),
                          ),
                        ),
                        // Title (centered)
                        Expanded(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Center(
                                child: Text(
                                  isEditMode ? 'Edit Device' : 'Add New Device',
                                  style: TextStyle(
                                    color: isDark ? Colors.white : theme.colorScheme.onSurface,
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              if (!isEditMode)
                                Padding(
                                  padding: const EdgeInsets.only(top: 2),
                                  child: Center(
                                    child: Text(
                                      'Visible to everyone on Explore',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        color: Colors.grey,
                                        fontSize: 10,
                                        fontWeight: FontWeight.w400,
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                        // Submit button
                        TextButton(
                          onPressed: isButtonEnabled && !_isLoading ? _handleSubmit : null,
                          child: _isLoading
                              ? SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      isDark ? Colors.white : theme.colorScheme.primary,
                                    ),
                                  ),
                                )
                              : Text(
                                  isEditMode ? 'Save Changes' : 'Add',
                                  style: TextStyle(
                                    color: isButtonEnabled
                                        ? (isDark ? Colors.white : theme.colorScheme.primary)
                                        : (isDark ? Colors.white : theme.colorScheme.onSurface).withOpacity(0.3),
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                        ),
                      ],
                    ),
                  ),
                  // Divider
                  Divider(
                    height: 1,
                    thickness: 1,
                    color: (isDark ? Colors.white : Colors.black).withOpacity(0.1),
                  ),
                  // Content
                  Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Device Name with integrated category suffixIcon
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            TextField(
                              controller: _nameController,
                              focusNode: _deviceNameFocusNode,
                              style: TextStyle(color: isDark ? Colors.white : theme.colorScheme.onSurface),
                              decoration: InputDecoration(
                                labelText: 'Device Name',
                                labelStyle: TextStyle(
                                  color: (isDark ? Colors.white : theme.colorScheme.onSurface).withOpacity(0.7),
                                ),
                                hintText: 'e.g., MacBook Pro M1',
                                hintStyle: TextStyle(
                                  color: (isDark ? Colors.white : theme.colorScheme.onSurface).withOpacity(0.5),
                                ),
                                alignLabelWithHint: true,
                                enabledBorder: UnderlineInputBorder(
                                  borderSide: BorderSide(
                                    color: (isDark ? Colors.grey[600]! : Colors.grey[300]!),
                                  ),
                                ),
                                focusedBorder: UnderlineInputBorder(
                                  borderSide: BorderSide(
                                    color: theme.colorScheme.primary,
                                    width: 1.5,
                                  ),
                                ),
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 16,
                                ),
                                suffixIcon: InkWell(
                                  onTap: () {
                                    setState(() => _showCategoryPicker = !_showCategoryPicker);
                                  },
                                  borderRadius: BorderRadius.circular(24),
                                  child: Padding(
                                    padding: const EdgeInsets.all(12),
                                    child: Icon(
                                      _selectedIcon,
                                      size: 24,
                                      color: (isDark ? Colors.white : theme.colorScheme.onSurface).withOpacity(0.8),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            if (_showCategoryPicker) ...[
                              const SizedBox(height: 12),
                              _CategoryPickerStrip(
                                selectedIcon: _selectedIcon,
                                isDark: isDark,
                                primaryColor: theme.colorScheme.primary,
                                onCategorySelected: (selectedIcon) {
                                  setState(() {
                                    _isManualCategorySelection = true;
                                    _showCategoryPicker = false;
                                    _selectedIcon = selectedIcon;
                                  });
                                  // Convert icon to deviceType for parent
                                  final deviceType = _getDeviceTypeForIcon(selectedIcon);
                                  setState(() {
                                    _deviceType = deviceType;
                                  });
                                },
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 36),
                        // Year Range Slider
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Year Range',
                                  style: TextStyle(
                                    color: (isDark ? Colors.white : theme.colorScheme.onSurface).withOpacity(0.9),
                                    fontSize: 16,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                Text(
                                  _stillUsing
                                      ? '${_yearRange.start.toInt()} - Present'
                                      : '${_yearRange.start.toInt()} - ${_yearRange.end.toInt()}',
                                  style: TextStyle(
                                    color: (isDark ? Colors.white : theme.colorScheme.onSurface).withOpacity(0.7),
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            RangeSlider(
                              values: _yearRange,
                              min: 2010,
                              max: 2026,
                              divisions: 16,
                              labels: RangeLabels(
                                _yearRange.start.toInt().toString(),
                                _stillUsing
                                    ? 'Present'
                                    : _yearRange.end.toInt().toString(),
                              ),
                              activeColor: isDark ? Colors.white : theme.colorScheme.primary,
                              inactiveColor: (isDark ? Colors.white : theme.colorScheme.primary).withOpacity(0.3),
                              onChanged: _stillUsing
                                  ? (range) {
                                      setState(() {
                                        _yearRange = RangeValues(range.start, 2026);
                                      });
                                    }
                                  : (range) {
                                      setState(() {
                                        _yearRange = range;
                                      });
                                    },
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        // Still Using Toggle
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                'Still Using',
                                style: TextStyle(
                                  color: (isDark ? Colors.white : theme.colorScheme.onSurface).withOpacity(0.9),
                                  fontSize: 16,
                                ),
                              ),
                            ),
                            Switch(
                              value: _stillUsing,
                              onChanged: (value) {
                                setState(() {
                                  _stillUsing = value;
                                  if (value) {
                                    _yearRange = RangeValues(_yearRange.start, 2026);
                                  }
                                });
                              },
                              activeColor: isDark ? Colors.white : theme.colorScheme.primary,
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        // Note
                        TextField(
                          controller: _noteController,
                          focusNode: _noteFocusNode,
                          textInputAction: TextInputAction.done,
                          onSubmitted: (_) => FocusScope.of(context).unfocus(),
                          style: TextStyle(color: isDark ? Colors.white : theme.colorScheme.onSurface),
                          maxLines: 5,
                          decoration: InputDecoration(
                            hintText: "What makes this device special to you?",
                            hintMaxLines: 5,
                            hintStyle: TextStyle(
                              color: (isDark ? Colors.white : theme.colorScheme.onSurface).withOpacity(0.5),
                            ),
                            filled: true,
                            fillColor: (isDark ? Colors.white : Colors.black).withOpacity(0.06),
                            enabledBorder: UnderlineInputBorder(
                              borderSide: BorderSide(
                                color: (isDark ? Colors.grey[600]! : Colors.grey[300]!),
                              ),
                            ),
                            focusedBorder: UnderlineInputBorder(
                              borderSide: BorderSide(
                                color: theme.colorScheme.primary,
                                width: 1.5,
                              ),
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 16,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Minimalist Wrap of category icons (black/white/grey). Single-select only.
class _CategoryPickerStrip extends StatelessWidget {
  final IconData selectedIcon;
  final bool isDark;
  final Color primaryColor;
  final ValueChanged<IconData> onCategorySelected;

  const _CategoryPickerStrip({
    required this.selectedIcon,
    required this.isDark,
    required this.primaryColor,
    required this.onCategorySelected,
  });

  static const double _iconSize = 24;
  static const double _chipSize = 44;
  static const double _spacing = 8;

  @override
  Widget build(BuildContext context) {
    final base = isDark ? Colors.white : Colors.black;
    return Wrap(
      spacing: _spacing,
      runSpacing: _spacing,
      children: deviceCategories.map<Widget>((category) {
        // Use icon as unique identifier for exclusive selection
        final selected = category.icon == selectedIcon;
        // Capture the specific category icon in a local variable to avoid closure issues
        final categoryIcon = category.icon;
        return Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () {
              // Single-select: tapping updates selection with the specific icon
              // Each icon has its own closure with its own categoryIcon value
              onCategorySelected(categoryIcon);
            },
            borderRadius: BorderRadius.circular(_chipSize / 2),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              width: _chipSize,
              height: _chipSize,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: selected
                    ? primaryColor.withOpacity(0.15)
                    : base.withOpacity(0.06),
                border: Border.all(
                  color: selected ? primaryColor : Colors.transparent,
                  width: selected ? 2.5 : 0,
                ),
                boxShadow: selected
                    ? [
                        BoxShadow(
                          color: primaryColor.withOpacity(0.2),
                          blurRadius: 6,
                          spreadRadius: 0,
                        ),
                      ]
                    : null,
              ),
              alignment: Alignment.center,
              child: Icon(
                category.icon,
                size: _iconSize,
                color: selected
                    ? primaryColor
                    : base.withOpacity(0.5),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}
