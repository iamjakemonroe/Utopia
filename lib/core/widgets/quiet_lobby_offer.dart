import 'dart:async';

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../theme/app_theme.dart';
import 'coin_buddy.dart';
import 'pop_card.dart';
import 'primary_button.dart';
import '../../l10n/strings.dart';

/// How long a search for players runs before an offline game is offered.
const kQuietLobbyAfter = Duration(seconds: 20);

/// Under a search for players that has found nobody for a while: a free
/// offline game instead, so a quiet hour never means a long wait. The search
/// carries on until they take it or cancel.
class QuietLobbyOffer extends StatefulWidget {
  const QuietLobbyOffer({
    super.key,
    required this.label,
    required this.onPlay,
    this.after = kQuietLobbyAfter,
  });

  /// The button: "Play Chip", "Play with bots".
  final String label;
  final VoidCallback onPlay;
  final Duration after;

  @override
  State<QuietLobbyOffer> createState() => _QuietLobbyOfferState();
}

class _QuietLobbyOfferState extends State<QuietLobbyOffer> {
  bool _shown = false;
  late final Timer _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer(widget.after, () {
      if (mounted) setState(() => _shown = true);
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 350),
      transitionBuilder: (child, animation) => FadeTransition(
        opacity: animation,
        child: SizeTransition(sizeFactor: animation, child: child),
      ),
      child: !_shown
          ? const SizedBox(width: double.infinity)
          : Padding(
              key: const ValueKey('offer'),
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.lg,
                AppSpacing.lg,
                0,
              ),
              child: PopCard(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        const CoinBuddy(mood: BuddyMood.happy, size: 48),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                strings.quietLobbyOfferItSQuietRightNow,
                                style: AppTextStyles.display(fontSize: 17),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                strings.quietLobbyOfferWeLlKeepLookingOr,
                                style: AppTextStyles.body(
                                  fontSize: 13,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.md),
                    PrimaryButton(
                      label: widget.label,
                      color: const Color(0xFF2E8FE0),
                      onPressed: widget.onPlay,
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
