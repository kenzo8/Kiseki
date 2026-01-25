import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../models/seki_model.dart';
import '../widgets/seki_card.dart';
import '../widgets/device_icon_selector.dart';

class DeviceDetailPage extends StatefulWidget {
  final Seki seki;

  const DeviceDetailPage({super.key, required this.seki});

  @override
  State<DeviceDetailPage> createState() => _DeviceDetailPageState();
}

class _DeviceDetailPageState extends State<DeviceDetailPage> {
  late Stream<DocumentSnapshot> _sekiStream;

  @override
  void initState() {
    super.initState();
    // Listen to Firestore for real-time updates
    _sekiStream = FirebaseFirestore.instance
        .collection('seki')
        .doc(widget.seki.id)
        .snapshots();
  }

  String _getStatus(Seki seki) => seki.endYear == null ? 'Active' : 'Vintage';
  
  String _getPeriod(Seki seki) => seki.endYear == null
      ? '${seki.startYear} – Present'
      : '${seki.startYear} – ${seki.endYear}';

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
                  content: Text('Device updated successfully!'),
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
            content: Text('Failed to update device: $e'),
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
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    final isOwner = currentUserId != null && currentUserId == widget.seki.uid;

    return StreamBuilder<DocumentSnapshot>(
      stream: _sekiStream,
      builder: (context, snapshot) {
        Seki seki = widget.seki;
        if (snapshot.hasData && snapshot.data!.exists) {
          seki = Seki.fromFirestore(snapshot.data!);
        }

        final lightGreyBg = isDark
            ? Colors.white.withOpacity(0.08)
            : Colors.grey.shade100;
        final labelColor = isDark
            ? theme.colorScheme.onSurface.withOpacity(0.5)
            : Colors.grey.shade600;
        final valueColor = theme.colorScheme.onSurface;

        return Scaffold(
          backgroundColor: scaffoldBg,
          appBar: AppBar(
            backgroundColor: scaffoldBg,
            elevation: 0,
            leading: IconButton(
              icon: Icon(
                Icons.arrow_back,
                color: theme.colorScheme.onSurface,
              ),
              onPressed: () => Navigator.of(context).pop(),
            ),
            actions: isOwner
                ? [
                    IconButton(
                      icon: Icon(
                        Icons.edit_outlined,
                        color: theme.colorScheme.onSurface,
                      ),
                      onPressed: () => _showEditSekiBottomSheet(seki),
                    ),
                  ]
                : null,
          ),
          body: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const SizedBox(height: 32),
                  // Hero Header: Icon + Device Name
                  Hero(
                    tag: 'device_icon_${seki.id}',
                    child: Container(
                      width: 160,
                      height: 160,
                      decoration: BoxDecoration(
                        color: lightGreyBg,
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: Icon(
                        getIconByDeviceName(seki.deviceName),
                        size: 80,
                        color: isDark
                            ? theme.colorScheme.onSurface.withOpacity(0.8)
                            : Colors.grey.shade700,
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  // Device Name
                  Text(
                    seki.deviceName,
                    style: TextStyle(
                      color: valueColor,
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      height: 1.2,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 40),
                  // Unified Info Section
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: isDark
                          ? theme.colorScheme.surface.withOpacity(0.3)
                          : Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: isDark
                          ? null
                          : [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.05),
                                blurRadius: 10,
                                offset: const Offset(0, 2),
                              ),
                            ],
                    ),
                    child: Column(
                      children: [
                        _buildInfoRow('STATUS', _getStatus(seki), labelColor, valueColor),
                        const SizedBox(height: 20),
                        Divider(
                          height: 1,
                          thickness: 1,
                          color: theme.colorScheme.onSurface.withOpacity(0.1),
                        ),
                        const SizedBox(height: 20),
                        _buildInfoRow('PERIOD', _getPeriod(seki), labelColor, valueColor),
                        const SizedBox(height: 20),
                        Divider(
                          height: 1,
                          thickness: 1,
                          color: theme.colorScheme.onSurface.withOpacity(0.1),
                        ),
                        const SizedBox(height: 20),
                        _buildInfoRow('OWNER', seki.username, labelColor, valueColor),
                      ],
                    ),
                  ),
                  // Note Section (if available)
                  if (seki.note.isNotEmpty) ...[
                    const SizedBox(height: 32),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: RichText(
                        textAlign: TextAlign.left,
                        text: TextSpan(
                          style: TextStyle(
                            color: valueColor.withOpacity(0.85),
                            fontSize: 18,
                            height: 1.6,
                            fontStyle: FontStyle.italic,
                          ),
                          children: [
                            TextSpan(
                              text: '"',
                              style: TextStyle(
                                fontSize: 32,
                                height: 0.5,
                                color: labelColor,
                                fontFamily: 'serif',
                              ),
                            ),
                            TextSpan(text: seki.note),
                          ],
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildInfoRow(
    String label,
    String value,
    Color labelColor,
    Color valueColor,
  ) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: labelColor,
            fontSize: 12,
            fontWeight: FontWeight.w600,
            letterSpacing: 1.2,
          ),
        ),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: TextStyle(
              color: valueColor,
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
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
                                  'Edit Device',
                                  style: TextStyle(
                                    color: isDark ? Colors.white : theme.colorScheme.onSurface,
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
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
                                  'Save Changes',
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
