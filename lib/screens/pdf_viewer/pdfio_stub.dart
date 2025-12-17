import 'package:http/http.dart' as http;
import 'package:pdfx/pdfx.dart';

/// Web / fallback implementation: fetch bytes and open with PdfDocument.openData
Future<PdfDocument> loadPdfDocumentFromUrl(String url) async {
  final response = await http.get(Uri.parse(url)).timeout(
        const Duration(seconds: 30),
      );

  if (response.statusCode != 200) {
    throw Exception(
        'Erro HTTP ${response.statusCode}: ${response.reasonPhrase}');
  }

  return PdfDocument.openData(response.bodyBytes);
}
