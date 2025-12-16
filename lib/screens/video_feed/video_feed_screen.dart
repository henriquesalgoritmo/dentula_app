import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:http/http.dart' as http;

import '../../api_config.dart';

class VideoFeedScreen extends StatefulWidget {
  final int idPlaylist;
  const VideoFeedScreen({Key? key, this.idPlaylist = 1}) : super(key: key);

  static const String routeName = '/video-feed';

  @override
  State<VideoFeedScreen> createState() => _VideoFeedScreenState();
}

class _VideoFeedScreenState extends State<VideoFeedScreen> {
  List<Map<String, dynamic>> items = [];
  bool loading = true;
  int currentIndex = 0;
  VideoPlayerController? _controller;

  final PageController _pageController = PageController();

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  @override
  void dispose() {
    _controller?.dispose();
    _pageController.dispose();
    super.dispose();
  }

  String _buildFileUrl(String path) {
    if (path.isEmpty) return '';
    final parts = path.split('.');
    if (parts.length < 2) return '${getApiBaseUrl()}file/$path';
    final ext = parts.removeLast();
    final idPart = parts.join('.');
    return '${getApiBaseUrl()}file/$idPart/$ext';
  }

  Future<void> _fetch() async {
    setState(() => loading = true);
    try {
      final url = '${getApiBaseUrl()}conteudo-playlist/${widget.idPlaylist}';
      final resp = await http.get(Uri.parse(url));
      if (resp.statusCode == 200) {
        final body = jsonDecode(resp.body);
        List<dynamic> data = [];
        if (body is Map && body['data'] is List) data = body['data'];
        if (body is List) data = body;
        // Filter only video and audio (tipo_conteudo_id 1 or 2)
        items = data
            .whereType<Map<String, dynamic>>()
            .where(
                (e) => e['tipo_conteudo_id'] == 1 || e['tipo_conteudo_id'] == 2)
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
        if (items.isNotEmpty) _initControllerForIndex(0);
      }
    } catch (e) {
      // ignore
    } finally {
      setState(() => loading = false);
    }
  }

  void _initControllerForIndex(int idx) async {
    _controller?.pause();
    await _controller?.dispose();
    _controller = null;

    if (idx < 0 || idx >= items.length) return;
    final item = items[idx];
    final path = (item['path'] ?? '').toString();
    final url = _buildFileUrl(path);
    if (url.isEmpty) return;

    _controller = VideoPlayerController.network(url)
      ..setLooping(true)
      ..initialize().then((_) {
        setState(() {});
        _controller?.play();
      });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : PageView.builder(
              controller: _pageController,
              scrollDirection: Axis.vertical,
              itemCount: items.length,
              onPageChanged: (i) {
                setState(() => currentIndex = i);
                _initControllerForIndex(i);
              },
              itemBuilder: (context, index) {
                final item = items[index];
                final isVideo = item['tipo_conteudo_id'] == 1;
                return GestureDetector(
                  onTap: () {
                    if (_controller != null &&
                        _controller!.value.isInitialized) {
                      setState(() {
                        if (_controller!.value.isPlaying)
                          _controller!.pause();
                        else
                          _controller!.play();
                      });
                    }
                  },
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      if (isVideo)
                        _controller != null && _controller!.value.isInitialized
                            ? FittedBox(
                                fit: BoxFit.cover,
                                child: SizedBox(
                                  width: _controller!.value.size.width,
                                  height: _controller!.value.size.height,
                                  child: VideoPlayer(_controller!),
                                ),
                              )
                            : const Center(child: CircularProgressIndicator())
                      else
                        // Audio placeholder
                        Container(
                          color: Colors.black,
                          child: const Center(
                            child: Icon(Icons.audiotrack,
                                size: 96, color: Colors.white),
                          ),
                        ),

                      // Top overlay
                      Positioned(
                        top: MediaQuery.of(context).padding.top + 8,
                        left: 12,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(item['titulo'] ?? '',
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold)),
                            const SizedBox(height: 6),
                            Text(item['descricao'] ?? '',
                                style: const TextStyle(color: Colors.white70)),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
    );
  }
}
