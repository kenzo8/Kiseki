import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../services/theme_preference_service.dart';
import '../main.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  Future<void> _handleLogout(BuildContext context) async {
    final authService = AuthService();
    try {
      await authService.signOut();
      // Navigation will be handled by auth state listener in main.dart
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to sign out: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: isDark
              ? [
                  const Color(0xFF02081A),
                  const Color(0xFF04102C),
                ]
              : [
                  Colors.grey.shade100,
                  Colors.grey.shade200,
                ],
        ),
      ),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: Icon(
              Icons.arrow_back,
              color: theme.colorScheme.onSurface,
            ),
            onPressed: () => Navigator.of(context).pop(),
          ),
          title: Text(
            'Settings',
            style: TextStyle(
              color: theme.colorScheme.onSurface,
              fontSize: 24,
              fontWeight: FontWeight.w600,
              letterSpacing: 2,
            ),
          ),
        ),
        body: SafeArea(
          child: ValueListenableBuilder<ThemeMode>(
            valueListenable: themeModeNotifier,
            builder: (context, currentThemeMode, child) {
              final isDarkMode = currentThemeMode == ThemeMode.dark;
              return ListView(
                padding: const EdgeInsets.all(16.0),
                children: [
                  // Dark Mode Toggle
                  Card(
                    color: theme.colorScheme.surface.withOpacity(0.1),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: SwitchListTile(
                      title: Row(
                        children: [
                          Icon(
                            Icons.dark_mode,
                            size: 20,
                            color: theme.colorScheme.onSurface,
                          ),
                          const SizedBox(width: 12),
                          Text(
                            'Dark Mode',
                            style: TextStyle(
                              color: theme.colorScheme.onSurface,
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                      value: isDarkMode,
                      onChanged: (value) async {
                        // Update the theme immediately
                        themeModeNotifier.value = value ? ThemeMode.dark : ThemeMode.light;
                        // Save the preference persistently
                        await ThemePreferenceService.saveThemePreference(value);
                      },
                      activeColor: theme.colorScheme.primary,
                      inactiveThumbColor: Colors.grey.shade300,
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Logout Button
                  Card(
                    color: theme.colorScheme.surface.withOpacity(0.1),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: ListTile(
                      leading: Icon(
                        Icons.logout,
                        color: theme.colorScheme.onSurface,
                      ),
                      title: Text(
                        'Logout',
                        style: TextStyle(
                          color: theme.colorScheme.onSurface,
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      onTap: () => _handleLogout(context),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
