import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'firebase_options.dart';
import 'pages/login_page.dart';
import 'pages/explore_page.dart';
import 'pages/circle_page.dart';
import 'pages/inbox_page.dart';
import 'pages/profile_page.dart';
import 'services/auth_service.dart';
import 'services/theme_preference_service.dart';
import 'widgets/seki_card.dart';
import 'widgets/device_icon_selector.dart';

// Global theme state
late final ValueNotifier<ThemeMode> themeModeNotifier;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize Firebase
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  
  // Load theme preference before runApp to prevent flickering
  final isDarkMode = await ThemePreferenceService.loadThemePreference();
  themeModeNotifier = ValueNotifier<ThemeMode>(
    isDarkMode ? ThemeMode.dark : ThemeMode.light,
  );
  
  runApp(const KisekiApp());
}

class KisekiApp extends StatelessWidget {
  const KisekiApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeModeNotifier,
      builder: (context, themeMode, child) {
        return MaterialApp(
          title: 'Kiseki',
          debugShowCheckedModeBanner: false,
          theme: ThemeData(
            useMaterial3: true,
            colorScheme: ColorScheme.fromSeed(
              seedColor: const Color(0xFF02081A),
              brightness: Brightness.light,
            ),
          ),
          darkTheme: ThemeData(
            useMaterial3: true,
            colorScheme: ColorScheme.fromSeed(
              seedColor: const Color(0xFF02081A),
              brightness: Brightness.dark,
            ),
          ),
          themeMode: themeMode,
          home: const MainNavigationScreen(),
        );
      },
    );
  }
}

class MainNavigationScreen extends StatelessWidget {
  const MainNavigationScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        // Show loading while checking auth state
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(),
            ),
          );
        }

        // Show login page if not authenticated
        final user = snapshot.data;
        if (user == null) {
          return const LoginPage();
        }

        // Show main navigation if authenticated
        return _MainNavigationContent(user: user);
      },
    );
  }
}

class _MainNavigationContent extends StatefulWidget {
  final User user;

  const _MainNavigationContent({required this.user});

  @override
  State<_MainNavigationContent> createState() => _MainNavigationContentState();
}

class _MainNavigationContentState extends State<_MainNavigationContent> {
  int _currentIndex = 0;

