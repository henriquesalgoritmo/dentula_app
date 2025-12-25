import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, TargetPlatform, kIsWeb;

/// Returns the base API URL for the backend, adjusted per platform.
///
/// - Android emulator: `10.0.2.2` is used to reach host `localhost`.
/// - iOS simulator / desktop: `localhost` works.
/// - Web: uses `http://localhost:8000/api/` by default.
String getApiBaseUrl() {
  // You can change the port/path here if your backend uses a different one.
  //const apiPath = 'https://api.myvisto.dentula.ao/api/';
  const apiPath = 'http://127.0.0.1:8000/api/';

  if (kIsWeb) return apiPath;

  switch (defaultTargetPlatform) {
    case TargetPlatform.android:
      // Android emulator routes host localhost to 10.0.2.2
      //return 'https://api.myvisto.dentula.ao/api/';
      return 'http://127.0.0.1:8000/api/';
    case TargetPlatform.iOS:
    case TargetPlatform.macOS:
    case TargetPlatform.windows:
    case TargetPlatform.linux:
    default:
      return apiPath;
  }
}
