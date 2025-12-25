import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:video_player/video_player.dart';
import 'package:http/http.dart' as http;

import '../../api_config.dart';
import '../../navigation_service.dart';
import 'package:provider/provider.dart';
import 'package:shop_app/providers/auth_provider.dart';

class VideoFeedScreen extends StatefulWidget {
  final int idPlaylist;
  const VideoFeedScreen({Key? key, this.idPlaylist = 0}) : super(key: key);

  static const String routeName = '/video-feed';

  @override
  State<VideoFeedScreen> createState() => _VideoFeedScreenState();
}

class _VideoFeedScreenState extends State<VideoFeedScreen> with RouteAware {
  List<Map<String, dynamic>> items = [];
  bool loading = true;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  int _page = 1;
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
    _fetch(page: 1, append: false);
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

  Future<void> _fetch({int page = 1, bool append = false}) async {
    if (!append) setState(() => loading = true);
    try {
      final url =
          '${getApiBaseUrl()}conteudo-playlist/${widget.idPlaylist}?page=$page';
      final resp = await http.get(Uri.parse(url));
      if (resp.statusCode == 200) {
        debugPrint('video feed response body: ${resp.body}');
        final body = jsonDecode(resp.body);
        List<dynamic> data = [];
        if (body is Map && body['data'] is List) data = body['data'];
        if (body is List) data = body;
        final newItems = data
            .whereType<Map<String, dynamic>>()
            .where(
                (e) => e['tipo_conteudo_id'] == 1 || e['tipo_conteudo_id'] == 2)
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
        if (append) {
          // append while avoiding duplicates by id
          final existingIds = items.map((e) => e['id']).toSet();
          for (final it in newItems) {
            if (!existingIds.contains(it['id'])) items.add(it);
          }
        } else {
          items = newItems;
        }
        // determine pagination
        try {
          if (body is Map) {
            if (body.containsKey('current_page') &&
                body.containsKey('last_page')) {
              final cur = int.tryParse(body['current_page'].toString()) ?? page;
              final last = int.tryParse(body['last_page'].toString()) ?? cur;
              _hasMore = cur < last;
              _page = cur;
            } else if (body.containsKey('next_page_url')) {
              _hasMore = body['next_page_url'] != null;
              // page remains as requested
              _page = page;
            } else if (body.containsKey('meta') &&
                body['meta'] is Map &&
                body['meta'].containsKey('last_page')) {
              final cur = int.tryParse(body['current_page'].toString()) ?? page;
              final last =
                  int.tryParse(body['meta']['last_page'].toString()) ?? cur;
              _hasMore = cur < last;
              _page = cur;
            } else {
              // unknown format: if we received items, assume there may be more
              _hasMore = newItems.isNotEmpty;
              _page = page;
            }
          }
        } catch (_) {
          _hasMore = newItems.isNotEmpty;
        }
        debugPrint('video feed parsed items count: ${items.length}');
        // Print full file URL for each item for easier debugging in terminal
        for (var i = 0; i < items.length; i++) {
          try {
            final it = items[i];
            final path = (it['path'] ?? '').toString();
            final url = _buildFileUrl(path);
            debugPrint(
                'video[$i] id=${it['id']} title=${it['titulo'] ?? ''} url=$url');
          } catch (e) {
            debugPrint('video print error for index $i: $e');
          }
        }
        if (items.isNotEmpty) {
          final route = ModalRoute.of(context);
          if (route != null && route.isCurrent) {
            // initialize only if first page or not appending
            if (!append) await _initControllerForIndex(0);
          } else {
            currentIndex = 0;
          }
        }
      }
    } catch (e) {
      debugPrint('video feed fetch error: $e');
    } finally {
      if (!append) setState(() => loading = false);
      if (append) setState(() => _isLoadingMore = false);
    }
  }

  Future<void> _loadNextPage() async {
    if (!_hasMore || _isLoadingMore) return;
    _isLoadingMore = true;
    final next = _page + 1;
    await _fetch(page: next, append: true);
  }

