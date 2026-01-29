import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../models/seki_model.dart';
import '../services/system_ui_service.dart';
import '../pages/profile_page.dart';
import '../pages/other_user_profile_page.dart';
import '../pages/device_detail_page.dart';
import '../widgets/seki_card.dart';
import '../widgets/device_icon_selector.dart';

class ExplorePage extends StatefulWidget {
  final User? user;
  final ValueNotifier<bool>? refreshNotifier;

  const ExplorePage({super.key, required this.user, this.refreshNotifier});

  @override
  State<ExplorePage> createState() => _ExplorePageState();
}

class _ExplorePageState extends State<ExplorePage> {
  String? _selectedDeviceType; // null means "All"
  Future<QuerySnapshot>? _dataFuture;
  List<QueryDocumentSnapshot>? _cachedDocs; // Cache current docs for partial refresh
  bool _isLoading = false;
  Set<String> _updatedItemIds = {}; // Track items that were updated in partial refresh
  // Cache data for each device type to avoid reloading when switching tabs
  final Map<String?, List<QueryDocumentSnapshot>> _deviceTypeCache = {};

  @override
  void initState() {
    super.initState();
    _loadData();
    // Listen to refresh notifications
    widget.refreshNotifier?.addListener(_onRefreshRequested);
  }

  @override
  void dispose() {
    widget.refreshNotifier?.removeListener(_onRefreshRequested);
    super.dispose();
  }

  void _onRefreshRequested() {
    if (widget.refreshNotifier?.value == true) {
      // If we have cached data, do partial refresh; otherwise full refresh
      if (_cachedDocs != null && _cachedDocs!.isNotEmpty) {
        _refreshPartial();
      } else {
        _loadData(forceRefresh: true);
      }
      // Reset the notifier
      widget.refreshNotifier?.value = false;
    }
  }

  Future<void> _loadData({bool forceRefresh = false}) async {
    // Check cache first if not forcing refresh
    if (!forceRefresh && _deviceTypeCache.containsKey(_selectedDeviceType)) {
      setState(() {
        _cachedDocs = _deviceTypeCache[_selectedDeviceType];
        _isLoading = false;
        _dataFuture = null; // Clear future since we're using cache
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _cachedDocs = null; // Clear cache when doing full refresh
      _dataFuture = _selectedDeviceType == null
          ? FirebaseFirestore.instance
              .collection('seki')
              .orderBy('createdAt', descending: true)
              .get()
          : FirebaseFirestore.instance
              .collection('seki')
              .where('deviceType', isEqualTo: _selectedDeviceType)
              .orderBy('createdAt', descending: true)
              .get();
    });
    
    // Cache the docs after loading
    _dataFuture?.then((snapshot) {
      if (mounted) {
        setState(() {
          _cachedDocs = snapshot.docs;
          // Store in cache for this device type
          _deviceTypeCache[_selectedDeviceType] = snapshot.docs;
          _isLoading = false;
        });
      }
    }).catchError((error) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    });
  }

  Future<void> _refreshPartial() async {
    if (_cachedDocs == null || _cachedDocs!.isEmpty) {
      _loadData(forceRefresh: true);
      return;
    }

    try {
      // Get the latest data for the first few items (most recent)
      // This will catch newly added items and recent updates
      final latestSnapshot = _selectedDeviceType == null
          ? await FirebaseFirestore.instance
              .collection('seki')
              .orderBy('createdAt', descending: true)
              .limit(20) // Get top 20 most recent
              .get()
          : await FirebaseFirestore.instance
              .collection('seki')
              .where('deviceType', isEqualTo: _selectedDeviceType)
              .orderBy('createdAt', descending: true)
              .limit(20)
              .get();

      if (!mounted) return;

      // Create a map of existing docs by ID for quick lookup
      final existingDocsMap = <String, QueryDocumentSnapshot>{};
      for (var doc in _cachedDocs!) {
        existingDocsMap[doc.id] = doc;
      }

      // Update or add docs from the latest snapshot
      final updatedDocs = <QueryDocumentSnapshot>[];
      final processedIds = <String>{};

      // First, add/update items from latest snapshot
      for (var newDoc in latestSnapshot.docs) {
        processedIds.add(newDoc.id);
        // Always use the new data if it exists (it might be updated)
        updatedDocs.add(newDoc);
      }

      // Add remaining existing docs that weren't in the latest snapshot
      for (var doc in _cachedDocs!) {
        if (!processedIds.contains(doc.id)) {
          updatedDocs.add(doc);
        }
      }

      // Sort by createdAt descending
      updatedDocs.sort((a, b) {
        final aTime = a.data() as Map<String, dynamic>;
        final bTime = b.data() as Map<String, dynamic>;
        final aCreatedAt = aTime['createdAt'] as Timestamp?;
        final bCreatedAt = bTime['createdAt'] as Timestamp?;
        if (aCreatedAt == null && bCreatedAt == null) return 0;
        if (aCreatedAt == null) return 1;
        if (bCreatedAt == null) return -1;
        return bCreatedAt.compareTo(aCreatedAt);
      });

      // Track which items were updated/added (compare with existing docs)
      final updatedIds = <String>{};
      final existingIds = _cachedDocs!.map((doc) => doc.id).toSet();
      
      for (var newDoc in latestSnapshot.docs) {
        final docId = newDoc.id;
        // Mark as updated if it's a new item
        if (!existingIds.contains(docId)) {
          updatedIds.add(docId);
        } else {
          // Check if existing item was updated
          final oldDoc = existingDocsMap[docId]!;
          if (_isDocUpdated(oldDoc, newDoc)) {
            updatedIds.add(docId);
          }
        }
      }

      // Update the cached docs directly
      setState(() {
        _cachedDocs = updatedDocs;
        // Update the device type cache as well
        _deviceTypeCache[_selectedDeviceType] = updatedDocs;
        _updatedItemIds = updatedIds;
        // Clear the updated IDs after animation completes
        Future.delayed(const Duration(milliseconds: 600), () {
          if (mounted) {
            setState(() {
              _updatedItemIds.clear();
            });
          }
        });
      });
    } catch (e) {
      // If partial refresh fails, fall back to full refresh
      _loadData(forceRefresh: true);
    }
  }

