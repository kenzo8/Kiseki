// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'kien';

  @override
  String get cancel => 'Cancel';

  @override
  String get ok => 'OK';

  @override
  String get save => 'Save';

  @override
  String get create => 'Create';

  @override
  String get explore => 'Explore';

  @override
  String get profile => 'Profile';

  @override
  String get addDevice => 'Add Device';

  @override
  String get editDevice => 'Edit Device';

  @override
  String get deviceName => 'Device Name';

  @override
  String get category => 'Category';

  @override
  String get period => 'Period';

  @override
  String get startDate => 'Start Date';

  @override
  String get endDate => 'End Date';

  @override
  String get inUse => 'In Use';

  @override
  String get present => 'Present';

  @override
  String get yearsOnly => 'Years Only';

  @override
  String get publicOnExplore => 'Public on Explore';

  @override
  String get deviceNameHint => 'What makes this device special to you?';

  @override
  String get pleaseEnterDeviceName => 'Please enter a device name';

  @override
  String get pleaseAddNote => 'Please add a short note';

  @override
  String get deviceAddedSuccessfully => 'Device added successfully!';

  @override
  String get deviceUpdatedSuccessfully => 'Device updated successfully!';

  @override
  String failedToAddDevice(String error) {
    return 'Failed to add device: $error';
  }

  @override
  String failedToUpdateDevice(String error) {
    return 'Failed to update device: $error';
  }

  @override
  String get time => 'TIME';

  @override
  String get impression => 'IMPRESSION';

  @override
  String get settings => 'Settings';

  @override
  String get language => 'Language';

  @override
  String get selectLanguage => 'Select Language';

  @override
  String get systemDefault => 'System Default';

  @override
  String get exportData => 'Export Data';

  @override
  String get importData => 'Import Data';

  @override
  String get blockedUsers => 'Blocked users';

  @override
  String get privacyPolicy => 'Privacy Policy';

  @override
  String get feedback => 'Feedback';

  @override
  String get logout => 'Logout';

  @override
  String get deleteAccount => 'Delete Account';

  @override
  String get exportDataTitle => 'Export Data';

  @override
  String get account => 'Account';

  @override
  String get chooseExportFormat => 'Choose export format:';

  @override
  String get noDataToExport => 'No data to export';

  @override
  String get exportFailed => 'Export failed';

  @override
  String exportError(String error) {
    return 'Export error: $error';
  }

  @override
  String get importDataTitle => 'Import Data';

  @override
  String get importDataMessage =>
      'Importing data will add new devices to your account. Supported formats: CSV, XLSX.\n\nNote: Only the first 100 data rows will be read. If your file has more rows, split it or import in batches.';

  @override
  String get import => 'Import';

  @override
  String get pleaseSelectCsvOrXlsx => 'Please select a CSV or XLSX file';

  @override
  String get importComplete => 'Import Complete';

  @override
  String get importFailed => 'Import Failed';

  @override
  String get errorDetails => 'Error Details:';

  @override
  String importError(String error) {
    return 'Import error: $error';
  }

  @override
  String get logoutTitle => 'Logout';

  @override
  String get areYouSureLogout => 'Are you sure you want to logout?';

  @override
  String get deleteAccountTitle => 'Delete Account';

  @override
  String get deleteAccountMessage =>
      'After deletion, your account and all device and wishlist data will be permanently removed and cannot be recovered.';

  @override
  String get yourAccount => 'Your account:';

  @override
  String get typeEmailToConfirm => 'Type your email to confirm';

  @override
  String get pleaseLoginFirst => 'Please login first';

  @override
  String get pleaseLogInFirst => 'Please log in first';

  @override
  String failedToSignOut(String error) {
    return 'Failed to sign out: $error';
  }

  @override
  String failedToDeleteAccount(String error) {
    return 'Failed to delete account: $error';
  }

  @override
  String get couldNotOpenPrivacyPolicy => 'Could not open Privacy Policy';
}
