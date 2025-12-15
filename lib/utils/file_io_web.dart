import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import 'package:flutter/widgets.dart';

Future<bool> existsFile(String filename) async => false;
Future<String?> saveFileBytes(String filename, List<int> bytes) async => null;
String? localFilePath(String filename) => null;
Future<String?> getLocalFilePath(String filename) async => null;

Widget buildPdfViewer({String? localPath, required String url}) {
  return SfPdfViewer.network(url);
}
