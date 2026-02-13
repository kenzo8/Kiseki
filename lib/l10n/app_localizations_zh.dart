// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Chinese (`zh`).
class AppLocalizationsZh extends AppLocalizations {
  AppLocalizationsZh([String locale = 'zh']) : super(locale);

  @override
  String get appTitle => 'kien';

  @override
  String get cancel => '取消';

  @override
  String get ok => '确定';

  @override
  String get save => '保存';

  @override
  String get create => '创建';

  @override
  String get explore => '探索';

  @override
  String get profile => '个人资料';

  @override
  String get addDevice => '添加设备';

  @override
  String get editDevice => '编辑设备';

  @override
  String get deviceName => '设备名称';

  @override
  String get category => '类别';

  @override
  String get period => '时间段';

  @override
  String get startDate => '开始日期';

  @override
  String get endDate => '结束日期';

  @override
  String get inUse => '使用中';

  @override
  String get present => '至今';

  @override
  String get yearsOnly => '仅年份';

  @override
  String get publicOnExplore => '在探索中公开';

  @override
  String get deviceNameHint => '这个设备对你有什么特别之处？';

  @override
  String get pleaseEnterDeviceName => '请输入设备名称';

  @override
  String get pleaseAddNote => '请添加简短备注';

  @override
  String get deviceAddedSuccessfully => '设备添加成功！';

  @override
  String get deviceUpdatedSuccessfully => '设备更新成功！';

  @override
  String failedToAddDevice(String error) {
    return '添加设备失败：$error';
  }

  @override
  String failedToUpdateDevice(String error) {
    return '更新设备失败：$error';
  }

  @override
  String get time => '时间';

  @override
  String get impression => '印象';

  @override
  String get settings => '设置';

  @override
  String get language => '语言';

  @override
  String get selectLanguage => '选择语言';

  @override
  String get systemDefault => '系统默认';

  @override
  String get exportData => '导出数据';

  @override
  String get importData => '导入数据';

  @override
  String get blockedUsers => '已屏蔽用户';

  @override
  String get privacyPolicy => '隐私政策';

  @override
  String get feedback => '反馈';

  @override
  String get logout => '退出登录';

  @override
  String get deleteAccount => '删除账户';

  @override
  String get exportDataTitle => '导出数据';

  @override
  String get account => '账户';

  @override
  String get chooseExportFormat => '选择导出格式：';

  @override
  String get noDataToExport => '没有可导出的数据';

  @override
  String get exportFailed => '导出失败';

  @override
  String exportError(String error) {
    return '导出错误：$error';
  }

  @override
  String get importDataTitle => '导入数据';

  @override
  String get importDataMessage =>
      '导入数据将为您的账户添加新设备。支持的格式：CSV、XLSX。\n\n注意：只会读取前100行数据。如果您的文件有更多行，请分批导入。';

  @override
  String get import => '导入';

  @override
  String get pleaseSelectCsvOrXlsx => '请选择CSV或XLSX文件';

  @override
  String get importComplete => '导入完成';

  @override
  String get importFailed => '导入失败';

  @override
  String get errorDetails => '错误详情：';

  @override
  String importError(String error) {
    return '导入错误：$error';
  }

  @override
  String get logoutTitle => '退出登录';

  @override
  String get areYouSureLogout => '您确定要退出登录吗？';

  @override
  String get deleteAccountTitle => '删除账户';

  @override
  String get deleteAccountMessage => '删除后，您的账户以及所有设备和愿望清单数据将被永久删除且无法恢复。';

  @override
  String get yourAccount => '您的账户：';

  @override
  String get typeEmailToConfirm => '输入您的邮箱以确认';

  @override
  String get pleaseLoginFirst => '请先登录';

  @override
  String get pleaseLogInFirst => '请先登录';

  @override
  String failedToSignOut(String error) {
    return '退出登录失败：$error';
  }

  @override
  String failedToDeleteAccount(String error) {
    return '删除账户失败：$error';
  }

  @override
  String get couldNotOpenPrivacyPolicy => '无法打开隐私政策';
}
