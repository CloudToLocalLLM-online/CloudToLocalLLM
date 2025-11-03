// Stub for non-web platforms

class WebWindow {
  const WebWindow();
  
  void open(String url, String target) {
    throw UnimplementedError('web.window.open is not available on this platform');
  }
}

final web = const WebWindow();

