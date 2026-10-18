import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/data/auth_repository.dart';
import '../../features/auth/presentation/providers/auth_providers.dart';
import '../../features/auth/presentation/screens/auth_choice_screen.dart';
import '../../features/auth/presentation/screens/email_link_screen.dart';
import '../../features/auth/presentation/screens/splash_screen.dart';
import '../../features/checkers/domain/checkers_engine.dart';
import '../../features/checkers/presentation/screens/checkers_bot_screen.dart';
import '../../features/checkers/presentation/screens/checkers_match_screen.dart';
import '../../features/chess/domain/chess_bot.dart';
import '../../features/chess/domain/chess_types.dart';
import '../../features/chess/domain/time_control.dart';
import '../../features/chess/presentation/screens/chess_bot_screen.dart';
import '../../features/chess/presentation/screens/chess_lobby_screen.dart';
import '../bots/bots.dart';
import '../../features/chess/presentation/screens/chess_match_screen.dart';
import '../../features/birthday/presentation/birthday_screen.dart';
import '../../features/collection/presentation/collection_screen.dart';
import '../../features/help/presentation/how_to_play_screen.dart';
import '../../features/invites/domain/game_invite.dart';
import '../../features/invites/presentation/join_invite_screen.dart';
import '../../features/home/presentation/screens/home_screen.dart';
import '../../features/guess_doodle/presentation/guess_doodle_lobby_screen.dart';
import '../../features/guess_doodle/presentation/chip_doodle_screen.dart';
import '../../features/guess_doodle/presentation/guess_doodle_screen.dart';
import '../../features/ludo/presentation/screens/ludo_lobby_screen.dart';
import '../../features/ludo/presentation/screens/ludo_match_screen.dart';
import '../../features/ludo/presentation/screens/ludo_room_screen.dart';
import '../../features/notifications/presentation/notifications_screen.dart';
import '../../features/profile/presentation/screens/profile_screen.dart';
import '../../features/rankings/presentation/rankings_screen.dart';
import '../../features/settings/presentation/settings_screen.dart';
import '../../features/store/presentation/store_screen.dart';
import '../../features/doodle_studio/domain/art_doc.dart';
import '../../features/doodle_studio/presentation/sketchbook_screen.dart';
import '../../features/doodle_studio/presentation/studio_screen.dart';
import '../../features/support/presentation/privacy_screen.dart';
import '../../features/support/presentation/report_bug_screen.dart';
import '../widgets/game_card_art.dart';
import 'go_router_refresh_stream.dart';
import 'popup_tracker.dart';

/// Where the player is right now: the path of the screen on top, whether
/// it was gone to or pushed. (go_router keeps the match list's `uri` at the
/// base location when a screen is pushed over it, so `uri.path` alone
/// still says "/home" in the middle of a game.)
String currentPath(GoRouter router) {
  final config = router.routerDelegate.currentConfiguration;
  if (config.isEmpty) return '/';
  final last = config.last;
  if (last is ImperativeRouteMatch) return last.matches.uri.path;
  return config.uri.path;
}

