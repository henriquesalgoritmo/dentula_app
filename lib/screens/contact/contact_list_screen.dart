import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';

import '../../api_config.dart';
import '../../providers/auth_provider.dart';
import 'chat_screen.dart';
import 'create_conversation_screen.dart';

class ContactListScreen extends StatefulWidget {
  const ContactListScreen({Key? key}) : super(key: key);

  static const String routeName = '/contacts';

  @override
  State<ContactListScreen> createState() => _ContactListScreenState();
}

class _ContactListScreenState extends State<ContactListScreen> {
  bool loading = false;
  List<dynamic> conversations = [];

  @override
  void initState() {
    super.initState();
    fetchConversations();
  }

  Future<Map<String, String>> _authHeaders() async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final token = auth.token;
    final headers = <String, String>{'Accept': 'application/json'};
    if (token != null && token.isNotEmpty)
      headers['Authorization'] = 'Bearer $token';
    return headers;
  }

  Future<void> fetchConversations() async {
    setState(() => loading = true);
    try {
      final base = getApiBaseUrl();
      final uri = Uri.parse('${base}conversations');
      final headers = await _authHeaders();
      final resp = await http
          .get(uri, headers: headers)
          .timeout(const Duration(seconds: 20));
      if (resp.statusCode == 200) {
        final body = jsonDecode(resp.body);
        setState(() => conversations = body is List ? body : []);
      } else {
        debugPrint(
            'conversations fetch status: ${resp.statusCode} ${resp.body}');
      }
    } catch (e) {
      debugPrint('fetchConversations error: $e');
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  void _openConversation(dynamic conv) {
    Navigator.of(context)
        .push(MaterialPageRoute(
            builder: (_) => ChatScreen(conversationId: conv['id'])))
        .then((_) => fetchConversations());
  }

  void _createConversation() async {
    final res = await Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const CreateConversationScreen()));
    if (res is int) {
      // open newly created conversation
      Navigator.of(context)
          .push(MaterialPageRoute(
              builder: (_) => ChatScreen(conversationId: res)))
          .then((_) => fetchConversations());
    } else {
      fetchConversations();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Contactos')),
      floatingActionButton: FloatingActionButton(
        onPressed: _createConversation,
        child: const Icon(Icons.add_comment),
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : conversations.isEmpty
              ? const Center(child: Text('Sem conversas'))
              : ListView.separated(
                  itemCount: conversations.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, i) {
                    final c = conversations[i];
                    final unread = c['unread_count'] ?? 0;
                    final last =
                        (c['messages'] != null && c['messages'].isNotEmpty)
                            ? c['messages'][0]
                            : null;
                    return ListTile(
                      title: Text(c['title'] ?? 'Sem título'),
                      subtitle: Text(c['description'] ?? ''),
                      trailing: unread > 0
                          ? CircleAvatar(
                              radius: 12,
                              backgroundColor: Colors.red,
                              child: Text('$unread',
                                  style: const TextStyle(
                                      color: Colors.white, fontSize: 12)))
                          : (last != null
                              ? Text(last['created_at']?.toString() ?? '')
                              : null),
                      onTap: () => _openConversation(c),
                    );
                  },
                ),
    );
  }
}
