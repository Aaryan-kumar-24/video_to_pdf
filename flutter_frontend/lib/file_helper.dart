import 'file_helper_stub.dart'
    if (dart.library.html) 'file_helper_web.dart'
    if (dart.library.io) 'file_helper_io.dart';

void handlePreview(String url, String filename) {
  previewImpl(url, filename);
}

void handleDownload(String url, String filename) {
  downloadImpl(url, filename);
}

void handleShare(String url, String filename) {
  shareImpl(url, filename);
}
