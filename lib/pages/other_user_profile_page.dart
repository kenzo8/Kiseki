import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../models/seki_model.dart';
import '../widgets/timeline_seki_item.dart';
import '../widgets/seki_card.dart';

class OtherUserProfilePage extends StatelessWidget {
  final String publisherId;

  const OtherUserProfilePage({super.key, required this.publisherId});

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

    return Scaffold(
      backgroundColor: scaffoldBg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          color: theme.colorScheme.onSurface.withOpacity(0.7),
          tooltip: 'Back',
          onPressed: () {
            Navigator.of(context).pop();
          },
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            // User Info Section
            StreamBuilder<DocumentSnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('users')
                  .doc(publisherId)
                  .snapshots(),
              builder: (context, userSnapshot) {
                if (userSnapshot.connectionState == ConnectionState.waiting) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                    child: Card(
                      color: theme.colorScheme.surface.withOpacity(0.1),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Padding(
                        padding: EdgeInsets.all(16),
                        child: Center(
                          child: CircularProgressIndicator(),
                        ),
                      ),
                    ),
                  );
                }

                if (userSnapshot.hasData && userSnapshot.data!.exists) {
                  final userData = userSnapshot.data!.data() as Map<String, dynamic>;
                  final username = userData['username'] as String? ?? 'Unknown';
                  final email = userData['email'] as String? ?? 'Unknown';
                  final bio = userData['bio'] as String? ?? '';

                  return StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('seki')
                        .where('publisherId', isEqualTo: publisherId)
                        .snapshots(),
                    builder: (context, sekiSnapshot) {
                      List<Seki> activeDevices = [];
                      if (sekiSnapshot.hasData && sekiSnapshot.data!.docs.isNotEmpty) {
                        final sekis = sekiSnapshot.data!.docs
                            .map((doc) => Seki.fromFirestore(doc))
                            .toList();
                        activeDevices = _getActiveDevices(sekis);
                      } else if (sekiSnapshot.hasData && sekiSnapshot.data!.docs.isEmpty) {
                        // Fallback to uid query
                        return StreamBuilder<QuerySnapshot>(
                          stream: FirebaseFirestore.instance
                              .collection('seki')
                              .where('uid', isEqualTo: publisherId)
                              .snapshots(),
                          builder: (context, fallbackSekiSnapshot) {
                            List<Seki> fallbackActiveDevices = [];
                            if (fallbackSekiSnapshot.hasData && fallbackSekiSnapshot.data!.docs.isNotEmpty) {
                              final sekis = fallbackSekiSnapshot.data!.docs
                                  .map((doc) => Seki.fromFirestore(doc))
                                  .toList();
                              fallbackActiveDevices = _getActiveDevices(sekis);
                            }
                            return _buildUserInfoCard(
                              username: username,
                              email: email,
                              bio: bio,
                              activeDevices: fallbackActiveDevices,
                              theme: theme,
                            );
                          },
                        );
                      }

                      return _buildUserInfoCard(
                        username: username,
                        email: email,
                        bio: bio,
                        activeDevices: activeDevices,
                        theme: theme,
                      );
                    },
                  );
                }
                // If user document doesn't exist, show a placeholder
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
                      child: Text(
                        'User information not available',
                        style: TextStyle(
                          color: theme.colorScheme.onSurface.withOpacity(0.7),
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 8),
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('seki')
                    .where('publisherId', isEqualTo: publisherId)
                    .snapshots(),
                builder: (context, snapshot) {
                  // Fallback to uid if publisherId query returns no results (for backward compatibility)
                  if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                    return StreamBuilder<QuerySnapshot>(
                      stream: FirebaseFirestore.instance
                          .collection('seki')
                          .where('uid', isEqualTo: publisherId)
                          .snapshots(),
                      builder: (context, fallbackSnapshot) {
                        if (fallbackSnapshot.connectionState == ConnectionState.waiting) {
                          return Center(
                            child: CircularProgressIndicator(
                              valueColor: AlwaysStoppedAnimation<Color>(theme.colorScheme.primary),
                            ),
                          );
                        }

                        if (fallbackSnapshot.hasError) {
                          return Center(
                            child: Text(
                              'Failed to load: ${fallbackSnapshot.error}',
                              style: TextStyle(color: theme.colorScheme.onSurface.withOpacity(0.7)),
                            ),
                          );
                        }

                        if (!fallbackSnapshot.hasData || fallbackSnapshot.data!.docs.isEmpty) {
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

                        return _buildSekiList(
                          fallbackSnapshot.data!.docs,
                          theme,
                          isDark,
                        );
                      },
                    );
                  }

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

                  return _buildSekiList(
                    snapshot.data!.docs,
                    theme,
                    isDark,
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUserInfoCard({
    required String username,
    required String email,
    required String bio,
    List<Seki> activeDevices = const [],
    required ThemeData theme,
  }) {
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
                  Expanded(
                    child: Text(
                      username,
                      style: TextStyle(
                        color: theme.colorScheme.onSurface,
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
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
  }

  Widget _buildSekiList(
    List<QueryDocumentSnapshot> docs,
    ThemeData theme,
    bool isDark,
  ) {
    // Sort by startYear in ascending order
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
        );
      },
    );
  }
}
