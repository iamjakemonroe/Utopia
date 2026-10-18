import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/audio/game_audio.dart';
import '../../../core/supabase/supabase_providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/utopia_themes.dart';
import '../../../core/widgets/app_background.dart';
import '../../../core/widgets/coin_buddy.dart';
import '../../../core/widgets/pop_card.dart';
import '../../../core/widgets/primary_button.dart';
import '../../../core/layout/responsive.dart';

/// This build, as "1.0.0+14", so a report says exactly which one it's about.
final _buildProvider = FutureProvider<String>((ref) async {
  final info = await PackageInfo.fromPlatform();
  return '${info.version}+${info.buildNumber}';
});

/// A report this player sent, and what came of it.
class SentReport {
  const SentReport({
    required this.category,
    required this.description,
    required this.status,
    required this.createdAt,
    this.resolution,
  });

  final String category;
  final String description;

  /// new, triaged (on the list), fixed, or wontfix.
  final String status;
  final DateTime createdAt;

  /// The team's note back: what was done about it.
  final String? resolution;

  bool get idea => category == 'idea';

  static SentReport fromRow(Map<String, dynamic> row) => SentReport(
    category: row['category'] as String? ?? 'bug',
    description: row['description'] as String? ?? '',
    status: row['status'] as String? ?? 'new',
    createdAt:
        DateTime.tryParse(row['created_at'] as String? ?? '') ?? DateTime.now(),
    resolution: row['resolution'] as String?,
  );
}

/// The player's own reports, newest first (the server only ever shows a
/// player theirs).
final myReportsProvider = FutureProvider.autoDispose<List<SentReport>>((
  ref,
) async {
  final rows = await ref
      .read(supabaseClientProvider)
      .from('bug_reports')
      .select('category, description, status, resolution, created_at')
      .order('created_at', ascending: false)
      .limit(20);
  return [for (final r in rows) SentReport.fromRow(r)];
});

/// "Report a bug" or, with [idea], "Suggest a feature": what it's about,
/// what happened (or what they'd love to see), a screenshot if they like,
/// and how to reach them. It goes with the build, the phone's system, the
/// screen they came from ([from]) and their world, so it can be acted on.
/// Underneath, their earlier reports and what came of each.
class ReportBugScreen extends ConsumerStatefulWidget {
  const ReportBugScreen({super.key, this.idea = false, this.from});

  final bool idea;

  /// The screen they were on when they decided to report.
  final String? from;

  @override
  ConsumerState<ReportBugScreen> createState() => _ReportBugScreenState();
}

class _ReportBugScreenState extends ConsumerState<ReportBugScreen> {
  final _description = TextEditingController();
  final _contact = TextEditingController();
  late String _category = widget.idea ? 'idea' : 'bug';
  Uint8List? _shot;
  String _shotType = 'jpg';
  bool _sending = false;
  bool _sent = false;
  String? _error;

  static const _categories = [
    ('bug', Icons.bug_report_rounded, 'Something broke'),
    ('gameplay', Icons.casino_rounded, 'Gameplay'),
    ('payments', Icons.credit_card_rounded, 'Purchases'),
    ('account', Icons.person_rounded, 'Account'),
  ];

  bool get _idea => widget.idea;

  @override
  void dispose() {
    _description.dispose();
    _contact.dispose();
    super.dispose();
  }

