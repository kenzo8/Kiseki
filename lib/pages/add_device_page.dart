import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/seki_model.dart';
import '../widgets/device_icon_selector.dart';
import '../services/auth_service.dart';
import '../services/profile_data_service.dart';
import '../pages/login_page.dart';

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
  bool _isPreciseMode = true;
  DateTime? _startDate;
  DateTime? _endDate;
  bool _isLoading = false;
  bool _showCategoryPicker = false;
  bool _isManualCategorySelection = false;
  late IconData _selectedIcon;
  final FocusNode _deviceNameFocusNode = FocusNode();
  final FocusNode _noteFocusNode = FocusNode();
  final GlobalKey _noteFieldKey = GlobalKey();
  String _previousNoteText = '';
  
  // Key for storing last selected device type
  static const String _lastDeviceTypeKey = 'last_device_type';
  
  // Track category color for bottom glow effect
  Color get _categoryColor => getCategoryColor(_deviceType);

  bool get isEditMode => widget.seki != null;

  @override
  void initState() {
    super.initState();
    
    // Initialize controllers and state from existing device if in edit mode
    if (isEditMode && widget.seki != null) {
      _nameController = TextEditingController(text: widget.seki!.deviceName);
      _noteController = TextEditingController(text: widget.seki!.note);
      _previousNoteText = widget.seki!.note;
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
      _previousNoteText = '';
      // Load last selected device type, default to 'Laptop'
      _deviceType = 'Laptop';
      // Use override if provided, otherwise use pre-filled or default
      _stillUsing = widget.overrideStillUsing ?? widget.preFilledStillUsing ?? false;
      _yearRange = const RangeValues(2020, 2026);
      _startDate = DateTime(2020, 1, 1);
      _endDate = _stillUsing ? null : DateTime(2026, 1, 1);
    }
    
    // Initialize selected icon from current deviceType
    _selectedIcon = deviceTypeToIcon(_deviceType);
    // In edit mode, treat loaded category as manually selected so it isn't overwritten by name suggestion
    if (isEditMode) _isManualCategorySelection = true;
    
    // Auto-focus the device name field when the page opens
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _deviceNameFocusNode.requestFocus();
      // Load last device type after widget is built
      if (!isEditMode) {
        _loadLastDeviceType();
      }
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
            _selectedIcon = deviceTypeToIcon(suggestedType);
          });
        }
      }
    }
    setState(() {});
  }

  void _onTextChanged() {
    final currentText = _noteController.text;
    // Check if a newline was added
    if (currentText.length > _previousNoteText.length) {
      final addedText = currentText.substring(_previousNoteText.length);
      if (addedText.contains('\n')) {
        // Newline detected, dismiss keyboard
        FocusScope.of(context).unfocus();
      }
    }
    _previousNoteText = currentText;
    setState(() {});
  }

  /// Load the last selected device type from SharedPreferences
  Future<void> _loadLastDeviceType() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final lastType = prefs.getString(_lastDeviceTypeKey);
      if (lastType != null && lastType.isNotEmpty) {
        setState(() {
          _deviceType = lastType;
          _selectedIcon = deviceTypeToIcon(lastType);
        });
      }
    } catch (e) {
      // If loading fails, keep default value
      debugPrint('Failed to load last device type: $e');
    }
  }

  /// Save the selected device type to SharedPreferences
  Future<void> _saveLastDeviceType(String deviceType) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_lastDeviceTypeKey, deviceType);
    } catch (e) {
      debugPrint('Failed to save last device type: $e');
    }
  }

  /// Shows a slide-style date picker (3 wheels: month, day, year).
  Future<DateTime?> _showSlideDatePicker({
    required DateTime initialDate,
    required DateTime firstDate,
    required DateTime lastDate,
  }) async {
    DateTime picked = initialDate;
    if (picked.isBefore(firstDate)) picked = firstDate;
    if (picked.isAfter(lastDate)) picked = lastDate;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return showModalBottomSheet<DateTime>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              decoration: BoxDecoration(
                color: isDark ? theme.colorScheme.surface : Colors.white,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.08),
                    blurRadius: 12,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              child: SafeArea(
                top: false,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(height: 12),
                    Center(
                      child: Container(
                        width: 36,
                        height: 4,
                        decoration: BoxDecoration(
                          color: (isDark ? Colors.white : theme.colorScheme.onSurface).withOpacity(0.2),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: Text(
                              'Cancel',
                              style: TextStyle(
                                color: isDark ? Colors.white70 : theme.colorScheme.onSurfaceVariant,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                          TextButton(
                            onPressed: () => Navigator.pop(context, picked),
                            style: TextButton.styleFrom(
                              backgroundColor: theme.colorScheme.primary,
                              foregroundColor: theme.colorScheme.onPrimary,
                              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(20),
                              ),
                            ),
                            child: const Text('OK'),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(
                      height: 220,
                      child: CupertinoTheme(
                        data: CupertinoThemeData(
                          brightness: theme.brightness,
                        ),
                        child: CupertinoDatePicker(
                          mode: CupertinoDatePickerMode.date,
                          initialDateTime: picked,
                          minimumDate: firstDate,
                          maximumDate: lastDate,
                          onDateTimeChanged: (DateTime value) {
                            picked = value;
                            setModalState(() {});
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _selectStartDate() async {
    final now = DateTime.now();
    final initial = _startDate ?? now;
    final clamped = initial.isAfter(now)
        ? now
        : (initial.isBefore(DateTime(2000)) ? DateTime(2000) : initial);
    final picked = await _showSlideDatePicker(
      initialDate: clamped,
      firstDate: DateTime(2000),
      lastDate: now,
    );
    if (picked != null) {
      setState(() {
        _startDate = picked;
        if (!_stillUsing) _endDate = picked;
        // Update year range for consistency
        _yearRange = RangeValues(
          picked.year.toDouble(),
          _stillUsing ? DateTime.now().year.toDouble() : (_endDate?.year.toDouble() ?? picked.year.toDouble()),
        );
      });
      if (!_stillUsing) {
        WidgetsBinding.instance.addPostFrameCallback((_) => _selectEndDate());
      }
    }
  }

  Future<void> _selectEndDate() async {
    final now = DateTime.now();
    final start = _startDate ?? DateTime(2000);
    final endDefault = _endDate ?? _startDate ?? now;
    DateTime initial = endDefault;
    if (initial.isBefore(start)) initial = start;
    if (initial.isAfter(now)) initial = now;
    final picked = await _showSlideDatePicker(
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

  String _getDeviceTypeForIcon(IconData icon) {
    // Map icon to device type using deviceCategories
    for (final category in deviceCategories) {
      if (category.icon == icon) {
        return category.deviceType;
      }
    }
    return 'Laptop'; // Default fallback
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
      // Focus and scroll to note field
      _noteFocusNode.requestFocus();
      // Use a post-frame callback to ensure the widget is built before scrolling
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final context = _noteFieldKey.currentContext;
        if (context != null) {
          Scrollable.ensureVisible(
            context,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
            alignment: 0.1, // Position near top of visible area
          );
        }
      });
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
        Navigator.pop(context); // Close the bottom sheet first
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => const LoginPage(),
          ),
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
      
      // Save the selected device type for next time
      await _saveLastDeviceType(_deviceType);
      
      // Ensure ProfileDataService is initialized to receive stream updates
      final currentUserId = FirebaseAuth.instance.currentUser?.uid;
      if (currentUserId != null) {
        ProfileDataService.instance.initialize(currentUserId);
      }
      
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        Navigator.pop(context, true); // Return true to indicate success
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
      
      // Save the selected device type for next time
      await _saveLastDeviceType(_deviceType);
      
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        Navigator.pop(context, true); // Return true to indicate success
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
        gradient: isDark 
            ? null 
            : const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFFF8FAFC), Color(0xFFEEF2F6)],
              ),
        color: isDark ? const Color(0xFF1A1F35) : null,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Stack(
        children: [
          DraggableScrollableSheet(
        initialChildSize: 0.9,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scrollController) {
          final mq = MediaQuery.of(context);
          return Padding(
            padding: EdgeInsets.only(
              bottom: mq.viewInsets.bottom + mq.padding.bottom,
            ),
            child: SingleChildScrollView(
              controller: scrollController,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Drag handle
                  Padding(
                    padding: const EdgeInsets.only(top: 10, bottom: 4),
                    child: Center(
                      child: Container(
                        width: 36,
                        height: 4,
                        decoration: BoxDecoration(
                          color: (isDark ? Colors.white : theme.colorScheme.onSurface).withOpacity(0.25),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                  ),
                  // Top Header
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                    child: Row(
                      children: [
                        // Cancel button
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          style: TextButton.styleFrom(
                            foregroundColor: (isDark ? Colors.white70 : theme.colorScheme.onSurfaceVariant),
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          ),
                          child: Text(
                            'Cancel',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
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
                                  isEditMode ? 'Edit Device' : 'Add Device',
                                  style: theme.textTheme.titleLarge?.copyWith(
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: -0.3,
                                  ) ?? TextStyle(
                                    color: isDark ? Colors.white : theme.colorScheme.onSurface,
                                    fontSize: 20,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                              if (!isEditMode)
                                Padding(
                                  padding: const EdgeInsets.only(top: 4),
                                  child: Center(
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          Icons.public_outlined,
                                          size: 12,
                                          color: (isDark ? Colors.white54 : theme.colorScheme.onSurfaceVariant).withOpacity(0.9),
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          'Public on Explore',
                                          textAlign: TextAlign.center,
                                          style: TextStyle(
                                            color: (isDark ? Colors.white54 : theme.colorScheme.onSurfaceVariant).withOpacity(0.9),
                                            fontSize: 12,
                                            fontWeight: FontWeight.w400,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                        // Submit button
                        TextButton(
                          onPressed: !_isLoading && isButtonEnabled ? _handleSubmit : null,
                          style: TextButton.styleFrom(
                            backgroundColor: isButtonEnabled
                                ? (isDark ? Colors.white : theme.colorScheme.primary)
                                : (isDark ? Colors.white12 : theme.colorScheme.surfaceContainerHighest),
                            foregroundColor: isButtonEnabled
                                ? (isDark ? theme.colorScheme.onPrimary : Colors.white)
                                : (isDark ? Colors.white38 : theme.colorScheme.onSurfaceVariant.withOpacity(0.5)),
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(24),
                            ),
                            elevation: isButtonEnabled ? 0 : null,
                          ),
                          child: _isLoading
                              ? SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      isButtonEnabled
                                          ? (isDark ? theme.colorScheme.onPrimary : Colors.white)
                                          : (isDark ? Colors.white38 : theme.colorScheme.onSurfaceVariant),
                                    ),
                                  ),
                                )
                              : Text(
                                  isEditMode ? 'Save' : 'Create',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    letterSpacing: 0.2,
                                  ),
                                ),
                        ),
                      ],
                    ),
                  ),
                  // Subtle divider
                  Divider(
                    height: 1,
                    thickness: 1,
                    color: (isDark ? Colors.white : Colors.black).withOpacity(0.06),
                  ),
                  // Content
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 24, 20, 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Device Name with integrated category suffixIcon
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              decoration: BoxDecoration(
                                color: isDark
                                    ? theme.colorScheme.surface.withOpacity(0.4)
                                    : Colors.white,
                                borderRadius: BorderRadius.circular(16),
                                boxShadow: isDark
                                    ? null
                                    : [
                                        BoxShadow(
                                          color: Colors.black.withOpacity(0.04),
                                          blurRadius: 6,
                                          offset: const Offset(0, 1),
                                        ),
                                      ],
                              ),
                              child: TextField(
                                controller: _nameController,
                                focusNode: _deviceNameFocusNode,
                                textInputAction: TextInputAction.next,
                                maxLength: 80,
                                onSubmitted: (_) {
                                  FocusScope.of(context).requestFocus(_noteFocusNode);
                                  WidgetsBinding.instance.addPostFrameCallback((_) {
                                    final ctx = _noteFieldKey.currentContext;
                                    if (ctx != null) {
                                      Scrollable.ensureVisible(
                                        ctx,
                                        duration: const Duration(milliseconds: 300),
                                        curve: Curves.easeInOut,
                                        alignment: 0.1,
                                      );
                                    }
                                  });
                                },
                                style: TextStyle(color: isDark ? Colors.white : theme.colorScheme.onSurface),
                                decoration: InputDecoration(
                                  labelText: 'Device Name',
                                  labelStyle: TextStyle(
                                    color: (isDark ? Colors.white : theme.colorScheme.onSurface).withOpacity(0.7),
                                  ),
                                  hintText: getHintForDeviceType(_deviceType),
                                  hintStyle: TextStyle(
                                    color: (isDark ? Colors.white : theme.colorScheme.onSurface).withOpacity(0.5),
                                  ),
                                  alignLabelWithHint: true,
                                  prefixIcon: InkWell(
                                    onTap: () {
                                      setState(() => _showCategoryPicker = !_showCategoryPicker);
                                    },
                                    borderRadius: BorderRadius.circular(24),
                                    child: Padding(
                                      padding: const EdgeInsets.only(left: 16, right: 12),
                                      child: Icon(
                                        _selectedIcon,
                                        size: 24,
                                        color: (isDark ? Colors.white : _categoryColor).withOpacity(0.8),
                                      ),
                                    ),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(16),
                                    borderSide: BorderSide(
                                      color: (isDark ? Colors.grey[600]! : Colors.grey[300]!),
                                      width: 1,
                                    ),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(16),
                                    borderSide: BorderSide(
                                      color: _categoryColor,
                                      width: 2,
                                    ),
                                  ),
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 16,
                                  ),
                                  counterText: '',
                                  suffixIcon: InkWell(
                                    onTap: () {
                                      setState(() => _showCategoryPicker = !_showCategoryPicker);
                                    },
                                    borderRadius: BorderRadius.circular(24),
                                    child: Padding(
                                      padding: const EdgeInsets.all(12),
                                      child: Icon(
                                        Icons.arrow_drop_down_rounded,
                                        size: 24,
                                        color: (isDark ? Colors.white : theme.colorScheme.onSurface).withOpacity(0.6),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            if (_showCategoryPicker) ...[
                              const SizedBox(height: 14),
                              Row(
                                children: [
                                  Text(
                                    'Category',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: (isDark ? Colors.white70 : theme.colorScheme.onSurfaceVariant).withOpacity(0.9),
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              _CategoryPickerStrip(
                                selectedIcon: _selectedIcon,
                                isDark: isDark,
                                onCategorySelected: (selectedIcon) {
                                  final deviceType = _getDeviceTypeForIcon(selectedIcon);
                                  setState(() {
                                    _isManualCategorySelection = true;
                                    _showCategoryPicker = false;
                                    _selectedIcon = selectedIcon;
                                    _deviceType = deviceType;
                                  });
                                },
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 36),
                        // Construction Time Section
                        Container(
                          decoration: BoxDecoration(
                            color: isDark
                                ? theme.colorScheme.surface.withOpacity(0.5)
                                : Colors.white,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: (isDark ? Colors.white : Colors.black).withOpacity(0.06),
                              width: 1,
                            ),
                            boxShadow: isDark
                                ? null
                                : [
                                    BoxShadow(
                                      color: _categoryColor.withOpacity(0.03),
                                      blurRadius: 8,
                                      offset: const Offset(0, 2),
                                    ),
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.03),
                                      blurRadius: 4,
                                      offset: const Offset(0, 1),
                                    ),
                                  ],
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(20),
                            child: Stack(
                              children: [
                                // Left accent strip
                                Positioned(
                                  left: 0,
                                  top: 0,
                                  bottom: 0,
                                  child: Container(
                                    width: 4,
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        begin: Alignment.topCenter,
                                        end: Alignment.bottomCenter,
                                        colors: [
                                          _categoryColor.withOpacity(0.5),
                                          _categoryColor.withOpacity(0.15),
                                        ],
                                      ),
                                      borderRadius: const BorderRadius.horizontal(right: Radius.circular(2)),
                                    ),
                                  ),
                                ),
                                // Clock icon background - subtle
                                Positioned(
                                  top: 12,
                                  right: 12,
                                  child: Icon(
                                    Icons.schedule_rounded,
                                    size: 40,
                                    color: _categoryColor.withOpacity(0.08),
                                  ),
                                ),
                                // Content
                                Padding(
                                  padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      // Label
                                      Row(
                                        children: [
                                          Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(
                                                Icons.schedule_rounded,
                                                size: 14,
                                                color: (isDark ? Colors.white70 : theme.colorScheme.onSurfaceVariant).withOpacity(0.9),
                                              ),
                                              const SizedBox(width: 6),
                                              Text(
                                                'TIME',
                                                style: TextStyle(
                                                  color: (isDark ? Colors.white70 : theme.colorScheme.onSurfaceVariant).withOpacity(0.95),
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.w700,
                                                  letterSpacing: 1,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    const SizedBox(height: 14),
                                    // Animated transition between Year Range Slider and Date Range UI
                                    AnimatedCrossFade(
                                      duration: const Duration(milliseconds: 300),
                                      crossFadeState: _isPreciseMode
                                          ? CrossFadeState.showSecond
                                          : CrossFadeState.showFirst,
                                      firstChild: // Period (Year Range)
                                      Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Text(
                                                'Period',
                                                style: TextStyle(
                                                  color: (isDark ? Colors.white : theme.colorScheme.onSurface).withOpacity(0.9),
                                                  fontSize: 16,
                                                  fontWeight: FontWeight.w500,
                                                ),
                                              ),
                                              const Spacer(),
                                              SizedBox(
                                                width: 112,
                                                child: InkWell(
                                                  onTap: () {
                                                    setState(() {
                                                      _isPreciseMode = !_isPreciseMode;
                                                      if (_isPreciseMode) {
                                                        _startDate ??= DateTime(_yearRange.start.toInt(), 1, 1);
                                                        if (!_stillUsing && _endDate == null) {
                                                          _endDate = DateTime(_yearRange.end.toInt(), 12, 31);
                                                        }
                                                      } else {
                                                        if (_startDate != null) {
                                                          _yearRange = RangeValues(
                                                            _startDate!.year.toDouble(),
                                                            _stillUsing ? DateTime.now().year.toDouble() : (_endDate?.year.toDouble() ?? DateTime.now().year.toDouble()),
                                                          );
                                                        }
                                                      }
                                                    });
                                                  },
                                                  borderRadius: BorderRadius.circular(8),
                                                  child: Padding(
                                                    padding: const EdgeInsets.symmetric(vertical: 4),
                                                    child: Row(
                                                      mainAxisAlignment: MainAxisAlignment.end,
                                                      mainAxisSize: MainAxisSize.min,
                                                      children: [
                                                        Text(
                                                          'Years Only',
                                                          style: TextStyle(
                                                            color: (isDark ? Colors.white : theme.colorScheme.onSurface).withOpacity(0.8),
                                                            fontSize: 13,
                                                          ),
                                                        ),
                                                        const SizedBox(width: 8),
                                                        SizedBox(
                                                          width: 20,
                                                          height: 20,
                                                          child: Checkbox(
                                                            value: !_isPreciseMode,
                                                            onChanged: (value) {
                                                              setState(() {
                                                                _isPreciseMode = !(value ?? false);
                                                                if (_isPreciseMode) {
                                                                  _startDate ??= DateTime(_yearRange.start.toInt(), 1, 1);
                                                                  if (!_stillUsing && _endDate == null) {
                                                                    _endDate = DateTime(_yearRange.end.toInt(), 12, 31);
                                                                  }
                                                                } else {
                                                                  if (_startDate != null) {
                                                                    _yearRange = RangeValues(
                                                                      _startDate!.year.toDouble(),
                                                                      _stillUsing ? DateTime.now().year.toDouble() : (_endDate?.year.toDouble() ?? DateTime.now().year.toDouble()),
                                                                    );
                                                                  }
                                                                }
                                                              });
                                                            },
                                                            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                                            activeColor: isDark ? Colors.white70 : theme.colorScheme.primary,
                                                            fillColor: WidgetStateProperty.resolveWith<Color>((states) {
                                                              if (states.contains(WidgetState.selected)) {
                                                                return (isDark ? Colors.white70 : theme.colorScheme.primary).withOpacity(0.2);
                                                              }
                                                              return Colors.transparent;
                                                            }),
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 6),
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
                                          const SizedBox(height: 4),
                                          Align(
                                            alignment: Alignment.center,
                                            child: Text(
                                              _stillUsing
                                                  ? '${_yearRange.start.toInt()} - Present'
                                                  : '${_yearRange.start.toInt()} - ${_yearRange.end.toInt()}',
                                              style: TextStyle(
                                                color: (isDark ? Colors.white : theme.colorScheme.onSurface).withOpacity(0.7),
                                                fontSize: 14,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      secondChild: // Date Range UI (Period)
                                      Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Text(
                                                'Period',
                                                style: TextStyle(
                                                  color: (isDark ? Colors.white : theme.colorScheme.onSurface).withOpacity(0.9),
                                                  fontSize: 16,
                                                  fontWeight: FontWeight.w500,
                                                ),
                                              ),
                                              const Spacer(),
                                              SizedBox(
                                                width: 112,
                                                child: InkWell(
                                                  onTap: () {
                                                    setState(() {
                                                      _isPreciseMode = !_isPreciseMode;
                                                      if (_isPreciseMode) {
                                                        _startDate ??= DateTime(_yearRange.start.toInt(), 1, 1);
                                                        if (!_stillUsing && _endDate == null) {
                                                          _endDate = DateTime(_yearRange.end.toInt(), 12, 31);
                                                        }
                                                      } else {
                                                        if (_startDate != null) {
                                                          _yearRange = RangeValues(
                                                            _startDate!.year.toDouble(),
                                                            _stillUsing ? DateTime.now().year.toDouble() : (_endDate?.year.toDouble() ?? DateTime.now().year.toDouble()),
                                                          );
                                                        }
                                                      }
                                                    });
                                                  },
                                                  borderRadius: BorderRadius.circular(8),
                                                  child: Padding(
                                                    padding: const EdgeInsets.symmetric(vertical: 4),
                                                    child: Row(
                                                      mainAxisAlignment: MainAxisAlignment.end,
                                                      mainAxisSize: MainAxisSize.min,
                                                      children: [
                                                        Text(
                                                          'Years Only',
                                                          style: TextStyle(
                                                            color: (isDark ? Colors.white : theme.colorScheme.onSurface).withOpacity(0.8),
                                                            fontSize: 13,
                                                          ),
                                                        ),
                                                        const SizedBox(width: 8),
                                                        SizedBox(
                                                          width: 20,
                                                          height: 20,
                                                          child: Checkbox(
                                                            value: !_isPreciseMode,
                                                            onChanged: (value) {
                                                              setState(() {
                                                                _isPreciseMode = !(value ?? false);
                                                                if (_isPreciseMode) {
                                                                  _startDate ??= DateTime(_yearRange.start.toInt(), 1, 1);
                                                                  if (!_stillUsing && _endDate == null) {
                                                                    _endDate = DateTime(_yearRange.end.toInt(), 12, 31);
                                                                  }
                                                                } else {
                                                                  if (_startDate != null) {
                                                                    _yearRange = RangeValues(
                                                                      _startDate!.year.toDouble(),
                                                                      _stillUsing ? DateTime.now().year.toDouble() : (_endDate?.year.toDouble() ?? DateTime.now().year.toDouble()),
                                                                    );
                                                                  }
                                                                }
                                                              });
                                                            },
                                                            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                                            activeColor: isDark ? Colors.white70 : theme.colorScheme.primary,
                                                            fillColor: WidgetStateProperty.resolveWith<Color>((states) {
                                                              if (states.contains(WidgetState.selected)) {
                                                                return (isDark ? Colors.white70 : theme.colorScheme.primary).withOpacity(0.2);
                                                              }
                                                              return Colors.transparent;
                                                            }),
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 8),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                            decoration: BoxDecoration(
                                              color: isDark ? theme.colorScheme.surfaceContainerHighest : Colors.white,
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
                                                  child: Material(
                                                    color: isDark ? theme.colorScheme.surface : Colors.white,
                                                    borderRadius: BorderRadius.circular(8),
                                                    child: InkWell(
                                                      onTap: _selectStartDate,
                                                      borderRadius: BorderRadius.circular(8),
                                                      child: Container(
                                                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                                        decoration: BoxDecoration(
                                                          borderRadius: BorderRadius.circular(8),
                                                          border: Border.all(
                                                            color: (isDark ? Colors.white : theme.colorScheme.onSurface).withOpacity(0.2),
                                                            width: 1,
                                                          ),
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
                                                          overflow: TextOverflow.ellipsis,
                                                        ),
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
                                                  child: Material(
                                                    color: _stillUsing
                                                        ? Colors.transparent
                                                        : (isDark ? theme.colorScheme.surface : Colors.white),
                                                    borderRadius: BorderRadius.circular(8),
                                                    child: InkWell(
                                                      onTap: _stillUsing ? null : _selectEndDate,
                                                      borderRadius: BorderRadius.circular(8),
                                                      child: Container(
                                                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                                        decoration: BoxDecoration(
                                                          borderRadius: BorderRadius.circular(8),
                                                          border: Border.all(
                                                            color: (_stillUsing
                                                                    ? (isDark ? Colors.white : theme.colorScheme.onSurface).withOpacity(0.15)
                                                                    : (isDark ? Colors.white : theme.colorScheme.onSurface).withOpacity(0.2)),
                                                            width: 1,
                                                          ),
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
                                                          overflow: TextOverflow.ellipsis,
                                                        ),
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
                                    const SizedBox(height: 14),
                                    // In Use Toggle
                                    InkWell(
                                      onTap: () {
                                        setState(() {
                                          _stillUsing = !_stillUsing;
                                          if (_stillUsing) {
                                            if (_isPreciseMode) {
                                              _endDate = null;
                                            } else {
                                              _yearRange = RangeValues(_yearRange.start, DateTime.now().year.toDouble());
                                            }
                                          } else {
                                            if (_isPreciseMode && _endDate == null) _endDate = DateTime.now();
                                          }
                                        });
                                      },
                                      borderRadius: BorderRadius.circular(8),
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(vertical: 4),
                                        child: Row(
                                          children: [
                                            Expanded(
                                              child: Text(
                                                'In Use',
                                                style: TextStyle(
                                                  color: (isDark ? Colors.white : theme.colorScheme.onSurface).withOpacity(0.9),
                                                  fontSize: 16,
                                                ),
                                              ),
                                            ),
                                            SizedBox(
                                              width: 112,
                                              child: Row(
                                                mainAxisAlignment: MainAxisAlignment.end,
                                                children: [
                                                  SizedBox(
                                                    width: 20,
                                                    height: 20,
                                                    child: Checkbox(
                                                value: _stillUsing,
                                                onChanged: (value) {
                                                  setState(() {
                                                    _stillUsing = value ?? false;
                                                    if (_stillUsing) {
                                                      if (_isPreciseMode) {
                                                        _endDate = null;
                                                      } else {
                                                        _yearRange = RangeValues(_yearRange.start, DateTime.now().year.toDouble());
                                                      }
                                                    } else {
                                                      if (_isPreciseMode && _endDate == null) _endDate = DateTime.now();
                                                    }
                                                  });
                                                },
                                                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                                activeColor: isDark ? Colors.white70 : theme.colorScheme.primary,
                                                fillColor: WidgetStateProperty.resolveWith<Color>((states) {
                                                  if (states.contains(WidgetState.selected)) {
                                                    return (isDark ? Colors.white70 : theme.colorScheme.primary).withOpacity(0.2);
                                                  }
                                                  return Colors.transparent;
                                                }),
                                              ),
                                            ),
                                                ],
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        ),
                        const SizedBox(height: 22),
                        // Note
                        GestureDetector(
                          onTap: () {
                            _noteFocusNode.requestFocus();
                          },
                          child: Container(
                            decoration: BoxDecoration(
                              color: isDark
                                  ? theme.colorScheme.surface.withOpacity(0.5)
                                  : Colors.white,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: (isDark ? Colors.white : Colors.black).withOpacity(0.06),
                                width: 1,
                              ),
                              boxShadow: isDark
                                  ? null
                                  : [
                                      BoxShadow(
                                        color: _categoryColor.withOpacity(0.03),
                                        blurRadius: 8,
                                        offset: const Offset(0, 2),
                                      ),
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.03),
                                        blurRadius: 4,
                                        offset: const Offset(0, 1),
                                      ),
                                    ],
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(20),
                              child: Stack(
                                children: [
                                  // Left accent strip
                                  Positioned(
                                    left: 0,
                                    top: 0,
                                    bottom: 0,
                                    child: Container(
                                      width: 4,
                                      decoration: BoxDecoration(
                                        gradient: LinearGradient(
                                          begin: Alignment.topCenter,
                                          end: Alignment.bottomCenter,
                                          colors: [
                                            _categoryColor.withOpacity(0.5),
                                            _categoryColor.withOpacity(0.15),
                                          ],
                                        ),
                                        borderRadius: const BorderRadius.horizontal(right: Radius.circular(2)),
                                      ),
                                    ),
                                  ),
                                  // Quote icon background - subtle
                                  Positioned(
                                    top: 12,
                                    right: 12,
                                    child: Icon(
                                      Icons.format_quote_rounded,
                                      size: 40,
                                      color: _categoryColor.withOpacity(0.08),
                                    ),
                                  ),
                                  // Content
                                  Padding(
                                    padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        // Label
                                        Row(
                                          children: [
                                            Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Icon(
                                                  Icons.rate_review_rounded,
                                                  size: 14,
                                                  color: (isDark ? Colors.white70 : theme.colorScheme.onSurfaceVariant).withOpacity(0.9),
                                                ),
                                                const SizedBox(width: 6),
                                                Text(
                                                  'IMPRESSION',
                                                  style: TextStyle(
                                                    color: (isDark ? Colors.white70 : theme.colorScheme.onSurfaceVariant).withOpacity(0.95),
                                                    fontSize: 11,
                                                    fontWeight: FontWeight.w700,
                                                    letterSpacing: 1,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      const SizedBox(height: 12),
                                      // TextField
                                      TextField(
                                        key: _noteFieldKey,
                                        controller: _noteController,
                                        focusNode: _noteFocusNode,
                                        textInputAction: TextInputAction.newline,
                                        keyboardType: TextInputType.multiline,
                                        style: TextStyle(
                                          color: isDark ? Colors.white : theme.colorScheme.onSurface,
                                          fontSize: 15,
                                          height: 1.6,
                                          fontWeight: FontWeight.w400,
                                        ),
                                        maxLines: 5,
                                        minLines: 1,
                                        maxLength: 800,
                                        decoration: InputDecoration(
                                          hintText: "What makes this device special to you?",
                                          hintMaxLines: 5,
                                          hintStyle: TextStyle(
                                            color: (isDark ? Colors.white : theme.colorScheme.onSurface).withOpacity(0.5),
                                            fontSize: 15,
                                            height: 1.6,
                                          ),
                                          prefixIcon: Padding(
                                            padding: const EdgeInsets.only(left: 0, right: 6, top: 2),
                                            child: Icon(
                                              Icons.format_quote,
                                              size: 18,
                                              color: _categoryColor.withOpacity(0.4),
                                            ),
                                          ),
                                          prefixIconConstraints: const BoxConstraints(
                                            minWidth: 24,
                                            minHeight: 24,
                                          ),
                                          enabledBorder: InputBorder.none,
                                          focusedBorder: InputBorder.none,
                                          border: InputBorder.none,
                                          contentPadding: const EdgeInsets.symmetric(
                                            horizontal: 12,
                                            vertical: 12,
                                          ),
                                          counterStyle: TextStyle(
                                            fontSize: 12,
                                            color: (isDark ? Colors.white : theme.colorScheme.onSurface).withOpacity(0.5),
                                          ),
                                        ),
                                      ),
                                    ],
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
                ],
              ),
            ),
          );
        },
      ),
        ],
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
  static const double _labelFontSize = 10;

  /// Max height for the icon strip when scrollable (>10 categories).
  static const double _maxHeight = 140;

  @override
  Widget build(BuildContext context) {
    final base = isDark ? Colors.white : Colors.black;
    final useScroll = deviceCategories.length > 10;
    
    return LayoutBuilder(
      builder: (context, constraints) {
        // Calculate width for 6 icons per row
        // 6 icons + 5 spacings between them
        final availableWidth = constraints.maxWidth;
        final totalSpacing = 5 * _spacing; // 5 spacings for 6 items
        final itemWidth = ((availableWidth - totalSpacing) / 6).clamp(_chipSize * 0.8, double.infinity);
        
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
              width: itemWidth,
              height: _chipSize + 28, // Fixed height: icon (24) + spacing (4) + 2 lines of text (~20)
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
              decoration: BoxDecoration(
                shape: BoxShape.rectangle,
                borderRadius: BorderRadius.circular(12),
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
                          color: categoryColor.withOpacity(0.12),
                          blurRadius: 4,
                          spreadRadius: 0,
                        ),
                      ]
                    : null,
              ),
              alignment: Alignment.center,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    category.icon,
                    size: _iconSize,
                    color: selected
                        ? categoryColor
                        : base.withOpacity(0.5),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    category.label,
                    style: TextStyle(
                      fontSize: _labelFontSize,
                      color: selected
                          ? categoryColor
                          : base.withOpacity(0.6),
                      fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                      height: 1.2,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    softWrap: true,
                    overflow: TextOverflow.visible,
                  ),
                ],
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
      },
    );
  }
}
