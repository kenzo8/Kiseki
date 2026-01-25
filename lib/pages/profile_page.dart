import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../models/seki_model.dart';
import '../pages/settings_page.dart';
import '../widgets/timeline_seki_item.dart';
import '../widgets/seki_card.dart';
import '../widgets/device_icon_selector.dart';

class ProfilePage extends StatefulWidget {
  final User? user;

  const ProfilePage({super.key, required this.user});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {

  /// Gets all active devices from a list of Sekis.
  /// An active device is one where endYear is null.
  /// Returns a list of active Sekis, or empty list if none found.
  List<Seki> _getActiveDevices(List<Seki> sekis) {
    final activeSekis = sekis.where((seki) => seki.endYear == null).toList();
    if (activeSekis.isEmpty) {
      return [];
    }
    // Sort by startYear descending to get the latest first
    activeSekis.sort((a, b) => b.startYear.compareTo(a.startYear));
    return activeSekis;
  }

  void _showEditSekiBottomSheet(Seki seki) {
    final TextEditingController deviceNameController = TextEditingController(text: seki.deviceName);
    final TextEditingController noteController = TextEditingController(text: seki.note);
    String deviceType = seki.deviceType;
    RangeValues yearRange = RangeValues(
      seki.startYear.toDouble(),
      seki.endYear?.toDouble() ?? 2026.0,
    );
    bool stillUsing = seki.endYear == null;
    bool isLoading = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => _EditSekiBottomSheet(
          sekiId: seki.id,
          deviceNameController: deviceNameController,
          noteController: noteController,
          deviceType: deviceType,
          yearRange: yearRange,
          stillUsing: stillUsing,
          isLoading: isLoading,
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
          },
          onSave: () async {
            if (deviceNameController.text.trim().isEmpty) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Please enter a device name')),
              );
              return;
            }
            setModalState(() {
              isLoading = true;
            });
            final success = await _updateSeki(
              sekiId: seki.id,
              deviceName: deviceNameController.text,
              deviceType: deviceType,
              startYear: yearRange.start.toInt(),
              endYear: stillUsing ? null : yearRange.end.toInt(),
              note: noteController.text.trim(),
            );
            setModalState(() {
              isLoading = false;
            });
            if (success && mounted) {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Seki updated successfully!'),
                  backgroundColor: Colors.green,
                  duration: Duration(seconds: 2),
                ),
              );
            }
          },
        ),
      ),
    );
  }

  Future<bool> _updateSeki({
    required String sekiId,
    required String deviceName,
    required String deviceType,
    required int startYear,
    int? endYear,
    required String note,
  }) async {
    try {
      await FirebaseFirestore.instance.collection('seki').doc(sekiId).update({
        'deviceName': deviceName.trim(),
        'deviceType': deviceType,
        'startYear': startYear,
        'endYear': endYear,
        'note': note,
      });
      return true;
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update Seki: $e'),
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
    final scaffoldBg = isDark ? const Color(0xFF02081A) : const Color(0xFFF5F5F5);

    if (widget.user == null) {
      return Container(
        color: scaffoldBg,
        child: Center(
          child: Text(
            'Please sign in to view profile',
            style: TextStyle(color: theme.colorScheme.onSurface.withOpacity(0.7)),
          ),
        ),
      );
    }

    return Container(
      color: scaffoldBg,
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Back button (only show if we can pop)
                  if (Navigator.canPop(context))
                    IconButton(
                      icon: const Icon(Icons.arrow_back),
                      color: theme.colorScheme.onSurface.withOpacity(0.7),
                      tooltip: 'Back',
                      onPressed: () {
                        Navigator.of(context).pop();
                      },
                    )
                  else
                    const SizedBox(width: 48), // Spacer to maintain alignment
                  // Settings button
                  IconButton(
                    icon: const Icon(Icons.settings),
                    color: theme.colorScheme.onSurface.withOpacity(0.7),
                    tooltip: 'Settings',
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) => const SettingsPage(),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
            // User Info Section
            StreamBuilder<DocumentSnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('users')
                  .doc(FirebaseAuth.instance.currentUser?.uid ?? '')
                  .snapshots(),
              builder: (context, userSnapshot) {
                if (userSnapshot.hasData && userSnapshot.data!.exists) {
                  final userData = userSnapshot.data!.data() as Map<String, dynamic>;
                  final username = userData['username'] as String? ?? 'Unknown';
                  final email = userData['email'] as String? ?? widget.user?.email ?? 'Unknown';
                  final bio = userData['bio'] as String? ?? '';

                  return StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('seki')
                        .where('uid', isEqualTo: FirebaseAuth.instance.currentUser?.uid ?? '')
                        .snapshots(),
                    builder: (context, sekiSnapshot) {
                      List<Seki> activeDevices = [];
                      if (sekiSnapshot.hasData && sekiSnapshot.data!.docs.isNotEmpty) {
                        final sekis = sekiSnapshot.data!.docs
                            .map((doc) => Seki.fromFirestore(doc))
                            .toList();
                        activeDevices = _getActiveDevices(sekis);
                      }

                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                        child: Card(
                          color: theme.colorScheme.surface.withOpacity(0.1),
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Icon(
                                      Icons.person,
                                      size: 20,
                                      color: theme.colorScheme.onSurface.withOpacity(0.7),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      username,
                                      style: TextStyle(
                                        color: theme.colorScheme.onSurface,
                                        fontSize: 18,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    Icon(
                                      Icons.email,
                                      size: 16,
                                      color: theme.colorScheme.onSurface.withOpacity(0.6),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        email,
                                        style: TextStyle(
                                          color: theme.colorScheme.onSurface.withOpacity(0.7),
                                          fontSize: 14,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                if (bio.isNotEmpty) ...[
                                  const SizedBox(height: 12),
                                  Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Icon(
                                        Icons.info_outline,
                                        size: 16,
                                        color: theme.colorScheme.onSurface.withOpacity(0.6),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          bio,
                                          style: TextStyle(
                                            color: theme.colorScheme.onSurface.withOpacity(0.7),
                                            fontSize: 14,
                                            height: 1.5,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                                if (activeDevices.isNotEmpty) ...[
                                  const SizedBox(height: 12),
                                  Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'In Use:',
                                        style: TextStyle(
                                          color: theme.colorScheme.primary.withOpacity(0.8),
                                          fontSize: 14,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Wrap(
                                          spacing: 8,
                                          runSpacing: 6,
                                          children: activeDevices.map((seki) {
                                            return Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Icon(
                                                  getIconByDeviceName(seki.deviceName),
                                                  size: 16,
                                                  color: theme.colorScheme.onSurface.withOpacity(0.7),
                                                ),
                                                const SizedBox(width: 4),
                                                Text(
                                                  seki.deviceName,
                                                  style: TextStyle(
                                                    color: theme.colorScheme.onSurface.withOpacity(0.8),
                                                    fontSize: 14,
                                                    fontWeight: FontWeight.w400,
                                                  ),
                                                ),
                                              ],
                                            );
                                          }).toList(),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  );
                }
                return const SizedBox.shrink();
              },
            ),
            const SizedBox(height: 8),
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('seki')
                    .where('uid', isEqualTo: FirebaseAuth.instance.currentUser?.uid ?? '')
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return Center(
                      child: CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(theme.colorScheme.primary),
                      ),
                    );
                  }

                  if (snapshot.hasError) {
                    return Center(
                      child: Text(
                        'Failed to load: ${snapshot.error}',
                        style: TextStyle(color: theme.colorScheme.onSurface.withOpacity(0.7)),
                      ),
                    );
                  }

                  if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                    return Center(
                      child: Text(
                        'No memories yet.',
                        style: TextStyle(
                          color: theme.colorScheme.onSurface.withOpacity(0.6),
                          fontSize: 16,
                        ),
                      ),
                    );
                  }

                  // Sort by startYear in ascending order
                  final docs = snapshot.data!.docs.toList();
                  docs.sort((a, b) {
                    final aData = a.data() as Map<String, dynamic>;
                    final bData = b.data() as Map<String, dynamic>;
                    final aStartYear = aData['startYear'] as int? ?? 0;
                    final bStartYear = bData['startYear'] as int? ?? 0;
                    return aStartYear.compareTo(bStartYear); // Ascending order
                  });

                  if (docs.isEmpty) {
                    return Center(
                      child: Text(
                        'No memories yet.',
                        style: TextStyle(
                          color: theme.colorScheme.onSurface.withOpacity(0.6),
                          fontSize: 16,
                        ),
                      ),
                    );
                  }

                  return ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                    itemCount: docs.length,
                    itemBuilder: (context, index) {
                      final doc = docs[index];
                      final seki = Seki.fromFirestore(doc);
                      final isLast = index == docs.length - 1;
                      return TimelineSekiItem(
                        seki: seki,
                        isDark: isDark,
                        isLast: isLast,
                        onTap: () => _showEditSekiBottomSheet(seki),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

}

class _EditSekiBottomSheet extends StatefulWidget {
  final String sekiId;
  final TextEditingController deviceNameController;
  final TextEditingController noteController;
  final String deviceType;
  final RangeValues yearRange;
  final bool stillUsing;
  final bool isLoading;
  final ValueChanged<String> onDeviceTypeChanged;
  final ValueChanged<RangeValues> onYearRangeChanged;
  final ValueChanged<bool> onStillUsingChanged;
  final VoidCallback onCancel;
  final VoidCallback onSave;

  const _EditSekiBottomSheet({
    required this.sekiId,
    required this.deviceNameController,
    required this.noteController,
    required this.deviceType,
    required this.yearRange,
    required this.stillUsing,
    required this.isLoading,
    required this.onDeviceTypeChanged,
    required this.onYearRangeChanged,
    required this.onStillUsingChanged,
    required this.onCancel,
    required this.onSave,
  });

  @override
  State<_EditSekiBottomSheet> createState() => _EditSekiBottomSheetState();
}

class _EditSekiBottomSheetState extends State<_EditSekiBottomSheet> {
  final FocusNode _deviceNameFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _deviceNameFocusNode.requestFocus();
    });
    // Listen to text changes to update button state and suggest device type
    widget.deviceNameController.addListener(_onDeviceNameChanged);
    widget.noteController.addListener(_onTextChanged);
  }

  void _onDeviceNameChanged() {
    // Auto-suggest device type based on device name
    final deviceName = widget.deviceNameController.text.trim();
    if (deviceName.isNotEmpty) {
      final suggestedType = suggestDeviceTypeFromName(deviceName);
      if (suggestedType != widget.deviceType) {
        widget.onDeviceTypeChanged(suggestedType);
      }
    }
    // Update icon preview
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
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    
    // Check if button should be enabled
    final isButtonEnabled = widget.deviceNameController.text.trim().isNotEmpty &&
        widget.noteController.text.trim().isNotEmpty &&
        !widget.isLoading;

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
                          onPressed: widget.isLoading ? null : widget.onCancel,
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
                          child: Text(
                            'Edit Seki',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: isDark ? Colors.white : theme.colorScheme.onSurface,
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        // Save button
                        TextButton(
                          onPressed: isButtonEnabled ? widget.onSave : null,
                          child: widget.isLoading
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
                                  'Save',
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
                // Device Name with Icon Preview
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: TextField(
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
                          filled: true,
                          fillColor: (isDark ? Colors.white : Colors.black).withOpacity(0.1),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 16,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Padding(
                      padding: const EdgeInsets.only(top: 16),
                      child: DeviceIconPreview(
                        deviceName: widget.deviceNameController.text,
                        isDark: isDark,
                        size: 48,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                // Device Category Selector
                DeviceCategorySelector(
                  selectedDeviceType: widget.deviceType,
                  onCategorySelected: (deviceType) {
                    widget.onDeviceTypeChanged(deviceType);
                  },
                  isDark: isDark,
                ),
                const SizedBox(height: 20),
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
                      activeThumbColor: isDark ? Colors.white : theme.colorScheme.primary,
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                // Note
                TextField(
                  controller: widget.noteController,
                  style: TextStyle(color: isDark ? Colors.white : theme.colorScheme.onSurface),
                  maxLines: 4,
                  decoration: InputDecoration(
                    labelText: 'Note',
                    labelStyle: TextStyle(
                      color: (isDark ? Colors.white : theme.colorScheme.onSurface).withOpacity(0.7),
                    ),
                    hintText: 'Share your experience...',
                    hintStyle: TextStyle(
                      color: (isDark ? Colors.white : theme.colorScheme.onSurface).withOpacity(0.5),
                    ),
                    filled: true,
                    fillColor: (isDark ? Colors.white : Colors.black).withOpacity(0.1),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
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
