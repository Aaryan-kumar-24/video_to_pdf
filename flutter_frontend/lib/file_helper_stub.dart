import 'dart:typed_data';

void previewImpl(Uint8List bytes, String filename) {
  throw UnsupportedError('Cannot preview on this platform');
}

void downloadImpl(Uint8List bytes, String filename) {
  throw UnsupportedError('Cannot download on this platform');
}
