import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../models/seki_model.dart';
import '../models/want_model.dart';
import '../services/system_ui_service.dart';
import '../widgets/timeline_seki_item.dart';
import '../widgets/seki_card.dart';
import '../pages/device_detail_page.dart';

/// Custom delegate for pinned TabBar in NestedScrollView
class _OtherUserSliverAppBarDelegate extends SliverPersistentHeaderDelegate {
  final TabBar tabBar;
  final Color backgroundColor;
  final int deviceCount;
  final int wantCount;

  _OtherUserSliverAppBarDelegate(
    this.tabBar, {
    required this.backgroundColor,
    required this.deviceCount,
    required this.wantCount,
  });

  @override
  double get minExtent => tabBar.preferredSize.height;

  @override
  double get maxExtent => tabBar.preferredSize.height;

  @override
  Widget build(
      BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      color: backgroundColor,
      child: tabBar,
    );
  }

  @override
  bool shouldRebuild(_OtherUserSliverAppBarDelegate oldDelegate) {
    return backgroundColor != oldDelegate.backgroundColor ||
        deviceCount != oldDelegate.deviceCount ||
        wantCount != oldDelegate.wantCount;
  }
}

class OtherUserProfilePage extends StatefulWidget {
  final String publisherId;

  const OtherUserProfilePage({super.key, required this.publisherId});

  @override
  State<OtherUserProfilePage> createState() => _OtherUserProfilePageState();
}

