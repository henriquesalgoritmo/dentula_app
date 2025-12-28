import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import '../../api_config.dart';
import 'pdf_viewer_screen.dart';

class PdfViewerTestScreen extends StatefulWidget {
  const PdfViewerTestScreen({super.key});

  static String routeName = "/pdf-test";

  @override
  State<PdfViewerTestScreen> createState() => _PdfViewerTestScreenState();
}

class _PdfViewerTestScreenState extends State<PdfViewerTestScreen> {
  bool loading = false;
  List<dynamic> items = [];

  @override
  void initState() {
    super.initState();
    fetchData();
  }

  Future<void> fetchData() async {
    setState(() => loading = true);
    try {
      final base = getApiBaseUrl();
      final uri = Uri.parse('${base}documentos');
      print('GET $uri');
      // increase timeout and log response for debugging
      final resp = await http.get(uri).timeout(const Duration(seconds: 20));
      print('fetch documentos status: ${resp.statusCode}');
      print('fetch documentos headers: ${resp.headers}');
      print('fetch documentos body: ${resp.body}');
      if (resp.statusCode == 200) {
        final body = jsonDecode(resp.body);
        setState(() {
          items = body['data'] ?? [];
        });
      } else {
        print('fetch documentos não OK: ${resp.statusCode}');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Erro na API: ${resp.statusCode}')));
        }
      }
    } catch (e, st) {
      // Print full error and stack for diagnosis
      print('Erro fetch documentos: $e');
      print('Stack: $st');
      if (e is TimeoutException) print('Request timed out after 20s');
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Erro ao buscar documentos: $e')));
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  String _proxyImageUrl(String path) {
    final base = getApiBaseUrl();
    var root = base.replaceAll(RegExp(r'\/$'), '');
    return '$root/proxy-image/$path';
  }

  String _toProxyPdf(String raw) {
    if (raw.startsWith('http')) {
      if (raw.contains('/storage/')) {
        final idx = raw.indexOf('/storage/') + '/storage/'.length;
        final path = raw.substring(idx);
        return '${getApiBaseUrl()}proxy-image/$path';
      }
      return raw;
    }
    final p = raw.replaceAll(RegExp(r'^/+'), '');
    return '${getApiBaseUrl()}proxy-image/$p';
  }

  String _buildDownloadUrl(String path) {
    if (path.isEmpty) return '';
    final parts = path.split('/');
    if (parts.isEmpty) return '';
    final last = parts.removeLast();
    final lastParts = last.split('.');
    if (lastParts.length < 2) {
      // fallback to file route
      return '${getApiBaseUrl()}file/$path';
    }
    final ext = lastParts.removeLast();
    final filename = lastParts.join('.');
    final folder = parts.join('/');
    return '${getApiBaseUrl()}download/$folder/$filename/$ext';
  }

  void _openPdfViewerWithUrl(String raw) {
    final url = _toProxyPdf(raw);
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'PDF',
      transitionDuration: const Duration(milliseconds: 200),
      pageBuilder: (context, animation, secondaryAnimation) {
        return SafeArea(
          child: SizedBox(
            width: MediaQuery.of(context).size.width,
            height: MediaQuery.of(context).size.height,
            child: Scaffold(
              body: PdfViewerScreen(pdfUrl: url),
            ),
          ),
        );
      },
    );
  }

