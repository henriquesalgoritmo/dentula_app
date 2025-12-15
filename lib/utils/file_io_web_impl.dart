// Web implementation: use an iframe rendered by flutter_html to avoid
// platform view registration issues.
// This file is only imported on web (dart.library.html).
import 'package:flutter/material.dart';
import 'package:flutter_html/flutter_html.dart';

Future<bool> existsFile(String filename) async => false;
Future<String?> saveFileBytes(String filename, List<int> bytes) async => null;
String? localFilePath(String filename) => null;
Future<String?> getLocalFilePath(String filename) async => null;

Widget buildPdfViewer({String? localPath, required String url}) {
  // Render an iframe using flutter_html. If the browser blocks embedding,
  // the iframe will show the browser's own error; callers already provide
  // an 'open externally' button in the dialog chrome.
  return SizedBox(
    width: double.infinity,
    height: double.infinity,
    child: Html(
      data: '<iframe src="$url" width="100%" height="100%"></iframe>',
    ),
  );
}
