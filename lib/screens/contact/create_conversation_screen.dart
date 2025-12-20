import 'dart:convert';
import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';

import '../../api_config.dart';
import '../../providers/auth_provider.dart';

class CreateConversationScreen extends StatefulWidget {
  const CreateConversationScreen({Key? key}) : super(key: key);

  @override
  State<CreateConversationScreen> createState() =>
      _CreateConversationScreenState();
}

class _CreateConversationScreenState extends State<CreateConversationScreen> {
  final _formKey = GlobalKey<FormState>();
  String title = '';
  String description = '';
  String initialMessage = '';
  List<XFile> attachments = [];
  bool sending = false;

  Future<Map<String, String>> _authHeaders() async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final token = auth.token;
    final headers = <String, String>{'Accept': 'application/json'};
    if (token != null && token.isNotEmpty)
      headers['Authorization'] = 'Bearer $token';
    return headers;
  }

  Future<void> pickFiles() async {
    final files = await openFiles(acceptedTypeGroups: [
      XTypeGroup(label: 'files', extensions: ['jpg', 'png', 'jpeg', 'pdf'])
    ]);
    if (files.isNotEmpty) {
      setState(() => attachments.addAll(files));
    }
  }

  Future<void> submit() async {
    if (!_formKey.currentState!.validate()) return;
    _formKey.currentState!.save();
    setState(() => sending = true);
    try {
      final base = getApiBaseUrl();
      final uri = Uri.parse('${base}conversations');
      final headers = await _authHeaders();

      final request = http.MultipartRequest('POST', uri);
      request.headers.addAll(headers);
      request.fields['title'] = title;
      request.fields['description'] = description;
      request.fields['message'] = initialMessage;

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
        final id = body['id'];
        if (mounted) Navigator.of(context).pop(id);
      } else {
        if (mounted)
          ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Erro: ${resp.statusCode}')));
      }
    } catch (e) {
      debugPrint('create conv error: $e');
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Erro ao criar conversa')));
    } finally {
      if (mounted) setState(() => sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 800),
        child: Scaffold(
          appBar: AppBar(title: const Text('Nova Conversa')),
          body: Padding(
            padding: const EdgeInsets.all(12.0),
            child: Form(
              key: _formKey,
              child: Column(
                children: [
                  TextFormField(
                    decoration: const InputDecoration(labelText: 'Título'),
                    validator: (v) => v == null || v.trim().isEmpty
                        ? 'Título requerido'
                        : null,
                    onSaved: (v) => title = v!.trim(),
                  ),
                  TextFormField(
                    decoration: const InputDecoration(
                        labelText: 'Descrição (opcional)'),
                    onSaved: (v) => description = v?.trim() ?? '',
                  ),
                  TextFormField(
                    decoration: const InputDecoration(
                        labelText: 'Mensagem inicial (opcional)'),
                    onSaved: (v) => initialMessage = v?.trim() ?? '',
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: attachments
                        .map((a) => Chip(
                            label: Text(a.name),
                            onDeleted: () =>
                                setState(() => attachments.remove(a))))
                        .toList(),
                  ),
                  LayoutBuilder(builder: (context, constraints) {
                    final maxW = constraints.maxWidth.isFinite
                        ? constraints.maxWidth
                        : MediaQuery.of(context).size.width;
                    // reserve ~120 for the icon button and spacing
                    final buttonWidth = (maxW - 120).clamp(80.0, maxW);
                    return Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                                minimumSize: const Size(100, 40)),
                            onPressed: pickFiles,
                            icon: const Icon(Icons.attach_file),
                            label: const Text('Anexar')),
                        const SizedBox(width: 8),
                        SizedBox(
                          width: buttonWidth,
                          child: ElevatedButton(
                            onPressed: sending ? null : submit,
                            child: sending
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Text('Criar'),
                          ),
                        ),
                      ],
                    );
                  })
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
