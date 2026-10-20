import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/profiles/profile_providers.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/coin_buddy.dart';
import '../../../../core/widgets/primary_button.dart';
import '../../../../core/widgets/user_avatar.dart';
import '../../../coins/presentation/player_coins.dart';
import '../../../ludo/presentation/screens/ludo_lobby_screen.dart'
    show CodeTiles;
import '../../domain/doodle_game.dart';
import 'doodle_chat.dart';
import '../../../../l10n/strings.dart';

/// A soft dark veil over the paper, so what's on it stays readable.
class _Veil extends StatelessWidget {
  const _Veil({required this.child, this.strength = 0.72});

  final Widget child;
  final double strength;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOut,
      builder: (context, v, child) => Opacity(opacity: v, child: child),
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              AppColors.background.withValues(alpha: strength * 0.92),
              AppColors.background.withValues(alpha: strength),
            ],
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Center(
            child: FittedBox(fit: BoxFit.scaleDown, child: child),
          ),
        ),
      ),
    );
  }
}

/// Waiting to start. A private game shows its code to share and who's in;
/// the host starts it. A public game starts by itself once two are in.
class DoodleWaitingRoom extends ConsumerWidget {
  const DoodleWaitingRoom({
    super.key,
    required this.game,
    required this.players,
    required this.me,
    required this.offset,
    required this.onCopy,
    required this.onShare,
    required this.onStart,
  });

