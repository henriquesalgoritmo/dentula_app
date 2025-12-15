import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import 'package:flutter/widgets.dart';

Future<bool> existsFile(String filename) async {
  final dir = await getApplicationDocumentsDirectory();
  final f = File(p.join(dir.path, filename));
  return f.exists();
}

Future<String> saveFileBytes(String filename, List<int> bytes) async {
  final dir = await getApplicationDocumentsDirectory();
  final path = p.join(dir.path, filename);
  final f = File(path);
  await f.writeAsBytes(bytes, flush: true);
  return path;
}

String localFilePath(String filename) {
  // caller should ensure filename is correct; this just returns expected path
  // Use getApplicationDocumentsDirectory at runtime if needed
  return filename; // placeholder (not used directly)
}

/// Returns the absolute local path for [filename] inside the app documents directory.
Future<String> getLocalFilePath(String filename) async {
  final dir = await getApplicationDocumentsDirectory();
  return p.join(dir.path, filename);
}

Widget buildPdfViewer({String? localPath, required String url}) {
  if (localPath != null && File(localPath).existsSync()) {
    return SfPdfViewer.file(File(localPath));
  }
  return SfPdfViewer.network(url);
}
