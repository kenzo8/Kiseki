import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../models/seki_model.dart';
import '../widgets/device_icon_selector.dart';
import '../services/system_ui_service.dart';
import '../services/auth_service.dart';
import 'add_device_page.dart';
import 'profile_page.dart';
import 'other_user_profile_page.dart';

class DeviceDetailPage extends StatefulWidget {
  final Seki seki;

  const DeviceDetailPage({super.key, required this.seki});

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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please sign in to use this feature')),
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
      }

      if (mounted && _isWantingDevice == true) {
        setState(() => _isWantingDevice = false);
      }
    } catch (e) {
      // Silently fail - not critical
    }
  }

  void _openDeviceSheet({required bool stillUsing}) {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    if (currentUserId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please sign in to add a device')),
      );
      return;
    }

    // If user has existing device, open Edit sheet; otherwise open Add sheet
    final existingDevice = _userDeviceEntry;
    
    showModalBottomSheet(
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
    ).then((_) async {
      // Refresh device status after sheet closes
      await _checkUserDeviceStatus();
      
      // If device was just added and Want was active, clear it
      if (_userDeviceEntry != null && _isWantingDevice == true) {
        await _clearWantState();
      }
    });
  }

  String _getStatus(Seki seki) {
    final isActive = seki.isPreciseMode 
        ? (seki.endTime == null) 
        : (seki.endYear == null);
    return isActive ? 'Active' : 'Vintage';
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

  IconData _getIconForDeviceType(String deviceType) {
    // Map device type to icon using deviceCategories
    for (final category in deviceCategories) {
      if (category.deviceType == deviceType) {
        return category.icon;
      }
    }
    return Icons.devices; // Default fallback
  }

  void _showEditSekiBottomSheet(Seki seki) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => AddDevicePage(seki: seki),
    );
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
          Navigator.of(context).pop();
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

        return Scaffold(
          backgroundColor: scaffoldBg,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            leading: IconButton(
              icon: Icon(
                Icons.arrow_back,
                color: theme.colorScheme.onSurface,
              ),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ),
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
              child: SingleChildScrollView(
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
                          _getIconForDeviceType(seki.deviceType),
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
                        color: valueColor,
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
                    // Usage Selector (for non-owners)
                    if (!isOwner) ...[
                      const SizedBox(height: 24),
                      _buildUsageSelector(seki),
                    ],
                    // Action Buttons (for owners)
                    if (isOwner) ...[
                      const SizedBox(height: 24),
                      _buildActionButtons(seki, theme),
                    ],
                    const SizedBox(height: 40),
                  ],
                ),
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


  Widget _buildActionButtons(Seki seki, ThemeData theme) {
    return Row(
      children: [
        Expanded(
          child: ElevatedButton.icon(
            onPressed: () => _showEditSekiBottomSheet(seki),
            icon: const Icon(Icons.edit_outlined, size: 20),
            label: const Text('Edit'),
            style: ElevatedButton.styleFrom(
              backgroundColor: theme.colorScheme.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              elevation: 2,
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
              side: BorderSide(color: Colors.red.withOpacity(0.5)),
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
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
                    Icons.folder_outlined,
                    size: 16,
                    color: labelColor,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'MEMORIES',
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


  Widget _buildUsageSelector(Seki seki) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    final isOwner = currentUserId != null && currentUserId == seki.uid;
    
    // Don't show selector for owner's own device
    if (isOwner) {
      return const SizedBox.shrink();
    }

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

    final buttonBg = isDark
        ? theme.colorScheme.surface.withOpacity(0.3)
        : Colors.white;
    final buttonTextColor = theme.colorScheme.onSurface.withOpacity(0.8);
    final buttonTextColorActive = theme.colorScheme.primary;
    final buttonBorderColor = isDark
        ? theme.colorScheme.onSurface.withOpacity(0.1)
        : Colors.grey.shade200;
    final buttonBorderColorActive = theme.colorScheme.primary.withOpacity(0.5);

    return Row(
      children: [
        // Used button
        Expanded(
          child: _UsageButton(
            label: 'Used',
            icon: Icons.history,
            isActive: isUsedActive,
            backgroundColor: buttonBg,
            textColor: isUsedActive ? buttonTextColorActive : buttonTextColor,
            borderColor: isUsedActive ? buttonBorderColorActive : buttonBorderColor,
            onTap: () => _openDeviceSheet(stillUsing: false),
          ),
        ),
        const SizedBox(width: 12),
        // Using button
        Expanded(
          child: _UsageButton(
            label: 'Using',
            icon: Icons.circle,
            isActive: isUsingActive,
            backgroundColor: buttonBg,
            textColor: isUsingActive ? buttonTextColorActive : buttonTextColor,
            borderColor: isUsingActive ? buttonBorderColorActive : buttonBorderColor,
            onTap: () => _openDeviceSheet(stillUsing: true),
          ),
        ),
        const SizedBox(width: 12),
        // Want button
        Expanded(
          child: _UsageButton(
            label: 'Want',
            icon: isWanting ? Icons.star : Icons.star_outline,
            isActive: isWanting,
            backgroundColor: buttonBg,
            textColor: isWanting ? buttonTextColorActive : buttonTextColor,
            borderColor: isWanting ? buttonBorderColorActive : buttonBorderColor,
            onTap: _toggleWant,
          ),
        ),
      ],
    );
  }
}

class _UsageButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isActive;
  final Color backgroundColor;
  final Color textColor;
  final Color borderColor;
  final VoidCallback? onTap;

  const _UsageButton({
    required this.label,
    required this.icon,
    required this.isActive,
    required this.backgroundColor,
    required this.textColor,
    required this.borderColor,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final iconColor = isActive 
        ? textColor 
        : textColor.withOpacity(0.6);
    
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: borderColor,
              width: isActive ? 1.5 : 1,
            ),
          ),
          child: Center(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  icon,
                  size: 14,
                  color: iconColor,
                ),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: TextStyle(
                    color: textColor,
                    fontSize: 14,
                    fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
                  ),
                ),
                if (isActive) ...[
                  const SizedBox(width: 4),
                  Icon(
                    Icons.check,
                    size: 16,
                    color: textColor,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