  final DoodleGame game;
  final List<DoodlePlayer> players;
  final String? me;
  final Duration offset;
  final VoidCallback onCopy;
  final VoidCallback onShare;
  final Future<void> Function() onStart;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final host = game.hostId == me;
    final enough = players.length >= 2;
    return _Veil(
      child: SizedBox(
        width: 320,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (game.isPublic) ...[
              CoinBuddy(
                mood: enough ? BuddyMood.excited : BuddyMood.thinking,
                size: 96,
              ),
              const SizedBox(height: 6),
              Text(
                enough
                    ? strings.doodleOverlaysStartingSoon
                    : strings.doodleOverlaysFindingPlayers,
                style: AppTextStyles.display(fontSize: 24),
              ),
              const SizedBox(height: 4),
              if (enough && game.phaseEndsAt != null)
                _Countdown(endsAt: game.phaseEndsAt!, offset: offset)
              else
                Text(
                  strings.doodleOverlaysTheGameStartsWhenSomeone,
                  textAlign: TextAlign.center,
                  style: AppTextStyles.body(
                    fontSize: 14,
                    color: AppColors.textSecondary,
                  ),
                ),
            ] else ...[
              Text(
                strings.doodleOverlaysInviteFriends,
                style: AppTextStyles.display(fontSize: 22),
              ),
              const SizedBox(height: 10),
              GestureDetector(
                onTap: onCopy,
                child: CodeTiles(code: game.code, size: 36),
              ),
              const SizedBox(height: 10),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _SmallButton(
                    icon: Icons.content_copy_rounded,
                    label: strings.doodleOverlaysCopy,
                    onTap: onCopy,
                  ),
                  const SizedBox(width: 10),
                  _SmallButton(
                    icon: Icons.ios_share_rounded,
                    label: strings.doodleOverlaysShare,
                    onTap: onShare,
                  ),
                ],
              ),
            ],
            const SizedBox(height: 14),
            Text(
              strings.doodleOverlaysOfPlayers(players.length, game.maxPlayers),
              style: AppTextStyles.body(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 8),
            // A big room (up to 20): smaller seats, more to a row.
            Wrap(
              spacing: players.length > 8 ? 6 : 10,
              runSpacing: players.length > 8 ? 6 : 8,
              alignment: WrapAlignment.center,
              children: [
                for (final p in players)
                  _Seat(
                    userId: p.userId,
                    me: me,
                    host: game.hostId,
                    compact: players.length > 8,
                  ),
              ],
            ),
            if (!game.isPublic) ...[
              const SizedBox(height: 16),
              if (host)
                SizedBox(
                  width: 240,
                  child: PrimaryButton(
                    label: enough
                        ? strings.doodleOverlaysStartGame
                        : strings.doodleOverlaysWaitingForFriends,
                    onPressed: enough ? onStart : null,
                  ),
                )
              else
                Text(
                  strings.doodleOverlaysWaitingForToStart(
                    doodleName(ref, game.hostId, me),
                  ),
                  style: AppTextStyles.body(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textSecondary,
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Seat extends ConsumerWidget {
  const _Seat({
    required this.userId,
    required this.me,
    required this.host,
    this.compact = false,
  });

  final String userId;
  final String? me;
  final String host;
  final bool compact;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final name = doodleName(ref, userId, me);
    return SizedBox(
      width: compact ? 46 : 64,
      child: Column(
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              UserAvatar.fromProfile(
                ref.watch(profileByIdProvider(userId)).valueOrNull,
                fallbackInitial: name.isEmpty ? '?' : name[0],
                radius: compact ? 16 : 22,
              ),
              if (userId == host)
                const Positioned(
                  right: -4,
                  top: -4,
                  child: Icon(
                    Icons.star_rounded,
                    size: 18,
                    color: Color(0xFFFFC94D),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.body(
              fontSize: compact ? 10 : 12,
              fontWeight: FontWeight.w800,
            ),
          ),
          if (!compact) PlayerCoins(userId: userId, size: 10),
        ],
      ),
    );
  }
}

class _SmallButton extends StatelessWidget {
  const _SmallButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.onWorld.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 18, color: AppColors.onWorld),
              const SizedBox(width: 6),
              Text(
                label,
                style: AppTextStyles.body(
                  fontWeight: FontWeight.w800,
                  color: AppColors.onWorld,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// "Starting in 7", counting down to [endsAt] on the server's clock.
class _Countdown extends StatefulWidget {
  const _Countdown({required this.endsAt, required this.offset});

  final DateTime endsAt;
  final Duration offset;

  @override
  State<_Countdown> createState() => _CountdownState();
}

class _CountdownState extends State<_Countdown> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(
      const Duration(milliseconds: 250),
      (_) => mounted ? setState(() {}) : null,
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final left = widget.endsAt.difference(DateTime.now().add(widget.offset));
    final s = (left.inMilliseconds / 1000).ceil().clamp(0, 99);
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 250),
      transitionBuilder: (child, a) => ScaleTransition(
        scale: CurvedAnimation(parent: a, curve: Curves.easeOutBack),
        child: child,
      ),
      child: Text(
        s > 0
            ? strings.doodleOverlaysStartingIn(s)
            : strings.doodleOverlaysHereWeGo,
        key: ValueKey(s),
        style: AppTextStyles.display(
          fontSize: 20,
          color: AppColors.readable(AppColors.coinGold),
        ),
      ),
    );
  }
}

/// The drawer picks one of three words; everyone else waits with Chip.
class DoodleChoosing extends ConsumerStatefulWidget {
  const DoodleChoosing({
    super.key,
    required this.drawerId,
    required this.me,
    required this.choices,
    required this.onChoose,
  });

  final String? drawerId;
  final String? me;
  final List<String> choices;
  final Future<void> Function(int index) onChoose;

  @override
  ConsumerState<DoodleChoosing> createState() => _DoodleChoosingState();
}

class _DoodleChoosingState extends ConsumerState<DoodleChoosing> {
  int? _picked;

  @override
  Widget build(BuildContext context) {
    final mine = widget.drawerId != null && widget.drawerId == widget.me;
    if (!mine) {
      return _Veil(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CoinBuddy(mood: BuddyMood.thinking, size: 110),
            const SizedBox(height: 8),
            Text(
              strings.doodleOverlaysIsPickingAWord(
                doodleName(ref, widget.drawerId, widget.me),
              ),
              textAlign: TextAlign.center,
              style: AppTextStyles.display(fontSize: 20),
            ),
            const SizedBox(height: 4),
            Text(
              strings.doodleOverlaysGetReadyToGuess,
              style: AppTextStyles.body(color: AppColors.textSecondary),
            ),
          ],
        ),
      );
    }
    return _Veil(
      child: SizedBox(
        width: 300,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              strings.doodleOverlaysPickAWordToDraw,
              style: AppTextStyles.display(fontSize: 24),
            ),
            const SizedBox(height: 14),
            if (widget.choices.isEmpty)
              const Padding(
                padding: EdgeInsets.all(20),
                child: CircularProgressIndicator(),
              )
            else
              for (var i = 0; i < widget.choices.length; i++)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0, end: 1),
                    duration: Duration(milliseconds: 420 + i * 110),
                    curve: Curves.easeOutBack,
                    builder: (context, v, child) => Transform.translate(
                      offset: Offset(0, 24 * (1 - v)),
                      child: Opacity(opacity: v.clamp(0, 1), child: child),
                    ),
                    child: _WordChoice(
                      word: widget.choices[i],
                      color: const [
                        Color(0xFF2FD98E),
                        Color(0xFF5AB8FF),
                        Color(0xFFFF8FB8),
                      ][i % 3],
                      picked: _picked == i,
                      dimmed: _picked != null && _picked != i,
                      onTap: _picked != null
                          ? null
                          : () async {
                              HapticFeedback.mediumImpact();
                              setState(() => _picked = i);
                              try {
                                await widget.onChoose(i);
                              } catch (_) {
                                if (mounted) setState(() => _picked = null);
                              }
                            },
                    ),
                  ),
                ),
          ],
        ),
      ),
    );
  }
}

