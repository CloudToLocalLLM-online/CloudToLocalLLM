import 'file_download_helper_stub.dart'
    if (dart.library.html) 'file_download_helper_web.dart';

/// Download a file with the given bytes, filename, and MIME type
void downloadFile(List<int> bytes, String filename, String mimeType) {
  downloadFileImpl(bytes, filename, mimeType);
}
