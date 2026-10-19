import 'dart:io';
import 'dart:typed_data';

/// A finished recording's bytes; its file is deleted after.
Future<Uint8List> takeRecording(String path) async {
  final file = File(path);
  final bytes = await file.readAsBytes();
  file.delete().ignore();
  return bytes;
}
