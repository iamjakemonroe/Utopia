import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../platform/device_key.dart';

import '../supabase/supabase_providers.dart';

/// A picture Chip started drawing (or found) for the player.
@immutable
class ChipPicture {
  const ChipPicture({
    required this.status,
    required this.subject,
    this.id,
    this.fromPhoto = false,
  });

  /// 'drawing', 'ready', 'refused', 'limited' or 'error'.
  final String status;
  final String subject;
  final String? id;

  /// Drawn from a photo the player sent (theirs alone).
  final bool fromPhoto;

  static ChipPicture? fromJson(Object? json) {
    if (json is! Map || json['status'] is! String) return null;
    return ChipPicture(
      status: json['status'] as String,
      subject: json['subject'] as String? ?? '',
      id: json['id'] as String?,
      fromPhoto: json['photo'] == true,
    );
  }

  Map<String, Object?> toJson() => {
    'status': status,
    'subject': subject,
    'id': id,
    if (fromPhoto) 'photo': true,
  };
}

/// Chip offering a real portrait (a photo-quality drawing that looks just
/// like the person). How it works for the player is [state]: 'free' (their
/// one free portrait), 'maestro' (a Chip Maestro member, [left] this month)
/// or 'locked' (it takes Chip Maestro).
@immutable
class ChipPortraitOffer {
  const ChipPortraitOffer({
    required this.subject,
    this.fromPhoto = false,
    this.state = 'locked',
    this.left = 0,
  });

  final String subject;

  /// From the photo they sent (not a name).
  final bool fromPhoto;
  final String state;
  final int left;