  bool _isDocUpdated(QueryDocumentSnapshot oldDoc, QueryDocumentSnapshot newDoc) {
    // Compare key fields that might change
    final oldData = oldDoc.data() as Map<String, dynamic>;
    final newData = newDoc.data() as Map<String, dynamic>;
    
    return oldData['deviceName'] != newData['deviceName'] ||
           oldData['deviceType'] != newData['deviceType'] ||
           oldData['note'] != newData['note'] ||
           oldData['startYear'] != newData['startYear'] ||
           oldData['endYear'] != newData['endYear'] ||
           oldData['isPreciseMode'] != newData['isPreciseMode'] ||
           oldData['startTime'] != newData['startTime'] ||
           oldData['endTime'] != newData['endTime'];
  }


  Future<void> _handleRefresh() async {
    // Use partial refresh if we have cached data, otherwise full refresh
    if (_cachedDocs != null && _cachedDocs!.isNotEmpty) {
      await _refreshPartial();
    } else {
      await _loadData(forceRefresh: true);
    }
  }

  Widget _buildContent(ThemeData theme, bool isDark) {
    // If we have cached docs, use them directly for faster UI updates
    if (_cachedDocs != null && _cachedDocs!.isNotEmpty) {
      return RefreshIndicator(
        onRefresh: _handleRefresh,
        color: theme.colorScheme.primary,
        child: ListView.builder(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          itemCount: _cachedDocs!.length,
          itemBuilder: (context, index) {
            final doc = _cachedDocs![index];
            final seki = Seki.fromFirestore(doc);
            final currentUserId = FirebaseAuth.instance.currentUser?.uid;
            final publisherId = seki.publisherId;

            // Add animation for updated items
            return TweenAnimationBuilder<double>(
              key: ValueKey('${doc.id}_${_updatedItemIds.contains(doc.id)}'),
              tween: Tween<double>(
                begin: _updatedItemIds.contains(doc.id) ? 0.0 : 1.0,
                end: 1.0,
              ),
              duration: _updatedItemIds.contains(doc.id)
                  ? const Duration(milliseconds: 400)
                  : const Duration(milliseconds: 0),
              curve: Curves.easeOut,
              builder: (context, value, child) {
                return Opacity(
                  opacity: value,
                  child: Transform.translate(
                    offset: Offset(0, _updatedItemIds.contains(doc.id) ? (1 - value) * 15 : 0),
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeOut,
                        decoration: _updatedItemIds.contains(doc.id) && value > 0.5
                            ? BoxDecoration(
                                borderRadius: BorderRadius.circular(12),
                                boxShadow: [
                                  BoxShadow(
                                    color: theme.colorScheme.primary.withOpacity(0.2 * (value - 0.5) * 2),
                                    blurRadius: 10,
                                    spreadRadius: 1,
                                  ),
                                ],
                              )
                            : null,
                        child: SekiCard(
                          seki: seki,
                          isDark: isDark,
                          onBodyTap: () async {
                            // Navigate to DeviceDetailPage with the device object
                            final result = await Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (context) => DeviceDetailPage(seki: seki),
                              ),
                            );
                            // If device was edited, do partial refresh
                            if (result == true) {
                              if (_cachedDocs != null && _cachedDocs!.isNotEmpty) {
                                _refreshPartial();
                              } else {
                                _loadData(forceRefresh: true);
                              }
                            }
                          },
                          onBottomBarTap: () {
                            // Navigate to ProfilePage based on owner
                            if (publisherId == currentUserId) {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (context) => ProfilePage(user: widget.user),
                                ),
                              );
                            } else {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (context) => OtherUserProfilePage(publisherId: publisherId),
                                ),
                              );
                            }
                          },
                        ),
                      ),
                    ),
                  ),
                );
              },
            );
          },
        ),
      );
    }

    // Otherwise use FutureBuilder for initial load
    return FutureBuilder<QuerySnapshot>(
      future: _dataFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting || _isLoading) {
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
          return RefreshIndicator(
            onRefresh: _handleRefresh,
            color: theme.colorScheme.primary,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              child: SizedBox(
                height: MediaQuery.of(context).size.height * 0.5,
                child: Center(
                  child: Text(
                    _selectedDeviceType == null
                        ? 'No Seki posts yet. Be the first!'
                        : 'No ${_selectedDeviceType} posts yet.',
                    style: TextStyle(
                      color: theme.colorScheme.onSurface.withOpacity(0.6),
                      fontSize: 16,
                    ),
                  ),
                ),
              ),
            ),
          );
        }

        // Update cache when data is loaded from FutureBuilder
        if (_cachedDocs == null && snapshot.hasData) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              setState(() {
                _cachedDocs = snapshot.data!.docs;
              });
            }
          });
        }

        return RefreshIndicator(
          onRefresh: _handleRefresh,
          color: theme.colorScheme.primary,
          child: ListView.builder(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            itemCount: snapshot.data!.docs.length,
            itemBuilder: (context, index) {
              final doc = snapshot.data!.docs[index];
              final seki = Seki.fromFirestore(doc);
              final currentUserId = FirebaseAuth.instance.currentUser?.uid;
              final publisherId = seki.publisherId;

              return Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: SekiCard(
                  seki: seki,
                  isDark: isDark,
                  onBodyTap: () async {
                    // Navigate to DeviceDetailPage with the device object
                    final result = await Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => DeviceDetailPage(seki: seki),
                      ),
                    );
                    // If device was edited, do partial refresh
                    if (result == true) {
                      if (_cachedDocs != null && _cachedDocs!.isNotEmpty) {
                        _refreshPartial();
                      } else {
                        _loadData(forceRefresh: true);
                      }
                    }
                  },
                  onBottomBarTap: () {
                    // Navigate to ProfilePage based on owner
                    if (publisherId == currentUserId) {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) => ProfilePage(user: widget.user),
                        ),
                      );
                    } else {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) => OtherUserProfilePage(publisherId: publisherId),
                        ),
                      );
                    }
                  },
                ),
              );
            },
          ),
        );
      },
    );
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
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 7.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Explore',
                    style: TextStyle(
                      color: theme.colorScheme.onSurface,
                      fontSize: 24,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 4,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 4),
            // Filter bar
            _buildFilterBar(theme, isDark),
            const SizedBox(height: 8),
            Expanded(
              child: _buildContent(theme, isDark),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterBar(ThemeData theme, bool isDark) {
    // Show "All" and first 4 common categories, plus a "More" button
    const int quickFiltersCount = 4;
    final quickCategories = deviceCategories.take(quickFiltersCount).toList();
    
    return Container(
      height: 50,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            // "All" option
            _buildFilterChip(
              theme: theme,
              isDark: isDark,
              label: 'All',
              icon: null,
              isSelected: _selectedDeviceType == null,
              onTap: () {
                setState(() {
                  _selectedDeviceType = null;
                });
                _loadData(forceRefresh: false);
              },
            ),
            const SizedBox(width: 4),
            // Quick filter categories
            ...quickCategories.map((category) {
              final isSelected = _selectedDeviceType == category.deviceType;
              return Padding(
                padding: const EdgeInsets.only(right: 4),
                child: _buildFilterChip(
                  theme: theme,
                  isDark: isDark,
                  label: category.label,
                  icon: category.icon,
                  isSelected: isSelected,
                  deviceType: category.deviceType,
                  onTap: () {
                    setState(() {
                      _selectedDeviceType = category.deviceType;
                    });
                    _loadData(forceRefresh: false);
                  },
                ),
              );
            }),
            // "More" button
            Padding(
              padding: const EdgeInsets.only(left: 4),
              child: _buildFilterChip(
                theme: theme,
                isDark: isDark,
                label: 'More',
                icon: Icons.more_horiz,
                isSelected: _selectedDeviceType != null && 
                            !quickCategories.any((c) => c.deviceType == _selectedDeviceType),
                onTap: () {
                  _showCategoryPicker(theme, isDark);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChip({
    required ThemeData theme,
    required bool isDark,
    required String label,
    IconData? icon,
    required bool isSelected,
    String? deviceType, // Optional deviceType for category color
    required VoidCallback onTap,
  }) {
    // Use category color if deviceType is provided, otherwise use theme color
    final Color? categoryColor = deviceType != null ? getCategoryColor(deviceType) : null;
    final Color selectedBgColor = categoryColor != null
        ? categoryColor.withOpacity(0.2)
        : (isDark ? Colors.white : theme.colorScheme.primary).withOpacity(0.2);
    final Color unselectedBgColor = (isDark ? Colors.white : Colors.black).withOpacity(0.1);
    final Color selectedBorderColor = categoryColor != null
        ? categoryColor
        : (isDark ? Colors.white : theme.colorScheme.primary).withOpacity(0.5);
    final Color selectedTextColor = categoryColor != null
        ? categoryColor
        : (isDark ? Colors.white : theme.colorScheme.primary);
    final Color selectedIconColor = categoryColor != null
        ? categoryColor
        : (isDark ? Colors.white : theme.colorScheme.primary);
    
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: icon != null ? 12 : 16,
          vertical: 8,
        ),
        decoration: BoxDecoration(
          color: isSelected ? selectedBgColor : unselectedBgColor,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? selectedBorderColor : Colors.transparent,
            width: 2,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(
                icon,
                size: 18,
                color: isSelected
                    ? selectedIconColor
                    : (isDark ? Colors.white : theme.colorScheme.onSurface).withOpacity(0.7),
              ),
              const SizedBox(width: 6),
            ],
            Text(
              label,
              style: TextStyle(
                color: isSelected
                    ? selectedTextColor
                    : (isDark ? Colors.white : theme.colorScheme.onSurface).withOpacity(0.7),
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showCategoryPicker(ThemeData theme, bool isDark) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1A1A2E) : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle bar
            Container(
              margin: const EdgeInsets.only(top: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: (isDark ? Colors.white : Colors.black).withOpacity(0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'Select Device Type',
                style: TextStyle(
                  color: theme.colorScheme.onSurface,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Flexible(
              child: GridView.builder(
                shrinkWrap: true,
                padding: const EdgeInsets.all(16),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: 1.1,
                ),
                itemCount: deviceCategories.length,
                itemBuilder: (context, index) {
                  final category = deviceCategories[index];
                  final isSelected = _selectedDeviceType == category.deviceType;
                  final categoryColor = getCategoryColor(category.deviceType);
                  
                  return GestureDetector(
                    onTap: () {
                      setState(() {
                        _selectedDeviceType = category.deviceType;
                      });
                      Navigator.pop(context);
                      _loadData(forceRefresh: false);
                    },
                    child: Container(
                      decoration: BoxDecoration(
                        color: isSelected
                            ? categoryColor.withOpacity(0.2)
                            : Colors.grey[100],
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isSelected
                              ? categoryColor
                              : Colors.transparent,
                          width: 2,
                        ),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            category.icon,
                            size: 32,
                            color: isSelected
                                ? categoryColor
                                : Colors.grey.shade400,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            category.label,
                            style: TextStyle(
                              color: isSelected
                                  ? categoryColor
                                  : Colors.grey.shade600,
                              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                              fontSize: 12,
                            ),
                            textAlign: TextAlign.center,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            // Add "All" option at the bottom
            Padding(
              padding: const EdgeInsets.all(16),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    setState(() {
                      _selectedDeviceType = null;
                    });
                    Navigator.pop(context);
                    _loadData(forceRefresh: false);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _selectedDeviceType == null
                        ? (isDark ? Colors.white : theme.colorScheme.primary).withOpacity(0.2)
                        : (isDark ? Colors.white : Colors.black).withOpacity(0.1),
                    foregroundColor: _selectedDeviceType == null
                        ? (isDark ? Colors.white : theme.colorScheme.primary)
                        : (isDark ? Colors.white : theme.colorScheme.onSurface).withOpacity(0.7),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(
                        color: _selectedDeviceType == null
                            ? (isDark ? Colors.white : theme.colorScheme.primary).withOpacity(0.5)
                            : Colors.transparent,
                        width: 2,
                      ),
                    ),
                  ),
                  child: Text(
                    'All',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: _selectedDeviceType == null ? FontWeight.w600 : FontWeight.w400,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
