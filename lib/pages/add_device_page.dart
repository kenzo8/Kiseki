import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../models/seki_model.dart';
import '../widgets/device_icon_selector.dart';
import '../widgets/seki_card.dart';
import '../services/auth_service.dart';
import '../services/profile_data_service.dart';

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
  bool _isPreciseMode = false;
  DateTime? _startDate;
  DateTime? _endDate;
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
      _isPreciseMode = widget.seki!.isPreciseMode;
      // Use override if provided, otherwise use saved value
      _stillUsing = widget.overrideStillUsing ?? (widget.seki!.endYear == null && widget.seki!.endTime == null);
      
      if (_isPreciseMode && widget.seki!.startTime != null) {
        // Load precise dates
        _startDate = widget.seki!.startTime!.toDate();
        _endDate = widget.seki!.endTime?.toDate();
        // Also set year range for fallback display
        _yearRange = RangeValues(
          widget.seki!.startYear.toDouble(),
          _stillUsing ? DateTime.now().year.toDouble() : (widget.seki!.endYear?.toDouble() ?? DateTime.now().year.toDouble()),
        );
      } else {
        // Load year range
        _yearRange = RangeValues(
          widget.seki!.startYear.toDouble(),
          _stillUsing ? DateTime.now().year.toDouble() : (widget.seki!.endYear?.toDouble() ?? DateTime.now().year.toDouble()),
        );
        // Initialize dates from years for precise mode switch
        _startDate = DateTime(widget.seki!.startYear, 1, 1);
        _endDate = widget.seki!.endYear != null ? DateTime(widget.seki!.endYear!, 12, 31) : null;
      }
    } else {
      // Initialize with default values for add mode, or use pre-filled values
      _nameController = TextEditingController(text: widget.preFilledDeviceName ?? '');
      _noteController = TextEditingController();
      _deviceType = 'Laptop';
      // Use override if provided, otherwise use pre-filled or default
      _stillUsing = widget.overrideStillUsing ?? widget.preFilledStillUsing ?? false;
      _yearRange = const RangeValues(2020, 2026);
      _startDate = DateTime(2020, 1, 1);
      _endDate = _stillUsing ? null : DateTime(2026, 1, 1);
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

  Future<void> _selectStartDate() async {
    final now = DateTime.now();
    final initial = _startDate ?? now;
    final clamped = initial.isAfter(now)
        ? now
        : (initial.isBefore(DateTime(2000)) ? DateTime(2000) : initial);
    final picked = await showDatePicker(
      context: context,
      initialDate: clamped,
      firstDate: DateTime(2000),
      lastDate: now,
    );
    if (picked != null) {
      setState(() {
        _startDate = picked;
        // Update year range for consistency
        _yearRange = RangeValues(
          picked.year.toDouble(),
          _stillUsing ? DateTime.now().year.toDouble() : (_endDate?.year.toDouble() ?? picked.year.toDouble()),
        );
      });
    }
  }

  Future<void> _selectEndDate() async {
    final now = DateTime.now();
    final start = _startDate ?? DateTime(2000);
    final endDefault = _endDate ?? now;
    DateTime initial = endDefault;
    if (initial.isBefore(start)) initial = start;
    if (initial.isAfter(now)) initial = now;
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: start,
      lastDate: now,
    );
    if (picked != null) {
      setState(() {
        _endDate = picked;
        // Update year range for consistency
        _yearRange = RangeValues(
          _startDate?.year.toDouble() ?? 2010,
          picked.year.toDouble(),
        );
      });
    }
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
    return 'Laptop'; // Default fallback
  }

  String _getHintForDeviceType(String deviceType) {
    // Map device type to appropriate hint text
    switch (deviceType) {
      case 'Mobile':
        return 'e.g., iPhone 15 Pro';
      case 'Tablet':
        return 'e.g., iPad Pro 12.9"';
      case 'Laptop':
        return 'e.g., MacBook Pro M1';
      case 'Desktop':
        return 'e.g., iMac 24"';
      case 'Watch':
        return 'e.g., Apple Watch Series 9';
      case 'Earbuds':
        return 'e.g., AirPods Pro 2';
      case 'Headphones':
        return 'e.g., Sony WH-1000XM5';
      case 'Camera':
        return 'e.g., Canon EOS R5';
      case 'Gaming':
        return 'e.g., PlayStation 5';
      case 'Accessory':
        return 'e.g., Magic Keyboard';
      case 'Smart Home':
        return 'e.g., HomePod mini';
      case 'VR/AR':
        return 'e.g., Apple Vision Pro';
      case 'Gaming Peripherals':
        return 'e.g., Logitech MX Master 3';
      case 'Drone':
        return 'e.g., DJI Mavic 3';
      case 'e-Reader':
        return 'e.g., Kindle Paperwhite';
      default:
        return 'e.g., MacBook Pro M1';
    }
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

      final Map<String, dynamic> deviceData = {
        'uid': uid,
        'username': username,
        'deviceName': _nameController.text.trim(),
        'deviceType': _deviceType,
        'isPreciseMode': _isPreciseMode,
        'createdAt': FieldValue.serverTimestamp(),
        'note': _noteController.text.trim(),
      };

      if (_isPreciseMode) {
        // Save timestamps for precise mode
        deviceData['startTime'] = Timestamp.fromDate(_startDate ?? DateTime.now());
        if (!_stillUsing && _endDate != null) {
          deviceData['endTime'] = Timestamp.fromDate(_endDate!);
        } else {
          deviceData['endTime'] = null;
        }
        // Also save years for backward compatibility
        deviceData['startYear'] = (_startDate ?? DateTime.now()).year;
        if (!_stillUsing && _endDate != null) {
          deviceData['endYear'] = _endDate!.year;
        } else {
          deviceData['endYear'] = null;
        }
      } else {
        // Save years for non-precise mode
        deviceData['startYear'] = _yearRange.start.toInt();
        if (!_stillUsing) {
          deviceData['endYear'] = _yearRange.end.toInt();
        } else {
          deviceData['endYear'] = null;
        }
      }

      await FirebaseFirestore.instance.collection('seki').add(deviceData);
      
      // Ensure ProfileDataService is initialized to receive stream updates
      final currentUserId = FirebaseAuth.instance.currentUser?.uid;
      if (currentUserId != null) {
        ProfileDataService.instance.initialize(currentUserId);
      }
      
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
      final Map<String, dynamic> updateData = {
        'deviceName': _nameController.text.trim(),
        'deviceType': _deviceType,
        'isPreciseMode': _isPreciseMode,
        'note': _noteController.text.trim(),
      };

      if (_isPreciseMode) {
        // Update timestamps for precise mode
        updateData['startTime'] = Timestamp.fromDate(_startDate ?? DateTime.now());
        if (!_stillUsing && _endDate != null) {
          updateData['endTime'] = Timestamp.fromDate(_endDate!);
        } else {
          updateData['endTime'] = null;
        }
        // Also update years for backward compatibility
        updateData['startYear'] = (_startDate ?? DateTime.now()).year;
        if (!_stillUsing && _endDate != null) {
          updateData['endYear'] = _endDate!.year;
        } else {
          updateData['endYear'] = null;
        }
      } else {
        // Update years for non-precise mode
        updateData['startYear'] = _yearRange.start.toInt();
        if (!_stillUsing) {
          updateData['endYear'] = _yearRange.end.toInt();
        } else {
          updateData['endYear'] = null;
        }
      }

      await FirebaseFirestore.instance.collection('seki').doc(widget.seki!.id).update(updateData);
      
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
                                hintText: _getHintForDeviceType(_deviceType),
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
                        // Precise Mode Toggle
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                'Precise Mode',
                                style: TextStyle(
                                  color: (isDark ? Colors.white : theme.colorScheme.onSurface).withOpacity(0.9),
                                  fontSize: 16,
                                ),
                              ),
                            ),
                            Switch(
                              value: _isPreciseMode,
                              onChanged: (value) {
                                setState(() {
                                  _isPreciseMode = value;
                                  if (value) {
                                    // When enabling precise mode, initialize dates from year range
                                    if (_startDate == null) {
                                      _startDate = DateTime(_yearRange.start.toInt(), 1, 1);
                                    }
                                    if (!_stillUsing && _endDate == null) {
                                      _endDate = DateTime(_yearRange.end.toInt(), 12, 31);
                                    }
                                  } else {
                                    // When disabling precise mode, sync year range from dates
                                    if (_startDate != null) {
                                      _yearRange = RangeValues(
                                        _startDate!.year.toDouble(),
                                        _stillUsing ? DateTime.now().year.toDouble() : (_endDate?.year.toDouble() ?? DateTime.now().year.toDouble()),
                                      );
                                    }
                                  }
                                });
                              },
                              activeColor: isDark ? Colors.white : theme.colorScheme.primary,
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        // Animated transition between Year Range Slider and Date Range UI
                        AnimatedCrossFade(
                          duration: const Duration(milliseconds: 300),
                          crossFadeState: _isPreciseMode
                              ? CrossFadeState.showSecond
                              : CrossFadeState.showFirst,
                          firstChild: // Year Range Slider
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
                                max: DateTime.now().year.toDouble(),
                                divisions: DateTime.now().year - 2010,
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
                                          _yearRange = RangeValues(range.start, DateTime.now().year.toDouble());
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
                          secondChild: // Date Range UI
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Date Range',
                                style: TextStyle(
                                  color: (isDark ? Colors.white : theme.colorScheme.onSurface).withOpacity(0.9),
                                  fontSize: 16,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(height: 12),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                decoration: BoxDecoration(
                                  color: (isDark ? Colors.white : Colors.black).withOpacity(0.06),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Row(
                                  children: [
                                    // Calendar Icon Prefix
                                    Icon(
                                      Icons.calendar_today,
                                      size: 20,
                                      color: (isDark ? Colors.white : theme.colorScheme.onSurface).withOpacity(0.7),
                                    ),
                                    const SizedBox(width: 12),
                                    // Start Date Button
                                    Expanded(
                                      child: InkWell(
                                        onTap: _selectStartDate,
                                        borderRadius: BorderRadius.circular(8),
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                          decoration: BoxDecoration(
                                            color: (isDark ? Colors.white : Colors.black).withOpacity(0.04),
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          child: Text(
                                            _startDate != null
                                                ? '${_startDate!.year}/${_startDate!.month}/${_startDate!.day}'
                                                : 'Start Date',
                                            style: TextStyle(
                                              color: (isDark ? Colors.white : theme.colorScheme.onSurface),
                                              fontSize: 14,
                                            ),
                                            textAlign: TextAlign.center,
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    // Separator
                                    Icon(
                                      Icons.arrow_forward,
                                      size: 18,
                                      color: (isDark ? Colors.white : theme.colorScheme.onSurface).withOpacity(0.5),
                                    ),
                                    const SizedBox(width: 12),
                                    // End Date Button
                                    Expanded(
                                      child: InkWell(
                                        onTap: _stillUsing ? null : _selectEndDate,
                                        borderRadius: BorderRadius.circular(8),
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                          decoration: BoxDecoration(
                                            color: _stillUsing
                                                ? Colors.transparent
                                                : (isDark ? Colors.white : Colors.black).withOpacity(0.04),
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          child: Text(
                                            _stillUsing
                                                ? 'Present'
                                                : (_endDate != null
                                                    ? '${_endDate!.year}/${_endDate!.month}/${_endDate!.day}'
                                                    : 'End Date'),
                                            style: TextStyle(
                                              color: _stillUsing
                                                  ? (isDark ? Colors.white : theme.colorScheme.onSurface).withOpacity(0.5)
                                                  : (isDark ? Colors.white : theme.colorScheme.onSurface),
                                              fontSize: 14,
                                            ),
                                            textAlign: TextAlign.center,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
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
                                    if (_isPreciseMode) {
                                      _endDate = null;
                                    } else {
                                      _yearRange = RangeValues(_yearRange.start, DateTime.now().year.toDouble());
                                    }
                                  } else {
                                    if (_isPreciseMode && _endDate == null) {
                                      _endDate = DateTime.now();
                                    }
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

/// Minimalist Wrap of category icons with category-specific colors. Single-select only.
class _CategoryPickerStrip extends StatelessWidget {
  final IconData selectedIcon;
  final bool isDark;
  final ValueChanged<IconData> onCategorySelected;

  const _CategoryPickerStrip({
    required this.selectedIcon,
    required this.isDark,
    required this.onCategorySelected,
  });

  static const double _iconSize = 24;
  static const double _chipSize = 44;
  static const double _spacing = 8;

  /// Max height for the icon strip when scrollable (>10 categories).
  static const double _maxHeight = 140;

  @override
  Widget build(BuildContext context) {
    final base = isDark ? Colors.white : Colors.black;
    final useScroll = deviceCategories.length > 10;
    final wrap = Wrap(
      spacing: _spacing,
      runSpacing: _spacing,
      children: deviceCategories.map<Widget>((category) {
        // Use icon as unique identifier for exclusive selection
        final selected = category.icon == selectedIcon;
        // Get category-specific color from map
        final categoryColor = getCategoryColor(category.deviceType);
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
                    ? categoryColor.withOpacity(0.15)
                    : base.withOpacity(0.06),
                border: Border.all(
                  color: selected ? categoryColor : Colors.transparent,
                  width: selected ? 2.5 : 0,
                ),
                boxShadow: selected
                    ? [
                        BoxShadow(
                          color: categoryColor.withOpacity(0.2),
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
                    ? categoryColor
                    : base.withOpacity(0.5),
              ),
            ),
          ),
        );
      }).toList(),
    );
    if (useScroll) {
      return ConstrainedBox(
        constraints: const BoxConstraints(maxHeight: _maxHeight),
        child: SingleChildScrollView(
          child: wrap,
        ),
      );
    }
    return wrap;
  }
}
