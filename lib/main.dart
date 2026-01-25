import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'firebase_options.dart';
import 'pages/login_page.dart';
import 'pages/explore_page.dart';
import 'pages/circle_page.dart';
import 'pages/inbox_page.dart';
import 'pages/profile_page.dart';
import 'pages/add_device_page.dart';
import 'services/theme_preference_service.dart';

// Global theme state
late final ValueNotifier<ThemeMode> themeModeNotifier;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize Firebase
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  
  // Load theme preference before runApp to prevent flickering
  final isDarkMode = await ThemePreferenceService.loadThemePreference();
  themeModeNotifier = ValueNotifier<ThemeMode>(
    isDarkMode ? ThemeMode.dark : ThemeMode.light,
  );
  
  runApp(const KisekiApp());
}

class KisekiApp extends StatelessWidget {
  const KisekiApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeModeNotifier,
      builder: (context, themeMode, child) {
        return MaterialApp(
          title: 'Kiseki',
          debugShowCheckedModeBanner: false,
          theme: ThemeData(
            useMaterial3: true,
            colorScheme: ColorScheme.fromSeed(
              seedColor: const Color(0xFF02081A),
              brightness: Brightness.light,
            ),
          ),
          darkTheme: ThemeData(
            useMaterial3: true,
            colorScheme: ColorScheme.fromSeed(
              seedColor: const Color(0xFF02081A),
              brightness: Brightness.dark,
            ),
          ),
          themeMode: themeMode,
          home: const MainNavigationScreen(),
        );
      },
    );
  }
}

class MainNavigationScreen extends StatelessWidget {
  const MainNavigationScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        // Show loading while checking auth state
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(),
            ),
          );
        }

        // Show login page if not authenticated
        final user = snapshot.data;
        if (user == null) {
          return const LoginPage();
        }

        // Show main navigation if authenticated
        return _MainNavigationContent(user: user);
      },
    );
  }
}

class _MainNavigationContent extends StatefulWidget {
  final User user;

  const _MainNavigationContent({required this.user});

  @override
  State<_MainNavigationContent> createState() => _MainNavigationContentState();
}

class _MainNavigationContentState extends State<_MainNavigationContent> {
  int _currentIndex = 0;

  void _showSendSekiBottomSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const AddDevicePage(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: [
          ExplorePage(user: widget.user),
          const CirclePage(),
          const InboxPage(),
          ProfilePage(user: widget.user),
        ],
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF02081A) : theme.colorScheme.surface,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.3),
              blurRadius: 10,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildNavItem(
              icon: Icons.explore,
              label: 'Explore',
              index: 0,
              isSelected: _currentIndex == 0,
              theme: theme,
              isDark: isDark,
              onTap: () => setState(() => _currentIndex = 0),
            ),
            _buildNavItem(
              icon: Icons.people,
              label: 'Circle',
              index: 1,
              isSelected: _currentIndex == 1,
              theme: theme,
              isDark: isDark,
              onTap: () => setState(() => _currentIndex = 1),
            ),
            _buildCenterButton(theme, isDark),
            _buildNavItem(
              icon: Icons.inbox,
              label: 'Inbox',
              index: 2,
              isSelected: _currentIndex == 2,
              theme: theme,
              isDark: isDark,
              onTap: () => setState(() => _currentIndex = 2),
            ),
            _buildNavItem(
              icon: Icons.person,
              label: 'Profile',
              index: 3,
              isSelected: _currentIndex == 3,
              theme: theme,
              isDark: isDark,
              onTap: () => setState(() => _currentIndex = 3),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNavItem({
    required IconData icon,
    required String label,
    required int index,
    required bool isSelected,
    required ThemeData theme,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                color: isSelected
                    ? (isDark ? Colors.white : theme.colorScheme.primary)
                    : (isDark ? Colors.white.withOpacity(0.5) : theme.colorScheme.onSurface.withOpacity(0.6)),
                size: 24,
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                  color: isSelected
                      ? (isDark ? Colors.white : theme.colorScheme.primary)
                      : (isDark ? Colors.white.withOpacity(0.5) : theme.colorScheme.onSurface.withOpacity(0.6)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCenterButton(ThemeData theme, bool isDark) {
    return Expanded(
      child: InkWell(
        onTap: _showSendSekiBottomSheet,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: isDark ? Colors.white : const Color(0xFF02081A),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.add,
                  color: isDark ? const Color(0xFF02081A) : Colors.white,
                  size: 24,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
