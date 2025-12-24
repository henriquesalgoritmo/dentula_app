import 'dart:convert';
import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import 'package:provider/provider.dart';
import 'package:pdfx/pdfx.dart';
import 'package:video_player/video_player.dart';
import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

import '../../api_config.dart';
import '../../providers/auth_provider.dart';

class ChatScreen extends StatefulWidget {
  final int conversationId;
  const ChatScreen({Key? key, required this.conversationId}) : super(key: key);

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  List<dynamic> messages = [];
  bool loading = false;
  final _controller = TextEditingController();
  List<XFile> attachments = [];
  static const int _maxFileBytes = 30 * 1024 * 1024; // 30 MB

  Future<Map<String, String>> _authHeaders() async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final token = auth.token;
    final headers = <String, String>{'Accept': 'application/json'};
    if (token != null && token.isNotEmpty)
      headers['Authorization'] = 'Bearer $token';
    return headers;
  }

  @override
  void initState() {
    super.initState();
    fetchMessages();
  }

  Future<void> fetchMessages() async {
    setState(() => loading = true);
    try {
      final base = getApiBaseUrl();
      final uri =
          Uri.parse('${base}conversations/${widget.conversationId}/messages');
      final headers = await _authHeaders();
      final resp = await http
          .get(uri, headers: headers)
          .timeout(const Duration(seconds: 20));
      if (resp.statusCode == 200) {
        final body = jsonDecode(resp.body);
        setState(() => messages = body is List ? body : []);
        _markAsRead();
      }
    } catch (e) {
      debugPrint('fetch messages error: $e');
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> _markAsRead() async {
    try {
      final base = getApiBaseUrl();
      final uri =
          Uri.parse('${base}conversations/${widget.conversationId}/mark-read');
      final headers = await _authHeaders();
      await http
          .post(uri, headers: headers)
          .timeout(const Duration(seconds: 10));
    } catch (e) {
      debugPrint('markAsRead error: $e');
    }
  }

  Future<void> pickFiles() async {
    final files = await openFiles(acceptedTypeGroups: [
      XTypeGroup(label: 'files', extensions: ['jpg', 'png', 'jpeg', 'pdf'])
    ]);
    if (files.isEmpty) return;
    final accepted = <XFile>[];
    final rejected = <String>[];
    for (var f in files) {
      try {
        int size = 0;
        if (!kIsWeb && f.path.isNotEmpty) {
          size = await File(f.path).length();
        } else {
          final bytes = await f.readAsBytes();
          size = bytes.length;
        }
        if (size <= _maxFileBytes)
          accepted.add(f);
        else
          rejected.add(f.name);
      } catch (e) {
        rejected.add(f.name);
      }
    }
    if (accepted.isNotEmpty) setState(() => attachments.addAll(accepted));
    if (rejected.isNotEmpty && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(
              'Ficheiros maiores que 30MB foram ignorados: ${rejected.join(', ')}')));
    }
  }

  Future<void> sendMessage() async {
    final text = _controller.text.trim();
    if (text.isEmpty && attachments.isEmpty) return;
    try {
      final base = getApiBaseUrl();
      final uri =
          Uri.parse('${base}conversations/${widget.conversationId}/messages');
      final headers = await _authHeaders();

      final request = http.MultipartRequest('POST', uri);
      request.headers.addAll(headers);
      if (text.isNotEmpty) request.fields['content'] = text;

      // validate attachments sizes again before sending
      for (var f in attachments) {
        int size = 0;
        if (!kIsWeb && f.path.isNotEmpty) {
          try {
            size = await File(f.path).length();
          } catch (_) {
            // fallback to readAsBytes
            final bytes = await f.readAsBytes();
            size = bytes.length;
          }
        } else {
          final bytes = await f.readAsBytes();
          size = bytes.length;
        }
        if (size > _maxFileBytes) {
          if (mounted)
            ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Um ou mais ficheiros excedem 30MB.')));
          return;
        }
      }

      for (var f in attachments) {
        if (!kIsWeb && f.path.isNotEmpty) {
          request.files
              .add(await http.MultipartFile.fromPath('attachments[]', f.path));
        } else {
          final bytes = await f.readAsBytes();
          request.files.add(http.MultipartFile.fromBytes('attachments[]', bytes,
              filename: f.name));
        }
      }

      final streamed =
          await request.send().timeout(const Duration(seconds: 60));
      final resp = await http.Response.fromStream(streamed);
      if (resp.statusCode == 201 || resp.statusCode == 200) {
        final body = jsonDecode(resp.body);
        setState(() {
          messages.add(body);
          _controller.clear();
          attachments.clear();
        });
      } else {
        debugPrint('send message error ${resp.statusCode} ${resp.body}');
      }
    } catch (e) {
      debugPrint('sendMessage exception: $e');
    }
  }

  Widget _buildMessage(dynamic msg) {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final myId = auth.user?['id'];
    final isMine = (msg['user'] != null && msg['user']['id'] == myId) ||
        (msg['user_id'] == myId);
    final attachments = msg['attachments'] as List<dynamic>?;
    return Align(
      alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
            color: isMine ? Colors.blue : Colors.grey.shade200,
            borderRadius: BorderRadius.circular(12)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (msg['content'] != null && msg['content'].toString().isNotEmpty)
              Text(msg['content'],
                  style:
                      TextStyle(color: isMine ? Colors.white : Colors.black)),
            if (attachments != null && attachments.isNotEmpty)
              ...attachments.map((a) {
                return Padding(
                    padding: const EdgeInsets.only(top: 6.0),
                    child: _attachmentWidget(a, isMine));
              }).toList(),
            const SizedBox(height: 6),
            Text(
              formatDate(
                  msg['created_at'] ?? msg['createdAt'] ?? msg['created']),
              style: TextStyle(
                  fontSize: 11,
                  color: isMine ? Colors.white70 : Colors.black54),
            )
          ],
        ),
      ),
    );
  }

  Widget _attachmentWidget(dynamic att, bool isMine) {
    String path = '';
    String name = '';
    if (att is String) {
      path = att;
      name = att.split('/').last;
    } else if (att is Map) {
      path = att['path'] ?? '';
      name = att['name'] ??
          (att['path'] != null ? att['path'].split('/').last : 'Anexo');
    }

    if (path.isEmpty) return const SizedBox.shrink();

    final base = getApiBaseUrl();
    final cleanBase =
        base.endsWith('/') ? base.substring(0, base.length - 1) : base;
    final cleanPath = path.startsWith('/') ? path.substring(1) : path;
    final url = '$cleanBase/proxy-image/$cleanPath';

    final lower = name.toLowerCase();
    if (lower.endsWith('.jpg') ||
        lower.endsWith('.jpeg') ||
        lower.endsWith('.png') ||
        lower.endsWith('.webp') ||
        lower.endsWith('.gif')) {
      return GestureDetector(
          onTap: () => _showImageModal(url, name),
          child: Image.network(url, width: 160, height: 90, fit: BoxFit.cover));
    }
    if (lower.endsWith('.mp4') ||
        lower.endsWith('.webm') ||
        lower.endsWith('.mov') ||
        lower.endsWith('.m4v')) {
      return InkWell(
        onTap: () => Navigator.of(context).push(MaterialPageRoute(
            fullscreenDialog: true,
            builder: (_) => _VideoFullScreenPage(url: url, name: name))),
        child: Container(
          width: 160,
          height: 90,
          color: Colors.black12,
          child: Stack(
            alignment: Alignment.center,
            children: [
              const Icon(Icons.videocam, size: 40, color: Colors.black45),
              Positioned(
                  bottom: 6,
                  left: 6,
                  right: 6,
                  child: Text(name,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 12)))
            ],
          ),
        ),
      );
    }
    if (lower.endsWith('.mp3') ||
        lower.endsWith('.wav') ||
        lower.endsWith('.ogg') ||
        lower.endsWith('.m4a')) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          color: isMine ? Colors.blue.shade700 : Colors.white,
          borderRadius: BorderRadius.circular(8),
        ),
        child: AudioInlineWidget(url: url, name: name, isMine: isMine),
      );
    }
    if (lower.endsWith('.pdf')) {
      return InkWell(
        onTap: () => _openPdfInApp(url),
        child: Row(children: [
          const Icon(Icons.picture_as_pdf, color: Colors.red),
          const SizedBox(width: 8),
          Flexible(
              child: Text(name,
                  overflow: TextOverflow.ellipsis,
                  style:
                      TextStyle(color: isMine ? Colors.white70 : Colors.blue)))
        ]),
      );
    }
    return InkWell(
        onTap: () => _openUrl(url),
        child: Text(name,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: isMine ? Colors.white70 : Colors.blue)));
  }

  Future<void> _openUrl(String urlStr) async {
    try {
      final uri = Uri.parse(urlStr);
      if (!await launchUrl(uri, mode: LaunchMode.inAppWebView)) {
        debugPrint('Could not launch $urlStr');
      }
    } catch (e) {
      debugPrint('open url error: $e');
    }
  }

  Future<void> _openPdfInApp(String urlStr) async {
    try {
      Navigator.of(context).push(MaterialPageRoute(
          fullscreenDialog: true,
          builder: (_) => _PdfFullScreenPage(url: urlStr)));
    } catch (e) {
      debugPrint('open pdf error: $e');
    }
  }

  void _showImageModal(String url, String name) {
    Navigator.of(context).push(MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => _ImageFullScreenPage(url: url, name: name)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Conversa #${widget.conversationId}')),
      body: Column(
        children: [
          Expanded(
            child: loading
                ? const Center(child: CircularProgressIndicator())
                : ListView.builder(
                    padding: const EdgeInsets.all(8),
                    itemCount: messages.length,
                    itemBuilder: (c, i) => _buildMessage(messages[i]),
                  ),
          ),
          if (attachments.isNotEmpty)
            SizedBox(
              height: 60,
              child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: attachments
                      .map((a) => Chip(label: Text(a.name)))
                      .toList()),
            ),
          Row(
            children: [
              IconButton(
                  onPressed: pickFiles, icon: const Icon(Icons.attach_file)),
              Expanded(
                  child: TextField(
                      controller: _controller,
                      decoration: const InputDecoration(
                          hintText: 'Escreva uma mensagem'))),
              IconButton(onPressed: sendMessage, icon: const Icon(Icons.send)),
            ],
          )
        ],
      ),
    );
  }
}

