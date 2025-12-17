import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;

import '../../api_config.dart';
import 'change_password_screen.dart';
import '../../providers/auth_provider.dart';
import '../../utils/logging.dart' as logging;

class AccountScreen extends StatefulWidget {
  const AccountScreen({Key? key}) : super(key: key);

  @override
  State<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends State<AccountScreen> {
  final _formKey = GlobalKey<FormState>();
  bool loading = false;

  final TextEditingController _nameCtrl = TextEditingController();
  final TextEditingController _emailCtrl = TextEditingController();
  final TextEditingController _telefoneCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final user = auth.user;
    if (user != null) {
      _nameCtrl.text = (user['name'] ?? '').toString();
      _emailCtrl.text = (user['email'] ?? '').toString();
      _telefoneCtrl.text = (user['telefone'] ?? '').toString();
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _telefoneCtrl.dispose();

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
      // Enviar apenas o campo `name` para limitar a alteração no backend
      final body = {
        'name': _nameCtrl.text.trim(),
      };
      // Password changes are handled on a separate screen

      final resp = await http.put(uri,
          headers: {...headers, 'Content-Type': 'application/json'},
          body: jsonEncode(body));

      logging.logResponse('account.update', resp);

      if (resp.statusCode == 200) {
        final user = jsonDecode(resp.body);
        await auth.updateUser(user);
        if (mounted)
          ScaffoldMessenger.of(context)
              .showSnackBar(const SnackBar(content: Text('Perfil atualizado')));
      } else {
        final msg = _extractErrorMessage(resp, 'Erro ao atualizar');
        if (mounted)
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text(msg)));
      }
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Erro ao atualizar')));
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('My Account')),
      body: Padding(
        padding: const EdgeInsets.all(12.0),
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextFormField(
                  controller: _nameCtrl,
                  decoration: const InputDecoration(labelText: 'Nome'),
                  validator: (v) =>
                      (v == null || v.isEmpty) ? 'Obrigatório' : null,
                ),
                // Campos desativados: permitir apenas alterar o nome por enquanto
                // const SizedBox(height: 8),
                // TextFormField(
                //   controller: _emailCtrl,
                //   decoration: const InputDecoration(labelText: 'Email'),
                //   validator: (v) =>
                //       (v == null || v.isEmpty) ? 'Obrigatório' : null,
                // ),
                // const SizedBox(height: 8),
                // TextFormField(
                //   controller: _telefoneCtrl,
                //   decoration: const InputDecoration(labelText: 'Telefone'),
                // ),
                const SizedBox(height: 12),
                const SizedBox(height: 8),
                ElevatedButton(
                  onPressed: loading ? null : _submit,
                  child: loading
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : const Text('Salvar'),
                ),
                const SizedBox(height: 12),
                OutlinedButton(
                  onPressed: () {
                    Navigator.of(context).push(MaterialPageRoute(
                        builder: (_) => const ChangePasswordScreen()));
                  },
                  child: const Text('Alterar senha'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
