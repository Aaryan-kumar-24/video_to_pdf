import 'dart:typed_data';

import 'file_helper_stub.dart'
    if (dart.library.html) 'file_helper_web.dart'
    if (dart.library.io) 'file_helper_io.dart';

void handlePreview(Uint8List bytes, String filename) {
  previewImpl(bytes, filename);
}

void handleDownload(Uint8List bytes, String filename) {
  downloadImpl(bytes, filename);
}
