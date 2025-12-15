import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:pdfx/pdfx.dart';

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
  return _PdfInlineViewer(localPath: localPath, url: url);
}

class _PdfInlineViewer extends StatefulWidget {
  final String? localPath;
  final String url;

  const _PdfInlineViewer({required this.localPath, required this.url});

  @override
  State<_PdfInlineViewer> createState() => _PdfInlineViewerState();
}

class _PdfInlineViewerState extends State<_PdfInlineViewer> {
  late final Future<PdfDocument> _docFuture;
  PdfControllerPinch? _controller;

  @override
  void initState() {
    super.initState();
    _docFuture = _openDocument();
  }

  Future<PdfDocument> _openDocument() async {
    if (widget.localPath != null && File(widget.localPath!).existsSync()) {
      return PdfDocument.openFile(widget.localPath!);
    }
    final resp = await http.get(Uri.parse(widget.url));
    if (resp.statusCode != 200) {
      throw Exception('Falha ao baixar PDF (${resp.statusCode})');
    }
    return PdfDocument.openData(resp.bodyBytes);
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<PdfDocument>(
      future: _docFuture,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snap.hasError) {
          return Center(
            child: Text(
              'Erro ao abrir PDF: ${snap.error}',
              textAlign: TextAlign.center,
            ),
          );
        }
        final doc = snap.data!;
        _controller ??= PdfControllerPinch(document: Future.value(doc));
        return PdfViewPinch(controller: _controller!);
      },
    );
  }
}
