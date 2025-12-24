import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';

import '../../api_config.dart';
import '../../providers/auth_provider.dart';
import '../init_screen.dart';

class CoordenadaScreen extends StatefulWidget {
  const CoordenadaScreen({super.key});

  static String routeName = "/coordenada";

  @override
  State<CoordenadaScreen> createState() => _CoordenadaScreenState();
}

class _CoordenadaScreenState extends State<CoordenadaScreen> {
  int page = 1;
  int perPage = 10;
  bool loading = false;
  List<dynamic> items = [];
  int total = 0;

  @override
  void initState() {
    super.initState();
    fetchData();
  }

  Future<Map<String, String>> _authHeaders() async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final token = auth.token;
    final headers = <String, String>{'Accept': 'application/json'};
    if (token != null && token.isNotEmpty)
      headers['Authorization'] = 'Bearer $token';
    return headers;
  }

  Future<void> fetchData() async {
    setState(() => loading = true);
    try {
      final base = getApiBaseUrl();
      final uri =
          Uri.parse('${base}coordenadaBancaria').replace(queryParameters: {
        'page': page.toString(),
        'per_page': perPage.toString(),
      });
      final headers = await _authHeaders();
      final resp = await http.get(uri, headers: headers);
      if (resp.statusCode == 200) {
        final body = jsonDecode(resp.body);
        setState(() {
          items = body['data'] ?? [];
          total = body['total'] ?? items.length;
        });
      }
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Erro ao carregar coordenadas')));
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Coordenadas Bancárias',
                    style:
                        TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                const SizedBox.shrink(),
              ],
            ),
            const SizedBox(height: 12),
            Expanded(
              child: loading
                  ? const Center(child: CircularProgressIndicator())
                  : RefreshIndicator(
                      onRefresh: fetchData,
                      child: ListView.separated(
                        itemCount: items.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (context, index) {
                          final item = items[index];
                          return ListTile(
                            leading: const Icon(
                                Icons.account_balance_wallet_outlined),
                            title:
                                Text(item['nome'] ?? item['designacao'] ?? '-'),
                            subtitle: Text(
                                '${item['beneficiario'] ?? '-'}\nIBAN: ${item['iban'] ?? '-'}'),
                            isThreeLine: true,
                            onTap: () {
                              // Navigator.of(context).push(MaterialPageRoute(
                              //     builder: (_) => const InitScreen()));
                            },
                          );
                        },
                      ),
                    ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                TextButton(
                  onPressed: page > 1
                      ? () => setState(() {
                            page--;
                            fetchData();
                          })
                      : null,
                  child: const Text('Anterior'),
                ),
                Text('$page'),
                TextButton(
                  onPressed: items.length == perPage
                      ? () => setState(() {
                            page++;
                            fetchData();
                          })
                      : null,
                  child: const Text('Próximo'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