class _OtherUserProfilePageState extends State<OtherUserProfilePage> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  /// Gets all active devices from a list of Sekis.
  /// An active device is one where endYear/endTime is null.
  /// Returns a list of active Sekis, or empty list if none found.
  List<Seki> _getActiveDevices(List<Seki> sekis) {
    final activeSekis = sekis.where((seki) => 
      seki.isPreciseMode ? (seki.endTime == null) : (seki.endYear == null)
    ).toList();
    if (activeSekis.isEmpty) {
      return [];
    }
    // Sort by startYear descending to get the latest first
    activeSekis.sort((a, b) => b.startYear.compareTo(a.startYear));
    return activeSekis;
  }

  /// Calculate adaptive height based on content
  double _calculateHeaderHeight(String bio, List<Seki> activeDevices) {
    double baseHeight = 140.0; // Base height for username and email
    if (bio.isNotEmpty) {
      // Estimate bio height (approximate 1.5 line height * font size)
      final bioLines = (bio.length / 40).ceil(); // Rough estimate: ~40 chars per line
      baseHeight += 12 + (bioLines * 20.0); // 12 for spacing + line height
    }
    if (activeDevices.isNotEmpty) {
      baseHeight += 16; // Spacing before "In Use"
      // Estimate device chips height (max 60px with scrolling)
      baseHeight += 60.0;
    }
    return baseHeight.clamp(200.0, 400.0); // Clamp between 200 and 400
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final scaffoldBg = isDark ? const Color(0xFF02081A) : const Color(0xFFF5F5F5);
    
    // Set immersive status bar
    SystemUIService.setImmersiveStatusBar(context, backgroundColor: scaffoldBg);

    return Scaffold(
      backgroundColor: scaffoldBg,
      body: SafeArea(
        child: StreamBuilder<DocumentSnapshot>(
          stream: FirebaseFirestore.instance
              .collection('users')
              .doc(widget.publisherId)
              .snapshots(),
          builder: (context, userSnapshot) {
            if (userSnapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            if (!userSnapshot.hasData || !userSnapshot.data!.exists) {
              return Center(
                child: Text(
                  'User information not available',
                  style: TextStyle(
                    color: theme.colorScheme.onSurface.withOpacity(0.7),
                    fontSize: 14,
                  ),
                ),
              );
            }

            final userData = userSnapshot.data!.data() as Map<String, dynamic>;
            final username = userData['username'] as String? ?? 'Unknown';
            final email = userData['email'] as String? ?? 'Unknown';
            final bio = userData['bio'] as String? ?? '';

            return StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('seki')
                  .where('publisherId', isEqualTo: widget.publisherId)
                  .snapshots(),
              builder: (context, sekiSnapshot) {
                List<Seki> activeDevices = [];
                int deviceCount = 0;
                
                if (sekiSnapshot.hasData && sekiSnapshot.data!.docs.isNotEmpty) {
                  final sekis = sekiSnapshot.data!.docs
                      .map((doc) => Seki.fromFirestore(doc))
                      .toList();
                  activeDevices = _getActiveDevices(sekis);
                  deviceCount = sekiSnapshot.data!.docs.length;
                } else if (sekiSnapshot.hasData && sekiSnapshot.data!.docs.isEmpty) {
                  // Fallback to uid query for device count
                  return StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('seki')
                        .where('uid', isEqualTo: widget.publisherId)
                        .snapshots(),
                    builder: (context, fallbackSekiSnapshot) {
                      List<Seki> fallbackActiveDevices = [];
                      int fallbackDeviceCount = 0;
                      
                      if (fallbackSekiSnapshot.hasData && fallbackSekiSnapshot.data!.docs.isNotEmpty) {
                        final sekis = fallbackSekiSnapshot.data!.docs
                            .map((doc) => Seki.fromFirestore(doc))
                            .toList();
                        fallbackActiveDevices = _getActiveDevices(sekis);
                        fallbackDeviceCount = fallbackSekiSnapshot.data!.docs.length;
                      }

                      return StreamBuilder<QuerySnapshot>(
                        stream: FirebaseFirestore.instance
                            .collection('wants')
                            .where('uid', isEqualTo: widget.publisherId)
                            .snapshots(),
                        builder: (context, wantSnapshot) {
                          final wantCount = wantSnapshot.hasData 
                              ? wantSnapshot.data!.docs.length 
                              : 0;

                    return _buildNestedScrollView(
                      context,
                      theme,
                      isDark,
                      scaffoldBg,
                      username,
                      email,
                      bio,
                      fallbackActiveDevices,
                      fallbackDeviceCount,
                      wantCount,
                      true,
                    );
                        },
                      );
                    },
                  );
                }

                return StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('wants')
                      .where('uid', isEqualTo: widget.publisherId)
                      .snapshots(),
                  builder: (context, wantSnapshot) {
                    final wantCount = wantSnapshot.hasData 
                        ? wantSnapshot.data!.docs.length 
                        : 0;

                    return _buildNestedScrollView(
                      context,
                      theme,
                      isDark,
                      scaffoldBg,
                      username,
                      email,
                      bio,
                      activeDevices,
                      deviceCount,
                      wantCount,
                      false,
                    );
                  },
                );
              },
            );
          },
        ),
      ),
    );
  }

  Widget _buildNestedScrollView(
    BuildContext context,
    ThemeData theme,
    bool isDark,
    Color scaffoldBg,
    String username,
    String email,
    String bio,
    List<Seki> activeDevices,
    int deviceCount,
    int wantCount,
    bool useUidQuery,
  ) {
    final headerHeight = _calculateHeaderHeight(bio, activeDevices);
    
    return NestedScrollView(
      headerSliverBuilder: (BuildContext context, bool innerBoxIsScrolled) {
        return [
          SliverAppBar(
            backgroundColor: scaffoldBg,
            elevation: 0,
            pinned: false,
            floating: false,
            expandedHeight: headerHeight,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back),
              color: theme.colorScheme.onSurface.withOpacity(0.7),
              tooltip: 'Back',
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: BoxDecoration(
                  color: isDark
                      ? theme.colorScheme.surfaceContainerHighest.withOpacity(0.3)
                      : theme.colorScheme.surfaceContainerHighest.withOpacity(0.5),
                ),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    return SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(24, 60, 24, 24),
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          minHeight: constraints.maxHeight - 84,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                      Row(
                        children: [
                          Icon(
                            Icons.person,
                            size: 24,
                            color: theme.colorScheme.primary,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              username,
                              style: theme.textTheme.headlineSmall?.copyWith(
                                fontWeight: FontWeight.w600,
                                color: theme.colorScheme.onSurface,
                              ) ?? TextStyle(
                                color: theme.colorScheme.onSurface,
                                fontSize: 24,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Icon(
                            Icons.email,
                            size: 18,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              email,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ) ?? TextStyle(
                                color: theme.colorScheme.onSurfaceVariant,
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
                              size: 18,
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                bio,
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                  height: 1.5,
                                ) ?? TextStyle(
                                  color: theme.colorScheme.onSurfaceVariant,
                                  fontSize: 14,
                                  height: 1.5,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                      if (activeDevices.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'In Use:',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: theme.colorScheme.primary,
                                fontWeight: FontWeight.w500,
                              ) ?? TextStyle(
                                color: theme.colorScheme.primary,
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: ConstrainedBox(
                                constraints: const BoxConstraints(maxHeight: 60),
                                child: SingleChildScrollView(
                                  scrollDirection: Axis.vertical,
                                  child: Wrap(
                                    spacing: 8,
                                    runSpacing: 6,
                                    children: activeDevices.map((seki) {
                                      return InkWell(
                                        onTap: () {
                                          Navigator.of(context).push(
                                            MaterialPageRoute(
                                              builder: (context) => DeviceDetailPage(seki: seki),
                                            ),
                                          );
                                        },
                                        borderRadius: BorderRadius.circular(12),
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 10,
                                            vertical: 4,
                                          ),
                                          decoration: BoxDecoration(
                                            color: theme.colorScheme.primaryContainer,
                                            borderRadius: BorderRadius.circular(12),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(
                                                getIconByDeviceName(seki.deviceName),
                                                size: 16,
                                                color: theme.colorScheme.onPrimaryContainer,
                                              ),
                                              const SizedBox(width: 6),
                                              Text(
                                                seki.deviceName,
                                                style: theme.textTheme.labelMedium?.copyWith(
                                                  color: theme.colorScheme.onPrimaryContainer,
                                                  fontWeight: FontWeight.w500,
                                                ) ?? TextStyle(
                                                  color: theme.colorScheme.onPrimaryContainer,
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.w500,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      );
                                    }).toList(),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
          SliverPersistentHeader(
            pinned: true,
            delegate: _OtherUserSliverAppBarDelegate(
              TabBar(
                key: ValueKey('tabbar_${deviceCount}_${wantCount}'),
                controller: _tabController,
                tabs: [
                  Tab(
                    child: AnimatedBuilder(
                      animation: _tabController,
                      builder: (context, child) {
                        final isSelected = _tabController.index == 0;
                        final textColor = isSelected
                            ? theme.colorScheme.primary
                            : theme.colorScheme.onSurfaceVariant;
                        return Row(
                          mainAxisSize: MainAxisSize.min,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              'Owned',
                              style: TextStyle(color: textColor),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              '$deviceCount',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                                color: textColor,
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                  Tab(
                    child: AnimatedBuilder(
                      animation: _tabController,
                      builder: (context, child) {
                        final isSelected = _tabController.index == 1;
                        final textColor = isSelected
                            ? theme.colorScheme.primary
                            : theme.colorScheme.onSurfaceVariant;
                        return Row(
                          mainAxisSize: MainAxisSize.min,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              'Wants',
                              style: TextStyle(color: textColor),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              '$wantCount',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                                color: textColor,
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                ],
                labelColor: theme.colorScheme.primary,
                unselectedLabelColor: theme.colorScheme.onSurfaceVariant,
                indicatorColor: theme.colorScheme.primary,
                indicatorWeight: 3,
              ),
              backgroundColor: scaffoldBg,
              deviceCount: deviceCount,
              wantCount: wantCount,
            ),
          ),
        ];
      },
      body: TabBarView(
        controller: _tabController,
        children: [
          // Owned tab
          _buildOwnedTab(context, theme, isDark, useUidQuery),
          // Wants tab
          _buildWantsTab(context, theme, isDark),
        ],
      ),
    );
  }

  Widget _buildOwnedTab(BuildContext context, ThemeData theme, bool isDark, bool useUidQuery) {
    return StreamBuilder<QuerySnapshot>(
      stream: useUidQuery
          ? FirebaseFirestore.instance
              .collection('seki')
              .where('uid', isEqualTo: widget.publisherId)
              .snapshots()
          : FirebaseFirestore.instance
              .collection('seki')
              .where('publisherId', isEqualTo: widget.publisherId)
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

        return _buildSekiList(
          snapshot.data!.docs,
          theme,
          isDark,
        );
      },
    );
  }

  Widget _buildWantsTab(BuildContext context, ThemeData theme, bool isDark) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('wants')
          .where('uid', isEqualTo: widget.publisherId)
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
              'Failed to load wants: ${snapshot.error}',
              style: TextStyle(
                color: theme.colorScheme.onSurface.withOpacity(0.7),
              ),
            ),
          );
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(32.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.star_outline,
                    size: 72,
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
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          itemCount: wants.length,
          itemBuilder: (context, index) {
            final want = wants[index];
            return ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
                // Try to find the seki by device name and publisherId
                FirebaseFirestore.instance
                    .collection('seki')
                    .where('deviceName', isEqualTo: want.deviceName)
                    .where('publisherId', isEqualTo: widget.publisherId)
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
                    // Fallback to uid query
                    FirebaseFirestore.instance
                        .collection('seki')
                        .where('deviceName', isEqualTo: want.deviceName)
                        .where('uid', isEqualTo: widget.publisherId)
                        .limit(1)
                        .get()
                        .then((fallbackQuerySnapshot) {
                      if (fallbackQuerySnapshot.docs.isNotEmpty) {
                        final seki = Seki.fromFirestore(fallbackQuerySnapshot.docs.first);
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
                  }
                });
              },
            );
          },
        );
      },
    );
  }

  Widget _buildSekiList(
    List<QueryDocumentSnapshot> docs,
    ThemeData theme,
    bool isDark,
  ) {
    // Sort by startYear/startTime in ascending order
    docs.sort((a, b) {
      final aData = a.data() as Map<String, dynamic>;
      final bData = b.data() as Map<String, dynamic>;
      
      // Handle both old (startYear) and new (startTime) formats
      int aStartYear;
      int bStartYear;
      
      if (aData['isPreciseMode'] == true && aData['startTime'] != null) {
        final aStartTime = aData['startTime'] as Timestamp;
        aStartYear = aStartTime.toDate().year;
      } else {
        aStartYear = aData['startYear'] as int? ?? 0;
      }
      
      if (bData['isPreciseMode'] == true && bData['startTime'] != null) {
        final bStartTime = bData['startTime'] as Timestamp;
        bStartYear = bStartTime.toDate().year;
      } else {
        bStartYear = bData['startYear'] as int? ?? 0;
      }
      
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
