import 'dart:html' as html;
import 'dart:typed_data';

/// Web implementation for file downloads
void downloadFileImpl(List<int> bytes, String filename, String mimeType) {
  final blob = html.Blob([Uint8List.fromList(bytes)], mimeType);
  final url = html.Url.createObjectUrlFromBlob(blob);
  html.AnchorElement(href: url)
    ..setAttribute('download', filename)
    ..click();
  html.Url.revokeObjectUrl(url);
}
