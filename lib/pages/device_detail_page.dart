import 'dart:ui';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../models/seki_model.dart';
import '../widgets/device_icon_selector.dart';
import '../widgets/seki_card.dart';
import '../services/system_ui_service.dart';
import '../services/auth_service.dart';
import '../services/profile_data_service.dart';
import 'add_device_page.dart';
import 'profile_page.dart';
import 'other_user_profile_page.dart';
import 'login_page.dart';

class DeviceDetailPage extends StatefulWidget {
  final Seki seki;
  final ValueNotifier<bool>? exploreRefreshNotifier;

  const DeviceDetailPage({super.key, required this.seki, this.exploreRefreshNotifier});

  @override
  State<DeviceDetailPage> createState() => _DeviceDetailPageState();
}

class _DeviceDetailPageState extends State<DeviceDetailPage> {
  late Stream<DocumentSnapshot> _sekiStream;
  Seki? _userDeviceEntry; // Track the user's existing device entry
  bool? _isWantingDevice;

  @override
  void initState() {
    super.initState();
    // Listen to Firestore for real-time updates
    _sekiStream = FirebaseFirestore.instance
        .collection('seki')
        .doc(widget.seki.id)
        .snapshots();
    
    _checkUserDeviceStatus();
    _checkWantStatus();
  }

  Future<void> _checkUserDeviceStatus() async {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    if (currentUserId == null) {
      setState(() => _userDeviceEntry = null);
      return;
    }

    try {
      final querySnapshot = await FirebaseFirestore.instance
          .collection('seki')
          .where('uid', isEqualTo: currentUserId)
          .where('deviceName', isEqualTo: widget.seki.deviceName)
          .limit(1)
          .get();

      if (mounted) {
        if (querySnapshot.docs.isNotEmpty) {
          setState(() => _userDeviceEntry = Seki.fromFirestore(querySnapshot.docs.first));
        } else {
          setState(() => _userDeviceEntry = null);
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _userDeviceEntry = null);
      }
    }
  }

