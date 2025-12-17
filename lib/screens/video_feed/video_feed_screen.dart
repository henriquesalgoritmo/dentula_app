import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:http/http.dart' as http;

import '../../api_config.dart';
import '../../navigation_service.dart';

class VideoFeedScreen extends StatefulWidget {
  final int idPlaylist;
  const VideoFeedScreen({Key? key, this.idPlaylist = 1}) : super(key: key);

  static const String routeName = '/video-feed';

  @override
  State<VideoFeedScreen> createState() => _VideoFeedScreenState();
}

class _VideoFeedScreenState extends State<VideoFeedScreen> with RouteAware {
  List<Map<String, dynamic>> items = [];
  bool loading = true;
  int currentIndex = 0;
  VideoPlayerController? _controller;
  int? _controllerIndex;
  bool _isMuted = false;
  bool _isInitializing = false;

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
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (route != null) {
      try {
        routeObserver.subscribe(this, route);
      } catch (_) {}
    }
  }

  @override
  void dispose() {
    try {
      routeObserver.unsubscribe(this);
    } catch (_) {}
    try {
      if (_controller != null) {
        _controller!.removeListener(_onControllerUpdate);
      }
    } catch (_) {}
    try {
      _controller?.dispose();
    } catch (_) {}
    try {
      _nextController?.removeListener(_onControllerUpdate);
    } catch (_) {}
    try {
      _nextController?.dispose();
    } catch (_) {}
    _pageController.dispose();
    super.dispose();
  }

  @override
  void didPushNext() {
    // another route was pushed above this one
    _disposeControllers();
  }

  @override
  void didPopNext() {
    // returned to this route
    _initControllerForIndex(currentIndex);
  }

  @override
  void didPop() {
    _disposeControllers();
  }

  void _disposeControllers() {
    try {
      if (_controller != null) {
        try {
          _controller!.removeListener(_onControllerUpdate);
        } catch (_) {}
        try {
          if (_controller!.value.isPlaying) _controller!.pause();
        } catch (_) {}
        try {
          _controller!.dispose();
        } catch (_) {}
        _controller = null;
        _controllerIndex = null;
      }
    } catch (_) {}
    try {
      if (_nextController != null) {
        try {
          _nextController!.removeListener(_onControllerUpdate);
        } catch (_) {}
        try {
          if (_nextController!.value.isPlaying) _nextController!.pause();
        } catch (_) {}
        try {
          _nextController!.dispose();
        } catch (_) {}
        _nextController = null;
        _nextControllerIndex = null;
      }
    } catch (_) {}
  }

  void _onControllerUpdate() {
    if (!mounted) return;
    setState(() {});
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
        if (items.isNotEmpty) {
          final route = ModalRoute.of(context);
          if (route != null && route.isCurrent) {
            await _initControllerForIndex(0);
          } else {
            currentIndex = 0;
          }
        }
      }
    } catch (e) {
      debugPrint('video feed fetch error: $e');
    } finally {
      setState(() => loading = false);
    }
  }

  Future<void> _initControllerForIndex(int idx) async {
    if (_isInitializing) return;
    _isInitializing = true;
    try {
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
          // ensure listener and volume
          try {
            _controller!.addListener(_onControllerUpdate);
          } catch (_) {}
          try {
            _controller!.setVolume(_isMuted ? 0.0 : 1.0);
          } catch (_) {}
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
              try {
                _nextController!.addListener(_onControllerUpdate);
              } catch (_) {}
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
    } finally {
      _isInitializing = false;
    }
  }

  void _onPageChanged(int i) {
    setState(() => currentIndex = i);
    _initControllerForIndex(i);
  }

  @override
  void deactivate() {
    // stop and dispose controllers when widget is no longer active
    _disposeControllers();
    super.deactivate();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : items.isEmpty
              ? const Center(child: Text('Sem conteúdo'))
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

                          // Top-right label for type
                          Positioned(
                            top: MediaQuery.of(context).padding.top + 12,
                            right: 12,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                  color: Colors.black45,
                                  borderRadius: BorderRadius.circular(12)),
                              child: const Text('VÍDEO',
                                  style: TextStyle(
                                      color: Colors.white, fontSize: 12)),
                            ),
                          ),

                          // Bottom progress bar and controls
                          if (isActive &&
                              _controller != null &&
                              _controller!.value.isInitialized)
                            Positioned(
                              left: 12,
                              right: 12,
                              bottom: MediaQuery.of(context).padding.bottom + 8,
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  // progress slider
                                  _buildProgressSlider(),
                                  const SizedBox(height: 8),
                                  // controls: rewind, play/pause, forward, mute
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      IconButton(
                                        icon: const Icon(Icons.replay_10,
                                            color: Colors.white),
                                        onPressed: () => _seekRelative(
                                            const Duration(seconds: -15)),
                                      ),
                                      IconButton(
                                        icon: Icon(
                                            _controller!.value.isPlaying
                                                ? Icons.pause_circle_filled
                                                : Icons.play_circle_fill,
                                            color: Colors.white,
                                            size: 40),
                                        onPressed: () {
                                          setState(() {
                                            if (_controller!.value.isPlaying)
                                              _controller!.pause();
                                            else
                                              _controller!.play();
                                          });
                                        },
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.forward_10,
                                            color: Colors.white),
                                        onPressed: () => _seekRelative(
                                            const Duration(seconds: 15)),
                                      ),
                                      const SizedBox(width: 12),
                                      IconButton(
                                        icon: Icon(
                                            _isMuted
                                                ? Icons.volume_off
                                                : Icons.volume_up,
                                            color: Colors.white),
                                        onPressed: () async {
                                          setState(() => _isMuted = !_isMuted);
                                          try {
                                            await _controller?.setVolume(
                                                _isMuted ? 0.0 : 1.0);
                                          } catch (_) {}
                                        },
                                      ),
                                    ],
                                  )
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

  Widget _buildProgressSlider() {
    final value = _controller!.value;
    final duration = value.duration ?? Duration.zero;
    final position = value.position ?? Duration.zero;
    final totalMillis =
        duration.inMilliseconds > 0 ? duration.inMilliseconds.toDouble() : 1.0;
    final posMillis =
        position.inMilliseconds.toDouble().clamp(0.0, totalMillis);

    return Row(
      children: [
        Text(_formatDuration(position),
            style: const TextStyle(color: Colors.white, fontSize: 12)),
        Expanded(
          child: Slider(
            activeColor: Colors.red,
            inactiveColor: Colors.white24,
            value: posMillis,
            min: 0.0,
            max: totalMillis,
            onChanged: (v) {
              final seekTo = Duration(milliseconds: v.toInt());
              _controller?.seekTo(seekTo);
            },
          ),
        ),
        Text(_formatDuration(duration),
            style: const TextStyle(color: Colors.white, fontSize: 12)),
      ],
    );
  }

  String _formatDuration(Duration d) {
    final mm = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final ss = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$mm:$ss';
  }

  void _seekRelative(Duration offset) {
    try {
      final cur = _controller?.value.position ?? Duration.zero;
      final dur = _controller?.value.duration ?? Duration.zero;
      var target = cur + offset;
      if (target < Duration.zero) target = Duration.zero;
      if (target > dur) target = dur;
      _controller?.seekTo(target);
    } catch (_) {}
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
