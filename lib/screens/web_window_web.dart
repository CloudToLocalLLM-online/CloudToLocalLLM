// Web implementation for web platforms
import 'package:web/web.dart' as web_platform;

final web = WebWindow();

class WebWindow {
  void open(String url, String target) {
    web_platform.window.open(url, target);
  }
}