  Future<void> _initControllerForIndex(int idx) async {
    if (_isInitializing) return;
    _isInitializing = true;
    try {
      if (idx < 0 || idx >= items.length) return;

      debugPrint('init controller for index $idx');

      // If we already have the controller for this index, nothing to do
      if (_controllerIndex == idx && _controller != null) return;

      // Always initialize only the controller for the active index.
      // Dispose any existing controller first to free resources.
      try {
        await _controller?.pause();
      } catch (_) {}
      try {
        await _controller?.dispose();
      } catch (_) {}
      _controller = null;
      _controllerIndex = null;

      final item = items[idx];
      // Check access: if this content has associated pacotes and the current
      // user does not own any of them, block initialization.
      try {
        final auth = Provider.of<AuthProvider>(context, listen: false);
        final allowed = _userHasAccessForItem(item, auth);
        if (!allowed) {
          // mark blocked so UI can show overlay
          items[idx]['_blocked'] = true;
          if (mounted) setState(() {});
          return;
        } else {
          items[idx]['_blocked'] = false;
        }
      } catch (_) {
        // if anything goes wrong checking auth, default to not blocked
        items[idx]['_blocked'] = false;
      }
      final path = (item['path'] ?? '').toString();

      // Construct HLS playlist URL and use it exclusively
      String hlsUrl = '';
      try {
        final parts = path.split('/').last.split('.');
        if (parts.isNotEmpty) {
          final fileName = parts.sublist(0, parts.length - 1).join('.');
          final base = getApiBaseUrl().replaceAll(RegExp(r'/$'), '');
          hlsUrl = '$base/hls/$fileName/playlist.m3u8';
        }
      } catch (_) {}

      debugPrint('video init (active only): hls url=$hlsUrl');

      if (hlsUrl.isEmpty) return;

      final chosenUrl = hlsUrl;

      final isHls = chosenUrl.toLowerCase().endsWith('.m3u8');
      if (isHls) debugPrint('HLS stream detected for $chosenUrl');

      _controller = VideoPlayerController.network(chosenUrl)..setLooping(true);
      try {
        await _controller!.initialize();
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
    } finally {
      _isInitializing = false;
    }
  }

  void _onPageChanged(int i) {
    setState(() => currentIndex = i);
    _initControllerForIndex(i);
    // Prefetch next page when the user reaches the penultimate item
    // (better UX than waiting for the absolute last item).
    if (i >= items.length - 2 && _hasMore && !_isLoadingMore) {
      _loadNextPage();
    }
  }

  bool _userHasAccessForItem(Map<String, dynamic> item, AuthProvider auth) {
    try {
      // If content has no pacotes, it's public
      final contentPacotes = <int>[];
      if (item.containsKey('pacotes') && item['pacotes'] is List) {
        for (final p in item['pacotes']) {
          if (p is Map && p['id'] != null) {
            final id = int.tryParse(p['id'].toString());
            if (id != null) contentPacotes.add(id);
          } else if (p is int) {
            contentPacotes.add(p);
          }
        }
      }

      if (contentPacotes.isEmpty) return true;

      // Get user pacote ids (try multiple shapes)
      final user = auth.user;
      final userPacoteIds = <int>[];
      if (user != null) {
        if (user is Map && user['pacoteIds'] != null) {
          final pi = user['pacoteIds'];
          if (pi is List) {
            for (final v in pi) {
              final id = int.tryParse(v.toString());
              if (id != null) userPacoteIds.add(id);
            }
          } else if (pi is String) {
            try {
              final decoded = pi.startsWith('[') ? jsonDecode(pi) : null;
              if (decoded is List) {
                for (final v in decoded) {
                  final id = int.tryParse(v.toString());
                  if (id != null) userPacoteIds.add(id);
                }
              }
            } catch (_) {}
          }
        }
      }

      // If user has any matching pacote id, allow access
      for (final id in contentPacotes) {
        if (userPacoteIds.contains(id)) return true;
      }

      return false;
    } catch (_) {
      return true; // fail-open: if error, allow playback
    }
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
              : Stack(
                  children: [
                    PageView.builder(
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

                        final blocked = (item['_blocked'] == true);

                        return GestureDetector(
                          onTap: () {
                            // If blocked, do nothing (or show a message)
                            if (blocked) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                      content: Text(
                                          'Conteúdo bloqueado — adquira o pacote para aceder.')));
                              return;
                            }
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
                                    opacity: _controller!.value.isPlaying
                                        ? 0.0
                                        : 1.0,
                                    duration: const Duration(milliseconds: 250),
                                    child: Container(
                                      decoration: BoxDecoration(
                                          color: Colors.black45,
                                          borderRadius:
                                              BorderRadius.circular(48)),
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
                                bottom:
                                    MediaQuery.of(context).padding.bottom + 120,
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

                              // If blocked, show a centered lock and list the
                              // content's pacotes (names) in small text below it.
                              if (blocked)
                                Center(
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(16),
                                        decoration: BoxDecoration(
                                            color: Colors.black54,
                                            shape: BoxShape.circle),
                                        child: const Icon(Icons.lock_outline,
                                            color: Colors.white, size: 64),
                                      ),
                                      const SizedBox(height: 12),
                                      // Title (small but visible) — appears above the pacote list
                                      if ((title ?? '').toString().isNotEmpty)
                                        Padding(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 24.0),
                                          child: Text(
                                            title.toString(),
                                            textAlign: TextAlign.center,
                                            style: const TextStyle(
                                                color: Colors.white,
                                                fontSize: 14,
                                                fontWeight: FontWeight.bold),
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      const SizedBox(height: 8),
                                      // Label: Pacotes permitidos
                                      Padding(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 24.0),
                                        child: Text(
                                          'Pacotes permitidos:',
                                          textAlign: TextAlign.center,
                                          style: const TextStyle(
                                              color: Colors.white70,
                                              fontSize: 12,
                                              fontWeight: FontWeight.w600),
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      // Show list of pacote names associated with content
                                      Builder(builder: (c) {
                                        final pacotes = <String>[];
                                        if (item.containsKey('pacotes') &&
                                            item['pacotes'] is List) {
                                          for (final p in item['pacotes']) {
                                            try {
                                              if (p is Map &&
                                                  p['designacao'] != null) {
                                                pacotes.add(
                                                    p['designacao'].toString());
                                              } else if (p is Map &&
                                                  p['designacao'] == null &&
                                                  p['nome'] != null) {
                                                pacotes
                                                    .add(p['nome'].toString());
                                              }
                                            } catch (_) {}
                                          }
                                        }

                                        if (pacotes.isEmpty) {
                                          return const SizedBox.shrink();
                                        }

                                        return Padding(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 24.0),
                                          child: Text(
                                            pacotes.join(' • '),
                                            textAlign: TextAlign.center,
                                            style: const TextStyle(
                                                color: Colors.white70,
                                                fontSize: 12),
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        );
                                      }),
                                    ],
                                  ),
                                ),

                              // (Title/description moved below controls)

                              // (Type label moved below controls)

                              // Bottom progress bar and controls
                              if (isActive &&
                                  _controller != null &&
                                  _controller!.value.isInitialized)
                                Positioned(
                                  left: 12,
                                  right: 12,
                                  bottom:
                                      MediaQuery.of(context).padding.bottom + 8,
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      // progress slider
                                      _buildProgressSlider(),
                                      const SizedBox(height: 8),
                                      // controls: rewind, play/pause, forward, mute
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
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
                                                if (_controller!
                                                    .value.isPlaying)
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
                                              setState(
                                                  () => _isMuted = !_isMuted);
                                              try {
                                                await _controller?.setVolume(
                                                    _isMuted ? 0.0 : 1.0);
                                              } catch (_) {}
                                            },
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 8),
                                      // Black info bar: type (left) + title (left)
                                      Container(
                                        width: double.infinity,
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 12, vertical: 8),
                                        decoration: BoxDecoration(
                                            color: Colors.black45,
                                            borderRadius:
                                                BorderRadius.circular(8)),
                                        child: Row(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.center,
                                          children: [
                                            Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      horizontal: 8,
                                                      vertical: 4),
                                              decoration: BoxDecoration(
                                                  color: Colors.black38,
                                                  borderRadius:
                                                      BorderRadius.circular(8)),
                                              child: Text(
                                                  isVideo ? 'VÍDEO' : 'ÁUDIO',
                                                  style: const TextStyle(
                                                      color: Colors.white,
                                                      fontSize: 12)),
                                            ),
                                            const SizedBox(width: 12),
                                            Expanded(
                                              child: Text(title,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                  style: const TextStyle(
                                                      color: Colors.white,
                                                      fontSize: 16,
                                                      fontWeight:
                                                          FontWeight.bold)),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                            ],
                          ),
                        );
                      },
                    ),

                    // bottom loader when fetching next page
                    if (_isLoadingMore)
                      Positioned(
                        bottom: MediaQuery.of(context).padding.bottom + 24,
                        left: 0,
                        right: 0,
                        child: Center(
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.black45,
                              borderRadius: BorderRadius.circular(24),
                            ),
                            child: const SizedBox(
                              height: 24,
                              width: 24,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          ),
                        ),
                      ),
                  ],
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
