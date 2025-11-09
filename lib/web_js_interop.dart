import 'dart:js_interop';

@JS()
@anonymous
extension type History._(JSObject _) implements JSObject {
  external void replaceState(JSAny? data, String title, String? url);
}

@JS('history')
external History get history;
