// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appName => 'Desktop Pet';

  @override
  String get cancel => 'Cancel';

  @override
  String get confirm => 'OK';

  @override
  String get delete => 'Delete';

  @override
  String get retry => 'Retry';

  @override
  String get save => 'Save';

  @override
  String get restoreDefault => 'Restore default';

  @override
  String get disable => 'Disable';

  @override
  String get settings => 'Settings';

  @override
  String get addPet => 'Add pet';

  @override
  String get petAdded => 'Pet added';

  @override
  String get sectionAppearance => 'Appearance';

  @override
  String get sectionSkin => 'Skin';

  @override
  String get sectionShortcut => 'Shortcut';

  @override
  String get sectionQuickLaunch => 'Launch shortcuts';

  @override
  String get sectionAbout => 'About';

  @override
  String get sectionLanguage => 'Language';

  @override
  String globalOpacity(int percent) {
    return 'Global opacity — $percent%';
  }

  @override
  String globalScale(String scale) {
    return 'Global scale — ${scale}x';
  }

  @override
  String globalSpeed(String speed) {
    return 'Global speed — ${speed}x';
  }

  @override
  String scaleLimitExceeded(String limit) {
    return 'Global scale cannot exceed ${limit}x';
  }

  @override
  String get skinDirDefaultPath => 'Skin directory (default)';

  @override
  String get skinDir => 'Skin directory';

  @override
  String get skinBuiltInValue => 'assets/default_skin (built-in)';

  @override
  String get viewAvailableSkins => 'View available skins';

  @override
  String get browseDirectory => 'Browse directory';

  @override
  String get skinMigrated => 'Imported skin packages migrated';

  @override
  String skinMigrateFailed(String error) {
    return 'Failed to migrate skin packages';
  }

  @override
  String get defaultSkinName => 'Default skin';

  @override
  String get quickLaunchTitle => 'Quick launch';

  @override
  String get setShortcut => 'Set shortcut';

  @override
  String get noShortcuts => 'No launch shortcuts yet';

  @override
  String get addShortcut => 'Add launch shortcut';

  @override
  String get language => 'Language';

  @override
  String get languageSystem => 'Follow system';

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
    return 'My pets ($count)';
  }

  @override
  String get noPets => 'No pets yet';

  @override
  String get noPetsHint => 'Tap the + button at the top right to add one';

  @override
  String skinLabel(String skin) {
    return 'Skin: $skin';
  }

  @override
  String get locked => 'Locked';

  @override
  String get unlocked => 'Unlocked';

  @override
  String get shown => 'Visible';

  @override
  String get hidden => 'Hidden';

  @override
  String get deletePetTitle => 'Delete pet';

  @override
  String deletePetBody(String name, int scale, int opacity) {
    return 'Delete \"$name\"?\n\nScale: $scale%\nOpacity: $opacity%';
  }

  @override
  String get keepOnePet => 'Keep at least one pet';

  @override
  String get editPet => 'Edit pet';

  @override
  String get preview => 'Preview';

  @override
  String get name => 'Name';

  @override
  String get nameHint => 'Enter pet name';

  @override
  String get scaleMultiplier => 'Scale multiplier';

  @override
  String get opacityMultiplier => 'Opacity multiplier';

  @override
  String get speedMultiplier => 'Speed multiplier';

  @override
  String get skin => 'Skin';

  @override
  String get useGlobalSkin => 'Use skin from global settings';

  @override
  String get importZipSkin => 'Import ZIP skin';

  @override
  String get chooseSkin => 'Choose skin';

  @override
  String get finalSpeedFormula => '× global speed = final speed';

  @override
  String get finalScaleFormula => '× global scale = final scale';

  @override
  String get finalOpacityFormula => '× global opacity = final opacity';

  @override
  String get importingSkin => 'Importing skin package...';

  @override
  String get skinImportSuccess => 'Skin imported';

  @override
  String get skinImportFailed => 'Skin import failed';

  @override
  String get scaleTooHigh => 'Scale multiplier too high';

  @override
  String get scaleTooHighHint => 'Lower the multiplier or the global scale';

  @override
  String deletePetConfirm(String name) {
    return 'Delete \"$name\"? This cannot be undone.';
  }

  @override
  String get chooseSkinTitle => 'Choose skin';

  @override
  String get loadSkinsFailed => 'Failed to load skins';

  @override
  String get noSkinsFound => 'No skin packages found';

  @override
  String get noSkinsFoundHint =>
      'No valid skin package (with skin.json) in this directory';

  @override
  String get skinSourceImported => 'Source: imported skin package';

  @override
  String skinSourceDir(String path) {
    return 'Directory: $path';
  }

  @override
  String get builtIn => 'Built-in';

  @override
  String get addShortcutTitle => 'Add launch shortcut';

  @override
  String get editShortcutTitle => 'Edit launch shortcut';

  @override
  String get nameLabel => 'Name';

  @override
  String get nameHintShortcut => 'e.g. Notepad';

  @override
  String get pathLabel => 'Executable path';

  @override
  String get pathHint => 'e.g. C:\\Windows\\notepad.exe';

  @override
  String get browseFile => 'Browse file';

  @override
  String get hotkeyTitle => 'Set shortcut';

  @override
  String get hotkeyPlaceholder => '(tap a button below to choose)';

  @override
  String get modifiersLabel => 'Modifiers (multi-select)';

  @override
  String get keyLabel => 'Key';

  @override
  String get trayLock => 'Lock';

  @override
  String get trayUnlock => 'Unlock';

  @override
  String get traySettings => 'Settings';

  @override
  String get trayQuit => 'Quit';

  @override
  String get trayTooltip => 'Desktop Pet';

  @override
  String get defaultPetName => 'My Pet';

  @override
  String skinError(String message) {
    return 'error: $message';
  }
}
