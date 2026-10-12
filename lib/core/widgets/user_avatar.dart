import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../../features/auras/domain/aura.dart';
import '../../features/auras/presentation/aura_frame.dart';
import 'coin_buddy.dart';
import 'generated_avatar.dart';

/// A user's identity image, in priority order: an uploaded photo, else
/// their generated avatar (kind + seed — see [GeneratedAvatar]; every
/// account gets one automatically at signup so this is the common case for
/// anyone who hasn't uploaded a photo), else a bare initial as a last
/// resort. Used everywhere a person shows up: match player bars, friends
/// list, invite cards, the profile screen.
class UserAvatar extends StatelessWidget {
  const UserAvatar({
    super.key,
    required this.avatarUrl,
    required this.fallbackInitial,
    this.avatarKind,
    this.avatarSeed,
    this.radius = 16,
    this.aura,
  });

  /// Reads avatar_url/avatar_kind/avatar_seed straight off a profile row
  /// (as returned by ProfileRepository), so call sites don't each repeat
  /// the same three map lookups.
  ///
  /// The player's aura comes along too, while it's active; pass [aura] to
  /// preview a different one (the store does).
  factory UserAvatar.fromProfile(
    Map<String, dynamic>? profile, {
    required String fallbackInitial,
    double radius = 16,
    String? aura,
    bool showAura = true,
  }) {
    return UserAvatar(
      avatarUrl: profile?['avatar_url'] as String?,
      avatarKind: profile?['avatar_kind'] as String?,
      avatarSeed: (profile?['avatar_seed'] as num?)?.toInt(),
      fallbackInitial: fallbackInitial,
      radius: radius,
      aura: showAura ? (aura ?? activeAura(profile)) : null,
    );
  }

  final String? avatarUrl;
  final String? avatarKind;
  final int? avatarSeed;
  final String fallbackInitial;
  final double radius;

  /// An aura to draw around the avatar (see [AuraFrame]).
  final String? aura;

  @override
  Widget build(BuildContext context) {
    final avatar = _avatar();
    final a = aura;
    if (a == null) return avatar;
    return AuraFrame(aura: a, radius: radius, child: avatar);
  }

  Widget _avatar() {
    final url = avatarUrl;
    final hasPhoto = url != null && url.isNotEmpty;
    final kind = avatarKind;
    final seed = avatarSeed;

    // Computer players: Chip himself, or a little robot.
    if (!hasPhoto && kind == 'chip') return _botFrame(_chip());
    if (!hasPhoto && kind == 'robot') return _botFrame(_robot());

    // Generated characters already draw their own colored rim, so the gold
    // photo frame below would just add a second ring around it.
    if (!hasPhoto && kind != null && seed != null) {
      return GeneratedAvatar(kind: kind, seed: seed, size: radius * 2);
    }

    return Container(
      width: radius * 2,
      height: radius * 2,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: AppColors.accentSecondary, width: 1.5),
        boxShadow: const [
          BoxShadow(
            color: Colors.black38,
            offset: Offset(0, 1.5),
            blurRadius: 2,
          ),
        ],
      ),
      child: ClipOval(
        child: hasPhoto
            ? Image.network(
                url,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => _initial(),
              )
            : _initial(),
      ),
    );
  }

  Widget _botFrame(Widget face) {
    return Container(
      width: radius * 2,
      height: radius * 2,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          center: const Alignment(-0.3, -0.4),
          colors: [
            Color.lerp(AppColors.surfaceElevated, Colors.white, 0.15)!,
            AppColors.surface,
          ],
        ),
        border: Border.all(color: AppColors.accentSecondary, width: 1.5),
      ),
      child: ClipOval(child: Center(child: face)),
    );
  }

  Widget _chip() => CoinBuddy(mood: BuddyMood.happy, size: radius * 2.1);

  Widget _robot() => Icon(
    Icons.smart_toy_rounded,
    size: radius * 1.25,
    color: const Color(0xFF7DE8FF),
  );

  Widget _initial() {
    return Container(
      color: AppColors.accent.withValues(alpha: 0.3),
      alignment: Alignment.center,
      child: Text(
        fallbackInitial.isNotEmpty ? fallbackInitial[0].toUpperCase() : '?',
        style: AppTextStyles.body(fontWeight: FontWeight.w700),
      ),
    );
  }
}
