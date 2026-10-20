import '../../../l10n/strings.dart';

/// Where game invite links live: the Utopia site, which opens the app when
/// it's installed (see utopia-landingpage/public/.well-known) and shows the
/// code and how to get Utopia when it isn't (public/join.html).
const kInviteHost = 'utopia.kaivon.app';

/// The games a link can invite someone to.
enum InviteGame {
  ludo('ludo'),
  doodle('doodle');

  const InviteGame(this.key);

  /// The link's `game=` value.
  final String key;

  String get title => switch (this) {
    InviteGame.ludo => strings.gameInviteLudo,
    InviteGame.doodle => strings.gameInviteGuessMyDoodle,
  };
}

/// An invite to a friend's room: https://utopia.kaivon.app/join?game=ludo&code=ABC234.
class GameInvite {
  const GameInvite(this.game, this.code);

  final InviteGame game;

  /// The room's code: six letters and digits, without look-alikes.
  final String code;

  static final _code = RegExp(r'^[A-HJKMNP-Z2-9]{6}$');

  /// The invite in [uri] (a full link or just its path and query), or null
  /// when it isn't a valid one.
  static GameInvite? fromUri(Uri uri) {
    if (uri.path != '/join') return null;
    final key = uri.queryParameters['game'];
    final game = InviteGame.values.where((g) => g.key == key).firstOrNull;
    final code = (uri.queryParameters['code'] ?? '').toUpperCase();
    if (game == null || !_code.hasMatch(code)) return null;
    return GameInvite(game, code);
  }

  /// The link to share.
  Uri get link =>
      Uri.https(kInviteHost, '/join', {'game': game.key, 'code': code});

  /// The in-app location that joins it.
  String get location => '/join?game=${game.key}&code=$code';

  @override
  bool operator ==(Object other) =>
      other is GameInvite && other.game == game && other.code == code;

  @override
  int get hashCode => Object.hash(game, code);
}

/// An invite opened before the player could take it (the app was still
/// starting, or nobody was signed in): it waits here until they reach home.
abstract final class PendingInvite {
  static GameInvite? _invite;

  static void hold(GameInvite invite) => _invite = invite;

  /// The invite waiting, if any, now taken.
  static GameInvite? take() {
    final invite = _invite;
    _invite = null;
    return invite;
  }
}
