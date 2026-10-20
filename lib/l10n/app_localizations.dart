import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of L10n
/// returned by `L10n.of(context)`.
///
/// Applications need to include `L10n.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: L10n.localizationsDelegates,
///   supportedLocales: L10n.supportedLocales,
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
/// be consistent with the languages listed in the L10n.supportedLocales
/// property.
abstract class L10n {
  L10n(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static L10n of(BuildContext context) {
    return Localizations.of<L10n>(context, L10n)!;
  }

  static const LocalizationsDelegate<L10n> delegate = _L10nDelegate();

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
  static const List<Locale> supportedLocales = <Locale>[Locale('en')];

  /// The app's name.
  ///
  /// In en, this message translates to:
  /// **'Utopia'**
  String get appTitle;

  /// features/settings/presentation/settings_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settingsSettings;

  /// features/settings/presentation/settings_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Sound'**
  String get settingsSound;

  /// features/settings/presentation/settings_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Music'**
  String get settingsMusic;

  /// features/settings/presentation/settings_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Sound effects'**
  String get settingsSoundEffects;

  /// features/settings/presentation/settings_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Music world hears the room'**
  String get settingsMusicWorldHearsTheRoom;

  /// features/settings/presentation/settings_screen.dart
  ///
  /// In en, this message translates to:
  /// **'The show dances to the sound around you. Nothing is recorded.'**
  String get settingsTheShowDancesToThe;

  /// features/settings/presentation/settings_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Screen'**
  String get settingsScreen;

  /// features/settings/presentation/settings_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Install Utopia'**
  String get settingsInstallUtopia;

  /// features/settings/presentation/settings_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Play full screen from your home screen'**
  String get settingsPlayFullScreenFromYour;

  /// features/settings/presentation/settings_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Play'**
  String get settingsPlay;

  /// features/settings/presentation/settings_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Vibration'**
  String get settingsVibration;

  /// features/settings/presentation/settings_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Dice, captures, your turn'**
  String get settingsDiceCapturesYourTurn;

  /// features/settings/presentation/settings_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Timer ticks'**
  String get settingsTimerTicks;

  /// features/settings/presentation/settings_screen.dart
  ///
  /// In en, this message translates to:
  /// **'A soft tick when your time is nearly up'**
  String get settingsASoftTickWhenYour;

  /// features/settings/presentation/settings_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Play voice notes'**
  String get settingsPlayVoiceNotes;

  /// features/settings/presentation/settings_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Hear other players\' voice notes as they arrive'**
  String get settingsHearOtherPlayersVoiceNotes;

  /// features/settings/presentation/settings_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Game reminders'**
  String get settingsGameReminders;

  /// features/settings/presentation/settings_screen.dart
  ///
  /// In en, this message translates to:
  /// **'A nudge to come play when you have been away'**
  String get settingsANudgeToComePlay;

  /// features/settings/presentation/settings_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Show the music I\'m playing'**
  String get settingsShowTheMusicIM;

  /// features/settings/presentation/settings_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Chip vibes along with what\'s on. Titles go to Chip\'s AI to read the vibe'**
  String get settingsChipVibesAlongWithWhat;

  /// features/settings/presentation/settings_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Floating Chip'**
  String get settingsFloatingChip;

  /// features/settings/presentation/settings_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Chip floats over every screen. Tap him to chat'**
  String get settingsChipFloatsOverEveryScreen;

  /// features/settings/presentation/settings_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Let Chip see your music'**
  String get settingsLetChipSeeYourMusic;

  /// features/settings/presentation/settings_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Turn on notification access for Utopia'**
  String get settingsTurnOnNotificationAccessFor;

  /// features/settings/presentation/settings_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Allow Apple Music so Chip can show the song'**
  String get settingsAllowAppleMusicSoChip;

  /// features/settings/presentation/settings_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Chess move hints'**
  String get settingsChessMoveHints;

  /// features/settings/presentation/settings_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Show where a piece can go'**
  String get settingsShowWhereAPieceCan;

  /// features/settings/presentation/settings_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Utopia'**
  String get settingsUtopia;

  /// features/settings/presentation/settings_screen.dart
  ///
  /// In en, this message translates to:
  /// **'World'**
  String get settingsWorld;

  /// features/settings/presentation/settings_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Get coins'**
  String get settingsGetCoins;

  /// features/settings/presentation/settings_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Chip Maestro'**
  String get settingsChipMaestro;

  /// features/settings/presentation/settings_screen.dart
  ///
  /// In en, this message translates to:
  /// **'You\'re a member'**
  String get settingsYouReAMember;

  /// features/settings/presentation/settings_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Real portraits and more from Chip'**
  String get settingsRealPortraitsAndMoreFrom;

  /// features/settings/presentation/settings_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Restore purchases'**
  String get settingsRestorePurchases;

  /// features/settings/presentation/settings_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Got Chip Maestro on another phone? Get it here'**
  String get settingsGotChipMaestroOnAnother;

  /// features/settings/presentation/settings_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Account'**
  String get settingsAccount;

  /// features/settings/presentation/settings_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get settingsProfile;

  /// features/settings/presentation/settings_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Your birthday'**
  String get settingsYourBirthday;

  /// features/settings/presentation/settings_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Add it, and Chip throws you a party every year'**
  String get settingsAddItAndChipThrows;

  /// features/settings/presentation/settings_screen.dart
  ///
  /// In en, this message translates to:
  /// **'{label} (you can change it today)'**
  String settingsYouCanChangeItToday(Object label);

  /// features/settings/presentation/settings_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Show my coins'**
  String get settingsShowMyCoins;

  /// features/settings/presentation/settings_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Other players see them on your player card'**
  String get settingsOtherPlayersSeeThemOn;

  /// features/settings/presentation/settings_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t change that. Try again.'**
  String get settingsCouldnTChangeThatTry;

  /// features/settings/presentation/settings_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Show my stats'**
  String get settingsShowMyStats;

  /// features/settings/presentation/settings_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Others can open your rank hologram from the rankings'**
  String get settingsOthersCanOpenYourRank;

  /// features/settings/presentation/settings_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Gift PIN'**
  String get settingsGiftPin;

  /// features/settings/presentation/settings_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Every coin gift asks for it'**
  String get settingsEveryCoinGiftAsksFor;

  /// features/settings/presentation/settings_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Set · every coin gift asks for it'**
  String get settingsSetEveryCoinGiftAsks;

  /// features/settings/presentation/settings_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Not set yet · choose one for coin gifts'**
  String get settingsNotSetYetChooseOne;

  /// features/settings/presentation/settings_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Save your account'**
  String get settingsSaveYourAccount;

  /// features/settings/presentation/settings_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Keep your coins and worlds on any phone'**
  String get settingsKeepYourCoinsAndWorlds;

  /// features/settings/presentation/settings_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Sign out'**
  String get settingsSignOut;

  /// features/settings/presentation/settings_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Delete account'**
  String get settingsDeleteAccount;

  /// features/settings/presentation/settings_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Remove your account and everything in it'**
  String get settingsRemoveYourAccountAndEverything;

  /// features/settings/presentation/settings_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Help'**
  String get settingsHelp;

  /// features/settings/presentation/settings_screen.dart
  ///
  /// In en, this message translates to:
  /// **'How to play'**
  String get settingsHowToPlay;

  /// features/settings/presentation/settings_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Report a bug'**
  String get settingsReportABug;

  /// features/settings/presentation/settings_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Suggest a feature'**
  String get settingsSuggestAFeature;

  /// features/settings/presentation/settings_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Privacy policy'**
  String get settingsPrivacyPolicy;

  /// features/settings/presentation/settings_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Version {version}'**
  String settingsVersion(Object version);

  /// features/settings/presentation/settings_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Delete your account?'**
  String get settingsDeleteYourAccount;

  /// features/settings/presentation/settings_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Your profile, friends, chats, coins and everything you own in Utopia will be gone for good. This can\'t be undone.'**
  String get settingsYourProfileFriendsChatsCoins;

  /// features/settings/presentation/settings_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get settingsDelete;

  /// features/settings/presentation/settings_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Keep it'**
  String get settingsKeepIt;

  /// features/settings/presentation/settings_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t delete your account. Check your connection and try again.'**
  String get settingsCouldnTDeleteYourAccount;

  /// features/settings/presentation/settings_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Sign out?'**
  String get settingsSignOut2;

  /// features/settings/presentation/settings_screen.dart
  ///
  /// In en, this message translates to:
  /// **'You can sign back in with your email any time.'**
  String get settingsYouCanSignBackIn;

  /// features/settings/presentation/settings_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Stay'**
  String get settingsStay;

  /// features/settings/presentation/settings_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Screen size'**
  String get settingsScreenSize;

  /// features/settings/presentation/settings_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Reset'**
  String get settingsReset;
}

class _L10nDelegate extends LocalizationsDelegate<L10n> {
  const _L10nDelegate();

  @override
  Future<L10n> load(Locale locale) {
    return SynchronousFuture<L10n>(lookupL10n(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en'].contains(locale.languageCode);

  @override
  bool shouldReload(_L10nDelegate old) => false;
}

L10n lookupL10n(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return L10nEn();
  }

  throw FlutterError(
    'L10n.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
