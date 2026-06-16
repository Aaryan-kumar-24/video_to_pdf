void previewImpl(String url, String filename) {
  throw UnsupportedError('Cannot preview on this platform');
}

void downloadImpl(String url, String filename) {
  throw UnsupportedError('Cannot download on this platform');
}

void shareImpl(String url, String filename) {
  throw UnsupportedError('Cannot share on this platform');
}

bool canShareFilesImpl() {
  return false;
}
