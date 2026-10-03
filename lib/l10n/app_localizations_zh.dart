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
  String get confirm => '确定';

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
  String get sectionSkin => '皮肤';

  @override
  String get sectionShortcut => '快捷键';

  @override
  String get sectionQuickLaunch => '快捷启动应用';

  @override
  String get sectionAbout => '关于';

  @override
  String get sectionLanguage => '语言';

  @override
  String globalOpacity(int percent) {
    return '全局透明度 — $percent%';
  }

  @override
  String globalScale(String scale) {
    return '全局缩放 — ${scale}x';
  }

  @override
  String globalSpeed(String speed) {
    return '全局速度 — ${speed}x';
  }

  @override
  String scaleLimitExceeded(String limit) {
    return '全局缩放不能超过 ${limit}x';
  }

  @override
  String get skinDirDefaultPath => '皮肤目录 (默认路径)';

  @override
  String get skinDir => '皮肤目录';

  @override
  String get skinBuiltInValue => 'assets/default_skin（内置）';

  @override
  String get viewAvailableSkins => '查看可用皮肤';

  @override
  String get browseDirectory => '浏览目录';

  @override
  String get skinMigrated => '已迁移已导入的皮肤包';

  @override
  String skinMigrateFailed(String error) {
    return '迁移皮肤包失败';
  }

  @override
  String get defaultSkinName => '默认皮肤';

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
  String skinLabel(String skin) {
    return '皮肤: $skin';
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
  String deletePetBody(String name, int scale, int opacity) {
    return '确定要删除「$name」吗？\n\n缩放: $scale%\n透明度: $opacity%';
  }

  @override
  String get keepOnePet => '至少需要保留一个桌宠';

  @override
  String get editPet => '修改桌宠';

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
  String get speedMultiplier => '速度乘数';

  @override
  String get skin => '皮肤';

  @override
  String get useGlobalSkin => '使用全局设置中的皮肤';

  @override
  String get importZipSkin => '导入 ZIP 皮肤包';

  @override
  String get chooseSkin => '选择皮肤';

  @override
  String get finalSpeedFormula => '× 全局速度 = 最终速度';

  @override
  String get finalScaleFormula => '× 全局缩放 = 最终缩放';

  @override
  String get finalOpacityFormula => '× 全局透明度 = 最终透明度';

  @override
  String get importingSkin => '正在导入皮肤包...';

  @override
  String get skinImportSuccess => '皮肤导入成功';

  @override
  String get skinImportFailed => '皮肤导入失败';

  @override
  String get scaleTooHigh => '缩放乘数过高';

  @override
  String get scaleTooHighHint => '请降低乘数或全局缩放';

  @override
  String deletePetConfirm(String name) {
    return '确定要删除「$name」吗？此操作不可恢复。';
  }

  @override
  String get chooseSkinTitle => '选择皮肤';

  @override
  String get loadSkinsFailed => '加载皮肤列表失败';

  @override
  String get noSkinsFound => '未找到皮肤包';

  @override
  String get noSkinsFoundHint => '该目录下没有包含 skin.json 的有效皮肤包';

  @override
  String get skinSourceImported => '来源: 已导入的皮肤包';

  @override
  String skinSourceDir(String path) {
    return '目录: $path';
  }

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
  String skinError(String message) {
    return '错误：$message';
  }
}
