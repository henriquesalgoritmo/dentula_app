import 'dart:async';

import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:flutter/foundation.dart';

class HlsPlayerScreen extends StatefulWidget {
  static const String routeName = '/hls_player';
  final String url;

  const HlsPlayerScreen({Key? key, this.url = ''}) : super(key: key);

  @override
  State<HlsPlayerScreen> createState() => _HlsPlayerScreenState();
}

class _HlsPlayerScreenState extends State<HlsPlayerScreen> {
  late VideoPlayerController _controller;
  final String demoUrl =
      'http://localhost:8000/api/hls/YFHaT1mWqwB1Lmr8XajnkqOWr0YincjhHsUN5U2w/playlist.m3u8';
  bool _isBuffering = false;

  void _onControllerUpdate() {
    if (!mounted) return;
    final value = _controller.value;
    final buffering = value.isBuffering ?? false;
    if (buffering != _isBuffering) {
      setState(() => _isBuffering = buffering);
    } else {
      // update UI for position changes
      setState(() {});
    }
  }

  @override
  void initState() {
    super.initState();
    final toLoad = widget.url.isNotEmpty ? widget.url : demoUrl;

    // Log whether we're using an HLS (m3u8) URL and current platform
    final isHls =
        toLoad.toLowerCase().endsWith('.m3u8') || toLoad.contains('/hls/');
    debugPrint(
        'HLS Player: isHls=$isHls url=$toLoad platform=${kIsWeb ? 'web' : 'native'}');
    if (kIsWeb && isHls) {
      debugPrint('HLS on web: ensure hls.js is included in web/index.html');
    }

    _controller = VideoPlayerController.network(toLoad)
      ..initialize().then((_) {
        // listen for updates (buffering/position)
        try {
          _controller.addListener(_onControllerUpdate);
        } catch (_) {}
        setState(() {});
        _controller.setLooping(true);
        _controller.play();
      });
  }

  @override
  void dispose() {
    try {
      _controller.removeListener(_onControllerUpdate);
    } catch (_) {}
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(title: const Text('HLS Player (demo)')),
      body: Center(
        child: _controller.value.isInitialized
            ? Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AspectRatio(
                    aspectRatio: _controller.value.aspectRatio,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        VideoPlayer(_controller),
                        if (_isBuffering)
                          const Center(
                            child: CircularProgressIndicator(),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 6,
                    child: LayoutBuilder(builder: (context, constraints) {
                      final width = constraints.maxWidth;
                      final durMs = _controller.value.duration.inMilliseconds;
                      final dur = durMs > 0 ? durMs : 1;
                      final posMs = _controller.value.position.inMilliseconds
                          .clamp(0, dur);

                      // Base background
                      final children = <Widget>[];
                      children.add(Container(color: Colors.white12));

                      // Draw each buffered range as a separate segment
                      for (final range in _controller.value.buffered) {
                        final start = range.start.inMilliseconds.clamp(0, dur);
                        final end = range.end.inMilliseconds.clamp(0, dur);
                        final left = start / dur * width;
                        final segWidth = (end - start) / dur * width;
                        if (segWidth > 0) {
                          children.add(Positioned(
                            left: left,
                            width: segWidth,
                            top: 0,
                            bottom: 0,
                            child: Container(color: Colors.white38),
                          ));
                        }
                      }

                      // Played portion (red)
                      final playedWidth = posMs / dur * width;
                      children.add(Positioned(
                        left: 0,
                        width: playedWidth,
                        top: 0,
                        bottom: 0,
                        child: Container(color: Colors.red),
                      ));

                      return Stack(children: children);
                    }),
                  ),
                ],
              )
            : const CircularProgressIndicator(),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          setState(() {
            _controller.value.isPlaying
                ? _controller.pause()
                : _controller.play();
          });
        },
        child:
            Icon(_controller.value.isPlaying ? Icons.pause : Icons.play_arrow),
      ),
    );
  }
}
