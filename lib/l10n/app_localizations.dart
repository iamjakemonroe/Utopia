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
  /// **'Chip becomes your own artist.'**
  String get maestroChipBecomesYourOwnArtist;

  /// features/maestro/presentation/maestro_sheet.dart
  ///
  /// In en, this message translates to:
  /// **'{kMaestroPortraitsPerMonth} real portraits a month: anyone, from a photo or a famous name, looking just like them'**
  String maestroRealPortraitsAMonthAnyone(Object kMaestroPortraitsPerMonth);

  /// features/maestro/presentation/maestro_sheet.dart
  ///
  /// In en, this message translates to:
  /// **'Color with Chip all day long'**
  String get maestroColorWithChipAllDay;

  /// features/maestro/presentation/maestro_sheet.dart
  ///
  /// In en, this message translates to:
  /// **'10 of Chip\'s own drawings a day instead of 4'**
  String get maestro10OfChipSOwn;

  /// features/maestro/presentation/maestro_sheet.dart
  ///
  /// In en, this message translates to:
  /// **'Chip\'s artist look, and the Maestro frame for your picture'**
  String get maestroChipSArtistLookAnd;

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
