// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Japanese (`ja`).
class AppLocalizationsJa extends AppLocalizations {
  AppLocalizationsJa([String locale = 'ja']) : super(locale);

  @override
  String get appTitle => 'kien';

  @override
  String get cancel => 'キャンセル';

  @override
  String get ok => 'OK';

  @override
  String get save => '保存';

  @override
  String get create => '作成';

  @override
  String get explore => '探索';

  @override
  String get profile => 'プロフィール';

  @override
  String get addDevice => 'デバイスを追加';

  @override
  String get editDevice => 'デバイスを編集';

  @override
  String get deviceName => 'デバイス名';

  @override
  String get category => 'カテゴリ';

  @override
  String get period => '期間';

  @override
  String get startDate => '開始日';

  @override
  String get endDate => '終了日';

  @override
  String get inUse => '使用中';

  @override
  String get present => '現在';

  @override
  String get yearsOnly => '年のみ';

  @override
  String get publicOnExplore => '探索で公開';

  @override
  String get deviceNameHint => 'このデバイスの特別な点は何ですか？';

  @override
  String get pleaseEnterDeviceName => 'デバイス名を入力してください';

  @override
  String get pleaseAddNote => '短いメモを追加してください';

  @override
  String get deviceAddedSuccessfully => 'デバイスが正常に追加されました！';

  @override
  String get deviceUpdatedSuccessfully => 'デバイスが正常に更新されました！';

  @override
  String failedToAddDevice(String error) {
    return 'デバイスの追加に失敗しました：$error';
  }

  @override
  String failedToUpdateDevice(String error) {
    return 'デバイスの更新に失敗しました：$error';
  }

  @override
  String get time => '時間';

  @override
  String get impression => '印象';

  @override
  String get settings => '設定';

  @override
  String get language => '言語';

  @override
  String get selectLanguage => '言語を選択';

  @override
  String get systemDefault => 'システムデフォルト';

  @override
  String get exportData => 'データをエクスポート';

  @override
  String get importData => 'データをインポート';

  @override
  String get blockedUsers => 'ブロック済みユーザー';

  @override
  String get privacyPolicy => 'プライバシーポリシー';

  @override
  String get feedback => 'フィードバック';

  @override
  String get logout => 'ログアウト';

  @override
  String get deleteAccount => 'アカウントを削除';

  @override
  String get exportDataTitle => 'データをエクスポート';

  @override
  String get account => 'アカウント';

  @override
  String get chooseExportFormat => 'エクスポート形式を選択：';

  @override
  String get noDataToExport => 'エクスポートするデータがありません';

  @override
  String get exportFailed => 'エクスポートに失敗しました';

  @override
  String exportError(String error) {
    return 'エクスポートエラー：$error';
  }

  @override
  String get importDataTitle => 'データをインポート';

  @override
  String get importDataMessage =>
      'データをインポートすると、アカウントに新しいデバイスが追加されます。サポート形式：CSV、XLSX。\n\n注意：最初の100行のデータのみが読み込まれます。ファイルにそれ以上の行がある場合は、分割してインポートしてください。';

  @override
  String get import => 'インポート';

  @override
  String get pleaseSelectCsvOrXlsx => 'CSVまたはXLSXファイルを選択してください';

  @override
  String get importComplete => 'インポート完了';

  @override
  String get importFailed => 'インポートに失敗しました';

  @override
  String get errorDetails => 'エラー詳細：';

  @override
  String importError(String error) {
    return 'インポートエラー：$error';
  }

  @override
  String get logoutTitle => 'ログアウト';

  @override
  String get areYouSureLogout => 'ログアウトしてもよろしいですか？';

  @override
  String get deleteAccountTitle => 'アカウントを削除';

  @override
  String get deleteAccountMessage =>
      '削除後、アカウントおよびすべてのデバイスとウィッシュリストデータは永久に削除され、復元できません。';

  @override
  String get yourAccount => 'アカウント：';

  @override
  String get typeEmailToConfirm => '確認のためメールアドレスを入力してください';

  @override
  String get pleaseLoginFirst => 'まずログインしてください';

  @override
  String get pleaseLogInFirst => 'まずログインしてください';

  @override
  String failedToSignOut(String error) {
    return 'ログアウトに失敗しました：$error';
  }

  @override
  String failedToDeleteAccount(String error) {
    return 'アカウントの削除に失敗しました：$error';
  }

  @override
  String get couldNotOpenPrivacyPolicy => 'プライバシーポリシーを開けませんでした';
}
