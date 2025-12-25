import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../../api_config.dart';
import '../../constants.dart';

class NewsScreen extends StatefulWidget {
  const NewsScreen({Key? key}) : super(key: key);

  static const String routeName = '/news';

  @override
  State<NewsScreen> createState() => _NewsScreenState();
}

class _NewsScreenState extends State<NewsScreen> {
  bool loading = false;
  List<dynamic> items = [];

  String _two(int v) => v.toString().padLeft(2, '0');

  String _formatDateTime(dynamic raw) {
    if (raw == null) return '';
    try {
      final dt = DateTime.parse(raw.toString()).toLocal();
      return '${_two(dt.day)}/${_two(dt.month)}/${dt.year} ${_two(dt.hour)}:${_two(dt.minute)}';
    } catch (e) {
      return raw.toString();
    }
  }

  @override
  void initState() {
    super.initState();
    fetchData();
  }

  Future<void> fetchData() async {
    setState(() => loading = true);
    try {
      final uri = Uri.parse('${getApiBaseUrl()}noticias');
      final resp = await http.get(uri).timeout(const Duration(seconds: 15));
      if (resp.statusCode == 200) {
        final body = jsonDecode(resp.body);
        setState(() => items = body['data'] ?? []);
      }
    } catch (e) {
      debugPrint('news fetch error: $e');
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  void openFull(Map<String, dynamic> item) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) {
      return Scaffold(
        appBar: AppBar(title: Text(item['titulo'] ?? '')),
        body: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // show fixed-size cover image (use path_capa or imagem)
              if ((item['path_capa'] ?? item['imagem']) != null)
                GestureDetector(
                  onTap: () {
                    final img =
                        '${getApiBaseUrl()}proxy-image/${Uri.encodeComponent((item['path_capa'] ?? item['imagem']))}';
                    Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => ImageFullScreenPage(
                          url: img,
                          tag:
                              'news-${item['id'] ?? DateTime.now().millisecondsSinceEpoch}'),
                    ));
                  },
                  child: SizedBox(
                    height: 260,
                    width: double.infinity,
                    child: Hero(
                      tag:
                          'news-${item['id'] ?? DateTime.now().millisecondsSinceEpoch}',
                      child: Image.network(
                        '${getApiBaseUrl()}proxy-image/${Uri.encodeComponent((item['path_capa'] ?? item['imagem']))}',
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                ),
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(item['titulo'] ?? '',
                        style: const TextStyle(
                            fontSize: 22, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 12),
                    Text(item['descricao'] ?? ''),
                  ],
                ),
              )
            ],
          ),
        ),
      );
    }));
  }

  @override
  Widget build(BuildContext context) {
    if (loading) return const Center(child: CircularProgressIndicator());
    if (items.isEmpty) return const Center(child: Text('Sem notícias'));

    return RefreshIndicator(
      onRefresh: fetchData,
      child: ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: items.length,
        itemBuilder: (context, i) {
          final it = items[i] as Map<String, dynamic>;
          final image = it['path_capa'] ?? it['imagem'];
          return Card(
            margin: const EdgeInsets.symmetric(vertical: 8),
            child: InkWell(
              onTap: () => openFull(it),
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (image != null)
                      SizedBox(
                        height: 180,
                        width: double.infinity,
                        child: Image.network(
                          '${getApiBaseUrl()}proxy-image/${Uri.encodeComponent(image)}',
                          fit: BoxFit.cover,
                        ),
                      ),
                    const SizedBox(height: 8),
                    Text(it['titulo'] ?? '',
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 16)),
                    const SizedBox(height: 6),
                    // date/time line
                    Text(_formatDateTime(it['created_at']),
                        style:
                            TextStyle(color: Colors.grey[600], fontSize: 12)),
                    const SizedBox(height: 8),
                    Text((it['descricao'] ?? '')
                            .toString()
                            .replaceAll(RegExp(r'<[^>]*>'), '')
                            .substring(
                                0,
                                (it['descricao'] ?? '')
                                    .toString()
                                    .length
                                    .clamp(0, 140)) +
                        (it['descricao'] != null &&
                                it['descricao'].toString().length > 140
                            ? '...'
                            : '')),
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.bottomRight,
                      child: Icon(
                        Icons.remove_red_eye,
                        color: kPrimaryColor,
                        size: 28,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class ImageFullScreenPage extends StatelessWidget {
  final String url;
  final String tag;

  const ImageFullScreenPage({Key? key, required this.url, required this.tag})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Center(
        child: Hero(
          tag: tag,
          child: InteractiveViewer(
            panEnabled: true,
            minScale: 1.0,
            maxScale: 4.0,
            child: Image.network(url, fit: BoxFit.contain),
          ),
        ),
      ),
    );
  }
}
