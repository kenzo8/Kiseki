import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../models/seki_model.dart';
import '../services/system_ui_service.dart';
import '../services/profile_data_service.dart';
import '../pages/settings_page.dart';
import '../pages/device_detail_page.dart';
import '../pages/add_device_page.dart';
import '../pages/login_page.dart';
import '../widgets/timeline_seki_item.dart';
import '../widgets/seki_card.dart';
import '../widgets/device_icon_selector.dart';

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
  final VoidCallback? onGoToExplore;
  final ValueNotifier<bool>? exploreRefreshNotifier;

  const ProfilePage({
    super.key,
    required this.user,
    this.onGoToExplore,
    this.exploreRefreshNotifier,
  });

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

  /// Gets gradient colors based on device types and counts.
  /// Returns a gradient with colors weighted by device count * type frequency.
  List<Color> _getAvatarBorderGradientColors(List<Seki> sekis, ThemeData theme) {
    if (sekis.isEmpty) {
      return [theme.colorScheme.primary, theme.colorScheme.primary];
    }
    
    // Count occurrences of each deviceType (weighted by count)
    final deviceTypeWeights = <String, int>{};
    for (final seki in sekis) {
      deviceTypeWeights[seki.deviceType] = (deviceTypeWeights[seki.deviceType] ?? 0) + 1;
    }
    
    // Sort device types by weight (count) descending
    final sortedTypes = deviceTypeWeights.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    
    final totalDevices = sekis.length;
    
    // Calculate how many colors to use based on device count and diversity
    // More devices = more colors, but cap at 5 for visual clarity
    int maxColors;
    if (totalDevices >= 15) {
      // Many devices: use up to 5 colors to represent diversity
      maxColors = sortedTypes.length > 5 ? 5 : sortedTypes.length;
    } else if (totalDevices >= 8) {
      // Medium devices: use up to 4 colors
      maxColors = sortedTypes.length > 4 ? 4 : sortedTypes.length;
    } else {
      // Few devices: use up to 3 colors
      maxColors = sortedTypes.length > 3 ? 3 : sortedTypes.length;
    }
    
    // Get colors for top device types, weighted by their count
    final gradientColors = <Color>[];
    final colorWeights = <Color, int>{};
    
    // Collect colors with their weights
    for (int i = 0; i < maxColors && i < sortedTypes.length; i++) {
      final deviceType = sortedTypes[i].key;
      final count = sortedTypes[i].value;
      final color = getCategoryColor(deviceType);
      
      // If same color appears multiple times, accumulate weight
      colorWeights[color] = (colorWeights[color] ?? 0) + count;
    }
    
    // Sort colors by weight and add to gradient
    final sortedColors = colorWeights.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    
    for (final entry in sortedColors) {
      gradientColors.add(entry.key);
    }
    
    // Ensure we have at least 2 colors for gradient
    if (gradientColors.isEmpty) {
      return [theme.colorScheme.primary, theme.colorScheme.primary];
    } else if (gradientColors.length == 1) {
      return [gradientColors[0], gradientColors[0]];
    } else if (gradientColors.length == 2) {
      return gradientColors;
    } else {
      // For 3+ colors, use first, middle, and last for smooth gradient
      if (gradientColors.length == 3) {
        return gradientColors;
      } else if (gradientColors.length == 4) {
        // Use first, second, third, and last
        return [gradientColors[0], gradientColors[1], gradientColors[2], gradientColors[3]];
      } else {
        // Use first, middle, and last for 5+ colors
        final midIndex = gradientColors.length ~/ 2;
        return [gradientColors[0], gradientColors[midIndex], gradientColors[gradientColors.length - 1]];
      }
    }
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

    // If user is not logged in, show login prompt (don't auto-navigate if it's a main page)
    if (widget.user == null) {
      // Check if this is a main page (in IndexedStack)
      final isMainPage = _isMainPage(context);
      
      if (!isMainPage) {
        // If navigated to from elsewhere, show login page
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && Navigator.canPop(context)) {
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(
                builder: (context) => const LoginPage(),
              ),
            );
          }
        });
        return Scaffold(
          backgroundColor: scaffoldBg,
          body: const Center(
            child: CircularProgressIndicator(),
          ),
        );
      }
      
      // If it's a main page, show login prompt instead
      return Scaffold(
        backgroundColor: scaffoldBg,
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.person_outline,
                    size: 72,
                    color: theme.colorScheme.onSurface.withOpacity(0.3),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Log in to view your profile',
                    style: TextStyle(
                      color: theme.colorScheme.onSurface.withOpacity(0.7),
                      fontSize: 18,
                      fontWeight: FontWeight.w500,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 32),
                  ElevatedButton(
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) => const LoginPage(),
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                    ),
                    child: const Text('Log In'),
                  ),
                ],
              ),
            ),
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
            
            // Get gradient colors for avatar border based on device types and counts
            final avatarBorderGradientColors = _getAvatarBorderGradientColors(sekis, theme);

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
                              builder: (context) => SettingsPage(
                                exploreRefreshNotifier: widget.exploreRefreshNotifier,
                              ),
                            ),
                          );
                        },
                      ),
                    ],
                    flexibleSpace: FlexibleSpaceBar(
                      background: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: isDark
                                ? [
                                    const Color(0xFF1A1F2E).withOpacity(0.6),
                                    const Color(0xFF2A3441).withOpacity(0.4),
                                  ]
                                : [
                                    const Color(0xFFE8EBF0).withOpacity(0.8),
                                    const Color(0xFFD4D9E3).withOpacity(0.6),
                                  ],
                          ),
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
                                        Container(
                                          width: 28,
                                          height: 28,
                                          decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            gradient: LinearGradient(
                                              colors: avatarBorderGradientColors,
                                              begin: Alignment.topLeft,
                                              end: Alignment.bottomRight,
                                            ),
                                          ),
                                          padding: const EdgeInsets.all(2),
                                          child: Container(
                                            decoration: BoxDecoration(
                                              shape: BoxShape.circle,
                                              color: scaffoldBg,
                                            ),
                                            child: Icon(
                                              Icons.person,
                                              size: 24,
                                              color: theme.colorScheme.primary,
                                            ),
                                          ),
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
                                          color: theme.colorScheme.onSurfaceVariant.withOpacity(0.6),
                                        ),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: Text(
                                            email,
                                            style: theme.textTheme.bodySmall?.copyWith(
                                              color: theme.colorScheme.onSurfaceVariant.withOpacity(0.6),
                                            ) ?? TextStyle(
                                              color: theme.colorScheme.onSurfaceVariant.withOpacity(0.6),
                                              fontSize: 12,
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
                                                    // Distinct tag so same device in "In Use" chips and "Owned" list doesn't duplicate Hero tag.
                                                    final inUseHeroTag = 'device_icon_inuse_${seki.id}';
                                                    return InkWell(
                                                      onTap: () {
                                                        Navigator.of(context).push(
                                                          MaterialPageRoute(
                                                            builder: (context) => DeviceDetailPage(
                                                              seki: seki,
                                                              exploreRefreshNotifier: widget.exploreRefreshNotifier,
                                                              heroTag: inUseHeroTag,
                                                            ),
                                                          ),
                                                        );
                                                      },
                                                      borderRadius: BorderRadius.circular(20),
                                                      child: Container(
                                                        padding: const EdgeInsets.symmetric(
                                                          horizontal: 14,
                                                          vertical: 6,
                                                        ),
                                                        decoration: BoxDecoration(
                                                          color: isDark 
                                                              ? Colors.white.withOpacity(0.05)
                                                              : Colors.grey[100],
                                                          borderRadius: BorderRadius.circular(20),
                                                          border: Border.all(
                                                            color: theme.colorScheme.primary.withOpacity(0.3),
                                                            width: 1,
                                                          ),
                                                        ),
                                                        child: Row(
                                                          mainAxisSize: MainAxisSize.min,
                                                          children: [
                                                            Hero(
                                                              tag: inUseHeroTag,
                                                              child: Icon(
                                                                deviceTypeToIcon(seki.deviceType),
                                                                size: 16,
                                                                color: theme.colorScheme.primary.withOpacity(0.7),
                                                              ),
                                                            ),
                                                            const SizedBox(width: 6),
                                                            Text(
                                                              seki.deviceName,
                                                              style: theme.textTheme.labelMedium?.copyWith(
                                                                color: theme.colorScheme.primary.withOpacity(0.8),
                                                                fontWeight: FontWeight.w500,
                                                              ) ?? TextStyle(
                                                                color: theme.colorScheme.primary.withOpacity(0.8),
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
                                        fontWeight: FontWeight.w700,
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
                                        fontWeight: FontWeight.w700,
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
                  _OwnedTab(theme: theme, isDark: isDark, exploreRefreshNotifier: widget.exploreRefreshNotifier),
                  // Wants tab
                  _WantsTab(theme: theme, isDark: isDark, onGoToExplore: widget.onGoToExplore, exploreRefreshNotifier: widget.exploreRefreshNotifier),
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
  final ValueNotifier<bool>? exploreRefreshNotifier;

  const _OwnedTab({required this.theme, required this.isDark, this.exploreRefreshNotifier});

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
                      builder: (context) => DeviceDetailPage(seki: seki, exploreRefreshNotifier: widget.exploreRefreshNotifier),
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
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(32.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.devices_outlined,
                    size: 72,
                    color: theme.colorScheme.onSurface.withOpacity(0.3),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    "Add one you've used to get started.",
                    style: TextStyle(
                      fontSize: 14,
                      color: theme.colorScheme.onSurface.withOpacity(0.6),
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  FilledButton.icon(
                    onPressed: () {
                      showModalBottomSheet(
                        context: context,
                        isScrollControlled: true,
                        backgroundColor: Colors.transparent,
                        builder: (context) => const AddDevicePage(),
                      );
                    },
                    icon: const Icon(Icons.add, size: 20),
                    label: const Text('Add device'),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
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
  final VoidCallback? onGoToExplore;
  final ValueNotifier<bool>? exploreRefreshNotifier;

  const _WantsTab({required this.theme, required this.isDark, this.onGoToExplore, this.exploreRefreshNotifier});

  @override
  State<_WantsTab> createState() => _WantsTabState();
}

class _WantsTabState extends State<_WantsTab> with AutomaticKeepAliveClientMixin {
  final ProfileDataService _dataService = ProfileDataService.instance;

  @override
  bool get wantKeepAlive => true;

  /// Format createdAt timestamp to a readable string
  String _formatCreatedAt(Timestamp createdAt) {
    final now = DateTime.now();
    final created = createdAt.toDate();
    final difference = now.difference(created);

    if (difference.inDays == 0) {
      if (difference.inHours == 0) {
        if (difference.inMinutes == 0) {
          return 'Just now';
        }
        return '${difference.inMinutes} ${difference.inMinutes == 1 ? 'minute' : 'minutes'} ago';
      }
      return '${difference.inHours} ${difference.inHours == 1 ? 'hour' : 'hours'} ago';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} ${difference.inDays == 1 ? 'day' : 'days'} ago';
    } else if (difference.inDays < 30) {
      final weeks = (difference.inDays / 7).floor();
      return '$weeks ${weeks == 1 ? 'week' : 'weeks'} ago';
    } else if (difference.inDays < 365) {
      final months = (difference.inDays / 30).floor();
      return '$months ${months == 1 ? 'month' : 'months'} ago';
    } else {
      final years = (difference.inDays / 365).floor();
      return '$years ${years == 1 ? 'year' : 'years'} ago';
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // Required for AutomaticKeepAliveClientMixin

    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    if (currentUserId == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => const LoginPage(),
          ),
        );
      });
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.star_outline,
                size: 72,
                color: widget.theme.colorScheme.onSurface.withOpacity(0.3),
              ),
              const SizedBox(height: 16),
              Text(
                'Log in to view your wants',
                style: TextStyle(
                  color: widget.theme.colorScheme.onSurface.withOpacity(0.7),
                  fontSize: 16,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
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
          return _buildEmptyState(context, widget.theme, onGoToExplore: widget.onGoToExplore);
        }

        return RefreshIndicator(
          onRefresh: () => _dataService.refresh(),
          color: widget.theme.colorScheme.primary,
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            itemCount: wants.length,
            itemBuilder: (context, index) {
              final want = wants[index];
              final categoryColor = getCategoryColor(want.deviceType);
              final wantHeroTag = 'device_icon_want_${want.id}';
              return ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                leading: Hero(
                  tag: wantHeroTag,
                  child: Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: categoryColor.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      deviceTypeToIcon(want.deviceType),
                      color: categoryColor,
                      size: 24,
                    ),
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
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      want.deviceType,
                      style: TextStyle(
                        color: widget.theme.colorScheme.onSurface.withOpacity(0.6),
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _formatCreatedAt(want.createdAt),
                      style: TextStyle(
                        color: widget.theme.colorScheme.onSurface.withOpacity(0.5),
                        fontSize: 12,
                      ),
                    ),
                  ],
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
                          builder: (context) => DeviceDetailPage(
                            seki: seki,
                            exploreRefreshNotifier: widget.exploreRefreshNotifier,
                            heroTag: wantHeroTag,
                          ),
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

  Widget _buildEmptyState(BuildContext context, ThemeData theme, {VoidCallback? onGoToExplore}) {
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
                  const SizedBox(height: 20),
                  Text(
                    'Browse Explore and add devices here.',
                    style: TextStyle(
                      fontSize: 14,
                      color: theme.colorScheme.onSurface.withOpacity(0.6),
                    ),
                    textAlign: TextAlign.center,
                  ),
                  if (onGoToExplore != null) ...[
                    const SizedBox(height: 24),
                    FilledButton.icon(
                      onPressed: onGoToExplore,
                      icon: const Icon(Icons.explore, size: 20),
                      label: const Text('Back to Explore'),
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
