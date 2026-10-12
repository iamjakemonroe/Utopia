import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/audio/game_audio.dart';
import '../../../core/profiles/profile_providers.dart';
import '../../../core/profiles/profile_repository.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/bouncy_dialog.dart';
import '../../../core/widgets/coin_buddy.dart';
import '../../../core/widgets/pop_card.dart';
import '../../../core/widgets/primary_button.dart';
import '../../../core/widgets/user_avatar.dart';
import '../../../core/widgets/utopia_toast.dart';
import '../../auth/presentation/providers/auth_providers.dart';
import '../../auth/presentation/widgets/auth_world.dart';

/// What the player typed, ready to save.
class _Names {
  const _Names({required this.nickname, required this.username});

  final String? nickname;
  final String? username;
}

/// Lets the player change their nickname (what everyone sees; spaces are
/// fine and it needn't be unique) and their username (the unique @handle
/// friends search for). Checks both as they type, saves what changed and
/// refreshes their profile.
Future<void> editProfileNames(BuildContext context, WidgetRef ref) async {
  final myId = ref.read(currentUserProvider)?.id;
  if (myId == null) return;
  final profile = ref.read(profileByIdProvider(myId)).valueOrNull;
  final currentNick = profile?['display_name'] as String?;
  final currentUser = profile?['username'] as String?;

  final names = await showBouncyDialog<_Names>(
    context: context,
    audio: ref.read(gameAudioProvider),
    builder: (context) =>
        _NamesCard(nickname: currentNick, username: currentUser),
  );
  if (names == null || !context.mounted) return;

  final repo = ref.read(profileRepositoryProvider);
  try {
    if (names.username != null && names.username != currentUser) {
      await repo.setUsername(names.username!);
    }
    if (names.nickname != null && names.nickname != (currentNick ?? '')) {
      await repo.setNickname(names.nickname!);
    }
    ref.invalidate(profileByIdProvider(myId));
    ref.read(gameAudioProvider).play(Sfx.reaction);
    if (context.mounted) {
      final shown = names.nickname?.isNotEmpty == true
          ? names.nickname!
          : names.username ?? currentUser ?? '';
      showUtopiaToast(
        context,
        shown.isEmpty ? 'Saved' : "You're ${_capitalized(shown)} now",
        icon: Icons.badge_rounded,
        kind: ToastKind.success,
      );
    }
  } catch (e) {
    ref.invalidate(profileByIdProvider(myId));
    if (context.mounted) {
      showUtopiaToast(
        context,
        friendlyError(e, fallback: "That name didn't work. Try another."),
        kind: ToastKind.error,
      );
    }
  }
}

/// Kept for older call sites: the same editor.
Future<void> editUsername(
  BuildContext context,
  WidgetRef ref, {
  String? current,
}) => editProfileNames(context, ref);

String _capitalized(String s) =>
    s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);

enum _Availability { unknown, checking, free, taken }

class _NamesCard extends ConsumerStatefulWidget {
  const _NamesCard({this.nickname, this.username});

  final String? nickname;
  final String? username;

  @override
  ConsumerState<_NamesCard> createState() => _NamesCardState();
}

class _NamesCardState extends ConsumerState<_NamesCard> {
  late final _nick = TextEditingController(text: widget.nickname ?? '');
  late final _user = TextEditingController(text: widget.username ?? '');
  static final _userChars = RegExp(r'^[a-z0-9_]*$');
  static final _nickChars = RegExp(
    r"^[\p{L}\p{N}][\p{L}\p{N} _.'-]*$",
    unicode: true,
  );
  Timer? _debounce;
  _Availability _availability = _Availability.unknown;

  String get _nickText => _nick.text.trim().replaceAll(RegExp(r'\s+'), ' ');
  String get _userText => _user.text.trim();

  bool get _nickOk =>
      _nickText.isEmpty ||
      (_nickText.length >= 2 &&
          _nickText.length <= 24 &&
          _nickChars.hasMatch(_nickText));
  bool get _userLengthOk => _userText.length >= 3 && _userText.length <= 20;
  bool get _userCharsOk =>
      _userText.isNotEmpty && _userChars.hasMatch(_userText);
  bool get _userUnchanged => _userText == (widget.username ?? '');
  bool get _nickUnchanged => _nickText == (widget.nickname ?? '');

  /// The username is fine to keep or to save.
  bool get _userOk => _userUnchanged
      ? widget.username != null
      : _userLengthOk && _userCharsOk && _availability == _Availability.free;

  bool get _ok => _nickOk && _userOk && !(_nickUnchanged && _userUnchanged);

  @override
  void initState() {
    super.initState();
    _nick.addListener(() => setState(() {}));
    _user.addListener(_userChanged);
  }

  void _userChanged() {
    _debounce?.cancel();
    setState(() {
      _availability = _userLengthOk && _userCharsOk && !_userUnchanged
          ? _Availability.checking
          : _Availability.unknown;
    });
    if (_availability != _Availability.checking) return;
    final text = _userText;
    _debounce = Timer(const Duration(milliseconds: 450), () async {
      final me = ref.read(currentUserProvider)?.id ?? '';
      try {
        final taken = await ref
            .read(profileRepositoryProvider)
            .isUsernameTaken(text, me);
        if (!mounted || text != _userText) return;
        setState(
          () =>
              _availability = taken ? _Availability.taken : _Availability.free,
        );
      } catch (_) {
        // Couldn't check; let the server decide on save.
        if (mounted && text == _userText) {
          setState(() => _availability = _Availability.free);
        }
      }
    });
  }

