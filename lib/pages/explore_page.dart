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

  const ExplorePage({super.key, required this.user});

  @override
  State<ExplorePage> createState() => _ExplorePageState();
}

class _ExplorePageState extends State<ExplorePage> {
  String? _selectedDeviceType; // null means "All"

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
            'Please sign in to view Explore',
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
              child: StreamBuilder<QuerySnapshot>(
                stream: _selectedDeviceType == null
                    ? FirebaseFirestore.instance
                        .collection('seki')
                        .snapshots()
                    : FirebaseFirestore.instance
                        .collection('seki')
                        .where('deviceType', isEqualTo: _selectedDeviceType)
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
                        _selectedDeviceType == null
                            ? 'No Seki posts yet. Be the first!'
                            : 'No ${_selectedDeviceType} posts yet.',
                        style: TextStyle(
                          color: theme.colorScheme.onSurface.withOpacity(0.6),
                          fontSize: 16,
                        ),
                      ),
                    );
                  }

                  return ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    itemCount: snapshot.data!.docs.length,
                    itemBuilder: (context, index) {
                      final doc = snapshot.data!.docs[index];
                      final seki = Seki.fromFirestore(doc);
                      final currentUserId = FirebaseAuth.instance.currentUser?.uid;
                      final publisherId = seki.publisherId;

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: SekiCard(
                          seki: seki,
                          isDark: isDark,
                          onBodyTap: () {
                            // Navigate to DeviceDetailPage with the device object
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (context) => DeviceDetailPage(seki: seki),
                              ),
                            );
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
                  );
                },
              ),
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
                  onTap: () {
                    setState(() {
                      _selectedDeviceType = category.deviceType;
                    });
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
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: icon != null ? 12 : 16,
          vertical: 8,
        ),
        decoration: BoxDecoration(
          color: isSelected
              ? (isDark ? Colors.white : theme.colorScheme.primary).withOpacity(0.2)
              : (isDark ? Colors.white : Colors.black).withOpacity(0.1),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected
                ? (isDark ? Colors.white : theme.colorScheme.primary).withOpacity(0.5)
                : Colors.transparent,
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
                    ? (isDark ? Colors.white : theme.colorScheme.primary)
                    : (isDark ? Colors.white : theme.colorScheme.onSurface).withOpacity(0.7),
              ),
              const SizedBox(width: 6),
            ],
            Text(
              label,
              style: TextStyle(
                color: isSelected
                    ? (isDark ? Colors.white : theme.colorScheme.primary)
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
                  
                  return GestureDetector(
                    onTap: () {
                      setState(() {
                        _selectedDeviceType = category.deviceType;
                      });
                      Navigator.pop(context);
                    },
                    child: Container(
                      decoration: BoxDecoration(
                        color: isSelected
                            ? (isDark ? Colors.white : theme.colorScheme.primary).withOpacity(0.2)
                            : (isDark ? Colors.white : Colors.black).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isSelected
                              ? (isDark ? Colors.white : theme.colorScheme.primary).withOpacity(0.5)
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
                                ? (isDark ? Colors.white : theme.colorScheme.primary)
                                : (isDark ? Colors.white : theme.colorScheme.onSurface).withOpacity(0.7),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            category.label,
                            style: TextStyle(
                              color: isSelected
                                  ? (isDark ? Colors.white : theme.colorScheme.primary)
                                  : (isDark ? Colors.white : theme.colorScheme.onSurface).withOpacity(0.7),
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
