import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../models/seki_model.dart';
import '../services/system_ui_service.dart';
import '../services/profile_data_service.dart';
import '../pages/settings_page.dart';
import '../pages/device_detail_page.dart';
import '../pages/add_device_page.dart';
import '../widgets/timeline_seki_item.dart';
import '../widgets/seki_card.dart';

/// Custom delegate for pinned TabBar in NestedScrollView
class _SliverAppBarDelegate extends SliverPersistentHeaderDelegate {
  final TabBar tabBar;
  final Color backgroundColor;
  final int deviceCount;
  final int wantCount;

  _SliverAppBarDelegate(
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
  bool shouldRebuild(_SliverAppBarDelegate oldDelegate) {
    return backgroundColor != oldDelegate.backgroundColor ||
        deviceCount != oldDelegate.deviceCount ||
        wantCount != oldDelegate.wantCount;
  }
}

class ProfilePage extends StatefulWidget {
  final User? user;

  const ProfilePage({super.key, required this.user});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> 
    with SingleTickerProviderStateMixin, AutomaticKeepAliveClientMixin {
  late TabController _tabController;
  final ProfileDataService _dataService = ProfileDataService.instance;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    
    // Initialize data service if user is available
    if (widget.user?.uid != null) {
      _dataService.initialize(widget.user!.uid);
    }
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

  /// Check if this ProfilePage is displayed as a main page (in IndexedStack)
  /// Main pages should never show a back button to prevent black screen issues
  bool _isMainPage(BuildContext context) {
    // Check if this is the first route (main page)
    // This is the most reliable way to detect if we're on a main page
    final route = ModalRoute.of(context);
    return route?.isFirst ?? false;
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // Required for AutomaticKeepAliveClientMixin
    
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

    // Ensure service is initialized every time build is called
    // This ensures streams are active even if page was kept alive
    if (widget.user?.uid != null) {
      _dataService.initialize(widget.user!.uid);
    }

    // Check if this is a main page (should not show back button)
    final isMainPage = _isMainPage(context);

    return Scaffold(
      backgroundColor: scaffoldBg,
      body: SafeArea(
        child: ListenableBuilder(
          listenable: _dataService,
          builder: (context, _) {
            // Get cached user data
            final userSnapshot = _dataService.cachedUserData;
            if (userSnapshot == null || !userSnapshot.exists) {
              if (_dataService.isLoadingUserData) {
                return const Center(child: CircularProgressIndicator());
              }
              return const Center(child: Text('User data not found'));
            }

            final userData = userSnapshot.data() as Map<String, dynamic>;
            final username = userData['username'] as String? ?? 'Unknown';
            final email = userData['email'] as String? ?? widget.user?.email ?? 'Unknown';
            final bio = userData['bio'] as String? ?? '';

            // Get cached seki data
            final sekis = _dataService.cachedSekis ?? [];
            final activeDevices = _getActiveDevices(sekis);
            final deviceCount = sekis.length;

            // Get cached wants data
            final wants = _dataService.cachedWants ?? [];
            final wantCount = wants.length;

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
                    // Only show back button if NOT a main page AND can pop
                    leading: (!isMainPage && Navigator.canPop(context))
                        ? IconButton(
                            icon: const Icon(Icons.arrow_back),
                            color: theme.colorScheme.onSurface.withOpacity(0.7),
                            tooltip: 'Back',
                            onPressed: () {
                              Navigator.of(context).pop();
                            },
                          )
                        : const SizedBox.shrink(),
                    actions: [
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
                    delegate: _SliverAppBarDelegate(
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
                  _OwnedTab(theme: theme, isDark: isDark),
                  // Wants tab
                  _WantsTab(theme: theme, isDark: isDark),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

/// Owned tab widget with AutomaticKeepAliveClientMixin and pull-to-refresh
class _OwnedTab extends StatefulWidget {
  final ThemeData theme;
  final bool isDark;

  const _OwnedTab({required this.theme, required this.isDark});

  @override
  State<_OwnedTab> createState() => _OwnedTabState();
}

class _OwnedTabState extends State<_OwnedTab> with AutomaticKeepAliveClientMixin {
  final ProfileDataService _dataService = ProfileDataService.instance;

  @override
  bool get wantKeepAlive => true;

  List<Seki> _sortSekis(List<Seki> sekis) {
    final sorted = List<Seki>.from(sekis);
    sorted.sort((a, b) {
      final aYear = a.isPreciseMode && a.startTime != null
          ? a.startTime!.toDate().year
          : a.startYear;
      final bYear = b.isPreciseMode && b.startTime != null
          ? b.startTime!.toDate().year
          : b.startYear;
      return aYear.compareTo(bYear); // Ascending order
    });
    return sorted;
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // Required for AutomaticKeepAliveClientMixin

    return ListenableBuilder(
      listenable: _dataService,
      builder: (context, _) {
        if (_dataService.isLoadingSekis && _dataService.cachedSekis == null) {
          return Center(
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(widget.theme.colorScheme.primary),
            ),
          );
        }

        final sekis = _dataService.cachedSekis ?? [];
        if (sekis.isEmpty) {
          return _buildEmptyState(context, widget.theme);
        }

        final sortedSekis = _sortSekis(sekis);
        
        // Determine which items should show the year
        final shouldShowYear = <bool>[];
        int? previousYear;
        
        for (final seki in sortedSekis) {
          final currentYear = seki.isPreciseMode && seki.startTime != null
              ? seki.startTime!.toDate().year
              : seki.startYear;
          
          final showYear = previousYear == null || previousYear != currentYear;
          shouldShowYear.add(showYear);
          previousYear = currentYear;
        }

        return RefreshIndicator(
          onRefresh: () => _dataService.refresh(),
          color: widget.theme.colorScheme.primary,
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            itemCount: sortedSekis.length,
            itemBuilder: (context, index) {
              final seki = sortedSekis[index];
              final isLast = index == sortedSekis.length - 1;
              return TimelineSekiItem(
                seki: seki,
                isDark: widget.isDark,
                isLast: isLast,
                showYear: shouldShowYear[index],
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => DeviceDetailPage(seki: seki),
                    ),
                  );
                },
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildEmptyState(BuildContext context, ThemeData theme) {
    return RefreshIndicator(
      onRefresh: () => _dataService.refresh(),
      color: theme.colorScheme.primary,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: Container(
          width: double.infinity,
          height: MediaQuery.of(context).size.height * 0.6,
          color: Colors.white,
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Opacity(
                    opacity: 0.4,
                    child: Icon(
                      Icons.devices_outlined,
                      size: 72,
                      color: theme.colorScheme.onSurface.withOpacity(0.3),
                    ),
                  ),
                  const SizedBox(height: 24),
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
        ),
      ),
    );
  }
}

/// Wants tab widget with AutomaticKeepAliveClientMixin and pull-to-refresh
class _WantsTab extends StatefulWidget {
  final ThemeData theme;
  final bool isDark;

  const _WantsTab({required this.theme, required this.isDark});

  @override
  State<_WantsTab> createState() => _WantsTabState();
}

class _WantsTabState extends State<_WantsTab> with AutomaticKeepAliveClientMixin {
  final ProfileDataService _dataService = ProfileDataService.instance;

  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context); // Required for AutomaticKeepAliveClientMixin

    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    if (currentUserId == null) {
      return const Center(child: Text('Please sign in'));
    }

    return ListenableBuilder(
      listenable: _dataService,
      builder: (context, _) {
        if (_dataService.isLoadingWants && _dataService.cachedWants == null) {
          return Center(
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(widget.theme.colorScheme.primary),
            ),
          );
        }

        final wants = _dataService.cachedWants ?? [];
        if (wants.isEmpty) {
          return _buildEmptyState(context, widget.theme);
        }

        return RefreshIndicator(
          onRefresh: () => _dataService.refresh(),
          color: widget.theme.colorScheme.primary,
          child: ListView.builder(
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
                    color: widget.isDark
                        ? Colors.white.withOpacity(0.08)
                        : Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    getIconByDeviceName(want.deviceName),
                    color: widget.theme.colorScheme.onSurface.withOpacity(0.7),
                    size: 24,
                  ),
                ),
                title: Text(
                  want.deviceName,
                  style: TextStyle(
                    color: widget.theme.colorScheme.onSurface,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                subtitle: Text(
                  want.deviceType,
                  style: TextStyle(
                    color: widget.theme.colorScheme.onSurface.withOpacity(0.6),
                    fontSize: 14,
                  ),
                ),
                onTap: () {
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
          ),
        );
      },
    );
  }

  Widget _buildEmptyState(BuildContext context, ThemeData theme) {
    return RefreshIndicator(
      onRefresh: () => _dataService.refresh(),
      color: theme.colorScheme.primary,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: Container(
          width: double.infinity,
          height: MediaQuery.of(context).size.height * 0.6,
          child: Center(
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
          ),
        ),
      ),
    );
  }
}
