import 'dart:convert';
import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';

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
      }
    } catch (e) {
      debugPrint('fetch messages error: $e');
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> pickFiles() async {
    final files = await openFiles(acceptedTypeGroups: [
      XTypeGroup(label: 'files', extensions: ['jpg', 'png', 'jpeg', 'pdf'])
    ]);
    if (files.isNotEmpty) setState(() => attachments.addAll(files));
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
              ...attachments.map((a) => Padding(
                    padding: const EdgeInsets.only(top: 6.0),
                    child: GestureDetector(
                      onTap: () {
                        final url =
                            '${getApiBaseUrl()}proxy-image/${a.toString()}';
                        // open in browser on web or external
                      },
                      child: Text('Anexo: ${a.toString()}',
                          style: TextStyle(
                              color: isMine ? Colors.white70 : Colors.blue)),
                    ),
                  ))
          ],
        ),
      ),
    );
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
                children:
                    attachments.map((a) => Chip(label: Text(a.name))).toList(),
              ),
            ),
          Row(
            children: [
              IconButton(
                  onPressed: pickFiles, icon: const Icon(Icons.attach_file)),
              Expanded(
                child: TextField(
                    controller: _controller,
                    decoration: const InputDecoration(
                        hintText: 'Escreva uma mensagem')),
              ),
              IconButton(onPressed: sendMessage, icon: const Icon(Icons.send)),
            ],
          )
        ],
      ),
    );
  }
}
