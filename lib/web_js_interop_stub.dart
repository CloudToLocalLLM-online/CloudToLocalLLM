// This file is used as a stub for non-web platforms
// to avoid compilation errors.

// ignore_for_file: unused_element

class History {
  void replaceState(dynamic data, String title, String? url) {
    // No-op
  }
}

History get history => _UnsupportedHistory();

class _UnsupportedHistory implements History {
  @override
  void replaceState(dynamic data, String title, String? url) {
    throw UnimplementedError('History API is only available on the web.');
  }
}
