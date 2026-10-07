// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Chinese (`zh`).
class AppLocalizationsZh extends AppLocalizations {
  AppLocalizationsZh([String locale = 'zh']) : super(locale);

  @override
  String get appName => '桌面宠物';

  @override
  String get cancel => '取消';

  @override
  String get dismiss => '关闭';

  @override
  String get delete => '删除';

  @override
  String get retry => '重试';

  @override
  String get save => '保存';

  @override
  String get restoreDefault => '恢复默认';

  @override
  String get disable => '禁用';

  @override
  String get settings => '设置';

  @override
  String get addPet => '添加桌宠';

  @override
  String get petAdded => '桌宠添加成功';

  @override
  String get sectionAppearance => '外观';

  @override
  String get sectionPetPack => '宠物包';

  @override
  String get sectionShortcut => '快捷键';

  @override
  String get sectionQuickLaunch => '快捷启动应用';

  @override
  String get sectionAbout => '关于';

  @override
  String get sectionLanguage => '语言';

  @override
  String get globalOpacityLabel => '全局透明度';

  @override
  String get globalScaleLabel => '全局缩放';

  @override
  String scaleLimitExceeded(String limit) {
    return '全局缩放不能超过 ${limit}x';
  }

  @override
  String get petPackDirDefaultPath => '宠物包目录 (默认路径)';

  @override
  String get petPackDir => '宠物包目录';

  @override
  String get petPackBuiltInValue => 'assets/default_pet_pack（内置）';

  @override
  String get viewAvailablePetPacks => '查看可用宠物包';

  @override
  String get browseDirectory => '浏览目录';

  @override
  String get defaultPetPackName => '默认宠物包';

  @override
  String get quickLaunchTitle => '快捷启动';

  @override
  String get setShortcut => '设置快捷键';

  @override
  String get noShortcuts => '暂无快捷启动应用';

  @override
  String get addShortcut => '添加快捷启动';

  @override
  String get language => '语言';

  @override
  String get languageSystem => '跟随系统';

  @override
  String get languageEnglish => 'English';

  @override
  String get languageChinese => '简体中文';

  @override
  String versionLine(String platform) {
    return 'v1.0.0 — $platform';
  }

  @override
  String myPets(int count) {
    return '我的桌宠 ($count)';
  }

  @override
  String get noPets => '还没有添加桌宠';

  @override
  String get noPetsHint => '点击右上角 + 按钮添加';

  @override
  String petPackLabel(String petPack) {
    return '宠物包: $petPack';
  }

  @override
  String get locked => '已锁定';

  @override
  String get unlocked => '已解锁';

  @override
  String get shown => '已显示';

  @override
  String get hidden => '已隐藏';

  @override
  String get deletePetTitle => '删除桌宠';

  @override
  String deletePetBody(String name, String scale, int opacity) {
    return '确定要删除「$name」吗？\n\n缩放: ${scale}x\n透明度: $opacity%';
  }

  @override
  String get keepOnePet => '至少需要保留一个桌宠';

  @override
  String get editPet => '修改桌宠';

  @override
  String get unsavedChanges => '有未保存的修改';

  @override
  String get discardChanges => '放弃修改';

  @override
  String get preview => '预览';

  @override
  String get name => '名称';

  @override
  String get nameHint => '输入桌宠名称';

  @override
  String get scaleMultiplier => '缩放乘数';

  @override
  String get opacityMultiplier => '透明度乘数';

  @override
  String get l2dParamsSection => '参数';

  @override
  String get mouseFollowSection => '鼠标跟随';

  @override
  String get mouseFollowX => '左右跟随';

  @override
  String get mouseFollowY => '上下跟随';

  @override
  String get mouseFollowParamsSection => '跟随参数';

  @override
  String get mouseFollowNone => '不跟随';

  @override
  String get mouseFollowAxisX => 'X';

  @override
  String get mouseFollowAxisY => 'Y';

  @override
  String get mouseFollowAxisXY => 'XY';

  @override
  String get petPack => '宠物包';

  @override
  String get useGlobalPetPack => '使用全局设置中的宠物包';

  @override
  String get importZipPetPack => '导入 ZIP 宠物包';

  @override
  String get choosePetPack => '选择宠物包';

  @override
  String get finalScaleFormula => '× 全局缩放 = 最终缩放';

  @override
  String get finalOpacityFormula => '× 全局透明度 = 最终透明度';

  @override
  String get importingPetPack => '正在导入宠物包...';

  @override
  String get petPackImportSuccess => '宠物包导入成功';

  @override
  String get petPackImportFailed => '宠物包导入失败';

  @override
  String get scaleTooHigh => '缩放乘数过高';

  @override
  String get scaleTooHighHint => '请降低乘数或全局缩放';

  @override
  String deletePetConfirm(String name) {
    return '确定要删除「$name」吗？此操作不可恢复。';
  }

  @override
  String get choosePetPackTitle => '选择宠物包';

  @override
  String get loadPetPacksFailed => '加载宠物包列表失败';

  @override
  String get noPetPacksFound => '未找到宠物包';

  @override
  String get noPetPacksFoundHint => '该目录下没有包含 pet.json 的有效宠物包';

  @override
  String get loadingPetPacks => '正在读取宠物包';

  @override
  String get petPackSourceImported => '来源: 已导入的宠物包';

  @override
  String petPackSourceDir(String path) {
    return '目录: $path';
  }

  @override
  String get petPackTypeSprite => '精灵图';

  @override
  String get petPackTypeLive2d => 'Live2D';

  @override
  String get builtIn => '内置';

  @override
  String get addShortcutTitle => '添加快捷启动';

  @override
  String get editShortcutTitle => '编辑快捷启动';

  @override
  String get nameLabel => '名称';

  @override
  String get nameHintShortcut => '如：记事本';

  @override
  String get pathLabel => '可执行文件路径';

  @override
  String get pathHint => '如：C:\\Windows\\notepad.exe';

  @override
  String get browseFile => '浏览文件';

  @override
  String get requiredField => '此项必填';

  @override
  String get hotkeyTitle => '设置快捷键';

  @override
  String get hotkeyPlaceholder => '（点击下方按钮选择）';

  @override
  String get modifiersLabel => '修饰键（可多选）';

  @override
  String get keyLabel => '按键';

  @override
  String get trayLock => '锁定';

  @override
  String get trayUnlock => '解锁';

  @override
  String get traySettings => '设置';

  @override
  String get trayQuit => '退出';

  @override
  String get trayTooltip => '桌面宠物';

  @override
  String get defaultPetName => '默认桌宠';

  @override
  String petPackError(String message) {
    return '错误：$message';
  }
}
