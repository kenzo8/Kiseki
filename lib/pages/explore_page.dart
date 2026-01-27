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
    return Container(
      height: 50,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: deviceCategories.length + 1, // +1 for "All" option
        itemBuilder: (context, index) {
          if (index == 0) {
            // "All" option
            final isSelected = _selectedDeviceType == null;
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: GestureDetector(
                onTap: () {
                  setState(() {
                    _selectedDeviceType = null;
                  });
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
                  child: Center(
                    child: Text(
                      'All',
                      style: TextStyle(
                        color: isSelected
                            ? (isDark ? Colors.white : theme.colorScheme.primary)
                            : (isDark ? Colors.white : theme.colorScheme.onSurface).withOpacity(0.7),
                        fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ),
              ),
            );
          }

          final category = deviceCategories[index - 1];
          final isSelected = _selectedDeviceType == category.deviceType;

          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: GestureDetector(
              onTap: () {
                setState(() {
                  _selectedDeviceType = category.deviceType;
                });
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
                    Icon(
                      category.icon,
                      size: 18,
                      color: isSelected
                          ? (isDark ? Colors.white : theme.colorScheme.primary)
                          : (isDark ? Colors.white : theme.colorScheme.onSurface).withOpacity(0.7),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      category.label,
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
            ),
          );
        },
      ),
    );
  }
}
