import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

import '../../api_config.dart';
import '../../providers/auth_provider.dart';
import 'components/pacote_card.dart';
import '../init_screen.dart';
import '../subscricao/subscricao_screen.dart';

class PacoteScreen extends StatefulWidget {
  const PacoteScreen({super.key});

  static String routeName = "/pacote";

  @override
  State<PacoteScreen> createState() => _PacoteScreenState();
}

class _PacoteScreenState extends State<PacoteScreen> {
  int page = 1;
  int perPage = 10;
  String search = '';
  bool loading = false;
  List<dynamic> items = [];
  int total = 0;

  // For form
  bool formLoading = false;
  XFile? selectedFile;

  // Data for selects
  List<dynamic> statusList = [];
  List<dynamic> servicosList = [];

  @override
  void initState() {
    super.initState();
    fetchData();
    fetchStatus();
    fetchServicos();
  }

  Future<Map<String, String>> _authHeaders() async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final token = auth.token;
    final headers = <String, String>{
      'Accept': 'application/json',
    };
    if (token != null && token.isNotEmpty) {
      headers['Authorization'] = 'Bearer $token';
    }
    return headers;
  }

  Future<void> fetchData() async {
    setState(() => loading = true);
    try {
      final base = getApiBaseUrl();
      final uri = Uri.parse('${base}pacote').replace(queryParameters: {
        'page': page.toString(),
        'per_page': perPage.toString(),
        if (search.isNotEmpty) 'search': search,
      });
      final headers = await _authHeaders();
      final resp = await http.get(uri, headers: headers);
      if (resp.statusCode == 200) {
        final body = jsonDecode(resp.body);
        setState(() {
          items = body['data'] ?? [];
          total = body['total'] ?? (items.length);
        });
      } else {
        // ignore: avoid_print
        print('fetchData pacote status ${resp.statusCode} ${resp.body}');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Erro ao carregar pacotes')),
        );
      }
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> fetchStatus() async {
    try {
      final base = getApiBaseUrl();
      final uri = Uri.parse('${base}status');
      final headers = await _authHeaders();
      final resp = await http.get(uri, headers: headers);
      if (resp.statusCode == 200) {
        final body = jsonDecode(resp.body);
        setState(() => statusList = body is List ? body : []);
      }
    } catch (_) {}
  }

  Future<void> fetchServicos() async {
    try {
      final base = getApiBaseUrl();
      final uri = Uri.parse('${base}servico');
      final headers = await _authHeaders();
      final resp = await http.get(uri, headers: headers);
      if (resp.statusCode == 200) {
        final body = jsonDecode(resp.body);
        setState(() => servicosList = body['data'] ?? []);
      }
    } catch (_) {}
  }

  // (debug HEAD checks removed) keep only URL prints for debugging

  // File picking is done inline in the form using FilePicker

  Future<void> openForm({Map<String, dynamic>? pacote}) async {
    final formKey = GlobalKey<FormState>();
    final formData = <String, dynamic>{
      'id': pacote != null ? pacote['id'] : null,
      'designacao': pacote != null ? pacote['designacao'] ?? '' : '',
      'preco': pacote != null ? pacote['preco']?.toString() ?? '0' : '0',
      'diasDuracao':
          pacote != null ? pacote['diasDuracao']?.toString() ?? '0' : '0',
      'status_id':
          pacote != null ? pacote['status_id']?.toString() ?? '1' : '1',
      'descricao': pacote != null ? pacote['descricao'] ?? '' : '',
      'servicos': pacote != null
          ? (pacote['servicos'] ?? []).map((s) => s['id'].toString()).toList()
          : <String>[],
    };

    selectedFile = null;

    await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(pacote != null ? 'Editar Pacote' : 'Adicionar Pacote'),
          content: StatefulBuilder(builder: (context, setStateDialog) {
            return SizedBox(
              width: double.maxFinite,
              child: SingleChildScrollView(
                child: Form(
                  key: formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      TextFormField(
                        initialValue: formData['designacao'],
                        decoration:
                            const InputDecoration(labelText: 'Designação'),
                        onSaved: (v) => formData['designacao'] = v ?? '',
                        validator: (v) =>
                            (v == null || v.isEmpty) ? 'Obrigatório' : null,
                      ),
                      TextFormField(
                        initialValue: formData['preco'],
                        decoration: const InputDecoration(labelText: 'Preço'),
                        keyboardType: TextInputType.number,
                        onSaved: (v) => formData['preco'] = v ?? '0',
                      ),
                      TextFormField(
                        initialValue: formData['diasDuracao'],
                        decoration:
                            const InputDecoration(labelText: 'Duração (dias)'),
                        keyboardType: TextInputType.number,
                        onSaved: (v) => formData['diasDuracao'] = v ?? '0',
                      ),
                      const SizedBox(height: 8),
                      DropdownButtonFormField<String>(
                        value: formData['status_id']?.toString(),
                        items: statusList.map<DropdownMenuItem<String>>((s) {
                          final id = s['id'].toString();
                          final label = s['designacao'] ?? s['name'] ?? id;
                          return DropdownMenuItem(
                              value: id, child: Text(label));
                        }).toList(),
                        onChanged: (v) =>
                            setStateDialog(() => formData['status_id'] = v),
                        decoration: const InputDecoration(labelText: 'Estado'),
                      ),
                      const SizedBox(height: 8),
                      // Servicos multi-select simple
                      Wrap(
                        spacing: 8,
                        children: servicosList.map<Widget>((s) {
                          final sid = s['id'].toString();
                          final selected =
                              (formData['servicos'] as List).contains(sid);
                          return FilterChip(
                            selected: selected,
                            label: Text(s['designacao'] ?? sid),
                            onSelected: (val) {
                              setStateDialog(() {
                                if (val) {
                                  (formData['servicos'] as List).add(sid);
                                } else {
                                  (formData['servicos'] as List).remove(sid);
                                }
                              });
                            },
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        initialValue: formData['descricao'],
                        decoration:
                            const InputDecoration(labelText: 'Descrição'),
                        maxLines: 3,
                        onSaved: (v) => formData['descricao'] = v ?? '',
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          SizedBox(
                            width: 160,
                            child: ElevatedButton.icon(
                              onPressed: () async {
                                // Use file_selector openFile which works on web, mobile and desktop
                                final XFile? res = await openFile();
                                if (res != null) {
                                  setStateDialog(() => selectedFile = res);
                                }
                              },
                              icon: const Icon(Icons.upload_file),
                              label: const Text('Selecionar Capa'),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                              child: Text(selectedFile?.name ??
                                  'Nenhum arquivo selecionado')),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          }),
          actions: [
            TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Cancelar')),
            ConstrainedBox(
              constraints: const BoxConstraints(minWidth: 80, maxWidth: 160),
              child: ElevatedButton(
                onPressed: formLoading
                    ? null
                    : () async {
                        if (!formKey.currentState!.validate()) return;
                        formKey.currentState!.save();
                        await _submitForm(formData);
                        if (mounted) Navigator.of(context).pop();
                      },
                child: formLoading
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : Text(pacote != null ? 'Salvar' : 'Adicionar'),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _submitForm(Map<String, dynamic> formData) async {
    setState(() => formLoading = true);
    try {
      final base = getApiBaseUrl();
      final uri = formData['id'] != null
          ? Uri.parse('${base}pacote/${formData['id']}')
          : Uri.parse('${base}pacote');

      final headers = await _authHeaders();

      final request = http.MultipartRequest('POST', uri);
      request.headers.addAll(headers);
      if (formData['id'] != null) {
        request.fields['_method'] = 'PUT';
      }
      request.fields['designacao'] = formData['designacao'] ?? '';
      request.fields['preco'] = formData['preco']?.toString() ?? '0';
      request.fields['diasDuracao'] =
          formData['diasDuracao']?.toString() ?? '0';
      request.fields['status_id'] = formData['status_id']?.toString() ?? '1';
      request.fields['descricao'] = formData['descricao'] ?? '';
      // servicos as array (send as servicos[0], servicos[1], ...)
      final servicosListLocal = formData['servicos'] as List;
      for (var i = 0; i < servicosListLocal.length; i++) {
        request.fields['servicos[$i]'] = servicosListLocal[i].toString();
      }

      // Attach file: mobile Web/desktop use bytes or path accordingly
      if (selectedFile != null) {
        // If a path is available (mobile/desktop), use fromPath
        final path = selectedFile!.path;
        if (!kIsWeb && path.isNotEmpty) {
          // On mobile/desktop use file path
          request.files.add(await http.MultipartFile.fromPath('capa', path));
        } else {
          // On web (or when path is not available) read bytes
          final bytes = await selectedFile!.readAsBytes();
          request.files.add(http.MultipartFile.fromBytes(
            'capa',
            bytes,
            filename: selectedFile!.name,
          ));
        }
      }

      final streamed = await request.send();
      final resp = await http.Response.fromStream(streamed);
      if (resp.statusCode == 200 || resp.statusCode == 201) {
        if (mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(const SnackBar(content: Text('Salvo com sucesso')));
          await fetchData();
        }
      } else if (resp.statusCode == 422) {
        // validation errors
        final body = jsonDecode(resp.body);
        final errors = body['errors'] as Map<String, dynamic>?;
        if (errors != null) {
          errors.values.forEach((arr) {
            if (arr is List) {
              for (var m in arr) {
                if (mounted)
                  ScaffoldMessenger.of(context)
                      .showSnackBar(SnackBar(content: Text(m.toString())));
              }
            }
          });
        }
      } else {
        if (mounted)
          ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Erro: ${resp.statusCode}')));
      }
    } catch (e) {
      if (mounted) debugPrint('REGISTER status: ${e}');
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Erro ao salvar')));
    } finally {
      if (mounted) setState(() => formLoading = false);
    }
  }

  Future<void> deleteItem(dynamic item) async {
    final ok = await showDialog<bool>(
          context: context,
          builder: (c) => AlertDialog(
            title: const Text('Tem certeza?'),
            content: Text('Deseja excluir ${item['designacao']}?'),
            actions: [
              TextButton(
                  onPressed: () => Navigator.of(c).pop(false),
                  child: const Text('Cancelar')),
              ConstrainedBox(
                constraints: const BoxConstraints(minWidth: 80, maxWidth: 160),
                child: ElevatedButton(
                    onPressed: () => Navigator.of(c).pop(true),
                    child: const Text('Excluir')),
              ),
            ],
          ),
        ) ??
        false;

    if (!ok) return;

    try {
      final base = getApiBaseUrl();
      final uri = Uri.parse('${base}pacote/${item['id']}');
      final headers = await _authHeaders();
      final resp = await http.delete(uri, headers: headers);
      if (resp.statusCode == 200) {
        if (mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(const SnackBar(content: Text('Excluído')));
          await fetchData();
        }
      } else {
        if (mounted)
          ScaffoldMessenger.of(context)
              .showSnackBar(const SnackBar(content: Text('Erro ao excluir')));
      }
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Erro ao excluir')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Stack(
          children: [
            Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Pacotes',
                        style: TextStyle(
                            fontSize: 22, fontWeight: FontWeight.bold)),
                    const SizedBox.shrink(),
                  ],
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: loading
                      ? const Center(child: CircularProgressIndicator())
                      : RefreshIndicator(
                          onRefresh: fetchData,
                          child: ListView.builder(
                            itemCount: items.length,
                            itemBuilder: (context, index) {
                              final item = items[index];
                              final path = (item['path_capa'] ?? '').toString();
                              final imageUrl =
                                  path.isNotEmpty ? _proxyImageUrl(path) : null;
                              // Debug: print full image URL used by the app
                              debugPrint(
                                  'Pacote id=${item['id']} imageUrl=$imageUrl');
                              // only print the image URL for debugging
                              return PacoteCard(
                                id: item['id'],
                                designacao: item['designacao'] ?? '',
                                preco: item['preco'] ?? 0,
                                diasDuracao: item['diasDuracao'] ?? 0,
                                status: item['status']?['designacao'] ?? '-',
                                imageUrl: imageUrl,
                                onTap: () => Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) => InitScreen(
                                      initialIndex: 3,
                                      initialPacote: item,
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                ),
                // simple pagination controls
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

            // Floating add button removed per design
          ],
        ),
      ),
    );
  }
}

String _storageUrl(String path) {
  final base = getApiBaseUrl();
  // If base ends with /api/ remove the api/ so storage is served from root
  if (base.endsWith('/api/') || base.endsWith('api/')) {
    var server = base.replaceFirst(RegExp(r'api\/?$'), '');
    server = server.replaceAll(RegExp(r'\/$'), '');
    return '$server/storage/$path';
  }
  var root = base.replaceAll(RegExp(r'\/$'), '');
  return '$root/storage/$path';
}

String _proxyImageUrl(String path) {
  final base = getApiBaseUrl();
  var root = base.replaceAll(RegExp(r'\/$'), '');
  // base already contains the `/api` segment, so proxy endpoint is under api
  return '$root/proxy-image/$path';
}