  static ChipPortraitOffer? fromJson(Object? json) {
    if (json is! Map || json['subject'] is! String) return null;
    return ChipPortraitOffer(
      subject: json['subject'] as String,
      fromPhoto: json['photo'] == true,
      state: json['state'] as String? ?? 'locked',
      left: (json['left'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, Object?> toJson() => {
    'subject': subject,
    'photo': fromPhoto,
    'state': state,
    'left': left,
  };
}

/// What happened when the player took a portrait offer: 'drawing' or
/// 'ready' (with the picture's [id]), 'maestro' (it takes Chip Maestro),
/// 'limited' ([month]: this month's are used up), 'off' or 'error'.
@immutable
class ChipPortraitAsk {
  const ChipPortraitAsk(
    this.status, {
    this.id,
    this.left = 0,
    this.month = false,
  });

  final String status;
  final String? id;

  /// Real portraits left this month (members).
  final int left;
  final bool month;
}

/// One line of a chat with Chip.
@immutable
class ChipLine {
  const ChipLine({
    required this.fromChip,
    required this.text,
    this.mood,
    this.open,
    this.picture,
    this.sticker,
    this.at,
    this.photo,
    this.paint,
    this.portrait,
    this.limit,
    this.price,
  });

  final bool fromChip;
  final String text;

  /// Chip out of today's chats, and what the player can do: 'coins' (keep
  /// chatting, [price] coins a message), 'coins_short' (not enough coins)
  /// or 'guest' (save the account to chat more).
  final String? limit;
  final int? price;

  /// A photo the player sent with it: where it's kept on the phone.
  final String? photo;

  /// Chip offering to color the latest picture, in this style.
  final String? paint;

  /// Chip offering a real portrait.
  final ChipPortraitOffer? portrait;

  /// The face Chip made saying it ('happy', 'thinking', ...).
  final String? mood;

  /// A place Chip offered a button to ('store', 'sketchbook', ...).
  final String? open;

  /// A picture Chip is drawing for the player.
  final ChipPicture? picture;

  /// A sticker Chip sent with it ('chip:excited', 'icon:party', ...).
  final String? sticker;

  /// When it was said.
  final DateTime? at;

  /// The same line with its portrait offer taken.
  ChipLine withoutPortrait() => ChipLine(
    fromChip: fromChip,
    text: text,
    mood: mood,
    open: open,
    picture: picture,
    sticker: sticker,
    at: at,
    photo: photo,
    paint: paint,
  );

  /// For Chip's brain: who said what, when, and what Chip did about it.
  Map<String, String> toJson() => {
    'role': fromChip ? 'chip' : 'player',
    'text': text,
    if (at != null) 'at': chipTime(at!),
    if (picture?.id != null) 'picture_id': picture!.id!,
    'open': ?open,
    'sticker': ?sticker,
    if (photo != null) 'photo': 'yes',
  };

  /// Everything, for keeping the chat on the phone.
  Map<String, Object?> toStore() => {
    'chip': fromChip,
    'text': text,
    'mood': mood,
    'open': open,
    'picture': picture?.toJson(),
    'sticker': sticker,
    'at': at?.toIso8601String(),
    'photo': photo,
    'paint': paint,
    'portrait': portrait?.toJson(),
  };

  static ChipLine? fromStore(Object? json) {
    if (json is! Map || json['text'] is! String) return null;
    return ChipLine(
      fromChip: json['chip'] == true,
      text: json['text'] as String,
      mood: json['mood'] as String?,
      open: json['open'] as String?,
      picture: ChipPicture.fromJson(json['picture']),
      sticker: json['sticker'] as String?,
      at: DateTime.tryParse(json['at'] as String? ?? ''),
      photo: json['photo'] as String?,
      paint: json['paint'] as String?,
      portrait: ChipPortraitOffer.fromJson(json['portrait']),
    );
  }
}

/// Chip's colors for a coloring page.
@immutable
class ChipPaint {
  const ChipPaint(this.status, {this.fills = const {}, this.note = ''});

  /// 'ready', 'limited' (enough coloring for today), 'refused', 'off' or
  /// 'error'.
  final String status;

  /// Shape number to ARGB color.
  final Map<int, int> fills;

  /// What Chip says about his colors.
  final String note;
}

const _days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
const _months = [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];

/// "Tue 14 Oct, 2:10 pm" on the phone's clock.
String chipTime(DateTime when) {
  final t = when.toLocal();
  final hour = t.hour % 12 == 0 ? 12 : t.hour % 12;
  final minute = t.minute.toString().padLeft(2, '0');
  return '${_days[t.weekday - 1]} ${t.day} ${_months[t.month - 1]}, '
      '$hour:$minute ${t.hour < 12 ? 'am' : 'pm'}';
}

/// What Chip's brain made of something playing.
@immutable
class ChipVibe {
  const ChipVibe({
    required this.kind,
    required this.vibe,
    required this.headline,
    required this.detail,
  });

  /// 'music', 'video', 'podcast', 'sermon', 'audiobook', 'radio', 'unknown'.
  final String kind;

  /// 'hype', 'chill', 'study', 'funny'...
  final String vibe;
  final String headline;
  final String detail;

  static ChipVibe? fromJson(Object? data) {
    if (data is! Map) return null;
    final headline = data['headline'];
    if (headline is! String || headline.isEmpty) return null;
    return ChipVibe(
      kind: data['kind'] as String? ?? 'unknown',
      vibe: data['vibe'] as String? ?? 'neutral',
      headline: headline,
      detail: data['detail'] as String? ?? '',
    );
  }
}

/// Talks to Chip's brain (the `chip` Edge Function, which asks Claude).
class ChipBrain {
  ChipBrain(this._client);

  final SupabaseClient _client;

  /// Chip's answer to [message], with the face he makes. Never throws:
  /// when the brain can't be reached he says so in his own words.
  ///
  /// [photo] goes with it (a JPEG or PNG): one sent just now when
  /// [photoIsNew], otherwise one sent earlier that Chip hasn't drawn yet.
  Future<ChipLine> chat(
    String message, {
    List<ChipLine> history = const [],
    Map<String, String> context = const {},
    Uint8List? photo,
    bool photoIsNew = true,
    bool pay = false,
  }) async {
    try {
      final res = await _client.functions
          .invoke(
            'chip',
            body: {
              'action': 'chat',
              'device': DeviceKey.value,
              if (pay) 'pay': true,
              'message': message,
              'history': [for (final l in history) l.toJson()],
              'context': context,
              if (photo != null) ...{
                'photo': base64Encode(photo),
                'photo_new': photoIsNew,
              },
            },
          )
          .timeout(const Duration(seconds: 100));
      final data = res.data;
      if (data is Map && data['reply'] is String) {
        return ChipLine(
          fromChip: true,
          text: data['reply'] as String,
          mood: data['mood'] as String?,
          open: data['open'] as String?,
          picture: ChipPicture.fromJson(data['picture']),
          sticker: data['sticker'] as String?,
          paint: data['paint'] as String?,
          portrait: ChipPortraitOffer.fromJson(data['portrait']),
          limit: data['limited'] is String ? data['limited'] as String : null,
          price: data['price'] is int ? data['price'] as int : null,
          at: DateTime.now(),
        );
      }
    } on FunctionException catch (e) {
      if (e.status == 503) {
        return const ChipLine(
          fromChip: true,
          text: "My brain is still waking up. Try me again a bit later!",
          mood: 'thinking',
        );
      }
      if (e.status == 429) {
        return const ChipLine(
          fromChip: true,
          text: 'I need a little breather. Ask me again in a moment.',
          mood: 'sad',
        );
      }
    } catch (_) {}
    return const ChipLine(
      fromChip: true,
      text:
          "I couldn't hear you just now. Check your connection and try again?",
      mood: 'sad',
    );
  }

  /// Has a real portrait of [subject] made (from [photo] when given): one
  /// of their Chip Maestro portraits, or their free one.
  Future<ChipPortraitAsk> portrait(String subject, {Uint8List? photo}) async {
    try {
      final res = await _client.functions
          .invoke(
            'chip',
            body: {
              'action': 'portrait',
              'device': DeviceKey.value,
              'subject': subject,
              if (photo != null) 'photo': base64Encode(photo),
            },
          )
          .timeout(const Duration(seconds: 60));
      final data = res.data;
      if (data is Map && data['status'] is String) {
        return ChipPortraitAsk(
          data['status'] as String,
          id: data['id'] as String?,
          left: (data['left'] as num?)?.toInt() ?? 0,
          month: data['month'] == true,
        );
      }
    } on FunctionException catch (e) {
      if (e.status == 503) return const ChipPortraitAsk('off');
    } catch (_) {}
    return const ChipPortraitAsk('error');
  }

  /// Chip's colors for a page in [style]: [image] is the page (a PNG) with
  /// every shape numbered, and [shapes] says where each one is
  /// ({i: number, x, y: its label, w, h: its size, a: its area}).
  Future<ChipPaint> paint({
    required String style,
    required Uint8List image,
    required List<Map<String, int>> shapes,
    String? title,
  }) async {
    try {
      final res = await _client.functions
          .invoke(
            'chip',
            body: {
              'action': 'paint',
              'device': DeviceKey.value,
              'style': style,
              'title': ?title,
              'image': base64Encode(image),
              'regions': shapes,
            },
          )
          .timeout(const Duration(seconds: 150));
      final data = res.data;
      if (data is! Map || data['status'] is! String) {
        return const ChipPaint('error');
      }
      final status = data['status'] as String;
      if (status != 'ready') return ChipPaint(status);
      final fills = <int, int>{};
      for (final f in (data['fills'] as List? ?? const [])) {
        if (f is! Map || f['r'] is! num || f['c'] is! String) continue;
        final hex = int.tryParse(
          (f['c'] as String).replaceFirst('#', ''),
          radix: 16,
        );
        if (hex != null) fills[(f['r'] as num).toInt()] = 0xFF000000 | hex;
      }
      return fills.isEmpty
          ? const ChipPaint('error')
          : ChipPaint(
              'ready',
              fills: fills,
              note: data['note'] as String? ?? '',
            );
    } on FunctionException catch (e) {
      if (e.status == 503) return const ChipPaint('off');
    } catch (_) {}
    return const ChipPaint('error');
  }

  /// What Chip makes of the media described by [clues]. Null when the brain
  /// can't say (it's off, offline, or over today's allowance).
  Future<ChipVibe?> vibe(Map<String, Object?> clues) async {
    try {
      final res = await _client.functions.invoke(
        'chip',
        body: {'action': 'vibe', 'device': DeviceKey.value, 'clues': clues},
      );
      return ChipVibe.fromJson(res.data);
    } catch (_) {
      return null;
    }
  }
}

final chipBrainProvider = Provider<ChipBrain>(
  (ref) => ChipBrain(ref.watch(supabaseClientProvider)),
);
