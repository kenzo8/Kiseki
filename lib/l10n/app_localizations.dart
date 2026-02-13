import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_ja.dart';
import 'app_localizations_zh.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('ja'),
    Locale('zh'),
  ];

  /// The application title
  ///
  /// In en, this message translates to:
  /// **'kien'**
  String get appTitle;

  /// Cancel button text
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// OK button text
  ///
  /// In en, this message translates to:
  /// **'OK'**
  String get ok;

  /// Save button text
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

  /// Create button text
  ///
  /// In en, this message translates to:
  /// **'Create'**
  String get create;

  /// Explore tab label
  ///
  /// In en, this message translates to:
  /// **'Explore'**
  String get explore;

  /// Profile tab label
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get profile;

  /// Add device page title
  ///
  /// In en, this message translates to:
  /// **'Add Device'**
  String get addDevice;

  /// Edit device page title
  ///
  /// In en, this message translates to:
  /// **'Edit Device'**
  String get editDevice;

  /// Device name field label
  ///
  /// In en, this message translates to:
  /// **'Device Name'**
  String get deviceName;

  /// Category label
  ///
  /// In en, this message translates to:
  /// **'Category'**
  String get category;

  /// Period label
  ///
  /// In en, this message translates to:
  /// **'Period'**
  String get period;

  /// Start date label
  ///
  /// In en, this message translates to:
  /// **'Start Date'**
  String get startDate;

  /// End date label
  ///
  /// In en, this message translates to:
  /// **'End Date'**
  String get endDate;

  /// In use toggle label
  ///
  /// In en, this message translates to:
  /// **'In Use'**
  String get inUse;

  /// Present time indicator
  ///
  /// In en, this message translates to:
  /// **'Present'**
  String get present;

  /// Years only mode label
  ///
  /// In en, this message translates to:
  /// **'Years Only'**
  String get yearsOnly;

  /// Public on explore indicator
  ///
  /// In en, this message translates to:
  /// **'Public on Explore'**
  String get publicOnExplore;

  /// Device name hint text
  ///
  /// In en, this message translates to:
  /// **'What makes this device special to you?'**
  String get deviceNameHint;

  /// Device name validation message
  ///
  /// In en, this message translates to:
  /// **'Please enter a device name'**
  String get pleaseEnterDeviceName;

  /// Note validation message
  ///
  /// In en, this message translates to:
  /// **'Please add a short note'**
  String get pleaseAddNote;

  /// Success message when device is added
  ///
  /// In en, this message translates to:
  /// **'Device added successfully!'**
  String get deviceAddedSuccessfully;

  /// Success message when device is updated
  ///
  /// In en, this message translates to:
  /// **'Device updated successfully!'**
  String get deviceUpdatedSuccessfully;

  /// Error message when device add fails
  ///
  /// In en, this message translates to:
  /// **'Failed to add device: {error}'**
  String failedToAddDevice(String error);

  /// Error message when device update fails
  ///
  /// In en, this message translates to:
  /// **'Failed to update device: {error}'**
  String failedToUpdateDevice(String error);

  /// Time section label
  ///
  /// In en, this message translates to:
  /// **'TIME'**
  String get time;

  /// Impression section label
  ///
  /// In en, this message translates to:
  /// **'IMPRESSION'**
  String get impression;

  /// Settings page title
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settings;

  /// Language setting label
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get language;

  /// Language selection dialog title
  ///
  /// In en, this message translates to:
  /// **'Select Language'**
  String get selectLanguage;

  /// System default language option
  ///
  /// In en, this message translates to:
  /// **'System Default'**
  String get systemDefault;

  /// Export data setting label
  ///
  /// In en, this message translates to:
  /// **'Export Data'**
  String get exportData;

  /// Import data setting label
  ///
  /// In en, this message translates to:
  /// **'Import Data'**
  String get importData;

  /// Blocked users setting label
  ///
  /// In en, this message translates to:
  /// **'Blocked users'**
  String get blockedUsers;

  /// Privacy policy setting label
  ///
  /// In en, this message translates to:
  /// **'Privacy Policy'**
  String get privacyPolicy;

  /// Feedback setting label
  ///
  /// In en, this message translates to:
  /// **'Feedback'**
  String get feedback;

  /// Logout setting label
  ///
  /// In en, this message translates to:
  /// **'Logout'**
  String get logout;

  /// Delete account setting label
  ///
  /// In en, this message translates to:
  /// **'Delete Account'**
  String get deleteAccount;

  /// Export data dialog title
  ///
  /// In en, this message translates to:
  /// **'Export Data'**
  String get exportDataTitle;

  /// Account label
  ///
  /// In en, this message translates to:
  /// **'Account'**
  String get account;

  /// Choose export format label
  ///
  /// In en, this message translates to:
  /// **'Choose export format:'**
  String get chooseExportFormat;

  /// No data to export message
  ///
  /// In en, this message translates to:
  /// **'No data to export'**
  String get noDataToExport;

  /// Export failed message
  ///
  /// In en, this message translates to:
  /// **'Export failed'**
  String get exportFailed;

  /// Export error message
  ///
  /// In en, this message translates to:
  /// **'Export error: {error}'**
  String exportError(String error);

  /// Import data dialog title
  ///
  /// In en, this message translates to:
  /// **'Import Data'**
  String get importDataTitle;

  /// Import data dialog message
  ///
  /// In en, this message translates to:
  /// **'Importing data will add new devices to your account. Supported formats: CSV, XLSX.\n\nNote: Only the first 100 data rows will be read. If your file has more rows, split it or import in batches.'**
  String get importDataMessage;

  /// Import button text
  ///
  /// In en, this message translates to:
  /// **'Import'**
  String get import;

  /// Please select CSV or XLSX file message
  ///
  /// In en, this message translates to:
  /// **'Please select a CSV or XLSX file'**
  String get pleaseSelectCsvOrXlsx;

  /// Import complete dialog title
  ///
  /// In en, this message translates to:
  /// **'Import Complete'**
  String get importComplete;

  /// Import failed dialog title
  ///
  /// In en, this message translates to:
  /// **'Import Failed'**
  String get importFailed;

  /// Error details label
  ///
  /// In en, this message translates to:
  /// **'Error Details:'**
  String get errorDetails;

  /// Import error message
  ///
  /// In en, this message translates to:
  /// **'Import error: {error}'**
  String importError(String error);

  /// Logout dialog title
  ///
  /// In en, this message translates to:
  /// **'Logout'**
  String get logoutTitle;

  /// Logout confirmation message
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to logout?'**
  String get areYouSureLogout;

  /// Delete account dialog title
  ///
  /// In en, this message translates to:
  /// **'Delete Account'**
  String get deleteAccountTitle;

  /// Delete account warning message
  ///
  /// In en, this message translates to:
  /// **'After deletion, your account and all device and wishlist data will be permanently removed and cannot be recovered.'**
  String get deleteAccountMessage;

  /// Your account label
  ///
  /// In en, this message translates to:
  /// **'Your account:'**
  String get yourAccount;

  /// Type email to confirm label
  ///
  /// In en, this message translates to:
  /// **'Type your email to confirm'**
  String get typeEmailToConfirm;

  /// Please login first message
  ///
  /// In en, this message translates to:
  /// **'Please login first'**
  String get pleaseLoginFirst;

  /// Please log in first message
  ///
  /// In en, this message translates to:
  /// **'Please log in first'**
  String get pleaseLogInFirst;

  /// Failed to sign out message
  ///
  /// In en, this message translates to:
  /// **'Failed to sign out: {error}'**
  String failedToSignOut(String error);

  /// Failed to delete account message
  ///
  /// In en, this message translates to:
  /// **'Failed to delete account: {error}'**
  String failedToDeleteAccount(String error);

  /// Could not open privacy policy message
  ///
  /// In en, this message translates to:
  /// **'Could not open Privacy Policy'**
  String get couldNotOpenPrivacyPolicy;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'ja', 'zh'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'ja':
      return AppLocalizationsJa();
    case 'zh':
      return AppLocalizationsZh();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
