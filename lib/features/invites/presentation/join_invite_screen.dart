import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/audio/game_audio.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_background.dart';
import '../../../core/widgets/coin_buddy.dart';
import '../../../core/widgets/primary_button.dart';
import '../../../core/widgets/utopia_loader.dart';
import '../../guess_doodle/data/doodle_game_repository.dart';
import '../../guess_doodle/presentation/guess_doodle_lobby_screen.dart';
import '../../ludo/presentation/controllers/ludo_match_controller.dart';
import '../../ludo/presentation/screens/ludo_lobby_screen.dart';
import '../domain/game_invite.dart';

/// Where an invite link lands: joins the friend's room, then shows it (over
/// home, so leaving the room goes home). A null [invite] is a broken link.
class JoinInviteScreen extends ConsumerStatefulWidget {
  const JoinInviteScreen({super.key, required this.invite});

  final GameInvite? invite;

  @override
  ConsumerState<JoinInviteScreen> createState() => _JoinInviteScreenState();
}

class _JoinInviteScreenState extends ConsumerState<JoinInviteScreen> {
  String? _error;

  @override
  void initState() {
    super.initState();
    if (widget.invite == null) {
      _error = "That invite link doesn't work. Ask your friend for the code.";
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) => _join());
    }
  }

  Future<void> _join() async {
    final invite = widget.invite!;
    try {
      final location = switch (invite.game) {
        InviteGame.ludo =>
          '/ludo/room/${await ref.read(ludoRepositoryProvider).joinRoom(invite.code)}',
        InviteGame.doodle =>
          '/doodle-game/${await ref.read(doodleGameRepositoryProvider).join(invite.code)}',
      };
      if (!mounted) return;
      ref.read(gameAudioProvider).play(Sfx.reaction);
      final router = GoRouter.of(context);
      router.go('/home');
      router.push(location);
    } catch (e) {
      if (!mounted) return;
      setState(
        () => _error = switch (invite.game) {
          InviteGame.ludo => ludoErrorText(e),
          InviteGame.doodle => doodleErrorText(e),
        },
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final error = _error;
    return Scaffold(
      body: AppBackground(
        child: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: error == null
                  ? UtopiaLoader(
                      size: 88,
                      label: 'Joining ${widget.invite!.game.title}',
                    )
                  : Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const CoinBuddy(mood: BuddyMood.sad, size: 80),
                        const SizedBox(height: AppSpacing.md),
                        Text(
                          error,
                          textAlign: TextAlign.center,
                          style: AppTextStyles.body(
                            color: AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.lg),
                        PrimaryButton(
                          label: 'Go home',
                          onPressed: () => context.go('/home'),
                        ),
                      ],
                    ),
            ),
          ),
        ),
      ),
    );
  }
}
