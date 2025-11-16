import 'package:web/web.dart';
import 'dart:typed_data';
import 'dart:js_interop';

/// Web implementation for file downloads
void downloadFileImpl(List<int> bytes, String filename, String mimeType) {
  final uint8List = Uint8List.fromList(bytes);
  final blob = Blob(
    [uint8List.toJS].toJS,
    BlobPropertyBag(type: mimeType),
  );
  final url = URL.createObjectURL(blob);
  final anchor = document.createElement('a') as HTMLAnchorElement;
  anchor.href = url;
  anchor.setAttribute('download', filename);
  anchor.click();
  URL.revokeObjectURL(url);
}
