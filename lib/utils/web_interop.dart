// Web interop utilities using dart:js_interop (Flutter 3.27+)
// This file provides type-safe access to browser APIs using the new js_interop
import 'dart:js_interop';

/// Window object
@JS()
external Window get window;

/// Document object
@JS()
external Document get document;

/// Window interface
extension type Window(JSObject _) implements JSObject {
  external Location get location;
  external History get history;
  external Navigator get navigator;
  external Storage get localStorage;
  external Storage get sessionStorage;
  external void open(String url, String target);
}

/// Document interface
extension type Document(JSObject _) implements JSObject {
  external String get title;
}

/// Location interface
extension type Location(JSObject _) implements JSObject {
  external String get href;
  external String get origin;
  external String get pathname;
}

/// History interface
extension type History(JSObject _) implements JSObject {
  external void replaceState(JSAny? data, String title, String url);
}

/// Navigator interface
extension type Navigator(JSObject _) implements JSObject {
  external String get userAgent;
}

/// Storage interface (localStorage/sessionStorage)
extension type Storage(JSObject _) implements JSObject {
  external String? getItem(String key);
  external void setItem(String key, String value);
  external void removeItem(String key);
}

/// Storage convenience extensions
extension StorageExtension on Storage {
  String? operator [](String key) => getItem(key);
  void operator []=(String key, String value) => setItem(key, value);
  void remove(String key) => removeItem(key);
}

/// Legacy compatibility - these extensions maintain backward compatibility
extension WindowExtension on Window {
  // Already has location, history, navigator, localStorage, sessionStorage
}

extension LocationExtension on Location {
  // Already has href, origin, pathname
}

extension HistoryExtension on History {
  // Already has replaceState
}

extension NavigatorExtension on Navigator {
  // Already has userAgent
}

extension DocumentExtension on Document {
  // Already has title
}
