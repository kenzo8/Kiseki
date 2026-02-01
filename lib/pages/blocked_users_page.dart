import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../services/block_service.dart';
import '../services/system_ui_service.dart';

/// Page that lists users blocked by the current user and allows unblocking.
class BlockedUsersPage extends StatefulWidget {
  const BlockedUsersPage({super.key});

  @override
  State<BlockedUsersPage> createState() => _BlockedUsersPageState();
}

class _BlockedUsersPageState extends State<BlockedUsersPage> {
  final BlockService _blockService = BlockService();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final scaffoldBg = isDark ? const Color(0xFF02081A) : const Color(0xFFF5F5F5);

    SystemUIService.setImmersiveStatusBar(context, backgroundColor: scaffoldBg);

    return Scaffold(
      backgroundColor: scaffoldBg,
      appBar: AppBar(
        backgroundColor: scaffoldBg,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          color: theme.colorScheme.onSurface.withOpacity(0.7),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'Blocked users',
          style: TextStyle(
            color: theme.colorScheme.onSurface,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: StreamBuilder<List<String>>(
        stream: _blockService.blockedUserIdsStream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final blockedIds = snapshot.data ?? [];
          if (blockedIds.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.person_off_outlined,
                      size: 64,
                      color: theme.colorScheme.onSurface.withOpacity(0.3),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'No blocked users',
                      style: TextStyle(
                        color: theme.colorScheme.onSurface.withOpacity(0.7),
                        fontSize: 16,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'When you block someone, they will appear here. You can unblock them anytime.',
                      style: TextStyle(
                        color: theme.colorScheme.onSurface.withOpacity(0.5),
                        fontSize: 14,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            itemCount: blockedIds.length,
            itemBuilder: (context, index) {
              final uid = blockedIds[index];
              return _BlockedUserTile(
                userId: uid,
                onUnblock: () => _onUnblock(uid),
                theme: theme,
                isDark: isDark,
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _onUnblock(String userId) async {
    try {
      await _blockService.unblockUser(userId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('User unblocked. You can see their content again.')),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to unblock: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }
}

class _BlockedUserTile extends StatelessWidget {
  const _BlockedUserTile({
    required this.userId,
    required this.onUnblock,
    required this.theme,
    required this.isDark,
  });

  final String userId;
  final VoidCallback onUnblock;
  final ThemeData theme;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<DocumentSnapshot>(
      future: FirebaseFirestore.instance.collection('users').doc(userId).get(),
      builder: (context, userSnapshot) {
        final isLoading = userSnapshot.connectionState == ConnectionState.waiting;
        String username;
        if (isLoading) {
          username = ''; // Keep space; show placeholder below
        } else if (userSnapshot.hasData) {
          final snap = userSnapshot.data!;
          if (snap.exists) {
            final data = snap.data() as Map<String, dynamic>?;
            username = data?['username'] as String? ?? 'Unknown';
          } else {
            username = 'Unknown';
          }
        } else {
          username = 'Unknown';
        }
        return Card(
          color: theme.colorScheme.surface.withOpacity(0.1),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            leading: CircleAvatar(
              backgroundColor: theme.colorScheme.primary.withOpacity(0.2),
              child: isLoading
                  ? SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: theme.colorScheme.primary,
                      ),
                    )
                  : Icon(
                      Icons.person,
                      color: theme.colorScheme.primary,
                    ),
            ),
            title: isLoading
                ? Text(
                    '…',
                    style: TextStyle(
                      color: theme.colorScheme.onSurface.withOpacity(0.5),
                      fontWeight: FontWeight.w500,
                    ),
                  )
                : Text(
                    username,
                    style: TextStyle(
                      color: theme.colorScheme.onSurface,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
            subtitle: Text(
              'Blocked',
              style: TextStyle(
                color: theme.colorScheme.onSurface.withOpacity(0.6),
                fontSize: 12,
              ),
            ),
            trailing: TextButton(
              onPressed: onUnblock,
              child: const Text('Unblock'),
            ),
          ),
        );
      },
    );
  }
}
