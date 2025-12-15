// Conditional import wrapper for web/non-web implementations of PDF viewer utilities.
// The real implementations live in separate files so web-only APIs aren't
// referenced from non-web builds.

export 'file_io_web_stub.dart' if (dart.library.html) 'file_io_web_impl.dart';

// This file intentionally contains no symbols; it only selects the correct
// implementation at import time. Other code should import this file as:
// import 'package:shop_app/utils/file_io_web.dart';
