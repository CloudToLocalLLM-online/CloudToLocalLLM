// Minimal web stubs for non-web platforms so conditional import compiles.
// These are no-ops used only to satisfy references when not on web.

class _LocationStub {
  String get hostname => '';
  String get protocol => 'https:';
  String get port => '';
}

class _StorageStub {
  final Map<String, String> _store = {};
  void setItem(String key, String value) => _store[key] = value;
  String? getItem(String key) => _store[key];
  void removeItem(String key) => _store.remove(key);
}

class _WindowStub {
  final _LocationStub location = _LocationStub();
  final _StorageStub localStorage = _StorageStub();
}

final window = _WindowStub();

class _DocumentStub {
  dynamic querySelector(String selector) => null;
}

final document = _DocumentStub();

