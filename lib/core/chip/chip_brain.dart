import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../supabase/supabase_providers.dart';

/// A picture Chip started drawing (or found) for the player.
@immutable
class ChipPicture {
  const ChipPicture({required this.status, required this.subject, this.id});

  /// 'drawing', 'ready', 'refused', 'limited' or 'error'.
  final String status;
  final String subject;
  final String? id;

  static ChipPicture? fromJson(Object? json) {
    if (json is! Map || json['status'] is! String) return null;
    return ChipPicture(
      status: json['status'] as String,
      subject: json['subject'] as String? ?? '',
      id: json['id'] as String?,
    );
  }

  Map<String, Object?> toJson() => {
    'status': status,
    'subject': subject,
    'id': id,
  };
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
  });

  final bool fromChip;
  final String text;

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

  /// For Chip's brain: who said what, when, and what Chip did about it.
  Map<String, String> toJson() => {
    'role': fromChip ? 'chip' : 'player',
    'text': text,
    if (at != null) 'at': chipTime(at!),
    if (picture?.id != null) 'picture_id': picture!.id!,
    'open': ?open,
    'sticker': ?sticker,
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
    );
  }
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
  Future<ChipLine> chat(
    String message, {
    List<ChipLine> history = const [],
    Map<String, String> context = const {},
  }) async {
    try {
      final res = await _client.functions.invoke(
        'chip',
        body: {
          'action': 'chat',
          'message': message,
          'history': [for (final l in history) l.toJson()],
          'context': context,
        },
      );
      final data = res.data;
      if (data is Map && data['reply'] is String) {
        return ChipLine(
          fromChip: true,
          text: data['reply'] as String,
          mood: data['mood'] as String?,
          open: data['open'] as String?,
          picture: ChipPicture.fromJson(data['picture']),
          sticker: data['sticker'] as String?,
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

  /// What Chip makes of the media described by [clues]. Null when the brain
  /// can't say (it's off, offline, or over today's allowance).
  Future<ChipVibe?> vibe(Map<String, Object?> clues) async {
    try {
      final res = await _client.functions.invoke(
        'chip',
        body: {'action': 'vibe', 'clues': clues},
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