  Future<void> _pickShot() async {
    final picked = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 1600,
      maxHeight: 1600,
      imageQuality: 80,
    );
    if (picked == null || !mounted) return;
    final bytes = await picked.readAsBytes();
    if (!mounted) return;
    setState(() {
      _shot = bytes;
      _shotType = picked.name.toLowerCase().endsWith('.png') ? 'png' : 'jpg';
    });
  }

  Future<void> _send() async {
    final text = _description.text.trim();
    if (text.length < 5) {
      setState(() => _error = 'Tell us a little more (at least a few words).');
      return;
    }
    setState(() {
      _sending = true;
      _error = null;
    });
    final client = ref.read(supabaseClientProvider);
    try {
      String? shotPath;
      final shot = _shot;
      final me = client.auth.currentUser?.id;
      if (shot != null && me != null) {
        // Into the player's own folder; only the team can look at it.
        shotPath = '$me/${DateTime.now().millisecondsSinceEpoch}.$_shotType';
        await client.storage
            .from('bug-screenshots')
            .uploadBinary(
              shotPath,
              shot,
              fileOptions: FileOptions(
                contentType: _shotType == 'png' ? 'image/png' : 'image/jpeg',
              ),
            );
      }
      final build = await ref.read(_buildProvider.future).catchError((_) => '');
      await client.rpc(
        'submit_bug_report',
        params: {
          'p_description': text,
          'p_category': _category,
          'p_app_version': build.isEmpty ? null : build,
          'p_platform': kIsWeb
              ? 'web'
              : '${Platform.operatingSystem} ${Platform.operatingSystemVersion}',
          'p_contact': _contact.text.trim(),
          'p_screen': widget.from,
          'p_world': UtopiaThemes.active.name,
          'p_screenshot_path': shotPath,
        },
      );
      ref.read(gameAudioProvider).play(Sfx.reaction);
      ref.invalidate(myReportsProvider);
      if (mounted) setState(() => _sent = true);
    } catch (e) {
      if (mounted) {
        setState(() {
          _sending = false;
          _error = e.toString().contains('too many')
              ? "You've sent a lot of reports. Try again in a little while."
              : "Couldn't send that. Check your connection and try again.";
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_idea ? 'Suggest a feature' : 'Report a bug')),
      body: AppBackground(
        child: SafeArea(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 500),
            switchInCurve: Curves.elasticOut,
            transitionBuilder: (child, a) =>
                ScaleTransition(scale: a, child: child),
            child: _sent ? _thanks(context) : _form(),
          ),
        ),
      ),
    );
  }

  Widget _thanks(BuildContext context) {
    return Center(
      key: const ValueKey('thanks'),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CoinBuddy(mood: BuddyMood.happy, size: 130),
            const SizedBox(height: AppSpacing.md),
            Text('Thank you!', style: AppTextStyles.display(fontSize: 28)),
            const SizedBox(height: AppSpacing.xs),
            Text(
              _idea
                  ? 'We read every idea. Check back under Your reports to see what happens to it.'
                  : 'We read every report. Check back under Your reports to see when it’s fixed.',
              textAlign: TextAlign.center,
              style: AppTextStyles.body(color: AppColors.textSecondary),
            ),
            const SizedBox(height: AppSpacing.lg),
            PrimaryButton(
              label: 'Done',
              onPressed: () => Navigator.of(context).maybePop(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _label(String text) => Padding(
    padding: const EdgeInsets.only(bottom: AppSpacing.sm),
    child: Text(text, style: AppTextStyles.body(fontWeight: FontWeight.w800)),
  );

  Widget _form() {
    final shot = _shot;
    return ListView(
      key: const ValueKey('form'),
      padding: context.readablePadding(
        min: AppSpacing.lg,
        top: AppSpacing.lg,
        bottom: AppSpacing.lg,
      ),
      children: [
        Row(
          children: [
            CoinBuddy(
              mood: _idea ? BuddyMood.excited : BuddyMood.thinking,
              size: 70,
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Text(
                _idea
                    ? 'Got an idea for Utopia? Tell Chip what you’d love to see.'
                    : 'Spotted something off? Tell Chip what happened and we’ll fix it.',
                style: AppTextStyles.body(color: AppColors.textSecondary),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.lg),
        PopCard(
          borderRadius: 24,
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (!_idea) ...[
                _label('What’s it about?'),
                Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.sm,
                  children: [
                    for (final (id, icon, label) in _categories)
                      ChoiceChip(
                        avatar: Icon(icon, size: 18),
                        label: Text(label),
                        selected: _category == id,
                        onSelected: (_) => setState(() => _category = id),
                        selectedColor: AppColors.accent,
                        backgroundColor: AppColors.surface,
                        labelStyle: TextStyle(
                          color: _category == id
                              ? AppColors.onAccent
                              : AppColors.textSecondary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
              ],
              _label(_idea ? 'Your idea' : 'What happened?'),
              TextField(
                controller: _description,
                maxLines: 6,
                maxLength: 2000,
                decoration: InputDecoration(
                  hintText: _idea
                      ? 'What would make Utopia better for you?'
                      : 'What were you doing, and what went wrong?',
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              _label('Screenshot (optional)'),
              if (shot == null)
                OutlinedButton.icon(
                  onPressed: _sending ? null : _pickShot,
                  icon: const Icon(Icons.add_photo_alternate_rounded),
                  label: const Text('Add a screenshot'),
                )
              else
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(14),
                      child: Image.memory(shot, height: 160, fit: BoxFit.cover),
                    ),
                    Positioned(
                      top: -10,
                      right: -10,
                      child: IconButton.filled(
                        tooltip: 'Remove',
                        onPressed: _sending
                            ? null
                            : () => setState(() => _shot = null),
                        icon: const Icon(Icons.close_rounded, size: 18),
                      ),
                    ),
                  ],
                ),
              const SizedBox(height: AppSpacing.md),
              _label('Email (optional)'),
              TextField(
                controller: _contact,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                  hintText: 'So we can follow up',
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: AppSpacing.sm),
                Text(
                  _error!,
                  style: AppTextStyles.body(
                    color: AppColors.error,
                    fontSize: 13,
                  ),
                ),
              ],
              const SizedBox(height: AppSpacing.lg),
              PrimaryButton(
                label: _idea ? 'Send idea' : 'Send report',
                isLoading: _sending,
                onPressed: _send,
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'Sent with your username, the app version, your phone’s system and the screen you were on.',
                style: AppTextStyles.body(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
        const _YourReports(),
      ],
    );
  }
}

/// The player's earlier reports and what came of each.
class _YourReports extends ConsumerWidget {
  const _YourReports();

  static (String, Color) _status(SentReport r) => switch (r.status) {
    'triaged' => ('On our list', AppColors.coinGold),
    'fixed' => (r.idea ? 'Added' : 'Fixed', AppColors.success),
    'wontfix' => ('Not planned', AppColors.textSecondary),
    _ => ('Sent', AppColors.sky),
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reports = ref.watch(myReportsProvider).valueOrNull ?? const [];
    if (reports.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Your reports', style: AppTextStyles.display(fontSize: 18)),
          const SizedBox(height: AppSpacing.sm),
          for (final r in reports)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: PopCard(
                borderRadius: 18,
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          r.idea
                              ? Icons.lightbulb_rounded
                              : Icons.bug_report_rounded,
                          size: 16,
                          color: AppColors.textSecondary,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            MaterialLocalizations.of(
                              context,
                            ).formatMediumDate(r.createdAt.toLocal()),
                            style: AppTextStyles.body(
                              fontSize: 12,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ),
                        Builder(
                          builder: (context) {
                            final (label, color) = _status(r);
                            return Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(12),
                                color: color.withValues(alpha: 0.18),
                              ),
                              child: Text(
                                label,
                                style: AppTextStyles.body(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w800,
                                  color: color,
                                ),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      r.description,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.body(fontSize: 14),
                    ),
                    if (r.resolution != null && r.resolution!.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        r.resolution!,
                        style: AppTextStyles.body(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: AppColors.accent,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