Future<void> _downloadFileToDevice(
    BuildContext context, String url, String filename) async {
  try {
    if (kIsWeb) {
      await launchUrl(Uri.parse(url));
      return;
    }
    final resp =
        await http.get(Uri.parse(url)).timeout(const Duration(seconds: 30));
    if (resp.statusCode == 200) {
      final bytes = resp.bodyBytes;
      final dir = await getApplicationDocumentsDirectory();
      final file = File(p.join(dir.path, filename));
      await file.writeAsBytes(bytes);
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Salvo em ${file.path}')));
      }
    } else {
      if (context.mounted)
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Falha ao baixar: HTTP ${resp.statusCode}')));
    }
  } catch (e) {
    if (context.mounted)
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Erro ao baixar: $e')));
  }
}

class _ImageFullScreenPage extends StatelessWidget {
  final String url;
  final String name;
  const _ImageFullScreenPage({Key? key, required this.url, required this.name})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(name),
        actions: [
          IconButton(
              onPressed: () => _downloadFileToDevice(context, url, name),
              icon: const Icon(Icons.download)),
          IconButton(
              onPressed: () => Navigator.of(context).pop(),
              icon: const Icon(Icons.close))
        ],
      ),
      body: Center(
          child: InteractiveViewer(
              child: Image.network(url, fit: BoxFit.contain))),
    );
  }
}

