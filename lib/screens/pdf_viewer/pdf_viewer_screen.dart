import 'package:flutter/material.dart';
import 'package:pdfx/pdfx.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:url_launcher/url_launcher.dart';
import 'package:http/http.dart' as http;
import 'dart:io';
import 'package:path_provider/path_provider.dart';

class PdfViewerScreen extends StatefulWidget {
  final String pdfUrl;

  const PdfViewerScreen({
    super.key,
    required this.pdfUrl,
  });

  static String routeName = "/pdf-viewer";

  @override
  State<PdfViewerScreen> createState() => _PdfViewerScreenState();
}

class _PdfViewerScreenState extends State<PdfViewerScreen> {
  late PdfControllerPinch _pdfController;
  bool _isLoading = true;
  String? _errorMessage;
  int _currentPage = 1;
  int _totalPages = 0;

  @override
  void initState() {
    super.initState();
    _loadPdf();
  }

  Future<void> _loadPdf() async {
    try {
      print('=== PDF VIEWER ===');
      print('URL: ${widget.pdfUrl}');
      print('==================');

      // On web we can't use getTemporaryDirectory; open in browser instead
      if (kIsWeb) {
        await _openInBrowser();
        setState(() {
          _isLoading = false;
        });
        return;
      }

      // Download PDF from URL
      print('Baixando PDF...');
      final response = await http.get(Uri.parse(widget.pdfUrl)).timeout(
            const Duration(seconds: 30),
          );

      if (response.statusCode != 200) {
        throw Exception(
            'Erro HTTP ${response.statusCode}: ${response.reasonPhrase}');
      }

      print('PDF baixado: ${response.bodyBytes.length} bytes');

      // Save to temporary file
      final tempDir = await getTemporaryDirectory();
      final tempFile = File('${tempDir.path}/temp_pdf.pdf');
      await tempFile.writeAsBytes(response.bodyBytes);

      print('PDF salvo em: ${tempFile.path}');

      // Load PDF document
      final document = await PdfDocument.openFile(tempFile.path);
      print('PDF carregado com sucesso');
      print('Total de páginas: ${document.pagesCount}');

      _pdfController = PdfControllerPinch(
        document: Future.value(document),
      );

      setState(() {
        _isLoading = false;
        _totalPages = document.pagesCount;
        _currentPage = 1;
      });
    } catch (e) {
      print('Erro ao carregar PDF: $e');
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _openInBrowser() async {
    try {
      final uri = Uri.parse(widget.pdfUrl);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        _showError('Não foi possível abrir a URL');
      }
    } catch (e) {
      _showError('Erro ao abrir no navegador: $e');
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  void _nextPage() {
    if (_currentPage < _totalPages) {
      _pdfController.nextPage(
          duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
      setState(() => _currentPage++);
    }
  }

  void _previousPage() {
    if (_currentPage > 1) {
      _pdfController.previousPage(
          duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
      setState(() => _currentPage--);
    }
  }

  @override
  void dispose() {
    _pdfController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Visualizador de PDF'),
        elevation: 0,
        actions: [
          if (!_isLoading && _errorMessage == null)
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Center(
                child: Text(
                  '$_currentPage/$_totalPages',
                  style: const TextStyle(fontSize: 14),
                ),
              ),
            ),
          IconButton(
            icon: const Icon(Icons.open_in_browser),
            tooltip: 'Abrir no navegador',
            onPressed: _openInBrowser,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Carregando PDF...'),
                ],
              ),
            )
          : _errorMessage != null
              ? _buildErrorWidget()
              : Stack(
                  children: [
                    PdfViewPinch(
                      controller: _pdfController,
                    ),
                    Positioned(
                      bottom: 16,
                      left: 16,
                      right: 16,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          FloatingActionButton.small(
                            onPressed: _previousPage,
                            tooltip: 'Página anterior',
                            child: const Icon(Icons.arrow_back),
                          ),
                          const SizedBox(width: 16),
                          Text(
                            '$_currentPage / $_totalPages',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(width: 16),
                          FloatingActionButton.small(
                            onPressed: _nextPage,
                            tooltip: 'Próxima página',
                            child: const Icon(Icons.arrow_forward),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
    );
  }

  Widget _buildErrorWidget() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 64, color: Colors.red),
          const SizedBox(height: 16),
          const Text(
            'Erro ao carregar PDF',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: SingleChildScrollView(
              child: Text(
                _errorMessage ?? 'Erro desconhecido',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 13, color: Colors.grey),
              ),
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _openInBrowser,
            icon: const Icon(Icons.open_in_browser),
            label: const Text('Abrir no Navegador'),
          ),
          const SizedBox(height: 8),
          ElevatedButton.icon(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.arrow_back),
            label: const Text('Voltar'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.grey,
            ),
          ),
        ],
      ),
    );
  }
}
