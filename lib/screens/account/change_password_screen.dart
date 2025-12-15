import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;

import '../../api_config.dart';
import '../../providers/auth_provider.dart';
import '../../utils/logging.dart' as logging;

class ChangePasswordScreen extends StatefulWidget {
  const ChangePasswordScreen({Key? key}) : super(key: key);

  @override
  State<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _current = TextEditingController();
  final TextEditingController _new = TextEditingController();
  final TextEditingController _confirm = TextEditingController();
  bool loading = false;

  @override
  void dispose() {
    _current.dispose();
    _new.dispose();
    _confirm.dispose();
    super.dispose();
  }

  String _extractErrorMessage(http.Response? resp, [String fallback = 'Erro']) {
    if (resp == null) return fallback;
    try {
      final decoded = utf8.decode(resp.bodyBytes, allowMalformed: true);
      final parsed = jsonDecode(decoded);
      if (parsed is Map) {
        if (parsed['message'] != null) return parsed['message'].toString();
        if (parsed['errors'] != null) {
          final errors = parsed['errors'];
          if (errors is Map) {
            for (final v in errors.values) {
              if (v is List && v.isNotEmpty) return v.first.toString();
              if (v is String && v.isNotEmpty) return v;
            }
          }
        }
      }
      if (parsed is String && parsed.isNotEmpty) return parsed;
      if (decoded.isNotEmpty) return decoded;
    } catch (_) {}
    try {
      final fallbackBody = utf8.decode(resp.bodyBytes, allowMalformed: true);
      if (fallbackBody.isNotEmpty) return fallbackBody;
    } catch (_) {}
    return fallback;
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => loading = true);
    try {
      final auth = Provider.of<AuthProvider>(context, listen: false);
      final headers = await (() async {
        final token = auth.token;
        final h = <String, String>{'Accept': 'application/json'};
        if (token != null && token.isNotEmpty)
          h['Authorization'] = 'Bearer $token';
        return h;
      })();

      final uri = Uri.parse('${getApiBaseUrl()}user');
      final body = {
        'password': _new.text.trim(),
        'password_confirmation': _confirm.text.trim(),
        'current_password': _current.text.trim(),
      };

      final resp = await http.put(uri,
          headers: {...headers, 'Content-Type': 'application/json'},
          body: jsonEncode(body));

      logging.logResponse('account.change_password', resp);

      if (resp.statusCode == 200) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Senha alterada com sucesso')));
          Navigator.of(context).pop();
        }
        return;
      }

      final msg = _extractErrorMessage(resp, 'Erro ao alterar senha');
      if (mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(msg)));
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Erro ao alterar senha')));
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Alterar Senha')),
      body: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              TextFormField(
                controller: _current,
                decoration: const InputDecoration(labelText: 'Senha atual'),
                obscureText: true,
                validator: (v) =>
                    (v == null || v.isEmpty) ? 'Obrigatório' : null,
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _new,
                decoration: const InputDecoration(labelText: 'Nova senha'),
                obscureText: true,
                validator: (v) =>
                    (v == null || v.length < 6) ? 'Senha muito curta' : null,
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _confirm,
                decoration:
                    const InputDecoration(labelText: 'Confirmar nova senha'),
                obscureText: true,
                validator: (v) => (v == null || v != _new.text)
                    ? 'Confirmação não corresponde'
                    : null,
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: loading ? null : _submit,
                child: loading
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : const Text('Alterar senha'),
              )
            ],
          ),
        ),
      ),
    );
  }
}
