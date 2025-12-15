import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

// Decode HTTP response body to UTF-8 safely for terminal logging
String responseBodyPreview(http.Response resp, {int maxLen = 1000}) {
  try {
    final bytes = resp.bodyBytes;
    final s = utf8.decode(bytes, allowMalformed: true);
    if (s.length > maxLen)
      return s.substring(0, maxLen) + '... (truncated ${bytes.length} bytes)';
    return s;
  } catch (_) {
    try {
      return resp.body;
    } catch (_) {
      return '<binary ${resp.bodyBytes.length} bytes>';
    }
  }
}

void logInfo(String tag, String message) {
  if (kDebugMode) debugPrint('[$tag] $message');
}

void logResponse(String tag, http.Response resp) {
  if (!kDebugMode) return;
  debugPrint('[$tag] status=${resp.statusCode}');
  debugPrint('[$tag] body=${responseBodyPreview(resp)}');
}