class _VideoFullScreenPage extends StatefulWidget {
  final String url;
  final String name;
  const _VideoFullScreenPage({Key? key, required this.url, required this.name})
      : super(key: key);

  @override
  State<_VideoFullScreenPage> createState() => _VideoFullScreenPageState();
}

class _VideoFullScreenPageState extends State<_VideoFullScreenPage> {
  late VideoPlayerController _controller;
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.network(widget.url)
      ..initialize().then((_) {
        setState(() => _initialized = true);
        _controller.play();
      });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.name), actions: [
        IconButton(
            onPressed: () =>
                _downloadFileToDevice(context, widget.url, widget.name),
            icon: const Icon(Icons.download)),
        IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.close))
      ]),
      body: Center(
        child: _initialized
            ? AspectRatio(
                aspectRatio: _controller.value.aspectRatio,
                child: VideoPlayer(_controller))
            : const CircularProgressIndicator(),
      ),
      floatingActionButton: _initialized
          ? FloatingActionButton(
              onPressed: () => setState(() => _controller.value.isPlaying
                  ? _controller.pause()
                  : _controller.play()),
              child: Icon(
                  _controller.value.isPlaying ? Icons.pause : Icons.play_arrow),
            )
          : null,
    );
  }
}

class AudioInlineWidget extends StatefulWidget {
  final String url;
  final String name;
  final bool isMine;
  const AudioInlineWidget(
      {Key? key, required this.url, required this.name, required this.isMine})
      : super(key: key);

  @override
  State<AudioInlineWidget> createState() => _AudioInlineWidgetState();
}

class _AudioInlineWidgetState extends State<AudioInlineWidget> {
  late AudioPlayer _player;
  bool _loading = true;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;

  @override
  void initState() {
    super.initState();
    _player = AudioPlayer();
    _init();
  }

