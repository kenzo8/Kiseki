import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../models/seki_model.dart';
import '../models/want_model.dart';
import '../services/system_ui_service.dart';
import '../pages/settings_page.dart';
import '../pages/device_detail_page.dart';
import '../pages/add_device_page.dart';
import '../widgets/timeline_seki_item.dart';
import '../widgets/seki_card.dart';

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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final scaffoldBg = isDark ? const Color(0xFF02081A) : const Color(0xFFF5F5F5);
    
    // Set immersive status bar
    SystemUIService.setImmersiveStatusBar(context, backgroundColor: scaffoldBg);

    if (widget.user == null) {
      return Scaffold(
        backgroundColor: scaffoldBg,
        body: Center(
          child: Text(
            'Please sign in to view profile',
            style: TextStyle(color: theme.colorScheme.onSurface.withOpacity(0.7)),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: scaffoldBg,
      body: SafeArea(
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
                                            return Text(
                                              seki.deviceName,
                                              style: TextStyle(
                                                color: theme.colorScheme.onSurface.withOpacity(0.8),
                                                fontSize: 14,
                                                fontWeight: FontWeight.w400,
                                              ),
                                            );
                                          }).toList(),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                                // Devices count section
                                const SizedBox(height: 12),
                                Row(
                                  children: [
                                    Text(
                                      'Devices:',
                                      style: TextStyle(
                                        color: theme.colorScheme.primary.withOpacity(0.8),
                                        fontSize: 14,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      '${sekiSnapshot.hasData ? sekiSnapshot.data!.docs.length : 0}',
                                      style: TextStyle(
                                        color: theme.colorScheme.onSurface.withOpacity(0.8),
                                        fontSize: 14,
                                        fontWeight: FontWeight.w400,
                                      ),
                                    ),
                                  ],
                                ),
                                // Want section
                                const SizedBox(height: 12),
                                StreamBuilder<QuerySnapshot>(
                                  stream: FirebaseFirestore.instance
                                      .collection('wants')
                                      .where('uid', isEqualTo: FirebaseAuth.instance.currentUser?.uid ?? '')
                                      .snapshots(),
                                  builder: (context, wantSnapshot) {
                                    final wantCount = wantSnapshot.hasData 
                                        ? wantSnapshot.data!.docs.length 
                                        : 0;
                                    
                                    return InkWell(
                                      onTap: wantCount > 0 ? () => _showWantsBottomSheet(context, theme, isDark) : null,
                                      borderRadius: BorderRadius.circular(8),
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(vertical: 4),
                                        child: Row(
                                          children: [
                                            Text(
                                              'Want:',
                                              style: TextStyle(
                                                color: theme.colorScheme.primary.withOpacity(0.8),
                                                fontSize: 14,
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            Text(
                                              '$wantCount',
                                              style: TextStyle(
                                                color: theme.colorScheme.onSurface.withOpacity(0.8),
                                                fontSize: 14,
                                                fontWeight: FontWeight.w400,
                                              ),
                                            ),
                                            if (wantCount > 0) ...[
                                              const SizedBox(width: 8),
                                              Icon(
                                                Icons.chevron_right,
                                                size: 16,
                                                color: theme.colorScheme.onSurface.withOpacity(0.4),
                                              ),
                                            ],
                                          ],
                                        ),
                                      ),
                                    );
                                  },
                                ),
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
                    return _buildEmptyState(context, theme);
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
                    return _buildEmptyState(context, theme);
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
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (context) => DeviceDetailPage(seki: seki),
                            ),
                          );
                        },
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

  void _showWantsBottomSheet(BuildContext context, ThemeData theme, bool isDark) {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    if (currentUserId == null) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        final surfaceColor = isDark
            ? theme.colorScheme.surface.withOpacity(0.95)
            : Colors.white;

        return Container(
          decoration: BoxDecoration(
            color: surfaceColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 8),
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.onSurface.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 16),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      Icon(
                        Icons.star,
                        color: theme.colorScheme.primary,
                        size: 24,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Want List',
                        style: TextStyle(
                          color: theme.colorScheme.onSurface,
                          fontSize: 20,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Flexible(
                  child: StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('wants')
                        .where('uid', isEqualTo: currentUserId)
                        .snapshots(),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(
                          child: Padding(
                            padding: EdgeInsets.all(32.0),
                            child: CircularProgressIndicator(),
                          ),
                        );
                      }

                      if (snapshot.hasError) {
                        return Center(
                          child: Padding(
                            padding: const EdgeInsets.all(32.0),
                            child: Text(
                              'Failed to load wants: ${snapshot.error}',
                              style: TextStyle(
                                color: theme.colorScheme.onSurface.withOpacity(0.7),
                              ),
                            ),
                          ),
                        );
                      }

                      if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                        return Center(
                          child: Padding(
                            padding: const EdgeInsets.all(32.0),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.star_outline,
                                  size: 48,
                                  color: theme.colorScheme.onSurface.withOpacity(0.3),
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  'No wants yet',
                                  style: TextStyle(
                                    color: theme.colorScheme.onSurface.withOpacity(0.7),
                                    fontSize: 16,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }

                      final wants = snapshot.data!.docs
                          .map((doc) => Want.fromFirestore(doc))
                          .toList();

                      return ListView.builder(
                        shrinkWrap: true,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        itemCount: wants.length,
                        itemBuilder: (context, index) {
                          final want = wants[index];
                          return ListTile(
                            leading: Container(
                              width: 48,
                              height: 48,
                              decoration: BoxDecoration(
                                color: isDark
                                    ? Colors.white.withOpacity(0.08)
                                    : Colors.grey.shade100,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Icon(
                                getIconByDeviceName(want.deviceName),
                                color: theme.colorScheme.onSurface.withOpacity(0.7),
                                size: 24,
                              ),
                            ),
                            title: Text(
                              want.deviceName,
                              style: TextStyle(
                                color: theme.colorScheme.onSurface,
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            subtitle: Text(
                              want.deviceType,
                              style: TextStyle(
                                color: theme.colorScheme.onSurface.withOpacity(0.6),
                                fontSize: 14,
                              ),
                            ),
                            onTap: () {
                              // Navigate to device detail page if we can find the seki
                              Navigator.pop(context);
                              // Try to find the seki by device name
                              FirebaseFirestore.instance
                                  .collection('seki')
                                  .where('deviceName', isEqualTo: want.deviceName)
                                  .limit(1)
                                  .get()
                                  .then((querySnapshot) {
                                if (querySnapshot.docs.isNotEmpty) {
                                  final seki = Seki.fromFirestore(querySnapshot.docs.first);
                                  Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (context) => DeviceDetailPage(seki: seki),
                                    ),
                                  );
                                } else {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('Device "${want.deviceName}" not found'),
                                    ),
                                  );
                                }
                              });
                            },
                          );
                        },
                      );
                    },
                  ),
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildEmptyState(BuildContext context, ThemeData theme) {
    return Container(
      width: double.infinity,
      color: Colors.white,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Top illustration
              Opacity(
                opacity: 0.4,
                child: Icon(
                  Icons.devices_outlined,
                  size: 72,
                  color: theme.colorScheme.onSurface.withOpacity(0.3),
                ),
              ),
              const SizedBox(height: 24),
              // Main text
              Text(
                "Add a device you've used",
                style: TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.onSurface,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              // Action button
              OutlinedButton(
                onPressed: () {
                  showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    backgroundColor: Colors.transparent,
                    builder: (context) => const AddDevicePage(),
                  );
                },
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 32,
                    vertical: 12,
                  ),
                  minimumSize: const Size(0, 46),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24),
                  ),
                  side: BorderSide(
                    color: theme.colorScheme.onSurface.withOpacity(0.2),
                    width: 1,
                  ),
                ),
                child: Text(
                  'Add',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
