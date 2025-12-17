import 'package:http/http.dart' as http;
import 'package:pdfx/pdfx.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';

/// IO implementation: download to temp file then open by path
Future<PdfDocument> loadPdfDocumentFromUrl(String url) async {
  final response = await http.get(Uri.parse(url)).timeout(
        const Duration(seconds: 30),
      );

  if (response.statusCode != 200) {
    throw Exception(
        'Erro HTTP ${response.statusCode}: ${response.reasonPhrase}');
  }

  final tempDir = await getTemporaryDirectory();
  final tempFile = File('${tempDir.path}/temp_pdf.pdf');
  await tempFile.writeAsBytes(response.bodyBytes);

  return PdfDocument.openFile(tempFile.path);
}