  void _showSendSekiBottomSheet() {
    final TextEditingController deviceNameController = TextEditingController();
    final TextEditingController noteController = TextEditingController();
    String deviceType = 'Mac';
    RangeValues yearRange = const RangeValues(2010, 2026);
    bool stillUsing = false;

    void clearForm() {
      deviceNameController.clear();
      noteController.clear();
      deviceType = 'Mac';
      yearRange = const RangeValues(2010, 2026);
      stillUsing = false;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => _SendSekiBottomSheet(
          deviceNameController: deviceNameController,
          noteController: noteController,
          deviceType: deviceType,
          yearRange: yearRange,
          stillUsing: stillUsing,
          onDeviceTypeChanged: (type) {
            deviceType = type;
            setModalState(() {});
          },
          onYearRangeChanged: (range) {
            yearRange = range;
            setModalState(() {});
          },
          onStillUsingChanged: (value) {
            stillUsing = value;
            setModalState(() {});
          },
          onCancel: () {
            Navigator.pop(context);
            clearForm();
          },
          onSend: () async {
            if (deviceNameController.text.trim().isEmpty) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Please enter a device name')),
              );
              return;
            }
            final success = await _sendSeki(
              deviceName: deviceNameController.text,
              deviceType: deviceType,
              startYear: yearRange.start.toInt(),
              endYear: stillUsing ? null : yearRange.end.toInt(),
              note: noteController.text.trim(),
            );
            if (success && mounted) {
              Navigator.pop(context);
              clearForm();
            }
          },
        ),
      ),
    );
  }

  Future<bool> _sendSeki({
    required String deviceName,
    required String deviceType,
    required int startYear,
    int? endYear,
    required String note,
  }) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    final uid = currentUser?.uid;
    
    if (uid == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error: Not signed in')),
        );
      }
      return false;
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
        'deviceName': deviceName.trim(),
        'deviceType': deviceType,
        'startYear': startYear,
        'endYear': endYear,
        'createdAt': FieldValue.serverTimestamp(),
        'note': note,
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Device added successfully!'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      }
      return true;
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to add device: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: [
          ExplorePage(user: widget.user),
          const CirclePage(),
          const InboxPage(),
          ProfilePage(user: widget.user),
        ],
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF02081A) : theme.colorScheme.surface,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.3),
              blurRadius: 10,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildNavItem(
              icon: Icons.explore,
              label: 'Explore',
              index: 0,
              isSelected: _currentIndex == 0,
              theme: theme,
              isDark: isDark,
              onTap: () => setState(() => _currentIndex = 0),
            ),
            _buildNavItem(
              icon: Icons.people,
              label: 'Circle',
              index: 1,
              isSelected: _currentIndex == 1,
              theme: theme,
              isDark: isDark,
              onTap: () => setState(() => _currentIndex = 1),
            ),
            _buildCenterButton(theme, isDark),
            _buildNavItem(
              icon: Icons.inbox,
              label: 'Inbox',
              index: 2,
              isSelected: _currentIndex == 2,
              theme: theme,
              isDark: isDark,
              onTap: () => setState(() => _currentIndex = 2),
            ),
            _buildNavItem(
              icon: Icons.person,
              label: 'Profile',
              index: 3,
              isSelected: _currentIndex == 3,
              theme: theme,
              isDark: isDark,
              onTap: () => setState(() => _currentIndex = 3),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNavItem({
    required IconData icon,
    required String label,
    required int index,
    required bool isSelected,
    required ThemeData theme,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                color: isSelected
                    ? (isDark ? Colors.white : theme.colorScheme.primary)
                    : (isDark ? Colors.white.withOpacity(0.5) : theme.colorScheme.onSurface.withOpacity(0.6)),
                size: 24,
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                  color: isSelected
                      ? (isDark ? Colors.white : theme.colorScheme.primary)
                      : (isDark ? Colors.white.withOpacity(0.5) : theme.colorScheme.onSurface.withOpacity(0.6)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCenterButton(ThemeData theme, bool isDark) {
    return Expanded(
      child: InkWell(
        onTap: _showSendSekiBottomSheet,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: isDark ? Colors.white : const Color(0xFF02081A),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.add,
                  color: isDark ? const Color(0xFF02081A) : Colors.white,
                  size: 24,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SendSekiBottomSheet extends StatefulWidget {
  final TextEditingController deviceNameController;
  final TextEditingController noteController;
  final String deviceType;
  final RangeValues yearRange;
  final bool stillUsing;
  final ValueChanged<String> onDeviceTypeChanged;
  final ValueChanged<RangeValues> onYearRangeChanged;
  final ValueChanged<bool> onStillUsingChanged;
  final VoidCallback onCancel;
  final VoidCallback onSend;

  const _SendSekiBottomSheet({
    required this.deviceNameController,
    required this.noteController,
    required this.deviceType,
    required this.yearRange,
    required this.stillUsing,
    required this.onDeviceTypeChanged,
    required this.onYearRangeChanged,
    required this.onStillUsingChanged,
    required this.onCancel,
    required this.onSend,
  });

  @override
  State<_SendSekiBottomSheet> createState() => _SendSekiBottomSheetState();
}

class _SendSekiBottomSheetState extends State<_SendSekiBottomSheet> {
  final FocusNode _deviceNameFocusNode = FocusNode();
  final FocusNode _noteFocusNode = FocusNode();
  bool _showCategoryPicker = false;
  bool _isManualCategorySelection = false;

  @override
  void initState() {
    super.initState();
    // Auto-focus the device name field when the bottom sheet opens
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _deviceNameFocusNode.requestFocus();
    });
    // Listen to text changes to update button state and suggest device type
    widget.deviceNameController.addListener(_onDeviceNameChanged);
    widget.noteController.addListener(_onTextChanged);
  }

  void _onDeviceNameChanged() {
    // Auto-suggest device type only when user has NOT manually picked a category
    if (!_isManualCategorySelection) {
      final deviceName = widget.deviceNameController.text.trim();
      if (deviceName.isNotEmpty) {
        final suggestedType = suggestDeviceTypeFromName(deviceName);
        if (suggestedType != widget.deviceType) {
          widget.onDeviceTypeChanged(suggestedType);
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
    widget.deviceNameController.removeListener(_onDeviceNameChanged);
    widget.noteController.removeListener(_onTextChanged);
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

  void _handleAddButtonPressed() {
    // Smart validation with focus management
    if (widget.deviceNameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a name.')),
      );
      _deviceNameFocusNode.requestFocus();
      return;
    }
    
    if (widget.noteController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please add a short note.')),
      );
      _noteFocusNode.requestFocus();
      return;
    }
    
    // If validation passes, call the parent's onSend
    widget.onSend();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    
    // Check if button should be enabled
    final isButtonEnabled = widget.deviceNameController.text.trim().isNotEmpty &&
        widget.noteController.text.trim().isNotEmpty;

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
                          onPressed: widget.onCancel,
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
                                  'Add Device',
                                  style: TextStyle(
                                    color: isDark ? Colors.white : theme.colorScheme.onSurface,
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
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
                        // Add button (always clickable, validation handled in onPressed)
                        TextButton(
                          onPressed: _handleAddButtonPressed,
                          child: Text(
                            'Add',
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
                      controller: widget.deviceNameController,
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
                              _getIconForDeviceType(widget.deviceType),
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
                        selectedDeviceType: widget.deviceType,
                        isDark: isDark,
                        primaryColor: theme.colorScheme.primary,
                        onCategorySelected: (deviceType) {
                          setState(() {
                            _isManualCategorySelection = true;
                            _showCategoryPicker = false;
                          });
                          widget.onDeviceTypeChanged(deviceType);
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
                          widget.stillUsing
                              ? '${widget.yearRange.start.toInt()} - Present'
                              : '${widget.yearRange.start.toInt()} - ${widget.yearRange.end.toInt()}',
                          style: TextStyle(
                            color: (isDark ? Colors.white : theme.colorScheme.onSurface).withOpacity(0.7),
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    RangeSlider(
                      values: widget.yearRange,
                      min: 2010,
                      max: 2026,
                      divisions: 16,
                      labels: RangeLabels(
                        widget.yearRange.start.toInt().toString(),
                        widget.stillUsing
                            ? 'Present'
                            : widget.yearRange.end.toInt().toString(),
                      ),
                      activeColor: isDark ? Colors.white : theme.colorScheme.primary,
                      inactiveColor: (isDark ? Colors.white : theme.colorScheme.primary).withOpacity(0.3),
                      onChanged: widget.stillUsing
                          ? (range) {
                              widget.onYearRangeChanged(
                                RangeValues(range.start, 2026),
                              );
                            }
                          : widget.onYearRangeChanged,
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
                      value: widget.stillUsing,
                      onChanged: widget.onStillUsingChanged,
                      activeColor: isDark ? Colors.white : theme.colorScheme.primary,
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                // Note
                TextField(
                  controller: widget.noteController,
                  focusNode: _noteFocusNode,
                  style: TextStyle(color: isDark ? Colors.white : theme.colorScheme.onSurface),
                  maxLines: 5,
                  decoration: InputDecoration(
                    hintText: "What makes this device special to you?",
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
  final String selectedDeviceType;
  final bool isDark;
  final Color primaryColor;
  final ValueChanged<String> onCategorySelected;

  const _CategoryPickerStrip({
    required this.selectedDeviceType,
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
      children: deviceCategories.map<Widget>((c) {
        final selected = c.deviceType == selectedDeviceType;
        return Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () {
              // Single-select: tapping updates selection, deselecting previous
              onCategorySelected(c.deviceType);
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
                c.icon,
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
