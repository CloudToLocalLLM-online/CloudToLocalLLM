// Stub implementation for web-specific functionality on non-web platforms

class AnchorElement {
  AnchorElement({String? href});
  void setAttribute(String name, String value) {}
  void click() {}
  Map<String, String> get style => {};
}

class Document {
  Element? get body => null;
}

class Element {
  List<Element> get children => [];
}

class Navigator {
  String get userAgent => 'Unknown';
}

class Storage {
  void removeItem(String key) {}
  void setItem(String key, String value) {}
  String? getItem(String key) => null;
}

class Window {
  Navigator get navigator => Navigator();
  Storage get localStorage => Storage();
}

final document = Document();
final window = Window();
