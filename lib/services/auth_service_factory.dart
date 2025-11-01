import 'package:flutter/foundation.dart' show kIsWeb;
import 'auth0_service.dart';
import 'auth0_web_service.dart' if (dart.library.io) 'auth0_web_service_stub.dart';
import 'auth0_desktop_service.dart'
    if (dart.library.html) 'auth0_desktop_service_stub.dart';

Auth0Service createAuth0Service() {
  if (kIsWeb) {
    return Auth0WebService();
  } else {
    return Auth0DesktopService();
  }
}
