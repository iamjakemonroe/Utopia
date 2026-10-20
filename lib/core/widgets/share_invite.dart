import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import 'utopia_toast.dart';
import '../../l10n/strings.dart';

/// Shares a game invite: the phone's share sheet. In a browser without one
/// (most computers), the invite is copied instead and the player told so,
/// rather than an email being opened.
Future<void> shareInvite(
  BuildContext context, {
  required String text,
  required String subject,
  Rect? origin,
}) async {
  final params = ShareParams(
    text: text,
    subject: subject,
    sharePositionOrigin: origin,
    mailToFallbackEnabled: !kIsWeb,
  );
  if (!kIsWeb) {
    await SharePlus.instance.share(params);
    return;
  }
  try {
    await SharePlus.instance.share(params);
  } catch (_) {
    await Clipboard.setData(ClipboardData(text: text));
    if (!context.mounted) return;
    showUtopiaToast(
      context,
      strings.shareInviteInviteCopiedPasteItTo,
      icon: Icons.content_copy_rounded,
      kind: ToastKind.success,
    );
  }
}