class _WordChoice extends StatelessWidget {
  const _WordChoice({
    required this.word,
    required this.color,
    required this.picked,
    required this.dimmed,
    required this.onTap,
  });

  final String word;
  final Color color;
  final bool picked;
  final bool dimmed;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 200),
      opacity: dimmed ? 0.35 : 1,
      child: AnimatedScale(
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOutBack,
        scale: picked ? 1.06 : 1,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: onTap,
            child: Ink(
              height: 58,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color.lerp(color, Colors.white, 0.3)!, color],
                ),
                border: Border.all(color: Colors.white, width: 2),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.depthShade(color),
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Center(
                child: Text(
                  word.toUpperCase(),
                  style: AppTextStyles.display(
                    fontSize: 22,
                    color: Colors.white,
                  ).copyWith(letterSpacing: 1.5),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The turn's over: the word, and what everyone got for it.
class DoodleReveal extends ConsumerWidget {
  const DoodleReveal({
    super.key,
    required this.word,
    required this.players,
    required this.drawerId,
    required this.me,
  });

  final String? word;
  final List<DoodlePlayer> players;
  final String? drawerId;
  final String? me;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ranked = [...players]
      ..sort((a, b) => b.turnPoints.compareTo(a.turnPoints));
    final nobody = ranked.every((p) => p.turnPoints == 0);
    final (shown, more) = _top(ranked, me, 8);
    return _Veil(
      strength: 0.8,
      child: SizedBox(
        width: 300,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              nobody
                  ? strings.doodleOverlaysNobodyGotIt
                  : strings.doodleOverlaysTheWordWas,
              style: AppTextStyles.body(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: AppColors.textSecondary,
              ),
            ),
            if (nobody)
              Text(
                strings.doodleOverlaysTheWordWas,
                style: AppTextStyles.body(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                ),
              ),
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0.4, end: 1),
              duration: const Duration(milliseconds: 700),
              curve: Curves.elasticOut,
              builder: (context, v, child) =>
                  Transform.scale(scale: v, child: child),
              child: Text(
                (word ?? '').toUpperCase(),
                textAlign: TextAlign.center,
                style: AppTextStyles.display(
                  fontSize: 34,
                  color: AppColors.readable(AppColors.coinGold),
                ).copyWith(letterSpacing: 2),
              ),
            ),
            const SizedBox(height: 12),
            for (var i = 0; i < shown.length; i++)
              TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: 1),
                duration: Duration(milliseconds: 300 + i * 90),
                curve: Curves.easeOut,
                builder: (context, v, child) => Opacity(
                  opacity: v,
                  child: Transform.translate(
                    offset: Offset(20 * (1 - v), 0),
                    child: child,
                  ),
                ),
                child: _ScoreRow(
                  userId: shown[i].userId,
                  me: me,
                  points: shown[i].turnPoints,
                  drew: shown[i].userId == drawerId,
                ),
              ),
            _More(more),
          ],
        ),
      ),
    );
  }
}

