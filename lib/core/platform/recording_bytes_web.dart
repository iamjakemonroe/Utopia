import 'dart:js_interop';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

/// A finished recording's bytes: in a browser the recorder hands back a
/// blob: link, read and then let go.
Future<Uint8List> takeRecording(String path) async {
  final response = await web.window.fetch(path.toJS).toDart;
  final buffer = await response.arrayBuffer().toDart;
  web.URL.revokeObjectURL(path);
  return buffer.toDart.asUint8List();
}