/// Router with auth-gated redirects. `redirect` re-runs whenever
/// [GoRouterRefreshStream] fires (every auth state change), so signing in,
/// signing out, or linking an email all move the user to the right screen
/// automatically instead of screens manually calling `context.go`.
final goRouterProvider = Provider<GoRouter>((ref) {
  final authRepository = ref.watch(authRepositoryProvider);

  return GoRouter(
    initialLocation: '/splash',
    observers: [PopupTracker.instance],
    refreshListenable: GoRouterRefreshStream(authRepository.onAuthStateChange),
    redirect: (context, state) => _redirect(authRepository, state),
    routes: [
      GoRoute(
        path: '/splash',
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: '/auth',
        pageBuilder: (context, state) =>
            _fadeIn(state, const AuthChoiceScreen()),
      ),
      GoRoute(
        path: '/auth/link',
        builder: (context, state) => const EmailLinkScreen(),
      ),
      // The player's birthday: the last step of signing up
      // (?onboarding=1), or from Settings.
      GoRoute(
        path: '/birthday',
        builder: (context, state) => BirthdayScreen(
          onboarding: state.uri.queryParameters['onboarding'] == '1',
        ),
      ),
      GoRoute(
        path: '/home',
        pageBuilder: (context, state) => _fadeIn(state, const HomeScreen()),
      ),
      GoRoute(
        path: '/profile',
        builder: (context, state) => const ProfileScreen(),
      ),
      GoRoute(
        path: '/store',
        builder: (context, state) => StoreScreen(
          initialTab: switch (state.uri.queryParameters['tab']) {
            'auras' => 1,
            'ludo' => 2,
            'chess' => 3,
            _ => 0,
          },
        ),
      ),
      // Everything the player has: worlds, frames, piece sets.
      GoRoute(
        path: '/collection',
        builder: (context, state) => CollectionScreen(
          initialTab: switch (state.uri.queryParameters['tab']) {
            'frames' => 1,
            'ludo' => 2,
            'chess' => 3,
            _ => 0,
          },
        ),
      ),
      // Chess and checkers ratings, and the top players.
      GoRoute(
        path: '/rankings',
        builder: (context, state) => RankingsScreen(
          initialTab: switch (state.uri.queryParameters['game']) {
            'checkers' => 1,
            'doodle' => 2,
            _ => 0,
          },
        ),
      ),
      GoRoute(
        path: '/how-to-play',
        builder: (context, state) => HowToPlayScreen(
          initialGame: switch (state.uri.queryParameters['game']) {
            'ludo' => 1,
            'checkers' => 2,
            _ => 0,
          },
        ),
      ),
      GoRoute(
        path: '/notifications',
        builder: (context, state) => const NotificationsScreen(),
      ),
      GoRoute(
        path: '/settings',
        builder: (context, state) => const SettingsScreen(),
      ),
      // The Doodle world's sketchbook. New before :id.
      GoRoute(
        path: '/sketchbook',
        builder: (context, state) =>
            SketchbookScreen(pick: state.uri.queryParameters['pick'] == '1'),
      ),
      GoRoute(
        path: '/sketchbook/new',
        builder: (context, state) => StudioScreen(
          kind: state.uri.queryParameters['kind'] == 'coloring'
              ? ArtKind.coloring
              : ArtKind.sketch,
          pageId: state.uri.queryParameters['page'],
          paintStyle: state.uri.queryParameters['paint'],
        ),
      ),
      GoRoute(
        path: '/sketchbook/:id',
        builder: (context, state) =>
            StudioScreen(artId: state.pathParameters['id']),
      ),
      GoRoute(
        path: '/privacy',
        builder: (context, state) => const PrivacyScreen(),
      ),
      GoRoute(
        path: '/report-bug',
        builder: (context, state) => ReportBugScreen(
          idea: state.uri.queryParameters['kind'] == 'idea',
          from: state.uri.queryParameters['from'],
        ),
      ),
      GoRoute(
        path: '/chess',
        builder: (context, state) => const ChessLobbyScreen(),
      ),
      // Offline against the computer. Before /chess/:matchId, which would
      // otherwise take "bot" for a match id.
      GoRoute(
        path: '/chess/bot',
        builder: (context, state) {
          final q = state.uri.queryParameters;
          final color = switch (q['color']) {
            'black' => PieceColor.black,
            'white' => PieceColor.white,
            _ => math.Random().nextBool() ? PieceColor.white : PieceColor.black,
          };
          return ChessBotScreen(
            opponent: switch (q['opponent']) {
              'local' => null,
              final k when k == kChessRobot.key => kChessRobot,
              _ => kChessChip,
            },
            level: BotLevel.values.firstWhere(
              (l) => l.name == q['level'],
              orElse: () => BotLevel.normal,
            ),
            myColor: q['opponent'] == 'local' ? PieceColor.white : color,
            clock: _botClock(q),
            resume: q['resume'] == '1',
          );
        },
      ),
      GoRoute(
        path: '/chess/:matchId',
        builder: (context, state) =>
            ChessMatchScreen(matchId: state.pathParameters['matchId']!),
      ),
      GoRoute(
        path: '/checkers',
        builder: (context, state) =>
            const ChessLobbyScreen(game: GameKind.checkers),
      ),
      // Offline: against Chip or Robo, or two players on one phone
      // (opponent=local). Before /checkers/:matchId.
      GoRoute(
        path: '/checkers/bot',
        builder: (context, state) {
          final q = state.uri.queryParameters;
          final side = switch (q['color']) {
            'black' => CheckersSide.light,
            'white' => CheckersSide.dark,
            _ =>
              math.Random().nextBool() ? CheckersSide.dark : CheckersSide.light,
          };
          return CheckersBotScreen(
            opponent: switch (q['opponent']) {
              'local' => null,
              final k when k == kChessRobot.key => kChessRobot,
              _ => kChessChip,
            },
            level: BotLevel.values.firstWhere(
              (l) => l.name == q['level'],
              orElse: () => BotLevel.normal,
            ),
            mySide: q['opponent'] == 'local' ? CheckersSide.dark : side,
            clock: _botClock(q),
            resume: q['resume'] == '1',
          );
        },
      ),
      GoRoute(
        path: '/checkers/:matchId',
        builder: (context, state) =>
            CheckersMatchScreen(matchId: state.pathParameters['matchId']!),
      ),
      GoRoute(
        path: '/ludo',
        builder: (context, state) => const LudoLobbyScreen(),
      ),
      GoRoute(
        path: '/ludo/room/:roomId',
        builder: (context, state) =>
            LudoRoomScreen(roomId: state.pathParameters['roomId']!),
      ),
      GoRoute(
        path: '/ludo/:matchId',
        builder: (context, state) =>
            LudoMatchScreen(matchId: state.pathParameters['matchId']!),
      ),
      // Invite links (https://utopia.kaivon.app/join?game=ludo&code=...),
      // opened by the phone straight into the app.
      GoRoute(
        path: '/join',
        builder: (context, state) =>
            JoinInviteScreen(invite: GameInvite.fromUri(state.uri)),
      ),
      GoRoute(
        path: '/guess-my-doodle',
        builder: (context, state) => const GuessDoodleLobbyScreen(),
      ),
      // Chip draws, you guess: Guess My Doodle on your own.
      GoRoute(
        path: '/guess-my-doodle/chip',
        builder: (context, state) => const ChipDoodleScreen(),
      ),
      GoRoute(
        path: '/doodle-game/:gameId',
        builder: (context, state) =>
            GuessDoodleScreen(gameId: state.pathParameters['gameId']!),
      ),
    ],
  );
});

