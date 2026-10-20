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
import '../domain/nickname_rules.dart';
import '../../../l10n/strings.dart';

/// What the player typed, ready to save (null: unchanged).
class ProfileNames {
  const ProfileNames({required this.nickname, required this.username});

  final String? nickname;
  final String? username;
}

/// Saves [names] (what changed from [currentNick] and [currentUser]) and
/// refreshes the player's profile. Throws if the server says no.
Future<void> saveProfileNames(
  WidgetRef ref,
  ProfileNames names, {
  String? currentNick,
  String? currentUser,
}) async {
  final myId = ref.read(currentUserProvider)?.id;
  final repo = ref.read(profileRepositoryProvider);
  try {
    if (names.username != null && names.username != currentUser) {
      await repo.setUsername(names.username!);
    }
    if (names.nickname != null && names.nickname != (currentNick ?? '')) {
      await repo.setNickname(names.nickname!);
    }
  } finally {
    if (myId != null) ref.invalidate(profileByIdProvider(myId));
  }
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

  final names = await showBouncyDialog<ProfileNames>(
    context: context,
    audio: ref.read(gameAudioProvider),
    builder: (context) =>
        _NamesCard(nickname: currentNick, username: currentUser),
  );
  if (names == null || !context.mounted) return;

  try {
    await saveProfileNames(
      ref,
      names,
      currentNick: currentNick,
      currentUser: currentUser,
    );
    ref.read(gameAudioProvider).play(Sfx.reaction);
    if (context.mounted) {
      final shown = names.nickname?.isNotEmpty == true
          ? names.nickname!
          : names.username ?? currentUser ?? '';
      showUtopiaToast(
        context,
        shown.isEmpty
            ? strings.usernameSaved
            : strings.usernameYouReNow(_capitalized(shown)),
        icon: Icons.badge_rounded,
        kind: ToastKind.success,
      );
    }
  } catch (e) {
    if (context.mounted) {
      showUtopiaToast(
        context,
        friendlyError(e, fallback: strings.usernameThatNameDidnTWork),
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

/// The names editor in the profile's dialog.
class _NamesCard extends StatelessWidget {
  const _NamesCard({this.nickname, this.username});

  final String? nickname;
  final String? username;

  @override
  Widget build(BuildContext context) {
    return Material(
      type: MaterialType.transparency,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: NamesForm(
          nickname: nickname,
          username: username,
          title: strings.usernameYourName,
          submitLabel: strings.usernameSave,
          onSubmit: (names) => Navigator.of(context).pop(names),
        ),
      ),
    );
  }
}

/// The nickname (what everyone sees, written any way they like) and the
/// username (the unique @handle friends find them by), checked as they
/// type, with a preview of how others will see them; in the profile's
/// dialog and as a step of signing up. With [suggest], usernames made from
/// the nickname that are free are offered, a tap away.
class NamesForm extends ConsumerStatefulWidget {
  const NamesForm({
    super.key,
    this.nickname,
    this.username,
    this.title,
    this.subtitle,
    required this.submitLabel,
    required this.onSubmit,
    this.suggest = false,
    this.busy = false,
    this.chipSize = 70,
  });

  final String? nickname;
  final String? username;
  final String? title;
  final String? subtitle;
  final String submitLabel;
  final ValueChanged<ProfileNames> onSubmit;
  final bool suggest;

  /// Saving: the button waits.
  final bool busy;
  final double chipSize;

  @override
  ConsumerState<NamesForm> createState() => _NamesFormState();
}

class _NamesFormState extends ConsumerState<NamesForm> {
  late final _nick = TextEditingController(text: widget.nickname ?? '');
  late final _user = TextEditingController(text: widget.username ?? '');
  static final _userChars = RegExp(r'^[a-z0-9_]*$');
  Timer? _debounce;
  _Availability _availability = _Availability.unknown;

  String get _nickText => NicknameRules.tidy(_nick.text);
  String get _userText => _user.text.trim();

  bool get _nickOk => NicknameRules.problem(_nickText) == null;
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
    _nick.addListener(_nickChanged);
    _user.addListener(_userChanged);
  }

  /// Free usernames made from the nickname, offered while the username is
  /// still empty (or one of them).
  List<String> _ideas = const [];
  Timer? _ideasDebounce;

  void _nickChanged() {
    setState(() {});
    if (!widget.suggest) return;
    _ideasDebounce?.cancel();
    _ideasDebounce = Timer(const Duration(milliseconds: 500), _findIdeas);
  }

  Future<void> _findIdeas() async {
    final nick = _nickText;
    final base = nick
        .toLowerCase()
        .replaceAll(RegExp('[^a-z0-9]+'), '_')
        .replaceAll(RegExp(r'^_+|_+$'), '');
    if (base.length < 3) {
      if (mounted) setState(() => _ideas = const []);
      return;
    }
    final short = base.length > 17 ? base.substring(0, 17) : base;
    final seed = nick.runes.fold(0, (a, b) => (a * 31 + b) % 9973);
    final candidates = <String>{
      short,
      short.replaceAll('_', ''),
      '${short}_${seed % 100}',
      '$short${(seed * 7) % 1000}',
    }.where((c) => c.length >= 3 && c.length <= 20).toList();
    final me = ref.read(currentUserProvider)?.id ?? '';
    final repo = ref.read(profileRepositoryProvider);
    final free = <String>[];
    for (final c in candidates) {
      try {
        if (!await repo.isUsernameTaken(c, me)) free.add(c);
      } catch (_) {}
      if (free.length == 3) break;
    }
    if (!mounted || nick != _nickText) return;
    setState(() => _ideas = free);
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
    if (!_ok || widget.busy) return;
    widget.onSubmit(
      ProfileNames(
        nickname: _nickUnchanged ? null : _nickText,
        username: _userUnchanged ? null : _userText,
      ),
    );
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _ideasDebounce?.cancel();
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
        : (me == null ? strings.usernameYou : profileDisplayName(profile, me));
    final mood = _availability == _Availability.taken || !_nickOk
        ? BuddyMood.sad
        : _ok
        ? BuddyMood.excited
        : BuddyMood.thinking;

    return PopCard(
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
            Center(
              child: CoinBuddy(mood: mood, size: widget.chipSize),
            ),
            if (widget.title case final title?)
              Text(
                title,
                textAlign: TextAlign.center,
                style: AppTextStyles.display(fontSize: 24),
              ),
            if (widget.subtitle case final subtitle?)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  subtitle,
                  textAlign: TextAlign.center,
                  style: AppTextStyles.body(
                    fontSize: 14,
                    color: AppColors.textSecondary,
                  ),
                ),
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
            _FieldLabel(
              title: strings.usernameNickname,
              hint: strings.usernameWhatEveryoneSeesWriteIt,
            ),
            const SizedBox(height: 6),
            UtopiaTextField(
              controller: _nick,
              icon: Icons.badge_rounded,
              hint: strings.usernameNickname,
              textCapitalization: TextCapitalization.words,
              // Counted as a person counts them (an emoji family is one).
              inputFormatters: [
                LengthLimitingTextInputFormatter(NicknameRules.max),
              ],
              onSubmitted: (_) => _save(),
            ),
            if (!_nickOk)
              Padding(
                padding: const EdgeInsets.only(top: 6, left: 4),
                child: Text(
                  NicknameRules.problem(_nickText) ?? '',
                  style: AppTextStyles.body(
                    fontSize: 12,
                    color: AppColors.error,
                  ),
                ),
              ),
            const SizedBox(height: AppSpacing.md),
            _FieldLabel(
              title: strings.usernameUsername,
              hint: strings.usernameYoursAloneFriendsFindYou,
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
                _Check(ok: _userLengthOk, label: strings.username3To20Long),
                _Check(ok: _userCharsOk, label: strings.usernameLettersNumbers),
                if (_userUnchanged && widget.username != null)
                  _Check(ok: true, label: strings.usernameYours)
                else
                  _AvailabilityCheck(state: _availability),
              ],
            ),
            if (widget.suggest && _ideas.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.sm),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(
                    strings.usernameFree,
                    style: AppTextStyles.body(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  for (final idea in _ideas)
                    _Idea(
                      name: idea,
                      on: _userText == idea,
                      onTap: () {
                        HapticFeedback.selectionClick();
                        _user.text = idea;
                        _user.selection = TextSelection.collapsed(
                          offset: idea.length,
                        );
                      },
                    ),
                ],
              ),
            ],
            const SizedBox(height: AppSpacing.lg),
            PrimaryButton(
              label: widget.busy ? strings.usernameSaving : widget.submitLabel,
              color: AppColors.success,
              onPressed: _ok && !widget.busy ? _save : null,
            ),
          ],
        ),
      ),
    );
  }
}

/// A free username, offered: a tap fills it in.
class _Idea extends StatelessWidget {
  const _Idea({required this.name, required this.on, required this.onTap});

  final String name;
  final bool on;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = AppColors.readable(AppColors.success);
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: color.withValues(alpha: on ? 0.28 : 0.12),
          border: Border.all(color: color.withValues(alpha: on ? 0.9 : 0.45)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              on ? Icons.check_rounded : Icons.add_rounded,
              size: 14,
              color: color,
            ),
            const SizedBox(width: 3),
            Text(
              '@$name',
              style: AppTextStyles.body(
                fontSize: 12.5,
                fontWeight: FontWeight.w800,
                color: color,
              ),
            ),
          ],
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
      _Availability.unknown => _Check(
        ok: false,
        label: strings.usernameAvailable,
      ),
      _Availability.free => _Check(ok: true, label: strings.usernameAvailable),
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
              strings.usernameTaken,
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
              strings.usernameChecking,
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
