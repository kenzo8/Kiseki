import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../models/seki_model.dart';
import '../models/want_model.dart';
import '../services/block_service.dart';
import '../services/system_ui_service.dart';
import '../widgets/timeline_seki_item.dart';
import '../widgets/seki_card.dart';
import '../widgets/device_icon_selector.dart';
import '../pages/device_detail_page.dart';
import 'login_page.dart';

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

  /// Gets gradient colors based on device types and counts (for avatar ring).
  /// Returns a gradient with colors weighted by device count * type frequency.
  List<Color> _getAvatarBorderGradientColors(List<Seki> sekis, ThemeData theme) {
    if (sekis.isEmpty) {
      return [theme.colorScheme.primary, theme.colorScheme.primary];
    }

    final deviceTypeWeights = <String, int>{};
    for (final seki in sekis) {
      deviceTypeWeights[seki.deviceType] = (deviceTypeWeights[seki.deviceType] ?? 0) + 1;
    }

    final sortedTypes = deviceTypeWeights.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final totalDevices = sekis.length;
    int maxColors;
    if (totalDevices >= 15) {
      maxColors = sortedTypes.length > 5 ? 5 : sortedTypes.length;
    } else if (totalDevices >= 8) {
      maxColors = sortedTypes.length > 4 ? 4 : sortedTypes.length;
    } else {
      maxColors = sortedTypes.length > 3 ? 3 : sortedTypes.length;
    }

    final gradientColors = <Color>[];
    final colorWeights = <Color, int>{};
    for (int i = 0; i < maxColors && i < sortedTypes.length; i++) {
      final deviceType = sortedTypes[i].key;
      final count = sortedTypes[i].value;
      final color = getCategoryColor(deviceType);
      colorWeights[color] = (colorWeights[color] ?? 0) + count;
    }

    final sortedColors = colorWeights.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    for (final entry in sortedColors) {
      gradientColors.add(entry.key);
    }

    if (gradientColors.isEmpty) {
      return [theme.colorScheme.primary, theme.colorScheme.primary];
    } else if (gradientColors.length == 1) {
      return [gradientColors[0], gradientColors[0]];
    } else if (gradientColors.length == 2) {
      return gradientColors;
    } else if (gradientColors.length == 3) {
      return gradientColors;
    } else if (gradientColors.length == 4) {
      return [gradientColors[0], gradientColors[1], gradientColors[2], gradientColors[3]];
    } else {
      final midIndex = gradientColors.length ~/ 2;
      return [gradientColors[0], gradientColors[midIndex], gradientColors[gradientColors.length - 1]];
    }
  }

  /// Calculate adaptive height based on content
  double _calculateHeaderHeight(String bio, List<Seki> activeDevices, [String handle = '']) {
    double baseHeight = 120.0; // Base height for avatar + username row
    if (handle.isNotEmpty) baseHeight += 22.0;
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
    // Use smaller minimum when "In Use" is empty to reduce blank space
    final minHeight = activeDevices.isEmpty ? 160.0 : 200.0;
    return baseHeight.clamp(minHeight, 400.0);
  }

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

  static const _reportReasons = [
    'Spam',
    'Inappropriate content',
    'Harassment or bullying',
    'Fake or impersonation',
    'Other',
  ];

  final BlockService _blockService = BlockService();

  Future<void> _onBlockUserTapped(String blockUserId, String blockUsername) async {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    if (currentUserId == null) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => const LoginPage(),
        ),
      );
      return;
    }
    if (blockUserId == currentUserId) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Block user'),
        content: Text(
          'Block $blockUsername? You will no longer see their content in Explore. They will not be notified.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text('Cancel', style: TextStyle(color: Theme.of(ctx).colorScheme.onSurface)),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Block'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      await _blockService.blockUser(blockUserId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('User blocked. You will no longer see their content.')),
      );
      Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to block: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _onUnblockUserTapped(String unblockUserId, String unblockUsername) async {
    try {
      await _blockService.unblockUser(unblockUserId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$unblockUsername unblocked. You can see their content again.')),
      );
      setState(() {});
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to unblock: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _onReportUserTapped(String reportedUserId, String reportedUsername) async {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    if (currentUserId == null) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => const LoginPage(),
        ),
      );
      return;
    }
    await _showReportUserDialog(reportedUserId, reportedUsername);
  }

  Future<void> _showReportUserDialog(String reportedUserId, String reportedUsername) async {
    String? selectedReason;
    final detailsController = TextEditingController();
    final theme = Theme.of(context);
    final pageContext = context;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: const Text('Report user'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Report this user for violating our guidelines. Your report will be reviewed.',
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
                            'type': 'user',
                            'reporterUid': FirebaseAuth.instance.currentUser!.uid,
                            'reportedUserId': reportedUserId,
                            'reportedUsername': reportedUsername,
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
                          messenger.showSnackBar(SnackBar(
                            content: Text('Failed to submit report: $e'),
                            backgroundColor: Colors.red,
                          ));
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
            final handle = userData['handle'] as String? ?? '';
            final bio = userData['bio'] as String? ?? '';

            return StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('seki')
                  .where('publisherId', isEqualTo: widget.publisherId)
                  .snapshots(),
              builder: (context, sekiSnapshot) {
                List<Seki> activeDevices = [];
                int deviceCount = 0;
                List<Seki> sekis = [];

                if (sekiSnapshot.hasData && sekiSnapshot.data!.docs.isNotEmpty) {
                  sekis = sekiSnapshot.data!.docs
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

                    final fallbackSekis = fallbackSekiSnapshot.hasData && fallbackSekiSnapshot.data!.docs.isNotEmpty
                        ? fallbackSekiSnapshot.data!.docs
                            .map((doc) => Seki.fromFirestore(doc))
                            .toList()
                        : <Seki>[];
                    return _buildNestedScrollView(
                      context,
                      theme,
                      isDark,
                      scaffoldBg,
                      username,
                      handle,
                      bio,
                      fallbackActiveDevices,
                      fallbackDeviceCount,
                      wantCount,
                      true,
                      fallbackSekis,
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
                      handle,
                      bio,
                      activeDevices,
                      deviceCount,
                      wantCount,
                      false,
                      sekis,
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
    String handle,
    String bio,
    List<Seki> activeDevices,
    int deviceCount,
    int wantCount,
    bool useUidQuery,
    List<Seki> sekis,
  ) {
    final headerHeight = _calculateHeaderHeight(bio, activeDevices, handle);
    final avatarBorderGradientColors = _getAvatarBorderGradientColors(sekis, theme);
    
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
            actions: [
              StreamBuilder<List<String>>(
                stream: _blockService.blockedUserIdsStream,
                builder: (context, blockedSnapshot) {
                  final blockedIds = blockedSnapshot.data ?? [];
                  final isBlocked = blockedIds.contains(widget.publisherId);
                  final currentUserId = FirebaseAuth.instance.currentUser?.uid;
                  final isSelf = currentUserId == widget.publisherId;
                  return PopupMenuButton<String>(
                    icon: Icon(
                      Icons.more_vert,
                      color: theme.colorScheme.onSurface.withOpacity(0.7),
                    ),
                    tooltip: 'More',
                    onSelected: (value) {
                      if (value == 'report') {
                        _onReportUserTapped(widget.publisherId, username);
                      } else if (value == 'block') {
                        _onBlockUserTapped(widget.publisherId, username);
                      } else if (value == 'unblock') {
                        _onUnblockUserTapped(widget.publisherId, username);
                      }
                    },
                    itemBuilder: (context) => [
                      const PopupMenuItem(
                        value: 'report',
                        child: ListTile(
                          leading: Icon(Icons.flag_outlined),
                          title: Text('Report user'),
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                      if (!isSelf) ...[
                        if (isBlocked)
                          const PopupMenuItem(
                            value: 'unblock',
                            child: ListTile(
                              leading: Icon(Icons.person_remove_outlined),
                              title: Text('Unblock user'),
                              contentPadding: EdgeInsets.zero,
                            ),
                          )
                        else
                          const PopupMenuItem(
                            value: 'block',
                            child: ListTile(
                              leading: Icon(Icons.block),
                              title: Text('Block user'),
                              contentPadding: EdgeInsets.zero,
                            ),
                          ),
                      ],
                    ],
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
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Container(
                            width: 44,
                            height: 44,
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
                                size: 26,
                                color: theme.colorScheme.primary,
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  username,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: theme.textTheme.headlineSmall?.copyWith(
                                    fontWeight: FontWeight.w600,
                                    color: theme.colorScheme.onSurface,
                                  ) ?? TextStyle(
                                    color: theme.colorScheme.onSurface,
                                    fontSize: 24,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                if (handle.isNotEmpty) ...[
                                  const SizedBox(height: 4),
                                  Text(
                                    '@$handle',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: theme.textTheme.bodyMedium?.copyWith(
                                      color: theme.colorScheme.onSurfaceVariant,
                                      fontSize: 14,
                                    ) ?? TextStyle(
                                      color: theme.colorScheme.onSurfaceVariant,
                                      fontSize: 14,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      if (bio.isNotEmpty) ...[
                        const SizedBox(height: 10),
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
                        const SizedBox(height: 12),
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
                                              Icon(
                                                deviceTypeToIcon(seki.deviceType),
                                                size: 16,
                                                color: theme.colorScheme.primary.withOpacity(0.7),
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
            delegate: _OtherUserSliverAppBarDelegate(
              TabBar(
                key: ValueKey('tabbar_${deviceCount}_$wantCount'),
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
            final categoryColor = getCategoryColor(want.deviceType);
            return ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              leading: Container(
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
              title: Text(
                want.deviceName,
                style: TextStyle(
                  color: theme.colorScheme.onSurface,
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
                      color: theme.colorScheme.onSurface.withOpacity(0.6),
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _formatCreatedAt(want.createdAt),
                    style: TextStyle(
                      color: theme.colorScheme.onSurface.withOpacity(0.5),
                      fontSize: 12,
                    ),
                  ),
                ],
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

    // Convert docs to Seki objects and determine which ones should show year
    final sekis = docs.map((doc) => Seki.fromFirestore(doc)).toList();
    
    // Determine which items should show the year (first item of each year group)
    final shouldShowYear = <bool>[];
    int? previousYear;
    
    for (final seki in sekis) {
      final currentYear = seki.isPreciseMode && seki.startTime != null
          ? seki.startTime!.toDate().year
          : seki.startYear;
      
      // Show year if this is the first item or if the year changed
      final showYear = previousYear == null || previousYear != currentYear;
      shouldShowYear.add(showYear);
      previousYear = currentYear;
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      itemCount: sekis.length,
      itemBuilder: (context, index) {
        final seki = sekis[index];
        final isLast = index == sekis.length - 1;
        return TimelineSekiItem(
          seki: seki,
          isDark: isDark,
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
    );
  }

}
