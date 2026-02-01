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
  final ValueNotifier<bool>? scrollToTopNotifier;

  const ExplorePage({
    super.key,
    required this.user,
    this.refreshNotifier,
    this.scrollToTopNotifier,
  });

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
  // Search
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  final ScrollController _scrollController = ScrollController();
  final GlobalKey<RefreshIndicatorState> _refreshIndicatorKey = GlobalKey<RefreshIndicatorState>();
  final GlobalKey _searchRowKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _loadData();
    // Listen to refresh notifications
    widget.refreshNotifier?.addListener(_onRefreshRequested);
    // Listen to scroll-to-top (and refresh) when same tab is tapped
    widget.scrollToTopNotifier?.addListener(_onScrollToTopRequested);
  }

  void _onScrollToTopRequested() {
    if (widget.scrollToTopNotifier?.value != true) return;
    widget.scrollToTopNotifier!.value = false;
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
    // Use RefreshIndicator.show() to display pull-to-refresh animation
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _refreshIndicatorKey.currentState?.show();
    });
  }

  @override
  void dispose() {
    widget.refreshNotifier?.removeListener(_onRefreshRequested);
    widget.scrollToTopNotifier?.removeListener(_onScrollToTopRequested);
    _searchController.dispose();
    _searchFocusNode.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  /// Filter docs by search query (deviceName, note, username).
  List<QueryDocumentSnapshot> _getFilteredDocs([List<QueryDocumentSnapshot>? source]) {
    final list = source ?? _cachedDocs ?? [];
    if (_searchQuery.trim().isEmpty) return list;
    final q = _searchQuery.trim().toLowerCase();
    return list.where((doc) {
      final d = doc.data() as Map<String, dynamic>;
      final name = (d['deviceName'] as String? ?? '').toLowerCase();
      final note = (d['note'] as String? ?? '').toLowerCase();
      final username = (d['username'] as String? ?? '').toLowerCase();
      return name.contains(q) || note.contains(q) || username.contains(q);
    }).toList();
  }

  void _onRefreshRequested() {
    if (widget.refreshNotifier?.value == true) {
      // Always full refresh so deletes are reflected (partial refresh would re-add deleted docs from cache)
      _loadData(forceRefresh: true);
      // Reset the notifier
      widget.refreshNotifier?.value = false;
    }
  }

  Future<void> _loadData({bool forceRefresh = false}) async {
    // Check cache first if not forcing refresh. Empty cache (e.g. from offline load)
    // should not skip refetch so that when user comes back online and switches tab,
    // we automatically reload.
    if (!forceRefresh && _deviceTypeCache.containsKey(_selectedDeviceType)) {
      final cached = _deviceTypeCache[_selectedDeviceType];
      if (cached != null && cached.isNotEmpty) {
        setState(() {
          _cachedDocs = cached;
          _isLoading = false;
          _dataFuture = null; // Clear future since we're using cache
        });
        return;
      }
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
      final filteredDocs = _getFilteredDocs();
      if (filteredDocs.isEmpty && _searchQuery.trim().isNotEmpty) {
        return Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              'No results for "$_searchQuery"',
              style: TextStyle(
                color: theme.colorScheme.onSurface.withOpacity(0.6),
                fontSize: 16,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        );
      }
      return RefreshIndicator(
        key: _refreshIndicatorKey,
        onRefresh: _handleRefresh,
        color: theme.colorScheme.primary,
        child: ListView.builder(
          controller: _scrollController,
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          itemCount: filteredDocs.length,
          itemBuilder: (context, index) {
            final doc = filteredDocs[index];
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
                                builder: (context) => DeviceDetailPage(seki: seki, exploreRefreshNotifier: widget.refreshNotifier),
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
                            // Unfocus search when returning so keyboard only opens on tap
                            if (mounted) _searchFocusNode.unfocus();
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
            key: _refreshIndicatorKey,
            onRefresh: _handleRefresh,
            color: theme.colorScheme.primary,
            child: SingleChildScrollView(
              controller: _scrollController,
              physics: const AlwaysScrollableScrollPhysics(),
              child: SizedBox(
                height: MediaQuery.of(context).size.height * 0.5,
                child: Center(
                  child: Text(
                    _selectedDeviceType == null
                        ? 'No devices shared yet.\nBe the first to add one!'
                        : 'No $_selectedDeviceType devices yet.',
                    textAlign: TextAlign.center,
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

        final filteredDocs = _getFilteredDocs(snapshot.data!.docs);
        if (filteredDocs.isEmpty && _searchQuery.trim().isNotEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                'No results for "$_searchQuery"',
                style: TextStyle(
                  color: theme.colorScheme.onSurface.withOpacity(0.6),
                  fontSize: 16,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          );
        }
        return RefreshIndicator(
          key: _refreshIndicatorKey,
          onRefresh: _handleRefresh,
          color: theme.colorScheme.primary,
          child: ListView.builder(
            controller: _scrollController,
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            itemCount: filteredDocs.length,
            itemBuilder: (context, index) {
              final doc = filteredDocs[index];
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
                        builder: (context) => DeviceDetailPage(seki: seki, exploreRefreshNotifier: widget.refreshNotifier),
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
                    // Unfocus search when returning so keyboard only opens on tap
                    if (mounted) _searchFocusNode.unfocus();
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
      body: Listener(
        onPointerDown: (PointerDownEvent event) {
          // Unfocus search when tapping outside the search row so keyboard dismisses
          final globalPosition = event.position;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            final searchRowBox = _searchRowKey.currentContext?.findRenderObject() as RenderBox?;
            if (searchRowBox != null && searchRowBox.hasSize) {
              final localPos = searchRowBox.globalToLocal(globalPosition);
              final bounds = Offset.zero & searchRowBox.size;
              if (bounds.contains(localPos)) return; // tap was on search row, keep focus as-is
            }
            _searchFocusNode.unfocus();
          });
        },
        child: SafeArea(
          child: Column(
            children: [
              const SizedBox(height: 4),
              _buildTopRow(theme, isDark),
              const SizedBox(height: 6),
              Expanded(
                child: _buildContent(theme, isDark),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static const Color _searchBarFillLight = Color(0xFFF8F8F8);

  Widget _buildTopRow(ThemeData theme, bool isDark) {
    return Padding(
      key: _searchRowKey,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: _buildSearchBar(theme, isDark),
          ),
          const SizedBox(width: 8),
          _buildFilterButton(theme, isDark),
        ],
      ),
    );
  }

  Widget _buildSearchBar(ThemeData theme, bool isDark) {
    final fillColor = isDark ? Colors.white.withOpacity(0.06) : _searchBarFillLight;
    final borderColor = isDark ? Colors.white.withOpacity(0.08) : const Color(0xFFE8E8E8);

    return TextField(
      controller: _searchController,
      focusNode: _searchFocusNode,
      decoration: InputDecoration(
        hintText: 'Search devices, notes, people',
        hintStyle: TextStyle(
          color: theme.colorScheme.onSurface.withOpacity(0.45),
          fontSize: 14,
        ),
        prefixIcon: Icon(
          Icons.search,
          size: 20,
          color: theme.colorScheme.onSurface.withOpacity(0.5),
        ),
        suffixIcon: _searchQuery.isNotEmpty
            ? IconButton(
                icon: Icon(Icons.clear, size: 18, color: theme.colorScheme.onSurface.withOpacity(0.5)),
                onPressed: () {
                  _searchController.clear();
                  setState(() => _searchQuery = '');
                },
              )
            : null,
        filled: true,
        fillColor: fillColor,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: borderColor, width: 1),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: borderColor, width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: theme.colorScheme.primary.withOpacity(0.4), width: 1),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),
      style: TextStyle(
        color: theme.colorScheme.onSurface,
        fontSize: 14,
      ),
      onChanged: (value) => setState(() => _searchQuery = value),
    );
  }

  Widget _buildFilterButton(ThemeData theme, bool isDark) {
    final hasFilter = _selectedDeviceType != null;
    String? selectedLabel;
    Color? categoryColor;
    if (hasFilter) {
      for (final c in deviceCategories) {
        if (c.deviceType == _selectedDeviceType) {
          selectedLabel = c.label;
          categoryColor = getCategoryColor(c.deviceType);
          break;
        }
      }
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _showCategoryPicker(theme, isDark),
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (!hasFilter)
                Text(
                  'Filter',
                  style: TextStyle(
                    color: theme.colorScheme.onSurface.withOpacity(0.65),
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              if (hasFilter && selectedLabel != null && categoryColor != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: categoryColor.withOpacity(0.18),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: categoryColor.withOpacity(0.5),
                      width: 1,
                    ),
                  ),
                  child: Text(
                    selectedLabel,
                    style: TextStyle(
                      color: categoryColor,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              const SizedBox(width: 2),
              Icon(
                Icons.arrow_drop_down,
                size: 20,
                color: theme.colorScheme.onSurface.withOpacity(0.5),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showCategoryPicker(ThemeData theme, bool isDark) {
    _searchFocusNode.unfocus();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1A1A2E) : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: SafeArea(
          top: false,
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
            // "All" option — matches grid item style
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () {
                    setState(() => _selectedDeviceType = null);
                    Navigator.pop(context);
                    _loadData(forceRefresh: false);
                  },
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      color: _selectedDeviceType == null
                          ? theme.colorScheme.primary.withOpacity(0.12)
                          : (isDark ? Colors.white : Colors.black).withOpacity(0.06),
                      border: Border.all(
                        color: _selectedDeviceType == null
                            ? theme.colorScheme.primary.withOpacity(0.4)
                            : (isDark ? Colors.white : Colors.black).withOpacity(0.08),
                        width: 1.5,
                      ),
                    ),
                    child: Center(
                      child: Text(
                        'All',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: _selectedDeviceType == null ? FontWeight.w600 : FontWeight.w500,
                          color: _selectedDeviceType == null
                              ? theme.colorScheme.primary
                              : theme.colorScheme.onSurface.withOpacity(0.65),
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
  }
}