  void _save() {
    if (!_ok) return;
    Navigator.of(context).pop(
      _Names(
        nickname: _nickUnchanged ? null : _nickText,
        username: _userUnchanged ? null : _userText,
      ),
    );
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _nick.dispose();
    _user.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final me = ref.watch(currentUserProvider)?.id;
    final profile = me == null
        ? null
        : ref.watch(profileByIdProvider(me)).valueOrNull;
    final shownName = _nickText.isNotEmpty
        ? _nickText
        : _userText.isNotEmpty
        ? _capitalized(_userText)
        : (me == null ? 'You' : profileDisplayName(profile, me));
    final mood = _availability == _Availability.taken || !_nickOk
        ? BuddyMood.sad
        : _ok
        ? BuddyMood.excited
        : BuddyMood.thinking;

    return Material(
      type: MaterialType.transparency,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: PopCard(
          borderRadius: 30,
          glow: _availability == _Availability.taken
              ? AppColors.error
              : AppColors.accent,
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(child: CoinBuddy(mood: mood, size: 70)),
                Text(
                  'Your name',
                  textAlign: TextAlign.center,
                  style: AppTextStyles.display(fontSize: 24),
                ),
                const SizedBox(height: AppSpacing.md),
                // A live preview of how others will see them.
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(18),
                    color: Colors.black.withValues(alpha: 0.22),
                  ),
                  child: Row(
                    children: [
                      UserAvatar.fromProfile(
                        profile,
                        fallbackInitial: shownName,
                        radius: 20,
                        showAura: false,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            AnimatedSwitcher(
                              duration: const Duration(milliseconds: 200),
                              child: Text(
                                shownName,
                                key: ValueKey(shownName),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: AppTextStyles.body(
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                            if (_userText.isNotEmpty)
                              Text(
                                '@$_userText',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: AppTextStyles.body(
                                  fontSize: 12,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                const _FieldLabel(
                  title: 'Nickname',
                  hint: 'What everyone sees. Spaces are fine.',
                ),
                const SizedBox(height: 6),
                UtopiaTextField(
                  controller: _nick,
                  icon: Icons.badge_rounded,
                  hint: 'Jake Monroe',
                  textCapitalization: TextCapitalization.words,
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(
                      RegExp(r"[\p{L}\p{N} _.'-]", unicode: true),
                    ),
                    LengthLimitingTextInputFormatter(24),
                  ],
                  onSubmitted: (_) => _save(),
                ),
                if (!_nickOk)
                  Padding(
                    padding: const EdgeInsets.only(top: 6, left: 4),
                    child: Text(
                      'Use 2 to 24 letters or numbers (spaces are fine).',
                      style: AppTextStyles.body(
                        fontSize: 12,
                        color: AppColors.error,
                      ),
                    ),
                  ),
                const SizedBox(height: AppSpacing.md),
                const _FieldLabel(
                  title: 'Username',
                  hint: 'Yours alone. Friends find you with it.',
                ),
                const SizedBox(height: 6),
                UtopiaTextField(
                  controller: _user,
                  icon: Icons.alternate_email_rounded,
                  hint: 'yourname',
                  inputFormatters: [
                    LowerCaseFormatter(),
                    FilteringTextInputFormatter.allow(RegExp('[a-z0-9_]')),
                    LengthLimitingTextInputFormatter(20),
                  ],
                  onSubmitted: (_) => _save(),
                ),
                const SizedBox(height: AppSpacing.sm),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    _Check(ok: _userLengthOk, label: '3 to 20 long'),
                    _Check(ok: _userCharsOk, label: 'Letters, numbers, _'),
                    if (_userUnchanged && widget.username != null)
                      const _Check(ok: true, label: 'Yours')
                    else
                      _AvailabilityCheck(state: _availability),
                  ],
                ),
                const SizedBox(height: AppSpacing.lg),
                PrimaryButton(
                  label: 'Save',
                  color: AppColors.success,
                  onPressed: _ok ? _save : null,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel({required this.title, required this.hint});

  final String title;
  final String hint;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          Text(title, style: AppTextStyles.body(fontWeight: FontWeight.w900)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              hint,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.body(
                fontSize: 12,
                color: AppColors.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class LowerCaseFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue old, TextEditingValue v) =>
      v.copyWith(text: v.text.toLowerCase());
}

class _Check extends StatelessWidget {
  const _Check({required this.ok, required this.label});

  final bool ok;
  final String label;

  @override
  Widget build(BuildContext context) {
    final color = ok ? AppColors.success : AppColors.textSecondary;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        color: color.withValues(alpha: 0.14),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 250),
            transitionBuilder: (c, a) => ScaleTransition(scale: a, child: c),
            child: Icon(
              ok ? Icons.check_circle_rounded : Icons.radio_button_unchecked,
              key: ValueKey(ok),
              size: 14,
              color: color,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: AppTextStyles.body(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _AvailabilityCheck extends StatelessWidget {
  const _AvailabilityCheck({required this.state});

  final _Availability state;

  @override
  Widget build(BuildContext context) {
    return switch (state) {
      _Availability.unknown => const _Check(ok: false, label: 'Available'),
      _Availability.free => const _Check(ok: true, label: 'Available'),
      _Availability.taken => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          color: AppColors.error.withValues(alpha: 0.14),
          border: Border.all(color: AppColors.error.withValues(alpha: 0.6)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cancel_rounded, size: 14, color: AppColors.error),
            const SizedBox(width: 4),
            Text(
              'Taken',
              style: AppTextStyles.body(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: AppColors.error,
              ),
            ),
          ],
        ),
      ),
      _Availability.checking => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          color: Colors.white.withValues(alpha: 0.08),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox.square(
              dimension: 12,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: AppColors.accentSecondary,
              ),
            ),
            const SizedBox(width: 6),
            Text(
              'Checking',
              style: AppTextStyles.body(
                fontSize: 12,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    };
  }
}
