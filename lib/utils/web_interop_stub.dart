// Stub implementation for non-web platforms
// This file is used when building for desktop/mobile platforms

/// Stub Window class
class Window {
  Location get location =>
      throw UnsupportedError('Not available on this platform');
  History get history =>
      throw UnsupportedError('Not available on this platform');
  Navigator get navigator =>
      throw UnsupportedError('Not available on this platform');
  Storage get localStorage =>
      throw UnsupportedError('Not available on this platform');
  Storage get sessionStorage =>
      throw UnsupportedError('Not available on this platform');
  void open(String url, String target) =>
      throw UnsupportedError('Not available on this platform');
}

/// Stub Document class
class Document {
  String get title => throw UnsupportedError('Not available on this platform');
}

/// Stub Location class
class Location {
  String get href => throw UnsupportedError('Not available on this platform');
  String get origin => throw UnsupportedError('Not available on this platform');
  String get pathname =>
      throw UnsupportedError('Not available on this platform');
}

/// Stub History class
class History {
  void replaceState(dynamic data, String title, String url) =>
      throw UnsupportedError('Not available on this platform');
}

/// Stub Navigator class
class Navigator {
  String get userAgent =>
      throw UnsupportedError('Not available on this platform');
}

/// Stub Storage class
class Storage {
  String? getItem(String key) =>
      throw UnsupportedError('Not available on this platform');
  void setItem(String key, String value) =>
      throw UnsupportedError('Not available on this platform');
  void removeItem(String key) =>
      throw UnsupportedError('Not available on this platform');
}

/// Stub getters
Window get window => throw UnsupportedError('window is only available on web');
Document get document =>
    throw UnsupportedError('document is only available on web');

/// Stub extensions
extension StorageExtension on Storage {
  String? operator [](String key) =>
      throw UnsupportedError('Not available on this platform');
  void operator []=(String key, String value) =>
      throw UnsupportedError('Not available on this platform');
  void remove(String key) =>
      throw UnsupportedError('Not available on this platform');
}

extension WindowExtension on Window {
  // Stub
}

extension LocationExtension on Location {
  // Stub
}

extension HistoryExtension on History {
  // Stub
}

extension NavigatorExtension on Navigator {
  // Stub
}

extension DocumentExtension on Document {
  // Stub
}
