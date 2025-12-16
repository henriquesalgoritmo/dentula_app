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
  int? _controllerIndex;

  // Preload next controller to make transitions smoother
  VideoPlayerController? _nextController;
  int? _nextControllerIndex;

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
    final base = getApiBaseUrl().replaceAll(RegExp(r'/$'), '');
    final parts = path.split('.');
    if (parts.length < 2) return '$base/file/$path';
    final ext = parts.removeLast();
    final idPart = parts.join('.');
    return '$base/file/$idPart/$ext';
  }

  Future<void> _fetch() async {
    setState(() => loading = true);
    try {
      final url = '${getApiBaseUrl()}conteudo-playlist/${widget.idPlaylist}';
      final resp = await http.get(Uri.parse(url));
      if (resp.statusCode == 200) {
        debugPrint('video feed response body: ${resp.body}');
        final body = jsonDecode(resp.body);
        List<dynamic> data = [];
        if (body is Map && body['data'] is List) data = body['data'];
        if (body is List) data = body;
        items = data
            .whereType<Map<String, dynamic>>()
            .where(
                (e) => e['tipo_conteudo_id'] == 1 || e['tipo_conteudo_id'] == 2)
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
        debugPrint('video feed parsed items count: ${items.length}');
        if (items.isNotEmpty) await _initControllerForIndex(0);
      }
    } catch (e) {
      debugPrint('video feed fetch error: $e');
    } finally {
      setState(() => loading = false);
    }
  }

  Future<void> _initControllerForIndex(int idx) async {
    if (idx < 0 || idx >= items.length) return;

    debugPrint('init controller for index $idx');

    // If we already have the controller for this index, nothing to do
    if (_controllerIndex == idx && _controller != null) return;

    // If nextController was preloaded for this index, promote it
    if (_nextController != null && _nextControllerIndex == idx) {
      debugPrint('Promoting preloaded controller for $idx');
      try {
        await _controller?.pause();
      } catch (_) {}
      try {
        await _controller?.dispose();
      } catch (_) {}
      _controller = _nextController;
      _controllerIndex = _nextControllerIndex;
      _nextController = null;
      _nextControllerIndex = null;
      if (!mounted) return;
      setState(() {});
      try {
        await _controller!.play();
      } catch (e) {
        debugPrint('play error after promote: $e');
      }
    } else {
      // Normal init: dispose current and create new
      try {
        await _controller?.pause();
      } catch (_) {}
      try {
        await _controller?.dispose();
      } catch (_) {}
      _controller = null;
      _controllerIndex = null;

      final item = items[idx];
      final path = (item['path'] ?? '').toString();
      final url = _buildFileUrl(path);
      if (url.isEmpty) return;

      final isHls = url.toLowerCase().endsWith('.m3u8');
      if (isHls) debugPrint('HLS stream detected for $url');

      _controller = VideoPlayerController.network(url)..setLooping(true);
      try {
        await _controller!.initialize();
        if (!mounted) return;
        _controllerIndex = idx;
        setState(() {});
        await _controller!.play();
      } catch (e) {
        debugPrint('video init error: $e');
      }
    }

    // Preload next item to smooth transitions
    final nextIdx = idx + 1;
    if (nextIdx < items.length) {
      if (_nextControllerIndex == nextIdx && _nextController != null) {
        // already preloaded
      } else {
        // dispose old next
        try {
          await _nextController?.dispose();
        } catch (_) {}
        _nextController = null;
        _nextControllerIndex = null;

        final nextItem = items[nextIdx];
        final nextPath = (nextItem['path'] ?? '').toString();
        final nextUrl = _buildFileUrl(nextPath);
        if (nextUrl.isNotEmpty) {
          debugPrint('Preloading next index $nextIdx');
          _nextController = VideoPlayerController.network(nextUrl)
            ..setLooping(true);
          try {
            await _nextController!.initialize();
            _nextControllerIndex = nextIdx;
            // do not autoplay preloaded
            debugPrint('Preloaded next $nextIdx');
          } catch (e) {
            debugPrint('preload error: $e');
            try {
              await _nextController?.dispose();
            } catch (_) {}
            _nextController = null;
            _nextControllerIndex = null;
          }
        }
      }
    }
  }

  void _onPageChanged(int i) {
    setState(() => currentIndex = i);
    _initControllerForIndex(i);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : items.isEmpty
              ? const Center(child: Text('No content'))
              : PageView.builder(
                  controller: _pageController,
                  scrollDirection: Axis.vertical,
                  itemCount: items.length,
                  onPageChanged: _onPageChanged,
                  itemBuilder: (context, index) {
                    final item = items[index];
                    final isVideo = item['tipo_conteudo_id'] == 1;
                    final title = item['titulo'] ?? '';
                    final description = item['descricao'] ?? '';

                    final isActive = index == currentIndex;

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
                          // Video or audio placeholder
                          if (isVideo)
                            isActive &&
                                    _controller != null &&
                                    _controller!.value.isInitialized
                                ? Center(
                                    child: AspectRatio(
                                      aspectRatio:
                                          _controller!.value.aspectRatio,
                                      child: VideoPlayer(_controller!),
                                    ),
                                  )
                                : Container(color: Colors.black)
                          else
                            Container(
                              color: Colors.black,
                              child: const Center(
                                child: Icon(Icons.audiotrack,
                                    size: 96, color: Colors.white),
                              ),
                            ),

                          // Center play/pause overlay
                          if (isActive &&
                              _controller != null &&
                              _controller!.value.isInitialized)
                            Center(
                              child: AnimatedOpacity(
                                opacity:
                                    _controller!.value.isPlaying ? 0.0 : 1.0,
                                duration: const Duration(milliseconds: 250),
                                child: Container(
                                  decoration: BoxDecoration(
                                      color: Colors.black45,
                                      borderRadius: BorderRadius.circular(48)),
                                  padding: const EdgeInsets.all(12),
                                  child: Icon(
                                    _controller!.value.isPlaying
                                        ? Icons.pause
                                        : Icons.play_arrow,
                                    size: 48,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ),

                          // Right side controls (like/share)
                          Positioned(
                            right: 12,
                            bottom: MediaQuery.of(context).padding.bottom + 120,
                            child: Column(
                              children: [
                                LikeButton(),
                                const SizedBox(height: 12),
                                IconButton(
                                  icon: const Icon(Icons.share,
                                      color: Colors.white),
                                  onPressed: () {},
                                ),
                              ],
                            ),
                          ),

                          // Top overlay (title/desc)
                          Positioned(
                            top: MediaQuery.of(context).padding.top + 8,
                            left: 12,
                            right: 100,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(title,
                                    style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold)),
                                const SizedBox(height: 6),
                                Text(description,
                                    style:
                                        const TextStyle(color: Colors.white70),
                                    overflow: TextOverflow.ellipsis),
                              ],
                            ),
                          ),

                          // Bottom progress bar
                          if (isActive &&
                              _controller != null &&
                              _controller!.value.isInitialized)
                            Positioned(
                              left: 0,
                              right: 0,
                              bottom:
                                  MediaQuery.of(context).padding.bottom + 20,
                              child: VideoProgressIndicator(_controller!,
                                  allowScrubbing: false,
                                  colors: VideoProgressColors(
                                      playedColor: Colors.red)),
                            ),
                        ],
                      ),
                    );
                  },
                ),
    );
  }
}

class LikeButton extends StatefulWidget {
  const LikeButton({Key? key}) : super(key: key);

  @override
  State<LikeButton> createState() => _LikeButtonState();
}

class _LikeButtonState extends State<LikeButton> {
  bool liked = false;
  int count = 0;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        IconButton(
          icon: Icon(liked ? Icons.favorite : Icons.favorite_border,
              color: liked ? Colors.red : Colors.white),
          onPressed: () => setState(() {
            liked = !liked;
            count += liked ? 1 : -1;
          }),
        ),
        Text('$count', style: const TextStyle(color: Colors.white)),
      ],
    );
  }
}
