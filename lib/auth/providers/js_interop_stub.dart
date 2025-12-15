// Stub implementation for js_interop when not running on web
// This allows the code to compile on non-web platforms

class JSObject {
  const JSObject();
}

extension JSObjectExtension on JSObject {
  external T getProperty<T>(String property);
  external void setProperty<T>(String property, T value);
}

class JSArray<T> extends JSObject {
  JSArray();
}

class JSFunction extends JSObject {
  JSFunction(this.function);

  final Function function;
}

class JSAny extends JSObject {}

extension JSAnyExtension on JSAny {
  external T dartify<T>();
  external JSObject jsify();
}

external JSObject globalThis;

external T callMethod<T>(
  JSObject o,
  String method, [
  JSAny? arg1,
  JSAny? arg2,
  JSAny? arg3,
]);

external T getProperty<T>(JSObject o, String property);

external void setProperty<T>(JSObject o, String property, T value);
