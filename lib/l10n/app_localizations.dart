import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
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

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
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
    Locale('zh'),
  ];

  /// No description provided for @appName.
  ///
  /// In en, this message translates to:
  /// **'Desktop Pet'**
  String get appName;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @dismiss.
  ///
  /// In en, this message translates to:
  /// **'Dismiss'**
  String get dismiss;

  /// No description provided for @delete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get delete;

  /// No description provided for @retry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get retry;

  /// No description provided for @save.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

  /// No description provided for @restoreDefault.
  ///
  /// In en, this message translates to:
  /// **'Restore default'**
  String get restoreDefault;

  /// No description provided for @disable.
  ///
  /// In en, this message translates to:
  /// **'Disable'**
  String get disable;

  /// No description provided for @settings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settings;

  /// No description provided for @addPet.
  ///
  /// In en, this message translates to:
  /// **'Add pet'**
  String get addPet;

  /// No description provided for @petAdded.
  ///
  /// In en, this message translates to:
  /// **'Pet added'**
  String get petAdded;

  /// No description provided for @sectionAppearance.
  ///
  /// In en, this message translates to:
  /// **'Appearance'**
  String get sectionAppearance;

  /// No description provided for @sectionPetPack.
  ///
  /// In en, this message translates to:
  /// **'Pet packs'**
  String get sectionPetPack;

  /// No description provided for @sectionShortcut.
  ///
  /// In en, this message translates to:
  /// **'Shortcut'**
  String get sectionShortcut;

  /// No description provided for @sectionQuickLaunch.
  ///
  /// In en, this message translates to:
  /// **'Launch shortcuts'**
  String get sectionQuickLaunch;

  /// No description provided for @sectionAbout.
  ///
  /// In en, this message translates to:
  /// **'About'**
  String get sectionAbout;

  /// No description provided for @sectionLanguage.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get sectionLanguage;

  /// No description provided for @globalOpacityLabel.
  ///
  /// In en, this message translates to:
  /// **'Global opacity'**
  String get globalOpacityLabel;

  /// No description provided for @globalScaleLabel.
  ///
  /// In en, this message translates to:
  /// **'Global scale'**
  String get globalScaleLabel;

  /// No description provided for @scaleLimitExceeded.
  ///
  /// In en, this message translates to:
  /// **'Global scale cannot exceed {limit}x'**
  String scaleLimitExceeded(String limit);

  /// No description provided for @petPackDirDefaultPath.
  ///
  /// In en, this message translates to:
  /// **'Pet pack directory (default)'**
  String get petPackDirDefaultPath;

  /// No description provided for @petPackDir.
  ///
  /// In en, this message translates to:
  /// **'Pet pack directory'**
  String get petPackDir;

  /// No description provided for @petPackBuiltInValue.
  ///
  /// In en, this message translates to:
  /// **'assets/default_pet_pack (built-in)'**
  String get petPackBuiltInValue;

  /// No description provided for @viewAvailablePetPacks.
  ///
  /// In en, this message translates to:
  /// **'View available pet packs'**
  String get viewAvailablePetPacks;

  /// No description provided for @browseDirectory.
  ///
  /// In en, this message translates to:
  /// **'Browse directory'**
  String get browseDirectory;

  /// No description provided for @defaultPetPackName.
  ///
  /// In en, this message translates to:
  /// **'Default pet pack'**
  String get defaultPetPackName;

  /// No description provided for @quickLaunchTitle.
  ///
  /// In en, this message translates to:
  /// **'Quick launch'**
  String get quickLaunchTitle;

  /// No description provided for @setShortcut.
  ///
  /// In en, this message translates to:
  /// **'Set shortcut'**
  String get setShortcut;

  /// No description provided for @noShortcuts.
  ///
  /// In en, this message translates to:
  /// **'No launch shortcuts yet'**
  String get noShortcuts;

  /// No description provided for @addShortcut.
  ///
  /// In en, this message translates to:
  /// **'Add launch shortcut'**
  String get addShortcut;

  /// No description provided for @language.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get language;

  /// No description provided for @languageSystem.
  ///
  /// In en, this message translates to:
  /// **'Follow system'**
  String get languageSystem;

  /// No description provided for @languageEnglish.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get languageEnglish;

  /// No description provided for @languageChinese.
  ///
  /// In en, this message translates to:
  /// **'简体中文'**
  String get languageChinese;

  /// No description provided for @versionLine.
  ///
  /// In en, this message translates to:
  /// **'v1.0.0 — {platform}'**
  String versionLine(String platform);

  /// No description provided for @myPets.
  ///
  /// In en, this message translates to:
  /// **'My pets ({count})'**
  String myPets(int count);

  /// No description provided for @noPets.
  ///
  /// In en, this message translates to:
  /// **'No pets yet'**
  String get noPets;

  /// No description provided for @noPetsHint.
  ///
  /// In en, this message translates to:
  /// **'Tap the + button at the top right to add one'**
  String get noPetsHint;

  /// No description provided for @petPackLabel.
  ///
  /// In en, this message translates to:
  /// **'Pet pack: {petPack}'**
  String petPackLabel(String petPack);

  /// No description provided for @locked.
  ///
  /// In en, this message translates to:
  /// **'Locked'**
  String get locked;

  /// No description provided for @unlocked.
  ///
  /// In en, this message translates to:
  /// **'Unlocked'**
  String get unlocked;

  /// No description provided for @shown.
  ///
  /// In en, this message translates to:
  /// **'Visible'**
  String get shown;

  /// No description provided for @hidden.
  ///
  /// In en, this message translates to:
  /// **'Hidden'**
  String get hidden;

  /// No description provided for @deletePetTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete pet'**
  String get deletePetTitle;

  /// No description provided for @deletePetBody.
  ///
  /// In en, this message translates to:
  /// **'Delete \"{name}\"?\n\nScale: {scale}x\nOpacity: {opacity}%'**
  String deletePetBody(String name, String scale, int opacity);

  /// No description provided for @keepOnePet.
  ///
  /// In en, this message translates to:
  /// **'Keep at least one pet'**
  String get keepOnePet;

  /// No description provided for @editPet.
  ///
  /// In en, this message translates to:
  /// **'Edit pet'**
  String get editPet;

  /// No description provided for @unsavedChanges.
  ///
  /// In en, this message translates to:
  /// **'You have unsaved changes'**
  String get unsavedChanges;

  /// No description provided for @discardChanges.
  ///
  /// In en, this message translates to:
  /// **'Discard changes'**
  String get discardChanges;

  /// No description provided for @preview.
  ///
  /// In en, this message translates to:
  /// **'Preview'**
  String get preview;

  /// No description provided for @name.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get name;

  /// No description provided for @nameHint.
  ///
  /// In en, this message translates to:
  /// **'Enter pet name'**
  String get nameHint;

  /// No description provided for @scaleMultiplier.
  ///
  /// In en, this message translates to:
  /// **'Scale multiplier'**
  String get scaleMultiplier;

  /// No description provided for @opacityMultiplier.
  ///
  /// In en, this message translates to:
  /// **'Opacity multiplier'**
  String get opacityMultiplier;

  /// No description provided for @l2dParamsSection.
  ///
  /// In en, this message translates to:
  /// **'Parameters'**
  String get l2dParamsSection;

  /// No description provided for @mouseFollowSection.
  ///
  /// In en, this message translates to:
  /// **'Mouse follow'**
  String get mouseFollowSection;

  /// No description provided for @mouseFollowX.
  ///
  /// In en, this message translates to:
  /// **'Horizontally'**
  String get mouseFollowX;

  /// No description provided for @mouseFollowY.
  ///
  /// In en, this message translates to:
  /// **'Vertically'**
  String get mouseFollowY;

  /// No description provided for @mouseFollowParamsSection.
  ///
  /// In en, this message translates to:
  /// **'Cursor-follow parameters'**
  String get mouseFollowParamsSection;

  /// No description provided for @mouseFollowNone.
  ///
  /// In en, this message translates to:
  /// **'Don\'t follow'**
  String get mouseFollowNone;

  /// No description provided for @mouseFollowAxisX.
  ///
  /// In en, this message translates to:
  /// **'X'**
  String get mouseFollowAxisX;

  /// No description provided for @mouseFollowAxisY.
  ///
  /// In en, this message translates to:
  /// **'Y'**
  String get mouseFollowAxisY;

  /// No description provided for @mouseFollowAxisXY.
  ///
  /// In en, this message translates to:
  /// **'XY'**
  String get mouseFollowAxisXY;

  /// No description provided for @petPack.
  ///
  /// In en, this message translates to:
  /// **'Pet pack'**
  String get petPack;

  /// No description provided for @useGlobalPetPack.
  ///
  /// In en, this message translates to:
  /// **'Use pet pack from global settings'**
  String get useGlobalPetPack;

  /// No description provided for @importZipPetPack.
  ///
  /// In en, this message translates to:
  /// **'Import ZIP pet pack'**
  String get importZipPetPack;

  /// No description provided for @choosePetPack.
  ///
  /// In en, this message translates to:
  /// **'Choose pet pack'**
  String get choosePetPack;

  /// No description provided for @finalScaleFormula.
  ///
  /// In en, this message translates to:
  /// **'× global scale = final scale'**
  String get finalScaleFormula;

  /// No description provided for @finalOpacityFormula.
  ///
  /// In en, this message translates to:
  /// **'× global opacity = final opacity'**
  String get finalOpacityFormula;

  /// No description provided for @importingPetPack.
  ///
  /// In en, this message translates to:
  /// **'Importing pet pack...'**
  String get importingPetPack;

  /// No description provided for @petPackImportSuccess.
  ///
  /// In en, this message translates to:
  /// **'Pet pack imported'**
  String get petPackImportSuccess;

  /// No description provided for @petPackImportFailed.
  ///
  /// In en, this message translates to:
  /// **'Pet pack import failed'**
  String get petPackImportFailed;

  /// No description provided for @scaleTooHigh.
  ///
  /// In en, this message translates to:
  /// **'Scale multiplier too high'**
  String get scaleTooHigh;

  /// No description provided for @scaleTooHighHint.
  ///
  /// In en, this message translates to:
  /// **'Lower the multiplier or the global scale'**
  String get scaleTooHighHint;

  /// No description provided for @deletePetConfirm.
  ///
  /// In en, this message translates to:
  /// **'Delete \"{name}\"? This cannot be undone.'**
  String deletePetConfirm(String name);

  /// No description provided for @choosePetPackTitle.
  ///
  /// In en, this message translates to:
  /// **'Choose pet pack'**
  String get choosePetPackTitle;

  /// No description provided for @loadPetPacksFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to load pet packs'**
  String get loadPetPacksFailed;

  /// No description provided for @noPetPacksFound.
  ///
  /// In en, this message translates to:
  /// **'No pet packs found'**
  String get noPetPacksFound;

  /// No description provided for @noPetPacksFoundHint.
  ///
  /// In en, this message translates to:
  /// **'No valid pet pack (with pet.json) in this directory'**
  String get noPetPacksFoundHint;

  /// No description provided for @loadingPetPacks.
  ///
  /// In en, this message translates to:
  /// **'Reading pet packs'**
  String get loadingPetPacks;

  /// No description provided for @petPackSourceImported.
  ///
  /// In en, this message translates to:
  /// **'Source: imported pet pack'**
  String get petPackSourceImported;

  /// No description provided for @petPackSourceDir.
  ///
  /// In en, this message translates to:
  /// **'Directory: {path}'**
  String petPackSourceDir(String path);

  /// No description provided for @petPackTypeSprite.
  ///
  /// In en, this message translates to:
  /// **'Sprite'**
  String get petPackTypeSprite;

  /// No description provided for @petPackTypeLive2d.
  ///
  /// In en, this message translates to:
  /// **'Live2D'**
  String get petPackTypeLive2d;

  /// No description provided for @builtIn.
  ///
  /// In en, this message translates to:
  /// **'Built-in'**
  String get builtIn;

  /// No description provided for @addShortcutTitle.
  ///
  /// In en, this message translates to:
  /// **'Add launch shortcut'**
  String get addShortcutTitle;

  /// No description provided for @editShortcutTitle.
  ///
  /// In en, this message translates to:
  /// **'Edit launch shortcut'**
  String get editShortcutTitle;

  /// No description provided for @nameLabel.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get nameLabel;

  /// No description provided for @nameHintShortcut.
  ///
  /// In en, this message translates to:
  /// **'e.g. Notepad'**
  String get nameHintShortcut;

  /// No description provided for @pathLabel.
  ///
  /// In en, this message translates to:
  /// **'Executable path'**
  String get pathLabel;

  /// No description provided for @pathHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. C:\\Windows\\notepad.exe'**
  String get pathHint;

  /// No description provided for @browseFile.
  ///
  /// In en, this message translates to:
  /// **'Browse file'**
  String get browseFile;

  /// No description provided for @requiredField.
  ///
  /// In en, this message translates to:
  /// **'Required'**
  String get requiredField;

  /// No description provided for @hotkeyTitle.
  ///
  /// In en, this message translates to:
  /// **'Set shortcut'**
  String get hotkeyTitle;

  /// No description provided for @hotkeyPlaceholder.
  ///
  /// In en, this message translates to:
  /// **'(tap a button below to choose)'**
  String get hotkeyPlaceholder;

  /// No description provided for @modifiersLabel.
  ///
  /// In en, this message translates to:
  /// **'Modifiers (multi-select)'**
  String get modifiersLabel;

  /// No description provided for @keyLabel.
  ///
  /// In en, this message translates to:
  /// **'Key'**
  String get keyLabel;

  /// No description provided for @trayLock.
  ///
  /// In en, this message translates to:
  /// **'Lock'**
  String get trayLock;

  /// No description provided for @trayUnlock.
  ///
  /// In en, this message translates to:
  /// **'Unlock'**
  String get trayUnlock;

  /// No description provided for @traySettings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get traySettings;

  /// No description provided for @trayQuit.
  ///
  /// In en, this message translates to:
  /// **'Quit'**
  String get trayQuit;

  /// No description provided for @trayTooltip.
  ///
  /// In en, this message translates to:
  /// **'Desktop Pet'**
  String get trayTooltip;

  /// No description provided for @defaultPetName.
  ///
  /// In en, this message translates to:
  /// **'My Pet'**
  String get defaultPetName;

  /// No description provided for @petPackError.
  ///
  /// In en, this message translates to:
  /// **'error: {message}'**
  String petPackError(String message);
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
      <String>['en', 'zh'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
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
