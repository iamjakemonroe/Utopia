import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/generated_avatar.dart';
import '../../../../core/widgets/pop_card.dart';

/// A photo for an avatar, picked from the gallery (kept to 1024 px): its
/// bytes and file extension, or null if they backed out.
Future<(Uint8List, String)?> pickAvatarPhoto() async {
  final picked = await ImagePicker().pickImage(
    source: ImageSource.gallery,
    maxWidth: 1024,
    maxHeight: 1024,
    imageQuality: 85,
  );
  if (picked == null) return null;
  final dot = picked.name.lastIndexOf('.');
  return (
    await picked.readAsBytes(),
    dot == -1 ? 'jpg' : picked.name.substring(dot + 1),
  );
}

/// What [AvatarPickerSheet] returns: a null [kind] means "upload a photo".
class AvatarChoice {
  const AvatarChoice.photo() : kind = null, seed = null;
  const AvatarChoice.generated(String this.kind, int this.seed);

  final String? kind;
  final int? seed;
}

/// Avatars by kind, picked with icon tabs, plus "upload your own". With a
/// [title] (and [body]) it introduces itself, as a new player's first step;
/// with a [skipLabel] it can be passed over, and pops null.
class AvatarPickerSheet extends StatefulWidget {
  const AvatarPickerSheet({
    super.key,
    required this.currentKind,
    required this.currentSeed,
    this.title,
    this.body,
    this.skipLabel,
  });

  final String? currentKind;
  final int? currentSeed;
  final String? title;
  final String? body;
  final String? skipLabel;

  @override
  State<AvatarPickerSheet> createState() => _AvatarPickerSheetState();
}

class _AvatarPickerSheetState extends State<AvatarPickerSheet> {
  static const _kinds = [
    ('plant', Icons.eco_rounded, Color(0xFF3DDC97)),
    ('animal', Icons.pets_rounded, Color(0xFFFF8A3D)),
    ('human', Icons.face_rounded, Color(0xFF4DA3FF)),
  ];

  late String _kind = _kinds.any((k) => k.$1 == widget.currentKind)
      ? widget.currentKind!
      : _kinds.first.$1;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [AppColors.surfaceElevated, AppColors.background],
        ),
        border: sheetBorder(AppColors.goldBorder),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.sm,
            AppSpacing.lg,
            AppSpacing.lg,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 44,
                  height: 5,
                  decoration: BoxDecoration(
                    color: AppColors.textSecondary.withValues(alpha: 0.35),
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              if (widget.title != null) ...[
                Text(
                  widget.title!,
                  textAlign: TextAlign.center,
                  style: AppTextStyles.display(fontSize: 24),
                ),
                if (widget.body != null) ...[
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    widget.body!,
                    textAlign: TextAlign.center,
                    style: AppTextStyles.body(color: AppColors.textSecondary),
                  ),
                ],
                const SizedBox(height: AppSpacing.lg),
              ],
              Row(
                children: [
                  for (final (kind, icon, color) in _kinds) ...[
                    Expanded(
                      child: _KindTab(
                        icon: icon,
                        color: color,
                        selected: kind == _kind,
                        onTap: () => setState(() => _kind = kind),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                  ],
                  Expanded(
                    child: _KindTab(
                      icon: Icons.add_a_photo_rounded,
                      color: AppColors.coral,
                      selected: false,
                      onTap: () =>
                          Navigator.of(context).pop(const AvatarChoice.photo()),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 250),
                child: GridView.count(
                  key: ValueKey(_kind),
                  crossAxisCount: 4,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  mainAxisSpacing: AppSpacing.md,
                  crossAxisSpacing: AppSpacing.md,
                  children: [
                    for (var seed = 0; seed < kAvatarChoicesPerKind; seed++)
                      _AvatarOption(
                        kind: _kind,
                        seed: seed,
                        index: seed,
                        selected:
                            _kind == widget.currentKind &&
                            seed == widget.currentSeed,
                        onTap: () => Navigator.of(
                          context,
                        ).pop(AvatarChoice.generated(_kind, seed)),
                      ),
                  ],
                ),
              ),
              if (widget.skipLabel != null) ...[
                const SizedBox(height: AppSpacing.md),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(
                    widget.skipLabel!,
                    style: AppTextStyles.body(
                      fontWeight: FontWeight.w700,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _KindTab extends StatelessWidget {
  const _KindTab({
    required this.icon,
    required this.color,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedScale(
        scale: selected ? 1 : 0.9,
        duration: const Duration(milliseconds: 380),
        curve: Curves.elasticOut,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          height: 56,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: selected
                  ? [Color.lerp(color, Colors.white, 0.3)!, color]
                  : [AppColors.surfaceElevated, AppColors.surface],
            ),
            border: Border.all(
              color: selected ? Colors.white70 : color.withValues(alpha: 0.4),
              width: selected ? 2 : 1.2,
            ),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: color.withValues(alpha: 0.45),
                      blurRadius: 12,
                    ),
                  ]
                : null,
          ),
          child: Icon(icon, color: selected ? Colors.white : color, size: 28),
        ),
      ),
    );
  }
}

class _AvatarOption extends StatelessWidget {
  const _AvatarOption({
    required this.kind,
    required this.seed,
    required this.index,
    required this.selected,
    required this.onTap,
  });

  final String kind;
  final int seed;
  final int index;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 380 + index * 50),
      curve: Curves.elasticOut,
      builder: (context, v, child) => Transform.scale(scale: v, child: child),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: selected ? AppColors.goldBorderBright : Colors.transparent,
              width: 3,
            ),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: AppColors.goldBorderBright.withValues(alpha: 0.5),
                      blurRadius: 12,
                    ),
                  ]
                : null,
          ),
          child: LayoutBuilder(
            builder: (context, c) =>
                GeneratedAvatar(kind: kind, seed: seed, size: c.maxWidth),
          ),
        ),
      ),
    );
  }
}
