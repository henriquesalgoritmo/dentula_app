import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'pdf_viewer_screen.dart';

class PdfViewerTestScreen extends StatefulWidget {
  const PdfViewerTestScreen({super.key});

  static String routeName = "/pdf-test";

  @override
  State<PdfViewerTestScreen> createState() => _PdfViewerTestScreenState();
}

class _PdfViewerTestScreenState extends State<PdfViewerTestScreen> {
  late TextEditingController _urlController;
  final String defaultUrl =
      'http://localhost:8000/api/file/uploads/oXxvegRNXUa9YMfjyYwA0tnJMx7JhjwZ3AND8mpo/pdf?_t=1765786844000';
  bool _testingUrl = false;
  String? _testResult;

  @override
  void initState() {
    super.initState();
    _urlController = TextEditingController(text: defaultUrl);
  }

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }

  Future<void> _testUrl(String url) async {
    if (url.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Por favor, insira uma URL válida')),
      );
      return;
    }

    setState(() {
      _testingUrl = true;
      _testResult = null;
    });

    try {
      print('Testando URL: $url');
      final response = await http.head(Uri.parse(url)).timeout(
            const Duration(seconds: 10),
          );

      print('Status Code: ${response.statusCode}');
      print('Headers: ${response.headers}');

      setState(() {
        if (response.statusCode == 200) {
          _testResult =
              '✅ URL Válida (Status: ${response.statusCode})\n\nContent-Type: ${response.headers['content-type'] ?? 'N/A'}';
        } else {
          _testResult =
              '⚠️ Resposta: ${response.statusCode}\n\n${response.reasonPhrase}';
        }
      });
    } catch (e) {
      print('Erro ao testar URL: $e');
      setState(() {
        _testResult = '❌ Erro: $e';
      });
    } finally {
      setState(() => _testingUrl = false);
    }
  }

  void _openPdfViewer() {
    final url = _urlController.text.trim();
    if (url.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Por favor, insira uma URL válida')),
      );
      return;
    }

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => PdfViewerScreen(pdfUrl: url),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Visualizador de PDF'),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Insira a URL do PDF para visualizar:',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _urlController,
              maxLines: 3,
              decoration: InputDecoration(
                hintText: 'Ex: http://localhost:8000/api/file/uploads/...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                contentPadding: const EdgeInsets.all(12),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _testingUrl
                        ? null
                        : () => _testUrl(_urlController.text.trim()),
                    icon: _testingUrl
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                            ),
                          )
                        : const Icon(Icons.check_circle),
                    label: const Text('Testar URL'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _openPdfViewer,
                    icon: const Icon(Icons.open_in_new),
                    label: const Text('Abrir PDF'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
            if (_testResult != null) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _testResult!.contains('✅')
                      ? Colors.green.withOpacity(0.1)
                      : _testResult!.contains('⚠️')
                          ? Colors.orange.withOpacity(0.1)
                          : Colors.red.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: _testResult!.contains('✅')
                        ? Colors.green
                        : _testResult!.contains('⚠️')
                            ? Colors.orange
                            : Colors.red,
                  ),
                ),
                child: Text(
                  _testResult!,
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 12,
                  ),
                ),
              ),
            ],
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '📋 URLs dos Comprobativos:',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Verifique o console/terminal para ver as URLs dos comprobativos quando abrir uma subscrição.',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'URL padrão: $defaultUrl',
                    style:
                        const TextStyle(fontSize: 11, fontFamily: 'monospace'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.amber.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '⚠️ Dicas:',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 8),
                  Text(
                    '1. Use o botão "Testar URL" para verificar se a URL está acessível\n'
                    '2. Se o PDF não carregar, clique em "Abrir no navegador"\n'
                    '3. Verifique o console para mensagens de erro\n'
                    '4. Certifique-se de que o backend está rodando (localhost:8000)',
                    style: TextStyle(fontSize: 12),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
