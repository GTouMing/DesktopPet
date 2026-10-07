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
  String get dismiss => 'Dismiss';

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
  String get sectionPetPack => 'Pet packs';

  @override
  String get sectionShortcut => 'Shortcut';

  @override
  String get sectionQuickLaunch => 'Launch shortcuts';

  @override
  String get sectionAbout => 'About';

  @override
  String get sectionLanguage => 'Language';

  @override
  String get globalOpacityLabel => 'Global opacity';

  @override
  String get globalScaleLabel => 'Global scale';

  @override
  String scaleLimitExceeded(String limit) {
    return 'Global scale cannot exceed ${limit}x';
  }

  @override
  String get petPackDirDefaultPath => 'Pet pack directory (default)';

  @override
  String get petPackDir => 'Pet pack directory';

  @override
  String get petPackBuiltInValue => 'assets/default_pet_pack (built-in)';

  @override
  String get viewAvailablePetPacks => 'View available pet packs';

  @override
  String get browseDirectory => 'Browse directory';

  @override
  String get defaultPetPackName => 'Default pet pack';

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
  String petPackLabel(String petPack) {
    return 'Pet pack: $petPack';
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
  String deletePetBody(String name, String scale, int opacity) {
    return 'Delete \"$name\"?\n\nScale: ${scale}x\nOpacity: $opacity%';
  }

  @override
  String get keepOnePet => 'Keep at least one pet';

  @override
  String get editPet => 'Edit pet';

  @override
  String get unsavedChanges => 'You have unsaved changes';

  @override
  String get discardChanges => 'Discard changes';

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
  String get l2dParamsSection => 'Parameters';

  @override
  String get mouseFollowSection => 'Mouse follow';

  @override
  String get mouseFollowX => 'Horizontally';

  @override
  String get mouseFollowY => 'Vertically';

  @override
  String get mouseFollowParamsSection => 'Cursor-follow parameters';

  @override
  String get mouseFollowNone => 'Don\'t follow';

  @override
  String get mouseFollowAxisX => 'X';

  @override
  String get mouseFollowAxisY => 'Y';

  @override
  String get mouseFollowAxisXY => 'XY';

  @override
  String get petPack => 'Pet pack';

  @override
  String get useGlobalPetPack => 'Use pet pack from global settings';

  @override
  String get importZipPetPack => 'Import ZIP pet pack';

  @override
  String get choosePetPack => 'Choose pet pack';

  @override
  String get finalScaleFormula => '× global scale = final scale';

  @override
  String get finalOpacityFormula => '× global opacity = final opacity';

  @override
  String get importingPetPack => 'Importing pet pack...';

  @override
  String get petPackImportSuccess => 'Pet pack imported';

  @override
  String get petPackImportFailed => 'Pet pack import failed';

  @override
  String get scaleTooHigh => 'Scale multiplier too high';

  @override
  String get scaleTooHighHint => 'Lower the multiplier or the global scale';

  @override
  String deletePetConfirm(String name) {
    return 'Delete \"$name\"? This cannot be undone.';
  }

  @override
  String get choosePetPackTitle => 'Choose pet pack';

  @override
  String get loadPetPacksFailed => 'Failed to load pet packs';

  @override
  String get noPetPacksFound => 'No pet packs found';

  @override
  String get noPetPacksFoundHint =>
      'No valid pet pack (with pet.json) in this directory';

  @override
  String get loadingPetPacks => 'Reading pet packs';

  @override
  String get petPackSourceImported => 'Source: imported pet pack';

  @override
  String petPackSourceDir(String path) {
    return 'Directory: $path';
  }

  @override
  String get petPackTypeSprite => 'Sprite';

  @override
  String get petPackTypeLive2d => 'Live2D';

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
  String get requiredField => 'Required';

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
  String petPackError(String message) {
    return 'error: $message';
  }
}