/// The app's two "landing" screens (what the splash hands off to, and where
/// signing in/out lands) fade and settle in rather than sliding sideways
/// like a drill-down — they replace the whole screen, not push onto it.
CustomTransitionPage<void> _fadeIn(GoRouterState state, Widget child) {
  return CustomTransitionPage<void>(
    key: state.pageKey,
    child: child,
    transitionDuration: const Duration(milliseconds: 450),
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      final curved = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutCubic,
      );
      return FadeTransition(
        opacity: curved,
        child: ScaleTransition(
          scale: Tween(begin: 0.96, end: 1.0).animate(curved),
          child: child,
        ),
      );
    },
  );
}

/// While a sign-in is finishing (the guest portal trip, or an email
/// sign-in's "done" moment and birthday step), the sign-in screens stay
/// put instead of the router sending the new session home: they move on
/// themselves.
abstract final class SignInTrip {
  static bool holding = false;
}

/// Whether the splash has handed off yet. A link that opens the app starts
/// it at the link instead of the splash.
abstract final class SplashHandoff {
  static bool done = false;
}

String? _redirect(AuthRepository authRepository, GoRouterState state) {
  final location = state.matchedLocation;
  // The splash plays its intro and then routes itself (see SplashScreen).
  // Redirecting away from it here would skip it before its first frame.
  if (location == '/splash') return null;

  final hasSession = authRepository.currentSession != null;

  // An invite opened before the app is ready for it (still starting, or
  // nobody signed in yet) waits, and is taken up on the way home (below).
  if (location == '/join' && (!SplashHandoff.done || !hasSession)) {
    final invite = GameInvite.fromUri(state.uri);
    if (invite != null) PendingInvite.hold(invite);
    return SplashHandoff.done ? '/auth' : '/splash';
  }

  if (!hasSession) {
    // Signed-out users may only see the choice screen or the email-link
    // screen (used there for fresh sign-in/sign-up); everything else bounces
    // to the choice screen.
    return location.startsWith('/auth') ? null : '/auth';
  }

  // Signed in (including anonymous): the choice screen has nothing left to
  // do, so send them to the lobby. `/auth/link` stays reachable while
  // signed in — that's the "save your account" upgrade path for anonymous
  // users, reached explicitly from the home screen banner.
  // (A screen pushed over /auth, like /auth/link, is seen here as /auth.)
  if (location == '/auth' && SignInTrip.holding) return null;
  if (location == '/auth' || location == '/home') {
    final invite = PendingInvite.take();
    if (invite != null) return invite.location;
  }
  return location == '/auth' ? '/home' : null;
}

/// The clock picked for a game on this phone (`?clock=` minutes and
/// `&inc=` seconds a move), or null for none.
TimeControl? _botClock(Map<String, String> q) {
  final minutes = int.tryParse(q['clock'] ?? '') ?? 0;
  if (minutes <= 0) return null;
  return TimeControl(minutes, int.tryParse(q['inc'] ?? '') ?? 0);
}
