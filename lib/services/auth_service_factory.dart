import 'package:flutter/foundation.dart' show kIsWeb;

import 'auth0_service.dart';
import 'auth0_web_service.dart' if (dart.library.io) 'auth0_desktop_service.dart';

Auth0Service createAuth0Service() {
  if (kIsWeb) {
    return Auth0WebService();
  } else {
    return Auth0DesktopService();
  }
}