  Future<void> _init() async {
    try {
      await _player.setUrl(widget.url);
      _duration = _player.duration ?? Duration.zero;
      _player.positionStream.listen((p) {
        setState(() => _position = p);
      });
    } catch (e) {
      debugPrint('audio inline load error: $e');
    }
    if (mounted) setState(() => _loading = false);
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  String _format(Duration d) {
    final mm = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final ss = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$mm:$ss';
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        StreamBuilder<PlayerState>(
          stream: _player.playerStateStream,
          builder: (context, snapshot) {
            final playing = snapshot.data?.playing ?? false;
            return IconButton(
              icon: Icon(playing ? Icons.pause : Icons.play_arrow),
              onPressed: _loading
                  ? null
                  : () => playing ? _player.pause() : _player.play(),
            );
          },
        ),
        SizedBox(
          width: 120,
          child: StreamBuilder<Duration?>(
            stream: _player.durationStream,
            builder: (context, snapDur) {
              final dur = snapDur.data ?? Duration.zero;
              return StreamBuilder<Duration>(
                stream: _player.positionStream,
                builder: (context, snapPos) {
                  final pos = snapPos.data ?? Duration.zero;
                  final progress = dur.inMilliseconds > 0
                      ? pos.inMilliseconds / dur.inMilliseconds
                      : 0.0;
                  return LinearProgressIndicator(value: progress);
                },
              );
            },
          ),
        ),
        const SizedBox(width: 8),
        StreamBuilder<Duration?>(
          stream: _player.positionStream,
          builder: (context, snap) {
            final pos = snap.data ?? Duration.zero;
            return Text(_format(pos),
                style: TextStyle(
                    color: widget.isMine ? Colors.white70 : Colors.black87));
          },
        ),
      ],
    );
  }
}

String formatDate(String? iso) {
  if (iso == null) return '';
  try {
    final dt = DateTime.parse(iso).toLocal();
    return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  } catch (_) {
    return iso;
  }
}

class _AudioFullScreenPage extends StatefulWidget {
  final String url;
  final String name;
  const _AudioFullScreenPage({Key? key, required this.url, required this.name})
      : super(key: key);

  @override
  State<_AudioFullScreenPage> createState() => _AudioFullScreenPageState();
}

class _AudioFullScreenPageState extends State<_AudioFullScreenPage> {
  late AudioPlayer _player;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _player = AudioPlayer();
    _init();
  }

  Future<void> _init() async {
    try {
      await _player.setUrl(widget.url);
    } catch (e) {
      debugPrint('audio load error: $e');
    }
    if (mounted) setState(() => _loading = false);
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.name), actions: [
        IconButton(
            onPressed: () =>
                _downloadFileToDevice(context, widget.url, widget.name),
            icon: const Icon(Icons.download)),
        IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.close))
      ]),
      body: Center(
        child: _loading
            ? const CircularProgressIndicator()
            : Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  StreamBuilder<PlayerState>(
                      stream: _player.playerStateStream,
                      builder: (context, snapshot) {
                        final playing = snapshot.data?.playing ?? false;
                        return IconButton(
                            iconSize: 64,
                            icon: Icon(playing
                                ? Icons.pause_circle
                                : Icons.play_circle),
                            onPressed: () =>
                                playing ? _player.pause() : _player.play());
                      }),
                  StreamBuilder<Duration?>(
                      stream: _player.durationStream,
                      builder: (context, snap) => SizedBox.shrink()),
                ],
              ),
      ),
    );
  }
}

class _PdfFullScreenPage extends StatefulWidget {
  final String url;
  const _PdfFullScreenPage({Key? key, required this.url}) : super(key: key);

  @override
  State<_PdfFullScreenPage> createState() => _PdfFullScreenPageState();
}

class _PdfFullScreenPageState extends State<_PdfFullScreenPage> {
  PdfControllerPinch? _pdfController;
  bool _loadingPdf = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadPdf();
  }

  Future<void> _loadPdf() async {
    try {
      final resp = await http
          .get(Uri.parse(widget.url))
          .timeout(const Duration(seconds: 30));
      if (resp.statusCode == 200) {
        final bytes = resp.bodyBytes;
        final doc = await PdfDocument.openData(bytes);
        _pdfController = PdfControllerPinch(document: Future.value(doc));
      } else {
        _error = 'Falha ao carregar PDF: HTTP ${resp.statusCode}';
      }
    } catch (e) {
      _error = 'Erro ao carregar PDF: $e';
    }
    if (mounted) setState(() => _loadingPdf = false);
  }

  @override
  void dispose() {
    _pdfController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final filename =
        Uri.tryParse(widget.url)?.pathSegments.last ?? 'document.pdf';
    return Scaffold(
      appBar: AppBar(title: const Text('PDF'), actions: [
        IconButton(
            onPressed: () =>
                _downloadFileToDevice(context, widget.url, filename),
            icon: const Icon(Icons.download)),
        IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.close))
      ]),
      body: _loadingPdf
          ? const Center(child: CircularProgressIndicator())
          : (_error != null
              ? Center(child: Text(_error!))
              : PdfViewPinch(controller: _pdfController!)),
    );
  }
}
