// Web implementation for web platforms
import '../utils/web_interop_stub.dart'
    if (dart.library.html) '../utils/web_interop.dart';

final web = WebWindow();

class WebWindow {
  void open(String url, String target) {
    window.open(url, target);
  }
}