  Future<void> _checkWantStatus() async {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    if (currentUserId == null) {
      setState(() => _isWantingDevice = false);
      return;
    }

    try {
      final querySnapshot = await FirebaseFirestore.instance
          .collection('wants')
          .where('uid', isEqualTo: currentUserId)
          .where('deviceName', isEqualTo: widget.seki.deviceName)
          .limit(1)
          .get();

      if (mounted) {
        setState(() => _isWantingDevice = querySnapshot.docs.isNotEmpty);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isWantingDevice = false);
      }
    }
  }

  Future<void> _toggleWant() async {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    if (currentUserId == null) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => const LoginPage(),
        ),
      );
      return;
    }

    try {
      if (_isWantingDevice == true) {
        // Show confirmation dialog before removing
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Remove from wants?'),
            content: const Text('This device will be removed from your wants list.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: Text(
                  'Cancel',
                  style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
                ),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(true),
                style: TextButton.styleFrom(
                  foregroundColor: Colors.red,
                ),
                child: const Text('Remove'),
              ),
            ],
          ),
        );

        if (confirmed != true) {
          return; // User cancelled
        }

        // Find and delete the want document
        final querySnapshot = await FirebaseFirestore.instance
            .collection('wants')
            .where('uid', isEqualTo: currentUserId)
            .where('deviceName', isEqualTo: widget.seki.deviceName)
            .limit(1)
            .get();

        if (querySnapshot.docs.isNotEmpty) {
          await querySnapshot.docs.first.reference.delete();
          // Optimistic update: remove from cache so profile page list refreshes immediately
          ProfileDataService.instance.removeWantByDeviceName(widget.seki.deviceName);
        }

        if (mounted) {
          setState(() => _isWantingDevice = false);
        }
      } else {
        // Add to wants - get username first
        String username;
        final authService = AuthService();
        try {
          final userProfile = await authService.getUserProfile(currentUserId);
          if (userProfile != null && userProfile['username'] != null) {
            username = userProfile['username'] as String;
          } else {
            final currentUser = FirebaseAuth.instance.currentUser;
            final userEmail = currentUser?.email;
            if (userEmail != null) {
              username = authService.generateDefaultUsername(userEmail);
            } else {
              username = 'user${currentUserId.substring(0, 4)}';
            }
          }
        } catch (e) {
          final currentUser = FirebaseAuth.instance.currentUser;
          final userEmail = currentUser?.email;
          if (userEmail != null) {
            username = authService.generateDefaultUsername(userEmail);
          } else {
            username = 'user${currentUserId.substring(0, 4)}';
          }
        }

        // Create want document
        await FirebaseFirestore.instance.collection('wants').add({
          'uid': currentUserId,
          'username': username,
          'deviceName': widget.seki.deviceName,
          'deviceType': widget.seki.deviceType,
          'createdAt': FieldValue.serverTimestamp(),
        });
        
        // Refresh ProfileDataService to update want list immediately
        ProfileDataService.instance.refresh();

        if (mounted) {
          setState(() => _isWantingDevice = true);
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update want status: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _clearWantState() async {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    if (currentUserId == null) return;

    try {
      final querySnapshot = await FirebaseFirestore.instance
          .collection('wants')
          .where('uid', isEqualTo: currentUserId)
          .where('deviceName', isEqualTo: widget.seki.deviceName)
          .limit(1)
          .get();

      if (querySnapshot.docs.isNotEmpty) {
        await querySnapshot.docs.first.reference.delete();
        ProfileDataService.instance.removeWantByDeviceName(widget.seki.deviceName);
      }

      if (mounted && _isWantingDevice == true) {
        setState(() => _isWantingDevice = false);
      }
    } catch (e) {
      // Silently fail - not critical
    }
  }

  Future<void> _openDeviceSheet({required bool stillUsing}) async {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    if (currentUserId == null) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => const LoginPage(),
        ),
      );
      return;
    }

    // If user has existing device, open Edit sheet; otherwise open Add sheet
    final existingDevice = _userDeviceEntry;
    
    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => existingDevice != null
          ? AddDevicePage(
              seki: existingDevice,
              overrideStillUsing: stillUsing, // Override saved value based on button tapped
            )
          : AddDevicePage(
              preFilledDeviceName: widget.seki.deviceName,
              preFilledStillUsing: stillUsing,
            ),
    );
    
    // Refresh device status after sheet closes
    await _checkUserDeviceStatus();
    
    // If device was just added and Want was active, clear it
    if (_userDeviceEntry != null && _isWantingDevice == true) {
      await _clearWantState();
    }
    
    // If device was added/edited successfully, pop with result
    if (result == true && mounted) {
      Navigator.of(context).pop(true);
    }
  }

  String _getStatus(Seki seki) {
    final isActive = seki.isPreciseMode 
        ? (seki.endTime == null) 
        : (seki.endYear == null);
    return isActive ? 'Active' : 'Retired';
  }
  
  String _getPeriod(Seki seki) {
    if (seki.isPreciseMode && seki.startTime != null) {
      final startDate = seki.startTime!.toDate();
      if (seki.endTime == null) {
        return '${startDate.year}/${startDate.month}/${startDate.day} – Present';
      } else {
        final endDate = seki.endTime!.toDate();
        return '${startDate.year}/${startDate.month}/${startDate.day} – ${endDate.year}/${endDate.month}/${endDate.day}';
      }
    } else {
      return seki.endYear == null
          ? '${seki.startYear} – Present'
          : '${seki.startYear} – ${seki.endYear}';
    }
  }

  Future<void> _showEditSekiBottomSheet(Seki seki) async {
    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => AddDevicePage(seki: seki),
    );
    
    // If device was edited successfully, pop with result
    if (result == true && mounted) {
      Navigator.of(context).pop(true);
    }
  }

  Future<void> _deleteDevice(Seki seki) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete this device?'),
        content: const Text('This device will be removed from your profile.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(
              'Cancel',
              style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(
              foregroundColor: Colors.red,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      try {
        await FirebaseFirestore.instance
            .collection('seki')
            .doc(seki.id)
            .delete();

        if (mounted) {
          // Trigger Explore refresh so home page removes deleted item (whether we came from Profile or Explore)
          widget.exploreRefreshNotifier?.value = true;
          Navigator.of(context).pop(true);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Device deleted successfully'),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 2),
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to delete device: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  static const _reportReasons = [
    'Spam',
    'Inappropriate content',
    'Harassment or bullying',
    'Fake or impersonation',
    'Other',
  ];

  Future<void> _onReportTapped(Seki seki) async {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    if (currentUserId == null) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => const LoginPage(),
        ),
      );
      return;
    }
    await _showReportDialog(seki);
  }

  Future<void> _showReportDialog(Seki seki) async {
    String? selectedReason;
    final detailsController = TextEditingController();
    final theme = Theme.of(context);
    final pageContext = context;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: const Text('Report'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Report this device entry for violating our guidelines. Your report will be reviewed.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurface.withOpacity(0.7),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Reason',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 8),
                  ..._reportReasons.map((r) => RadioListTile<String>(
                    value: r,
                    groupValue: selectedReason,
                    onChanged: (v) => setDialogState(() => selectedReason = v),
                    title: Text(
                      r,
                      style: TextStyle(
                        fontSize: 14,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                  )),
                  const SizedBox(height: 12),
                  Text(
                    'Additional details (optional)',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 6),
                  TextField(
                    controller: detailsController,
                    maxLines: 2,
                    decoration: InputDecoration(
                      hintText: 'Provide more context if needed',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      filled: true,
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: Text(
                  'Cancel',
                  style: TextStyle(color: theme.colorScheme.onSurface),
                ),
              ),
              FilledButton(
                onPressed: selectedReason == null
                    ? null
                    : () async {
                        final navigator = Navigator.of(dialogContext);
                        final messenger = ScaffoldMessenger.of(pageContext);
                        try {
                          await FirebaseFirestore.instance
                              .collection('reports')
                              .add({
                            'reporterUid': FirebaseAuth.instance.currentUser!.uid,
                            'reportedSekiId': seki.id,
                            'reportedUid': seki.uid,
                            'deviceName': seki.deviceName,
                            'reason': selectedReason,
                            'details': detailsController.text.trim().isEmpty
                                ? null
                                : detailsController.text.trim(),
                            'createdAt': FieldValue.serverTimestamp(),
                          });
                          navigator.pop();
                          messenger.showSnackBar(
                            const SnackBar(
                              content: Text('Report submitted. Thank you.'),
                              backgroundColor: Colors.green,
                            ),
                          );
                        } catch (e) {
                          messenger.showSnackBar(
                            SnackBar(
                              content: Text('Failed to submit report: $e'),
                              backgroundColor: Colors.red,
                            ),
                          );
                        }
                      },
                child: const Text('Submit'),
              ),
            ],
          );
        },
      ),
    );
    detailsController.dispose();
  }

  Future<void> _removeUserDevice() async {
    final userDevice = _userDeviceEntry;
    if (userDevice == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove from your devices?'),
        content: const Text('This device will be removed from your profile.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(
              'Cancel',
              style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(
              foregroundColor: Colors.red,
            ),
            child: const Text('Remove'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      try {
        await FirebaseFirestore.instance
            .collection('seki')
            .doc(userDevice.id)
            .delete();

        if (mounted) {
          await _checkUserDeviceStatus();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Device removed successfully'),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 2),
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to remove device: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }


  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    final isOwner = currentUserId != null && currentUserId == widget.seki.uid;
    
    return StreamBuilder<DocumentSnapshot>(
      stream: _sekiStream,
      builder: (context, snapshot) {
        Seki seki = widget.seki;
        if (snapshot.hasData && snapshot.data!.exists) {
          seki = Seki.fromFirestore(snapshot.data!);
        }

        final categoryColor = getCategoryColor(seki.deviceType);
        // Create subtle gradient background based on category color
        final gradientStart = isDark
            ? categoryColor.withOpacity(0.12)
            : categoryColor.withOpacity(0.06);
        final gradientEnd = isDark
            ? categoryColor.withOpacity(0.03)
            : categoryColor.withOpacity(0.01);
        final scaffoldBg = isDark 
            ? const Color(0xFF02081A) 
            : const Color(0xFFF5F5F5);
        
        // Set immersive status bar
        SystemUIService.setImmersiveStatusBar(context, backgroundColor: scaffoldBg);

        final valueColor = theme.colorScheme.onSurface;
        // Device title color - always use dark color
        final deviceTitleColor = const Color(0xFF333333);

        return Scaffold(
          backgroundColor: scaffoldBg,
          bottomNavigationBar: _buildGlassmorphismBottomBar(context, seki, theme, scaffoldBg, isDark, isOwner),
          body: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  gradientStart,
                  gradientEnd,
                  scaffoldBg,
                ],
                stops: const [0.0, 0.3, 1.0],
              ),
            ),
            child: SafeArea(
              child: Stack(
                children: [
                  SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        const SizedBox(height: 32),
                    // Hero Icon Section with white container, shadow, and glow
                    Hero(
                      tag: 'device_icon_${seki.id}',
                      child: Container(
                        width: 180,
                        height: 180,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(32),
                          boxShadow: [
                            BoxShadow(
                              color: categoryColor.withOpacity(0.3),
                              blurRadius: 30,
                              spreadRadius: 5,
                              offset: const Offset(0, 8),
                            ),
                            BoxShadow(
                              color: Colors.black.withOpacity(0.1),
                              blurRadius: 20,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Icon(
                          deviceTypeToIcon(seki.deviceType),
                          size: 90,
                          color: categoryColor,
                        ),
                      ),
                    ),
                    const SizedBox(height: 32),
                    // Device Name
                    Text(
                      seki.deviceName,
                      style: TextStyle(
                        color: deviceTitleColor,
                        fontSize: 32,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.5,
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
                            ? theme.colorScheme.surface.withOpacity(0.4)
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
                          _buildInfoRow('STATUS', _getStatus(seki), theme, isDark, valueColor, Icons.info_outline),
                          const SizedBox(height: 20),
                          Divider(
                            height: 1,
                            thickness: 1,
                            color: theme.colorScheme.onSurface.withOpacity(0.1),
                          ),
                          const SizedBox(height: 20),
                          _buildInfoRow('DEVICE TYPE', seki.deviceType, theme, isDark, valueColor, Icons.devices),
                          const SizedBox(height: 20),
                          Divider(
                            height: 1,
                            thickness: 1,
                            color: theme.colorScheme.onSurface.withOpacity(0.1),
                          ),
                          const SizedBox(height: 20),
                          _buildInfoRow('PERIOD', _getPeriod(seki), theme, isDark, valueColor, Icons.access_time),
                          const SizedBox(height: 20),
                          Divider(
                            height: 1,
                            thickness: 1,
                            color: theme.colorScheme.onSurface.withOpacity(0.1),
                          ),
                          const SizedBox(height: 20),
                          _buildOwnerRow(seki, theme, isDark, valueColor),
                        ],
                      ),
                    ),
                    // Note Section - positioned between Info Card and Action Buttons
                    const SizedBox(height: 24),
                    _buildNoteCard(seki.note, categoryColor, theme, isDark),
                    // Add spacing between Impression card and action buttons
                    const SizedBox(height: 20),
                    // Add bottom padding to avoid overlap with fixed buttons
                    // Increased padding to ensure IMPRESSION text isn't cut off
                    const SizedBox(height: 120),
                      ],
                    ),
                  ),
                  // Back button — floating top-left with glassmorphism
                  Positioned(
                    top: 8,
                    left: 8,
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () => Navigator.of(context).pop(),
                        borderRadius: BorderRadius.circular(24),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(24),
                          child: BackdropFilter(
                            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                            child: Container(
                              width: 48,
                              height: 48,
                              decoration: BoxDecoration(
                                color: isDark
                                    ? Colors.white.withOpacity(0.15)
                                    : Colors.white.withOpacity(0.3),
                                borderRadius: BorderRadius.circular(24),
                              ),
                              child: Icon(
                                Icons.arrow_back,
                                color: isDark ? Colors.white : const Color(0xFF333333),
                                size: 24,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  // Report button — top-right, for non-owner (Google Play UGC compliance)
                  if (!isOwner)
                    Positioned(
                      top: 8,
                      right: 8,
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () => _onReportTapped(seki),
                          borderRadius: BorderRadius.circular(24),
                          child: Tooltip(
                            message: 'Report',
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(24),
                              child: BackdropFilter(
                                filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                                child: Container(
                                  width: 48,
                                  height: 48,
                                  decoration: BoxDecoration(
                                    color: isDark
                                        ? Colors.white.withOpacity(0.15)
                                        : Colors.white.withOpacity(0.3),
                                    borderRadius: BorderRadius.circular(24),
                                  ),
                                  child: Icon(
                                    Icons.flag_outlined,
                                    color: isDark ? Colors.white : const Color(0xFF333333),
                                    size: 22,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
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
    ThemeData theme,
    bool isDark,
    Color valueColor,
    IconData icon,
  ) {
    final labelColor = isDark
        ? theme.colorScheme.onSurface.withOpacity(0.5)
        : Colors.grey.shade600;
    
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              icon,
              size: 16,
              color: labelColor,
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: labelColor,
                fontSize: 12,
                fontWeight: FontWeight.w600,
                letterSpacing: 1.2,
              ),
            ),
          ],
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

  Widget _buildOwnerRow(
    Seki seki,
    ThemeData theme,
    bool isDark,
    Color valueColor,
  ) {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    final ownerId = seki.uid; // This is the publisherId
    final isCurrentUser = currentUserId != null && currentUserId == ownerId;
    
    // Use primary color to indicate clickability
    final usernameColor = theme.colorScheme.primary;
    final labelColor = isDark
        ? theme.colorScheme.onSurface.withOpacity(0.5)
        : Colors.grey.shade600;

    return InkWell(
      onTap: () {
        if (isCurrentUser) {
          // Navigate to own profile
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => ProfilePage(
                user: FirebaseAuth.instance.currentUser,
              ),
            ),
          );
        } else {
          // Navigate to other user's profile
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => OtherUserProfilePage(
                publisherId: ownerId,
              ),
            ),
          );
        }
      },
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        constraints: const BoxConstraints(minHeight: 44),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.person_outline,
                      size: 16,
                      color: labelColor,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'OWNER',
                      style: TextStyle(
                        color: labelColor,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ],
                ),
            Expanded(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text(
                    seki.username,
                    textAlign: TextAlign.right,
                    style: TextStyle(
                      color: usernameColor,
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    Icons.chevron_right,
                    size: 20,
                    color: usernameColor.withOpacity(0.7),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }


  Widget _buildGlassmorphismBottomBar(
    BuildContext context,
    Seki seki,
    ThemeData theme,
    Color scaffoldBg,
    bool isDark,
    bool isOwner,
  ) {
    return ClipRRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
        child: Container(
          padding: EdgeInsets.only(
            top: 16,
            left: 24,
            right: 24,
            bottom: 16 + MediaQuery.of(context).padding.bottom,
          ),
          decoration: BoxDecoration(
            color: (isDark 
                ? scaffoldBg 
                : Colors.white).withOpacity(0.85),
            border: Border(
              top: BorderSide(
                color: Colors.white.withOpacity(0.2),
                width: 0.5,
              ),
            ),
          ),
          child: SafeArea(
            top: false,
            child: isOwner
                ? _buildActionButtons(seki, theme)
                : _buildUsageActionButtons(seki, theme),
          ),
        ),
      ),
    );
  }

  Widget _buildActionButtons(Seki seki, ThemeData theme) {
    return Row(
      children: [
        Expanded(
          child: ElevatedButton.icon(
            onPressed: () => _showEditSekiBottomSheet(seki),
            icon: const Icon(Icons.edit_outlined, size: 20),
            label: const Text('Edit'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1A1A1B),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
              elevation: 0,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: OutlinedButton.icon(
            onPressed: () => _deleteDevice(seki),
            icon: const Icon(Icons.delete_outline, size: 20),
            label: const Text('Delete'),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.red,
              side: const BorderSide(color: Colors.red, width: 1.5),
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildUsageActionButtons(Seki seki, ThemeData theme) {
    final userDevice = _userDeviceEntry;
    final isWanting = _isWantingDevice ?? false;
    
    // Determine active state: Used if endYear/endTime exists, Using if endYear/endTime is null
    final bool isUsedActive = userDevice != null && 
        (userDevice.isPreciseMode 
            ? (userDevice.endTime != null) 
            : (userDevice.endYear != null));
    final bool isUsingActive = userDevice != null && 
        (userDevice.isPreciseMode 
            ? (userDevice.endTime == null) 
            : (userDevice.endYear == null));

    return Row(
      children: [
        Expanded(
          child: isUsedActive
              ? ElevatedButton.icon(
                  onPressed: _removeUserDevice,
                  icon: const Icon(Icons.check_circle, size: 20),
                  label: const Text('Used'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1A1A1B),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(24),
                    ),
                    elevation: 0,
                  ),
                )
              : OutlinedButton.icon(
                  onPressed: () => _openDeviceSheet(stillUsing: false),
                  icon: const Icon(Icons.history, size: 20),
                  label: const Text('Used'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.grey,
                    side: const BorderSide(color: Colors.grey, width: 1.5),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(24),
                    ),
                  ),
                ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: isUsingActive
              ? ElevatedButton.icon(
                  onPressed: _removeUserDevice,
                  icon: const Icon(Icons.check_circle, size: 20),
                  label: const Text('Using'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1A1A1B),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(24),
                    ),
                    elevation: 0,
                  ),
                )
              : OutlinedButton.icon(
                  onPressed: () => _openDeviceSheet(stillUsing: true),
                  icon: const Icon(Icons.circle, size: 20),
                  label: const Text('Using'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.grey,
                    side: const BorderSide(color: Colors.grey, width: 1.5),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(24),
                    ),
                  ),
                ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: OutlinedButton.icon(
            onPressed: _toggleWant,
            icon: Icon(
              isWanting ? Icons.star : Icons.star_outline,
              size: 20,
            ),
            label: const Text('Want'),
            style: OutlinedButton.styleFrom(
              foregroundColor: isWanting ? Colors.orange : Colors.grey,
              side: BorderSide(
                color: isWanting ? Colors.orange : Colors.grey,
                width: 1.5,
              ),
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildNoteCard(
    String note,
    Color categoryColor,
    ThemeData theme,
    bool isDark,
  ) {
    final isEmpty = note.isEmpty;
    final labelColor = isDark
        ? theme.colorScheme.onSurface.withOpacity(0.5)
        : Colors.grey.shade600;
    
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
      decoration: BoxDecoration(
        color: isDark
            ? theme.colorScheme.surface.withOpacity(0.4)
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
      child: Stack(
        children: [
          // Quote icon background - subtle
          Positioned(
            top: 12,
            right: 12,
            child: Icon(
              Icons.format_quote,
              size: 40,
              color: categoryColor.withOpacity(0.08),
            ),
          ),
          // Content
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Label
              Row(
                children: [
                  Icon(
                    Icons.comment_outlined,
                    size: 16,
                    color: labelColor,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'IMPRESSION',
                    style: TextStyle(
                      color: labelColor,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 1.2,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // Note content or placeholder - aligned with label
              isEmpty
                  ? Text(
                      'No notes added yet.',
                      style: TextStyle(
                        color: labelColor.withOpacity(0.7),
                        fontSize: 14,
                        fontStyle: FontStyle.italic,
                        height: 1.5,
                      ),
                    )
                  : Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Quote icon - positioned to align with text baseline
                        Padding(
                          padding: const EdgeInsets.only(top: 2, right: 6),
                          child: Icon(
                            Icons.format_quote,
                            size: 18,
                            color: categoryColor.withOpacity(0.4),
                          ),
                        ),
                        // Text - this will align with the label text, not the label icon
                        Expanded(
                          child: Text(
                            note,
                            style: TextStyle(
                              color: theme.colorScheme.onSurface.withOpacity(0.85),
                              fontSize: 15,
                              height: 1.6,
                              fontStyle: FontStyle.normal,
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                        ),
                      ],
                    ),
            ],
          ),
        ],
      ),
    );
  }
}
