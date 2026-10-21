// The house players' brain (lib/features/house/domain/house_brain.dart)
// and the online games' referee (board_referee.dart), for the house-move
// and board-move functions: tool/build_house_brain.sh compiles it to
// supabase/functions/house-move/brain.js, which sets
// globalThis.utopiaHouseTurn(json) -> json and
// globalThis.utopiaReferee(json) -> json.
import 'dart:convert';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import '../features/house/domain/board_referee.dart';
import '../features/house/domain/house_brain.dart';

void main() {
  globalContext.setProperty(
    'utopiaHouseTurn'.toJS,
    ((JSString input) {
      final ask = jsonDecode(input.toDart) as Map<String, dynamic>;
      return jsonEncode(
        houseTurn(
          game: ask['game'] as String,
          position: ask['position'] as String,
          rating: (ask['rating'] as num).toInt(),
          msLeft: (ask['ms_left'] as num).toInt(),
          ply: (ask['ply'] as num).toInt(),
          seed: (ask['seed'] as num).toInt(),
        ),
      ).toJS;
    }).toJS,
  );
  globalContext.setProperty(
    'utopiaReferee'.toJS,
    ((JSString input) {
      final ask = jsonDecode(input.toDart) as Map<String, dynamic>;
      return jsonEncode(
        refereeMove(
          game: ask['game'] as String,
          position: ask['position'] as String,
          from: ask['from'] as String,
          to: ask['to'] as String,
          promotion: ask['promotion'] as String?,
          notation: ask['notation'] as String?,
        ),
      ).toJS;
    }).toJS,
  );
}