class _ScoreRow extends ConsumerWidget {
  const _ScoreRow({
    required this.userId,
    required this.me,
    required this.points,
    required this.drew,
  });

  final String userId;
  final String? me;
  final int points;
  final bool drew;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final name = doodleName(ref, userId, me);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          UserAvatar.fromProfile(
            ref.watch(profileByIdProvider(userId)).valueOrNull,
            fallbackInitial: name.isEmpty ? '?' : name[0],
            radius: 13,
            showAura: false,
          ),
          const SizedBox(width: 8),
          if (drew)
            const Padding(
              padding: EdgeInsets.only(right: 4),
              child: Icon(
                Icons.brush_rounded,
                size: 15,
                color: Color(0xFFFFB020),
              ),
            ),
          Expanded(
            child: Text(
              name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.body(fontWeight: FontWeight.w800),
            ),
          ),
          Text(
            points > 0 ? '+$points' : '0',
            style: AppTextStyles.display(
              fontSize: 17,
              color: points > 0
                  ? const Color(0xFF6BF0B0)
                  : AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

/// The final scores: the top three on a podium (the winner crowned, Chip
/// cheering), then a rematch or the next game.
class DoodleScores extends ConsumerWidget {
  const DoodleScores({
    super.key,
    required this.game,
    required this.players,
    required this.me,
    required this.offset,
    required this.onAgain,
    required this.onLeave,
  });

  final DoodleGame game;
  final List<DoodlePlayer> players;
  final String? me;
  final Duration offset;
  final Future<void> Function() onAgain;
  final VoidCallback onLeave;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ranked = [...players]..sort((a, b) => b.score.compareTo(a.score));
    final podium = ranked.take(3).toList();
    final (rest, more) = _top(ranked.skip(3).toList(), me, 7);
    final won = game.winnerIds.contains(me);
    final host = game.hostId == me;
    // Podium order: 2nd, 1st, 3rd.
    final order = [
      if (podium.length > 1) (podium[1], 2),
      if (podium.isNotEmpty) (podium[0], 1),
      if (podium.length > 2) (podium[2], 3),
    ];
    return _Veil(
      strength: 0.85,
      child: SizedBox(
        width: 320,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CoinBuddy(
              mood: won ? BuddyMood.excited : BuddyMood.happy,
              size: 74,
            ),
            Text(
              won
                  ? strings.doodleOverlaysYouWon
                  : strings.doodleOverlaysFinalScores,
              style: AppTextStyles.display(fontSize: 26),
            ),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                for (final (p, place) in order)
                  _Step(userId: p.userId, me: me, score: p.score, place: place),
              ],
            ),
            if (ranked.length > 3) ...[
              const SizedBox(height: 8),
              for (final p in rest)
                _ScoreLine(userId: p.userId, me: me, score: p.score),
              _More(more),
            ],
            const SizedBox(height: 14),
            if (game.isPublic)
              game.phaseEndsAt == null
                  ? const SizedBox.shrink()
                  : _NextIn(endsAt: game.phaseEndsAt!, offset: offset)
            else if (host)
              SizedBox(
                width: 240,
                child: PrimaryButton(
                  label: players.length >= 2
                      ? strings.doodleOverlaysPlayAgain
                      : strings.doodleOverlaysWaitingForFriends,
                  onPressed: players.length >= 2 ? onAgain : null,
                ),
              )
            else
              Text(
                strings.doodleOverlaysTheHostCanStartAnother,
                style: AppTextStyles.body(color: AppColors.textSecondary),
              ),
            const SizedBox(height: 6),
            TextButton(
              onPressed: onLeave,
              child: Text(
                strings.doodleOverlaysLeave,
                style: AppTextStyles.body(
                  fontWeight: FontWeight.w800,
                  color: AppColors.textSecondary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Step extends ConsumerWidget {
  const _Step({
    required this.userId,
    required this.me,
    required this.score,
    required this.place,
  });

  final String userId;
  final String? me;
  final int score;
  final int place;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final name = doodleName(ref, userId, me);
    final color = switch (place) {
      1 => AppColors.coinGold,
      2 => const Color(0xFFD7DCE8),
      _ => const Color(0xFFE0A06A),
    };
    final height = switch (place) {
      1 => 62.0,
      2 => 44.0,
      _ => 32.0,
    };
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 500 + (3 - place) * 150),
      curve: Curves.easeOutBack,
      builder: (context, v, child) => Transform.translate(
        offset: Offset(0, 30 * (1 - v)),
        child: Opacity(opacity: v.clamp(0, 1), child: child),
      ),
      child: SizedBox(
        width: 92,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (place == 1)
              const Icon(
                Icons.emoji_events_rounded,
                size: 22,
                color: Color(0xFFFFC94D),
              ),
            UserAvatar.fromProfile(
              ref.watch(profileByIdProvider(userId)).valueOrNull,
              fallbackInitial: name.isEmpty ? '?' : name[0],
              radius: place == 1 ? 26 : 21,
            ),
            const SizedBox(height: 3),
            Text(
              name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.body(
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
            PlayerCoins(userId: userId, size: 10),
            const SizedBox(height: 3),
            Container(
              width: 80,
              height: height,
              decoration: BoxDecoration(
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(10),
                ),
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [color, Color.lerp(color, Colors.black, 0.35)!],
                ),
              ),
              alignment: Alignment.center,
              child: Text(
                '$score',
                style: AppTextStyles.display(
                  fontSize: 16,
                  color: AppColors.faceInk,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ScoreLine extends ConsumerWidget {
  const _ScoreLine({
    required this.userId,
    required this.me,
    required this.score,
  });

  final String userId;
  final String? me;
  final int score;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SizedBox(
      width: 260,
      child: Row(
        children: [
          Expanded(
            child: Text(
              doodleName(ref, userId, me),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.body(fontWeight: FontWeight.w700),
            ),
          ),
          Text(
            '$score',
            style: AppTextStyles.body(
              fontWeight: FontWeight.w900,
              color: AppColors.readable(AppColors.coinGold),
            ),
          ),
        ],
      ),
    );
  }
}

class _NextIn extends StatefulWidget {
  const _NextIn({required this.endsAt, required this.offset});

  final DateTime endsAt;
  final Duration offset;

  @override
  State<_NextIn> createState() => _NextInState();
}

class _NextInState extends State<_NextIn> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(
      const Duration(milliseconds: 500),
      (_) => mounted ? setState(() {}) : null,
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final left = widget.endsAt.difference(DateTime.now().add(widget.offset));
    final s = (left.inMilliseconds / 1000).ceil().clamp(0, 99);
    return Text(
      s > 0
          ? strings.doodleOverlaysNextGameIn(s)
          : strings.doodleOverlaysNextGameStarting,
      style: AppTextStyles.display(
        fontSize: 18,
        color: AppColors.readable(AppColors.coinGold),
      ),
    );
  }
}

/// The game ended (everyone else left, or it went quiet too long).
class DoodleEnded extends StatelessWidget {
  const DoodleEnded({super.key, required this.onBack});

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return _Veil(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CoinBuddy(mood: BuddyMood.sad, size: 96),
          const SizedBox(height: 6),
          Text(
            strings.doodleOverlaysThisGameHasEnded,
            style: AppTextStyles.display(fontSize: 22),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: 220,
            child: PrimaryButton(
              label: strings.doodleOverlaysBack,
              onPressed: onBack,
            ),
          ),
        ],
      ),
    );
  }
}

/// The first [count] of [ranked], and [me] if they're further down (a
/// room of 20 doesn't fit the board), and how many are left out.
(List<DoodlePlayer>, int) _top(
  List<DoodlePlayer> ranked,
  String? me,
  int count,
) {
  if (ranked.length <= count) return (ranked, 0);
  final shown = ranked.take(count).toList();
  final mine = ranked.skip(count).where((p) => p.userId == me).firstOrNull;
  if (mine != null) shown.add(mine);
  return (shown, ranked.length - shown.length);
}

/// "and 9 more", under a list cut short.
class _More extends StatelessWidget {
  const _More(this.count);

  final int count;

  @override
  Widget build(BuildContext context) {
    if (count <= 0) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Text(
        strings.doodleOverlaysAndMore(count),
        style: AppTextStyles.body(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: AppColors.textSecondary,
        ),
      ),
    );
  }
}