  Future<void> _downloadDocument(String path) async {
    var url = _buildDownloadUrl(path);
    if (url.isEmpty) return;
    // Ensure the URL is absolute (has a scheme). If not, prefix with API base.
    final parsed = Uri.tryParse(url);
    if (parsed == null || (parsed.scheme == null || parsed.scheme.isEmpty)) {
      final base = getApiBaseUrl();
      url = base + (url.startsWith('/') ? url.substring(1) : url);
    }

    try {
      final uri = Uri.parse(url);
      // Try to open with external application (browser). If it fails, show a message.
      final launched =
          await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!launched && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Não foi possível abrir o link de download')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Erro ao abrir link de download: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Documentos',
                      style:
                          TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                  SizedBox.shrink(),
                ],
              ),
              const SizedBox(height: 12),
              Expanded(
                child: loading
                    ? const Center(child: CircularProgressIndicator())
                    : RefreshIndicator(
                        onRefresh: fetchData,
                        child: items.isEmpty
                            ? ListView(
                                children: const [
                                  SizedBox(height: 80),
                                  Center(
                                      child:
                                          Text('Nenhum documento encontrado')),
                                ],
                              )
                            : ListView.builder(
                                padding: const EdgeInsets.all(12),
                                itemCount: items.length,
                                itemBuilder: (context, index) {
                                  final d = items[index];
                                  final capa =
                                      (d['path_capa'] as String? ?? '').trim();
                                  final pdf =
                                      (d['path_pdf'] as String? ?? '').trim();
                                  final titulo = d['titulo'] ?? '';
                                  final descricao = d['descricao'] ?? '';
                                  final pais = d['pais'] != null
                                      ? d['pais']['nome']
                                      : '';

                                  return Card(
                                    margin:
                                        const EdgeInsets.symmetric(vertical: 8),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        if (capa.isNotEmpty)
                                          SizedBox(
                                            height: 180,
                                            child: Row(
                                              children: [
                                                Expanded(
                                                  child: Image.network(
                                                    _proxyImageUrl(capa),
                                                    fit: BoxFit.cover,
                                                    errorBuilder: (c, e, s) =>
                                                        const Center(
                                                            child: Icon(Icons
                                                                .broken_image)),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        Padding(
                                          padding: const EdgeInsets.all(12.0),
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(titulo,
                                                  style: const TextStyle(
                                                      fontSize: 18,
                                                      fontWeight:
                                                          FontWeight.bold)),
                                              const SizedBox(height: 6),
                                              Text(descricao,
                                                  style: const TextStyle(
                                                      color: Colors.grey)),
                                              const SizedBox(height: 8),
                                              if (pais.isNotEmpty)
                                                Chip(
                                                  avatar: (pais.trim().length ==
                                                          2)
                                                      ? ClipRRect(
                                                          borderRadius:
                                                              BorderRadius
                                                                  .circular(3),
                                                          child: Image.network(
                                                            'https://flagcdn.com/w40/${pais.toLowerCase()}.png',
                                                            width: 20,
                                                            height: 14,
                                                            fit: BoxFit.cover,
                                                            errorBuilder: (c, e,
                                                                    s) =>
                                                                CircleAvatar(
                                                              radius: 10,
                                                              child: Text(pais[
                                                                      0]
                                                                  .toUpperCase()),
                                                            ),
                                                          ),
                                                        )
                                                      : CircleAvatar(
                                                          radius: 10,
                                                          child: Text(pais[0]
                                                              .toUpperCase()),
                                                        ),
                                                  label: Text(pais),
                                                ),
                                              const SizedBox(height: 12),
                                              Align(
                                                alignment:
                                                    Alignment.centerRight,
                                                child: Wrap(
                                                  spacing: 8,
                                                  children: [
                                                    ElevatedButton.icon(
                                                      onPressed: pdf.isNotEmpty
                                                          ? () =>
                                                              _downloadDocument(
                                                                  pdf)
                                                          : null,
                                                      icon: const Icon(
                                                          Icons.download),
                                                      label:
                                                          const Text('Baixar'),
                                                    ),
                                                    ElevatedButton.icon(
                                                      onPressed: pdf.isNotEmpty
                                                          ? () =>
                                                              _openPdfViewerWithUrl(
                                                                  pdf)
                                                          : null,
                                                      icon: const Icon(
                                                          Icons.open_in_new),
                                                      label:
                                                          const Text('Abrir'),
                                                      style: ElevatedButton
                                                          .styleFrom(
                                                              backgroundColor:
                                                                  Colors.green),
                                                    ),
                                                  ],
                                                ),
                                              )
                                            ],
                                          ),
                                        )
                                      ],
                                    ),
                                  );
                                },
                              ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
