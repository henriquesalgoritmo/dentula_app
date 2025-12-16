import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';

import '../../api_config.dart';
import '../../helper/keyboard.dart';

class VerificationScreen extends StatefulWidget {
  final String identifier; // email or phone

  const VerificationScreen({Key? key, required this.identifier})
      : super(key: key);

  @override
  State<VerificationScreen> createState() => _VerificationScreenState();
}

class _VerificationScreenState extends State<VerificationScreen> {
  final _codeCtrl = TextEditingController();
  bool loading = false;

  @override
  void dispose() {
    _codeCtrl.dispose();
    super.dispose();
  }

  Future<void> _logout() async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    await auth.logout();
    if (mounted) Navigator.pushReplacementNamed(context, '/sign_in');
  }

  Future<void> _confirmLogout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirmar saída'),
        content: const Text('Deseja realmente encerrar a sessão?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Sair'),
          ),
        ],
      ),
    );

    if (confirmed == true) await _logout();
  }

  Future<void> _verify() async {
    if (_codeCtrl.text.trim().isEmpty) return;
    setState(() => loading = true);
    final uri = Uri.parse('${getApiBaseUrl()}verify-account');
    try {
      final payload = {
        'email_or_telefone': widget.identifier,
        'code': _codeCtrl.text.trim(),
      };
      debugPrint('VERIFY sending to $uri payload: ${jsonEncode(payload)}');
      final resp = await http.post(uri,
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode(payload));

      if (resp.statusCode == 200) {
        // refresh user from API when logged in
        try {
          final auth = Provider.of<AuthProvider>(context, listen: false);
          if (auth.isLoggedIn && auth.token != null) {
            final userResp = await http.get(Uri.parse('${getApiBaseUrl()}user'), headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer ${auth.token}'
            });
            if (userResp.statusCode == 200) {
              final ubody = jsonDecode(userResp.body);
              if (ubody is Map) {
                await auth.updateUser(ubody as Map<String, dynamic>);
              }
            }
          }
        } catch (_) {}

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Conta verificada com sucesso')));
          Navigator.of(context).pushReplacementNamed('/');
        }
        return;
      }

      final body = resp.body.isNotEmpty ? jsonDecode(resp.body) : {};
      debugPrint('VERIFY response status: ${resp.statusCode}');
      debugPrint('VERIFY response body: ${resp.body}');
      String msg = 'Erro ao verificar';
      if (body is Map) {
        final first = body.values.first;
        if (first is List && first.isNotEmpty) msg = first.first.toString();
        if (body['message'] != null) msg = body['message'].toString();
      }
      if (mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(msg)));
    } catch (e) {
      debugPrint('VERIFY exception: $e');
      if (mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Erro: $e')));
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> _resend() async {
    setState(() => loading = true);
    final uri = Uri.parse('${getApiBaseUrl()}resend-verification');
    try {
      final resp = await http.post(uri,
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'email_or_telefone': widget.identifier}));
      if (resp.statusCode == 200) {
        if (mounted)
          ScaffoldMessenger.of(context)
              .showSnackBar(const SnackBar(content: Text('Código reenviado')));
        return;
      }
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Erro ao reenviar código: ${resp.statusCode}')));
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Erro: $e')));
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  void _changeContact() {
    Navigator.of(context).push(MaterialPageRoute(
        builder: (_) =>
            ChangeContactScreen(initialIdentifier: widget.identifier)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Verificar Conta'),
        actions: [
          IconButton(
            tooltip: 'Logout',
            icon: const Icon(Icons.logout),
            onPressed: loading ? null : _confirmLogout,
          )
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Enviámos um código para: ${widget.identifier}'),
            const SizedBox(height: 12),
            TextField(
              controller: _codeCtrl,
              decoration:
                  const InputDecoration(labelText: 'Código de verificação'),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 12),
            ElevatedButton(
                onPressed: loading ? null : _verify,
                child: const Text('Verificar')),
            const SizedBox(height: 8),
            TextButton(
                onPressed: loading ? null : _resend,
                child: const Text('Reenviar código')),
            const SizedBox(height: 8),
            TextButton(
                onPressed: _changeContact,
                child: const Text('Alterar email/telefone')),
          ],
        ),
      ),
    );
  }
}

// Simple ChangeContactScreen used by VerificationScreen (kept here to avoid extra imports)
class ChangeContactScreen extends StatefulWidget {
  final String initialIdentifier;
  const ChangeContactScreen({Key? key, required this.initialIdentifier})
      : super(key: key);

  @override
  State<ChangeContactScreen> createState() => _ChangeContactScreenState();
}

class _ChangeContactScreenState extends State<ChangeContactScreen> {
  final _emailCtrl = TextEditingController();
  final _telefoneCtrl = TextEditingController();
  bool loading = false;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _telefoneCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if ((_emailCtrl.text.trim().isEmpty) && (_telefoneCtrl.text.trim().isEmpty))
      return;
    setState(() => loading = true);
    final uri = Uri.parse('${getApiBaseUrl()}change-contact');
    try {
      final resp = await http.post(uri,
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'email_or_telefone': widget.initialIdentifier,
            'email':
                _emailCtrl.text.trim().isEmpty ? null : _emailCtrl.text.trim(),
            'telefone': _telefoneCtrl.text.trim().isEmpty
                ? null
                : _telefoneCtrl.text.trim(),
          }));
      if (resp.statusCode == 200) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text('Contato atualizado e código reenviado')));
          Navigator.of(context).pop(); // back to verification screen
        }
        return;
      }
      final body = resp.body.isNotEmpty ? jsonDecode(resp.body) : {};
      String msg = 'Erro ao atualizar contato';
      if (body is Map) {
        final first = body.values.first;
        if (first is List && first.isNotEmpty) msg = first.first.toString();
        if (body['message'] != null) msg = body['message'].toString();
      }
      if (mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(msg)));
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Erro: $e')));
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Alterar contato')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Text('Conta identificada por: ${widget.initialIdentifier}'),
            const SizedBox(height: 12),
            TextField(
                controller: _emailCtrl,
                decoration: const InputDecoration(labelText: 'Novo email')),
            const SizedBox(height: 8),
            TextField(
                controller: _telefoneCtrl,
                decoration: const InputDecoration(labelText: 'Novo telefone')),
            const SizedBox(height: 12),
            ElevatedButton(
                onPressed: loading ? null : _submit,
                child: const Text('Atualizar contato')),
          ],
        ),
      ),
    );
  }
}
