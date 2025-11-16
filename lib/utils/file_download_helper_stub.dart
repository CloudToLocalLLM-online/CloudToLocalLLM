/// Stub implementation for non-web platforms
void downloadFileImpl(List<int> bytes, String filename, String mimeType) {
  throw UnsupportedError('File download is not supported on this platform');
}
