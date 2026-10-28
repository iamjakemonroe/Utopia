// The pool coin tables' referee (lib/features/pool/domain/
// pool_referee.dart), for the pool-table function: tool/
// build_pool_referee.sh compiles it to supabase/functions/pool-table/
// referee.js, which sets globalThis.utopiaPool(json) -> json.
import 'dart:convert';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import '../features/pool/domain/pool_referee.dart';

void main() {
  globalContext.setProperty(
    'utopiaPool'.toJS,
    ((JSString input) {
      final ask = jsonDecode(input.toDart) as Map<String, dynamic>;
      return jsonEncode(poolReferee(ask)).toJS;
    }).toJS,
  );
}
