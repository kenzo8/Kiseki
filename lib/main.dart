import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'firebase_options.dart';
import 'pages/explore_page.dart';
import 'pages/profile_page.dart';
import 'pages/add_device_page.dart';
import 'pages/login_page.dart';
import 'services/system_ui_service.dart';

// Global theme state
late final ValueNotifier<ThemeMode> themeModeNotifier;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize Firebase
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Always use light mode
  themeModeNotifier = ValueNotifier<ThemeMode>(ThemeMode.light);
  
  runApp(const KienApp());
}

class KienApp extends StatelessWidget {
  const KienApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeModeNotifier,
      builder: (context, themeMode, child) {
        // Set initial status bar style based on theme
        WidgetsBinding.instance.addPostFrameCallback((_) {
          final isDark = themeMode == ThemeMode.dark;
          if (isDark) {
            SystemUIService.setDarkStatusBar();
          } else {
            SystemUIService.setLightStatusBar();
          }
        });
        
        return MaterialApp(
          title: 'kien',
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
          builder: (context, child) {
            return MediaQuery(
              data: MediaQuery.of(context).copyWith(textScaler: TextScaler.noScaling),
              child: child!,
            );
          },
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

        // Always show main navigation, even if not authenticated
        final user = snapshot.data;
        return _MainNavigationContent(user: user);
      },
    );
  }
}

class _MainNavigationContent extends StatefulWidget {
  final User? user;

  const _MainNavigationContent({this.user});

  @override
  State<_MainNavigationContent> createState() => _MainNavigationContentState();
}

class _MainNavigationContentState extends State<_MainNavigationContent> {
  int _currentIndex = 0;
  final ValueNotifier<bool> _exploreRefreshNotifier = ValueNotifier<bool>(false);
  final ValueNotifier<bool> _exploreScrollToTopNotifier = ValueNotifier<bool>(false);
  final ValueNotifier<bool> _profileScrollToTopNotifier = ValueNotifier<bool>(false);

  void _showSendSekiBottomSheet() async {
    // Intercept at plus tap: require login before opening add-device sheet
    if (widget.user == null) {
      Navigator.of(context).push(
        MaterialPageRoute(builder: (context) => const LoginPage()),
      );
      return;
    }
    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const AddDevicePage(),
    );
    
    // If device was added/updated successfully, refresh explore page
    if (result == true) {
      _exploreRefreshNotifier.value = true;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    
    // Use the exact same color for both system navigation bar and bottom navigation bar
    // Match the colors used in setDarkStatusBar() and setLightStatusBar()
    final bottomBarColor = isDark ? const Color(0xFF02081A) : Colors.white;
    
    // Create system UI overlay style with matching bottom bar color
    final systemUiOverlayStyle = SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
      statusBarBrightness: isDark ? Brightness.dark : Brightness.light,
      systemNavigationBarColor: bottomBarColor,
      systemNavigationBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
      systemNavigationBarDividerColor: Colors.transparent,
    );
    
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: systemUiOverlayStyle,
      child: Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: [
          ExplorePage(
            refreshNotifier: _exploreRefreshNotifier,
            scrollToTopNotifier: _exploreScrollToTopNotifier,
            user: widget.user,
          ),
          ProfilePage(
            user: widget.user,
            onGoToExplore: () => setState(() => _currentIndex = 0),
            exploreRefreshNotifier: _exploreRefreshNotifier,
            scrollToTopNotifier: _profileScrollToTopNotifier,
          ),
        ],
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: bottomBarColor,
        ),
        child: SafeArea(
          top: false,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
            _buildNavItem(
              icon: Icons.explore,
              iconOutlined: Icons.explore_outlined,
              label: 'Explore',
              index: 0,
              isSelected: _currentIndex == 0,
              theme: theme,
              isDark: isDark,
              onTap: () {
                if (_currentIndex == 0) {
                  _exploreScrollToTopNotifier.value = true;
                } else {
                  setState(() => _currentIndex = 0);
                }
              },
            ),
            _buildCenterButton(theme, isDark),
            _buildNavItem(
              icon: Icons.person,
              iconOutlined: Icons.person_outline,
              label: 'Profile',
              index: 1,
              isSelected: _currentIndex == 1,
              theme: theme,
              isDark: isDark,
              onTap: () {
                if (_currentIndex == 1) {
                  _profileScrollToTopNotifier.value = true;
                } else {
                  setState(() => _currentIndex = 1);
                }
              },
            ),
          ],
        ),
        ),
      ),
      ),
    );
  }

  Widget _buildNavItem({
    required IconData icon,
    required IconData iconOutlined,
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
                isSelected ? icon : iconOutlined,
                color: isSelected
                    ? (isDark ? Colors.white : Colors.black)
                    : (isDark ? Colors.white.withOpacity(0.6) : Colors.black.withOpacity(0.6)),
                size: 24,
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w400,
                  color: isSelected
                      ? (isDark ? Colors.white : Colors.black)
                      : (isDark ? Colors.white.withOpacity(0.6) : Colors.black.withOpacity(0.6)),
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
