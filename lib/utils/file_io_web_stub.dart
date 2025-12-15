// Non-web stub for `file_io_web` to keep the API available during analysis.
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

Future<bool> existsFile(String filename) async => false;
Future<String?> saveFileBytes(String filename, List<int> bytes) async => null;
String? localFilePath(String filename) => null;
Future<String?> getLocalFilePath(String filename) async => null;

Widget buildPdfViewer({String? localPath, required String url}) {
  return Center(
    child: Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('Visualização inline não suportada nesta plataforma.'),
          const SizedBox(height: 8),
          ElevatedButton(
            onPressed: () async {
              final uri = Uri.parse(url);
              await launchUrl(uri, mode: LaunchMode.externalApplication);
            },
            child: const Text('Abrir PDF no navegador'),
          ),
        ],
      ),
    ),
  );
}
