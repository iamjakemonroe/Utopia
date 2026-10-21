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

  /// features/help/presentation/how_to_play_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Chess'**
  String get howToPlayChess;

  /// features/help/presentation/how_to_play_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Ludo'**
  String get howToPlayLudo;

  /// features/help/presentation/how_to_play_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Checkers'**
  String get howToPlayCheckers;

  /// features/help/presentation/how_to_play_screen.dart
  ///
  /// In en, this message translates to:
  /// **'How to play'**
  String get howToPlayHowToPlay;

  /// features/help/presentation/how_to_play_screen.dart
  ///
  /// In en, this message translates to:
  /// **'King'**
  String get howToPlayKing;

  /// features/help/presentation/how_to_play_screen.dart
  ///
  /// In en, this message translates to:
  /// **'One square any way. Keep it safe: if it can be taken and has no escape, the game is lost.'**
  String get howToPlayOneSquareAnyWayKeep;

  /// features/help/presentation/how_to_play_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Queen'**
  String get howToPlayQueen;

  /// features/help/presentation/how_to_play_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Any number of squares in a straight line or along a diagonal.'**
  String get howToPlayAnyNumberOfSquaresIn;

  /// features/help/presentation/how_to_play_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Rook'**
  String get howToPlayRook;

  /// features/help/presentation/how_to_play_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Any number of squares straight up, down or across.'**
  String get howToPlayAnyNumberOfSquaresStraight;

  /// features/help/presentation/how_to_play_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Bishop'**
  String get howToPlayBishop;

  /// features/help/presentation/how_to_play_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Any number of squares along a diagonal.'**
  String get howToPlayAnyNumberOfSquaresAlong;

  /// features/help/presentation/how_to_play_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Knight'**
  String get howToPlayKnight;

  /// features/help/presentation/how_to_play_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Jumps in an L: two squares one way, then one to the side. It can hop over pieces.'**
  String get howToPlayJumpsInAnLTwo;

  /// features/help/presentation/how_to_play_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Pawn'**
  String get howToPlayPawn;

  /// features/help/presentation/how_to_play_screen.dart
  ///
  /// In en, this message translates to:
  /// **'One square forward (two on its first move) and takes one square diagonally forward.'**
  String get howToPlayOneSquareForwardTwoOn;

  /// features/help/presentation/how_to_play_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Two players, one board. Out-think your opponent and trap their king.'**
  String get howToPlayTwoPlayersOneBoardOut;

  /// features/help/presentation/how_to_play_screen.dart
  ///
  /// In en, this message translates to:
  /// **'The goal'**
  String get howToPlayTheGoal;

  /// features/help/presentation/how_to_play_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Checkmate wins'**
  String get howToPlayCheckmateWins;

  /// features/help/presentation/how_to_play_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Attack the other king so it can\'t escape. That\'s checkmate, and the game is yours.'**
  String get howToPlayAttackTheOtherKingSo;

  /// features/help/presentation/how_to_play_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Check'**
  String get howToPlayCheck;

  /// features/help/presentation/how_to_play_screen.dart
  ///
  /// In en, this message translates to:
  /// **'When your king is attacked you must get it out of danger on your very next move.'**
  String get howToPlayWhenYourKingIsAttacked;

  /// features/help/presentation/how_to_play_screen.dart
  ///
  /// In en, this message translates to:
  /// **'How the pieces move'**
  String get howToPlayHowThePiecesMove;

  /// features/help/presentation/how_to_play_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Special moves'**
  String get howToPlaySpecialMoves;

  /// features/help/presentation/how_to_play_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Castling'**
  String get howToPlayCastling;

  /// features/help/presentation/how_to_play_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Once a game, your king can step two squares toward a rook and the rook jumps over it, as long as neither has moved, nothing\'s between them and the king isn\'t in check.'**
  String get howToPlayOnceAGameYourKing;

  /// features/help/presentation/how_to_play_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Promotion'**
  String get howToPlayPromotion;

  /// features/help/presentation/how_to_play_screen.dart
  ///
  /// In en, this message translates to:
  /// **'A pawn that reaches the far side becomes a queen, rook, bishop or knight. You choose.'**
  String get howToPlayAPawnThatReachesThe;

  /// features/help/presentation/how_to_play_screen.dart
  ///
  /// In en, this message translates to:
  /// **'En passant'**
  String get howToPlayEnPassant;

  /// features/help/presentation/how_to_play_screen.dart
  ///
  /// In en, this message translates to:
  /// **'If a pawn rushes two squares past one of yours, you can take it as if it had moved one, on your very next move only.'**
  String get howToPlayIfAPawnRushesTwo;

  /// features/help/presentation/how_to_play_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Draws'**
  String get howToPlayDraws;

  /// features/help/presentation/how_to_play_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Stalemate'**
  String get howToPlayStalemate;

  /// features/help/presentation/how_to_play_screen.dart
  ///
  /// In en, this message translates to:
  /// **'If it\'s your move, you\'re not in check and you have no legal move, the game is a draw.'**
  String get howToPlayIfItSYourMove;

  /// features/help/presentation/how_to_play_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Not enough to win'**
  String get howToPlayNotEnoughToWin;

  /// features/help/presentation/how_to_play_screen.dart
  ///
  /// In en, this message translates to:
  /// **'When neither side has enough pieces left to checkmate, it\'s a draw. Entries go back to both players.'**
  String get howToPlayWhenNeitherSideHasEnough;

  /// features/help/presentation/how_to_play_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Playing in Utopia'**
  String get howToPlayPlayingInUtopia;

  /// features/help/presentation/how_to_play_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Clocks'**
  String get howToPlayClocks;

  /// features/help/presentation/how_to_play_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Each side has its own time. Run out and you lose. Make your first move within 30 seconds or the game is called off and entries are returned.'**
  String get howToPlayEachSideHasItsOwn;

  /// features/help/presentation/how_to_play_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Entries and prizes'**
  String get howToPlayEntriesAndPrizes;

  /// features/help/presentation/how_to_play_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Pick a free game or an entry. The winner takes the prize; a draw gives everyone their entry back.'**
  String get howToPlayPickAFreeGameOr;

  /// features/help/presentation/how_to_play_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Look back'**
  String get howToPlayLookBack;

  /// features/help/presentation/how_to_play_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Use the arrows under the board to step through every move, during the game or after it. Tap a move to jump to it.'**
  String get howToPlayUseTheArrowsUnderThe;

  /// features/help/presentation/how_to_play_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Chat'**
  String get howToPlayChat;

  /// features/help/presentation/how_to_play_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Send messages, stickers and voice notes from the chat button. Games with strangers keep it friendly.'**
  String get howToPlaySendMessagesStickersAndVoice;

  /// features/help/presentation/how_to_play_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Leaving resigns'**
  String get howToPlayLeavingResigns;

  /// features/help/presentation/how_to_play_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Leaving a game in progress resigns it. Closed the app by accident? Open it again and you\'re taken straight back to your game.'**
  String get howToPlayLeavingAGameInProgress;

  /// features/help/presentation/how_to_play_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Two to six players race their pieces around the board and home. Roll, capture, and get all four in first.'**
  String get howToPlayTwoToSixPlayersRace;

  /// features/help/presentation/how_to_play_screen.dart
  ///
  /// In en, this message translates to:
  /// **'The basics'**
  String get howToPlayTheBasics;

  /// features/help/presentation/how_to_play_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Winning'**
  String get howToPlayWinning;

  /// features/help/presentation/how_to_play_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Playing with friends'**
  String get howToPlayPlayingWithFriends;

  /// features/help/presentation/how_to_play_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Rooms'**
  String get howToPlayRooms;

  /// features/help/presentation/how_to_play_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Make a room and share its code. Friends join with the code and the host starts the game.'**
  String get howToPlayMakeARoomAndShare;

  /// features/help/presentation/how_to_play_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Pick your seat'**
  String get howToPlayPickYourSeat;

  /// features/help/presentation/how_to_play_screen.dart
  ///
  /// In en, this message translates to:
  /// **'In a room, tap an empty seat to sit there and play that color, or share an invite to it.'**
  String get howToPlayInARoomTapAn;

  /// features/help/presentation/how_to_play_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Voice notes'**
  String get howToPlayVoiceNotes;

  /// features/help/presentation/how_to_play_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Hold a conversation without typing: record up to 30 seconds and it plays for everyone at the table.'**
  String get howToPlayHoldAConversationWithoutTyping;

  /// features/help/presentation/how_to_play_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Two players, twelve pieces each, on the dark squares of an 8x8 board. Dark moves first.'**
  String get howToPlayTwoPlayersTwelvePiecesEach;

  /// features/help/presentation/how_to_play_screen.dart
  ///
  /// In en, this message translates to:
  /// **'How pieces move'**
  String get howToPlayHowPiecesMove;

  /// features/help/presentation/how_to_play_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Men'**
  String get howToPlayMen;

  /// features/help/presentation/how_to_play_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Every piece starts as a man. A man moves one square diagonally forward, onto an empty dark square.'**
  String get howToPlayEveryPieceStartsAsA;

  /// features/help/presentation/how_to_play_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Kings'**
  String get howToPlayKings;

  /// features/help/presentation/how_to_play_screen.dart
  ///
  /// In en, this message translates to:
  /// **'A man that reaches the far row is crowned king. Kings move one square diagonally forward or backward.'**
  String get howToPlayAManThatReachesThe;

  /// features/help/presentation/how_to_play_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Taking pieces'**
  String get howToPlayTakingPieces;

  /// features/help/presentation/how_to_play_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Jump to take'**
  String get howToPlayJumpToTake;

  /// features/help/presentation/how_to_play_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Jump diagonally over an opponent\'s piece to an empty square right behind it, and that piece is taken. Men jump forward only; kings jump either way.'**
  String get howToPlayJumpDiagonallyOverAnOpponent;

  /// features/help/presentation/how_to_play_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Taking is a must'**
  String get howToPlayTakingIsAMust;

  /// features/help/presentation/how_to_play_screen.dart
  ///
  /// In en, this message translates to:
  /// **'If you can take a piece, you have to. The pieces that can take glow orange, and you choose which jump to make if there\'s more than one.'**
  String get howToPlayIfYouCanTakeA;

  /// features/help/presentation/how_to_play_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Multi-jumps'**
  String get howToPlayMultiJumps;

  /// features/help/presentation/how_to_play_screen.dart
  ///
  /// In en, this message translates to:
  /// **'After a jump, if the same piece can jump again, it keeps going in the same move. A man that\'s crowned mid-jump stops there.'**
  String get howToPlayAfterAJumpIfThe;

  /// features/help/presentation/how_to_play_screen.dart
  ///
  /// In en, this message translates to:
  /// **'No moves, no game'**
  String get howToPlayNoMovesNoGame;

  /// features/help/presentation/how_to_play_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Take all of your opponent\'s pieces, or leave them with no move to make, and you win.'**
  String get howToPlayTakeAllOfYourOpponent;

  /// features/help/presentation/how_to_play_screen.dart
  ///
  /// In en, this message translates to:
  /// **'If only kings move for forty moves each, with nothing taken, it\'s a draw. Entries go back to both players.'**
  String get howToPlayIfOnlyKingsMoveFor;

  /// features/help/presentation/how_to_play_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Clocks, entries and chat'**
  String get howToPlayClocksEntriesAndChat;

  /// features/help/presentation/how_to_play_screen.dart
  ///
  /// In en, this message translates to:
  /// **'The same as chess: your own clock, free games or an entry, every move to look back on, and chat with stickers and voice notes. Make your first move within 30 seconds.'**
  String get howToPlayTheSameAsChessYour;

  /// features/help/presentation/how_to_play_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Offline'**
  String get howToPlayOffline;

  /// features/help/presentation/how_to_play_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Play Chip or Robo at three levels, or pass one phone between two players. No internet needed.'**
  String get howToPlayPlayChipOrRoboAt;

  /// features/help/presentation/how_to_play_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Your pieces'**
  String get howToPlayYourPieces;

  /// features/help/presentation/how_to_play_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Your pieces wear your chess set. Buddies, Monsters and Robots get faces that watch the game.'**
  String get howToPlayYourPiecesWearYourChess;

  /// features/rankings/presentation/hologram/rank_hologram.dart
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get rankHologramClose;

  /// features/rankings/presentation/hologram/rank_hologram.dart
  ///
  /// In en, this message translates to:
  /// **'{toUpperCase}\'S HOLOGRAM'**
  String rankHologramSHologram(Object toUpperCase);

  /// features/rankings/presentation/hologram/rank_hologram.dart
  ///
  /// In en, this message translates to:
  /// **'COULDN\'T REACH {whose} STATS. CLOSE AND TRY AGAIN.'**
  String rankHologramCouldnTReachStatsClose(Object whose);

  /// features/rankings/presentation/hologram/rank_hologram.dart
  ///
  /// In en, this message translates to:
  /// **'SCANNING {whose} GAMES…'**
  String rankHologramScanningGames(Object whose);

  /// features/rankings/presentation/hologram/rank_hologram.dart
  ///
  /// In en, this message translates to:
  /// **'{value} KEEPS THEIR STATS TO THEMSELVES.'**
  String rankHologramKeepsTheirStatsToThemselves(Object value);

  /// features/rankings/presentation/hologram/rank_hologram.dart
  ///
  /// In en, this message translates to:
  /// **'YOUR HOLOGRAM FILLS IN AS YOU PLAY RATED {value} GAMES.'**
  String rankHologramYourHologramFillsInAs(Object value);

  /// features/rankings/presentation/hologram/rank_hologram.dart
  ///
  /// In en, this message translates to:
  /// **'{toUpperCase} HASN\'T PLAYED RATED {value} GAMES YET.'**
  String rankHologramHasnTPlayedRatedGames(Object toUpperCase, Object value);

  /// features/rankings/presentation/hologram/rank_hologram.dart
  ///
  /// In en, this message translates to:
  /// **'HOW YOU WIN'**
  String get rankHologramHowYouWin;

  /// features/rankings/presentation/hologram/rank_hologram.dart
  ///
  /// In en, this message translates to:
  /// **'HOW THEY WIN'**
  String get rankHologramHowTheyWin;

  /// features/rankings/presentation/hologram/rank_hologram.dart
  ///
  /// In en, this message translates to:
  /// **'HOW YOU LOSE'**
  String get rankHologramHowYouLose;

  /// features/rankings/presentation/hologram/rank_hologram.dart
  ///
  /// In en, this message translates to:
  /// **'HOW THEY LOSE'**
  String get rankHologramHowTheyLose;

  /// features/rankings/presentation/hologram/rank_hologram.dart
  ///
  /// In en, this message translates to:
  /// **'BEST WIN'**
  String get rankHologramBestWin;

  /// features/rankings/presentation/hologram/rank_hologram.dart
  ///
  /// In en, this message translates to:
  /// **'Rated {rating} when {first} beat them'**
  String rankHologramRatedWhenBeatThem(Object rating, Object first);

  /// features/rankings/presentation/hologram/rank_hologram.dart
  ///
  /// In en, this message translates to:
  /// **'YOUR RIVAL'**
  String get rankHologramYourRival;

  /// features/rankings/presentation/hologram/rank_hologram.dart
  ///
  /// In en, this message translates to:
  /// **'THEIR RIVAL'**
  String get rankHologramTheirRival;

  /// features/rankings/presentation/hologram/rank_hologram.dart
  ///
  /// In en, this message translates to:
  /// **'{games} games · {first} won {wins}, lost {losses}'**
  String rankHologramGamesWonLost(
    Object games,
    Object first,
    Object wins,
    Object losses,
  );

  /// features/rankings/presentation/hologram/rank_hologram.dart
  ///
  /// In en, this message translates to:
  /// **'YOUR NEMESIS'**
  String get rankHologramYourNemesis;

  /// features/rankings/presentation/hologram/rank_hologram.dart
  ///
  /// In en, this message translates to:
  /// **'THEIR NEMESIS'**
  String get rankHologramTheirNemesis;

  /// features/rankings/presentation/hologram/rank_hologram.dart
  ///
  /// In en, this message translates to:
  /// **'Beat {first} {losses} times'**
  String rankHologramBeatTimes(Object first, Object losses);

  /// features/rankings/presentation/hologram/rank_hologram.dart
  ///
  /// In en, this message translates to:
  /// **'RATED {value} SINCE {value2}'**
  String rankHologramRatedSince(Object value, Object value2);

  /// features/rankings/presentation/hologram/rank_hologram.dart
  ///
  /// In en, this message translates to:
  /// **'Feb'**
  String get rankHologramFeb;

  /// features/rankings/presentation/hologram/rank_hologram.dart
  ///
  /// In en, this message translates to:
  /// **'Mar'**
  String get rankHologramMar;

  /// features/rankings/presentation/hologram/rank_hologram.dart
  ///
  /// In en, this message translates to:
  /// **'Apr'**
  String get rankHologramApr;

  /// features/rankings/presentation/hologram/rank_hologram.dart
  ///
  /// In en, this message translates to:
  /// **'May'**
  String get rankHologramMay;

  /// features/rankings/presentation/hologram/rank_hologram.dart
  ///
  /// In en, this message translates to:
  /// **'Jun'**
  String get rankHologramJun;

  /// features/rankings/presentation/hologram/rank_hologram.dart
  ///
  /// In en, this message translates to:
  /// **'Jul'**
  String get rankHologramJul;

  /// features/rankings/presentation/hologram/rank_hologram.dart
  ///
  /// In en, this message translates to:
  /// **'Aug'**
  String get rankHologramAug;

  /// features/rankings/presentation/hologram/rank_hologram.dart
  ///
  /// In en, this message translates to:
  /// **'Sep'**
  String get rankHologramSep;

  /// features/rankings/presentation/hologram/rank_hologram.dart
  ///
  /// In en, this message translates to:
  /// **'Oct'**
  String get rankHologramOct;

  /// features/rankings/presentation/hologram/rank_hologram.dart
  ///
  /// In en, this message translates to:
  /// **'Nov'**
  String get rankHologramNov;

  /// features/rankings/presentation/hologram/rank_hologram.dart
  ///
  /// In en, this message translates to:
  /// **'Dec'**
  String get rankHologramDec;

  /// features/rankings/presentation/hologram/rank_hologram.dart
  ///
  /// In en, this message translates to:
  /// **'{value} more rated game{value2} to be ranked'**
  String rankHologramMoreRatedGameToBe(Object value, Object value2);

  /// features/rankings/presentation/hologram/rank_hologram.dart
  ///
  /// In en, this message translates to:
  /// **'THE TOP TIER'**
  String get rankHologramTheTopTier;

  /// features/rankings/presentation/hologram/rank_hologram.dart
  ///
  /// In en, this message translates to:
  /// **'THIS WEEK'**
  String get rankHologramThisWeek;

  /// features/rankings/presentation/hologram/rank_hologram.dart
  ///
  /// In en, this message translates to:
  /// **'THIS MONTH'**
  String get rankHologramThisMonth;

  /// features/rankings/presentation/hologram/rank_hologram.dart
  ///
  /// In en, this message translates to:
  /// **'STREAK NOW'**
  String get rankHologramStreakNow;

  /// features/rankings/presentation/hologram/rank_hologram.dart
  ///
  /// In en, this message translates to:
  /// **'Best: {bestStreak} {value} in a row'**
  String rankHologramBestInARow(Object bestStreak, Object value);

  /// features/rankings/presentation/hologram/rank_hologram.dart
  ///
  /// In en, this message translates to:
  /// **'BIGGEST CLIMB'**
  String get rankHologramBiggestClimb;

  /// features/rankings/presentation/hologram/rank_hologram.dart
  ///
  /// In en, this message translates to:
  /// **'in one game'**
  String get rankHologramInOneGame;

  /// features/rankings/presentation/hologram/rank_hologram.dart
  ///
  /// In en, this message translates to:
  /// **'rated games'**
  String get rankHologramRatedGames;

  /// features/rankings/presentation/hologram/rank_hologram.dart
  ///
  /// In en, this message translates to:
  /// **'AVERAGE OPPONENT'**
  String get rankHologramAverageOpponent;

  /// features/rankings/presentation/hologram/rank_hologram.dart
  ///
  /// In en, this message translates to:
  /// **'USUAL CLOCK'**
  String get rankHologramUsualClock;

  /// features/rankings/presentation/hologram/rank_hologram.dart
  ///
  /// In en, this message translates to:
  /// **'minutes + seconds a move'**
  String get rankHologramMinutesSecondsAMove;

  /// features/rankings/presentation/hologram/rank_hologram.dart
  ///
  /// In en, this message translates to:
  /// **'FASTEST WIN'**
  String get rankHologramFastestWin;

  /// features/rankings/presentation/hologram/rank_hologram.dart
  ///
  /// In en, this message translates to:
  /// **'AVERAGE GAME'**
  String get rankHologramAverageGame;

  /// features/rankings/presentation/hologram/rank_hologram.dart
  ///
  /// In en, this message translates to:
  /// **'no games yet'**
  String get rankHologramNoGamesYet;

  /// features/rankings/presentation/hologram/rank_hologram.dart
  ///
  /// In en, this message translates to:
  /// **'{wins} of {games} won · {value}%'**
  String rankHologramOfWon(Object wins, Object games, Object value);

  /// features/rankings/presentation/hologram/rank_hologram.dart
  ///
  /// In en, this message translates to:
  /// **'WHITE OR BLACK'**
  String get rankHologramWhiteOrBlack;

  /// features/rankings/presentation/hologram/rank_hologram.dart
  ///
  /// In en, this message translates to:
  /// **'DARK OR LIGHT'**
  String get rankHologramDarkOrLight;

  /// features/rankings/presentation/hologram/rank_hologram.dart
  ///
  /// In en, this message translates to:
  /// **'AS WHITE'**
  String get rankHologramAsWhite;

  /// features/rankings/presentation/hologram/rank_hologram.dart
  ///
  /// In en, this message translates to:
  /// **'AS DARK'**
  String get rankHologramAsDark;

  /// features/rankings/presentation/hologram/rank_hologram.dart
  ///
  /// In en, this message translates to:
  /// **'AS BLACK'**
  String get rankHologramAsBlack;

  /// features/rankings/presentation/hologram/rank_hologram.dart
  ///
  /// In en, this message translates to:
  /// **'AS LIGHT'**
  String get rankHologramAsLight;

  /// features/rankings/presentation/hologram/rank_hologram.dart
  ///
  /// In en, this message translates to:
  /// **'Checkmate'**
  String get rankHologramCheckmate;

  /// features/rankings/presentation/hologram/rank_hologram.dart
  ///
  /// In en, this message translates to:
  /// **'Resigned'**
  String get rankHologramResigned;

  /// features/rankings/presentation/hologram/rank_hologram.dart
  ///
  /// In en, this message translates to:
  /// **'On time'**
  String get rankHologramOnTime;

  /// features/rankings/presentation/hologram/rank_hologram.dart
  ///
  /// In en, this message translates to:
  /// **'Out of moves'**
  String get rankHologramOutOfMoves;

  /// features/rankings/presentation/hologram/rank_hologram.dart
  ///
  /// In en, this message translates to:
  /// **'Stalemate'**
  String get rankHologramStalemate;

  /// features/rankings/presentation/hologram/rank_hologram.dart
  ///
  /// In en, this message translates to:
  /// **'Draw'**
  String get rankHologramDraw;

  /// features/home/presentation/screens/home_screen.dart
  ///
  /// In en, this message translates to:
  /// **'{name} said not now.'**
  String homeSaidNotNow(Object name);

  /// features/home/presentation/screens/home_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Your challenge to {name} ran out.'**
  String homeYourChallengeToRanOut(Object name);

  /// features/home/presentation/screens/home_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get homeClose;

  /// features/home/presentation/screens/home_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Tap anywhere to close'**
  String get homeTapAnywhereToClose;

  /// features/home/presentation/screens/home_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Save your account to keep your coins and worlds on any phone.'**
  String get homeSaveYourAccountToKeep;

  /// features/home/presentation/screens/home_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Pick a username so friends can find you.'**
  String get homePickAUsernameSoFriends;

  /// features/home/presentation/screens/home_screen.dart
  ///
  /// In en, this message translates to:
  /// **'That challenge is no longer open.'**
  String get homeThatChallengeIsNoLonger;

  /// features/home/presentation/screens/home_screen.dart
  ///
  /// In en, this message translates to:
  /// **'{name} challenged you'**
  String homeChallengedYou(Object name);

  /// features/home/presentation/screens/home_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Checkers'**
  String get homeCheckers;

  /// features/home/presentation/screens/home_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Chess'**
  String get homeChess;

  /// features/home/presentation/screens/home_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Free'**
  String get homeFree;

  /// features/home/presentation/screens/home_screen.dart
  ///
  /// In en, this message translates to:
  /// **'{minutesLeft} min left'**
  String homeMinLeft(Object minutesLeft);

  /// features/home/presentation/screens/home_screen.dart
  ///
  /// In en, this message translates to:
  /// **'{name} stepped away. Play waits for them.'**
  String homeSteppedAwayPlayWaitsFor(Object name);

  /// features/home/presentation/screens/home_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Play'**
  String get homePlay;

  /// features/home/presentation/screens/home_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Waiting for {name}'**
  String homeWaitingFor(Object name);

  /// features/home/presentation/screens/home_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get homeCancel;

  /// features/home/presentation/screens/home_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Games'**
  String get homeGames;

  /// features/home/presentation/screens/home_screen.dart
  ///
  /// In en, this message translates to:
  /// **'1 to 30 min'**
  String get home1To30Min;

  /// features/home/presentation/screens/home_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Online & friends'**
  String get homeOnlineFriends;

  /// features/home/presentation/screens/home_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Ludo'**
  String get homeLudo;

  /// features/home/presentation/screens/home_screen.dart
  ///
  /// In en, this message translates to:
  /// **'2 to 6 players'**
  String get home2To6Players;

  /// features/home/presentation/screens/home_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Room codes'**
  String get homeRoomCodes;

  /// features/home/presentation/screens/home_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Multi-jumps'**
  String get homeMultiJumps;

  /// features/home/presentation/screens/home_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Play offline'**
  String get homePlayOffline;

  /// features/home/presentation/screens/home_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Guess My Doodle'**
  String get homeGuessMyDoodle;

  /// features/home/presentation/screens/home_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Draw & guess'**
  String get homeDrawGuess;

  /// features/home/presentation/screens/home_screen.dart
  ///
  /// In en, this message translates to:
  /// **'2 to 20 players'**
  String get home2To20Players;

  /// features/home/presentation/screens/home_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Your game is still on'**
  String get homeYourGameIsStillOn;

  /// features/home/presentation/screens/home_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Rejoin'**
  String get homeRejoin;

  /// features/home/presentation/screens/home_screen.dart
  ///
  /// In en, this message translates to:
  /// **'You'**
  String get homeYou;

  /// features/home/presentation/screens/home_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Open menu'**
  String get homeOpenMenu;

  /// features/home/presentation/screens/home_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Sketchbook'**
  String get homeSketchbook;

  /// features/home/presentation/screens/home_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Draw anything or color a picture, with real art tools.'**
  String get homeDrawAnythingOrColorA;

  /// features/home/presentation/screens/home_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Worlds & pieces'**
  String get homeWorldsPieces;

  /// features/home/presentation/screens/home_screen.dart
  ///
  /// In en, this message translates to:
  /// **'{length} worlds and {length2} color themes, and pieces made of crystal, candy and starlight.'**
  String homeWorldsAndColorThemesAnd(Object length, Object length2);

  /// features/home/presentation/screens/home_screen.dart
  ///
  /// In en, this message translates to:
  /// **'{name} with {value} · pick up where you left off'**
  String homeWithPickUpWhereYou(Object name, Object value);

  /// features/home/presentation/screens/home_screen.dart
  ///
  /// In en, this message translates to:
  /// **'{name} vs {against} · pick up where you left off'**
  String homeVsPickUpWhereYou(Object name, Object against);

  /// features/home/presentation/screens/home_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Ludo · the table is waiting'**
  String get homeLudoTheTableIsWaiting;

  /// features/home/presentation/screens/home_screen.dart
  ///
  /// In en, this message translates to:
  /// **'{name} · the game goes on without you'**
  String homeTheGameGoesOnWithout(Object name);

  /// features/home/presentation/screens/home_screen.dart
  ///
  /// In en, this message translates to:
  /// **'{name} · your clock may be running'**
  String homeYourClockMayBeRunning(Object name);

  /// features/coins/presentation/gift_pin.dart
  ///
  /// In en, this message translates to:
  /// **'Four digits, please.'**
  String get giftPinFourDigitsPlease;

  /// features/coins/presentation/gift_pin.dart
  ///
  /// In en, this message translates to:
  /// **'That one\'s too easy to guess. Try another.'**
  String get giftPinThatOneSTooEasy;

  /// features/coins/presentation/gift_pin.dart
  ///
  /// In en, this message translates to:
  /// **'in a minute'**
  String get giftPinInAMinute;

  /// features/coins/presentation/gift_pin.dart
  ///
  /// In en, this message translates to:
  /// **'in {ceil} minutes'**
  String giftPinInMinutes(Object ceil);

  /// features/coins/presentation/gift_pin.dart
  ///
  /// In en, this message translates to:
  /// **'Wrong PIN. One more try before gifts lock for a while.'**
  String get giftPinWrongPinOneMoreTry;

  /// features/coins/presentation/gift_pin.dart
  ///
  /// In en, this message translates to:
  /// **'Wrong PIN. {n} tries left.'**
  String giftPinWrongPinTriesLeft(Object n);

  /// features/coins/presentation/gift_pin.dart
  ///
  /// In en, this message translates to:
  /// **'Wrong PIN.'**
  String get giftPinWrongPin;

  /// features/coins/presentation/gift_pin.dart
  ///
  /// In en, this message translates to:
  /// **'Too many wrong tries. Try again {value}, or reset your PIN.'**
  String giftPinTooManyWrongTriesTry(Object value);

  /// features/coins/presentation/gift_pin.dart
  ///
  /// In en, this message translates to:
  /// **'Save your account first: gifts are for accounts.'**
  String get giftPinSaveYourAccountFirstGifts;

  /// features/coins/presentation/gift_pin.dart
  ///
  /// In en, this message translates to:
  /// **'That took a while. Send yourself a new code.'**
  String get giftPinThatTookAWhileSend;

  /// features/coins/presentation/gift_pin.dart
  ///
  /// In en, this message translates to:
  /// **'Choose a gift PIN first.'**
  String get giftPinChooseAGiftPinFirst;

  /// features/coins/presentation/gift_pin.dart
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t do that. Try again.'**
  String get giftPinCouldnTDoThatTry;

  /// features/coins/presentation/gift_pin.dart
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get giftPinDelete;

  /// features/coins/presentation/gift_pin.dart
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t send the code. Try again in a minute.'**
  String get giftPinCouldnTSendTheCode;

  /// features/coins/presentation/gift_pin.dart
  ///
  /// In en, this message translates to:
  /// **'That code didn\'t work. Check it, or send a new one.'**
  String get giftPinThatCodeDidnTWork;

  /// features/coins/presentation/gift_pin.dart
  ///
  /// In en, this message translates to:
  /// **'Those didn\'t match. Choose one again.'**
  String get giftPinThoseDidnTMatchChoose;

  /// features/coins/presentation/gift_pin.dart
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t save it. Try again.'**
  String get giftPinCouldnTSaveItTry;

  /// features/coins/presentation/gift_pin.dart
  ///
  /// In en, this message translates to:
  /// **'Forgot your PIN?'**
  String get giftPinForgotYourPin;

  /// features/coins/presentation/gift_pin.dart
  ///
  /// In en, this message translates to:
  /// **'Your account has no email for a code. Ask us through Report a bug and we\'ll help.'**
  String get giftPinYourAccountHasNoEmail;

  /// features/coins/presentation/gift_pin.dart
  ///
  /// In en, this message translates to:
  /// **'We\'ll email a code to {value} to check it\'s you. Then choose a new PIN.'**
  String giftPinWeLlEmailACode(Object value);

  /// features/coins/presentation/gift_pin.dart
  ///
  /// In en, this message translates to:
  /// **'Email me a code'**
  String get giftPinEmailMeACode;

  /// features/coins/presentation/gift_pin.dart
  ///
  /// In en, this message translates to:
  /// **'Enter the code'**
  String get giftPinEnterTheCode;

  /// features/coins/presentation/gift_pin.dart
  ///
  /// In en, this message translates to:
  /// **'The {kEmailCodeLength} digits in \"Your Utopia gift PIN code\", sent to {value}'**
  String giftPinTheDigitsInYourUtopia(Object kEmailCodeLength, Object value);

  /// features/coins/presentation/gift_pin.dart
  ///
  /// In en, this message translates to:
  /// **'Send a new code in {wait}s'**
  String giftPinSendANewCodeIn(Object wait);

  /// features/coins/presentation/gift_pin.dart
  ///
  /// In en, this message translates to:
  /// **'Send a new code'**
  String get giftPinSendANewCode;

  /// features/coins/presentation/gift_pin.dart
  ///
  /// In en, this message translates to:
  /// **'Your current PIN'**
  String get giftPinYourCurrentPin;

  /// features/coins/presentation/gift_pin.dart
  ///
  /// In en, this message translates to:
  /// **'Then choose a new one'**
  String get giftPinThenChooseANewOne;

  /// features/coins/presentation/gift_pin.dart
  ///
  /// In en, this message translates to:
  /// **'Choose a gift PIN'**
  String get giftPinChooseAGiftPin;

  /// features/coins/presentation/gift_pin.dart
  ///
  /// In en, this message translates to:
  /// **'Choose a new PIN'**
  String get giftPinChooseANewPin;

  /// features/coins/presentation/gift_pin.dart
  ///
  /// In en, this message translates to:
  /// **'4 digits you\'ll enter for every gift. Keep it to yourself.'**
  String get giftPin4DigitsYouLlEnter;

  /// features/coins/presentation/gift_pin.dart
  ///
  /// In en, this message translates to:
  /// **'Enter it again'**
  String get giftPinEnterItAgain;

  /// features/coins/presentation/gift_pin.dart
  ///
  /// In en, this message translates to:
  /// **'Just to be sure'**
  String get giftPinJustToBeSure;

  /// features/coins/presentation/gift_pin.dart
  ///
  /// In en, this message translates to:
  /// **'New gift PIN saved'**
  String get giftPinNewGiftPinSaved;

  /// features/coins/presentation/gift_pin.dart
  ///
  /// In en, this message translates to:
  /// **'Gift PIN set'**
  String get giftPinGiftPinSet;

  /// features/coins/presentation/gift_pin.dart
  ///
  /// In en, this message translates to:
  /// **'Save your account to send coins to friends, and give your gifts a PIN.'**
  String get giftPinSaveYourAccountToSend;

  /// features/coins/presentation/gift_pin.dart
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t check your PIN. Try again.'**
  String get giftPinCouldnTCheckYourPin;

  /// features/coins/presentation/gift_pin.dart
  ///
  /// In en, this message translates to:
  /// **'Gift PIN'**
  String get giftPinGiftPin;

  /// features/coins/presentation/gift_pin.dart
  ///
  /// In en, this message translates to:
  /// **'Every coin gift asks for it, so only you can send your coins.'**
  String get giftPinEveryCoinGiftAsksFor;

  /// features/coins/presentation/gift_pin.dart
  ///
  /// In en, this message translates to:
  /// **'You don\'t have one yet. You\'ll choose one before your first gift, or choose it now.'**
  String get giftPinYouDonTHaveOne;

  /// features/coins/presentation/gift_pin.dart
  ///
  /// In en, this message translates to:
  /// **'Locked after too many wrong tries: open again {value}, or reset it.'**
  String giftPinLockedAfterTooManyWrong(Object value);

  /// features/coins/presentation/gift_pin.dart
  ///
  /// In en, this message translates to:
  /// **'Choose a PIN'**
  String get giftPinChooseAPin;

  /// features/coins/presentation/gift_pin.dart
  ///
  /// In en, this message translates to:
  /// **'Change PIN'**
  String get giftPinChangePin;

  /// features/coins/presentation/gift_pin.dart
  ///
  /// In en, this message translates to:
  /// **'Forgot PIN?'**
  String get giftPinForgotPin;

  /// core/now_playing/media_kind.dart
  ///
  /// In en, this message translates to:
  /// **'Turn it up!'**
  String get mediaKindTurnItUp;

  /// core/now_playing/media_kind.dart
  ///
  /// In en, this message translates to:
  /// **'Okay, this one hits'**
  String get mediaKindOkayThisOneHits;

  /// core/now_playing/media_kind.dart
  ///
  /// In en, this message translates to:
  /// **'Party mode: on'**
  String get mediaKindPartyModeOn;

  /// core/now_playing/media_kind.dart
  ///
  /// In en, this message translates to:
  /// **'My feet are moving'**
  String get mediaKindMyFeetAreMoving;

  /// core/now_playing/media_kind.dart
  ///
  /// In en, this message translates to:
  /// **'Perfect chill vibes'**
  String get mediaKindPerfectChillVibes;

  /// core/now_playing/media_kind.dart
  ///
  /// In en, this message translates to:
  /// **'Nice and easy'**
  String get mediaKindNiceAndEasy;

  /// core/now_playing/media_kind.dart
  ///
  /// In en, this message translates to:
  /// **'This one is sweet'**
  String get mediaKindThisOneIsSweet;

  /// core/now_playing/media_kind.dart
  ///
  /// In en, this message translates to:
  /// **'So much heart'**
  String get mediaKindSoMuchHeart;

  /// core/now_playing/media_kind.dart
  ///
  /// In en, this message translates to:
  /// **'A sad one, huh'**
  String get mediaKindASadOneHuh;

  /// core/now_playing/media_kind.dart
  ///
  /// In en, this message translates to:
  /// **'I\'m here with you'**
  String get mediaKindIMHereWithYou;

  /// core/now_playing/media_kind.dart
  ///
  /// In en, this message translates to:
  /// **'This lifts me up'**
  String get mediaKindThisLiftsMeUp;

  /// core/now_playing/media_kind.dart
  ///
  /// In en, this message translates to:
  /// **'Beautiful praise'**
  String get mediaKindBeautifulPraise;

  /// core/now_playing/media_kind.dart
  ///
  /// In en, this message translates to:
  /// **'Now that\'s a tune'**
  String get mediaKindNowThatSATune;

  /// core/now_playing/media_kind.dart
  ///
  /// In en, this message translates to:
  /// **'This one\'s a vibe'**
  String get mediaKindThisOneSAVibe;

  /// core/now_playing/media_kind.dart
  ///
  /// In en, this message translates to:
  /// **'Is that {artist}?'**
  String mediaKindIsThat(Object artist);

  /// core/now_playing/media_kind.dart
  ///
  /// In en, this message translates to:
  /// **'Something good. I\'m vibing along.'**
  String get mediaKindSomethingGoodIMVibing;

  /// core/now_playing/media_kind.dart
  ///
  /// In en, this message translates to:
  /// **'Ooh, learning stuff'**
  String get mediaKindOohLearningStuff;

  /// core/now_playing/media_kind.dart
  ///
  /// In en, this message translates to:
  /// **'Glasses on. Let\'s learn'**
  String get mediaKindGlassesOnLetSLearn;

  /// core/now_playing/media_kind.dart
  ///
  /// In en, this message translates to:
  /// **'I can\'t stop laughing'**
  String get mediaKindICanTStopLaughing;

  /// core/now_playing/media_kind.dart
  ///
  /// In en, this message translates to:
  /// **'Okay that got me'**
  String get mediaKindOkayThatGotMe;

  /// core/now_playing/media_kind.dart
  ///
  /// In en, this message translates to:
  /// **'Who\'s winning?'**
  String get mediaKindWhoSWinning;

  /// core/now_playing/media_kind.dart
  ///
  /// In en, this message translates to:
  /// **'Ooh, nice play'**
  String get mediaKindOohNicePlay;

  /// core/now_playing/media_kind.dart
  ///
  /// In en, this message translates to:
  /// **'Did you see that?'**
  String get mediaKindDidYouSeeThat;

  /// core/now_playing/media_kind.dart
  ///
  /// In en, this message translates to:
  /// **'Go go go!'**
  String get mediaKindGoGoGo;

  /// core/now_playing/media_kind.dart
  ///
  /// In en, this message translates to:
  /// **'Ooh, a video!'**
  String get mediaKindOohAVideo;

  /// core/now_playing/media_kind.dart
  ///
  /// In en, this message translates to:
  /// **'Watching something{where}?'**
  String mediaKindWatchingSomething(Object where);

  /// core/now_playing/media_kind.dart
  ///
  /// In en, this message translates to:
  /// **'Is it a good one?'**
  String get mediaKindIsItAGoodOne;

  /// core/now_playing/media_kind.dart
  ///
  /// In en, this message translates to:
  /// **'Don\'t mind me, I\'m watching too.'**
  String get mediaKindDonTMindMeI;

  /// core/now_playing/media_kind.dart
  ///
  /// In en, this message translates to:
  /// **'A podcast? Smart.'**
  String get mediaKindAPodcastSmart;

  /// core/now_playing/media_kind.dart
  ///
  /// In en, this message translates to:
  /// **'Ooh, what\'s this one about?'**
  String get mediaKindOohWhatSThisOne;

  /// core/now_playing/media_kind.dart
  ///
  /// In en, this message translates to:
  /// **'A good listen, I bet'**
  String get mediaKindAGoodListenIBet;

  /// core/now_playing/media_kind.dart
  ///
  /// In en, this message translates to:
  /// **'I\'m all ears.'**
  String get mediaKindIMAllEars;

  /// core/now_playing/media_kind.dart
  ///
  /// In en, this message translates to:
  /// **'Taking in a sermon'**
  String get mediaKindTakingInASermon;

  /// core/now_playing/media_kind.dart
  ///
  /// In en, this message translates to:
  /// **'Some peace for the soul'**
  String get mediaKindSomePeaceForTheSoul;

  /// core/now_playing/media_kind.dart
  ///
  /// In en, this message translates to:
  /// **'I\'m listening quietly.'**
  String get mediaKindIMListeningQuietly;

  /// core/now_playing/media_kind.dart
  ///
  /// In en, this message translates to:
  /// **'Which chapter are we on?'**
  String get mediaKindWhichChapterAreWeOn;

  /// core/now_playing/media_kind.dart
  ///
  /// In en, this message translates to:
  /// **'A good book, nice'**
  String get mediaKindAGoodBookNice;

  /// core/now_playing/media_kind.dart
  ///
  /// In en, this message translates to:
  /// **'Don\'t tell me how it ends.'**
  String get mediaKindDonTTellMeHow;

  /// core/now_playing/media_kind.dart
  ///
  /// In en, this message translates to:
  /// **'Live and on air.'**
  String get mediaKindLiveAndOnAir;

  /// core/now_playing/media_kind.dart
  ///
  /// In en, this message translates to:
  /// **'What are we listening to?'**
  String get mediaKindWhatAreWeListeningTo;

  /// core/now_playing/media_kind.dart
  ///
  /// In en, this message translates to:
  /// **'I hear something good'**
  String get mediaKindIHearSomethingGood;

  /// core/now_playing/media_kind.dart
  ///
  /// In en, this message translates to:
  /// **'Tap me and tell me what\'s on.'**
  String get mediaKindTapMeAndTellMe;

  /// features/profile/presentation/screens/profile_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t change your avatar. Try again.'**
  String get profileCouldnTChangeYourAvatar;

  /// features/profile/presentation/screens/profile_screen.dart
  ///
  /// In en, this message translates to:
  /// **'You'**
  String get profileYou;

  /// features/profile/presentation/screens/profile_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get profileSettings;

  /// features/profile/presentation/screens/profile_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Save your account'**
  String get profileSaveYourAccount;

  /// features/profile/presentation/screens/profile_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Collection'**
  String get profileCollection;

  /// features/profile/presentation/screens/profile_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Recent games'**
  String get profileRecentGames;

  /// features/profile/presentation/screens/profile_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Pick a username'**
  String get profilePickAUsername;

  /// features/profile/presentation/screens/profile_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Feb'**
  String get profileFeb;

  /// features/profile/presentation/screens/profile_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Mar'**
  String get profileMar;

  /// features/profile/presentation/screens/profile_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Apr'**
  String get profileApr;

  /// features/profile/presentation/screens/profile_screen.dart
  ///
  /// In en, this message translates to:
  /// **'May'**
  String get profileMay;

  /// features/profile/presentation/screens/profile_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Jun'**
  String get profileJun;

  /// features/profile/presentation/screens/profile_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Jul'**
  String get profileJul;

  /// features/profile/presentation/screens/profile_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Aug'**
  String get profileAug;

  /// features/profile/presentation/screens/profile_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Sep'**
  String get profileSep;

  /// features/profile/presentation/screens/profile_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Oct'**
  String get profileOct;

  /// features/profile/presentation/screens/profile_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Nov'**
  String get profileNov;

  /// features/profile/presentation/screens/profile_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Dec'**
  String get profileDec;

  /// features/profile/presentation/screens/profile_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Guest'**
  String get profileGuest;

  /// features/profile/presentation/screens/profile_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Member'**
  String get profileMember;

  /// features/profile/presentation/screens/profile_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Member since {value} {value2}'**
  String profileMemberSince(Object value, Object value2);

  /// features/profile/presentation/screens/profile_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Coins'**
  String get profileCoins;

  /// features/profile/presentation/screens/profile_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Get coins'**
  String get profileGetCoins;

  /// features/profile/presentation/screens/profile_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Played'**
  String get profilePlayed;

  /// features/profile/presentation/screens/profile_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Won'**
  String get profileWon;

  /// features/profile/presentation/screens/profile_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Win rate'**
  String get profileWinRate;

  /// features/profile/presentation/screens/profile_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Ranks'**
  String get profileRanks;

  /// features/profile/presentation/screens/profile_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Unrated'**
  String get profileUnrated;

  /// features/profile/presentation/screens/profile_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Play online'**
  String get profilePlayOnline;

  /// features/profile/presentation/screens/profile_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Classic'**
  String get profileClassic;

  /// features/profile/presentation/screens/profile_screen.dart
  ///
  /// In en, this message translates to:
  /// **'No aura'**
  String get profileNoAura;

  /// features/profile/presentation/screens/profile_screen.dart
  ///
  /// In en, this message translates to:
  /// **'No games yet. Your first win will show up here.'**
  String get profileNoGamesYetYourFirst;

  /// features/profile/presentation/screens/profile_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Draw'**
  String get profileDraw;

  /// features/profile/presentation/screens/profile_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Lost'**
  String get profileLost;

  /// features/profile/presentation/screens/profile_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Chip'**
  String get profileChip;

  /// features/profile/presentation/screens/profile_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Your companion in every world. Drag Chip to give it a spin.'**
  String get profileYourCompanionInEveryWorld;

  /// features/support/presentation/report_bug_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Something broke'**
  String get reportBugSomethingBroke;

  /// features/support/presentation/report_bug_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Gameplay'**
  String get reportBugGameplay;

  /// features/support/presentation/report_bug_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Purchases'**
  String get reportBugPurchases;

  /// features/support/presentation/report_bug_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Account'**
  String get reportBugAccount;

  /// features/support/presentation/report_bug_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Tell us a little more (at least a few words).'**
  String get reportBugTellUsALittleMore;

  /// features/support/presentation/report_bug_screen.dart
  ///
  /// In en, this message translates to:
  /// **'You\'ve sent a lot of reports. Try again in a little while.'**
  String get reportBugYouVeSentALot;

  /// features/support/presentation/report_bug_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t send that. Check your connection and try again.'**
  String get reportBugCouldnTSendThatCheck;

  /// features/support/presentation/report_bug_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Suggest a feature'**
  String get reportBugSuggestAFeature;

  /// features/support/presentation/report_bug_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Report a bug'**
  String get reportBugReportABug;

  /// features/support/presentation/report_bug_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Thank you!'**
  String get reportBugThankYou;

  /// features/support/presentation/report_bug_screen.dart
  ///
  /// In en, this message translates to:
  /// **'We read every idea. Check back under Your reports to see what happens to it.'**
  String get reportBugWeReadEveryIdeaCheck;

  /// features/support/presentation/report_bug_screen.dart
  ///
  /// In en, this message translates to:
  /// **'We read every report. Check back under Your reports to see when it’s fixed.'**
  String get reportBugWeReadEveryReportCheck;

  /// features/support/presentation/report_bug_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get reportBugDone;

  /// features/support/presentation/report_bug_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Got an idea for Utopia? Tell Chip what you’d love to see.'**
  String get reportBugGotAnIdeaForUtopia;

  /// features/support/presentation/report_bug_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Spotted something off? Tell Chip what happened and we’ll fix it.'**
  String get reportBugSpottedSomethingOffTellChip;

  /// features/support/presentation/report_bug_screen.dart
  ///
  /// In en, this message translates to:
  /// **'What’s it about?'**
  String get reportBugWhatSItAbout;

  /// features/support/presentation/report_bug_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Your idea'**
  String get reportBugYourIdea;

  /// features/support/presentation/report_bug_screen.dart
  ///
  /// In en, this message translates to:
  /// **'What happened?'**
  String get reportBugWhatHappened;

  /// features/support/presentation/report_bug_screen.dart
  ///
  /// In en, this message translates to:
  /// **'What would make Utopia better for you?'**
  String get reportBugWhatWouldMakeUtopiaBetter;

  /// features/support/presentation/report_bug_screen.dart
  ///
  /// In en, this message translates to:
  /// **'What were you doing, and what went wrong?'**
  String get reportBugWhatWereYouDoingAnd;

  /// features/support/presentation/report_bug_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Screenshot (optional)'**
  String get reportBugScreenshotOptional;

  /// features/support/presentation/report_bug_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Add a screenshot'**
  String get reportBugAddAScreenshot;

  /// features/support/presentation/report_bug_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get reportBugRemove;

  /// features/support/presentation/report_bug_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Email (optional)'**
  String get reportBugEmailOptional;

  /// features/support/presentation/report_bug_screen.dart
  ///
  /// In en, this message translates to:
  /// **'So we can follow up'**
  String get reportBugSoWeCanFollowUp;

  /// features/support/presentation/report_bug_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Send idea'**
  String get reportBugSendIdea;

  /// features/support/presentation/report_bug_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Send report'**
  String get reportBugSendReport;

  /// features/support/presentation/report_bug_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Sent with your username, the app version, your phone’s system and the screen you were on.'**
  String get reportBugSentWithYourUsernameThe;

  /// features/support/presentation/report_bug_screen.dart
  ///
  /// In en, this message translates to:
  /// **'On our list'**
  String get reportBugOnOurList;

  /// features/support/presentation/report_bug_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Added'**
  String get reportBugAdded;

  /// features/support/presentation/report_bug_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Fixed'**
  String get reportBugFixed;

  /// features/support/presentation/report_bug_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Not planned'**
  String get reportBugNotPlanned;

  /// features/support/presentation/report_bug_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Sent'**
  String get reportBugSent;

  /// features/support/presentation/report_bug_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Your reports'**
  String get reportBugYourReports;

  /// features/collection/presentation/collection_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Collection'**
  String get collectionCollection;

  /// features/collection/presentation/collection_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Worlds'**
  String get collectionWorlds;

  /// features/collection/presentation/collection_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Frames'**
  String get collectionFrames;

  /// features/collection/presentation/collection_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Ludo'**
  String get collectionLudo;

  /// features/collection/presentation/collection_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Chess'**
  String get collectionChess;

  /// features/collection/presentation/collection_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Your worlds'**
  String get collectionYourWorlds;

  /// features/collection/presentation/collection_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Tap one to travel there. Chip takes you through a portal!'**
  String get collectionTapOneToTravelThere;

  /// features/collection/presentation/collection_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Your colors'**
  String get collectionYourColors;

  /// features/collection/presentation/collection_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Utopia recolored, at dawn, dusk or midnight.'**
  String get collectionUtopiaRecoloredAtDawnDusk;

  /// features/collection/presentation/collection_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Back next season'**
  String get collectionBackNextSeason;

  /// features/collection/presentation/collection_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Yours for good. They open again when their event\'s on.'**
  String get collectionYoursForGoodTheyOpen;

  /// features/collection/presentation/collection_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Find more worlds in the store'**
  String get collectionFindMoreWorldsInThe;

  /// features/collection/presentation/collection_screen.dart
  ///
  /// In en, this message translates to:
  /// **'You\'re here'**
  String get collectionYouReHere;

  /// features/collection/presentation/collection_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Birthday · today'**
  String get collectionBirthdayToday;

  /// features/collection/presentation/collection_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Owned'**
  String get collectionOwned;

  /// features/collection/presentation/collection_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Rented · {value}'**
  String collectionRented(Object value);

  /// features/collection/presentation/collection_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Free'**
  String get collectionFree;

  /// features/collection/presentation/collection_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Back next {value}'**
  String collectionBackNext(Object value);

  /// features/collection/presentation/collection_screen.dart
  ///
  /// In en, this message translates to:
  /// **'{name} opens again next {value}.'**
  String collectionOpensAgainNext(Object name, Object value);

  /// features/collection/presentation/collection_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Your frames'**
  String get collectionYourFrames;

  /// features/collection/presentation/collection_screen.dart
  ///
  /// In en, this message translates to:
  /// **'You don\'t have a frame right now.'**
  String get collectionYouDonTHaveA;

  /// features/collection/presentation/collection_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Wear one around your picture, for everyone to see.'**
  String get collectionWearOneAroundYourPicture;

  /// features/collection/presentation/collection_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Yours for good. Wear them again when their event\'s on.'**
  String get collectionYoursForGoodWearThem;

  /// features/collection/presentation/collection_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Find more frames in the store'**
  String get collectionFindMoreFramesInThe;

  /// features/collection/presentation/collection_screen.dart
  ///
  /// In en, this message translates to:
  /// **'You can wear {name} again next {value}.'**
  String collectionYouCanWearAgainNext(Object name, Object value);

  /// features/collection/presentation/collection_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t change your frame. Try again?'**
  String get collectionCouldnTChangeYourFrame;

  /// features/collection/presentation/collection_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Out of season'**
  String get collectionOutOfSeason;

  /// features/collection/presentation/collection_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Take off'**
  String get collectionTakeOff;

  /// features/collection/presentation/collection_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Wear'**
  String get collectionWear;

  /// features/support/presentation/privacy_screen.dart
  ///
  /// In en, this message translates to:
  /// **'October 20, 2026'**
  String get privacyOctober202026;

  /// features/support/presentation/privacy_screen.dart
  ///
  /// In en, this message translates to:
  /// **'What we collect'**
  String get privacyWhatWeCollect;

  /// features/support/presentation/privacy_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Your profile. The name, username and picture you choose (a picture you upload is stored so other players can see it), the world, piece sets and aura you wear, and your coin balance.'**
  String get privacyYourProfileTheNameUsername;

  /// features/support/presentation/privacy_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Games. The games you play and their moves and results, your coin history (coins are virtual, have no cash value and can\'t be cashed out), and the items you own or rent. In Guess My Doodle, what you draw is shown live to the players in that game and kept only until the turn is over; a game\'s chat and guesses are deleted a day after it ends.'**
  String get privacyGamesTheGamesYouPlay;

  /// features/support/presentation/privacy_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Purchases. If you buy coins, Apple or Google take the payment, and we never see your card or bank details. We get the purchase\'s ID, the pack, when it was bought and whether it was refunded, so we can add your coins once and take them back if the payment is refunded. If you join Chip Maestro, Apple or Google handle the subscription; we keep its ID, plan and renewal dates so we know you\'re a member.'**
  String get privacyPurchasesIfYouBuyCoins;

  /// features/support/presentation/privacy_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Messages. Chat messages and voice notes you send in games and to friends. Voice notes are only available to the players in that game.'**
  String get privacyMessagesChatMessagesAndVoice;

  /// features/support/presentation/privacy_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Friends. Friend requests and your friends list.'**
  String get privacyFriendsFriendRequestsAndYour;

  /// features/support/presentation/privacy_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Reports. When you report a bug or suggest a feature: what you write, an optional screenshot, an optional email for follow-up, and the app version, phone system, screen and world you were in.'**
  String get privacyReportsWhenYouReportA;

  /// features/support/presentation/privacy_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Crash reports. If the app crashes, a report of what went wrong (the error, your phone\'s model and system version, and the app version) goes to Sentry, which helps us fix it. It doesn\'t include your name, messages or anything you\'ve made.'**
  String get privacyCrashReportsIfTheApp;

  /// features/support/presentation/privacy_screen.dart
  ///
  /// In en, this message translates to:
  /// **'How you use Utopia. When the app opens, the screens you go to, and when you finish a game, buy something, earn a reward, share an invite or chat with Chip (not what you say), so we can see what works and fix what doesn\'t. It stays in our own database: it\'s never sold or given to advertisers, and it\'s deleted with your account.'**
  String get privacyHowYouUseUtopiaWhen;

  /// features/support/presentation/privacy_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Chip. When you chat with Chip, your messages and some context from the app (your first name, the time, the screen and world you\'re on, and your coins, worlds and aura) are used to write his replies. Your conversation is kept on your phone until you start a new chat. Chip can also keep a few short notes about things you tell him, like a plan or a favourite world, so he can follow up next time; ask him to forget and he deletes them. If you send Chip a photo, it\'s used to draw your picture and isn\'t kept on our servers; it stays on your phone until you start a new chat, and a picture drawn from it is visible only to you. When Chip colors a picture for you, the picture is sent to him to choose the colors. A real portrait is drawn from your photo or the name you give. One from your photo is kept privately for you; one of a famous person is shared with other Chip Maestro members who ask for them. If you let Chip see what you\'re playing in other apps, the title and artist of the song, video or podcast are used for his reaction to it.'**
  String get privacyChipWhenYouChatWith;

  /// features/support/presentation/privacy_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Your Sketchbook drawings are kept only on your phone, unless you choose to save one to your photos.'**
  String get privacyYourSketchbookDrawingsAreKept;

  /// features/support/presentation/privacy_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Permissions on your phone'**
  String get privacyPermissionsOnYourPhone;

  /// features/support/presentation/privacy_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Photos: to pick a profile picture or a screenshot for a report, and to save your drawings to your photos when you ask.'**
  String get privacyPhotosToPickAProfile;

  /// features/support/presentation/privacy_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Notifications: game reminders and alerts, which you can turn off in Settings.'**
  String get privacyNotificationsGameRemindersAndAlerts;

  /// features/support/presentation/privacy_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Notification access (Android) or Apple Music (iPhone): optional, so Chip can see what\'s playing. You can turn it off any time in your phone\'s settings.'**
  String get privacyNotificationAccessAndroidOrApple;

  /// features/support/presentation/privacy_screen.dart
  ///
  /// In en, this message translates to:
  /// **'How we use it'**
  String get privacyHowWeUseIt;

  /// features/support/presentation/privacy_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Who we share it with'**
  String get privacyWhoWeShareItWith;

  /// features/support/presentation/privacy_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Supabase hosts Utopia\'s servers and stores the information above (in the European Union, Ireland).'**
  String get privacySupabaseHostsUtopiaSServers;

  /// features/support/presentation/privacy_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Resend delivers the sign-in codes we email you.'**
  String get privacyResendDeliversTheSignIn;

  /// features/support/presentation/privacy_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Sentry receives crash reports, to help us fix what went wrong.'**
  String get privacySentryReceivesCrashReportsTo;

  /// features/support/presentation/privacy_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Anthropic processes Chip\'s chats, the photos you send him and what\'s-playing details to write his replies and draw and color your pictures. It doesn\'t use them to train its models.'**
  String get privacyAnthropicProcessesChipSChats;

  /// features/support/presentation/privacy_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Google draws real portraits: it gets the photo or name for that portrait, under its paid API terms.'**
  String get privacyGoogleDrawsRealPortraitsIt;

  /// features/support/presentation/privacy_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Apple and Google run the app stores Utopia comes from, and take the payment when you buy coins.'**
  String get privacyAppleAndGoogleRunThe;

  /// features/support/presentation/privacy_screen.dart
  ///
  /// In en, this message translates to:
  /// **'We may also share information if the law requires it, or to protect players and Utopia.'**
  String get privacyWeMayAlsoShareInformation;

  /// features/support/presentation/privacy_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Keeping and deleting it'**
  String get privacyKeepingAndDeletingIt;

  /// features/support/presentation/privacy_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Children'**
  String get privacyChildren;

  /// features/support/presentation/privacy_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Changes and contact'**
  String get privacyChangesAndContact;

  /// features/support/presentation/privacy_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Privacy policy'**
  String get privacyPrivacyPolicy;

  /// features/support/presentation/privacy_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Last updated {updated}'**
  String privacyLastUpdated(Object updated);

  /// features/support/presentation/privacy_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Utopia is a game app for chess, checkers, Ludo and Guess My Doodle, with animated worlds and a mascot called Chip. This policy explains what information Utopia collects, why, who it\'s shared with, and the choices you have.'**
  String get privacyUtopiaIsAGameApp;

  /// features/maestro/presentation/maestro_sheet.dart
  ///
  /// In en, this message translates to:
  /// **'Chip Maestro'**
  String get maestroChipMaestro;

  /// features/maestro/presentation/maestro_sheet.dart
  ///
  /// In en, this message translates to:
  /// **'You\'re a Chip Maestro. Chip is your artist.'**
  String get maestroYouReAChipMaestro;

  /// features/maestro/presentation/maestro_sheet.dart
  ///
  /// In en, this message translates to:
  /// **'Coming soon'**
  String get maestroComingSoon;

  /// features/maestro/presentation/maestro_sheet.dart
  ///
  /// In en, this message translates to:
  /// **'Join Chip Maestro'**
  String get maestroJoinChipMaestro;

  /// features/maestro/presentation/maestro_sheet.dart
  ///
  /// In en, this message translates to:
  /// **'Join for {price} a month'**
  String maestroJoinForAMonth(Object price);

  /// features/maestro/presentation/maestro_sheet.dart
  ///
  /// In en, this message translates to:
  /// **'Not sure yet? Your first real portrait is free.'**
  String get maestroNotSureYetYourFirst;

  /// features/maestro/presentation/maestro_sheet.dart
  ///
  /// In en, this message translates to:
  /// **'Restore purchases'**
  String get maestroRestorePurchases;

  /// features/maestro/presentation/maestro_sheet.dart
  ///
  /// In en, this message translates to:
  /// **'Renews every month until you cancel. Cancel any time in your {value} settings, at least a day before it renews.'**
  String maestroRenewsEveryMonthUntilYou(Object value);

  /// features/maestro/presentation/maestro_sheet.dart
  ///
  /// In en, this message translates to:
  /// **'Terms of Use'**
  String get maestroTermsOfUse;

  /// features/maestro/presentation/maestro_sheet.dart
  ///
  /// In en, this message translates to:
  /// **'Privacy Policy'**
  String get maestroPrivacyPolicy;

  /// features/maestro/presentation/maestro_sheet.dart
  ///
  /// In en, this message translates to:
  /// **'Feb'**
  String get maestroFeb;

  /// features/maestro/presentation/maestro_sheet.dart
  ///
  /// In en, this message translates to:
  /// **'Mar'**
  String get maestroMar;

  /// features/maestro/presentation/maestro_sheet.dart
  ///
  /// In en, this message translates to:
  /// **'Apr'**
  String get maestroApr;

  /// features/maestro/presentation/maestro_sheet.dart
  ///
  /// In en, this message translates to:
  /// **'May'**
  String get maestroMay;

  /// features/maestro/presentation/maestro_sheet.dart
  ///
  /// In en, this message translates to:
  /// **'Jun'**
  String get maestroJun;

  /// features/maestro/presentation/maestro_sheet.dart
  ///
  /// In en, this message translates to:
  /// **'Jul'**
  String get maestroJul;

  /// features/maestro/presentation/maestro_sheet.dart
  ///
  /// In en, this message translates to:
  /// **'Aug'**
  String get maestroAug;

  /// features/maestro/presentation/maestro_sheet.dart
  ///
  /// In en, this message translates to:
  /// **'Sep'**
  String get maestroSep;

  /// features/maestro/presentation/maestro_sheet.dart
  ///
  /// In en, this message translates to:
  /// **'Oct'**
  String get maestroOct;

  /// features/maestro/presentation/maestro_sheet.dart
  ///
  /// In en, this message translates to:
  /// **'Nov'**
  String get maestroNov;

  /// features/maestro/presentation/maestro_sheet.dart
  ///
  /// In en, this message translates to:
  /// **'Dec'**
  String get maestroDec;

  /// features/maestro/presentation/maestro_sheet.dart
  ///
  /// In en, this message translates to:
  /// **'{left} real portraits left this month'**
  String maestroRealPortraitsLeftThisMonth(Object left);

  /// features/maestro/presentation/maestro_sheet.dart
  ///
  /// In en, this message translates to:
  /// **'Renews on {whenValue}'**
  String maestroRenewsOn(Object whenValue);

  /// features/maestro/presentation/maestro_sheet.dart
  ///
  /// In en, this message translates to:
  /// **'Ends on {whenValue}'**
  String maestroEndsOn(Object whenValue);

  /// features/maestro/presentation/maestro_sheet.dart
  ///
  /// In en, this message translates to:
  /// **'Manage your plan'**
  String get maestroManageYourPlan;

  /// features/coins/presentation/send_coins_sheet.dart
  ///
  /// In en, this message translates to:
  /// **'Sent {value} coins to {name}'**
  String sendCoinsSentCoinsTo(Object value, Object name);

  /// features/coins/presentation/send_coins_sheet.dart
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t send them. Try again (it won\'t send twice).'**
  String get sendCoinsCouldnTSendThemTry;

  /// features/coins/presentation/send_coins_sheet.dart
  ///
  /// In en, this message translates to:
  /// **'You can only send coins to friends.'**
  String get sendCoinsYouCanOnlySendCoins;

  /// features/coins/presentation/send_coins_sheet.dart
  ///
  /// In en, this message translates to:
  /// **'House players can\'t take gifts.'**
  String get sendCoinsHousePlayersCanTTake;

  /// features/coins/presentation/send_coins_sheet.dart
  ///
  /// In en, this message translates to:
  /// **'Choose how many to send.'**
  String get sendCoinsChooseHowManyToSend;

  /// features/coins/presentation/send_coins_sheet.dart
  ///
  /// In en, this message translates to:
  /// **'You don\'t have that many coins.'**
  String get sendCoinsYouDonTHaveThat;

  /// features/coins/presentation/send_coins_sheet.dart
  ///
  /// In en, this message translates to:
  /// **'Coins bought in the last two weeks can\'t be sent yet.'**
  String get sendCoinsCoinsBoughtInTheLast;

  /// features/coins/presentation/send_coins_sheet.dart
  ///
  /// In en, this message translates to:
  /// **'Save your account to send coins.'**
  String get sendCoinsSaveYourAccountToSend;

  /// features/coins/presentation/send_coins_sheet.dart
  ///
  /// In en, this message translates to:
  /// **'Sending coins is paused right now. Try again later.'**
  String get sendCoinsSendingCoinsIsPausedRight;

  /// features/coins/presentation/send_coins_sheet.dart
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t send them. Try again.'**
  String get sendCoinsCouldnTSendThemTry2;

  /// features/coins/presentation/send_coins_sheet.dart
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get sendCoinsBack;

  /// features/coins/presentation/send_coins_sheet.dart
  ///
  /// In en, this message translates to:
  /// **'Send coins'**
  String get sendCoinsSendCoins;

  /// features/coins/presentation/send_coins_sheet.dart
  ///
  /// In en, this message translates to:
  /// **'Send {value}'**
  String sendCoinsSend(Object value);

  /// features/coins/presentation/send_coins_sheet.dart
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t check what you can send. Try again.'**
  String get sendCoinsCouldnTCheckWhatYou;

  /// features/coins/presentation/send_coins_sheet.dart
  ///
  /// In en, this message translates to:
  /// **'Try again'**
  String get sendCoinsTryAgain;

  /// features/coins/presentation/send_coins_sheet.dart
  ///
  /// In en, this message translates to:
  /// **'Enter your gift PIN'**
  String get sendCoinsEnterYourGiftPin;

  /// features/coins/presentation/send_coins_sheet.dart
  ///
  /// In en, this message translates to:
  /// **'{name} gets them straight away. A gift can’t be undone.'**
  String sendCoinsGetsThemStraightAwayA(Object name);

  /// features/coins/presentation/send_coins_sheet.dart
  ///
  /// In en, this message translates to:
  /// **'Forgot PIN?'**
  String get sendCoinsForgotPin;

  /// features/coins/presentation/send_coins_sheet.dart
  ///
  /// In en, this message translates to:
  /// **'Choose a gift PIN'**
  String get sendCoinsChooseAGiftPin;

  /// features/coins/presentation/send_coins_sheet.dart
  ///
  /// In en, this message translates to:
  /// **'Gifts need one, so only you can send your coins: 4 digits you\'ll enter each time.'**
  String get sendCoinsGiftsNeedOneSoOnly;

  /// features/coins/presentation/send_coins_sheet.dart
  ///
  /// In en, this message translates to:
  /// **'Save your account to send coins to friends. It keeps your coins safe too.'**
  String get sendCoinsSaveYourAccountToSend2;

  /// features/coins/presentation/send_coins_sheet.dart
  ///
  /// In en, this message translates to:
  /// **'Save my account'**
  String get sendCoinsSaveMyAccount;

  /// features/coins/presentation/send_coins_sheet.dart
  ///
  /// In en, this message translates to:
  /// **'Other'**
  String get sendCoinsOther;

  /// features/coins/presentation/send_coins_sheet.dart
  ///
  /// In en, this message translates to:
  /// **'You don\'t have coins you can send right now.'**
  String get sendCoinsYouDonTHaveCoins;

  /// features/coins/presentation/send_coins_sheet.dart
  ///
  /// In en, this message translates to:
  /// **'You have {value} · you can send up to {value2}'**
  String sendCoinsYouHaveYouCanSend(Object value, Object value2);

  /// features/coins/presentation/send_coins_sheet.dart
  ///
  /// In en, this message translates to:
  /// **'{value} bought in the last {holdDays} days can be sent after that.'**
  String sendCoinsBoughtInTheLastDays(Object value, Object holdDays);

  /// features/coins/presentation/send_coins_sheet.dart
  ///
  /// In en, this message translates to:
  /// **'Send {value} coins'**
  String sendCoinsSendCoins2(Object value);

  /// features/coins/presentation/send_coins_sheet.dart
  ///
  /// In en, this message translates to:
  /// **'Friends only · your gift PIN sends it'**
  String get sendCoinsFriendsOnlyYourGiftPin;

  /// features/coins/presentation/send_coins_sheet.dart
  ///
  /// In en, this message translates to:
  /// **'Friends only · you\'ll choose a gift PIN next'**
  String get sendCoinsFriendsOnlyYouLlChoose;

  /// features/welcome/presentation/welcome_week.dart
  ///
  /// In en, this message translates to:
  /// **'Last day of your welcome pass. Keep the things you love from the store.'**
  String get welcomeWeekLastDayOfYourWelcome;

  /// features/welcome/presentation/welcome_week.dart
  ///
  /// In en, this message translates to:
  /// **'Tue'**
  String get welcomeWeekTue;

  /// features/welcome/presentation/welcome_week.dart
  ///
  /// In en, this message translates to:
  /// **'Wed'**
  String get welcomeWeekWed;

  /// features/welcome/presentation/welcome_week.dart
  ///
  /// In en, this message translates to:
  /// **'Thu'**
  String get welcomeWeekThu;

  /// features/welcome/presentation/welcome_week.dart
  ///
  /// In en, this message translates to:
  /// **'Fri'**
  String get welcomeWeekFri;

  /// features/welcome/presentation/welcome_week.dart
  ///
  /// In en, this message translates to:
  /// **'Sat'**
  String get welcomeWeekSat;

  /// features/welcome/presentation/welcome_week.dart
  ///
  /// In en, this message translates to:
  /// **'Feb'**
  String get welcomeWeekFeb;

  /// features/welcome/presentation/welcome_week.dart
  ///
  /// In en, this message translates to:
  /// **'Mar'**
  String get welcomeWeekMar;

  /// features/welcome/presentation/welcome_week.dart
  ///
  /// In en, this message translates to:
  /// **'Apr'**
  String get welcomeWeekApr;

  /// features/welcome/presentation/welcome_week.dart
  ///
  /// In en, this message translates to:
  /// **'May'**
  String get welcomeWeekMay;

  /// features/welcome/presentation/welcome_week.dart
  ///
  /// In en, this message translates to:
  /// **'Jun'**
  String get welcomeWeekJun;

  /// features/welcome/presentation/welcome_week.dart
  ///
  /// In en, this message translates to:
  /// **'Jul'**
  String get welcomeWeekJul;

  /// features/welcome/presentation/welcome_week.dart
  ///
  /// In en, this message translates to:
  /// **'Aug'**
  String get welcomeWeekAug;

  /// features/welcome/presentation/welcome_week.dart
  ///
  /// In en, this message translates to:
  /// **'Sep'**
  String get welcomeWeekSep;

  /// features/welcome/presentation/welcome_week.dart
  ///
  /// In en, this message translates to:
  /// **'Oct'**
  String get welcomeWeekOct;

  /// features/welcome/presentation/welcome_week.dart
  ///
  /// In en, this message translates to:
  /// **'Nov'**
  String get welcomeWeekNov;

  /// features/welcome/presentation/welcome_week.dart
  ///
  /// In en, this message translates to:
  /// **'Dec'**
  String get welcomeWeekDec;

  /// features/welcome/presentation/welcome_week.dart
  ///
  /// In en, this message translates to:
  /// **'Everything’s yours for {days} days'**
  String welcomeWeekEverythingSYoursForDays(Object days);

  /// features/welcome/presentation/welcome_week.dart
  ///
  /// In en, this message translates to:
  /// **'Every world, frame, chess set and piece set in Utopia is free to use for {days} days. Try them all, then keep the ones you love.'**
  String welcomeWeekEveryWorldFrameChessSet(Object days);

  /// features/welcome/presentation/welcome_week.dart
  ///
  /// In en, this message translates to:
  /// **'Free until {value}'**
  String welcomeWeekFreeUntil(Object value);

  /// features/welcome/presentation/welcome_week.dart
  ///
  /// In en, this message translates to:
  /// **'Explore everything'**
  String get welcomeWeekExploreEverything;

  /// features/welcome/presentation/welcome_week.dart
  ///
  /// In en, this message translates to:
  /// **'Maybe later'**
  String get welcomeWeekMaybeLater;

  /// features/welcome/presentation/welcome_week.dart
  ///
  /// In en, this message translates to:
  /// **'Your welcome pass is over'**
  String get welcomeWeekYourWelcomePassIsOver;

  /// features/welcome/presentation/welcome_week.dart
  ///
  /// In en, this message translates to:
  /// **'Hope you loved it. Your coins, and everything you bought or won, stay yours. Keep a favourite from the store any time: worlds can be rented from 1,200 coins.'**
  String get welcomeWeekHopeYouLovedItYour;

  /// features/welcome/presentation/welcome_week.dart
  ///
  /// In en, this message translates to:
  /// **'See the store'**
  String get welcomeWeekSeeTheStore;

  /// features/welcome/presentation/welcome_week.dart
  ///
  /// In en, this message translates to:
  /// **'Not now'**
  String get welcomeWeekNotNow;

  /// features/rankings/presentation/rankings_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Rankings'**
  String get rankingsRankings;

  /// features/rankings/presentation/rankings_widgets.dart
  ///
  /// In en, this message translates to:
  /// **'How rankings work'**
  String get rankingsHowRankingsWork;

  /// features/rankings/presentation/rankings_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Top players'**
  String get rankingsTopPlayers;

  /// features/rankings/presentation/rankings_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Players tagged House are Utopia\'s own: they keep the board busy until more players join, and never win prizes.'**
  String get rankingsPlayersTaggedHouseAreUtopia;

  /// features/rankings/presentation/rankings_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Ratings come from online games. Pull down to refresh.'**
  String get rankingsRatingsComeFromOnlineGames;

  /// features/rankings/presentation/rankings_screen.dart
  ///
  /// In en, this message translates to:
  /// **'YOUR RATING'**
  String get rankingsYourRating;

  /// features/rankings/presentation/rankings_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Last {length} games'**
  String rankingsLastGames(Object length);

  /// features/rankings/presentation/rankings_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Wins'**
  String get rankingsWins;

  /// features/rankings/presentation/rankings_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Losses'**
  String get rankingsLosses;

  /// features/rankings/presentation/rankings_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Draws'**
  String get rankingsDraws;

  /// features/rankings/presentation/rankings_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Best'**
  String get rankingsBest;

  /// features/rankings/presentation/rankings_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Insights'**
  String get rankingsInsights;

  /// features/rankings/presentation/rankings_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Not ranked yet'**
  String get rankingsNotRankedYet;

  /// features/rankings/presentation/rankings_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Getting placed'**
  String get rankingsGettingPlaced;

  /// features/rankings/presentation/rankings_screen.dart
  ///
  /// In en, this message translates to:
  /// **'#{place} among friends'**
  String rankingsAmongFriends(Object place);

  /// features/rankings/presentation/rankings_screen.dart
  ///
  /// In en, this message translates to:
  /// **'#{place} in Utopia'**
  String rankingsInUtopia(Object place);

  /// features/rankings/presentation/rankings_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Play {kGamesToRank} online games to get your place'**
  String rankingsPlayOnlineGamesToGet(Object kGamesToRank);

  /// features/rankings/presentation/rankings_screen.dart
  ///
  /// In en, this message translates to:
  /// **'{left} more {value} to get your place'**
  String rankingsMoreToGetYourPlace(Object left, Object value);

  /// features/rankings/presentation/rankings_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Everyone'**
  String get rankingsEveryone;

  /// features/rankings/presentation/rankings_widgets.dart
  ///
  /// In en, this message translates to:
  /// **'Friends'**
  String get rankingsFriends;

  /// features/rankings/presentation/rankings_screen.dart
  ///
  /// In en, this message translates to:
  /// **'None of your friends are ranked yet'**
  String get rankingsNoneOfYourFriendsAre;

  /// features/rankings/presentation/rankings_screen.dart
  ///
  /// In en, this message translates to:
  /// **'The podium is empty'**
  String get rankingsThePodiumIsEmpty;

  /// features/rankings/presentation/rankings_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Play {kGamesToRank} public games to the end to get on the board. The top spot is waiting!'**
  String rankingsPlayPublicGamesToThe(Object kGamesToRank);

  /// features/rankings/presentation/rankings_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Play {kGamesToRank} online games to get on the board. The top spot is waiting!'**
  String rankingsPlayOnlineGamesToGet2(Object kGamesToRank);

  /// features/rankings/presentation/rankings_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Play Guess My Doodle'**
  String get rankingsPlayGuessMyDoodle;

  /// features/rankings/presentation/rankings_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Play {value} online'**
  String rankingsPlayOnline(Object value);

  /// features/rankings/presentation/rankings_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t load the rankings.'**
  String get rankingsCouldnTLoadTheRankings;

  /// features/rankings/presentation/rankings_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Try again'**
  String get rankingsTryAgain;

  /// features/friends/presentation/widgets/friends_popup.dart
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t send the request. Try again.'**
  String get friendsCouldnTSendTheRequest;

  /// features/friends/presentation/widgets/friends_popup.dart
  ///
  /// In en, this message translates to:
  /// **'Friends'**
  String get friendsFriends;

  /// features/friends/presentation/widgets/friends_popup.dart
  ///
  /// In en, this message translates to:
  /// **'Search by username or name'**
  String get friendsSearchByUsernameOrName;

  /// features/friends/presentation/widgets/friends_popup.dart
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get friendsAll;

  /// features/friends/presentation/widgets/friends_popup.dart
  ///
  /// In en, this message translates to:
  /// **'Friends · {length}'**
  String friendsFriends2(Object length);

  /// features/friends/presentation/widgets/friends_popup.dart
  ///
  /// In en, this message translates to:
  /// **'Recents'**
  String get friendsRecents;

  /// features/friends/presentation/widgets/friends_popup.dart
  ///
  /// In en, this message translates to:
  /// **'No friends match that.'**
  String get friendsNoFriendsMatchThat;

  /// features/friends/presentation/widgets/friends_popup.dart
  ///
  /// In en, this message translates to:
  /// **'No friends yet. Search for someone above.'**
  String get friendsNoFriendsYetSearchFor;

  /// features/friends/presentation/widgets/friends_popup.dart
  ///
  /// In en, this message translates to:
  /// **'People you\'ve played who aren\'t friends yet will show up here.'**
  String get friendsPeopleYouVePlayedWho;

  /// features/friends/presentation/widgets/friends_popup.dart
  ///
  /// In en, this message translates to:
  /// **'Play a match or search for a username to add your first friend.'**
  String get friendsPlayAMatchOrSearch;

  /// features/friends/presentation/widgets/friends_popup.dart
  ///
  /// In en, this message translates to:
  /// **'On Utopia'**
  String get friendsOnUtopia;

  /// features/friends/presentation/widgets/friends_popup.dart
  ///
  /// In en, this message translates to:
  /// **'No one by that name yet.'**
  String get friendsNoOneByThatName;

  /// features/friends/presentation/widgets/friends_popup.dart
  ///
  /// In en, this message translates to:
  /// **'wants to be friends'**
  String get friendsWantsToBeFriends;

  /// features/friends/presentation/widgets/friends_popup.dart
  ///
  /// In en, this message translates to:
  /// **'Sent'**
  String get friendsSent;

  /// features/friends/presentation/widgets/friends_popup.dart
  ///
  /// In en, this message translates to:
  /// **'Play'**
  String get friendsPlay;

  /// features/friends/presentation/widgets/friends_popup.dart
  ///
  /// In en, this message translates to:
  /// **'Challenge sent'**
  String get friendsChallengeSent;

  /// features/friends/presentation/widgets/friends_popup.dart
  ///
  /// In en, this message translates to:
  /// **'Waiting for {name} to answer. Take it back?'**
  String friendsWaitingForToAnswerTake(Object name);

  /// features/friends/presentation/widgets/friends_popup.dart
  ///
  /// In en, this message translates to:
  /// **'{name} has {left} min left to answer. Take it back?'**
  String friendsHasMinLeftToAnswer(Object name, Object left);

  /// features/friends/presentation/widgets/friends_popup.dart
  ///
  /// In en, this message translates to:
  /// **'Cancel challenge'**
  String get friendsCancelChallenge;

  /// features/friends/presentation/widgets/friends_popup.dart
  ///
  /// In en, this message translates to:
  /// **'Keep it'**
  String get friendsKeepIt;

  /// features/friends/presentation/widgets/friends_popup.dart
  ///
  /// In en, this message translates to:
  /// **'Challenge sent to {name}. It lasts 10 minutes.'**
  String friendsChallengeSentToItLasts(Object name);

  /// features/friends/presentation/widgets/friends_popup.dart
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t send the challenge. Try again.'**
  String get friendsCouldnTSendTheChallenge;

  /// features/friends/presentation/widgets/friends_popup.dart
  ///
  /// In en, this message translates to:
  /// **'Send coins'**
  String get friendsSendCoins;

  /// features/friends/presentation/widgets/friends_popup.dart
  ///
  /// In en, this message translates to:
  /// **'Gift'**
  String get friendsGift;

  /// features/friends/presentation/widgets/friends_popup.dart
  ///
  /// In en, this message translates to:
  /// **'Requested'**
  String get friendsRequested;

  /// features/friends/presentation/widgets/friends_popup.dart
  ///
  /// In en, this message translates to:
  /// **'Accept'**
  String get friendsAccept;

  /// features/friends/presentation/widgets/friends_popup.dart
  ///
  /// In en, this message translates to:
  /// **'Add friend'**
  String get friendsAddFriend;

  /// features/rankings/presentation/rankings_widgets.dart
  ///
  /// In en, this message translates to:
  /// **'{value}{delta} this week'**
  String rankingsThisWeek(Object value, Object delta);

  /// features/rankings/presentation/rankings_widgets.dart
  ///
  /// In en, this message translates to:
  /// **'Start'**
  String get rankingsStart;

  /// features/rankings/presentation/rankings_widgets.dart
  ///
  /// In en, this message translates to:
  /// **'You\'re a Legend. The very top!'**
  String get rankingsYouReALegendThe;

  /// features/rankings/presentation/rankings_widgets.dart
  ///
  /// In en, this message translates to:
  /// **'{value} more rating to reach {label}'**
  String rankingsMoreRatingToReach(Object value, Object label);

  /// features/rankings/presentation/rankings_widgets.dart
  ///
  /// In en, this message translates to:
  /// **'Open spot'**
  String get rankingsOpenSpot;

  /// features/rankings/presentation/rankings_widgets.dart
  ///
  /// In en, this message translates to:
  /// **'You'**
  String get rankingsYou;

  /// features/rankings/presentation/rankings_widgets.dart
  ///
  /// In en, this message translates to:
  /// **'{label} · {games} games'**
  String rankingsGames(Object label, Object games);

  /// features/rankings/presentation/rankings_widgets.dart
  ///
  /// In en, this message translates to:
  /// **'House player'**
  String get rankingsHousePlayer;

  /// features/rankings/presentation/rankings_widgets.dart
  ///
  /// In en, this message translates to:
  /// **'House'**
  String get rankingsHouse;

  /// features/rankings/presentation/rankings_widgets.dart
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t send the request. Try again.'**
  String get rankingsCouldnTSendTheRequest;

  /// features/rankings/presentation/rankings_widgets.dart
  ///
  /// In en, this message translates to:
  /// **'One of Utopia\'s house players: they play free games when nobody\'s free, and keep the board busy while it\'s new. They never win prizes.'**
  String get rankingsOneOfUtopiaSHouse;

  /// features/rankings/presentation/rankings_widgets.dart
  ///
  /// In en, this message translates to:
  /// **'Rating'**
  String get rankingsRating;

  /// features/rankings/presentation/rankings_widgets.dart
  ///
  /// In en, this message translates to:
  /// **'Place'**
  String get rankingsPlace;

  /// features/rankings/presentation/rankings_widgets.dart
  ///
  /// In en, this message translates to:
  /// **'Rated games'**
  String get rankingsRatedGames;

  /// features/rankings/presentation/rankings_widgets.dart
  ///
  /// In en, this message translates to:
  /// **'Request sent'**
  String get rankingsRequestSent;

  /// features/rankings/presentation/rankings_widgets.dart
  ///
  /// In en, this message translates to:
  /// **'Accept friend request'**
  String get rankingsAcceptFriendRequest;

  /// features/rankings/presentation/rankings_widgets.dart
  ///
  /// In en, this message translates to:
  /// **'Add friend'**
  String get rankingsAddFriend;

  /// features/rankings/presentation/rankings_widgets.dart
  ///
  /// In en, this message translates to:
  /// **'See my stats'**
  String get rankingsSeeMyStats;

  /// features/rankings/presentation/rankings_widgets.dart
  ///
  /// In en, this message translates to:
  /// **'See their stats'**
  String get rankingsSeeTheirStats;

  /// features/rankings/presentation/rankings_widgets.dart
  ///
  /// In en, this message translates to:
  /// **'Everyone starts at 1000 in chess, checkers and Guess My Doodle. Win an online game and your rating goes up; lose and it goes down. Beating someone rated higher earns more. After {kGamesToRank} games you get a place on the board.\n\nGuess My Doodle counts public games played to the end, ranking everyone by their final score.'**
  String rankingsEveryoneStartsAt1000In(Object kGamesToRank);

  /// features/rankings/presentation/rankings_widgets.dart
  ///
  /// In en, this message translates to:
  /// **'{from} and up'**
  String rankingsAndUp(Object from);

  /// features/rankings/presentation/rankings_widgets.dart
  ///
  /// In en, this message translates to:
  /// **'The same two players count 3 games a day against each other.'**
  String get rankingsTheSameTwoPlayersCount;

  /// features/events/presentation/event_widgets.dart
  ///
  /// In en, this message translates to:
  /// **'All done this week. New quests on Monday.'**
  String get eventAllDoneThisWeekNew;

  /// features/events/presentation/event_widgets.dart
  ///
  /// In en, this message translates to:
  /// **'You earned everything. Yours every {title}.'**
  String eventYouEarnedEverythingYoursEvery(Object title);

  /// features/events/presentation/event_widgets.dart
  ///
  /// In en, this message translates to:
  /// **'play {games} more game{value}'**
  String eventPlayMoreGame(Object games, Object value);

  /// features/events/presentation/event_widgets.dart
  ///
  /// In en, this message translates to:
  /// **'come by on {days} more day{value}'**
  String eventComeByOnMoreDay(Object days, Object value);

  /// features/events/presentation/event_widgets.dart
  ///
  /// In en, this message translates to:
  /// **'Coins for playing, new every Monday. {timeLeft}.'**
  String eventCoinsForPlayingNewEvery(Object timeLeft);

  /// features/events/presentation/event_widgets.dart
  ///
  /// In en, this message translates to:
  /// **'Earn these free by playing. They stay yours, and come back every {title}. {timeLeft}.'**
  String eventEarnTheseFreeByPlaying(Object title, Object timeLeft);

  /// features/events/presentation/event_widgets.dart
  ///
  /// In en, this message translates to:
  /// **'Every game counts: online, with friends, or against Chip and Robo.'**
  String get eventEveryGameCountsOnlineWith;

  /// features/events/presentation/event_widgets.dart
  ///
  /// In en, this message translates to:
  /// **'World'**
  String get eventWorld;

  /// features/events/presentation/event_widgets.dart
  ///
  /// In en, this message translates to:
  /// **'Frame'**
  String get eventFrame;

  /// features/events/presentation/event_widgets.dart
  ///
  /// In en, this message translates to:
  /// **'Coins'**
  String get eventCoins;

  /// features/events/presentation/event_widgets.dart
  ///
  /// In en, this message translates to:
  /// **'Collected'**
  String get eventCollected;

  /// features/events/presentation/event_widgets.dart
  ///
  /// In en, this message translates to:
  /// **'Play {games} games'**
  String eventPlayGames(Object games);

  /// features/events/presentation/event_widgets.dart
  ///
  /// In en, this message translates to:
  /// **'Come by on {days} days'**
  String eventComeByOnDays(Object days);

  /// features/events/presentation/event_widgets.dart
  ///
  /// In en, this message translates to:
  /// **'You\'re here'**
  String get eventYouReHere;

  /// features/events/presentation/event_widgets.dart
  ///
  /// In en, this message translates to:
  /// **'Travel there'**
  String get eventTravelThere;

  /// features/events/presentation/event_widgets.dart
  ///
  /// In en, this message translates to:
  /// **'Wearing it'**
  String get eventWearingIt;

  /// features/events/presentation/event_widgets.dart
  ///
  /// In en, this message translates to:
  /// **'Wear it'**
  String get eventWearIt;

  /// features/events/presentation/event_widgets.dart
  ///
  /// In en, this message translates to:
  /// **'You\'re wearing {name}.'**
  String eventYouReWearing(Object name);

  /// features/events/presentation/event_widgets.dart
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t put it on. Try again?'**
  String get eventCouldnTPutItOn;

  /// features/events/presentation/event_widgets.dart
  ///
  /// In en, this message translates to:
  /// **'Quest complete!'**
  String get eventQuestComplete;

  /// features/events/presentation/event_widgets.dart
  ///
  /// In en, this message translates to:
  /// **'Unlocked!'**
  String get eventUnlocked;

  /// features/events/presentation/event_widgets.dart
  ///
  /// In en, this message translates to:
  /// **'A new world, yours for good. It\'s open whenever its season is on.'**
  String get eventANewWorldYoursFor;

  /// features/events/presentation/event_widgets.dart
  ///
  /// In en, this message translates to:
  /// **'A new frame, yours for good. You can wear it whenever its season is on.'**
  String get eventANewFrameYoursFor;

  /// features/events/presentation/event_widgets.dart
  ///
  /// In en, this message translates to:
  /// **'Added to your coins. Keep playing: there\'s more this week.'**
  String get eventAddedToYourCoinsKeep;

  /// features/events/presentation/event_widgets.dart
  ///
  /// In en, this message translates to:
  /// **'{title} event · {timeLeft}'**
  String eventEvent(Object title, Object timeLeft);

  /// features/events/presentation/event_widgets.dart
  ///
  /// In en, this message translates to:
  /// **'You earned {value}. Enjoy!'**
  String eventYouEarnedEnjoy(Object value);

  /// features/events/presentation/event_widgets.dart
  ///
  /// In en, this message translates to:
  /// **'Earn {value} free, just by playing.'**
  String eventEarnFreeJustByPlaying(Object value);

  /// features/auth/presentation/screens/email_link_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Enter a valid email address.'**
  String get emailLinkEnterAValidEmailAddress;

  /// features/auth/presentation/screens/email_link_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Too many code requests. Wait a few minutes and try again.'**
  String get emailLinkTooManyCodeRequestsWait;

  /// features/auth/presentation/screens/email_link_screen.dart
  ///
  /// In en, this message translates to:
  /// **'We couldn\'t send that email right now. Try again shortly.'**
  String get emailLinkWeCouldnTSendThat;

  /// features/auth/presentation/screens/email_link_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t send a code. Check the address and try again.'**
  String get emailLinkCouldnTSendACode;

  /// features/auth/presentation/screens/email_link_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Enter the code from your email.'**
  String get emailLinkEnterTheCodeFromYour;

  /// features/auth/presentation/screens/email_link_screen.dart
  ///
  /// In en, this message translates to:
  /// **'That code didn\'t work. Try again.'**
  String get emailLinkThatCodeDidnTWork;

  /// features/auth/presentation/screens/email_link_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Account saved!'**
  String get emailLinkAccountSaved;

  /// features/auth/presentation/screens/email_link_screen.dart
  ///
  /// In en, this message translates to:
  /// **'You\'re in!'**
  String get emailLinkYouReIn;

  /// features/auth/presentation/screens/email_link_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Check your email'**
  String get emailLinkCheckYourEmail;

  /// features/auth/presentation/screens/email_link_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Save your account'**
  String get emailLinkSaveYourAccount;

  /// features/auth/presentation/screens/email_link_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Welcome to Utopia'**
  String get emailLinkWelcomeToUtopia;

  /// features/auth/presentation/screens/email_link_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Your coins and worlds are safe on any phone now.'**
  String get emailLinkYourCoinsAndWorldsAre;

  /// features/auth/presentation/screens/email_link_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Signed in as {trim}'**
  String emailLinkSignedInAs(Object trim);

  /// features/auth/presentation/screens/email_link_screen.dart
  ///
  /// In en, this message translates to:
  /// **'We sent a code to {trim}'**
  String emailLinkWeSentACodeTo(Object trim);

  /// features/auth/presentation/screens/email_link_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Enter your email and we\'ll send you a code.'**
  String get emailLinkEnterYourEmailAndWe;

  /// features/auth/presentation/screens/email_link_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Send code'**
  String get emailLinkSendCode;

  /// features/auth/presentation/screens/email_link_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Verify'**
  String get emailLinkVerify;

  /// features/auth/presentation/screens/email_link_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Change email'**
  String get emailLinkChangeEmail;

  /// features/auth/presentation/screens/email_link_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Resend in {resendIn}s'**
  String emailLinkResendInS(Object resendIn);

  /// features/auth/presentation/screens/email_link_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Resend'**
  String get emailLinkResend;

  /// features/auth/presentation/screens/email_link_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Not there? It can take a minute, or land in spam.'**
  String get emailLinkNotThereItCanTake;

  /// features/auth/presentation/screens/email_link_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Keep your coins, worlds and friends'**
  String get emailLinkKeepYourCoinsWorldsAnd;

  /// features/auth/presentation/screens/email_link_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Play on any phone, or in your browser'**
  String get emailLinkPlayOnAnyPhoneOr;

  /// features/auth/presentation/screens/email_link_screen.dart
  ///
  /// In en, this message translates to:
  /// **'No password. We email you a code.'**
  String get emailLinkNoPasswordWeEmailYou;

  /// features/auth/presentation/screens/email_link_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Opening the portal'**
  String get emailLinkOpeningThePortal;

  /// core/widgets/utopia_toast.dart
  ///
  /// In en, this message translates to:
  /// **'You don\'t have enough coins for that.'**
  String get utopiaToastYouDonTHaveEnough;

  /// core/widgets/utopia_toast.dart
  ///
  /// In en, this message translates to:
  /// **'Can\'t reach Utopia right now. Check your connection.'**
  String get utopiaToastCanTReachUtopiaRight;

  /// core/widgets/utopia_toast.dart
  ///
  /// In en, this message translates to:
  /// **'Too late: they already answered it.'**
  String get utopiaToastTooLateTheyAlreadyAnswered;

  /// core/widgets/utopia_toast.dart
  ///
  /// In en, this message translates to:
  /// **'That challenge ran out: they last 10 minutes. Challenge them back!'**
  String get utopiaToastThatChallengeRanOutThey;

  /// core/widgets/utopia_toast.dart
  ///
  /// In en, this message translates to:
  /// **'They\'ve stepped away, so the game can\'t start yet. It waits till they\'re back (or it runs out).'**
  String get utopiaToastTheyVeSteppedAwaySo;

  /// core/widgets/utopia_toast.dart
  ///
  /// In en, this message translates to:
  /// **'That room is already full.'**
  String get utopiaToastThatRoomIsAlreadyFull;

  /// core/widgets/utopia_toast.dart
  ///
  /// In en, this message translates to:
  /// **'We couldn\'t find a room with that code.'**
  String get utopiaToastWeCouldnTFindA;

  /// core/widgets/utopia_toast.dart
  ///
  /// In en, this message translates to:
  /// **'That game has already started.'**
  String get utopiaToastThatGameHasAlreadyStarted;

  /// core/widgets/utopia_toast.dart
  ///
  /// In en, this message translates to:
  /// **'Use 3 to 20 letters, numbers or underscores.'**
  String get utopiaToastUse3To20Letters;

  /// core/widgets/utopia_toast.dart
  ///
  /// In en, this message translates to:
  /// **'That name is taken. Try another.'**
  String get utopiaToastThatNameIsTakenTry;

  /// features/notifications/presentation/notification_center.dart
  ///
  /// In en, this message translates to:
  /// **'Utopia'**
  String get notificationCenterUtopia;

  /// features/notifications/presentation/notification_center.dart
  ///
  /// In en, this message translates to:
  /// **'{name} wants to be friends'**
  String notificationCenterWantsToBeFriends(Object name);

  /// features/notifications/presentation/notification_center.dart
  ///
  /// In en, this message translates to:
  /// **'Accept and you can challenge each other any time.'**
  String get notificationCenterAcceptAndYouCanChallenge;

  /// features/notifications/presentation/notification_center.dart
  ///
  /// In en, this message translates to:
  /// **'{name} accepted your request'**
  String notificationCenterAcceptedYourRequest(Object name);

  /// features/notifications/presentation/notification_center.dart
  ///
  /// In en, this message translates to:
  /// **'You\'re friends now. Send a challenge!'**
  String get notificationCenterYouReFriendsNowSend;

  /// features/notifications/presentation/notification_center.dart
  ///
  /// In en, this message translates to:
  /// **'{name} challenged you'**
  String notificationCenterChallengedYou(Object name);

  /// features/notifications/presentation/notification_center.dart
  ///
  /// In en, this message translates to:
  /// **'It\'s {name}\'s birthday!'**
  String notificationCenterItSSBirthday(Object name);

  /// features/notifications/presentation/notification_center.dart
  ///
  /// In en, this message translates to:
  /// **'Wish them a happy birthday.'**
  String get notificationCenterWishThemAHappyBirthday;

  /// features/notifications/presentation/notification_center.dart
  ///
  /// In en, this message translates to:
  /// **'{name} sent you {value} coins'**
  String notificationCenterSentYouCoins(Object name, Object value);

  /// features/notifications/presentation/notification_center.dart
  ///
  /// In en, this message translates to:
  /// **'A gift. They’re in your coins now.'**
  String get notificationCenterAGiftTheyReIn;

  /// features/notifications/presentation/notification_center.dart
  ///
  /// In en, this message translates to:
  /// **'Your idea is in Utopia!'**
  String get notificationCenterYourIdeaIsInUtopia;

  /// features/notifications/presentation/notification_center.dart
  ///
  /// In en, this message translates to:
  /// **'Your report is fixed!'**
  String get notificationCenterYourReportIsFixed;

  /// features/notifications/presentation/notification_center.dart
  ///
  /// In en, this message translates to:
  /// **'About your idea'**
  String get notificationCenterAboutYourIdea;

  /// features/notifications/presentation/notification_center.dart
  ///
  /// In en, this message translates to:
  /// **'About your report'**
  String get notificationCenterAboutYourReport;

  /// features/notifications/presentation/notification_center.dart
  ///
  /// In en, this message translates to:
  /// **'Thanks for telling us.'**
  String get notificationCenterThanksForTellingUs;

  /// features/notifications/presentation/notification_center.dart
  ///
  /// In en, this message translates to:
  /// **'{name} wished you a happy birthday!'**
  String notificationCenterWishedYouAHappyBirthday(Object name);

  /// features/notifications/presentation/notification_center.dart
  ///
  /// In en, this message translates to:
  /// **'Have a wonderful day.'**
  String get notificationCenterHaveAWonderfulDay;

  /// features/notifications/presentation/notification_center.dart
  ///
  /// In en, this message translates to:
  /// **'Someone'**
  String get notificationCenterSomeone;

  /// features/notifications/presentation/notification_center.dart
  ///
  /// In en, this message translates to:
  /// **'Play'**
  String get notificationCenterPlay;

  /// features/notifications/presentation/notification_center.dart
  ///
  /// In en, this message translates to:
  /// **'Accept'**
  String get notificationCenterAccept;

  /// features/home/domain/greeting.dart
  ///
  /// In en, this message translates to:
  /// **'Fresh skies, fresh games.'**
  String get greetingFreshSkiesFreshGames;

  /// features/home/domain/greeting.dart
  ///
  /// In en, this message translates to:
  /// **'Coffee and a quick game?'**
  String get greetingCoffeeAndAQuickGame;

  /// features/home/domain/greeting.dart
  ///
  /// In en, this message translates to:
  /// **'The early bird gets the first roll.'**
  String get greetingTheEarlyBirdGetsThe;

  /// features/home/domain/greeting.dart
  ///
  /// In en, this message translates to:
  /// **'Perfect weather for a win.'**
  String get greetingPerfectWeatherForAWin;

  /// features/home/domain/greeting.dart
  ///
  /// In en, this message translates to:
  /// **'The board is set. Your move.'**
  String get greetingTheBoardIsSetYour;

  /// features/home/domain/greeting.dart
  ///
  /// In en, this message translates to:
  /// **'The sun is high over Utopia.'**
  String get greetingTheSunIsHighOver;

  /// features/home/domain/greeting.dart
  ///
  /// In en, this message translates to:
  /// **'Time for a quick round?'**
  String get greetingTimeForAQuickRound;

  /// features/home/domain/greeting.dart
  ///
  /// In en, this message translates to:
  /// **'A good afternoon for a long game.'**
  String get greetingAGoodAfternoonForA;

  /// features/home/domain/greeting.dart
  ///
  /// In en, this message translates to:
  /// **'Wind down with a game or two.'**
  String get greetingWindDownWithAGame;

  /// features/home/domain/greeting.dart
  ///
  /// In en, this message translates to:
  /// **'The sunset looks great from here.'**
  String get greetingTheSunsetLooksGreatFrom;

  /// features/home/domain/greeting.dart
  ///
  /// In en, this message translates to:
  /// **'One more game before bed?'**
  String get greetingOneMoreGameBeforeBed;

  /// features/home/domain/greeting.dart
  ///
  /// In en, this message translates to:
  /// **'Quiet night. Loud dice.'**
  String get greetingQuietNightLoudDice;

  /// features/home/domain/greeting.dart
  ///
  /// In en, this message translates to:
  /// **'Hello, night owl'**
  String get greetingHelloNightOwl;

  /// features/home/domain/greeting.dart
  ///
  /// In en, this message translates to:
  /// **'The moon is keeping score tonight.'**
  String get greetingTheMoonIsKeepingScore;

  /// features/home/domain/greeting.dart
  ///
  /// In en, this message translates to:
  /// **'Just one more game. Probably.'**
  String get greetingJustOneMoreGameProbably;

  /// features/home/domain/greeting.dart
  ///
  /// In en, this message translates to:
  /// **'Make a wish! Mine is that you win today.'**
  String get greetingMakeAWishMineIs;

  /// features/home/domain/greeting.dart
  ///
  /// In en, this message translates to:
  /// **'Cake first, then games. Birthday rules.'**
  String get greetingCakeFirstThenGamesBirthday;

  /// features/home/domain/greeting.dart
  ///
  /// In en, this message translates to:
  /// **'Every firework out there is for you.'**
  String get greetingEveryFireworkOutThereIs;

  /// features/home/domain/greeting.dart
  ///
  /// In en, this message translates to:
  /// **'Your birthday world is open all day. Enjoy it!'**
  String get greetingYourBirthdayWorldIsOpen;

  /// features/home/domain/greeting.dart
  ///
  /// In en, this message translates to:
  /// **'Another trip around the sun. Let\'s celebrate!'**
  String get greetingAnotherTripAroundTheSun;

  /// features/home/domain/greeting.dart
  ///
  /// In en, this message translates to:
  /// **'I put my party hat on just for you.'**
  String get greetingIPutMyPartyHat;

  /// features/home/domain/greeting.dart
  ///
  /// In en, this message translates to:
  /// **'Hey there'**
  String get greetingHeyThere;

  /// features/install/presentation/install_sheet.dart
  ///
  /// In en, this message translates to:
  /// **'Utopia is on the App Store'**
  String get installUtopiaIsOnTheApp;

  /// features/install/presentation/install_sheet.dart
  ///
  /// In en, this message translates to:
  /// **'Utopia is on Google Play'**
  String get installUtopiaIsOnGooglePlay;

  /// features/install/presentation/install_sheet.dart
  ///
  /// In en, this message translates to:
  /// **'Get the app for sound in the background, notifications and more. Sign in with the same email and everything comes with you.'**
  String get installGetTheAppForSound;

  /// features/install/presentation/install_sheet.dart
  ///
  /// In en, this message translates to:
  /// **'Get the app'**
  String get installGetTheApp;

  /// features/install/presentation/install_sheet.dart
  ///
  /// In en, this message translates to:
  /// **'Keep playing here'**
  String get installKeepPlayingHere;

  /// features/install/presentation/install_sheet.dart
  ///
  /// In en, this message translates to:
  /// **'Utopia is on your home screen now.'**
  String get installUtopiaIsOnYourHome;

  /// features/install/presentation/install_sheet.dart
  ///
  /// In en, this message translates to:
  /// **'Tap the Share button in Safari'**
  String get installTapTheShareButtonIn;

  /// features/install/presentation/install_sheet.dart
  ///
  /// In en, this message translates to:
  /// **'Choose \"Add to Home Screen\"'**
  String get installChooseAddToHomeScreen;

  /// features/install/presentation/install_sheet.dart
  ///
  /// In en, this message translates to:
  /// **'Open Utopia from your home screen'**
  String get installOpenUtopiaFromYourHome;

  /// features/install/presentation/install_sheet.dart
  ///
  /// In en, this message translates to:
  /// **'In the menu bar, open File'**
  String get installInTheMenuBarOpen;

  /// features/install/presentation/install_sheet.dart
  ///
  /// In en, this message translates to:
  /// **'Choose \"Add to Dock\"'**
  String get installChooseAddToDock;

  /// features/install/presentation/install_sheet.dart
  ///
  /// In en, this message translates to:
  /// **'Open Utopia from your Dock'**
  String get installOpenUtopiaFromYourDock;

  /// features/install/presentation/install_sheet.dart
  ///
  /// In en, this message translates to:
  /// **'Open your browser\'s menu'**
  String get installOpenYourBrowserSMenu;

  /// features/install/presentation/install_sheet.dart
  ///
  /// In en, this message translates to:
  /// **'Choose \"Install Utopia\"'**
  String get installChooseInstallUtopia;

  /// features/install/presentation/install_sheet.dart
  ///
  /// In en, this message translates to:
  /// **'Open Utopia like any app'**
  String get installOpenUtopiaLikeAnyApp;

  /// features/install/presentation/install_sheet.dart
  ///
  /// In en, this message translates to:
  /// **'Install Utopia'**
  String get installInstallUtopia;

  /// features/install/presentation/install_sheet.dart
  ///
  /// In en, this message translates to:
  /// **'Play full screen, straight from your home screen, like any app. It\'s free and takes no space.'**
  String get installPlayFullScreenStraightFrom;

  /// features/install/presentation/install_sheet.dart
  ///
  /// In en, this message translates to:
  /// **'Install'**
  String get installInstall;

  /// features/install/presentation/install_sheet.dart
  ///
  /// In en, this message translates to:
  /// **'Not now'**
  String get installNotNow;

  /// features/birthday/presentation/birthday_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t change that. Try again?'**
  String get birthdayCouldnTChangeThatTry;

  /// features/birthday/presentation/birthday_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Your birthday\'s locked now. Report a bug if it\'s wrong and we\'ll fix it.'**
  String get birthdayYourBirthdaySLockedNow;

  /// features/birthday/presentation/birthday_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t save that. Try again?'**
  String get birthdayCouldnTSaveThatTry;

  /// features/birthday/presentation/birthday_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Saved. Chip will see you on {label}.'**
  String birthdaySavedChipWillSeeYou(Object label);

  /// features/birthday/presentation/birthday_screen.dart
  ///
  /// In en, this message translates to:
  /// **'It\'s a date!'**
  String get birthdayItSADate;

  /// features/birthday/presentation/birthday_screen.dart
  ///
  /// In en, this message translates to:
  /// **'When\'s your birthday?'**
  String get birthdayWhenSYourBirthday;

  /// features/birthday/presentation/birthday_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Chip throws you a party every year, in a world that only opens on your birthday.'**
  String get birthdayChipThrowsYouAParty;

  /// features/birthday/presentation/birthday_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Month'**
  String get birthdayMonth;

  /// features/birthday/presentation/birthday_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Day'**
  String get birthdayDay;

  /// features/birthday/presentation/birthday_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Your birthday\'s locked. If it\'s wrong, report a bug and we\'ll fix it.'**
  String get birthdayYourBirthdaySLockedIf;

  /// features/birthday/presentation/birthday_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Saved!'**
  String get birthdaySaved;

  /// features/birthday/presentation/birthday_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Save my birthday'**
  String get birthdaySaveMyBirthday;

  /// features/birthday/presentation/birthday_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Just the day and month, never the year. Only you can see it.'**
  String get birthdayJustTheDayAndMonth;

  /// features/birthday/presentation/birthday_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Skip for now'**
  String get birthdaySkipForNow;

  /// features/birthday/presentation/birthday_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Pick a month and a day'**
  String get birthdayPickAMonthAndA;

  /// features/birthday/presentation/birthday_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Your party: {label}'**
  String birthdayYourParty(Object label);

  /// features/birthday/presentation/birthday_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Tell my friends on the day'**
  String get birthdayTellMyFriendsOnThe;

  /// features/birthday/presentation/birthday_screen.dart
  ///
  /// In en, this message translates to:
  /// **'They can send you a birthday wish.'**
  String get birthdayTheyCanSendYouA;

  /// features/profile/presentation/username_dialog.dart
  ///
  /// In en, this message translates to:
  /// **'Saved'**
  String get usernameSaved;

  /// features/profile/presentation/username_dialog.dart
  ///
  /// In en, this message translates to:
  /// **'You\'re {value} now'**
  String usernameYouReNow(Object value);

  /// features/profile/presentation/username_dialog.dart
  ///
  /// In en, this message translates to:
  /// **'That name didn\'t work. Try another.'**
  String get usernameThatNameDidnTWork;

  /// features/profile/presentation/username_dialog.dart
  ///
  /// In en, this message translates to:
  /// **'Your name'**
  String get usernameYourName;

  /// features/profile/presentation/username_dialog.dart
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get usernameSave;

  /// features/profile/presentation/username_dialog.dart
  ///
  /// In en, this message translates to:
  /// **'You'**
  String get usernameYou;

  /// features/profile/presentation/username_dialog.dart
  ///
  /// In en, this message translates to:
  /// **'Nickname'**
  String get usernameNickname;

  /// features/profile/presentation/username_dialog.dart
  ///
  /// In en, this message translates to:
  /// **'What everyone sees. Write it any way you like: fancy letters, symbols and emoji are all fine.'**
  String get usernameWhatEveryoneSeesWriteIt;

  /// features/profile/presentation/username_dialog.dart
  ///
  /// In en, this message translates to:
  /// **'Username'**
  String get usernameUsername;

  /// features/profile/presentation/username_dialog.dart
  ///
  /// In en, this message translates to:
  /// **'Yours alone. Friends find you with it.'**
  String get usernameYoursAloneFriendsFindYou;

  /// features/profile/presentation/username_dialog.dart
  ///
  /// In en, this message translates to:
  /// **'3 to 20 long'**
  String get username3To20Long;

  /// features/profile/presentation/username_dialog.dart
  ///
  /// In en, this message translates to:
  /// **'Letters, numbers, _'**
  String get usernameLettersNumbers;

  /// features/profile/presentation/username_dialog.dart
  ///
  /// In en, this message translates to:
  /// **'Yours'**
  String get usernameYours;

  /// features/profile/presentation/username_dialog.dart
  ///
  /// In en, this message translates to:
  /// **'Free:'**
  String get usernameFree;

  /// features/profile/presentation/username_dialog.dart
  ///
  /// In en, this message translates to:
  /// **'Saving...'**
  String get usernameSaving;

  /// features/profile/presentation/username_dialog.dart
  ///
  /// In en, this message translates to:
  /// **'Available'**
  String get usernameAvailable;

  /// features/profile/presentation/username_dialog.dart
  ///
  /// In en, this message translates to:
  /// **'Taken'**
  String get usernameTaken;

  /// features/profile/presentation/username_dialog.dart
  ///
  /// In en, this message translates to:
  /// **'Checking'**
  String get usernameChecking;

  /// features/home/presentation/widgets/side_menu.dart
  ///
  /// In en, this message translates to:
  /// **'Close menu'**
  String get sideMenuCloseMenu;

  /// features/home/presentation/widgets/side_menu.dart
  ///
  /// In en, this message translates to:
  /// **'Player'**
  String get sideMenuPlayer;

  /// features/home/presentation/widgets/side_menu.dart
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get sideMenuProfile;

  /// features/home/presentation/widgets/side_menu.dart
  ///
  /// In en, this message translates to:
  /// **'Sketchbook'**
  String get sideMenuSketchbook;

  /// features/home/presentation/widgets/side_menu.dart
  ///
  /// In en, this message translates to:
  /// **'Store'**
  String get sideMenuStore;

  /// features/home/presentation/widgets/side_menu.dart
  ///
  /// In en, this message translates to:
  /// **'Collection'**
  String get sideMenuCollection;

  /// features/home/presentation/widgets/side_menu.dart
  ///
  /// In en, this message translates to:
  /// **'Rankings'**
  String get sideMenuRankings;

  /// features/home/presentation/widgets/side_menu.dart
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get sideMenuNotifications;

  /// features/home/presentation/widgets/side_menu.dart
  ///
  /// In en, this message translates to:
  /// **'Friends'**
  String get sideMenuFriends;

  /// features/home/presentation/widgets/side_menu.dart
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get sideMenuSettings;

  /// features/home/presentation/widgets/side_menu.dart
  ///
  /// In en, this message translates to:
  /// **'Help & feedback'**
  String get sideMenuHelpFeedback;

  /// features/home/presentation/widgets/side_menu.dart
  ///
  /// In en, this message translates to:
  /// **'Save your account'**
  String get sideMenuSaveYourAccount;

  /// features/home/presentation/widgets/side_menu.dart
  ///
  /// In en, this message translates to:
  /// **'Sign out'**
  String get sideMenuSignOut;

  /// features/home/presentation/widgets/side_menu.dart
  ///
  /// In en, this message translates to:
  /// **'Sign out?'**
  String get sideMenuSignOut2;

  /// features/home/presentation/widgets/side_menu.dart
  ///
  /// In en, this message translates to:
  /// **'You can sign back in with your email any time.'**
  String get sideMenuYouCanSignBackIn;

  /// features/home/presentation/widgets/side_menu.dart
  ///
  /// In en, this message translates to:
  /// **'Stay'**
  String get sideMenuStay;

  /// features/home/presentation/widgets/side_menu.dart
  ///
  /// In en, this message translates to:
  /// **'Guest'**
  String get sideMenuGuest;

  /// features/home/presentation/widgets/side_menu.dart
  ///
  /// In en, this message translates to:
  /// **'No username yet'**
  String get sideMenuNoUsernameYet;

  /// features/home/presentation/widgets/side_menu.dart
  ///
  /// In en, this message translates to:
  /// **'Utopia 1.0'**
  String get sideMenuUtopia10;

  /// core/notifications/local_notifications.dart
  ///
  /// In en, this message translates to:
  /// **'Friends and challenges'**
  String get localNotificationsFriendsAndChallenges;

  /// core/notifications/local_notifications.dart
  ///
  /// In en, this message translates to:
  /// **'Friend requests and game challenges.'**
  String get localNotificationsFriendRequestsAndGameChallenges;

  /// core/notifications/local_notifications.dart
  ///
  /// In en, this message translates to:
  /// **'Reminders'**
  String get localNotificationsReminders;

  /// core/notifications/local_notifications.dart
  ///
  /// In en, this message translates to:
  /// **'Now and then, a nudge to come back and play.'**
  String get localNotificationsNowAndThenANudge;

  /// core/notifications/local_notifications.dart
  ///
  /// In en, this message translates to:
  /// **'Chip misses you'**
  String get localNotificationsChipMissesYou;

  /// core/notifications/local_notifications.dart
  ///
  /// In en, this message translates to:
  /// **'One quick game? Your world is waiting.'**
  String get localNotificationsOneQuickGameYourWorld;

  /// core/notifications/local_notifications.dart
  ///
  /// In en, this message translates to:
  /// **'Game time?'**
  String get localNotificationsGameTime;

  /// core/notifications/local_notifications.dart
  ///
  /// In en, this message translates to:
  /// **'A chess game takes five minutes. Go on.'**
  String get localNotificationsAChessGameTakesFive;

  /// core/notifications/local_notifications.dart
  ///
  /// In en, this message translates to:
  /// **'An empty seat'**
  String get localNotificationsAnEmptySeat;

  /// core/notifications/local_notifications.dart
  ///
  /// In en, this message translates to:
  /// **'The Ludo table is waiting for someone to roll a six.'**
  String get localNotificationsTheLudoTableIsWaiting;

  /// core/notifications/local_notifications.dart
  ///
  /// In en, this message translates to:
  /// **'Something new is glowing'**
  String get localNotificationsSomethingNewIsGlowing;

  /// core/notifications/local_notifications.dart
  ///
  /// In en, this message translates to:
  /// **'Fresh auras are waiting in the store.'**
  String get localNotificationsFreshAurasAreWaitingIn;

  /// core/notifications/local_notifications.dart
  ///
  /// In en, this message translates to:
  /// **'Rematch?'**
  String get localNotificationsRematch;

  /// core/notifications/local_notifications.dart
  ///
  /// In en, this message translates to:
  /// **'Your friends are a tap away.'**
  String get localNotificationsYourFriendsAreATap;

  /// core/notifications/local_notifications.dart
  ///
  /// In en, this message translates to:
  /// **'Your clock is ready'**
  String get localNotificationsYourClockIsReady;

  /// core/notifications/local_notifications.dart
  ///
  /// In en, this message translates to:
  /// **'Pick a time and find an opponent.'**
  String get localNotificationsPickATimeAndFind;

  /// core/notifications/local_notifications.dart
  ///
  /// In en, this message translates to:
  /// **'Roll the dice'**
  String get localNotificationsRollTheDice;

  /// core/notifications/local_notifications.dart
  ///
  /// In en, this message translates to:
  /// **'Fancy a round of Ludo with friends?'**
  String get localNotificationsFancyARoundOfLudo;

  /// core/notifications/local_notifications.dart
  ///
  /// In en, this message translates to:
  /// **'Back to Utopia'**
  String get localNotificationsBackToUtopia;

  /// core/notifications/local_notifications.dart
  ///
  /// In en, this message translates to:
  /// **'Your coins are right where you left them.'**
  String get localNotificationsYourCoinsAreRightWhere;

  /// features/notifications/presentation/notifications_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get notificationsNotifications;

  /// features/notifications/presentation/notifications_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Friends'**
  String get notificationsFriends;

  /// features/notifications/presentation/notifications_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get notificationsToday;

  /// features/notifications/presentation/notifications_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Earlier'**
  String get notificationsEarlier;

  /// features/notifications/presentation/notifications_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Accepted'**
  String get notificationsAccepted;

  /// features/notifications/presentation/notifications_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Declined'**
  String get notificationsDeclined;

  /// features/notifications/presentation/notifications_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Their birthday is over. Catch them next year!'**
  String get notificationsTheirBirthdayIsOverCatch;

  /// features/notifications/presentation/notifications_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t send that. Try again?'**
  String get notificationsCouldnTSendThatTry;

  /// features/notifications/presentation/notifications_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Wished!'**
  String get notificationsWished;

  /// features/notifications/presentation/notifications_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Utopia'**
  String get notificationsUtopia;

  /// features/notifications/presentation/notifications_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Someone'**
  String get notificationsSomeone;

  /// features/notifications/presentation/notifications_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Play'**
  String get notificationsPlay;

  /// features/notifications/presentation/notifications_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Accept'**
  String get notificationsAccept;

  /// features/notifications/presentation/notifications_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Wish happy birthday'**
  String get notificationsWishHappyBirthday;

  /// features/notifications/presentation/notifications_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Play a game'**
  String get notificationsPlayAGame;

  /// features/notifications/presentation/notifications_screen.dart
  ///
  /// In en, this message translates to:
  /// **'All quiet'**
  String get notificationsAllQuiet;

  /// features/notifications/presentation/notifications_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Friend requests and challenges will show up here.'**
  String get notificationsFriendRequestsAndChallengesWill;

  /// features/home/presentation/widgets/now_playing_widgets.dart
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get nowPlayingClose;

  /// features/home/presentation/widgets/now_playing_widgets.dart
  ///
  /// In en, this message translates to:
  /// **'Previous'**
  String get nowPlayingPrevious;

  /// features/home/presentation/widgets/now_playing_widgets.dart
  ///
  /// In en, this message translates to:
  /// **'Pause'**
  String get nowPlayingPause;

  /// features/home/presentation/widgets/now_playing_widgets.dart
  ///
  /// In en, this message translates to:
  /// **'Play'**
  String get nowPlayingPlay;

  /// features/home/presentation/widgets/now_playing_widgets.dart
  ///
  /// In en, this message translates to:
  /// **'Next'**
  String get nowPlayingNext;

  /// features/home/presentation/widgets/now_playing_widgets.dart
  ///
  /// In en, this message translates to:
  /// **'Tap anywhere to close'**
  String get nowPlayingTapAnywhereToClose;

  /// features/home/presentation/widgets/now_playing_widgets.dart
  ///
  /// In en, this message translates to:
  /// **'Ooh, what\'s playing? I can hear it, but iPhone only shows me songs from Apple Music. Tell me what it is!'**
  String get nowPlayingOohWhatSPlayingI;

  /// features/home/presentation/widgets/now_playing_widgets.dart
  ///
  /// In en, this message translates to:
  /// **'Ooh, what\'s playing? Let me see your Apple Music and I\'ll show the song and the buttons here. Or just tell me what it is!'**
  String get nowPlayingOohWhatSPlayingLet;

  /// features/home/presentation/widgets/now_playing_widgets.dart
  ///
  /// In en, this message translates to:
  /// **'Ooh, what\'s playing? Let me see it and I\'ll show the song, the cover and the buttons here. Or just tell me what it is!'**
  String get nowPlayingOohWhatSPlayingLet2;

  /// features/home/presentation/widgets/now_playing_widgets.dart
  ///
  /// In en, this message translates to:
  /// **'Show my Apple Music'**
  String get nowPlayingShowMyAppleMusic;

  /// features/home/presentation/widgets/now_playing_widgets.dart
  ///
  /// In en, this message translates to:
  /// **'Allow'**
  String get nowPlayingAllow;

  /// features/home/presentation/widgets/now_playing_widgets.dart
  ///
  /// In en, this message translates to:
  /// **'Tell Chip'**
  String get nowPlayingTellChip;

  /// features/birthday/domain/birthday.dart
  ///
  /// In en, this message translates to:
  /// **'February'**
  String get birthdayFebruary;

  /// features/birthday/domain/birthday.dart
  ///
  /// In en, this message translates to:
  /// **'March'**
  String get birthdayMarch;

  /// features/birthday/domain/birthday.dart
  ///
  /// In en, this message translates to:
  /// **'April'**
  String get birthdayApril;

  /// features/birthday/domain/birthday.dart
  ///
  /// In en, this message translates to:
  /// **'May'**
  String get birthdayMay;

  /// features/birthday/domain/birthday.dart
  ///
  /// In en, this message translates to:
  /// **'June'**
  String get birthdayJune;

  /// features/birthday/domain/birthday.dart
  ///
  /// In en, this message translates to:
  /// **'July'**
  String get birthdayJuly;

  /// features/birthday/domain/birthday.dart
  ///
  /// In en, this message translates to:
  /// **'August'**
  String get birthdayAugust;

  /// features/birthday/domain/birthday.dart
  ///
  /// In en, this message translates to:
  /// **'September'**
  String get birthdaySeptember;

  /// features/birthday/domain/birthday.dart
  ///
  /// In en, this message translates to:
  /// **'October'**
  String get birthdayOctober;

  /// features/birthday/domain/birthday.dart
  ///
  /// In en, this message translates to:
  /// **'November'**
  String get birthdayNovember;

  /// features/birthday/domain/birthday.dart
  ///
  /// In en, this message translates to:
  /// **'December'**
  String get birthdayDecember;

  /// core/audio/sound_controls.dart
  ///
  /// In en, this message translates to:
  /// **'Sound'**
  String get soundControlsSound;

  /// core/audio/sound_controls.dart
  ///
  /// In en, this message translates to:
  /// **'Music'**
  String get soundControlsMusic;

  /// core/audio/sound_controls.dart
  ///
  /// In en, this message translates to:
  /// **'Dreamy loops in menus, upbeat in games'**
  String get soundControlsDreamyLoopsInMenusUpbeat;

  /// core/audio/sound_controls.dart
  ///
  /// In en, this message translates to:
  /// **'Sound effects'**
  String get soundControlsSoundEffects;

  /// core/audio/sound_controls.dart
  ///
  /// In en, this message translates to:
  /// **'Dice, hops, captures and reactions'**
  String get soundControlsDiceHopsCapturesAndReactions;

  /// core/audio/sound_controls.dart
  ///
  /// In en, this message translates to:
  /// **'Vibration'**
  String get soundControlsVibration;

  /// core/audio/sound_controls.dart
  ///
  /// In en, this message translates to:
  /// **'Dice, captures, your turn'**
  String get soundControlsDiceCapturesYourTurn;

  /// core/audio/sound_controls.dart
  ///
  /// In en, this message translates to:
  /// **'Sound settings'**
  String get soundControlsSoundSettings;

  /// features/rankings/domain/ranking.dart
  ///
  /// In en, this message translates to:
  /// **'Checkers'**
  String get rankingCheckers;

  /// features/rankings/domain/ranking.dart
  ///
  /// In en, this message translates to:
  /// **'Doodle'**
  String get rankingDoodle;

  /// features/rankings/domain/ranking.dart
  ///
  /// In en, this message translates to:
  /// **'Chess'**
  String get rankingChess;

  /// features/help/presentation/help_sheet.dart
  ///
  /// In en, this message translates to:
  /// **'Help & feedback'**
  String get helpHelpFeedback;

  /// features/help/presentation/help_sheet.dart
  ///
  /// In en, this message translates to:
  /// **'How to play'**
  String get helpHowToPlay;

  /// features/help/presentation/help_sheet.dart
  ///
  /// In en, this message translates to:
  /// **'The rules of every game'**
  String get helpTheRulesOfEveryGame;

  /// features/help/presentation/help_sheet.dart
  ///
  /// In en, this message translates to:
  /// **'Report a bug'**
  String get helpReportABug;

  /// features/help/presentation/help_sheet.dart
  ///
  /// In en, this message translates to:
  /// **'Something not working? We\'ll fix it'**
  String get helpSomethingNotWorkingWeLl;

  /// features/help/presentation/help_sheet.dart
  ///
  /// In en, this message translates to:
  /// **'Suggest a feature'**
  String get helpSuggestAFeature;

  /// features/help/presentation/help_sheet.dart
  ///
  /// In en, this message translates to:
  /// **'Ideas for games, worlds, anything'**
  String get helpIdeasForGamesWorldsAnything;

  /// features/auth/presentation/screens/auth_choice_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t start a guest game. Try again.'**
  String get authChoiceCouldnTStartAGuest;

  /// features/auth/presentation/screens/auth_choice_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Utopia'**
  String get authChoiceUtopia;

  /// features/auth/presentation/screens/auth_choice_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Games with friends,\nin a world that feels alive.'**
  String get authChoiceGamesWithFriendsInA;

  /// features/auth/presentation/screens/auth_choice_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Play now'**
  String get authChoicePlayNow;

  /// features/auth/presentation/screens/auth_choice_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Log in or sign up'**
  String get authChoiceLogInOrSignUp;

  /// features/auth/presentation/screens/auth_choice_screen.dart
  ///
  /// In en, this message translates to:
  /// **'No account needed. Save it any time.'**
  String get authChoiceNoAccountNeededSaveIt;

  /// features/auth/presentation/screens/auth_choice_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Privacy Policy'**
  String get authChoicePrivacyPolicy;

  /// app.dart
  ///
  /// In en, this message translates to:
  /// **'Dragon set complete. The dragon flies free.'**
  String get appDragonSetCompleteTheDragon;

  /// app.dart
  ///
  /// In en, this message translates to:
  /// **'Heaven set complete. The gates are open.'**
  String get appHeavenSetCompleteTheGates;

  /// app.dart
  ///
  /// In en, this message translates to:
  /// **'Hell set complete. Chip grew horns.'**
  String get appHellSetCompleteChipGrew;

  /// app.dart
  ///
  /// In en, this message translates to:
  /// **'Music set complete. Chip is on the decks.'**
  String get appMusicSetCompleteChipIs;

  /// app.dart
  ///
  /// In en, this message translates to:
  /// **'Halloween set complete. Chip got carved.'**
  String get appHalloweenSetCompleteChipGot;

  /// app.dart
  ///
  /// In en, this message translates to:
  /// **'Winter set complete. Chip wrapped up warm.'**
  String get appWinterSetCompleteChipWrapped;

  /// app.dart
  ///
  /// In en, this message translates to:
  /// **'Zombie set complete. Chip got bitten.'**
  String get appZombieSetCompleteChipGot;

  /// features/coins/presentation/daily_reward_sheet.dart
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t claim it just now. Try again.'**
  String get dailyRewardCouldnTClaimItJust;

  /// features/coins/presentation/daily_reward_sheet.dart
  ///
  /// In en, this message translates to:
  /// **'Daily reward'**
  String get dailyRewardDailyReward;

  /// features/coins/presentation/daily_reward_sheet.dart
  ///
  /// In en, this message translates to:
  /// **'Come back every day: the reward grows with your streak.'**
  String get dailyRewardComeBackEveryDayThe;

  /// features/coins/presentation/daily_reward_sheet.dart
  ///
  /// In en, this message translates to:
  /// **'Day {streak} in a row. Keep it going!'**
  String dailyRewardDayInARowKeep(Object streak);

  /// features/coins/presentation/daily_reward_sheet.dart
  ///
  /// In en, this message translates to:
  /// **'Claim {value} coins'**
  String dailyRewardClaimCoins(Object value);

  /// features/profile/presentation/screens/names_screen.dart
  ///
  /// In en, this message translates to:
  /// **'That name didn\'t work. Try another.'**
  String get namesThatNameDidnTWork;

  /// features/profile/presentation/screens/names_screen.dart
  ///
  /// In en, this message translates to:
  /// **'What should we call you?'**
  String get namesWhatShouldWeCallYou;

  /// features/profile/presentation/screens/names_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Your nickname is what everyone sees: write it any way you like. Your username is how friends find you.'**
  String get namesYourNicknameIsWhatEveryone;

  /// features/profile/presentation/screens/names_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get namesContinue;

  /// features/profile/domain/nickname_rules.dart
  ///
  /// In en, this message translates to:
  /// **'Hidden or text-flipping characters can\'t be used.'**
  String get nicknameRulesHiddenOrTextFlippingCharacters;

  /// features/profile/domain/nickname_rules.dart
  ///
  /// In en, this message translates to:
  /// **'At most 3 marks on one letter.'**
  String get nicknameRulesAtMost3MarksOn;

  /// features/profile/domain/nickname_rules.dart
  ///
  /// In en, this message translates to:
  /// **'Use at least 2 characters you can see.'**
  String get nicknameRulesUseAtLeast2Characters;

  /// features/profile/domain/nickname_rules.dart
  ///
  /// In en, this message translates to:
  /// **'Up to {max} characters.'**
  String nicknameRulesUpToCharacters(Object max);

  /// features/notifications/presentation/notification_actions.dart
  ///
  /// In en, this message translates to:
  /// **'Someone'**
  String get notificationActionsSomeone;

  /// features/notifications/presentation/notification_actions.dart
  ///
  /// In en, this message translates to:
  /// **'You and {value} are friends now'**
  String notificationActionsYouAndAreFriendsNow(Object value);

  /// features/notifications/presentation/notification_actions.dart
  ///
  /// In en, this message translates to:
  /// **'That request is no longer open.'**
  String get notificationActionsThatRequestIsNoLonger;

  /// features/notifications/presentation/notification_actions.dart
  ///
  /// In en, this message translates to:
  /// **'That challenge is no longer open.'**
  String get notificationActionsThatChallengeIsNoLonger;

  /// features/music/presentation/room_ears.dart
  ///
  /// In en, this message translates to:
  /// **'Let the Music world hear the room?'**
  String get roomEarsLetTheMusicWorldHear;

  /// features/music/presentation/room_ears.dart
  ///
  /// In en, this message translates to:
  /// **'Play music, sing or clap, and the show dances to it: the lights, the lasers, the speakers and the crowd. It only listens for how loud it is and where the beat is. Nothing is recorded or sent anywhere. Turn it off any time in Settings.'**
  String get roomEarsPlayMusicSingOrClap;

  /// features/music/presentation/room_ears.dart
  ///
  /// In en, this message translates to:
  /// **'Turn it on'**
  String get roomEarsTurnItOn;

  /// features/music/presentation/room_ears.dart
  ///
  /// In en, this message translates to:
  /// **'Not now'**
  String get roomEarsNotNow;

  /// features/auth/presentation/widgets/game_fan.dart
  ///
  /// In en, this message translates to:
  /// **'Chess'**
  String get gameFanChess;

  /// features/auth/presentation/widgets/game_fan.dart
  ///
  /// In en, this message translates to:
  /// **'Ludo'**
  String get gameFanLudo;

  /// features/auth/presentation/widgets/game_fan.dart
  ///
  /// In en, this message translates to:
  /// **'Checkers'**
  String get gameFanCheckers;

  /// features/auth/presentation/widgets/game_fan.dart
  ///
  /// In en, this message translates to:
  /// **'Doodle'**
  String get gameFanDoodle;

  /// features/invites/presentation/join_invite_screen.dart
  ///
  /// In en, this message translates to:
  /// **'That invite link doesn\'t work. Ask your friend for the code.'**
  String get joinInviteThatInviteLinkDoesnT;

  /// features/invites/presentation/join_invite_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Joining {value}'**
  String joinInviteJoining(Object value);

  /// features/invites/presentation/join_invite_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Go home'**
  String get joinInviteGoHome;

  /// features/friends/presentation/widgets/invite_stake_sheet.dart
  ///
  /// In en, this message translates to:
  /// **'Chess'**
  String get inviteStakeChess;

  /// features/friends/presentation/widgets/invite_stake_sheet.dart
  ///
  /// In en, this message translates to:
  /// **'Checkers'**
  String get inviteStakeCheckers;

  /// features/friends/presentation/widgets/invite_stake_sheet.dart
  ///
  /// In en, this message translates to:
  /// **'Send challenge'**
  String get inviteStakeSendChallenge;

  /// features/birthday/presentation/birthday_party.dart
  ///
  /// In en, this message translates to:
  /// **'Happy birthday, {name}!'**
  String birthdayPartyHappyBirthday(Object name);

  /// features/birthday/presentation/birthday_party.dart
  ///
  /// In en, this message translates to:
  /// **'Your own birthday world is open all day, and you\'re wearing the Birthday Party frame. Only on your birthday, only for you.'**
  String get birthdayPartyYourOwnBirthdayWorldIs;

  /// features/birthday/presentation/birthday_party.dart
  ///
  /// In en, this message translates to:
  /// **'Let\'s party!'**
  String get birthdayPartyLetSParty;

  /// core/widgets/web_update_banner.dart
  ///
  /// In en, this message translates to:
  /// **'A new version of Utopia is ready.'**
  String get webUpdateBannerANewVersionOfUtopia;

  /// core/widgets/web_update_banner.dart
  ///
  /// In en, this message translates to:
  /// **'Refresh'**
  String get webUpdateBannerRefresh;

  /// core/widgets/web_update_banner.dart
  ///
  /// In en, this message translates to:
  /// **'Later'**
  String get webUpdateBannerLater;

  /// core/widgets/entry_selector.dart
  ///
  /// In en, this message translates to:
  /// **'Free'**
  String get entrySelectorFree;

  /// core/widgets/entry_selector.dart
  ///
  /// In en, this message translates to:
  /// **'Just for fun'**
  String get entrySelectorJustForFun;

  /// core/widgets/entry_selector.dart
  ///
  /// In en, this message translates to:
  /// **'Winner gets '**
  String get entrySelectorWinnerGets;

  /// features/notifications/presentation/answer_buttons.dart
  ///
  /// In en, this message translates to:
  /// **'Decline'**
  String get answerButtonsDecline;

  /// features/friends/presentation/widgets/online_bubble.dart
  ///
  /// In en, this message translates to:
  /// **'Online'**
  String get onlineBubbleOnline;

  /// features/friends/presentation/widgets/online_bubble.dart
  ///
  /// In en, this message translates to:
  /// **'Offline'**
  String get onlineBubbleOffline;

  /// features/events/domain/game_event.dart
  ///
  /// In en, this message translates to:
  /// **'Last day'**
  String get gameEventLastDay;

  /// features/events/domain/game_event.dart
  ///
  /// In en, this message translates to:
  /// **'{days} day{value} left'**
  String gameEventDayLeft(Object days, Object value);

  /// core/widgets/quiet_lobby_offer.dart
  ///
  /// In en, this message translates to:
  /// **'It\'s quiet right now'**
  String get quietLobbyOfferItSQuietRightNow;

  /// core/widgets/quiet_lobby_offer.dart
  ///
  /// In en, this message translates to:
  /// **'We\'ll keep looking. Or play a free game offline while more players come online.'**
  String get quietLobbyOfferWeLlKeepLookingOr;

  /// core/widgets/bouncy_dialog.dart
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get bouncyClose;

  /// core/profiles/profile_repository.dart
  ///
  /// In en, this message translates to:
  /// **'Player {tag}'**
  String profilePlayer(Object tag);

  /// features/notifications/presentation/notification_bell.dart
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get notificationBellNotifications;

  /// features/friends/presentation/widgets/friend_icon_button.dart
  ///
  /// In en, this message translates to:
  /// **'Friends'**
  String get friendIconButtonFriends;

  /// features/auth/presentation/screens/splash_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Utopia'**
  String get splashUtopia;

  /// core/widgets/share_invite.dart
  ///
  /// In en, this message translates to:
  /// **'Invite copied. Paste it to a friend.'**
  String get shareInviteInviteCopiedPasteItTo;

  /// core/widgets/coin_balance_pill.dart
  ///
  /// In en, this message translates to:
  /// **'Coins. Tap to get more.'**
  String get coinBalancePillCoinsTapToGetMore;

  /// core/theme/utopia_themes.dart
  ///
  /// In en, this message translates to:
  /// **'Utopia Twilight'**
  String get utopiaThemesUtopiaTwilight;

  /// core/theme/utopia_themes.dart
  ///
  /// In en, this message translates to:
  /// **'Utopia'**
  String get utopiaThemesUtopia;

  /// core/theme/utopia_themes.dart
  ///
  /// In en, this message translates to:
  /// **'Twilight islands floating over a sea of clouds.'**
  String get utopiaThemesTwilightIslandsFloatingOverA;

  /// core/theme/utopia_themes.dart
  ///
  /// In en, this message translates to:
  /// **'Noir'**
  String get utopiaThemesNoir;

  /// core/theme/utopia_themes.dart
  ///
  /// In en, this message translates to:
  /// **'Pure black, pure white. Nothing in between.'**
  String get utopiaThemesPureBlackPureWhiteNothing;

  /// core/theme/utopia_themes.dart
  ///
  /// In en, this message translates to:
  /// **'Utopia Calm'**
  String get utopiaThemesUtopiaCalm;

  /// core/theme/utopia_themes.dart
  ///
  /// In en, this message translates to:
  /// **'A glassy ocean at dusk. Breathe in.'**
  String get utopiaThemesAGlassyOceanAtDusk;

  /// core/theme/utopia_themes.dart
  ///
  /// In en, this message translates to:
  /// **'Utopia Adventure'**
  String get utopiaThemesUtopiaAdventure;

  /// core/theme/utopia_themes.dart
  ///
  /// In en, this message translates to:
  /// **'Peaks, floating rocks and a balloon to chase.'**
  String get utopiaThemesPeaksFloatingRocksAndA;

  /// core/theme/utopia_themes.dart
  ///
  /// In en, this message translates to:
  /// **'Utopia Warm'**
  String get utopiaThemesUtopiaWarm;

  /// core/theme/utopia_themes.dart
  ///
  /// In en, this message translates to:
  /// **'Golden dunes and a sky full of lanterns.'**
  String get utopiaThemesGoldenDunesAndASky;

  /// core/theme/utopia_themes.dart
  ///
  /// In en, this message translates to:
  /// **'Utopia Alien'**
  String get utopiaThemesUtopiaAlien;

  /// core/theme/utopia_themes.dart
  ///
  /// In en, this message translates to:
  /// **'Glowing mushrooms, two moons and something in the sky.'**
  String get utopiaThemesGlowingMushroomsTwoMoonsAnd;

  /// core/theme/utopia_themes.dart
  ///
  /// In en, this message translates to:
  /// **'Utopia Tech'**
  String get utopiaThemesUtopiaTech;

  /// core/theme/utopia_themes.dart
  ///
  /// In en, this message translates to:
  /// **'A neon city that never sleeps, over a glowing grid.'**
  String get utopiaThemesANeonCityThatNever;

  /// core/theme/utopia_themes.dart
  ///
  /// In en, this message translates to:
  /// **'Utopia Anime'**
  String get utopiaThemesUtopiaAnime;

  /// core/theme/utopia_themes.dart
  ///
  /// In en, this message translates to:
  /// **'Cherry blossoms, a quiet shrine and a mountain at dusk.'**
  String get utopiaThemesCherryBlossomsAQuietShrine;

  /// core/theme/utopia_themes.dart
  ///
  /// In en, this message translates to:
  /// **'Utopia Dojo'**
  String get utopiaThemesUtopiaDojo;

  /// core/theme/utopia_themes.dart
  ///
  /// In en, this message translates to:
  /// **'A samurai castle at sunset, shadow fighters sparring and a dragon circling the sky.'**
  String get utopiaThemesASamuraiCastleAtSunset;

  /// core/theme/utopia_themes.dart
  ///
  /// In en, this message translates to:
  /// **'Utopia Zombie'**
  String get utopiaThemesUtopiaZombie;

  /// core/theme/utopia_themes.dart
  ///
  /// In en, this message translates to:
  /// **'A graveyard under a sick green moon, where the dead never stay down for long.'**
  String get utopiaThemesAGraveyardUnderASick;

  /// core/theme/utopia_themes.dart
  ///
  /// In en, this message translates to:
  /// **'Utopia Heaven'**
  String get utopiaThemesUtopiaHeaven;

  /// core/theme/utopia_themes.dart
  ///
  /// In en, this message translates to:
  /// **'Pearly gates above the clouds, where the light never sets.'**
  String get utopiaThemesPearlyGatesAboveTheClouds;

  /// core/theme/utopia_themes.dart
  ///
  /// In en, this message translates to:
  /// **'Utopia Hell'**
  String get utopiaThemesUtopiaHell;

  /// core/theme/utopia_themes.dart
  ///
  /// In en, this message translates to:
  /// **'A sea of fire under a blood moon. Something is watching.'**
  String get utopiaThemesASeaOfFireUnder;

  /// core/theme/utopia_themes.dart
  ///
  /// In en, this message translates to:
  /// **'Utopia Music'**
  String get utopiaThemesUtopiaMusic;

  /// core/theme/utopia_themes.dart
  ///
  /// In en, this message translates to:
  /// **'The show never ends. Lasers up, bass down, hands in the air.'**
  String get utopiaThemesTheShowNeverEndsLasers;

  /// core/theme/utopia_themes.dart
  ///
  /// In en, this message translates to:
  /// **'Utopia Halloween'**
  String get utopiaThemesUtopiaHalloween;

  /// core/theme/utopia_themes.dart
  ///
  /// In en, this message translates to:
  /// **'All Hallows\' Eve, every night. Don\'t look at the tower window.'**
  String get utopiaThemesAllHallowsEveEveryNight;

  /// core/theme/utopia_themes.dart
  ///
  /// In en, this message translates to:
  /// **'Utopia Winter'**
  String get utopiaThemesUtopiaWinter;

  /// core/theme/utopia_themes.dart
  ///
  /// In en, this message translates to:
  /// **'Snow on a cabin by a frozen lake. Listen for sleigh bells.'**
  String get utopiaThemesSnowOnACabinBy;

  /// core/theme/utopia_themes.dart
  ///
  /// In en, this message translates to:
  /// **'Your Birthday'**
  String get utopiaThemesYourBirthday;

  /// core/theme/utopia_themes.dart
  ///
  /// In en, this message translates to:
  /// **'A party in the sky, just for you. Happy birthday!'**
  String get utopiaThemesAPartyInTheSky;

  /// core/theme/utopia_themes.dart
  ///
  /// In en, this message translates to:
  /// **'Utopia Doodle'**
  String get utopiaThemesUtopiaDoodle;

  /// core/theme/utopia_themes.dart
  ///
  /// In en, this message translates to:
  /// **'Everything drawn in ink on paper, and still alive.'**
  String get utopiaThemesEverythingDrawnInInkOn;

  /// core/theme/utopia_themes.dart
  ///
  /// In en, this message translates to:
  /// **'Utopia Deep'**
  String get utopiaThemesUtopiaDeep;

  /// core/theme/utopia_themes.dart
  ///
  /// In en, this message translates to:
  /// **'Down under the waves, where the light comes in shafts.'**
  String get utopiaThemesDownUnderTheWavesWhere;

  /// core/theme/utopia_themes.dart
  ///
  /// In en, this message translates to:
  /// **'Ruby'**
  String get utopiaThemesRuby;

  /// core/theme/utopia_themes.dart
  ///
  /// In en, this message translates to:
  /// **'Molten ridges'**
  String get utopiaThemesMoltenRidges;

  /// core/theme/utopia_themes.dart
  ///
  /// In en, this message translates to:
  /// **'Ember'**
  String get utopiaThemesEmber;

  /// core/theme/utopia_themes.dart
  ///
  /// In en, this message translates to:
  /// **'Copper dunes'**
  String get utopiaThemesCopperDunes;

  /// core/theme/utopia_themes.dart
  ///
  /// In en, this message translates to:
  /// **'Sunbeam'**
  String get utopiaThemesSunbeam;

  /// core/theme/utopia_themes.dart
  ///
  /// In en, this message translates to:
  /// **'Honey skies'**
  String get utopiaThemesHoneySkies;

  /// core/theme/utopia_themes.dart
  ///
  /// In en, this message translates to:
  /// **'Jade'**
  String get utopiaThemesJade;

  /// core/theme/utopia_themes.dart
  ///
  /// In en, this message translates to:
  /// **'Emerald isles'**
  String get utopiaThemesEmeraldIsles;

  /// core/theme/utopia_themes.dart
  ///
  /// In en, this message translates to:
  /// **'Lagoon'**
  String get utopiaThemesLagoon;

  /// core/theme/utopia_themes.dart
  ///
  /// In en, this message translates to:
  /// **'Teal shallows'**
  String get utopiaThemesTealShallows;

  /// core/theme/utopia_themes.dart
  ///
  /// In en, this message translates to:
  /// **'Azure'**
  String get utopiaThemesAzure;

  /// core/theme/utopia_themes.dart
  ///
  /// In en, this message translates to:
  /// **'Open sea'**
  String get utopiaThemesOpenSea;

  /// core/theme/utopia_themes.dart
  ///
  /// In en, this message translates to:
  /// **'Sapphire'**
  String get utopiaThemesSapphire;

  /// core/theme/utopia_themes.dart
  ///
  /// In en, this message translates to:
  /// **'Deep blue'**
  String get utopiaThemesDeepBlue;

  /// core/theme/utopia_themes.dart
  ///
  /// In en, this message translates to:
  /// **'Amethyst'**
  String get utopiaThemesAmethyst;

  /// core/theme/utopia_themes.dart
  ///
  /// In en, this message translates to:
  /// **'Violet isles'**
  String get utopiaThemesVioletIsles;

  /// core/theme/utopia_themes.dart
  ///
  /// In en, this message translates to:
  /// **'Blossom'**
  String get utopiaThemesBlossom;

  /// core/theme/utopia_themes.dart
  ///
  /// In en, this message translates to:
  /// **'Cherry clouds'**
  String get utopiaThemesCherryClouds;

  /// core/theme/utopia_themes.dart
  ///
  /// In en, this message translates to:
  /// **'Rose Gold'**
  String get utopiaThemesRoseGold;

  /// core/theme/utopia_themes.dart
  ///
  /// In en, this message translates to:
  /// **'Rosy sands'**
  String get utopiaThemesRosySands;

  /// core/theme/utopia_themes.dart
  ///
  /// In en, this message translates to:
  /// **'Onyx'**
  String get utopiaThemesOnyx;

  /// core/theme/utopia_themes.dart
  ///
  /// In en, this message translates to:
  /// **'Obsidian peaks'**
  String get utopiaThemesObsidianPeaks;

  /// core/theme/utopia_themes.dart
  ///
  /// In en, this message translates to:
  /// **'Pearl'**
  String get utopiaThemesPearl;

  /// core/theme/utopia_themes.dart
  ///
  /// In en, this message translates to:
  /// **'Moonlit snow'**
  String get utopiaThemesMoonlitSnow;

  /// features/auras/domain/aura.dart
  ///
  /// In en, this message translates to:
  /// **'Common'**
  String get auraCommon;

  /// features/auras/domain/aura.dart
  ///
  /// In en, this message translates to:
  /// **'Rare'**
  String get auraRare;

  /// features/auras/domain/aura.dart
  ///
  /// In en, this message translates to:
  /// **'Legendary'**
  String get auraLegendary;

  /// features/auras/domain/aura.dart
  ///
  /// In en, this message translates to:
  /// **'Mythic'**
  String get auraMythic;

  /// features/auras/domain/aura.dart
  ///
  /// In en, this message translates to:
  /// **'3 days'**
  String get aura3Days;

  /// features/auras/domain/aura.dart
  ///
  /// In en, this message translates to:
  /// **'1 week'**
  String get aura1Week;

  /// features/auras/domain/aura.dart
  ///
  /// In en, this message translates to:
  /// **'1 month'**
  String get aura1Month;

  /// features/auras/domain/aura.dart
  ///
  /// In en, this message translates to:
  /// **'Dragon Coil'**
  String get auraDragonCoil;

  /// features/auras/domain/aura.dart
  ///
  /// In en, this message translates to:
  /// **'A dragon wound round your picture, breathing fire. In the Dojo world, it flies free and Chip squares up to it.'**
  String get auraADragonWoundRoundYour;

  /// features/auras/domain/aura.dart
  ///
  /// In en, this message translates to:
  /// **'Crimson Fury'**
  String get auraCrimsonFury;

  /// features/auras/domain/aura.dart
  ///
  /// In en, this message translates to:
  /// **'Red lightning, a roaring fire vortex and shockwaves. Pure fury.'**
  String get auraRedLightningARoaringFire;

  /// features/auras/domain/aura.dart
  ///
  /// In en, this message translates to:
  /// **'Supernova'**
  String get auraSupernova;

  /// features/auras/domain/aura.dart
  ///
  /// In en, this message translates to:
  /// **'A star exploding around you, over and over.'**
  String get auraAStarExplodingAroundYou;

  /// features/auras/domain/aura.dart
  ///
  /// In en, this message translates to:
  /// **'Event Horizon'**
  String get auraEventHorizon;

  /// features/auras/domain/aura.dart
  ///
  /// In en, this message translates to:
  /// **'A black hole with a blazing disk, pulling the light in.'**
  String get auraABlackHoleWithA;

  /// features/auras/domain/aura.dart
  ///
  /// In en, this message translates to:
  /// **'Frostfire'**
  String get auraFrostfire;

  /// features/auras/domain/aura.dart
  ///
  /// In en, this message translates to:
  /// **'Ice and fire chasing each other round. Sparks where they meet.'**
  String get auraIceAndFireChasingEach;

  /// features/auras/domain/aura.dart
  ///
  /// In en, this message translates to:
  /// **'Ring of Fire'**
  String get auraRingOfFire;

  /// features/auras/domain/aura.dart
  ///
  /// In en, this message translates to:
  /// **'A blazing ring of fire, spinning all around you.'**
  String get auraABlazingRingOfFire;

  /// features/auras/domain/aura.dart
  ///
  /// In en, this message translates to:
  /// **'Zombie Bite'**
  String get auraZombieBite;

  /// features/auras/domain/aura.dart
  ///
  /// In en, this message translates to:
  /// **'Rotting hands claw up to grab you. Something took a bite. In the Zombie world, Chip gets bitten too.'**
  String get auraRottingHandsClawUpTo;

  /// features/auras/domain/aura.dart
  ///
  /// In en, this message translates to:
  /// **'Encore'**
  String get auraEncore;

  /// features/auras/domain/aura.dart
  ///
  /// In en, this message translates to:
  /// **'Your picture on a spinning record, an equalizer jumping all around it on the beat. In the Music world, Chip takes the decks.'**
  String get auraYourPictureOnASpinning;

  /// features/auras/domain/aura.dart
  ///
  /// In en, this message translates to:
  /// **'Jack\'s Lantern'**
  String get auraJackSLantern;

  /// features/auras/domain/aura.dart
  ///
  /// In en, this message translates to:
  /// **'Black brambles round your picture, grinning jack-o\'-lanterns on the rim, a spider on its web and bats circling. In the Halloween world, Chip gets carved.'**
  String get auraBlackBramblesRoundYourPicture;

  /// features/auras/domain/aura.dart
  ///
  /// In en, this message translates to:
  /// **'Snow Globe'**
  String get auraSnowGlobe;

  /// features/auras/domain/aura.dart
  ///
  /// In en, this message translates to:
  /// **'Your picture sealed in a snow globe on a polished stand, the snow swirling up round you every time it\'s shaken. In the Winter world, Chip wraps up warm.'**
  String get auraYourPictureSealedInA;

  /// features/auras/domain/aura.dart
  ///
  /// In en, this message translates to:
  /// **'Inferno'**
  String get auraInferno;

  /// features/auras/domain/aura.dart
  ///
  /// In en, this message translates to:
  /// **'A frame of lava running down both sides, flames trying to catch, obsidian horns and tail. In the Hell world, Chip grows horns.'**
  String get auraAFrameOfLavaRunning;

  /// features/auras/domain/aura.dart
  ///
  /// In en, this message translates to:
  /// **'Phoenix'**
  String get auraPhoenix;

  /// features/auras/domain/aura.dart
  ///
  /// In en, this message translates to:
  /// **'Wings of flame that beat behind you.'**
  String get auraWingsOfFlameThatBeat;

  /// features/auras/domain/aura.dart
  ///
  /// In en, this message translates to:
  /// **'Galaxy'**
  String get auraGalaxy;

  /// features/auras/domain/aura.dart
  ///
  /// In en, this message translates to:
  /// **'A spiral of stars turning around you.'**
  String get auraASpiralOfStarsTurning;

  /// features/auras/domain/aura.dart
  ///
  /// In en, this message translates to:
  /// **'Shadow Flame'**
  String get auraShadowFlame;

  /// features/auras/domain/aura.dart
  ///
  /// In en, this message translates to:
  /// **'Dark fire with a glowing green heart.'**
  String get auraDarkFireWithAGlowing;

  /// features/auras/domain/aura.dart
  ///
  /// In en, this message translates to:
  /// **'Violet Storm'**
  String get auraVioletStorm;

  /// features/auras/domain/aura.dart
  ///
  /// In en, this message translates to:
  /// **'Purple lightning crackling all around you.'**
  String get auraPurpleLightningCracklingAllAround;

  /// features/auras/domain/aura.dart
  ///
  /// In en, this message translates to:
  /// **'White Storm'**
  String get auraWhiteStorm;

  /// features/auras/domain/aura.dart
  ///
  /// In en, this message translates to:
  /// **'White lightning crackling all around you.'**
  String get auraWhiteLightningCracklingAllAround;

  /// features/auras/domain/aura.dart
  ///
  /// In en, this message translates to:
  /// **'Blue Storm'**
  String get auraBlueStorm;

  /// features/auras/domain/aura.dart
  ///
  /// In en, this message translates to:
  /// **'Electric blue bolts, never still.'**
  String get auraElectricBlueBoltsNeverStill;

  /// features/auras/domain/aura.dart
  ///
  /// In en, this message translates to:
  /// **'Emerald Storm'**
  String get auraEmeraldStorm;

  /// features/auras/domain/aura.dart
  ///
  /// In en, this message translates to:
  /// **'Green lightning with a wild streak.'**
  String get auraGreenLightningWithAWild;

  /// features/auras/domain/aura.dart
  ///
  /// In en, this message translates to:
  /// **'Golden Storm'**
  String get auraGoldenStorm;

  /// features/auras/domain/aura.dart
  ///
  /// In en, this message translates to:
  /// **'Gold bolts, like a crown of thunder.'**
  String get auraGoldBoltsLikeACrown;

  /// features/auras/domain/aura.dart
  ///
  /// In en, this message translates to:
  /// **'Pink Storm'**
  String get auraPinkStorm;

  /// features/auras/domain/aura.dart
  ///
  /// In en, this message translates to:
  /// **'Hot pink lightning that never calms down.'**
  String get auraHotPinkLightningThatNever;

  /// features/auras/domain/aura.dart
  ///
  /// In en, this message translates to:
  /// **'Sunburst'**
  String get auraSunburst;

  /// features/auras/domain/aura.dart
  ///
  /// In en, this message translates to:
  /// **'Golden rays turning slowly, like a sunrise.'**
  String get auraGoldenRaysTurningSlowlyLike;

  /// features/auras/domain/aura.dart
  ///
  /// In en, this message translates to:
  /// **'Prism'**
  String get auraPrism;

  /// features/auras/domain/aura.dart
  ///
  /// In en, this message translates to:
  /// **'A rainbow ring that never stops turning.'**
  String get auraARainbowRingThatNever;

  /// features/auras/domain/aura.dart
  ///
  /// In en, this message translates to:
  /// **'Orbit'**
  String get auraOrbit;

  /// features/auras/domain/aura.dart
  ///
  /// In en, this message translates to:
  /// **'Little planets circling your picture.'**
  String get auraLittlePlanetsCirclingYourPicture;

  /// features/auras/domain/aura.dart
  ///
  /// In en, this message translates to:
  /// **'Neon Pulse'**
  String get auraNeonPulse;

  /// features/auras/domain/aura.dart
  ///
  /// In en, this message translates to:
  /// **'Two neon rings racing opposite ways.'**
  String get auraTwoNeonRingsRacingOpposite;

  /// features/auras/domain/aura.dart
  ///
  /// In en, this message translates to:
  /// **'Tidal'**
  String get auraTidal;

  /// features/auras/domain/aura.dart
  ///
  /// In en, this message translates to:
  /// **'Waves rolling around you, splashing as they go.'**
  String get auraWavesRollingAroundYouSplashing;

  /// features/auras/domain/aura.dart
  ///
  /// In en, this message translates to:
  /// **'Angel Halo'**
  String get auraAngelHalo;

  /// features/auras/domain/aura.dart
  ///
  /// In en, this message translates to:
  /// **'A golden halo and feathers drifting down. In the Heaven world, Chip gets his wings.'**
  String get auraAGoldenHaloAndFeathers;

  /// features/auras/domain/aura.dart
  ///
  /// In en, this message translates to:
  /// **'Bubble Ring'**
  String get auraBubbleRing;

  /// features/auras/domain/aura.dart
  ///
  /// In en, this message translates to:
  /// **'Soap bubbles drifting up and away.'**
  String get auraSoapBubblesDriftingUpAnd;

  /// features/auras/domain/aura.dart
  ///
  /// In en, this message translates to:
  /// **'Sakura'**
  String get auraSakura;

  /// features/auras/domain/aura.dart
  ///
  /// In en, this message translates to:
  /// **'Cherry petals dancing in a circle.'**
  String get auraCherryPetalsDancingInA;

  /// features/auras/domain/aura.dart
  ///
  /// In en, this message translates to:
  /// **'Frost'**
  String get auraFrost;

  /// features/auras/domain/aura.dart
  ///
  /// In en, this message translates to:
  /// **'Ice crystals and a cool blue shimmer.'**
  String get auraIceCrystalsAndACool;

  /// features/auras/domain/aura.dart
  ///
  /// In en, this message translates to:
  /// **'Lovestruck'**
  String get auraLovestruck;

  /// features/auras/domain/aura.dart
  ///
  /// In en, this message translates to:
  /// **'Hearts circling you, beating as they go.'**
  String get auraHeartsCirclingYouBeatingAs;

  /// features/auras/domain/aura.dart
  ///
  /// In en, this message translates to:
  /// **'Fireflies'**
  String get auraFireflies;

  /// features/auras/domain/aura.dart
  ///
  /// In en, this message translates to:
  /// **'Little lights wandering around you at dusk.'**
  String get auraLittleLightsWanderingAroundYou;

  /// features/auras/domain/aura.dart
  ///
  /// In en, this message translates to:
  /// **'Starlight'**
  String get auraStarlight;

  /// features/auras/domain/aura.dart
  ///
  /// In en, this message translates to:
  /// **'Stars twinkling all around your picture.'**
  String get auraStarsTwinklingAllAroundYour;

  /// features/auras/domain/aura.dart
  ///
  /// In en, this message translates to:
  /// **'Autumn Leaves'**
  String get auraAutumnLeaves;

  /// features/auras/domain/aura.dart
  ///
  /// In en, this message translates to:
  /// **'Golden leaves swirling on the wind.'**
  String get auraGoldenLeavesSwirlingOnThe;

  /// features/auras/domain/aura.dart
  ///
  /// In en, this message translates to:
  /// **'Maestro'**
  String get auraMaestro;

  /// features/auras/domain/aura.dart
  ///
  /// In en, this message translates to:
  /// **'A ring of wet paint, with a brush painting around you.'**
  String get auraARingOfWetPaint;

  /// features/auras/domain/aura.dart
  ///
  /// In en, this message translates to:
  /// **'Chip Maestro'**
  String get auraChipMaestro;

  /// features/auras/domain/aura.dart
  ///
  /// In en, this message translates to:
  /// **'Birthday Party'**
  String get auraBirthdayParty;

  /// features/auras/domain/aura.dart
  ///
  /// In en, this message translates to:
  /// **'A ribbon in every color, a party hat, balloons and a little cake. Only on your birthday.'**
  String get auraARibbonInEveryColor;

  /// features/auras/domain/aura.dart
  ///
  /// In en, this message translates to:
  /// **'Expired'**
  String get auraExpired;

  /// features/auras/domain/aura.dart
  ///
  /// In en, this message translates to:
  /// **'{inDays}d {value}h left'**
  String auraDHLeft(Object inDays, Object value);

  /// features/auras/domain/aura.dart
  ///
  /// In en, this message translates to:
  /// **'{inHours}h {value}m left'**
  String auraHMLeft(Object inHours, Object value);

  /// features/auras/domain/aura.dart
  ///
  /// In en, this message translates to:
  /// **'{value}m left'**
  String auraMLeft(Object value);

  /// features/chip/presentation/chip_chat_sheet.dart
  ///
  /// In en, this message translates to:
  /// **'Turn my photo into a coloring page'**
  String get chipChatTurnMyPhotoIntoA;

  /// features/chip/presentation/chip_chat_sheet.dart
  ///
  /// In en, this message translates to:
  /// **'Tell me a joke'**
  String get chipChatTellMeAJoke;

  /// features/chip/presentation/chip_chat_sheet.dart
  ///
  /// In en, this message translates to:
  /// **'Which world should I try?'**
  String get chipChatWhichWorldShouldITry;

  /// features/chip/presentation/chip_chat_sheet.dart
  ///
  /// In en, this message translates to:
  /// **'How do I play Ludo?'**
  String get chipChatHowDoIPlayLudo;

  /// features/chip/presentation/chip_chat_sheet.dart
  ///
  /// In en, this message translates to:
  /// **'Help me with my homework'**
  String get chipChatHelpMeWithMyHomework;

  /// features/chip/presentation/chip_chat_sheet.dart
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t open that photo.'**
  String get chipChatCouldnTOpenThatPhoto;

  /// features/chip/presentation/chip_chat_sheet.dart
  ///
  /// In en, this message translates to:
  /// **'That picture isn\'t ready to color yet.'**
  String get chipChatThatPictureIsnTReady;

  /// features/chip/presentation/chip_chat_sheet.dart
  ///
  /// In en, this message translates to:
  /// **'your photo'**
  String get chipChatYourPhoto;

  /// features/chip/presentation/chip_chat_sheet.dart
  ///
  /// In en, this message translates to:
  /// **'Your free real portrait'**
  String get chipChatYourFreeRealPortrait;

  /// features/chip/presentation/chip_chat_sheet.dart
  ///
  /// In en, this message translates to:
  /// **'Chip has a photo-quality coloring page made that looks just like {who}. Your first one is free; after that, real portraits come with Chip Maestro.'**
  String chipChatChipHasAPhotoQuality(Object who);

  /// features/chip/presentation/chip_chat_sheet.dart
  ///
  /// In en, this message translates to:
  /// **'Not now'**
  String get chipChatNotNow;

  /// features/chip/presentation/chip_chat_sheet.dart
  ///
  /// In en, this message translates to:
  /// **'Draw it free'**
  String get chipChatDrawItFree;

  /// features/chip/presentation/chip_chat_sheet.dart
  ///
  /// In en, this message translates to:
  /// **'That\'s this month\'s real portraits. More when your plan renews!'**
  String get chipChatThatSThisMonthS;

  /// features/chip/presentation/chip_chat_sheet.dart
  ///
  /// In en, this message translates to:
  /// **'That\'s all the real portraits for today. More tomorrow!'**
  String get chipChatThatSAllTheReal;

  /// features/chip/presentation/chip_chat_sheet.dart
  ///
  /// In en, this message translates to:
  /// **'Real portraits are coming soon.'**
  String get chipChatRealPortraitsAreComingSoon;

  /// features/chip/presentation/chip_chat_sheet.dart
  ///
  /// In en, this message translates to:
  /// **'Send Chip the photo again first.'**
  String get chipChatSendChipThePhotoAgain;

  /// features/chip/presentation/chip_chat_sheet.dart
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t start the portrait. Try again?'**
  String get chipChatCouldnTStartThePortrait;

  /// features/chip/presentation/chip_chat_sheet.dart
  ///
  /// In en, this message translates to:
  /// **'Start a new chat?'**
  String get chipChatStartANewChat;

  /// features/chip/presentation/chip_chat_sheet.dart
  ///
  /// In en, this message translates to:
  /// **'Chip will forget this conversation.'**
  String get chipChatChipWillForgetThisConversation;

  /// features/chip/presentation/chip_chat_sheet.dart
  ///
  /// In en, this message translates to:
  /// **'Keep it'**
  String get chipChatKeepIt;

  /// features/chip/presentation/chip_chat_sheet.dart
  ///
  /// In en, this message translates to:
  /// **'New chat'**
  String get chipChatNewChat;

  /// features/chip/presentation/chip_chat_sheet.dart
  ///
  /// In en, this message translates to:
  /// **'Open the Store'**
  String get chipChatOpenTheStore;

  /// features/chip/presentation/chip_chat_sheet.dart
  ///
  /// In en, this message translates to:
  /// **'See auras'**
  String get chipChatSeeAuras;

  /// features/chip/presentation/chip_chat_sheet.dart
  ///
  /// In en, this message translates to:
  /// **'Change world'**
  String get chipChatChangeWorld;

  /// features/chip/presentation/chip_chat_sheet.dart
  ///
  /// In en, this message translates to:
  /// **'Get coins'**
  String get chipChatGetCoins;

  /// features/chip/presentation/chip_chat_sheet.dart
  ///
  /// In en, this message translates to:
  /// **'Open Friends'**
  String get chipChatOpenFriends;

  /// features/chip/presentation/chip_chat_sheet.dart
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get chipChatNotifications;

  /// features/chip/presentation/chip_chat_sheet.dart
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get chipChatSettings;

  /// features/chip/presentation/chip_chat_sheet.dart
  ///
  /// In en, this message translates to:
  /// **'Your profile'**
  String get chipChatYourProfile;

  /// features/chip/presentation/chip_chat_sheet.dart
  ///
  /// In en, this message translates to:
  /// **'Open the Sketchbook'**
  String get chipChatOpenTheSketchbook;

  /// features/chip/presentation/chip_chat_sheet.dart
  ///
  /// In en, this message translates to:
  /// **'How to play chess'**
  String get chipChatHowToPlayChess;

  /// features/chip/presentation/chip_chat_sheet.dart
  ///
  /// In en, this message translates to:
  /// **'How to play checkers'**
  String get chipChatHowToPlayCheckers;

  /// features/chip/presentation/chip_chat_sheet.dart
  ///
  /// In en, this message translates to:
  /// **'How to play Ludo'**
  String get chipChatHowToPlayLudo;

  /// features/chip/presentation/chip_chat_sheet.dart
  ///
  /// In en, this message translates to:
  /// **'Play chess'**
  String get chipChatPlayChess;

  /// features/chip/presentation/chip_chat_sheet.dart
  ///
  /// In en, this message translates to:
  /// **'Play checkers'**
  String get chipChatPlayCheckers;

  /// features/chip/presentation/chip_chat_sheet.dart
  ///
  /// In en, this message translates to:
  /// **'Play Ludo'**
  String get chipChatPlayLudo;

  /// features/chip/presentation/chip_chat_sheet.dart
  ///
  /// In en, this message translates to:
  /// **'Play Guess My Doodle'**
  String get chipChatPlayGuessMyDoodle;

  /// features/chip/presentation/chip_chat_sheet.dart
  ///
  /// In en, this message translates to:
  /// **'Save your account'**
  String get chipChatSaveYourAccount;

  /// features/chip/presentation/chip_chat_sheet.dart
  ///
  /// In en, this message translates to:
  /// **'Report a bug'**
  String get chipChatReportABug;

  /// features/chip/presentation/chip_chat_sheet.dart
  ///
  /// In en, this message translates to:
  /// **'Suggest a feature'**
  String get chipChatSuggestAFeature;

  /// features/chip/presentation/chip_chat_sheet.dart
  ///
  /// In en, this message translates to:
  /// **'Chip'**
  String get chipChatChip;

  /// features/chip/presentation/chip_chat_sheet.dart
  ///
  /// In en, this message translates to:
  /// **'Thinking...'**
  String get chipChatThinking;

  /// features/chip/presentation/chip_chat_sheet.dart
  ///
  /// In en, this message translates to:
  /// **'Your buddy in Utopia. Ask me anything.'**
  String get chipChatYourBuddyInUtopiaAsk;

  /// features/chip/presentation/chip_chat_sheet.dart
  ///
  /// In en, this message translates to:
  /// **'Draw it for real · Free'**
  String get chipChatDrawItForRealFree;

  /// features/chip/presentation/chip_chat_sheet.dart
  ///
  /// In en, this message translates to:
  /// **'Draw it for real · {left} left'**
  String chipChatDrawItForRealLeft(Object left);

  /// features/chip/presentation/chip_chat_sheet.dart
  ///
  /// In en, this message translates to:
  /// **'Draw it for real with Chip Maestro'**
  String get chipChatDrawItForRealWith;

  /// features/chip/presentation/chip_chat_sheet.dart
  ///
  /// In en, this message translates to:
  /// **'Color it with Chip'**
  String get chipChatColorItWithChip;

  /// features/chip/presentation/chip_chat_sheet.dart
  ///
  /// In en, this message translates to:
  /// **'Keep chatting · {value} coins'**
  String chipChatKeepChattingCoins(Object value);

  /// features/chip/presentation/chip_chat_sheet.dart
  ///
  /// In en, this message translates to:
  /// **'Tell Chip about the photo'**
  String get chipChatTellChipAboutThePhoto;

  /// features/chip/presentation/chip_chat_sheet.dart
  ///
  /// In en, this message translates to:
  /// **'Say something to Chip'**
  String get chipChatSaySomethingToChip;

  /// features/chip/presentation/chip_chat_sheet.dart
  ///
  /// In en, this message translates to:
  /// **'Hi! I know every corner of Utopia, and plenty outside it. Ask me anything, have me draw you a picture to color, or just say hello.'**
  String get chipChatHiIKnowEveryCorner;

  /// features/chip/presentation/chip_chat_sheet.dart
  ///
  /// In en, this message translates to:
  /// **'Found a bug, or got an idea? Pass it on and the team will see it.'**
  String get chipChatFoundABugOrGot;

  /// features/chip/presentation/chip_chat_sheet.dart
  ///
  /// In en, this message translates to:
  /// **'Send'**
  String get chipChatSend;

  /// features/chip/presentation/chip_chat_sheet.dart
  ///
  /// In en, this message translates to:
  /// **'Send Chip a photo'**
  String get chipChatSendChipAPhoto;

  /// features/chip/presentation/chip_chat_sheet.dart
  ///
  /// In en, this message translates to:
  /// **'Photo for Chip'**
  String get chipChatPhotoForChip;

  /// features/chip/presentation/chip_chat_sheet.dart
  ///
  /// In en, this message translates to:
  /// **'Remove the photo'**
  String get chipChatRemoveThePhoto;

  /// features/chip/presentation/chip_chat_sheet.dart
  ///
  /// In en, this message translates to:
  /// **'Color it'**
  String get chipChatColorIt;

  /// features/chip/presentation/chip_chat_sheet.dart
  ///
  /// In en, this message translates to:
  /// **'Travel to Doodle to color it'**
  String get chipChatTravelToDoodleToColor;

  /// features/chip/presentation/chip_chat_sheet.dart
  ///
  /// In en, this message translates to:
  /// **'Get the Doodle world to color it'**
  String get chipChatGetTheDoodleWorldTo;

  /// features/chip/presentation/chip_chat_sheet.dart
  ///
  /// In en, this message translates to:
  /// **'Drawing {subject}...'**
  String chipChatDrawing(Object subject);

  /// features/chip/presentation/chip_chat_sheet.dart
  ///
  /// In en, this message translates to:
  /// **'I can\'t draw that one. Try something else?'**
  String get chipChatICanTDrawThat;

  /// features/chip/presentation/chip_chat_sheet.dart
  ///
  /// In en, this message translates to:
  /// **'I\'ve drawn all I can today. Ask me again tomorrow!'**
  String get chipChatIVeDrawnAllI;

  /// features/chip/presentation/chip_chat_sheet.dart
  ///
  /// In en, this message translates to:
  /// **'My pencil isn\'t ready yet.'**
  String get chipChatMyPencilIsnTReady;

  /// features/chip/presentation/chip_chat_sheet.dart
  ///
  /// In en, this message translates to:
  /// **'That drawing didn\'t work out. Ask me again?'**
  String get chipChatThatDrawingDidnTWork;

  /// features/chess/presentation/screens/chess_bot_screen.dart
  ///
  /// In en, this message translates to:
  /// **'White'**
  String get chessBotWhite;

  /// features/chess/presentation/screens/chess_bot_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Black'**
  String get chessBotBlack;

  /// features/chess/presentation/screens/chess_bot_screen.dart
  ///
  /// In en, this message translates to:
  /// **'a friend'**
  String get chessBotAFriend;

  /// features/chess/presentation/screens/chess_bot_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Ready? I\'ve been practising!'**
  String get chessBotReadyIVeBeenPractising;

  /// features/chess/presentation/screens/chess_bot_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Good luck! Have fun!'**
  String get chessBotGoodLuckHaveFun;

  /// features/chess/presentation/screens/chess_bot_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Mine now!'**
  String get chessBotMineNow;

  /// features/chess/presentation/screens/chess_bot_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Oof, nice one.'**
  String get chessBotOofNiceOne;

  /// features/chess/presentation/screens/chess_bot_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Nooo, my piece!'**
  String get chessBotNoooMyPiece;

  /// features/chess/presentation/screens/chess_bot_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Watch your king!'**
  String get chessBotWatchYourKing;

  /// features/chess/presentation/screens/chess_bot_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Whoa, check?'**
  String get chessBotWhoaCheck;

  /// features/chess/presentation/screens/chess_bot_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Checkmate... you\'re good!'**
  String get chessBotCheckmateYouReGood;

  /// features/chess/presentation/screens/chess_bot_screen.dart
  ///
  /// In en, this message translates to:
  /// **'ERROR: PIECE MISSING.'**
  String get chessBotErrorPieceMissing;

  /// features/chess/presentation/screens/chess_bot_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Leave this game?'**
  String get chessBotLeaveThisGame;

  /// features/chess/presentation/screens/chess_bot_screen.dart
  ///
  /// In en, this message translates to:
  /// **'This game ends here and won\'t be saved.'**
  String get chessBotThisGameEndsHereAnd;

  /// features/chess/presentation/screens/chess_bot_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Your game against {value} ends here and won\'t be saved.'**
  String chessBotYourGameAgainstEndsHere(Object value);

  /// features/chess/presentation/screens/chess_bot_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Leave'**
  String get chessBotLeave;

  /// features/chess/presentation/screens/chess_bot_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Keep playing'**
  String get chessBotKeepPlaying;

  /// features/chess/presentation/screens/chess_bot_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Resign this game?'**
  String get chessBotResignThisGame;

  /// features/chess/presentation/screens/chess_bot_screen.dart
  ///
  /// In en, this message translates to:
  /// **'{value} wins this one.'**
  String chessBotWinsThisOne(Object value);

  /// features/chess/presentation/screens/chess_bot_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Resign'**
  String get chessBotResign;

  /// features/chess/presentation/screens/chess_bot_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Easy'**
  String get chessBotEasy;

  /// features/chess/presentation/screens/chess_bot_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Normal'**
  String get chessBotNormal;

  /// features/chess/presentation/screens/chess_bot_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Hard'**
  String get chessBotHard;

  /// features/chess/presentation/screens/chess_bot_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Leave game'**
  String get chessBotLeaveGame;

  /// features/chess/presentation/screens/chess_bot_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get chessBotClose;

  /// features/chess/presentation/screens/chess_bot_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Chess · one phone'**
  String get chessBotChessOnePhone;

  /// features/chess/presentation/screens/chess_bot_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Take back'**
  String get chessBotTakeBack;

  /// features/chess/presentation/screens/chess_bot_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Draw'**
  String get chessBotDraw;

  /// features/chess/presentation/screens/chess_bot_screen.dart
  ///
  /// In en, this message translates to:
  /// **'{value} ran out of time'**
  String chessBotRanOutOfTime(Object value);

  /// features/chess/presentation/screens/chess_bot_screen.dart
  ///
  /// In en, this message translates to:
  /// **'{value}: check!'**
  String chessBotCheck(Object value);

  /// features/chess/presentation/screens/chess_bot_screen.dart
  ///
  /// In en, this message translates to:
  /// **'{value}\'s move'**
  String chessBotSMove(Object value);

  /// features/chess/presentation/screens/chess_bot_screen.dart
  ///
  /// In en, this message translates to:
  /// **'You'**
  String get chessBotYou;

  /// features/chess/presentation/screens/chess_bot_screen.dart
  ///
  /// In en, this message translates to:
  /// **'You won!'**
  String get chessBotYouWon;

  /// features/chess/presentation/screens/chess_bot_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Out of time'**
  String get chessBotOutOfTime;

  /// features/chess/presentation/screens/chess_bot_screen.dart
  ///
  /// In en, this message translates to:
  /// **'{value} is thinking...'**
  String chessBotIsThinking(Object value);

  /// features/chess/presentation/screens/chess_bot_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Check! Protect your king'**
  String get chessBotCheckProtectYourKing;

  /// features/chess/presentation/screens/chess_bot_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Your move'**
  String get chessBotYourMove;

  /// features/chess/presentation/screens/chess_bot_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Result'**
  String get chessBotResult;

  /// features/chess/presentation/screens/chess_bot_screen.dart
  ///
  /// In en, this message translates to:
  /// **'It\'s a draw'**
  String get chessBotItSADraw;

  /// features/chess/presentation/screens/chess_bot_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Thinking...'**
  String get chessBotThinking;

  /// features/chess/presentation/screens/chess_bot_screen.dart
  ///
  /// In en, this message translates to:
  /// **'{level} · offline'**
  String chessBotOffline(Object level);

  /// features/chess/presentation/screens/chess_bot_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Their time ran out!'**
  String get chessBotTheirTimeRanOut;

  /// features/chess/presentation/screens/chess_bot_screen.dart
  ///
  /// In en, this message translates to:
  /// **'You resigned'**
  String get chessBotYouResigned;

  /// features/chess/presentation/screens/chess_bot_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Play again'**
  String get chessBotPlayAgain;

  /// features/chess/presentation/screens/chess_bot_screen.dart
  ///
  /// In en, this message translates to:
  /// **'See the board'**
  String get chessBotSeeTheBoard;

  /// features/chess/presentation/screens/chess_bot_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get chessBotDone;

  /// features/store/domain/store_catalog.dart
  ///
  /// In en, this message translates to:
  /// **'Pouch'**
  String get storeCatalogPouch;

  /// features/store/domain/store_catalog.dart
  ///
  /// In en, this message translates to:
  /// **'Sack'**
  String get storeCatalogSack;

  /// features/store/domain/store_catalog.dart
  ///
  /// In en, this message translates to:
  /// **'Chest'**
  String get storeCatalogChest;

  /// features/store/domain/store_catalog.dart
  ///
  /// In en, this message translates to:
  /// **'Popular'**
  String get storeCatalogPopular;

  /// features/store/domain/store_catalog.dart
  ///
  /// In en, this message translates to:
  /// **'Vault'**
  String get storeCatalogVault;

  /// features/store/domain/store_catalog.dart
  ///
  /// In en, this message translates to:
  /// **'Mountain'**
  String get storeCatalogMountain;

  /// features/store/domain/store_catalog.dart
  ///
  /// In en, this message translates to:
  /// **'Dragon\'s Hoard'**
  String get storeCatalogDragonSHoard;

  /// features/store/domain/store_catalog.dart
  ///
  /// In en, this message translates to:
  /// **'Best value'**
  String get storeCatalogBestValue;

  /// features/store/domain/store_catalog.dart
  ///
  /// In en, this message translates to:
  /// **'Starter pack'**
  String get storeCatalogStarterPack;

  /// features/store/domain/store_catalog.dart
  ///
  /// In en, this message translates to:
  /// **'Once only'**
  String get storeCatalogOnceOnly;

  /// features/store/domain/store_catalog.dart
  ///
  /// In en, this message translates to:
  /// **'Classic Gloss'**
  String get storeCatalogClassicGloss;

  /// features/store/domain/store_catalog.dart
  ///
  /// In en, this message translates to:
  /// **'Shiny enamel pins, the timeless look.'**
  String get storeCatalogShinyEnamelPinsTheTimeless;

  /// features/store/domain/store_catalog.dart
  ///
  /// In en, this message translates to:
  /// **'Bubble Pop'**
  String get storeCatalogBubblePop;

  /// features/store/domain/store_catalog.dart
  ///
  /// In en, this message translates to:
  /// **'Wobbly soap bubbles that shimmer as they hop.'**
  String get storeCatalogWobblySoapBubblesThatShimmer;

  /// features/store/domain/store_catalog.dart
  ///
  /// In en, this message translates to:
  /// **'Jelly Buddies'**
  String get storeCatalogJellyBuddies;

  /// features/store/domain/store_catalog.dart
  ///
  /// In en, this message translates to:
  /// **'Squishy jelly critters that blink and jiggle.'**
  String get storeCatalogSquishyJellyCrittersThatBlink;

  /// features/store/domain/store_catalog.dart
  ///
  /// In en, this message translates to:
  /// **'Crystal Shards'**
  String get storeCatalogCrystalShards;

  /// features/store/domain/store_catalog.dart
  ///
  /// In en, this message translates to:
  /// **'Faceted gems that catch the light.'**
  String get storeCatalogFacetedGemsThatCatchThe;

  /// features/store/domain/store_catalog.dart
  ///
  /// In en, this message translates to:
  /// **'Candy Swirl'**
  String get storeCatalogCandySwirl;

  /// features/store/domain/store_catalog.dart
  ///
  /// In en, this message translates to:
  /// **'Spinning lollipops, sweet and glossy.'**
  String get storeCatalogSpinningLollipopsSweetAndGlossy;

  /// features/store/domain/store_catalog.dart
  ///
  /// In en, this message translates to:
  /// **'Cosmic Orbs'**
  String get storeCatalogCosmicOrbs;

  /// features/store/domain/store_catalog.dart
  ///
  /// In en, this message translates to:
  /// **'Tiny ringed planets with orbiting moons.'**
  String get storeCatalogTinyRingedPlanetsWithOrbiting;

  /// features/store/domain/store_catalog.dart
  ///
  /// In en, this message translates to:
  /// **'Royal Crowns'**
  String get storeCatalogRoyalCrowns;

  /// features/store/domain/store_catalog.dart
  ///
  /// In en, this message translates to:
  /// **'Gold-crowned pieces with jewel hearts.'**
  String get storeCatalogGoldCrownedPiecesWithJewel;

  /// features/store/domain/store_catalog.dart
  ///
  /// In en, this message translates to:
  /// **'Classic'**
  String get storeCatalogClassic;

  /// features/store/domain/store_catalog.dart
  ///
  /// In en, this message translates to:
  /// **'Ivory and violet, clean and readable.'**
  String get storeCatalogIvoryAndVioletCleanAnd;

  /// features/store/domain/store_catalog.dart
  ///
  /// In en, this message translates to:
  /// **'Chess Buddies'**
  String get storeCatalogChessBuddies;

  /// features/store/domain/store_catalog.dart
  ///
  /// In en, this message translates to:
  /// **'Pieces with faces: they blink, cheer, panic and faint.'**
  String get storeCatalogPiecesWithFacesTheyBlink;

  /// features/store/domain/store_catalog.dart
  ///
  /// In en, this message translates to:
  /// **'Monster Mash'**
  String get storeCatalogMonsterMash;

  /// features/store/domain/store_catalog.dart
  ///
  /// In en, this message translates to:
  /// **'Horns, fangs and one very big eye. They mean business.'**
  String get storeCatalogHornsFangsAndOneVery;

  /// features/store/domain/store_catalog.dart
  ///
  /// In en, this message translates to:
  /// **'Robo Knights'**
  String get storeCatalogRoboKnights;

  /// features/store/domain/store_catalog.dart
  ///
  /// In en, this message translates to:
  /// **'Chrome pieces with LED faces that scan the board.'**
  String get storeCatalogChromePiecesWithLedFaces;

  /// features/store/domain/store_catalog.dart
  ///
  /// In en, this message translates to:
  /// **'Crystal'**
  String get storeCatalogCrystal;

  /// features/store/domain/store_catalog.dart
  ///
  /// In en, this message translates to:
  /// **'Ice-clear pieces with a frosted glow.'**
  String get storeCatalogIceClearPiecesWithA;

  /// features/store/domain/store_catalog.dart
  ///
  /// In en, this message translates to:
  /// **'Royal Gold'**
  String get storeCatalogRoyalGold;

  /// features/store/domain/store_catalog.dart
  ///
  /// In en, this message translates to:
  /// **'Gold against obsidian, fit for a throne.'**
  String get storeCatalogGoldAgainstObsidianFitFor;

  /// features/store/domain/store_catalog.dart
  ///
  /// In en, this message translates to:
  /// **'Neon'**
  String get storeCatalogNeon;

  /// features/store/domain/store_catalog.dart
  ///
  /// In en, this message translates to:
  /// **'Pieces that glow like an arcade at night.'**
  String get storeCatalogPiecesThatGlowLikeAn;

  /// features/store/domain/store_catalog.dart
  ///
  /// In en, this message translates to:
  /// **'Candy'**
  String get storeCatalogCandy;

  /// features/store/domain/store_catalog.dart
  ///
  /// In en, this message translates to:
  /// **'Bubblegum pink and mint, sweet as it gets.'**
  String get storeCatalogBubblegumPinkAndMintSweet;

  /// features/store/domain/store_catalog.dart
  ///
  /// In en, this message translates to:
  /// **'{value} Pack'**
  String storeCatalogPack(Object value);

  /// features/store/domain/store_catalog.dart
  ///
  /// In en, this message translates to:
  /// **'Every World'**
  String get storeCatalogEveryWorld;

  /// features/store/domain/store_catalog.dart
  ///
  /// In en, this message translates to:
  /// **'{name} Chess'**
  String storeCatalogChess(Object name);

  /// features/store/domain/store_catalog.dart
  ///
  /// In en, this message translates to:
  /// **'Ruby'**
  String get storeCatalogRuby;

  /// features/store/domain/store_catalog.dart
  ///
  /// In en, this message translates to:
  /// **'Ember'**
  String get storeCatalogEmber;

  /// features/store/domain/store_catalog.dart
  ///
  /// In en, this message translates to:
  /// **'Sunbeam'**
  String get storeCatalogSunbeam;

  /// features/store/domain/store_catalog.dart
  ///
  /// In en, this message translates to:
  /// **'Jade'**
  String get storeCatalogJade;

  /// features/store/domain/store_catalog.dart
  ///
  /// In en, this message translates to:
  /// **'Lagoon'**
  String get storeCatalogLagoon;

  /// features/store/domain/store_catalog.dart
  ///
  /// In en, this message translates to:
  /// **'Azure'**
  String get storeCatalogAzure;

  /// features/store/domain/store_catalog.dart
  ///
  /// In en, this message translates to:
  /// **'Sapphire'**
  String get storeCatalogSapphire;

  /// features/store/domain/store_catalog.dart
  ///
  /// In en, this message translates to:
  /// **'Amethyst'**
  String get storeCatalogAmethyst;

  /// features/store/domain/store_catalog.dart
  ///
  /// In en, this message translates to:
  /// **'Blossom'**
  String get storeCatalogBlossom;

  /// features/store/domain/store_catalog.dart
  ///
  /// In en, this message translates to:
  /// **'Rose Gold'**
  String get storeCatalogRoseGold;

  /// features/store/domain/store_catalog.dart
  ///
  /// In en, this message translates to:
  /// **'Onyx'**
  String get storeCatalogOnyx;

  /// features/store/domain/store_catalog.dart
  ///
  /// In en, this message translates to:
  /// **'Pearl'**
  String get storeCatalogPearl;

  /// features/checkers/presentation/screens/checkers_bot_screen.dart
  ///
  /// In en, this message translates to:
  /// **'a friend'**
  String get checkersBotAFriend;

  /// features/checkers/presentation/screens/checkers_bot_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Ready? I\'ve been practising my jumps!'**
  String get checkersBotReadyIVeBeenPractising;

  /// features/checkers/presentation/screens/checkers_bot_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Good luck! Have fun!'**
  String get checkersBotGoodLuckHaveFun;

  /// features/checkers/presentation/screens/checkers_bot_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Mine now!'**
  String get checkersBotMineNow;

  /// features/checkers/presentation/screens/checkers_bot_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Oof, nice jump.'**
  String get checkersBotOofNiceJump;

  /// features/checkers/presentation/screens/checkers_bot_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Boing boing!'**
  String get checkersBotBoingBoing;

  /// features/checkers/presentation/screens/checkers_bot_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Whoa, a double!'**
  String get checkersBotWhoaADouble;

  /// features/checkers/presentation/screens/checkers_bot_screen.dart
  ///
  /// In en, this message translates to:
  /// **'That\'s not fair... it is fair.'**
  String get checkersBotThatSNotFairIt;

  /// features/checkers/presentation/screens/checkers_bot_screen.dart
  ///
  /// In en, this message translates to:
  /// **'I\'m a king now!'**
  String get checkersBotIMAKingNow;

  /// features/checkers/presentation/screens/checkers_bot_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Your Majesty...'**
  String get checkersBotYourMajesty;

  /// features/checkers/presentation/screens/checkers_bot_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Kings go backwards too. Eek.'**
  String get checkersBotKingsGoBackwardsTooEek;

  /// features/checkers/presentation/screens/checkers_bot_screen.dart
  ///
  /// In en, this message translates to:
  /// **'ERROR: PIECE MISSING.'**
  String get checkersBotErrorPieceMissing;

  /// features/checkers/presentation/screens/checkers_bot_screen.dart
  ///
  /// In en, this message translates to:
  /// **'VICTORY PROTOCOL COMPLETE.'**
  String get checkersBotVictoryProtocolComplete;

  /// features/checkers/presentation/screens/checkers_bot_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Dark'**
  String get checkersBotDark;

  /// features/checkers/presentation/screens/checkers_bot_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get checkersBotLight;

  /// features/checkers/presentation/screens/checkers_bot_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Easy'**
  String get checkersBotEasy;

  /// features/checkers/presentation/screens/checkers_bot_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Normal'**
  String get checkersBotNormal;

  /// features/checkers/presentation/screens/checkers_bot_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Hard'**
  String get checkersBotHard;

  /// features/checkers/presentation/screens/checkers_bot_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Draw'**
  String get checkersBotDraw;

  /// features/checkers/presentation/screens/checkers_bot_screen.dart
  ///
  /// In en, this message translates to:
  /// **'{value} ran out of time'**
  String checkersBotRanOutOfTime(Object value);

  /// features/checkers/presentation/screens/checkers_bot_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Out of time'**
  String get checkersBotOutOfTime;

  /// features/checkers/presentation/screens/checkers_bot_screen.dart
  ///
  /// In en, this message translates to:
  /// **'You won!'**
  String get checkersBotYouWon;

  /// features/checkers/presentation/screens/checkers_bot_screen.dart
  ///
  /// In en, this message translates to:
  /// **'{value} is thinking...'**
  String checkersBotIsThinking(Object value);

  /// features/checkers/presentation/screens/checkers_bot_screen.dart
  ///
  /// In en, this message translates to:
  /// **'{value}: you must take a piece'**
  String checkersBotYouMustTakeAPiece(Object value);

  /// features/checkers/presentation/screens/checkers_bot_screen.dart
  ///
  /// In en, this message translates to:
  /// **'{value}\'s move'**
  String checkersBotSMove(Object value);

  /// features/checkers/presentation/screens/checkers_bot_screen.dart
  ///
  /// In en, this message translates to:
  /// **'You must take a piece'**
  String get checkersBotYouMustTakeAPiece2;

  /// features/checkers/presentation/screens/checkers_bot_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Your move'**
  String get checkersBotYourMove;

  /// features/checkers/presentation/screens/checkers_bot_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get checkersBotClose;

  /// features/checkers/presentation/screens/checkers_bot_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Checkers · one phone'**
  String get checkersBotCheckersOnePhone;

  /// features/checkers/presentation/screens/checkers_bot_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Take back'**
  String get checkersBotTakeBack;

  /// features/checkers/presentation/screens/checkers_bot_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Resign'**
  String get checkersBotResign;

  /// features/checkers/presentation/screens/checkers_bot_screen.dart
  ///
  /// In en, this message translates to:
  /// **'You'**
  String get checkersBotYou;

  /// features/checkers/presentation/screens/checkers_bot_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Result'**
  String get checkersBotResult;

  /// features/checkers/presentation/screens/checkers_bot_screen.dart
  ///
  /// In en, this message translates to:
  /// **'It\'s a draw'**
  String get checkersBotItSADraw;

  /// features/checkers/presentation/screens/checkers_bot_screen.dart
  ///
  /// In en, this message translates to:
  /// **'You resigned'**
  String get checkersBotYouResigned;

  /// features/checkers/presentation/screens/checkers_bot_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Took {taken}'**
  String checkersBotTook(Object taken);

  /// features/checkers/presentation/screens/checkers_bot_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Thinking...'**
  String get checkersBotThinking;

  /// features/checkers/presentation/screens/checkers_bot_screen.dart
  ///
  /// In en, this message translates to:
  /// **'{level} · offline'**
  String checkersBotOffline(Object level);

  /// features/checkers/presentation/screens/checkers_bot_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Play again'**
  String get checkersBotPlayAgain;

  /// features/checkers/presentation/screens/checkers_bot_screen.dart
  ///
  /// In en, this message translates to:
  /// **'See the board'**
  String get checkersBotSeeTheBoard;

  /// features/checkers/presentation/screens/checkers_bot_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get checkersBotDone;

  /// features/ludo/presentation/widgets/ludo_player_card.dart
  ///
  /// In en, this message translates to:
  /// **'Dark'**
  String get ludoPlayerDark;

  /// features/ludo/presentation/widgets/ludo_player_card.dart
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get ludoPlayerLight;

  /// features/ludo/presentation/widgets/ludo_player_card.dart
  ///
  /// In en, this message translates to:
  /// **'White'**
  String get ludoPlayerWhite;

  /// features/ludo/presentation/widgets/ludo_player_card.dart
  ///
  /// In en, this message translates to:
  /// **'Black'**
  String get ludoPlayerBlack;

  /// features/ludo/presentation/widgets/ludo_player_card.dart
  ///
  /// In en, this message translates to:
  /// **'You'**
  String get ludoPlayerYou;

  /// features/ludo/presentation/widgets/ludo_player_card.dart
  ///
  /// In en, this message translates to:
  /// **'Classic Gloss'**
  String get ludoPlayerClassicGloss;

  /// features/ludo/presentation/widgets/ludo_player_card.dart
  ///
  /// In en, this message translates to:
  /// **'Classic'**
  String get ludoPlayerClassic;

  /// features/ludo/presentation/widgets/ludo_player_card.dart
  ///
  /// In en, this message translates to:
  /// **'Joined {value}'**
  String ludoPlayerJoined(Object value);

  /// features/ludo/presentation/widgets/ludo_player_card.dart
  ///
  /// In en, this message translates to:
  /// **'Ludo wins'**
  String get ludoPlayerLudoWins;

  /// features/ludo/presentation/widgets/ludo_player_card.dart
  ///
  /// In en, this message translates to:
  /// **'Chess wins'**
  String get ludoPlayerChessWins;

  /// features/ludo/presentation/widgets/ludo_player_card.dart
  ///
  /// In en, this message translates to:
  /// **'Checkers wins'**
  String get ludoPlayerCheckersWins;

  /// features/ludo/presentation/widgets/ludo_player_card.dart
  ///
  /// In en, this message translates to:
  /// **'Doodle wins'**
  String get ludoPlayerDoodleWins;

  /// features/ludo/presentation/widgets/ludo_player_card.dart
  ///
  /// In en, this message translates to:
  /// **'Played'**
  String get ludoPlayerPlayed;

  /// features/ludo/presentation/widgets/ludo_player_card.dart
  ///
  /// In en, this message translates to:
  /// **'Win rate'**
  String get ludoPlayerWinRate;

  /// features/ludo/presentation/widgets/ludo_player_card.dart
  ///
  /// In en, this message translates to:
  /// **'Unmute chat'**
  String get ludoPlayerUnmuteChat;

  /// features/ludo/presentation/widgets/ludo_player_card.dart
  ///
  /// In en, this message translates to:
  /// **'Mute chat'**
  String get ludoPlayerMuteChat;

  /// features/ludo/presentation/widgets/ludo_player_card.dart
  ///
  /// In en, this message translates to:
  /// **'Report'**
  String get ludoPlayerReport;

  /// features/ludo/presentation/widgets/ludo_player_card.dart
  ///
  /// In en, this message translates to:
  /// **'Feb'**
  String get ludoPlayerFeb;

  /// features/ludo/presentation/widgets/ludo_player_card.dart
  ///
  /// In en, this message translates to:
  /// **'Mar'**
  String get ludoPlayerMar;

  /// features/ludo/presentation/widgets/ludo_player_card.dart
  ///
  /// In en, this message translates to:
  /// **'Apr'**
  String get ludoPlayerApr;

  /// features/ludo/presentation/widgets/ludo_player_card.dart
  ///
  /// In en, this message translates to:
  /// **'May'**
  String get ludoPlayerMay;

  /// features/ludo/presentation/widgets/ludo_player_card.dart
  ///
  /// In en, this message translates to:
  /// **'Jun'**
  String get ludoPlayerJun;

  /// features/ludo/presentation/widgets/ludo_player_card.dart
  ///
  /// In en, this message translates to:
  /// **'Jul'**
  String get ludoPlayerJul;

  /// features/ludo/presentation/widgets/ludo_player_card.dart
  ///
  /// In en, this message translates to:
  /// **'Aug'**
  String get ludoPlayerAug;

  /// features/ludo/presentation/widgets/ludo_player_card.dart
  ///
  /// In en, this message translates to:
  /// **'Sep'**
  String get ludoPlayerSep;

  /// features/ludo/presentation/widgets/ludo_player_card.dart
  ///
  /// In en, this message translates to:
  /// **'Oct'**
  String get ludoPlayerOct;

  /// features/ludo/presentation/widgets/ludo_player_card.dart
  ///
  /// In en, this message translates to:
  /// **'Nov'**
  String get ludoPlayerNov;

  /// features/ludo/presentation/widgets/ludo_player_card.dart
  ///
  /// In en, this message translates to:
  /// **'Dec'**
  String get ludoPlayerDec;

  /// features/ludo/presentation/widgets/ludo_player_card.dart
  ///
  /// In en, this message translates to:
  /// **'Save your account to add friends'**
  String get ludoPlayerSaveYourAccountToAdd;

  /// features/ludo/presentation/widgets/ludo_player_card.dart
  ///
  /// In en, this message translates to:
  /// **'Add friend'**
  String get ludoPlayerAddFriend;

  /// features/ludo/presentation/widgets/ludo_player_card.dart
  ///
  /// In en, this message translates to:
  /// **'Friends'**
  String get ludoPlayerFriends;

  /// features/ludo/presentation/widgets/ludo_player_card.dart
  ///
  /// In en, this message translates to:
  /// **'Request sent'**
  String get ludoPlayerRequestSent;

  /// features/ludo/presentation/widgets/ludo_player_card.dart
  ///
  /// In en, this message translates to:
  /// **'Accept friend request'**
  String get ludoPlayerAcceptFriendRequest;

  /// features/ludo/presentation/widgets/ludo_player_card.dart
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t send the request. Try again.'**
  String get ludoPlayerCouldnTSendTheRequest;

  /// features/ludo/presentation/widgets/ludo_player_card.dart
  ///
  /// In en, this message translates to:
  /// **'Report this player'**
  String get ludoPlayerReportThisPlayer;

  /// features/ludo/presentation/widgets/ludo_player_card.dart
  ///
  /// In en, this message translates to:
  /// **'Offensive chat'**
  String get ludoPlayerOffensiveChat;

  /// features/ludo/presentation/widgets/ludo_player_card.dart
  ///
  /// In en, this message translates to:
  /// **'Cheating'**
  String get ludoPlayerCheating;

  /// features/ludo/presentation/widgets/ludo_player_card.dart
  ///
  /// In en, this message translates to:
  /// **'Leaving games on purpose'**
  String get ludoPlayerLeavingGamesOnPurpose;

  /// features/ludo/presentation/widgets/ludo_player_card.dart
  ///
  /// In en, this message translates to:
  /// **'Inappropriate name or picture'**
  String get ludoPlayerInappropriateNameOrPicture;

  /// features/ludo/presentation/widgets/ludo_player_card.dart
  ///
  /// In en, this message translates to:
  /// **'Something else'**
  String get ludoPlayerSomethingElse;

  /// features/ludo/presentation/widgets/ludo_player_card.dart
  ///
  /// In en, this message translates to:
  /// **'Thanks. Our team will take a look.'**
  String get ludoPlayerThanksOurTeamWillTake;

  /// features/ludo/presentation/widgets/ludo_player_card.dart
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t send the report. Try again.'**
  String get ludoPlayerCouldnTSendTheReport;

  /// features/ludo/presentation/screens/ludo_match_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Out of time! Your turn was played for you.'**
  String get ludoMatchOutOfTimeYourTurn;

  /// features/ludo/presentation/screens/ludo_match_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Leave this game?'**
  String get ludoMatchLeaveThisGame;

  /// features/ludo/presentation/screens/ludo_match_screen.dart
  ///
  /// In en, this message translates to:
  /// **'This game against the bots will end.'**
  String get ludoMatchThisGameAgainstTheBots;

  /// features/ludo/presentation/screens/ludo_match_screen.dart
  ///
  /// In en, this message translates to:
  /// **'You\'ll lose your {stake}-coin entry{value}.'**
  String ludoMatchYouLlLoseYourCoin(Object stake, Object value);

  /// features/ludo/presentation/screens/ludo_match_screen.dart
  ///
  /// In en, this message translates to:
  /// **'You\'ll lose this game{value}.'**
  String ludoMatchYouLlLoseThisGame(Object value);

  /// features/ludo/presentation/screens/ludo_match_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Leave game'**
  String get ludoMatchLeaveGame;

  /// features/ludo/presentation/screens/ludo_match_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Keep playing'**
  String get ludoMatchKeepPlaying;

  /// features/ludo/presentation/screens/ludo_match_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Sound & music'**
  String get ludoMatchSoundMusic;

  /// features/ludo/presentation/screens/ludo_match_screen.dart
  ///
  /// In en, this message translates to:
  /// **'How to play'**
  String get ludoMatchHowToPlay;

  /// features/ludo/presentation/screens/ludo_match_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Chat'**
  String get ludoMatchChat;

  /// features/ludo/presentation/screens/ludo_match_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Setting up the board'**
  String get ludoMatchSettingUpTheBoard;

  /// features/ludo/presentation/screens/ludo_match_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Ludo'**
  String get ludoMatchLudo;

  /// features/ludo/presentation/screens/ludo_match_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Game menu'**
  String get ludoMatchGameMenu;

  /// features/ludo/presentation/screens/ludo_match_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Free'**
  String get ludoMatchFree;

  /// features/ludo/presentation/screens/ludo_match_screen.dart
  ///
  /// In en, this message translates to:
  /// **'You left this game.'**
  String get ludoMatchYouLeftThisGame;

  /// features/ludo/presentation/screens/ludo_match_screen.dart
  ///
  /// In en, this message translates to:
  /// **'{value} captured! Tap the piece to react, or roll on'**
  String ludoMatchCapturedTapThePieceTo(Object value);

  /// features/ludo/presentation/screens/ludo_match_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Captured! Tap your piece to react, or roll on'**
  String get ludoMatchCapturedTapYourPieceTo;

  /// features/ludo/presentation/screens/ludo_match_screen.dart
  ///
  /// In en, this message translates to:
  /// **'{value}, tap a glowing piece'**
  String ludoMatchTapAGlowingPiece(Object value);

  /// features/ludo/presentation/screens/ludo_match_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Tap a glowing piece to move'**
  String get ludoMatchTapAGlowingPieceTo;

  /// features/ludo/presentation/screens/ludo_match_screen.dart
  ///
  /// In en, this message translates to:
  /// **'{value}\'s turn. Tap the die!'**
  String ludoMatchSTurnTapTheDie(Object value);

  /// features/ludo/presentation/screens/ludo_match_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Your turn. Tap the die!'**
  String get ludoMatchYourTurnTapTheDie;

  /// features/ludo/presentation/screens/ludo_match_screen.dart
  ///
  /// In en, this message translates to:
  /// **'{value} is playing'**
  String ludoMatchIsPlaying(Object value);

  /// features/ludo/presentation/screens/ludo_match_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Result under review'**
  String get ludoMatchResultUnderReview;

  /// features/ludo/presentation/screens/ludo_match_screen.dart
  ///
  /// In en, this message translates to:
  /// **'You won!'**
  String get ludoMatchYouWon;

  /// features/ludo/presentation/screens/ludo_match_screen.dart
  ///
  /// In en, this message translates to:
  /// **'You came {value}'**
  String ludoMatchYouCame(Object value);

  /// Status line for a player who has finished while the others play on; value is their place, e.g. 1st.
  ///
  /// In en, this message translates to:
  /// **'You came {value}! Watching the rest'**
  String ludoMatchYouFinishedWatching(Object value);

  /// Status line when the player's piece has just been captured and sent back to its yard.
  ///
  /// In en, this message translates to:
  /// **'Sent home! Tap your piece to react'**
  String get ludoMatchSentHomeTapYourPiece;

  /// Status line in pass-and-play when a friend's piece was sent home; value is their color.
  ///
  /// In en, this message translates to:
  /// **'{value} was sent home! Tap the piece to react'**
  String ludoMatchSentHomeTapThePiece(Object value);

  /// Under 'You won!' / 'You came 2nd' while the game goes on; value is the next place, e.g. 2nd.
  ///
  /// In en, this message translates to:
  /// **'All four home! The others play on for {value} place.'**
  String ludoMatchOthersPlayOn(Object value);

  /// Next to the coins won, on the panel shown when the player finishes.
  ///
  /// In en, this message translates to:
  /// **'Your prize'**
  String get ludoMatchYourPrize;

  /// Button: stay and watch the others finish the game.
  ///
  /// In en, this message translates to:
  /// **'Watch'**
  String get ludoMatchWatch;

  /// Button: leave the game after finishing (no penalty).
  ///
  /// In en, this message translates to:
  /// **'Leave'**
  String get ludoMatchLeave;

  /// Banner when another player gets all four pieces home; place is e.g. 1st.
  ///
  /// In en, this message translates to:
  /// **'{name} came {place}!'**
  String ludoMatchFinished(String name, String place);

  /// Menu item for a player who has finished: leaving costs nothing.
  ///
  /// In en, this message translates to:
  /// **'Leave (your place stays)'**
  String get ludoMatchLeaveFinished;

  /// features/ludo/presentation/screens/ludo_match_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Game over'**
  String get ludoMatchGameOver;

  /// features/ludo/presentation/screens/ludo_match_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Someone'**
  String get ludoMatchSomeone;

  /// features/ludo/presentation/screens/ludo_match_screen.dart
  ///
  /// In en, this message translates to:
  /// **'All four pieces home!'**
  String get ludoMatchAllFourPiecesHome;

  /// features/ludo/presentation/screens/ludo_match_screen.dart
  ///
  /// In en, this message translates to:
  /// **'{winnerName} got all four pieces home first.'**
  String ludoMatchGotAllFourPiecesHome(Object winnerName);

  /// features/ludo/presentation/screens/ludo_match_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Everyone else left. The win is yours.'**
  String get ludoMatchEveryoneElseLeftTheWin;

  /// features/ludo/presentation/screens/ludo_match_screen.dart
  ///
  /// In en, this message translates to:
  /// **'The others ran out of time. You win!'**
  String get ludoMatchTheOthersRanOutOf;

  /// features/ludo/presentation/screens/ludo_match_screen.dart
  ///
  /// In en, this message translates to:
  /// **'You ran out of time.'**
  String get ludoMatchYouRanOutOfTime;

  /// features/ludo/presentation/screens/ludo_match_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get ludoMatchHome;

  /// features/ludo/presentation/screens/ludo_match_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Play again'**
  String get ludoMatchPlayAgain;

  /// features/ludo/presentation/screens/ludo_match_screen.dart
  ///
  /// In en, this message translates to:
  /// **'You'**
  String get ludoMatchYou;

  /// features/ludo/presentation/screens/ludo_match_screen.dart
  ///
  /// In en, this message translates to:
  /// **'{value} · Left the game'**
  String ludoMatchLeftTheGame(Object value);

  /// features/store/presentation/store_controller.dart
  ///
  /// In en, this message translates to:
  /// **'Chip Maestro is in the Utopia app on your phone.'**
  String get storeChipMaestroIsInThe;

  /// features/store/data/store_repository.dart
  ///
  /// In en, this message translates to:
  /// **'Save your account to buy coins.'**
  String get storeSaveYourAccountToBuy;

  /// features/store/presentation/store_controller.dart
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t open the payment page. Try again.'**
  String get storeCouldnTOpenThePayment;

  /// features/store/presentation/store_controller.dart
  ///
  /// In en, this message translates to:
  /// **'Coin top-ups are coming soon.'**
  String get storeCoinTopUpsAreComing;

  /// features/store/presentation/store_controller.dart
  ///
  /// In en, this message translates to:
  /// **'Sign in to buy coins.'**
  String get storeSignInToBuyCoins;

  /// features/store/presentation/store_controller.dart
  ///
  /// In en, this message translates to:
  /// **'The store isn\'t available right now. Try again soon.'**
  String get storeTheStoreIsnTAvailable;

  /// features/store/presentation/store_controller.dart
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t start the purchase.'**
  String get storeCouldnTStartThePurchase;

  /// features/store/presentation/store_controller.dart
  ///
  /// In en, this message translates to:
  /// **'Chip Maestro is coming soon.'**
  String get storeChipMaestroIsComingSoon;

  /// features/store/presentation/store_controller.dart
  ///
  /// In en, this message translates to:
  /// **'Sign in to join Chip Maestro.'**
  String get storeSignInToJoinChip;

  /// features/store/presentation/store_controller.dart
  ///
  /// In en, this message translates to:
  /// **'Nothing to restore yet.'**
  String get storeNothingToRestoreYet;

  /// features/store/presentation/store_controller.dart
  ///
  /// In en, this message translates to:
  /// **'Looking for your purchases…'**
  String get storeLookingForYourPurchases;

  /// features/store/presentation/store_controller.dart
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t look for your purchases.'**
  String get storeCouldnTLookForYour;

  /// features/store/presentation/store_controller.dart
  ///
  /// In en, this message translates to:
  /// **'Test top-ups aren\'t available on this server.'**
  String get storeTestTopUpsArenT;

  /// features/store/presentation/store_controller.dart
  ///
  /// In en, this message translates to:
  /// **'Your payment is still going through. Chip Maestro starts as soon as it does.'**
  String get storeYourPaymentIsStillGoing;

  /// features/store/presentation/store_controller.dart
  ///
  /// In en, this message translates to:
  /// **'Your payment is still going through. Your coins arrive as soon as it does.'**
  String get storeYourPaymentIsStillGoing2;

  /// features/store/presentation/store_controller.dart
  ///
  /// In en, this message translates to:
  /// **'The purchase didn\'t go through.'**
  String get storeThePurchaseDidnTGo;

  /// features/store/presentation/store_controller.dart
  ///
  /// In en, this message translates to:
  /// **'Welcome to Chip Maestro!'**
  String get storeWelcomeToChipMaestro;

  /// features/store/presentation/store_controller.dart
  ///
  /// In en, this message translates to:
  /// **'Your Chip Maestro plan is back.'**
  String get storeYourChipMaestroPlanIs;

  /// features/store/presentation/store_controller.dart
  ///
  /// In en, this message translates to:
  /// **'That Chip Maestro plan belongs to another Utopia account.'**
  String get storeThatChipMaestroPlanBelongs;

  /// features/store/presentation/store_controller.dart
  ///
  /// In en, this message translates to:
  /// **'Payment received. Chip Maestro will start the next time you open Utopia.'**
  String get storePaymentReceivedChipMaestroWill;

  /// features/store/presentation/store_controller.dart
  ///
  /// In en, this message translates to:
  /// **'Those coins went to the account that bought them.'**
  String get storeThoseCoinsWentToThe;

  /// features/store/presentation/store_controller.dart
  ///
  /// In en, this message translates to:
  /// **'That payment was cancelled, so no coins were added.'**
  String get storeThatPaymentWasCancelledSo;

  /// features/store/presentation/store_controller.dart
  ///
  /// In en, this message translates to:
  /// **'Payment received. Your coins will arrive the next time you open Utopia.'**
  String get storePaymentReceivedYourCoinsWill;

  /// features/store/presentation/store_controller.dart
  ///
  /// In en, this message translates to:
  /// **'Not enough coins yet.'**
  String get storeNotEnoughCoinsYet;

  /// features/store/presentation/store_controller.dart
  ///
  /// In en, this message translates to:
  /// **'You need {value} coins for that.'**
  String storeYouNeedCoinsForThat(Object value);

  /// features/store/presentation/store_controller.dart
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t unlock that. Check your connection and try again.'**
  String get storeCouldnTUnlockThatCheck;

  /// features/store/presentation/store_controller.dart
  ///
  /// In en, this message translates to:
  /// **'Unlock it first.'**
  String get storeUnlockItFirst;

  /// features/store/presentation/store_controller.dart
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t equip that. Try again?'**
  String get storeCouldnTEquipThatTry;

  /// features/store/presentation/store_controller.dart
  ///
  /// In en, this message translates to:
  /// **'Your welcome pass has ended: back to your own pieces. Keep a favourite set from the store any time.'**
  String get storeYourWelcomePassHasEnded;

  /// features/store/presentation/store_controller.dart
  ///
  /// In en, this message translates to:
  /// **'Your birthday party is over. See you next year!'**
  String get storeYourBirthdayPartyIsOver;

  /// features/store/presentation/store_controller.dart
  ///
  /// In en, this message translates to:
  /// **'{value} is over. {name} comes back next {value2}.'**
  String storeIsOverComesBackNext(Object value, Object name, Object value2);

  /// features/store/presentation/store_controller.dart
  ///
  /// In en, this message translates to:
  /// **'Your time in {name} ran out. Rent it again any time.'**
  String storeYourTimeInRanOut(Object name);

  /// features/store/presentation/store_controller.dart
  ///
  /// In en, this message translates to:
  /// **'You need more coins for that.'**
  String get storeYouNeedMoreCoinsFor;

  /// features/store/presentation/store_controller.dart
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t rent that world. Try again.'**
  String get storeCouldnTRentThatWorld;

  /// features/ludo/presentation/screens/ludo_lobby_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Someone in the room needs more coins for this game.'**
  String get ludoLobbySomeoneInTheRoomNeeds;

  /// features/ludo/presentation/screens/ludo_lobby_screen.dart
  ///
  /// In en, this message translates to:
  /// **'We couldn\'t find that room. Check the code.'**
  String get ludoLobbyWeCouldnTFindThat;

  /// features/ludo/presentation/screens/ludo_lobby_screen.dart
  ///
  /// In en, this message translates to:
  /// **'You need at least 2 players to start.'**
  String get ludoLobbyYouNeedAtLeast2;

  /// features/ludo/presentation/screens/ludo_lobby_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Ludo'**
  String get ludoLobbyLudo;

  /// features/ludo/presentation/screens/ludo_lobby_screen.dart
  ///
  /// In en, this message translates to:
  /// **'How to play'**
  String get ludoLobbyHowToPlay;

  /// features/ludo/presentation/screens/ludo_lobby_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Play online'**
  String get ludoLobbyPlayOnline;

  /// features/ludo/presentation/screens/ludo_lobby_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Join a table of 2 or 4 players'**
  String get ludoLobbyJoinATableOf2;

  /// features/ludo/presentation/screens/ludo_lobby_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Play with friends'**
  String get ludoLobbyPlayWithFriends;

  /// features/ludo/presentation/screens/ludo_lobby_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Make a room or join one with a code'**
  String get ludoLobbyMakeARoomOrJoin;

  /// features/ludo/presentation/screens/ludo_lobby_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Play offline'**
  String get ludoLobbyPlayOffline;

  /// features/ludo/presentation/screens/ludo_lobby_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Bots, or friends taking turns on this phone'**
  String get ludoLobbyBotsOrFriendsTakingTurns;

  /// features/ludo/presentation/screens/ludo_lobby_screen.dart
  ///
  /// In en, this message translates to:
  /// **'2 to 6\nplayers'**
  String get ludoLobby2To6Players;

  /// features/ludo/presentation/screens/ludo_lobby_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Timed\nturns'**
  String get ludoLobbyTimedTurns;

  /// features/ludo/presentation/screens/ludo_lobby_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Chat &\nreactions'**
  String get ludoLobbyChatReactions;

  /// features/ludo/presentation/screens/ludo_lobby_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Private\nrooms'**
  String get ludoLobbyPrivateRooms;

  /// features/ludo/presentation/screens/ludo_lobby_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Friends on this phone'**
  String get ludoLobbyFriendsOnThisPhone;

  /// features/ludo/presentation/screens/ludo_lobby_screen.dart
  ///
  /// In en, this message translates to:
  /// **'None'**
  String get ludoLobbyNone;

  /// features/ludo/presentation/screens/ludo_lobby_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Tap a seat to sit there'**
  String get ludoLobbyTapASeatToSit;

  /// features/ludo/presentation/screens/ludo_lobby_screen.dart
  ///
  /// In en, this message translates to:
  /// **'You'**
  String get ludoLobbyYou;

  /// features/ludo/presentation/screens/ludo_lobby_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Start game'**
  String get ludoLobbyStartGame;

  /// features/ludo/presentation/screens/ludo_lobby_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Play'**
  String get ludoLobbyPlay;

  /// features/ludo/presentation/screens/ludo_lobby_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Join room'**
  String get ludoLobbyJoinRoom;

  /// features/ludo/presentation/screens/ludo_lobby_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Classic board'**
  String get ludoLobbyClassicBoard;

  /// features/ludo/presentation/screens/ludo_lobby_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Star board'**
  String get ludoLobbyStarBoard;

  /// features/ludo/presentation/screens/ludo_lobby_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Create room'**
  String get ludoLobbyCreateRoom;

  /// features/ludo/presentation/screens/ludo_lobby_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Create'**
  String get ludoLobbyCreate;

  /// features/ludo/presentation/screens/ludo_lobby_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Join'**
  String get ludoLobbyJoin;

  /// features/ludo/presentation/screens/ludo_lobby_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Finding an opponent'**
  String get ludoLobbyFindingAnOpponent;

  /// features/ludo/presentation/screens/ludo_lobby_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Gathering players'**
  String get ludoLobbyGatheringPlayers;

  /// features/ludo/presentation/screens/ludo_lobby_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Free'**
  String get ludoLobbyFree;

  /// features/ludo/presentation/screens/ludo_lobby_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Play with bots'**
  String get ludoLobbyPlayWithBots;

  /// features/ludo/presentation/screens/ludo_lobby_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get ludoLobbyCancel;

  /// features/guess_doodle/presentation/guess_doodle_lobby_screen.dart
  ///
  /// In en, this message translates to:
  /// **'We couldn\'t find that game. Check the code.'**
  String get guessDoodleLobbyWeCouldnTFindThat;

  /// features/guess_doodle/presentation/guess_doodle_lobby_screen.dart
  ///
  /// In en, this message translates to:
  /// **'That game is full.'**
  String get guessDoodleLobbyThatGameIsFull;

  /// features/guess_doodle/presentation/guess_doodle_lobby_screen.dart
  ///
  /// In en, this message translates to:
  /// **'That game has ended.'**
  String get guessDoodleLobbyThatGameHasEnded;

  /// features/guess_doodle/presentation/guess_doodle_lobby_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Finding a game'**
  String get guessDoodleLobbyFindingAGame;

  /// features/guess_doodle/presentation/guess_doodle_lobby_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Guess My Doodle'**
  String get guessDoodleLobbyGuessMyDoodle;

  /// features/guess_doodle/presentation/guess_doodle_lobby_screen.dart
  ///
  /// In en, this message translates to:
  /// **'How to play'**
  String get guessDoodleLobbyHowToPlay;

  /// features/guess_doodle/presentation/guess_doodle_lobby_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Play online'**
  String get guessDoodleLobbyPlayOnline;

  /// features/guess_doodle/presentation/guess_doodle_lobby_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Jump into a game with players anywhere'**
  String get guessDoodleLobbyJumpIntoAGameWith;

  /// features/guess_doodle/presentation/guess_doodle_lobby_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Play with friends'**
  String get guessDoodleLobbyPlayWithFriends;

  /// features/guess_doodle/presentation/guess_doodle_lobby_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Make a game or join one with a code'**
  String get guessDoodleLobbyMakeAGameOrJoin;

  /// features/guess_doodle/presentation/guess_doodle_lobby_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Chip draws, you guess'**
  String get guessDoodleLobbyChipDrawsYouGuess;

  /// features/guess_doodle/presentation/guess_doodle_lobby_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Guess his doodles on your own'**
  String get guessDoodleLobbyGuessHisDoodlesOnYour;

  /// features/guess_doodle/presentation/guess_doodle_lobby_screen.dart
  ///
  /// In en, this message translates to:
  /// **'1 to 20\nplayers'**
  String get guessDoodleLobby1To20Players;

  /// features/guess_doodle/presentation/guess_doodle_lobby_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Draw &\nguess'**
  String get guessDoodleLobbyDrawGuess;

  /// features/guess_doodle/presentation/guess_doodle_lobby_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Faster guess,\nmore points'**
  String get guessDoodleLobbyFasterGuessMorePoints;

  /// features/guess_doodle/presentation/guess_doodle_lobby_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Private\ngames'**
  String get guessDoodleLobbyPrivateGames;

  /// features/guess_doodle/presentation/guess_doodle_lobby_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Join game'**
  String get guessDoodleLobbyJoinGame;

  /// features/guess_doodle/presentation/guess_doodle_lobby_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Rounds'**
  String get guessDoodleLobbyRounds;

  /// features/guess_doodle/presentation/guess_doodle_lobby_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Time to draw'**
  String get guessDoodleLobbyTimeToDraw;

  /// features/guess_doodle/presentation/guess_doodle_lobby_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Create game'**
  String get guessDoodleLobbyCreateGame;

  /// features/guess_doodle/presentation/guess_doodle_lobby_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Create'**
  String get guessDoodleLobbyCreate;

  /// features/guess_doodle/presentation/guess_doodle_lobby_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Join'**
  String get guessDoodleLobbyJoin;

  /// features/guess_doodle/presentation/guess_doodle_lobby_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Take turns drawing'**
  String get guessDoodleLobbyTakeTurnsDrawing;

  /// features/guess_doodle/presentation/guess_doodle_lobby_screen.dart
  ///
  /// In en, this message translates to:
  /// **'One player picks a word from three and draws it. No letters or numbers in the drawing.'**
  String get guessDoodleLobbyOnePlayerPicksAWord;

  /// features/guess_doodle/presentation/guess_doodle_lobby_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Guess in the chat'**
  String get guessDoodleLobbyGuessInTheChat;

  /// features/guess_doodle/presentation/guess_doodle_lobby_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Everyone else types guesses. A right guess is never shown to the others, and \"so close\" tells only you when you nearly have it.'**
  String get guessDoodleLobbyEveryoneElseTypesGuessesA;

  /// features/guess_doodle/presentation/guess_doodle_lobby_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Be quick'**
  String get guessDoodleLobbyBeQuick;

  /// features/guess_doodle/presentation/guess_doodle_lobby_screen.dart
  ///
  /// In en, this message translates to:
  /// **'The sooner you guess, the more points you get, with a bonus for the first. The drawer scores for everyone who gets it.'**
  String get guessDoodleLobbyTheSoonerYouGuessThe;

  /// features/guess_doodle/presentation/guess_doodle_lobby_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Hints'**
  String get guessDoodleLobbyHints;

  /// features/guess_doodle/presentation/guess_doodle_lobby_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Letters of the word appear as the clock runs down.'**
  String get guessDoodleLobbyLettersOfTheWordAppear;

  /// features/guess_doodle/presentation/guess_doodle_lobby_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Win'**
  String get guessDoodleLobbyWin;

  /// features/guess_doodle/presentation/guess_doodle_lobby_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Everyone draws once each round. The most points after the last round wins.'**
  String get guessDoodleLobbyEveryoneDrawsOnceEachRound;

  /// features/guess_doodle/presentation/guess_doodle_lobby_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Got it'**
  String get guessDoodleLobbyGotIt;

  /// features/doodle_studio/presentation/studio_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t open this one.'**
  String get studioCouldnTOpenThisOne;

  /// features/doodle_studio/presentation/studio_screen.dart
  ///
  /// In en, this message translates to:
  /// **'I\'ve colored lots today. Ask me again tomorrow!'**
  String get studioIVeColoredLotsToday;

  /// features/doodle_studio/presentation/studio_screen.dart
  ///
  /// In en, this message translates to:
  /// **'I can\'t color that one.'**
  String get studioICanTColorThat;

  /// features/doodle_studio/presentation/studio_screen.dart
  ///
  /// In en, this message translates to:
  /// **'My paintbrush isn\'t ready yet.'**
  String get studioMyPaintbrushIsnTReady;

  /// features/doodle_studio/presentation/studio_screen.dart
  ///
  /// In en, this message translates to:
  /// **'I couldn\'t color it just now. Try again?'**
  String get studioICouldnTColorIt;

  /// features/doodle_studio/presentation/studio_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Allow Utopia to add to your photos in Settings, then try again.'**
  String get studioAllowUtopiaToAddTo;

  /// features/doodle_studio/presentation/studio_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Saved to your photos'**
  String get studioSavedToYourPhotos;

  /// features/doodle_studio/presentation/studio_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t save to your photos. Try again.'**
  String get studioCouldnTSaveToYour;

  /// features/doodle_studio/presentation/studio_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Keep it'**
  String get studioKeepIt;

  /// features/doodle_studio/presentation/studio_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Start over?'**
  String get studioStartOver;

  /// features/doodle_studio/presentation/studio_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Everything on this page will be cleared.'**
  String get studioEverythingOnThisPageWill;

  /// features/doodle_studio/presentation/studio_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Clear it'**
  String get studioClearIt;

  /// features/doodle_studio/presentation/studio_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Delete this?'**
  String get studioDeleteThis;

  /// features/doodle_studio/presentation/studio_screen.dart
  ///
  /// In en, this message translates to:
  /// **'It\'ll be gone from your sketchbook for good.'**
  String get studioItLlBeGoneFrom;

  /// features/doodle_studio/presentation/studio_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get studioDelete;

  /// features/doodle_studio/presentation/studio_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Sketchbook'**
  String get studioSketchbook;

  /// features/doodle_studio/presentation/studio_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Coloring'**
  String get studioColoring;

  /// features/doodle_studio/presentation/studio_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Sketch'**
  String get studioSketch;

  /// features/doodle_studio/presentation/studio_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get studioBack;

  /// features/doodle_studio/presentation/studio_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t save, will try again'**
  String get studioCouldnTSaveWillTry;

  /// features/doodle_studio/presentation/studio_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Saved in Utopia'**
  String get studioSavedInUtopia;

  /// features/doodle_studio/presentation/studio_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Tap a shape to fill it'**
  String get studioTapAShapeToFill;

  /// features/doodle_studio/presentation/studio_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Draw anything'**
  String get studioDrawAnything;

  /// features/doodle_studio/presentation/studio_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Undo'**
  String get studioUndo;

  /// features/doodle_studio/presentation/studio_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Redo'**
  String get studioRedo;

  /// features/doodle_studio/presentation/studio_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Save picture'**
  String get studioSavePicture;

  /// features/doodle_studio/presentation/studio_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Save to Photos'**
  String get studioSaveToPhotos;

  /// features/doodle_studio/presentation/studio_screen.dart
  ///
  /// In en, this message translates to:
  /// **'More'**
  String get studioMore;

  /// features/doodle_studio/presentation/studio_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Start over'**
  String get studioStartOver2;

  /// features/doodle_studio/presentation/studio_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Getting your page ready…'**
  String get studioGettingYourPageReady;

  /// features/doodle_studio/presentation/studio_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Zoom in'**
  String get studioZoomIn;

  /// features/doodle_studio/presentation/studio_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Zoom out'**
  String get studioZoomOut;

  /// features/doodle_studio/presentation/studio_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Fit the page'**
  String get studioFitThePage;

  /// features/doodle_studio/presentation/studio_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Color with Chip'**
  String get studioColorWithChip;

  /// features/doodle_studio/presentation/studio_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Chip is coloring your picture…'**
  String get studioChipIsColoringYourPicture;

  /// features/store/presentation/store_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Store'**
  String get storeStore;

  /// features/store/presentation/store_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Worlds'**
  String get storeWorlds;

  /// features/store/presentation/store_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Auras'**
  String get storeAuras;

  /// features/store/presentation/store_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Ludo'**
  String get storeLudo;

  /// features/store/presentation/store_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Chess'**
  String get storeChess;

  /// features/store/presentation/store_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Save your account so your purchases are never lost.'**
  String get storeSaveYourAccountSoYour;

  /// features/store/presentation/store_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Unlocked!'**
  String get storeUnlocked;

  /// features/store/presentation/store_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Where to first?'**
  String get storeWhereToFirst;

  /// features/store/presentation/store_screen.dart
  ///
  /// In en, this message translates to:
  /// **'You\'re already here'**
  String get storeYouReAlreadyHere;

  /// features/store/presentation/store_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Travel to {name}'**
  String storeTravelTo(Object name);

  /// features/store/presentation/store_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Pick a world'**
  String get storePickAWorld;

  /// features/store/presentation/store_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Equip now'**
  String get storeEquipNow;

  /// features/store/presentation/store_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Later'**
  String get storeLater;

  /// features/store/presentation/store_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Utopia worlds'**
  String get storeUtopiaWorlds;

  /// features/store/presentation/store_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Every world has its own living sky. Changing worlds sends Chip through a portal!'**
  String get storeEveryWorldHasItsOwn;

  /// features/store/presentation/store_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Every World'**
  String get storeEveryWorld;

  /// features/store/presentation/store_screen.dart
  ///
  /// In en, this message translates to:
  /// **'All {value} worlds and {length} colors, now and forever.'**
  String storeAllWorldsAndColorsNow(Object value, Object length);

  /// features/store/presentation/store_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Color worlds'**
  String get storeColorWorlds;

  /// features/store/presentation/store_screen.dart
  ///
  /// In en, this message translates to:
  /// **'12 colors, each at dawn, dusk and midnight.'**
  String get store12ColorsEachAtDawn;

  /// features/store/presentation/store_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Owned'**
  String get storeOwned;

  /// features/store/presentation/store_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Current'**
  String get storeCurrent;

  /// features/store/presentation/store_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Free'**
  String get storeFree;

  /// features/store/presentation/store_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Locked'**
  String get storeLocked;

  /// features/store/presentation/store_screen.dart
  ///
  /// In en, this message translates to:
  /// **'You\'re here'**
  String get storeYouReHere;

  /// features/store/presentation/store_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Travel to this world'**
  String get storeTravelToThisWorld;

  /// features/store/presentation/store_screen.dart
  ///
  /// In en, this message translates to:
  /// **'A week more in {name}'**
  String storeAWeekMoreIn(Object name);

  /// features/store/presentation/store_screen.dart
  ///
  /// In en, this message translates to:
  /// **'or rent it for a week'**
  String get storeOrRentItForA;

  /// features/store/presentation/store_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Rent for a week · {value}'**
  String storeRentForAWeek(Object value);

  /// features/store/presentation/store_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Add a week · {value}'**
  String storeAddAWeek(Object value);

  /// features/store/presentation/store_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Pack · {value}'**
  String storePack(Object value);

  /// features/store/presentation/store_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Equipped'**
  String get storeEquipped;

  /// features/store/presentation/store_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Equipping'**
  String get storeEquipping;

  /// features/store/presentation/store_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Equip'**
  String get storeEquip;

  /// features/store/presentation/store_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Animated'**
  String get storeAnimated;

  /// features/chess/presentation/screens/chess_lobby_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Save your account so friends can find you.'**
  String get chessLobbySaveYourAccountSoFriends;

  /// features/chess/presentation/screens/chess_lobby_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Checkers'**
  String get chessLobbyCheckers;

  /// features/chess/presentation/screens/chess_lobby_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Chess'**
  String get chessLobbyChess;

  /// features/chess/presentation/screens/chess_lobby_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Clock'**
  String get chessLobbyClock;

  /// features/chess/presentation/screens/chess_lobby_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Entry'**
  String get chessLobbyEntry;

  /// features/chess/presentation/screens/chess_lobby_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Play online'**
  String get chessLobbyPlayOnline;

  /// features/chess/presentation/screens/chess_lobby_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Get matched with a player now'**
  String get chessLobbyGetMatchedWithAPlayer;

  /// features/chess/presentation/screens/chess_lobby_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Play a friend'**
  String get chessLobbyPlayAFriend;

  /// features/chess/presentation/screens/chess_lobby_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Send a challenge to someone you know'**
  String get chessLobbySendAChallengeToSomeone;

  /// features/chess/presentation/screens/chess_lobby_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Play offline'**
  String get chessLobbyPlayOffline;

  /// features/chess/presentation/screens/chess_lobby_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Chip, Robo or a friend on this phone'**
  String get chessLobbyChipRoboOrAFriend;

  /// features/chess/presentation/screens/chess_lobby_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Opponent'**
  String get chessLobbyOpponent;

  /// features/chess/presentation/screens/chess_lobby_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Chip'**
  String get chessLobbyChip;

  /// features/chess/presentation/screens/chess_lobby_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Robo'**
  String get chessLobbyRobo;

  /// features/chess/presentation/screens/chess_lobby_screen.dart
  ///
  /// In en, this message translates to:
  /// **'A friend'**
  String get chessLobbyAFriend;

  /// features/chess/presentation/screens/chess_lobby_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Two players on this phone, taking turns.'**
  String get chessLobbyTwoPlayersOnThisPhone;

  /// features/chess/presentation/screens/chess_lobby_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Level'**
  String get chessLobbyLevel;

  /// features/chess/presentation/screens/chess_lobby_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Easy'**
  String get chessLobbyEasy;

  /// features/chess/presentation/screens/chess_lobby_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Normal'**
  String get chessLobbyNormal;

  /// features/chess/presentation/screens/chess_lobby_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Hard'**
  String get chessLobbyHard;

  /// features/chess/presentation/screens/chess_lobby_screen.dart
  ///
  /// In en, this message translates to:
  /// **'You play'**
  String get chessLobbyYouPlay;

  /// features/chess/presentation/screens/chess_lobby_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Dark'**
  String get chessLobbyDark;

  /// features/chess/presentation/screens/chess_lobby_screen.dart
  ///
  /// In en, this message translates to:
  /// **'White'**
  String get chessLobbyWhite;

  /// features/chess/presentation/screens/chess_lobby_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Random'**
  String get chessLobbyRandom;

  /// features/chess/presentation/screens/chess_lobby_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get chessLobbyLight;

  /// features/chess/presentation/screens/chess_lobby_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Black'**
  String get chessLobbyBlack;

  /// features/chess/presentation/screens/chess_lobby_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Dark moves first.'**
  String get chessLobbyDarkMovesFirst;

  /// features/chess/presentation/screens/chess_lobby_screen.dart
  ///
  /// In en, this message translates to:
  /// **'No clock'**
  String get chessLobbyNoClock;

  /// features/chess/presentation/screens/chess_lobby_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Start game'**
  String get chessLobbyStartGame;

  /// features/chess/presentation/screens/chess_lobby_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Finding an opponent'**
  String get chessLobbyFindingAnOpponent;

  /// features/chess/presentation/screens/chess_lobby_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Free'**
  String get chessLobbyFree;

  /// features/chess/presentation/screens/chess_lobby_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Play Chip'**
  String get chessLobbyPlayChip;

  /// features/chess/presentation/screens/chess_lobby_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get chessLobbyCancel;

  /// features/ludo/presentation/screens/ludo_room_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Someone needs more coins for this game.'**
  String get ludoRoomSomeoneNeedsMoreCoinsFor;

  /// features/ludo/presentation/screens/ludo_room_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Wait for at least one friend to join.'**
  String get ludoRoomWaitForAtLeastOne;

  /// features/ludo/presentation/screens/ludo_room_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t start the game. Try again.'**
  String get ludoRoomCouldnTStartTheGame;

  /// features/ludo/presentation/screens/ludo_room_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Someone just took that seat.'**
  String get ludoRoomSomeoneJustTookThatSeat;

  /// features/ludo/presentation/screens/ludo_room_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t change seats. Try again.'**
  String get ludoRoomCouldnTChangeSeatsTry;

  /// features/ludo/presentation/screens/ludo_room_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Code copied'**
  String get ludoRoomCodeCopied;

  /// features/ludo/presentation/screens/ludo_room_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Come play Ludo with me in Utopia! Tap to join, or use room code {code}: {value}'**
  String ludoRoomComePlayLudoWithMe(Object code, Object value);

  /// features/ludo/presentation/screens/ludo_room_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Ludo in Utopia'**
  String get ludoRoomLudoInUtopia;

  /// features/ludo/presentation/screens/ludo_room_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Opening the room'**
  String get ludoRoomOpeningTheRoom;

  /// features/ludo/presentation/screens/ludo_room_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Private room'**
  String get ludoRoomPrivateRoom;

  /// features/ludo/presentation/screens/ludo_room_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Share code'**
  String get ludoRoomShareCode;

  /// features/ludo/presentation/screens/ludo_room_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Players'**
  String get ludoRoomPlayers;

  /// features/ludo/presentation/screens/ludo_room_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Start game'**
  String get ludoRoomStartGame;

  /// features/ludo/presentation/screens/ludo_room_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Waiting for friends'**
  String get ludoRoomWaitingForFriends;

  /// features/ludo/presentation/screens/ludo_room_screen.dart
  ///
  /// In en, this message translates to:
  /// **'The host will start the game'**
  String get ludoRoomTheHostWillStartThe;

  /// features/ludo/presentation/screens/ludo_room_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Close room'**
  String get ludoRoomCloseRoom;

  /// features/ludo/presentation/screens/ludo_room_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Leave room'**
  String get ludoRoomLeaveRoom;

  /// features/ludo/presentation/screens/ludo_room_screen.dart
  ///
  /// In en, this message translates to:
  /// **'ROOM CODE'**
  String get ludoRoomRoomCode;

  /// features/ludo/presentation/screens/ludo_room_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Copy'**
  String get ludoRoomCopy;

  /// features/ludo/presentation/screens/ludo_room_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Share'**
  String get ludoRoomShare;

  /// features/ludo/presentation/screens/ludo_room_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Classic'**
  String get ludoRoomClassic;

  /// features/ludo/presentation/screens/ludo_room_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Star board'**
  String get ludoRoomStarBoard;

  /// features/ludo/presentation/screens/ludo_room_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Free'**
  String get ludoRoomFree;

  /// features/ludo/presentation/screens/ludo_room_screen.dart
  ///
  /// In en, this message translates to:
  /// **'40s turns'**
  String get ludoRoom40sTurns;

  /// features/ludo/presentation/screens/ludo_room_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Seat'**
  String get ludoRoomSeat;

  /// features/ludo/presentation/screens/ludo_room_screen.dart
  ///
  /// In en, this message translates to:
  /// **'You'**
  String get ludoRoomYou;

  /// features/ludo/presentation/screens/ludo_room_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Take this seat'**
  String get ludoRoomTakeThisSeat;

  /// features/ludo/presentation/screens/ludo_room_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Play as {name}'**
  String ludoRoomPlayAs(Object name);

  /// features/ludo/presentation/screens/ludo_room_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Share invite'**
  String get ludoRoomShareInvite;

  /// features/ludo/presentation/screens/ludo_room_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Send the room code to a friend'**
  String get ludoRoomSendTheRoomCodeTo;

  /// features/doodle_studio/presentation/sketchbook_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get sketchbookBack;

  /// features/doodle_studio/presentation/sketchbook_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Sketchbook'**
  String get sketchbookSketchbook;

  /// features/doodle_studio/presentation/sketchbook_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Draw anything, or color a picture. Everything saves as you go.'**
  String get sketchbookDrawAnythingOrColorA;

  /// features/doodle_studio/presentation/sketchbook_screen.dart
  ///
  /// In en, this message translates to:
  /// **'New sketch'**
  String get sketchbookNewSketch;

  /// features/doodle_studio/presentation/sketchbook_screen.dart
  ///
  /// In en, this message translates to:
  /// **'A blank page'**
  String get sketchbookABlankPage;

  /// features/doodle_studio/presentation/sketchbook_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Color a picture'**
  String get sketchbookColorAPicture;

  /// features/doodle_studio/presentation/sketchbook_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Or search any picture'**
  String get sketchbookOrSearchAnyPicture;

  /// features/doodle_studio/presentation/sketchbook_screen.dart
  ///
  /// In en, this message translates to:
  /// **'My art'**
  String get sketchbookMyArt;

  /// features/doodle_studio/presentation/sketchbook_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Nothing here yet. What you draw and color shows up here.'**
  String get sketchbookNothingHereYetWhatYou;

  /// features/doodle_studio/presentation/sketchbook_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Delete this?'**
  String get sketchbookDeleteThis;

  /// features/doodle_studio/presentation/sketchbook_screen.dart
  ///
  /// In en, this message translates to:
  /// **'It\'ll be gone from your sketchbook for good.'**
  String get sketchbookItLlBeGoneFrom;

  /// features/doodle_studio/presentation/sketchbook_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Keep it'**
  String get sketchbookKeepIt;

  /// features/doodle_studio/presentation/sketchbook_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get sketchbookDelete;

  /// features/doodle_studio/presentation/sketchbook_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t open that one. Try again?'**
  String get sketchbookCouldnTOpenThatOne;

  /// features/doodle_studio/presentation/sketchbook_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Chip\'s drawing it. It\'ll be in Yours in about a minute.'**
  String get sketchbookChipSDrawingItIt;

  /// features/doodle_studio/presentation/sketchbook_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Chip can\'t draw that one. Try something else?'**
  String get sketchbookChipCanTDrawThat;

  /// features/doodle_studio/presentation/sketchbook_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Chip has drawn all he can today. Ask again tomorrow!'**
  String get sketchbookChipHasDrawnAllHe;

  /// features/doodle_studio/presentation/sketchbook_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Chip\'s pencil isn\'t ready yet. Try again later.'**
  String get sketchbookChipSPencilIsnT;

  /// features/doodle_studio/presentation/sketchbook_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t reach Chip. Check your connection and try again.'**
  String get sketchbookCouldnTReachChipCheck;

  /// features/doodle_studio/presentation/sketchbook_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Pick a picture to color'**
  String get sketchbookPickAPictureToColor;

  /// features/doodle_studio/presentation/sketchbook_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Yours'**
  String get sketchbookYours;

  /// features/doodle_studio/presentation/sketchbook_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Drawn for players'**
  String get sketchbookDrawnForPlayers;

  /// features/doodle_studio/presentation/sketchbook_screen.dart
  ///
  /// In en, this message translates to:
  /// **'From the library'**
  String get sketchbookFromTheLibrary;

  /// features/doodle_studio/presentation/sketchbook_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Search any picture: a lion, a castle...'**
  String get sketchbookSearchAnyPictureALion;

  /// features/doodle_studio/presentation/sketchbook_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Didn\'t work out'**
  String get sketchbookDidnTWorkOut;

  /// features/doodle_studio/presentation/sketchbook_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Chip is drawing...'**
  String get sketchbookChipIsDrawing;

  /// features/doodle_studio/presentation/sketchbook_screen.dart
  ///
  /// In en, this message translates to:
  /// **'New picture'**
  String get sketchbookNewPicture;

  /// features/doodle_studio/presentation/sketchbook_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Nobody has asked for that yet.'**
  String get sketchbookNobodyHasAskedForThat;

  /// features/doodle_studio/presentation/sketchbook_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Asking Chip...'**
  String get sketchbookAskingChip;

  /// features/doodle_studio/presentation/sketchbook_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Ask Chip to draw \"{subject}\"'**
  String sketchbookAskChipToDraw(Object subject);

  /// features/doodle_studio/presentation/sketchbook_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Not quite? Ask Chip to draw \"{subject}\"'**
  String sketchbookNotQuiteAskChipTo(Object subject);

  /// features/guess_doodle/presentation/widgets/doodle_overlays.dart
  ///
  /// In en, this message translates to:
  /// **'Starting soon'**
  String get doodleOverlaysStartingSoon;

  /// features/guess_doodle/presentation/widgets/doodle_overlays.dart
  ///
  /// In en, this message translates to:
  /// **'Finding players'**
  String get doodleOverlaysFindingPlayers;

  /// features/guess_doodle/presentation/widgets/doodle_overlays.dart
  ///
  /// In en, this message translates to:
  /// **'The game starts when someone else joins.'**
  String get doodleOverlaysTheGameStartsWhenSomeone;

  /// features/guess_doodle/presentation/widgets/doodle_overlays.dart
  ///
  /// In en, this message translates to:
  /// **'Invite friends'**
  String get doodleOverlaysInviteFriends;

  /// features/guess_doodle/presentation/widgets/doodle_overlays.dart
  ///
  /// In en, this message translates to:
  /// **'Copy'**
  String get doodleOverlaysCopy;

  /// features/guess_doodle/presentation/widgets/doodle_overlays.dart
  ///
  /// In en, this message translates to:
  /// **'Share'**
  String get doodleOverlaysShare;

  /// features/guess_doodle/presentation/widgets/doodle_overlays.dart
  ///
  /// In en, this message translates to:
  /// **'{length} of {maxPlayers} players'**
  String doodleOverlaysOfPlayers(Object length, Object maxPlayers);

  /// features/guess_doodle/presentation/widgets/doodle_overlays.dart
  ///
  /// In en, this message translates to:
  /// **'Start game'**
  String get doodleOverlaysStartGame;

  /// features/guess_doodle/presentation/widgets/doodle_overlays.dart
  ///
  /// In en, this message translates to:
  /// **'Waiting for friends'**
  String get doodleOverlaysWaitingForFriends;

  /// features/guess_doodle/presentation/widgets/doodle_overlays.dart
  ///
  /// In en, this message translates to:
  /// **'Waiting for {value} to start'**
  String doodleOverlaysWaitingForToStart(Object value);

  /// features/guess_doodle/presentation/widgets/doodle_overlays.dart
  ///
  /// In en, this message translates to:
  /// **'Starting in {s}'**
  String doodleOverlaysStartingIn(Object s);

  /// features/guess_doodle/presentation/widgets/doodle_overlays.dart
  ///
  /// In en, this message translates to:
  /// **'Here we go'**
  String get doodleOverlaysHereWeGo;

  /// features/guess_doodle/presentation/widgets/doodle_overlays.dart
  ///
  /// In en, this message translates to:
  /// **'{value} is picking a word'**
  String doodleOverlaysIsPickingAWord(Object value);

  /// features/guess_doodle/presentation/widgets/doodle_overlays.dart
  ///
  /// In en, this message translates to:
  /// **'Get ready to guess'**
  String get doodleOverlaysGetReadyToGuess;

  /// features/guess_doodle/presentation/widgets/doodle_overlays.dart
  ///
  /// In en, this message translates to:
  /// **'Pick a word to draw'**
  String get doodleOverlaysPickAWordToDraw;

  /// features/guess_doodle/presentation/widgets/doodle_overlays.dart
  ///
  /// In en, this message translates to:
  /// **'Nobody got it'**
  String get doodleOverlaysNobodyGotIt;

  /// features/guess_doodle/presentation/widgets/doodle_overlays.dart
  ///
  /// In en, this message translates to:
  /// **'The word was'**
  String get doodleOverlaysTheWordWas;

  /// features/guess_doodle/presentation/widgets/doodle_overlays.dart
  ///
  /// In en, this message translates to:
  /// **'You won!'**
  String get doodleOverlaysYouWon;

  /// features/guess_doodle/presentation/widgets/doodle_overlays.dart
  ///
  /// In en, this message translates to:
  /// **'Final scores'**
  String get doodleOverlaysFinalScores;

  /// features/guess_doodle/presentation/widgets/doodle_overlays.dart
  ///
  /// In en, this message translates to:
  /// **'Play again'**
  String get doodleOverlaysPlayAgain;

  /// features/guess_doodle/presentation/widgets/doodle_overlays.dart
  ///
  /// In en, this message translates to:
  /// **'The host can start another game'**
  String get doodleOverlaysTheHostCanStartAnother;

  /// features/guess_doodle/presentation/widgets/doodle_overlays.dart
  ///
  /// In en, this message translates to:
  /// **'Leave'**
  String get doodleOverlaysLeave;

  /// features/guess_doodle/presentation/widgets/doodle_overlays.dart
  ///
  /// In en, this message translates to:
  /// **'Next game in {s}'**
  String doodleOverlaysNextGameIn(Object s);

  /// features/guess_doodle/presentation/widgets/doodle_overlays.dart
  ///
  /// In en, this message translates to:
  /// **'Next game starting'**
  String get doodleOverlaysNextGameStarting;

  /// features/guess_doodle/presentation/widgets/doodle_overlays.dart
  ///
  /// In en, this message translates to:
  /// **'This game has ended'**
  String get doodleOverlaysThisGameHasEnded;

  /// features/guess_doodle/presentation/widgets/doodle_overlays.dart
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get doodleOverlaysBack;

  /// features/guess_doodle/presentation/widgets/doodle_overlays.dart
  ///
  /// In en, this message translates to:
  /// **'and {count} more'**
  String doodleOverlaysAndMore(Object count);

  /// features/chess/presentation/widgets/board_match_parts.dart
  ///
  /// In en, this message translates to:
  /// **'Chat'**
  String get boardMatchPartsChat;

  /// features/chess/presentation/widgets/board_match_parts.dart
  ///
  /// In en, this message translates to:
  /// **'Previous move'**
  String get boardMatchPartsPreviousMove;

  /// features/chess/presentation/widgets/board_match_parts.dart
  ///
  /// In en, this message translates to:
  /// **'Moves will show up here'**
  String get boardMatchPartsMovesWillShowUpHere;

  /// features/chess/presentation/widgets/board_match_parts.dart
  ///
  /// In en, this message translates to:
  /// **'Start'**
  String get boardMatchPartsStart;

  /// features/chess/presentation/widgets/board_match_parts.dart
  ///
  /// In en, this message translates to:
  /// **'Next move'**
  String get boardMatchPartsNextMove;

  /// features/chess/presentation/widgets/board_match_parts.dart
  ///
  /// In en, this message translates to:
  /// **'Your win'**
  String get boardMatchPartsYourWin;

  /// features/chess/presentation/widgets/board_match_parts.dart
  ///
  /// In en, this message translates to:
  /// **'Result'**
  String get boardMatchPartsResult;

  /// features/chess/presentation/widgets/board_match_parts.dart
  ///
  /// In en, this message translates to:
  /// **'Play again'**
  String get boardMatchPartsPlayAgain;

  /// features/chess/presentation/widgets/board_match_parts.dart
  ///
  /// In en, this message translates to:
  /// **'Under review'**
  String get boardMatchPartsUnderReview;

  /// features/chess/presentation/widgets/board_match_parts.dart
  ///
  /// In en, this message translates to:
  /// **'Called off'**
  String get boardMatchPartsCalledOff;

  /// features/chess/presentation/widgets/board_match_parts.dart
  ///
  /// In en, this message translates to:
  /// **'Victory!'**
  String get boardMatchPartsVictory;

  /// features/chess/presentation/widgets/board_match_parts.dart
  ///
  /// In en, this message translates to:
  /// **'Defeat'**
  String get boardMatchPartsDefeat;

  /// features/chess/presentation/widgets/board_match_parts.dart
  ///
  /// In en, this message translates to:
  /// **'Draw'**
  String get boardMatchPartsDraw;

  /// features/chess/presentation/widgets/board_match_parts.dart
  ///
  /// In en, this message translates to:
  /// **'You and your opponent reported different results. We\'ll sort it out.'**
  String get boardMatchPartsYouAndYourOpponentReported;

  /// features/chess/presentation/widgets/board_match_parts.dart
  ///
  /// In en, this message translates to:
  /// **'Your opponent resigned.'**
  String get boardMatchPartsYourOpponentResigned;

  /// features/chess/presentation/widgets/board_match_parts.dart
  ///
  /// In en, this message translates to:
  /// **'You resigned.'**
  String get boardMatchPartsYouResigned;

  /// features/chess/presentation/widgets/board_match_parts.dart
  ///
  /// In en, this message translates to:
  /// **'Nobody can win from here.'**
  String get boardMatchPartsNobodyCanWinFromHere;

  /// features/chess/presentation/widgets/board_match_parts.dart
  ///
  /// In en, this message translates to:
  /// **'Their clock ran out.'**
  String get boardMatchPartsTheirClockRanOut;

  /// features/chess/presentation/widgets/board_match_parts.dart
  ///
  /// In en, this message translates to:
  /// **'Your clock ran out.'**
  String get boardMatchPartsYourClockRanOut;

  /// features/chess/presentation/widgets/board_match_parts.dart
  ///
  /// In en, this message translates to:
  /// **'A first move didn\'t come in time. Your coins are back.'**
  String get boardMatchPartsAFirstMoveDidnT;

  /// features/chess/presentation/widgets/board_match_parts.dart
  ///
  /// In en, this message translates to:
  /// **'A first move didn\'t come in time.'**
  String get boardMatchPartsAFirstMoveDidnT2;

  /// features/chess/presentation/widgets/board_match_parts.dart
  ///
  /// In en, this message translates to:
  /// **'Sending your prize'**
  String get boardMatchPartsSendingYourPrize;

  /// features/chess/presentation/widgets/board_match_parts.dart
  ///
  /// In en, this message translates to:
  /// **'Wrapping up'**
  String get boardMatchPartsWrappingUp;

  /// features/chess/presentation/widgets/board_match_parts.dart
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get boardMatchPartsHome;

  /// features/chess/presentation/widgets/board_match_parts.dart
  ///
  /// In en, this message translates to:
  /// **'Review the game'**
  String get boardMatchPartsReviewTheGame;

  /// features/chess/presentation/widgets/board_match_parts.dart
  ///
  /// In en, this message translates to:
  /// **'Rating {round}'**
  String boardMatchPartsRating(Object round);

  /// features/chess/presentation/widgets/board_match_parts.dart
  ///
  /// In en, this message translates to:
  /// **'You'**
  String get boardMatchPartsYou;

  /// features/chess/presentation/widgets/board_match_parts.dart
  ///
  /// In en, this message translates to:
  /// **'Opponent'**
  String get boardMatchPartsOpponent;

  /// features/guess_doodle/presentation/chip_doodle_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Hmm, what shall I draw?'**
  String get chipDoodleHmmWhatShallIDraw;

  /// features/guess_doodle/presentation/chip_doodle_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Oops, my pencil broke!'**
  String get chipDoodleOopsMyPencilBroke;

  /// features/guess_doodle/presentation/chip_doodle_screen.dart
  ///
  /// In en, this message translates to:
  /// **'You got it! +{lastPoints}'**
  String chipDoodleYouGotIt(Object lastPoints);

  /// features/guess_doodle/presentation/chip_doodle_screen.dart
  ///
  /// In en, this message translates to:
  /// **'It was {value}!'**
  String chipDoodleItWas(Object value);

  /// features/guess_doodle/presentation/chip_doodle_screen.dart
  ///
  /// In en, this message translates to:
  /// **'What a game!'**
  String get chipDoodleWhatAGame;

  /// features/guess_doodle/presentation/chip_doodle_screen.dart
  ///
  /// In en, this message translates to:
  /// **'So close! Keep going.'**
  String get chipDoodleSoCloseKeepGoing;

  /// features/guess_doodle/presentation/chip_doodle_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Quick, time is nearly up!'**
  String get chipDoodleQuickTimeIsNearlyUp;

  /// features/guess_doodle/presentation/chip_doodle_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Here\'s a little hint!'**
  String get chipDoodleHereSALittleHint;

  /// features/guess_doodle/presentation/chip_doodle_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Nope! Look again.'**
  String get chipDoodleNopeLookAgain;

  /// features/guess_doodle/presentation/chip_doodle_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Watch closely...'**
  String get chipDoodleWatchClosely;

  /// features/guess_doodle/presentation/chip_doodle_screen.dart
  ///
  /// In en, this message translates to:
  /// **'What do you think it is?'**
  String get chipDoodleWhatDoYouThinkIt;

  /// features/guess_doodle/presentation/chip_doodle_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Chip draws'**
  String get chipDoodleChipDraws;

  /// features/guess_doodle/presentation/chip_doodle_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Chip couldn\'t draw just now.'**
  String get chipDoodleChipCouldnTDrawJust;

  /// features/guess_doodle/presentation/chip_doodle_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Try again'**
  String get chipDoodleTryAgain;

  /// features/guess_doodle/presentation/chip_doodle_screen.dart
  ///
  /// In en, this message translates to:
  /// **'See your score'**
  String get chipDoodleSeeYourScore;

  /// features/guess_doodle/presentation/chip_doodle_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Next doodle'**
  String get chipDoodleNextDoodle;

  /// features/guess_doodle/presentation/chip_doodle_screen.dart
  ///
  /// In en, this message translates to:
  /// **'New best score!'**
  String get chipDoodleNewBestScore;

  /// features/guess_doodle/presentation/chip_doodle_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Great guessing!'**
  String get chipDoodleGreatGuessing;

  /// features/guess_doodle/presentation/chip_doodle_screen.dart
  ///
  /// In en, this message translates to:
  /// **'You guessed {guessedCount} of {rounds}'**
  String chipDoodleYouGuessedOf(Object guessedCount, Object rounds);

  /// features/guess_doodle/presentation/chip_doodle_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Your best: {best}'**
  String chipDoodleYourBest(Object best);

  /// features/guess_doodle/presentation/chip_doodle_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Play again'**
  String get chipDoodlePlayAgain;

  /// features/guess_doodle/presentation/chip_doodle_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get chipDoodleDone;

  /// features/guess_doodle/presentation/chip_doodle_screen.dart
  ///
  /// In en, this message translates to:
  /// **'{text} · so close!'**
  String chipDoodleSoClose(Object text);

  /// features/guess_doodle/presentation/chip_doodle_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Type your guess'**
  String get chipDoodleTypeYourGuess;

  /// features/guess_doodle/presentation/chip_doodle_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Get ready...'**
  String get chipDoodleGetReady;

  /// features/guess_doodle/presentation/chip_doodle_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Guess'**
  String get chipDoodleGuess;

  /// features/guess_doodle/presentation/chip_doodle_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Skip this one'**
  String get chipDoodleSkipThisOne;

  /// features/chess/presentation/screens/chess_match_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Setting up the board'**
  String get chessMatchSettingUpTheBoard;

  /// features/chess/presentation/screens/chess_match_screen.dart
  ///
  /// In en, this message translates to:
  /// **'We couldn\'t find this game.'**
  String get chessMatchWeCouldnTFindThis;

  /// features/chess/presentation/screens/chess_match_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Leave game'**
  String get chessMatchLeaveGame;

  /// features/chess/presentation/screens/chess_match_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get chessMatchClose;

  /// features/chess/presentation/screens/chess_match_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Resign'**
  String get chessMatchResign;

  /// features/chess/presentation/screens/chess_match_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Checkmate. Beautifully played.'**
  String get chessMatchCheckmateBeautifullyPlayed;

  /// features/chess/presentation/screens/chess_match_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Checkmated.'**
  String get chessMatchCheckmated;

  /// features/chess/presentation/screens/chess_match_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Stalemate: no legal moves left.'**
  String get chessMatchStalemateNoLegalMovesLeft;

  /// features/chess/presentation/screens/chess_match_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Resign this game?'**
  String get chessMatchResignThisGame;

  /// features/chess/presentation/screens/chess_match_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Your opponent wins the game and the prize.'**
  String get chessMatchYourOpponentWinsTheGame;

  /// features/chess/presentation/screens/chess_match_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Your opponent wins the game.'**
  String get chessMatchYourOpponentWinsTheGame2;

  /// features/chess/presentation/screens/chess_match_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Keep playing'**
  String get chessMatchKeepPlaying;

  /// features/chess/presentation/screens/chess_match_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Chess'**
  String get chessMatchChess;

  /// features/chess/presentation/screens/chess_match_screen.dart
  ///
  /// In en, this message translates to:
  /// **'You'**
  String get chessMatchYou;

  /// features/chess/presentation/screens/chess_match_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Opponent'**
  String get chessMatchOpponent;

  /// features/chess/presentation/screens/chess_match_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Starting position'**
  String get chessMatchStartingPosition;

  /// features/chess/presentation/screens/chess_match_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Move {displayPly} of {length}'**
  String chessMatchMoveOf(Object displayPly, Object length);

  /// features/chess/presentation/screens/chess_match_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Back to live'**
  String get chessMatchBackToLive;

  /// features/chess/presentation/screens/chess_match_screen.dart
  ///
  /// In en, this message translates to:
  /// **'You\'re in check'**
  String get chessMatchYouReInCheck;

  /// features/chess/presentation/screens/chess_match_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Check!'**
  String get chessMatchCheck;

  /// features/chess/presentation/screens/chess_match_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Your move · {value}s to start'**
  String chessMatchYourMoveSToStart(Object value);

  /// features/chess/presentation/screens/chess_match_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Your move'**
  String get chessMatchYourMove;

  /// features/chess/presentation/screens/chess_match_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Waiting for the first move · {value}s'**
  String chessMatchWaitingForTheFirstMove(Object value);

  /// features/chess/presentation/screens/chess_match_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Their move'**
  String get chessMatchTheirMove;

  /// features/checkers/presentation/screens/checkers_match_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Setting up the board'**
  String get checkersMatchSettingUpTheBoard;

  /// features/checkers/presentation/screens/checkers_match_screen.dart
  ///
  /// In en, this message translates to:
  /// **'We couldn\'t find this game.'**
  String get checkersMatchWeCouldnTFindThis;

  /// features/checkers/presentation/screens/checkers_match_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Leave game'**
  String get checkersMatchLeaveGame;

  /// features/checkers/presentation/screens/checkers_match_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get checkersMatchClose;

  /// features/checkers/presentation/screens/checkers_match_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Resign'**
  String get checkersMatchResign;

  /// features/checkers/presentation/screens/checkers_match_screen.dart
  ///
  /// In en, this message translates to:
  /// **'No moves left for them. Well played.'**
  String get checkersMatchNoMovesLeftForThem;

  /// features/checkers/presentation/screens/checkers_match_screen.dart
  ///
  /// In en, this message translates to:
  /// **'You ran out of moves.'**
  String get checkersMatchYouRanOutOfMoves;

  /// features/checkers/presentation/screens/checkers_match_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Forty moves each with no progress.'**
  String get checkersMatchFortyMovesEachWithNo;

  /// features/checkers/presentation/screens/checkers_match_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Resign this game?'**
  String get checkersMatchResignThisGame;

  /// features/checkers/presentation/screens/checkers_match_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Your opponent wins the game and the prize.'**
  String get checkersMatchYourOpponentWinsTheGame;

  /// features/checkers/presentation/screens/checkers_match_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Your opponent wins the game.'**
  String get checkersMatchYourOpponentWinsTheGame2;

  /// features/checkers/presentation/screens/checkers_match_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Keep playing'**
  String get checkersMatchKeepPlaying;

  /// features/checkers/presentation/screens/checkers_match_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Checkers'**
  String get checkersMatchCheckers;

  /// features/checkers/presentation/screens/checkers_match_screen.dart
  ///
  /// In en, this message translates to:
  /// **'You'**
  String get checkersMatchYou;

  /// features/checkers/presentation/screens/checkers_match_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Opponent'**
  String get checkersMatchOpponent;

  /// features/checkers/presentation/screens/checkers_match_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Took {count}'**
  String checkersMatchTook(Object count);

  /// features/checkers/presentation/screens/checkers_match_screen.dart
  ///
  /// In en, this message translates to:
  /// **'1 king'**
  String get checkersMatch1King;

  /// features/checkers/presentation/screens/checkers_match_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Starting position'**
  String get checkersMatchStartingPosition;

  /// features/checkers/presentation/screens/checkers_match_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Move {displayPly} of {length}'**
  String checkersMatchMoveOf(Object displayPly, Object length);

  /// features/checkers/presentation/screens/checkers_match_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Back to live'**
  String get checkersMatchBackToLive;

  /// features/checkers/presentation/screens/checkers_match_screen.dart
  ///
  /// In en, this message translates to:
  /// **'You must take a piece'**
  String get checkersMatchYouMustTakeAPiece;

  /// features/checkers/presentation/screens/checkers_match_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Your move · {value}s to start'**
  String checkersMatchYourMoveSToStart(Object value);

  /// features/checkers/presentation/screens/checkers_match_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Your move'**
  String get checkersMatchYourMove;

  /// features/checkers/presentation/screens/checkers_match_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Waiting for the first move · {value}s'**
  String checkersMatchWaitingForTheFirstMove(Object value);

  /// features/checkers/presentation/screens/checkers_match_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Their move'**
  String get checkersMatchTheirMove;

  /// features/guess_doodle/presentation/guess_doodle_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Slow down a little'**
  String get guessDoodleSlowDownALittle;

  /// features/guess_doodle/presentation/guess_doodle_screen.dart
  ///
  /// In en, this message translates to:
  /// **'You\'re not in this game anymore'**
  String get guessDoodleYouReNotInThis;

  /// features/guess_doodle/presentation/guess_doodle_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Leave the game?'**
  String get guessDoodleLeaveTheGame;

  /// features/guess_doodle/presentation/guess_doodle_screen.dart
  ///
  /// In en, this message translates to:
  /// **'The others will carry on without you.'**
  String get guessDoodleTheOthersWillCarryOn;

  /// features/guess_doodle/presentation/guess_doodle_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Stay'**
  String get guessDoodleStay;

  /// features/guess_doodle/presentation/guess_doodle_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Leave'**
  String get guessDoodleLeave;

  /// features/guess_doodle/presentation/guess_doodle_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Code copied'**
  String get guessDoodleCodeCopied;

  /// features/guess_doodle/presentation/guess_doodle_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Come play Guess My Doodle with me in Utopia! Tap to join, or use game code {code}: {value}'**
  String guessDoodleComePlayGuessMyDoodle(Object code, Object value);

  /// features/guess_doodle/presentation/guess_doodle_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Guess My Doodle in Utopia'**
  String get guessDoodleGuessMyDoodleInUtopia;

  /// features/guess_doodle/presentation/guess_doodle_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Clear the drawing?'**
  String get guessDoodleClearTheDrawing;

  /// features/guess_doodle/presentation/guess_doodle_screen.dart
  ///
  /// In en, this message translates to:
  /// **'You can\'t undo this.'**
  String get guessDoodleYouCanTUndoThis;

  /// features/guess_doodle/presentation/guess_doodle_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Keep it'**
  String get guessDoodleKeepIt;

  /// features/guess_doodle/presentation/guess_doodle_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get guessDoodleClear;

  /// features/guess_doodle/presentation/guess_doodle_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Chat with players who got it'**
  String get guessDoodleChatWithPlayersWhoGot;

  /// features/guess_doodle/presentation/guess_doodle_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Type your guess'**
  String get guessDoodleTypeYourGuess;

  /// features/guess_doodle/presentation/guess_doodle_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Only players who guess will see this'**
  String get guessDoodleOnlyPlayersWhoGuessWill;

  /// features/guess_doodle/presentation/guess_doodle_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Say something'**
  String get guessDoodleSaySomething;

  /// features/guess_doodle/presentation/guess_doodle_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Guess My Doodle'**
  String get guessDoodleGuessMyDoodle;

  /// features/guess_doodle/presentation/guess_doodle_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Round {round} of {rounds}'**
  String guessDoodleRoundOf(Object round, Object rounds);

  /// features/guess_doodle/presentation/guess_doodle_screen.dart
  ///
  /// In en, this message translates to:
  /// **'You got it!'**
  String get guessDoodleYouGotIt;

  /// features/ludo/presentation/widgets/ludo_rules_sheet.dart
  ///
  /// In en, this message translates to:
  /// **'How to play Ludo'**
  String get ludoRulesHowToPlayLudo;

  /// features/ludo/presentation/widgets/ludo_rules_sheet.dart
  ///
  /// In en, this message translates to:
  /// **'Roll a 6 to start'**
  String get ludoRulesRollA6ToStart;

  /// features/ludo/presentation/widgets/ludo_rules_sheet.dart
  ///
  /// In en, this message translates to:
  /// **'Each piece waits in your yard until you roll a 6. Then it hops out onto your start square.'**
  String get ludoRulesEachPieceWaitsInYour;

  /// features/ludo/presentation/widgets/ludo_rules_sheet.dart
  ///
  /// In en, this message translates to:
  /// **'Race around the board'**
  String get ludoRulesRaceAroundTheBoard;

  /// features/ludo/presentation/widgets/ludo_rules_sheet.dart
  ///
  /// In en, this message translates to:
  /// **'Pieces move by the number you roll. Tap a glowing piece to move it. If only one move is possible, it moves on its own.'**
  String get ludoRulesPiecesMoveByTheNumber;

  /// features/ludo/presentation/widgets/ludo_rules_sheet.dart
  ///
  /// In en, this message translates to:
  /// **'Timed turns'**
  String get ludoRulesTimedTurns;

  /// features/ludo/presentation/widgets/ludo_rules_sheet.dart
  ///
  /// In en, this message translates to:
  /// **'The ring around your picture shows your time: 15 seconds a move in public games, 40 with friends. Run out and your turn is played for you, and you stay in the game: come back any time and carry on.'**
  String get ludoRulesTheRingAroundYourPicture;

  /// features/ludo/presentation/widgets/ludo_rules_sheet.dart
  ///
  /// In en, this message translates to:
  /// **'Capture to send them home'**
  String get ludoRulesCaptureToSendThemHome;

  /// features/ludo/presentation/widgets/ludo_rules_sheet.dart
  ///
  /// In en, this message translates to:
  /// **'Land exactly on an opponent to send their piece back to its yard. Stars and start squares are safe.'**
  String get ludoRulesLandExactlyOnAnOpponent;

  /// features/ludo/presentation/widgets/ludo_rules_sheet.dart
  ///
  /// In en, this message translates to:
  /// **'War or peace'**
  String get ludoRulesWarOrPeace;

  /// features/ludo/presentation/widgets/ludo_rules_sheet.dart
  ///
  /// In en, this message translates to:
  /// **'After a capture, pick a reaction before the bubble runs out: an evil cackle or a peaceful hug. Everyone sees it.'**
  String get ludoRulesAfterACapturePickA;

  /// features/ludo/presentation/widgets/ludo_rules_sheet.dart
  ///
  /// In en, this message translates to:
  /// **'Bonus rolls'**
  String get ludoRulesBonusRolls;

  /// features/ludo/presentation/widgets/ludo_rules_sheet.dart
  ///
  /// In en, this message translates to:
  /// **'Rolling a 6, capturing, or getting a piece home earns another roll. Three 6s in a row and you lose the turn.'**
  String get ludoRulesRollingA6CapturingOr;

  /// features/ludo/presentation/widgets/ludo_rules_sheet.dart
  ///
  /// In en, this message translates to:
  /// **'Get all four home'**
  String get ludoRulesGetAllFourHome;

  /// features/ludo/presentation/widgets/ludo_rules_sheet.dart
  ///
  /// In en, this message translates to:
  /// **'Go up your own colored path into the center. You need the exact number to finish. The first player with all four pieces home wins.'**
  String get ludoRulesGoUpYourOwnColored;

  /// features/ludo/presentation/widgets/ludo_rules_sheet.dart
  ///
  /// In en, this message translates to:
  /// **'Leaving ends your game'**
  String get ludoRulesLeavingEndsYourGame;

  /// features/ludo/presentation/widgets/ludo_rules_sheet.dart
  ///
  /// In en, this message translates to:
  /// **'If you leave, you lose this game and your entry stays in the prize. With more than two players, the game carries on.'**
  String get ludoRulesIfYouLeaveYouLose;

  /// features/auras/presentation/aura_sheet.dart
  ///
  /// In en, this message translates to:
  /// **'{name} is yours for {label}'**
  String auraIsYoursFor(Object name, Object label);

  /// features/auras/presentation/aura_sheet.dart
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t buy that aura. Try again.'**
  String get auraCouldnTBuyThatAura;

  /// features/auras/presentation/aura_sheet.dart
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t change your aura.'**
  String get auraCouldnTChangeYourAura;

  /// features/auras/presentation/aura_sheet.dart
  ///
  /// In en, this message translates to:
  /// **'You'**
  String get auraYou;

  /// features/auras/presentation/aura_sheet.dart
  ///
  /// In en, this message translates to:
  /// **'Comes with {plan}. Yours to wear while you\'re a member.'**
  String auraComesWithYoursToWear(Object plan);

  /// features/auras/presentation/aura_sheet.dart
  ///
  /// In en, this message translates to:
  /// **'No longer sold. Yours to wear until it runs out.'**
  String get auraNoLongerSoldYoursTo;

  /// features/auras/presentation/aura_sheet.dart
  ///
  /// In en, this message translates to:
  /// **'Add {label} · {value}'**
  String auraAdd(Object label, Object value);

  /// features/auras/presentation/aura_sheet.dart
  ///
  /// In en, this message translates to:
  /// **'Buy for {value} coins'**
  String auraBuyForCoins(Object value);

  /// features/auras/presentation/aura_sheet.dart
  ///
  /// In en, this message translates to:
  /// **'You have '**
  String get auraYouHave;

  /// features/auras/presentation/aura_sheet.dart
  ///
  /// In en, this message translates to:
  /// **'Yours · {value}'**
  String auraYours(Object value);

  /// features/auras/presentation/aura_sheet.dart
  ///
  /// In en, this message translates to:
  /// **'Take off'**
  String get auraTakeOff;

  /// features/auras/presentation/aura_sheet.dart
  ///
  /// In en, this message translates to:
  /// **'Wear'**
  String get auraWear;

  /// features/auras/presentation/aura_sheet.dart
  ///
  /// In en, this message translates to:
  /// **'{value} a day'**
  String auraADay(Object value);

  /// features/auras/presentation/aura_sheet.dart
  ///
  /// In en, this message translates to:
  /// **'Best value'**
  String get auraBestValue;

  /// features/ludo/presentation/controllers/ludo_match_controller.dart
  ///
  /// In en, this message translates to:
  /// **'Connection lost. Reconnecting.'**
  String get ludoMatchConnectionLostReconnecting;

  /// features/ludo/presentation/controllers/ludo_match_controller.dart
  ///
  /// In en, this message translates to:
  /// **'Match not found'**
  String get ludoMatchMatchNotFound;

  /// features/ludo/presentation/controllers/ludo_match_controller.dart
  ///
  /// In en, this message translates to:
  /// **'Whoa, slow down a little!'**
  String get ludoMatchWhoaSlowDownALittle;

  /// features/ludo/presentation/controllers/ludo_match_controller.dart
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t send that message.'**
  String get ludoMatchCouldnTSendThatMessage;

  /// features/ludo/presentation/controllers/ludo_match_controller.dart
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t send your voice note.'**
  String get ludoMatchCouldnTSendYourVoice;

  /// features/ludo/presentation/controllers/ludo_match_controller.dart
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t send your roll. Reconnecting.'**
  String get ludoMatchCouldnTSendYourRoll;

  /// features/ludo/presentation/controllers/ludo_match_controller.dart
  ///
  /// In en, this message translates to:
  /// **'That move didn\'t go through. Reconnecting.'**
  String get ludoMatchThatMoveDidnTGo;

  /// features/doodle_studio/presentation/chip_paint.dart
  ///
  /// In en, this message translates to:
  /// **'Black and white shading'**
  String get chipPaintBlackAndWhiteShading;

  /// features/doodle_studio/presentation/chip_paint.dart
  ///
  /// In en, this message translates to:
  /// **'Pastel'**
  String get chipPaintPastel;

  /// features/doodle_studio/presentation/chip_paint.dart
  ///
  /// In en, this message translates to:
  /// **'Sunset'**
  String get chipPaintSunset;

  /// features/doodle_studio/presentation/chip_paint.dart
  ///
  /// In en, this message translates to:
  /// **'Neon'**
  String get chipPaintNeon;

  /// features/doodle_studio/presentation/chip_paint.dart
  ///
  /// In en, this message translates to:
  /// **'Ocean'**
  String get chipPaintOcean;

  /// features/doodle_studio/presentation/chip_paint.dart
  ///
  /// In en, this message translates to:
  /// **'Autumn'**
  String get chipPaintAutumn;

  /// features/doodle_studio/presentation/chip_paint.dart
  ///
  /// In en, this message translates to:
  /// **'Royal gold'**
  String get chipPaintRoyalGold;

  /// features/doodle_studio/presentation/chip_paint.dart
  ///
  /// In en, this message translates to:
  /// **'How should I color it?'**
  String get chipPaintHowShouldIColorIt;

  /// features/doodle_studio/presentation/chip_paint.dart
  ///
  /// In en, this message translates to:
  /// **'Or describe it, like \"only blues\"'**
  String get chipPaintOrDescribeItLikeOnly;

  /// features/doodle_studio/presentation/chip_paint.dart
  ///
  /// In en, this message translates to:
  /// **'Color it'**
  String get chipPaintColorIt;

  /// features/doodle_studio/presentation/studio_toolbar.dart
  ///
  /// In en, this message translates to:
  /// **'Pencil'**
  String get studioToolbarPencil;

  /// features/doodle_studio/presentation/studio_toolbar.dart
  ///
  /// In en, this message translates to:
  /// **'Ink pen'**
  String get studioToolbarInkPen;

  /// features/doodle_studio/presentation/studio_toolbar.dart
  ///
  /// In en, this message translates to:
  /// **'Marker'**
  String get studioToolbarMarker;

  /// features/doodle_studio/presentation/studio_toolbar.dart
  ///
  /// In en, this message translates to:
  /// **'Soft brush'**
  String get studioToolbarSoftBrush;

  /// features/doodle_studio/presentation/studio_toolbar.dart
  ///
  /// In en, this message translates to:
  /// **'Highlighter'**
  String get studioToolbarHighlighter;

  /// features/doodle_studio/presentation/studio_toolbar.dart
  ///
  /// In en, this message translates to:
  /// **'Eraser'**
  String get studioToolbarEraser;

  /// features/doodle_studio/presentation/studio_toolbar.dart
  ///
  /// In en, this message translates to:
  /// **'Paint bucket'**
  String get studioToolbarPaintBucket;

  /// features/doodle_studio/presentation/studio_toolbar.dart
  ///
  /// In en, this message translates to:
  /// **'Color'**
  String get studioToolbarColor;

  /// features/doodle_studio/presentation/studio_toolbar.dart
  ///
  /// In en, this message translates to:
  /// **'Brush size {value}'**
  String studioToolbarBrushSize(Object value);

  /// features/store/presentation/coin_shop.dart
  ///
  /// In en, this message translates to:
  /// **'Test build: packs are free so you can try them.'**
  String get coinShopTestBuildPacksAreFree;

  /// features/store/presentation/coin_shop.dart
  ///
  /// In en, this message translates to:
  /// **'Save your account to buy coins.'**
  String get coinShopSaveYourAccountToBuy;

  /// features/store/presentation/coin_shop.dart
  ///
  /// In en, this message translates to:
  /// **'Save your account so your coins are never lost.'**
  String get coinShopSaveYourAccountSoYour;

  /// features/store/presentation/coin_shop.dart
  ///
  /// In en, this message translates to:
  /// **'Coin top-ups are coming soon'**
  String get coinShopCoinTopUpsAreComing;

  /// features/store/presentation/coin_shop.dart
  ///
  /// In en, this message translates to:
  /// **'For now, earn them by playing: claim your daily reward every day, and win games with an entry.'**
  String get coinShopForNowEarnThemBy;

  /// features/store/presentation/coin_shop.dart
  ///
  /// In en, this message translates to:
  /// **'Coins'**
  String get coinShopCoins;

  /// features/store/presentation/coin_shop.dart
  ///
  /// In en, this message translates to:
  /// **'You need {value} more for that game.'**
  String coinShopYouNeedMoreForThat(Object value);

  /// features/store/presentation/coin_shop.dart
  ///
  /// In en, this message translates to:
  /// **'+{percent}% extra'**
  String coinShopExtra(Object percent);

  /// features/store/data/store_repository.dart
  ///
  /// In en, this message translates to:
  /// **'You already have the starter pack.'**
  String get storeYouAlreadyHaveTheStarter;

  /// features/store/data/store_repository.dart
  ///
  /// In en, this message translates to:
  /// **'Coin top-ups on the web are coming soon.'**
  String get storeCoinTopUpsOnThe;

  /// features/store/data/store_repository.dart
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t start the payment. Try again.'**
  String get storeCouldnTStartThePayment;

  /// features/store/data/store_repository.dart
  ///
  /// In en, this message translates to:
  /// **'GH₵'**
  String get storeGh;

  /// features/store/data/store_repository.dart
  ///
  /// In en, this message translates to:
  /// **'KSh '**
  String get storeKsh;

  /// features/guess_doodle/presentation/widgets/doodle_chat.dart
  ///
  /// In en, this message translates to:
  /// **'Someone'**
  String get doodleChatSomeone;

  /// features/guess_doodle/presentation/widgets/doodle_chat.dart
  ///
  /// In en, this message translates to:
  /// **'You'**
  String get doodleChatYou;

  /// features/guess_doodle/presentation/widgets/doodle_chat.dart
  ///
  /// In en, this message translates to:
  /// **'You got it!'**
  String get doodleChatYouGotIt;

  /// features/guess_doodle/presentation/widgets/doodle_chat.dart
  ///
  /// In en, this message translates to:
  /// **'{name} got it!'**
  String doodleChatGotIt(Object name);

  /// features/guess_doodle/presentation/widgets/doodle_chat.dart
  ///
  /// In en, this message translates to:
  /// **'\"{text}\" is so close!'**
  String doodleChatIsSoClose(Object text);

  /// features/guess_doodle/presentation/widgets/doodle_chat.dart
  ///
  /// In en, this message translates to:
  /// **'The word was {body}'**
  String doodleChatTheWordWas(Object body);

  /// features/guess_doodle/presentation/widgets/doodle_chat.dart
  ///
  /// In en, this message translates to:
  /// **'Your turn to draw'**
  String get doodleChatYourTurnToDraw;

  /// features/guess_doodle/presentation/widgets/doodle_chat.dart
  ///
  /// In en, this message translates to:
  /// **'{name} is drawing'**
  String doodleChatIsDrawing(Object name);

  /// features/doodle_studio/domain/coloring_pages.dart
  ///
  /// In en, this message translates to:
  /// **'Mandala'**
  String get coloringPagesMandala;

  /// features/doodle_studio/domain/coloring_pages.dart
  ///
  /// In en, this message translates to:
  /// **'Chip'**
  String get coloringPagesChip;

  /// features/doodle_studio/domain/coloring_pages.dart
  ///
  /// In en, this message translates to:
  /// **'Floating island'**
  String get coloringPagesFloatingIsland;

  /// features/doodle_studio/domain/coloring_pages.dart
  ///
  /// In en, this message translates to:
  /// **'Little dragon'**
  String get coloringPagesLittleDragon;

  /// features/doodle_studio/domain/coloring_pages.dart
  ///
  /// In en, this message translates to:
  /// **'Rocket'**
  String get coloringPagesRocket;

  /// features/doodle_studio/domain/coloring_pages.dart
  ///
  /// In en, this message translates to:
  /// **'Castle'**
  String get coloringPagesCastle;

  /// features/doodle_studio/domain/coloring_pages.dart
  ///
  /// In en, this message translates to:
  /// **'Under the sea'**
  String get coloringPagesUnderTheSea;

  /// features/doodle_studio/domain/coloring_pages.dart
  ///
  /// In en, this message translates to:
  /// **'Garden'**
  String get coloringPagesGarden;

  /// features/chat/presentation/game_chat_sheet.dart
  ///
  /// In en, this message translates to:
  /// **'Some words were hidden. Keep it friendly.'**
  String get gameChatSomeWordsWereHiddenKeep;

  /// features/chat/presentation/game_chat_sheet.dart
  ///
  /// In en, this message translates to:
  /// **'Chat'**
  String get gameChatChat;

  /// features/chat/presentation/game_chat_sheet.dart
  ///
  /// In en, this message translates to:
  /// **'Friends chat'**
  String get gameChatFriendsChat;

  /// features/chat/presentation/game_chat_sheet.dart
  ///
  /// In en, this message translates to:
  /// **'Friendly chat'**
  String get gameChatFriendlyChat;

  /// features/chat/presentation/game_chat_sheet.dart
  ///
  /// In en, this message translates to:
  /// **'Say hi'**
  String get gameChatSayHi;

  /// features/chat/presentation/game_chat_sheet.dart
  ///
  /// In en, this message translates to:
  /// **'Message your friends'**
  String get gameChatMessageYourFriends;

  /// features/chat/presentation/game_chat_sheet.dart
  ///
  /// In en, this message translates to:
  /// **'Say something nice'**
  String get gameChatSaySomethingNice;

  /// features/chat/presentation/game_chat_sheet.dart
  ///
  /// In en, this message translates to:
  /// **'You'**
  String get gameChatYou;

  /// core/bots/bots.dart
  ///
  /// In en, this message translates to:
  /// **'Player {value}'**
  String botsPlayer(Object value);

  /// core/bots/bots.dart
  ///
  /// In en, this message translates to:
  /// **'Pip'**
  String get botsPip;

  /// core/bots/bots.dart
  ///
  /// In en, this message translates to:
  /// **'Momo'**
  String get botsMomo;

  /// core/bots/bots.dart
  ///
  /// In en, this message translates to:
  /// **'Kiki'**
  String get botsKiki;

  /// core/bots/bots.dart
  ///
  /// In en, this message translates to:
  /// **'Bolt'**
  String get botsBolt;

  /// core/bots/bots.dart
  ///
  /// In en, this message translates to:
  /// **'Nova'**
  String get botsNova;

  /// core/bots/bots.dart
  ///
  /// In en, this message translates to:
  /// **'Chip'**
  String get botsChip;

  /// core/bots/bots.dart
  ///
  /// In en, this message translates to:
  /// **'Robo'**
  String get botsRobo;

  /// features/chat/domain/chat_filter.dart
  ///
  /// In en, this message translates to:
  /// **'Nice move!'**
  String get chatFilterNiceMove;

  /// features/chat/domain/chat_filter.dart
  ///
  /// In en, this message translates to:
  /// **'Well played!'**
  String get chatFilterWellPlayed;

  /// features/chat/domain/chat_filter.dart
  ///
  /// In en, this message translates to:
  /// **'So close!'**
  String get chatFilterSoClose;

  /// features/chat/domain/chat_filter.dart
  ///
  /// In en, this message translates to:
  /// **'Let\'s go!'**
  String get chatFilterLetSGo;

  /// features/chat/domain/chat_filter.dart
  ///
  /// In en, this message translates to:
  /// **'Your turn'**
  String get chatFilterYourTurn;

  /// features/chat/domain/chat_filter.dart
  ///
  /// In en, this message translates to:
  /// **'Oops!'**
  String get chatFilterOops;

  /// features/chat/domain/chat_filter.dart
  ///
  /// In en, this message translates to:
  /// **'Good game!'**
  String get chatFilterGoodGame;

  /// features/chat/presentation/game_chat_controller.dart
  ///
  /// In en, this message translates to:
  /// **'Whoa, slow down a little!'**
  String get gameChatWhoaSlowDownALittle;

  /// features/chat/presentation/game_chat_controller.dart
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t send that message.'**
  String get gameChatCouldnTSendThatMessage;

  /// features/chat/presentation/game_chat_controller.dart
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t send your voice note.'**
  String get gameChatCouldnTSendYourVoice;

  /// features/auras/presentation/auras_tab.dart
  ///
  /// In en, this message translates to:
  /// **'You'**
  String get aurasTabYou;

  /// features/auras/presentation/auras_tab.dart
  ///
  /// In en, this message translates to:
  /// **'No aura yet'**
  String get aurasTabNoAuraYet;

  /// features/auras/presentation/auras_tab.dart
  ///
  /// In en, this message translates to:
  /// **'Wear one and everyone sees it around your picture, in every game.'**
  String get aurasTabWearOneAndEveryoneSees;

  /// features/auras/presentation/auras_tab.dart
  ///
  /// In en, this message translates to:
  /// **'Wearing now · {value}'**
  String aurasTabWearingNow(Object value);

  /// features/auras/presentation/auras_tab.dart
  ///
  /// In en, this message translates to:
  /// **'Wearing'**
  String get aurasTabWearing;

  /// features/auras/presentation/auras_tab.dart
  ///
  /// In en, this message translates to:
  /// **'Owned'**
  String get aurasTabOwned;

  /// features/chat/presentation/voice_notes.dart
  ///
  /// In en, this message translates to:
  /// **'Allow microphone access in Settings to send voice notes.'**
  String get voiceNotesAllowMicrophoneAccessInSettings;

  /// features/chat/presentation/voice_notes.dart
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t start recording.'**
  String get voiceNotesCouldnTStartRecording;

  /// features/chat/presentation/voice_notes.dart
  ///
  /// In en, this message translates to:
  /// **'Record a voice note'**
  String get voiceNotesRecordAVoiceNote;

  /// features/chat/presentation/voice_notes.dart
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get voiceNotesDelete;

  /// features/chat/presentation/voice_notes.dart
  ///
  /// In en, this message translates to:
  /// **'Send'**
  String get voiceNotesSend;

  /// features/store/presentation/web_payment_return.dart
  ///
  /// In en, this message translates to:
  /// **'The payment didn\'t go through, so nothing was charged.'**
  String get webPaymentReturnThePaymentDidnTGo;

  /// features/store/presentation/web_payment_return.dart
  ///
  /// In en, this message translates to:
  /// **'Payment received: {value} coins added!'**
  String webPaymentReturnPaymentReceivedCoinsAdded(Object value);

  /// features/store/presentation/web_payment_return.dart
  ///
  /// In en, this message translates to:
  /// **'Your payment is being confirmed. Your coins will arrive in a moment.'**
  String get webPaymentReturnYourPaymentIsBeingConfirmed;

  /// features/store/presentation/web_payment_return.dart
  ///
  /// In en, this message translates to:
  /// **'We couldn\'t confirm that payment yet. If you were charged, your coins will arrive shortly.'**
  String get webPaymentReturnWeCouldnTConfirmThat;

  /// features/chess/domain/time_control.dart
  ///
  /// In en, this message translates to:
  /// **'Bullet'**
  String get timeControlBullet;

  /// features/chess/domain/time_control.dart
  ///
  /// In en, this message translates to:
  /// **'Blitz'**
  String get timeControlBlitz;

  /// features/chess/domain/time_control.dart
  ///
  /// In en, this message translates to:
  /// **'Rapid'**
  String get timeControlRapid;

  /// features/chess/domain/time_control.dart
  ///
  /// In en, this message translates to:
  /// **'Classical'**
  String get timeControlClassical;

  /// features/ludo/presentation/widgets/ludo_seat_panel.dart
  ///
  /// In en, this message translates to:
  /// **'You'**
  String get ludoSeatPanelYou;

  /// features/ludo/presentation/widgets/ludo_seat_panel.dart
  ///
  /// In en, this message translates to:
  /// **'Open seat'**
  String get ludoSeatPanelOpenSeat;

  /// features/ludo/presentation/widgets/ludo_seat_panel.dart
  ///
  /// In en, this message translates to:
  /// **'Left'**
  String get ludoSeatPanelLeft;

  /// features/ludo/presentation/widgets/ludo_chat_sheet.dart
  ///
  /// In en, this message translates to:
  /// **'Someone'**
  String get ludoChatSomeone;

  /// features/ludo/presentation/widgets/ludo_chat_sheet.dart
  ///
  /// In en, this message translates to:
  /// **'{who} chose war!'**
  String ludoChatChoseWar(Object who);

  /// features/ludo/presentation/widgets/ludo_chat_sheet.dart
  ///
  /// In en, this message translates to:
  /// **'{who} made peace.'**
  String ludoChatMadePeace(Object who);

  /// features/ludo/presentation/widgets/ludo_capture_bubble.dart
  ///
  /// In en, this message translates to:
  /// **'React'**
  String get ludoCaptureBubbleReact;

  /// features/ludo/presentation/widgets/ludo_capture_bubble.dart
  ///
  /// In en, this message translates to:
  /// **'War'**
  String get ludoCaptureBubbleWar;

  /// features/ludo/presentation/widgets/ludo_capture_bubble.dart
  ///
  /// In en, this message translates to:
  /// **'Peace'**
  String get ludoCaptureBubblePeace;

  /// A reaction for a piece just sent back home: sad about it.
  ///
  /// In en, this message translates to:
  /// **'Sad'**
  String get ludoCaptureBubbleSad;

  /// A reaction for a piece just sent back home: not giving up, going again.
  ///
  /// In en, this message translates to:
  /// **'Again!'**
  String get ludoCaptureBubbleAgain;

  /// features/guess_doodle/presentation/widgets/doodle_tools.dart
  ///
  /// In en, this message translates to:
  /// **'Eraser'**
  String get doodleToolsEraser;

  /// features/guess_doodle/presentation/widgets/doodle_tools.dart
  ///
  /// In en, this message translates to:
  /// **'Undo'**
  String get doodleToolsUndo;

  /// features/guess_doodle/presentation/widgets/doodle_tools.dart
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get doodleToolsClear;

  /// features/ludo/presentation/widgets/ludo_dice.dart
  ///
  /// In en, this message translates to:
  /// **'Roll the die'**
  String get ludoDiceRollTheDie;

  /// features/ludo/presentation/widgets/ludo_dice.dart
  ///
  /// In en, this message translates to:
  /// **'Die showing {value}'**
  String ludoDiceDieShowing(Object value);

  /// features/chess/presentation/widgets/time_control_style.dart
  ///
  /// In en, this message translates to:
  /// **'  ·  {minutes} min each'**
  String timeControlStyleMinEach(Object minutes);

  /// features/chess/presentation/widgets/time_control_style.dart
  ///
  /// In en, this message translates to:
  /// **'  ·  {minutes} min  +{increment}s a move'**
  String timeControlStyleMinSAMove(Object minutes, Object increment);

  /// features/chess/presentation/sent_challenges.dart
  ///
  /// In en, this message translates to:
  /// **'Challenge to {name} cancelled.'**
  String sentChallengesChallengeToCancelled(Object name);

  /// features/chess/presentation/sent_challenges.dart
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t cancel it. Try again.'**
  String get sentChallengesCouldnTCancelItTry;

  /// features/chess/presentation/controllers/chess_match_controller.dart
  ///
  /// In en, this message translates to:
  /// **'Match not found'**
  String get chessMatchMatchNotFound;

  /// features/chess/presentation/controllers/chess_match_controller.dart
  ///
  /// In en, this message translates to:
  /// **'That move didn\'t go through. Reconnecting.'**
  String get chessMatchThatMoveDidnTGo;

  /// features/checkers/presentation/controllers/checkers_match_controller.dart
  ///
  /// In en, this message translates to:
  /// **'Match not found'**
  String get checkersMatchMatchNotFound;

  /// features/checkers/presentation/controllers/checkers_match_controller.dart
  ///
  /// In en, this message translates to:
  /// **'That move didn\'t go through. Reconnecting.'**
  String get checkersMatchThatMoveDidnTGo;

  /// features/store/presentation/theme_teleport.dart
  ///
  /// In en, this message translates to:
  /// **'Welcome to'**
  String get themeTeleportWelcomeTo;

  /// features/guess_doodle/presentation/widgets/doodle_header.dart
  ///
  /// In en, this message translates to:
  /// **'Draw'**
  String get doodleHeaderDraw;

  /// features/guess_doodle/data/chip_doodle_repository.dart
  ///
  /// In en, this message translates to:
  /// **'Chip couldn\'t draw just now. Check your connection and try again.'**
  String get chipDoodleChipCouldnTDrawJust2;

  /// features/doodle_studio/presentation/doodle_world_gate.dart
  ///
  /// In en, this message translates to:
  /// **'Coloring happens in the Doodle world.'**
  String get doodleWorldGateColoringHappensInTheDoodle;

  /// features/chip/presentation/floating_chip.dart
  ///
  /// In en, this message translates to:
  /// **'Chat with Chip'**
  String get floatingChipChatWithChip;

  /// features/chess/presentation/widgets/promotion_sheet.dart
  ///
  /// In en, this message translates to:
  /// **'Promote your pawn'**
  String get promotionPromoteYourPawn;

  /// features/checkers/presentation/screens/checkers_bot_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Nooo!'**
  String get checkersBotNooo;

  /// features/checkers/presentation/screens/checkers_bot_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Two for one!'**
  String get checkersBotTwoForOne;

  /// features/checkers/presentation/screens/checkers_bot_screen.dart
  ///
  /// In en, this message translates to:
  /// **'All hail me!'**
  String get checkersBotAllHailMe;

  /// features/maestro/presentation/maestro_sheet.dart
  ///
  /// In en, this message translates to:
  /// **'App Store'**
  String get maestroAppStore;

  /// features/maestro/presentation/maestro_sheet.dart
  ///
  /// In en, this message translates to:
  /// **'Google Play'**
  String get maestroGooglePlay;

  /// features/ludo/presentation/screens/ludo_match_screen.dart
  ///
  /// In en, this message translates to:
  /// **' and the game will go on without you'**
  String get ludoMatchAndTheGameWillGo;

  /// features/ludo/presentation/screens/ludo_match_screen.dart
  ///
  /// In en, this message translates to:
  /// **' and it will go on without you'**
  String get ludoMatchAndItWillGoOn;

  /// features/chess/presentation/screens/chess_bot_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Check! Your move.'**
  String get chessBotCheckYourMove;

  /// features/chess/presentation/screens/chess_bot_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Okay, I see it.'**
  String get chessBotOkayISeeIt;

  /// features/welcome/presentation/welcome_week.dart
  ///
  /// In en, this message translates to:
  /// **'Sun'**
  String get welcomeWeekSun;

  /// features/rankings/presentation/hologram/rank_hologram.dart
  ///
  /// In en, this message translates to:
  /// **'Top {top}% of {ranked} ranked players'**
  String rankHologramTopOfRankedPlayers(Object top, Object ranked);

  /// features/rankings/presentation/hologram/rank_hologram.dart
  ///
  /// In en, this message translates to:
  /// **'#{place} on the board'**
  String rankHologramPlaceOnTheBoard(Object place);

  /// features/chess/presentation/screens/chess_match_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Your move · they played {move}'**
  String chessMatchYourMoveTheyPlayed(Object move);

  /// features/birthday/presentation/birthday_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Chip will throw you a party on {day}.'**
  String birthdayChipWillThrowYouAParty(Object day);

  /// features/rankings/domain/ranking.dart: a rank tier
  ///
  /// In en, this message translates to:
  /// **'Bronze'**
  String get rankTierBronze;

  /// features/rankings/domain/ranking.dart: a rank tier
  ///
  /// In en, this message translates to:
  /// **'Silver'**
  String get rankTierSilver;

  /// features/rankings/domain/ranking.dart: a rank tier
  ///
  /// In en, this message translates to:
  /// **'Gold'**
  String get rankTierGold;

  /// features/rankings/domain/ranking.dart: a rank tier
  ///
  /// In en, this message translates to:
  /// **'Diamond'**
  String get rankTierDiamond;

  /// features/rankings/domain/ranking.dart: a rank tier
  ///
  /// In en, this message translates to:
  /// **'Legend'**
  String get rankTierLegend;

  /// core/theme/utopia_themes.dart: a color world at dawn
  ///
  /// In en, this message translates to:
  /// **'Dawn'**
  String get utopiaThemesShadeDawn;

  /// core/theme/utopia_themes.dart: a color world at dusk
  ///
  /// In en, this message translates to:
  /// **'Dusk'**
  String get utopiaThemesShadeDusk;

  /// core/theme/utopia_themes.dart: a color world at midnight
  ///
  /// In en, this message translates to:
  /// **'Midnight'**
  String get utopiaThemesShadeMidnight;

  /// core/theme/utopia_themes.dart: the feel of a color world at dawn
  ///
  /// In en, this message translates to:
  /// **'first light'**
  String get utopiaThemesShadeDawnMood;

  /// core/theme/utopia_themes.dart: the feel of a color world at dusk
  ///
  /// In en, this message translates to:
  /// **'golden hour'**
  String get utopiaThemesShadeDuskMood;

  /// core/theme/utopia_themes.dart: the feel of a color world at midnight
  ///
  /// In en, this message translates to:
  /// **'starlit'**
  String get utopiaThemesShadeMidnightMood;

  /// features/invites/domain/game_invite.dart: a game an invite link is for
  ///
  /// In en, this message translates to:
  /// **'Ludo'**
  String get gameInviteLudo;

  /// features/invites/domain/game_invite.dart: a game an invite link is for
  ///
  /// In en, this message translates to:
  /// **'Guess My Doodle'**
  String get gameInviteGuessMyDoodle;

  /// features/notifications/presentation/answer_buttons.dart
  ///
  /// In en, this message translates to:
  /// **'Accept'**
  String get answerButtonsAccept;

  /// features/auras/presentation/mythic_badge.dart
  ///
  /// In en, this message translates to:
  /// **'Mythic'**
  String get mythicBadgeMythic;

  /// core/widgets/bouncy_dialog.dart
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get bouncyDialogCancel;

  /// core/widgets/utopia_toast.dart
  ///
  /// In en, this message translates to:
  /// **'Something went wrong. Try again.'**
  String get utopiaToastSomethingWentWrong;

  /// features/coins/presentation/send_coins_sheet.dart: the hint in the gift note field
  ///
  /// In en, this message translates to:
  /// **'Add a note (optional)'**
  String get sendCoinsAddANote;

  /// features/coins/presentation/send_coins_sheet.dart
  ///
  /// In en, this message translates to:
  /// **'Keep your note to 140 characters.'**
  String get sendCoinsNoteTooLong;

  /// features/coins/presentation/send_coins_sheet.dart: under "Send coins", who to
  ///
  /// In en, this message translates to:
  /// **'to {name}'**
  String sendCoinsToName(Object name);

  /// A gift note, quoted (in a phone notification)
  ///
  /// In en, this message translates to:
  /// **'“{note}”'**
  String giftNoteQuoted(Object note);

  /// features/coins/presentation/gift_note.dart: read aloud by screen readers
  ///
  /// In en, this message translates to:
  /// **'Note: {note}'**
  String giftNoteTheirNote(Object note);

  /// features/doodle_studio: a coloring page name or a heading in the picture picker
  ///
  /// In en, this message translates to:
  /// **'Lotus mandala'**
  String get coloringPagesLotusMandala;

  /// features/doodle_studio: a coloring page name or a heading in the picture picker
  ///
  /// In en, this message translates to:
  /// **'Rose window'**
  String get coloringPagesRoseWindow;

  /// features/doodle_studio: a coloring page name or a heading in the picture picker
  ///
  /// In en, this message translates to:
  /// **'Moroccan tiles'**
  String get coloringPagesMoroccanTiles;

  /// features/doodle_studio: a coloring page name or a heading in the picture picker
  ///
  /// In en, this message translates to:
  /// **'Koi pond'**
  String get coloringPagesKoiPond;

  /// features/doodle_studio: a coloring page name or a heading in the picture picker
  ///
  /// In en, this message translates to:
  /// **'Low-poly peaks'**
  String get coloringPagesLowPolyPeaks;

  /// features/doodle_studio: a coloring page name or a heading in the picture picker
  ///
  /// In en, this message translates to:
  /// **'Art deco fans'**
  String get coloringPagesArtDecoFans;

  /// features/doodle_studio: a coloring page name or a heading in the picture picker
  ///
  /// In en, this message translates to:
  /// **'City at night'**
  String get coloringPagesCityAtNight;

  /// features/doodle_studio: a coloring page name or a heading in the picture picker
  ///
  /// In en, this message translates to:
  /// **'Peacock feathers'**
  String get coloringPagesPeacockFeathers;

  /// features/doodle_studio: a coloring page name or a heading in the picture picker
  ///
  /// In en, this message translates to:
  /// **'Detailed'**
  String get sketchbookDetailed;

  /// features/doodle_studio: a coloring page name or a heading in the picture picker
  ///
  /// In en, this message translates to:
  /// **'Playful'**
  String get sketchbookPlayful;

  /// features/maestro: Chip Maestro, the upgrade
  ///
  /// In en, this message translates to:
  /// **'Upgrade Chip'**
  String get maestroUpgradeChip;

  /// features/maestro: Chip Maestro, the upgrade
  ///
  /// In en, this message translates to:
  /// **'Maestro'**
  String get maestroBadge;

  /// features/maestro: Chip Maestro, the upgrade
  ///
  /// In en, this message translates to:
  /// **'Chip at his best: smarter, chattier, and your own artist.'**
  String get maestroChipAtHisBest;

  /// features/maestro: Chip Maestro, the upgrade
  ///
  /// In en, this message translates to:
  /// **'Free'**
  String get maestroCompareFree;

  /// features/maestro: Chip Maestro, the upgrade
  ///
  /// In en, this message translates to:
  /// **'Yours'**
  String get maestroCompareYours;

  /// features/maestro: Chip Maestro, the upgrade
  ///
  /// In en, this message translates to:
  /// **'Chats a day'**
  String get maestroCompareChats;

  /// features/maestro: Chip Maestro, the upgrade
  ///
  /// In en, this message translates to:
  /// **'Chip\'s brain'**
  String get maestroCompareBrain;

  /// features/maestro: Chip Maestro, the upgrade
  ///
  /// In en, this message translates to:
  /// **'Quick'**
  String get maestroCompareBrainFree;

  /// features/maestro: Chip Maestro, the upgrade
  ///
  /// In en, this message translates to:
  /// **'Smartest, searches the web'**
  String get maestroCompareBrainMaestro;

  /// features/maestro: Chip Maestro, the upgrade
  ///
  /// In en, this message translates to:
  /// **'Drawings a day'**
  String get maestroCompareDrawings;

  /// features/maestro: Chip Maestro, the upgrade
  ///
  /// In en, this message translates to:
  /// **'Coloring with Chip a day'**
  String get maestroCompareColoring;

  /// features/maestro: Chip Maestro, the upgrade
  ///
  /// In en, this message translates to:
  /// **'Real portraits'**
  String get maestroComparePortraits;

  /// features/maestro: Chip Maestro, the upgrade
  ///
  /// In en, this message translates to:
  /// **'Your first'**
  String get maestroComparePortraitsFree;

  /// features/maestro: Chip Maestro, the upgrade
  ///
  /// In en, this message translates to:
  /// **'{count} a month'**
  String maestroComparePortraitsMaestro(Object count);

  /// features/maestro: Chip Maestro, the upgrade
  ///
  /// In en, this message translates to:
  /// **'Artist look and Maestro frame'**
  String get maestroCompareLook;

  /// features/maestro: Chip Maestro, the upgrade
  ///
  /// In en, this message translates to:
  /// **'Chip at his best: 200 chats a day, his smartest brain and 30 real portraits a month.'**
  String get maestroStripText;

  /// features/maestro: Chip Maestro, the upgrade
  ///
  /// In en, this message translates to:
  /// **'Chip Maestro: 200 chats a day'**
  String get chipChatGetMaestro;

  /// Crazy Eights: the live connection to the game dropped.
  ///
  /// In en, this message translates to:
  /// **'Connection lost. Reconnecting…'**
  String get eightsConnectionLost;

  /// Crazy Eights: the game no longer exists.
  ///
  /// In en, this message translates to:
  /// **'We couldn\'t find that game.'**
  String get eightsNotFound;

  /// Crazy Eights: playing a card failed; the table was reloaded.
  ///
  /// In en, this message translates to:
  /// **'That card didn\'t go through. Here\'s the table as it is.'**
  String get eightsThatCardDidntGo;

  /// Crazy Eights: drawing failed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t draw a card. Try again.'**
  String get eightsCouldntDraw;

  /// Crazy Eights: passing failed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t pass. Try again.'**
  String get eightsCouldntPass;

  /// Crazy Eights button: end your turn after drawing a card.
  ///
  /// In en, this message translates to:
  /// **'Pass'**
  String get eightsPass;

  /// The card game's name.
  ///
  /// In en, this message translates to:
  /// **'Crazy Eights'**
  String get homeCrazyEights;

  /// Home: an unfinished Crazy Eights game.
  ///
  /// In en, this message translates to:
  /// **'The card table is waiting for you.'**
  String get homeEightsTheTableIsWaiting;

  /// A fact on the Crazy Eights tile on home.
  ///
  /// In en, this message translates to:
  /// **'Eights are wild'**
  String get homeEightsAreWild;

  /// Player card stat at the card table.
  ///
  /// In en, this message translates to:
  /// **'Crazy Eights wins'**
  String get ludoPlayerEightsWins;

  /// Under a player at the Ludo or Crazy Eights table whose turns are being played for them while they're away.
  ///
  /// In en, this message translates to:
  /// **'Away'**
  String get seatAway;

  /// Crazy Eights: confirm leaving a game with an entry.
  ///
  /// In en, this message translates to:
  /// **'You\'ll lose your {coins} coin entry and the game goes on without you.'**
  String eightsLeaveLoseEntry(int coins);

  /// Crazy Eights: confirm leaving a free game.
  ///
  /// In en, this message translates to:
  /// **'You\'ll lose this game, and it goes on without you.'**
  String get eightsLeaveLoseGame;

  /// Crazy Eights loading label.
  ///
  /// In en, this message translates to:
  /// **'Shuffling the cards…'**
  String get eightsShuffling;

  /// Crazy Eights call when a player is down to one card.
  ///
  /// In en, this message translates to:
  /// **'Last card!'**
  String get eightsLastCard;

  /// Card suit.
  ///
  /// In en, this message translates to:
  /// **'Spades'**
  String get eightsSpades;

  /// Card suit.
  ///
  /// In en, this message translates to:
  /// **'Hearts'**
  String get eightsHearts;

  /// Card suit.
  ///
  /// In en, this message translates to:
  /// **'Diamonds'**
  String get eightsDiamonds;

  /// Card suit.
  ///
  /// In en, this message translates to:
  /// **'Clubs'**
  String get eightsClubs;

  /// Crazy Eights status when the player is down to one card.
  ///
  /// In en, this message translates to:
  /// **'Last card! One more and you win'**
  String get eightsYouHaveOneLeft;

  /// Crazy Eights status after drawing a card that doesn't fit.
  ///
  /// In en, this message translates to:
  /// **'Nothing goes: passing…'**
  String get eightsNothingGoesPassing;

  /// Crazy Eights status after drawing a card that fits.
  ///
  /// In en, this message translates to:
  /// **'Play a glowing card, or pass'**
  String get eightsPlayOrPass;

  /// Crazy Eights status when no card in hand fits.
  ///
  /// In en, this message translates to:
  /// **'Nothing goes: tap the deck to draw'**
  String get eightsNothingGoesDraw;

  /// Crazy Eights status after someone played an eight and named a suit.
  ///
  /// In en, this message translates to:
  /// **'Your turn: play {suit}, or an eight'**
  String eightsPlayASuitOrEight(String suit);

  /// Crazy Eights status: what can be played.
  ///
  /// In en, this message translates to:
  /// **'Your turn: {suit} or a {rank}, or an eight'**
  String eightsMatchSuitOrRank(String suit, String rank);

  /// Crazy Eights: title when playing an eight.
  ///
  /// In en, this message translates to:
  /// **'Pick a suit'**
  String get eightsPickASuit;

  /// Crazy Eights: under the suit picker title.
  ///
  /// In en, this message translates to:
  /// **'Everyone has to follow it. The one you hold most of is marked.'**
  String get eightsPickASuitHint;

  /// Crazy Eights game over subtitle for the winner.
  ///
  /// In en, this message translates to:
  /// **'You played your last card first!'**
  String get eightsYouWentOut;

  /// Crazy Eights game over subtitle.
  ///
  /// In en, this message translates to:
  /// **'{name} played their last card first.'**
  String eightsWentOut(String name);

  /// Crazy Eights standings: a player who left.
  ///
  /// In en, this message translates to:
  /// **'{name} (left)'**
  String eightsNameLeft(String name);

  /// Crazy Eights rules title.
  ///
  /// In en, this message translates to:
  /// **'How to play Crazy Eights'**
  String get eightsRulesTitle;

  /// Crazy Eights rule title.
  ///
  /// In en, this message translates to:
  /// **'Match the pile'**
  String get eightsRulesMatchTitle;

  /// Crazy Eights rule.
  ///
  /// In en, this message translates to:
  /// **'On your turn, play a card of the same suit or the same number as the top card. On a 7 of hearts: any heart, or any 7.'**
  String get eightsRulesMatchBody;

  /// Crazy Eights rule title.
  ///
  /// In en, this message translates to:
  /// **'Eights are wild'**
  String get eightsRulesWildTitle;

  /// Crazy Eights rule.
  ///
  /// In en, this message translates to:
  /// **'An eight goes on anything (it has a rainbow rim). Play one and pick the suit everyone has to follow next.'**
  String get eightsRulesWildBody;

  /// Crazy Eights rule title.
  ///
  /// In en, this message translates to:
  /// **'Can\'t go? Draw one'**
  String get eightsRulesDrawTitle;

  /// Crazy Eights rule.
  ///
  /// In en, this message translates to:
  /// **'Tap the deck to draw a card. If something fits now, play it; if not, your turn passes.'**
  String get eightsRulesDrawBody;

  /// Crazy Eights rule.
  ///
  /// In en, this message translates to:
  /// **'The ring around your timer is your clock. Run out and your turn is played for you (a card that goes, or a draw), and you stay in the game: come back any time and carry on.'**
  String get eightsRulesTimeBody;

  /// Crazy Eights rule title.
  ///
  /// In en, this message translates to:
  /// **'First to empty their hand wins'**
  String get eightsRulesWinTitle;

  /// Crazy Eights rule.
  ///
  /// In en, this message translates to:
  /// **'Get rid of every card to win the table, and the pot if there\'s an entry. Down to one? Everyone hears \"Last card!\"'**
  String get eightsRulesWinBody;

  /// Crazy Eights rule.
  ///
  /// In en, this message translates to:
  /// **'If you leave, you lose your entry. Your cards go back in the deck and the others play on.'**
  String get eightsRulesLeaveBody;

  /// Crazy Eights lobby: under Play online.
  ///
  /// In en, this message translates to:
  /// **'Join a table of 2, 3 or 4'**
  String get eightsLobbyOnlineSubtitle;

  /// Crazy Eights lobby: under Play offline.
  ///
  /// In en, this message translates to:
  /// **'Against bots, on this phone'**
  String get eightsLobbyOfflineSubtitle;

  /// Crazy Eights lobby fact.
  ///
  /// In en, this message translates to:
  /// **'Chat & voice'**
  String get eightsLobbyChatVoice;

  /// Crazy Eights offline setup: who you'll play.
  ///
  /// In en, this message translates to:
  /// **'You and {count, plural, =1{1 bot} other{{count} bots}}'**
  String eightsLobbyBotsFill(int count);

  /// Crazy Eights room invite text.
  ///
  /// In en, this message translates to:
  /// **'Come play Crazy Eights with me in Utopia! Room code: {code}\n{link}'**
  String eightsRoomComePlay(String code, Object link);

  /// Crazy Eights invite subject.
  ///
  /// In en, this message translates to:
  /// **'Crazy Eights in Utopia'**
  String get eightsRoomInUtopia;

  /// Crazy Eights room: the host's start button.
  ///
  /// In en, this message translates to:
  /// **'Deal the cards'**
  String get eightsRoomDeal;

  /// Settings (web): hide the browser's bars while playing.
  ///
  /// In en, this message translates to:
  /// **'Play full screen'**
  String get settingsPlayFullScreen;

  /// Settings (web, phone or tablet): how full screen works and how to leave it.
  ///
  /// In en, this message translates to:
  /// **'Hides the browser\'s bars from your first tap. Swipe down from the top, or go Back, to see them again.'**
  String get settingsPlayFullScreenTouch;

  /// Settings (web, computer): how full screen works and how to leave it.
  ///
  /// In en, this message translates to:
  /// **'Hides the browser\'s bars from your first click. Press Esc to see them again.'**
  String get settingsPlayFullScreenKeys;
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
