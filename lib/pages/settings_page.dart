import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/auth_service.dart';
import '../services/system_ui_service.dart';
import '../services/import_export_service.dart' show ImportExportService, ExportFormat;
import '../services/profile_data_service.dart';
import '../main.dart';
import 'login_page.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {

  bool _isExporting = false;
  bool _isImporting = false;
  bool _isDeletingAccount = false;
  PackageInfo? _packageInfo;

  @override
  void initState() {
    super.initState();
    PackageInfo.fromPlatform().then((info) {
      if (mounted) setState(() => _packageInfo = info);
    });
  }

  Future<void> _handleExport() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      if (mounted) {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => const LoginPage(),
          ),
        );
      }
      return;
    }

    // Ask for format: Cancel, CSV, or XLSX
    final format = await showDialog<ExportFormat>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Export Data'),
        content: const Text('Choose export format:'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(ExportFormat.csv),
            child: const Text('CSV'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(ExportFormat.xlsx),
            child: const Text('XLSX'),
          ),
        ],
      ),
    );

    if (format == null || !mounted) return;

    setState(() {
      _isExporting = true;
    });

    try {
      // Get user's devices
      final dataService = ProfileDataService.instance;
      if (dataService.cachedSekis == null || dataService.cachedSekis!.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('No data to export'),
              backgroundColor: Colors.orange,
            ),
          );
        }
        return;
      }

      // Export to selected format
      final filePath = await ImportExportService.export(dataService.cachedSekis!, format);
      
      if (filePath != null && mounted) {
        // Share the file
        await Share.shareXFiles(
          [XFile(filePath)],
          text: 'Device Data Export',
        );
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Export successful!'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Export failed'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Export error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isExporting = false;
        });
      }
    }
  }

  Future<void> _handleImport() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please login first'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    // Show confirmation dialog
    final shouldImport = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Import Data'),
        content: const Text(
          'Importing data will add new devices to your account. Supported formats: CSV, XLSX. Continue?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Import'),
          ),
        ],
      ),
    );

    if (shouldImport != true) return;

    setState(() {
      _isImporting = true;
    });

    try {
      // Pick file (CSV or XLSX)
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['csv', 'xlsx'],
      );

      if (result == null || result.files.single.path == null) {
        if (mounted) {
          setState(() {
            _isImporting = false;
          });
        }
        return;
      }

      final filePath = result.files.single.path!;
      
      // Import from file (auto-detect format)
      final importResult = await ImportExportService.importFromFile(filePath);
      
      if (mounted) {
        // Refresh data
        await ProfileDataService.instance.refresh();
        
        // Show result dialog
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(importResult.success ? 'Import Complete' : 'Import Failed'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(importResult.message),
                  if (importResult.errors.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    const Text(
                      'Error Details:',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    ...importResult.errors.take(10).map((error) => Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text(
                        error,
                        style: const TextStyle(fontSize: 12),
                      ),
                    )),
                    if (importResult.errors.length > 10)
                      Text('...and ${importResult.errors.length - 10} more errors'),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Import error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isImporting = false;
        });
      }
    }
  }

  Future<void> _handleLogout(BuildContext context) async {
    // Show confirmation dialog
    final shouldLogout = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Logout'),
          ),
        ],
      ),
    );

    // If user confirmed logout
    if (shouldLogout == true && context.mounted) {
      final authService = AuthService();
      try {
        // Clear authentication tokens/sessions
        await authService.signOut();
        
        // Navigate to MainNavigationScreen and remove all previous routes from stack
        // MainNavigationScreen will automatically show LoginPage based on auth state
        if (context.mounted) {
          Navigator.of(context).pushAndRemoveUntil(
            PageRouteBuilder(
              pageBuilder: (context, animation, secondaryAnimation) => const MainNavigationScreen(),
              transitionDuration: Duration.zero,
              reverseTransitionDuration: Duration.zero,
            ),
            (route) => false,
          );
        }
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
  }

  Future<void> _handleDeleteAccount(BuildContext context) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please log in first'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Account'),
        content: const Text(
          'After deletion, your account and all device and wishlist data will be permanently removed and cannot be recovered. Are you sure you want to delete your account?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(
              foregroundColor: Colors.red,
            ),
            child: const Text('Delete Account'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() {
      _isDeletingAccount = true;
    });

    try {
      final authService = AuthService();
      ProfileDataService.instance.clearCache();
      await authService.deleteAccount();
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        PageRouteBuilder(
          pageBuilder: (context, animation, secondaryAnimation) => const MainNavigationScreen(),
          transitionDuration: Duration.zero,
          reverseTransitionDuration: Duration.zero,
        ),
        (route) => false,
      );
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      final message = e.code == 'requires-recent-login'
          ? 'For security, please log out, log back in, and try again to delete your account.'
          : AuthService().authExceptionMessage(e);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.red,
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to delete account: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isDeletingAccount = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    
    // Set immersive status bar
    final gradientColors = isDark
        ? [
            const Color(0xFF02081A),
            const Color(0xFF04102C),
          ]
        : [
            Colors.grey.shade100,
            Colors.grey.shade200,
          ];
    SystemUIService.setImmersiveStatusBar(
      context,
      backgroundColor: gradientColors.first,
    );

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
          child: ListView(
            padding: const EdgeInsets.all(16.0),
            children: [
              // Current account (when logged in)
              if (FirebaseAuth.instance.currentUser?.email != null) ...[
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Text(
                    'Logged in as ${FirebaseAuth.instance.currentUser!.email}',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurface.withOpacity(0.7),
                      fontSize: 14,
                    ),
                  ),
                ),
              ],
              Builder(
                builder: (context) {
                  final tileStyle = TextStyle(
                    color: theme.colorScheme.onSurface,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  );
                  final leadingColor = theme.colorScheme.onSurface;
                  const tilePadding = EdgeInsets.symmetric(horizontal: 16, vertical: 4);
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Export
                      Card(
                        color: theme.colorScheme.surface.withOpacity(0.1),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: ListTile(
                          contentPadding: tilePadding,
                          leading: _isExporting
                              ? SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(leadingColor),
                                  ),
                                )
                              : Icon(Icons.upload_file, color: leadingColor, size: 24),
                          title: Text('Export Data', style: tileStyle),
                          onTap: _isExporting ? null : _handleExport,
                        ),
                      ),
                      const SizedBox(height: 12),
                      // Import
                      Card(
                        color: theme.colorScheme.surface.withOpacity(0.1),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: ListTile(
                          contentPadding: tilePadding,
                          leading: _isImporting
                              ? SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(leadingColor),
                                  ),
                                )
                              : Icon(Icons.download, color: leadingColor, size: 24),
                          title: Text('Import Data', style: tileStyle),
                          onTap: _isImporting ? null : _handleImport,
                        ),
                      ),
                      const SizedBox(height: 12),
                      // Privacy Policy
                      Card(
                        color: theme.colorScheme.surface.withOpacity(0.1),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: ListTile(
                          contentPadding: tilePadding,
                          leading: Icon(Icons.privacy_tip_outlined, color: leadingColor, size: 24),
                          title: Text('Privacy Policy', style: tileStyle),
                          trailing: Icon(Icons.open_in_new, color: leadingColor.withOpacity(0.6), size: 20),
                          onTap: () async {
                            final uri = Uri.parse('https://kenzo8.github.io/kien-privacy/');
                            if (await canLaunchUrl(uri)) {
                              await launchUrl(uri, mode: LaunchMode.externalApplication);
                            }
                          },
                        ),
                      ),
                      const SizedBox(height: 12),
                      // Terms of Service
                      Card(
                        color: theme.colorScheme.surface.withOpacity(0.1),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: ListTile(
                          contentPadding: tilePadding,
                          leading: Icon(Icons.description_outlined, color: leadingColor, size: 24),
                          title: Text('Terms of Service', style: tileStyle),
                          trailing: Icon(Icons.open_in_new, color: leadingColor.withOpacity(0.6), size: 20),
                          onTap: () async {
                            final uri = Uri.parse('https://kenzo8.github.io/kien-privacy/terms');
                            if (await canLaunchUrl(uri)) {
                              await launchUrl(uri, mode: LaunchMode.externalApplication);
                            }
                          },
                        ),
                      ),
                      const SizedBox(height: 12),
                      // Feedback / Contact
                      Card(
                        color: theme.colorScheme.surface.withOpacity(0.1),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: ListTile(
                          contentPadding: tilePadding,
                          leading: Icon(Icons.feedback_outlined, color: leadingColor, size: 24),
                          title: Text('Feedback & Support', style: tileStyle),
                          trailing: Icon(Icons.open_in_new, color: leadingColor.withOpacity(0.6), size: 20),
                          onTap: () async {
                            final uri = Uri.parse('mailto:support@example.com?subject=Kien%20App%20Feedback');
                            if (await canLaunchUrl(uri)) {
                              await launchUrl(uri, mode: LaunchMode.externalApplication);
                            }
                          },
                        ),
                      ),
                      const SizedBox(height: 12),
                      // Logout
                      Card(
                        color: theme.colorScheme.surface.withOpacity(0.1),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: ListTile(
                          contentPadding: tilePadding,
                          leading: Icon(Icons.logout, color: leadingColor, size: 24),
                          title: Text('Logout', style: tileStyle),
                          onTap: () => _handleLogout(context),
                        ),
                      ),
                      const SizedBox(height: 12),
                      // Delete Account
                      Card(
                        color: theme.colorScheme.surface.withOpacity(0.1),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: ListTile(
                          contentPadding: tilePadding,
                          leading: _isDeletingAccount
                              ? SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(leadingColor),
                                  ),
                                )
                              : Icon(Icons.person_off, color: leadingColor, size: 24),
                          title: Text('Delete Account', style: tileStyle),
                          onTap: _isDeletingAccount ? null : () => _handleDeleteAccount(context),
                        ),
                      ),
                      const SizedBox(height: 24),
                      // About / App version
                      Center(
                        child: Text(
                          _packageInfo != null
                              ? '${_packageInfo!.appName} v${_packageInfo!.version} (${_packageInfo!.buildNumber})'
                              : 'Loading…',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurface.withOpacity(0.5),
                            fontSize: 12,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
