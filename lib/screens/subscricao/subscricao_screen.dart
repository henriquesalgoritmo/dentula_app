import 'dart:convert';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;
import 'package:file_selector/file_selector.dart';
import 'package:photo_view/photo_view.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:video_player/video_player.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:path/path.dart' as p;
import 'package:shop_app/utils/file_io_web.dart'
    if (dart.library.io) 'package:shop_app/utils/file_io_io.dart' as file_io;

import '../../api_config.dart';
import '../../providers/auth_provider.dart';
import 'components/subscricao_card.dart';

class SubscricaoScreen extends StatefulWidget {
  const SubscricaoScreen({super.key});

  static String routeName = "/subscricao";

  @override
  State<SubscricaoScreen> createState() => _SubscricaoScreenState();
}

class _SubscricaoScreenState extends State<SubscricaoScreen> {
  int page = 1;
  int perPage = 10;
  String search = '';
  bool loading = false;
  List<dynamic> items = [];
  int total = 0;

  // form state
  bool formLoading = false;
  List<XFile> selectedFiles = [];

  // lists
  List<dynamic> pacotes = [];
  List<dynamic> clientes = [];
  List<dynamic> bancos = [];

  // verification mode
  bool verificar = false;
  Map<String, dynamic> form = {
    'id': null,
    'user_id': null,
    'pacote_id': null,
    'comprovante_pagamento_subscricao': [],
    'motivoAnulacaoOrRejeicao': ''
  };
  // inline preview state per comprovante
  final Map<int, bool> _showPreview = {};
  final Map<int, double> _previewZoom = {};
  final Map<int, bool> _expanded = {};
  // controllers per comprovante to avoid recreating controllers in build
  final Map<int, TextEditingController> _dateControllers = {};
  final Map<int, TextEditingController> _valorControllers = {};
  final Map<int, TextEditingController> _numTransControllers = {};

  @override
  void initState() {
    super.initState();
    fetchData();
    fetchPacotes();
    fetchClientes();
    fetchBancos();
  }

  Future<Map<String, String>> _authHeaders() async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final token = auth.token;
    final headers = <String, String>{'Accept': 'application/json'};
    if (token != null && token.isNotEmpty) {
      headers['Authorization'] = 'Bearer $token';
    }
    return headers;
  }

  Future<void> fetchData() async {
    setState(() => loading = true);
    try {
      final base = getApiBaseUrl();
      final uri = Uri.parse('${base}subscricao').replace(queryParameters: {
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
          total = body['total'] ?? items.length;
        });
      } else {
        if (mounted)
          ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Erro ao buscar subscrições')));
      }
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Erro ao carregar dados')));
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> editItem(Map<String, dynamic> item) async {
    // populate verification form and show detailed view
    setState(() {
      verificar = true;
      form['id'] = item['id'];
      form['user_id'] = item['user_id'];
      form['pacote_id'] = item['pacote_id'];
      form['comprovante_pagamento_subscricao'] =
          item['comprovante_pagamento_subscricao'] ?? [];
      form['motivoAnulacaoOrRejeicao'] = '';
      // also copy services and price for display
      form['servicos'] = item['servicos'] ?? [];
      form['preco'] = item['preco'] ?? item['preco']?.toString() ?? '';
      // initialize per-comprovante preview state
      final comps = form['comprovante_pagamento_subscricao'] as List<dynamic>;
      // clear any previous controllers
      _dateControllers.values.forEach((c) => c.dispose());
      _valorControllers.values.forEach((c) => c.dispose());
      _numTransControllers.values.forEach((c) => c.dispose());
      _dateControllers.clear();
      _valorControllers.clear();
      _numTransControllers.clear();

      for (var i = 0; i < comps.length; i++) {
        final c = comps[i] as Map<String, dynamic>;
        _showPreview[i] = false;
        _previewZoom[i] = 1.0;
        // init controllers
        final dateIso = c['data_movimento']?.toString() ?? '';
        _dateControllers[i] =
            TextEditingController(text: _formatDisplayDate(dateIso));
        final rawValor = c['valor']?.toString() ?? '';
        try {
          final v = rawValor.replaceAll(',', '.');
          final d = double.tryParse(v);
          _valorControllers[i] = TextEditingController(
              text: d != null
                  ? NumberFormat('#,##0.00', 'pt_BR').format(d)
                  : rawValor);
        } catch (_) {
          _valorControllers[i] = TextEditingController(text: rawValor);
        }
        _numTransControllers[i] = TextEditingController(
            text: c['numero_transaccao']?.toString() ?? '');
      }
    });
  }

  Future<void> deleteItem(dynamic item) async {
    final ok = await showDialog<bool>(
        context: context,
        builder: (c) => AlertDialog(
              title: const Text('Tem certeza?'),
              content:
                  Text('Deseja excluir ${item['designacao'] ?? item['id']}?'),
              actions: [
                TextButton(
                    onPressed: () => Navigator.of(c).pop(false),
                    child: const Text('Cancelar')),
                ConstrainedBox(
                  constraints:
                      const BoxConstraints(minWidth: 80, maxWidth: 160),
                  child: ElevatedButton(
                      onPressed: () => Navigator.of(c).pop(true),
                      child: const Text('Excluir')),
                )
              ],
            ));
    if (ok != true) return;
    try {
      final base = getApiBaseUrl();
      final uri = Uri.parse('${base}subscricao/${item['id']}');
      final headers = await _authHeaders();
      final resp = await http.delete(uri, headers: headers);
      if (resp.statusCode == 200) {
        if (mounted)
          ScaffoldMessenger.of(context)
              .showSnackBar(const SnackBar(content: Text('Excluído')));
        await fetchData();
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

  Future<void> submitValidacao(int operacao) async {
    // operacao: 1-aprovar,2-rejeitar,3-anular,4-retornar
    try {
      final base = getApiBaseUrl();
      final uri = Uri.parse('${base}validacaoSubscricao/${form['id']}');
      final headers = await _authHeaders();
      final body = {...form, 'operacao': operacao};
      final resp = await http.put(uri,
          headers: {...headers, 'Content-Type': 'application/json'},
          body: jsonEncode(body));
      if (resp.statusCode == 200) {
        if (mounted)
          ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Operação realizada')));
        setState(() => verificar = false);
        await fetchData();
      } else {
        if (mounted)
          ScaffoldMessenger.of(context)
              .showSnackBar(const SnackBar(content: Text('Erro na operação')));
      }
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Erro na operação')));
    }
  }

  Future<void> openForm() async {
    final formKey = GlobalKey<FormState>();
    final formData = <String, dynamic>{
      'cliente_id': null,
      'pacote_id': null,
      'preco': '',
    };

    selectedFiles = [];

    await showDialog(
      context: context,
      builder: (dialogCtx) {
        return AlertDialog(
          title: const Text('Nova Subscrição'),
          content: StatefulBuilder(builder: (context, setStateDialog) {
            return SizedBox(
              width: double.maxFinite,
              child: SingleChildScrollView(
                child: Form(
                  key: formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      DropdownButtonFormField<int>(
                        value: formData['cliente_id'] != null
                            ? int.tryParse(formData['cliente_id'].toString())
                            : null,
                        items: clientes.map<DropdownMenuItem<int>>((c) {
                          final id = c['id'] is int
                              ? c['id'] as int
                              : int.parse(c['id'].toString());
                          final label = c['name'] ?? c['nome'] ?? id.toString();
                          return DropdownMenuItem(
                              value: id, child: Text(label));
                        }).toList(),
                        decoration: const InputDecoration(labelText: 'Cliente'),
                        onChanged: (v) =>
                            setStateDialog(() => formData['cliente_id'] = v),
                        validator: (v) => v == null ? 'Obrigatório' : null,
                      ),
                      const SizedBox(height: 8),
                      DropdownButtonFormField<int>(
                        value: formData['pacote_id'] != null
                            ? int.tryParse(formData['pacote_id'].toString())
                            : null,
                        items: pacotes.map<DropdownMenuItem<int>>((p) {
                          final id = p['id'] is int
                              ? p['id'] as int
                              : int.parse(p['id'].toString());
                          final label =
                              p['designacao'] ?? p['name'] ?? id.toString();
                          return DropdownMenuItem(
                              value: id, child: Text(label));
                        }).toList(),
                        decoration: const InputDecoration(labelText: 'Pacote'),
                        onChanged: (v) =>
                            setStateDialog(() => formData['pacote_id'] = v),
                        validator: (v) => v == null ? 'Obrigatório' : null,
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        initialValue: formData['preco'],
                        decoration: const InputDecoration(labelText: 'Preço'),
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                        onSaved: (v) => formData['preco'] = v ?? '',
                      ),
                      const SizedBox(height: 8),
                      ElevatedButton.icon(
                        icon: const Icon(Icons.attach_file),
                        label: const Text('Selecionar comprovantes'),
                        onPressed: () async {
                          try {
                            final result = await openFiles();
                            if (result.isNotEmpty) {
                              setStateDialog(() {
                                selectedFiles = result;
                              });
                            }
                          } catch (e) {
                            // ignore
                          }
                        },
                      ),
                      const SizedBox(height: 8),
                      if (selectedFiles.isNotEmpty)
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: selectedFiles.map((f) {
                            return Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(child: Text(f.name)),
                                IconButton(
                                  icon: const Icon(Icons.delete_outline),
                                  onPressed: () => setStateDialog(() {
                                    selectedFiles.remove(f);
                                  }),
                                )
                              ],
                            );
                          }).toList(),
                        ),
                    ],
                  ),
                ),
              ),
            );
          }),
          actions: [
            TextButton(
                onPressed: () => Navigator.of(dialogCtx).pop(),
                child: const Text('Cancelar')),
            ConstrainedBox(
              constraints: const BoxConstraints(minWidth: 80, maxWidth: 200),
              child: ElevatedButton(
                onPressed: () async {
                  if (!formKey.currentState!.validate()) return;
                  formKey.currentState!.save();
                  setState(() => formLoading = true);
                  try {
                    final base = getApiBaseUrl();
                    final uri = Uri.parse('${base}subscricao');
                    final headers = await _authHeaders();

                    final request = http.MultipartRequest('POST', uri);
                    request.headers.addAll(headers);
                    request.fields['user_id'] =
                        (formData['cliente_id'] ?? '').toString();
                    request.fields['pacote_id'] =
                        (formData['pacote_id'] ?? '').toString();
                    request.fields['preco'] =
                        (formData['preco'] ?? '').toString();

                    for (final file in selectedFiles) {
                      try {
                        if (kIsWeb) {
                          final bytes = await file.readAsBytes();
                          request.files.add(http.MultipartFile.fromBytes(
                              'comprovantes[]', bytes,
                              filename: file.name));
                        } else {
                          request.files.add(await http.MultipartFile.fromPath(
                              'comprovantes[]', file.path,
                              filename: file.name));
                        }
                      } catch (_) {}
                    }

                    final streamed = await request.send();
                    final resp = await http.Response.fromStream(streamed);
                    if (resp.statusCode == 200 || resp.statusCode == 201) {
                      if (mounted)
                        ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Subscrição criada')));
                      Navigator.of(dialogCtx).pop();
                      await fetchData();
                    } else {
                      if (mounted)
                        ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                                content: Text('Erro ao criar subscrição')));
                    }
                  } catch (e) {
                    if (mounted)
                      ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Erro ao enviar')));
                  } finally {
                    if (mounted) setState(() => formLoading = false);
                  }
                },
                child: formLoading
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : const Text('Salvar'),
              ),
            )
          ],
        );
      },
    );
  }

  // Placeholder loaders for auxiliary lists. Replace with real API calls as needed.
  Future<void> fetchPacotes() async {
    try {
      final base = getApiBaseUrl();
      final uri = Uri.parse('${base}pacote');
      final headers = await _authHeaders();
      final resp = await http.get(uri, headers: headers);
      if (resp.statusCode == 200) {
        final body = jsonDecode(resp.body);
        setState(() => pacotes = body['data'] ?? (body is List ? body : []));
      } else {
        setState(() => pacotes = []);
      }
    } catch (_) {
      setState(() => pacotes = []);
    }
  }

  Future<void> fetchClientes() async {
    try {
      final base = getApiBaseUrl();
      final uri = Uri.parse('${base}clientes').replace(queryParameters: {
        'per_page': '100000',
      });
      final headers = await _authHeaders();
      final resp = await http.get(uri, headers: headers);
      if (resp.statusCode == 200) {
        final body = jsonDecode(resp.body);
        setState(() => clientes = body['data'] ?? (body is List ? body : []));
      } else {
        setState(() => clientes = []);
      }
    } catch (_) {
      setState(() => clientes = []);
    }
  }

  Future<void> fetchBancos() async {
    try {
      final base = getApiBaseUrl();
      final uri =
          Uri.parse('${base}coordenadaBancaria').replace(queryParameters: {
        'per_page': '100000',
      });
      final headers = await _authHeaders();
      final resp = await http.get(uri, headers: headers);
      if (resp.statusCode == 200) {
        final body = jsonDecode(resp.body);
        setState(() => bancos = body['data'] ?? (body is List ? body : []));
      } else {
        setState(() => bancos = []);
      }
    } catch (_) {
      setState(() => bancos = []);
    }
  }

  Widget _buildList() {
    if (loading) return const Center(child: CircularProgressIndicator());
    if (items.isEmpty) return const Center(child: Text('Sem subscrições'));
    return RefreshIndicator(
      onRefresh: fetchData,
      child: ListView.builder(
        padding: const EdgeInsets.only(bottom: 88),
        itemCount: items.length,
        itemBuilder: (c, i) {
          final it = items[i];
          final pacote = it['pacote'] ?? {};
          final statusStr = () {
            try {
              final cps = it['comprovante_pagamento_subscricao'];
              if (cps != null && cps is List && cps.isNotEmpty) {
                final sp = cps[0]['status_pagamento'];
                if (sp != null && sp is Map && sp['designacao'] != null)
                  return sp['designacao'].toString();
              }
            } catch (_) {}
            return '-';
          }();

          return SubscricaoCard(
            id: it['id'],
            designacao: it['designacao'] ?? '',
            cliente: it['user']?['name'] ?? '-',
            pacoteInfo:
                '${pacote['designacao'] ?? '-'}, Preço: ${it['preco'] ?? '-'} AKZ',
            status: statusStr,
            onTap: () => editItem(it),
            onDelete: () => deleteItem(it),
          );
        },
      ),
    );
  }

  Future<void> _previewFile(String path) async {
    if (path.isEmpty) return;
    final url = _buildFileUrl(path);
    String cacheBusted(String u) {
      final ts = DateTime.now().millisecondsSinceEpoch;
      if (u.contains('?')) return '$u&_t=$ts';
      return '$u?_t=$ts';
    }

    final ext = path.split('.').last.toLowerCase();

    if (['jpg', 'jpeg', 'png', 'gif', 'webp'].contains(ext)) {
      // image preview with zoom
      await showDialog(
        context: context,
        builder: (c) => Dialog(
          child: SizedBox(
            width: MediaQuery.of(context).size.width * 0.9,
            height: MediaQuery.of(context).size.height * 0.8,
            child: PhotoView(
              imageProvider: NetworkImage(cacheBusted(url)),
            ),
          ),
        ),
      );
      return;
    }

    if (['mp4', 'webm', 'ogg'].contains(ext)) {
      // try in-app video player
      await showDialog(
        context: context,
        builder: (c) => _VideoPreviewDialog(url: url),
      );
      return;
    }

    if (ext == 'pdf') {
      // show embedded PDF viewer using Syncfusion with download/cache controls
      final filename = p.basename(path);
      final cached = await file_io.existsFile(filename);
      String? localPath;
      if (cached && !kIsWeb) {
        // obtain the absolute local path
        localPath = await file_io.getLocalFilePath(filename);
      }

      await showDialog(
        context: context,
        builder: (d) => StatefulBuilder(builder: (context, setStateDialog) {
          String? local = localPath;
          bool isCached = cached;
          return Dialog(
            insetPadding: const EdgeInsets.all(12),
            child: SizedBox(
              width: MediaQuery.of(context).size.width * 0.9,
              height: MediaQuery.of(context).size.height * 0.9,
              child: Column(
                children: [
                  Material(
                    color: Theme.of(context).scaffoldBackgroundColor,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () => Navigator.of(d).pop(),
                        ),
                        Row(children: [
                          IconButton(
                            icon:
                                Icon(isCached ? Icons.refresh : Icons.download),
                            tooltip: isCached ? 'Recarregar' : 'Descarregar',
                            onPressed: () async {
                              try {
                                final resp =
                                    await http.get(Uri.parse(cacheBusted(url)));
                                if (resp.statusCode == 200) {
                                  final saved = await file_io.saveFileBytes(
                                      filename, resp.bodyBytes);
                                  local = saved;
                                  isCached = true;
                                  setStateDialog(() {});
                                  if (mounted)
                                    ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                            content: Text('Guardado: $saved')));
                                } else {
                                  if (mounted)
                                    ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(
                                            content:
                                                Text('Erro ao descarregar')));
                                }
                              } catch (e) {
                                if (mounted)
                                  ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                          content:
                                              Text('Erro ao descarregar')));
                              }
                            },
                          ),
                          IconButton(
                            icon: const Icon(Icons.open_in_new),
                            tooltip: 'Abrir externamente',
                            onPressed: () async {
                              final uri = Uri.parse(cacheBusted(url));
                              if (await canLaunchUrl(uri))
                                await launchUrl(uri,
                                    mode: LaunchMode.externalApplication);
                            },
                          ),
                        ])
                      ],
                    ),
                  ),
                  Expanded(
                    child: file_io.buildPdfViewer(
                        localPath: local, url: cacheBusted(url)),
                  )
                ],
              ),
            ),
          );
        }),
      );
      return;
    }

    // fallback: open url externally
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) await launchUrl(uri);
  }

  // Build file URL matching backend expected format (id/extension)
  String _buildFileUrl(String path) {
    if (path.isEmpty) return '';
    final parts = path.split('.');
    if (parts.length < 2) return '${getApiBaseUrl()}file/$path';
    final ext = parts.removeLast();
    final idPart = parts.join('.');
    return '${getApiBaseUrl()}file/$idPart/$ext';
  }

  String _formatDisplayDate(String? iso) {
    if (iso == null || iso.isEmpty) return '';
    try {
      final d = DateTime.parse(iso);
      return DateFormat('dd/MM/yyyy').format(d);
    } catch (_) {
      return iso;
    }
  }

  String _cacheBustedUrl(String u) {
    if (u.isEmpty) return u;
    final ts = DateTime.now().millisecondsSinceEpoch;
    return u.contains('?') ? '$u&_t=$ts' : '$u?_t=$ts';
  }

  Widget _buildVerifier() {
    final comprovantes =
        (form['comprovante_pagamento_subscricao'] as List<dynamic>?) ?? [];
    return SingleChildScrollView(
      padding: const EdgeInsets.all(12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text('Subscrição #${form['id']}',
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        // Display cliente and pacote info (read-only)
        Builder(builder: (context) {
          final cliente = clientes.firstWhere((c) => c['id'] == form['user_id'],
              orElse: () => null);
          final pacoteObj = pacotes.firstWhere(
              (p) => p['id'] == form['pacote_id'],
              orElse: () => null);
          final preco =
              form['preco'] ?? (pacoteObj != null ? pacoteObj['preco'] : '');
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                  'Cliente: ${cliente != null ? (cliente['name'] ?? '-') : '-'}'),
              const SizedBox(height: 6),
              Text(
                  'Pacote: ${pacoteObj != null ? (pacoteObj['designacao'] ?? '-') : (form['pacote_id'] ?? '-')}'),
              const SizedBox(height: 6),
              Text('Preço: ${preco ?? ''} AKZ'),
              const SizedBox(height: 8),
              const Text('Serviços do pacote',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              if (form['servicos'] != null &&
                  (form['servicos'] as List).isNotEmpty)
                Wrap(
                  spacing: 8,
                  children: (form['servicos'] as List).map<Widget>((s) {
                    final label = s is Map
                        ? (s['designacao'] ?? s.toString())
                        : s.toString();
                    return Chip(label: Text(label));
                  }).toList(),
                )
              else
                const Text('-'),
              const SizedBox(height: 8),
              const Text('Comprovantes',
                  style: TextStyle(fontWeight: FontWeight.bold)),
            ],
          );
        }),
        const SizedBox(height: 8),
        ExpansionPanelList(
          expansionCallback: (panelIndex, isExpanded) => setState(() {
            _expanded[panelIndex] = !isExpanded;
          }),
          children: comprovantes.asMap().entries.map((entry) {
            final idx = entry.key;
            final c = entry.value as Map<String, dynamic>;
            final path = (c['path'] ?? '').toString();
            final url = _buildFileUrl(path);

            return ExpansionPanel(
              canTapOnHeader: true,
              headerBuilder: (context, isExpanded) {
                return ListTile(
                  title: Text('Comprovante ${idx + 1}'),
                  trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                    IconButton(
                      icon: const Icon(Icons.remove_red_eye),
                      onPressed: () => setState(() {
                        final newVal = !(_showPreview[idx] ?? false);
                        _showPreview[idx] = newVal;
                        if (newVal) _expanded[idx] = true;
                      }),
                    ),
                    IconButton(
                      icon: const Icon(Icons.open_in_new),
                      onPressed: () async => await _previewFile(path),
                    ),
                  ]),
                );
              },
              body: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Data with date picker
                    GestureDetector(
                      onTap: () async {
                        DateTime? initial;
                        try {
                          if (c['data_movimento'] != null &&
                              c['data_movimento'].toString().isNotEmpty) {
                            initial =
                                DateTime.parse(c['data_movimento'].toString());
                          }
                        } catch (_) {}
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: initial ?? DateTime.now(),
                          firstDate: DateTime(2000),
                          lastDate: DateTime(2100),
                        );
                        if (picked != null)
                          setState(() => c['data_movimento'] =
                              picked.toIso8601String().split('T').first);
                      },
                      child: AbsorbPointer(
                        child: TextFormField(
                          controller: TextEditingController(
                              text: _formatDisplayDate(
                                  c['data_movimento']?.toString() ?? '')),
                          decoration: const InputDecoration(labelText: 'Data'),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    // Valor with numeric formatting/validation
                    TextFormField(
                      initialValue: c['valor']?.toString() ?? '',
                      decoration: const InputDecoration(labelText: 'Valor'),
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'[0-9\.,]'))
                      ],
                      onChanged: (v) {
                        final normalized = v.replaceAll(',', '.');
                        c['valor'] = normalized;
                      },
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<int>(
                      value: c['coordenadas_bancaria_id'] != null
                          ? int.tryParse(
                              c['coordenadas_bancaria_id'].toString())
                          : null,
                      items: bancos.map<DropdownMenuItem<int>>((b) {
                        final id = b['id'] is int
                            ? b['id'] as int
                            : int.parse(b['id'].toString());
                        final label = b['nome'] ?? b['name'] ?? id.toString();
                        return DropdownMenuItem(value: id, child: Text(label));
                      }).toList(),
                      decoration: const InputDecoration(labelText: 'Banco'),
                      onChanged: (v) =>
                          setState(() => c['coordenadas_bancaria_id'] = v),
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      initialValue: c['numero_transaccao']?.toString() ?? '',
                      decoration:
                          const InputDecoration(labelText: 'Nº Transação'),
                      onChanged: (v) => c['numero_transaccao'] = v,
                    ),
                    const SizedBox(height: 8),
                    if (_showPreview[idx] ?? false) ...[
                      const SizedBox(height: 8),
                      SizedBox(
                        height: 250,
                        child: Builder(builder: (context) {
                          final ext = path.split('.').last.toLowerCase();
                          if (['jpg', 'jpeg', 'png', 'gif', 'webp']
                              .contains(ext)) {
                            return Column(children: [
                              Expanded(
                                child: PhotoView(
                                  imageProvider:
                                      NetworkImage(_cacheBustedUrl(url)),
                                  loadingBuilder: (context, event) =>
                                      const Center(
                                          child: CircularProgressIndicator()),
                                ),
                              ),
                              Slider(
                                value:
                                    (_previewZoom[idx] ?? 1.0).clamp(0.5, 3.0),
                                min: 0.5,
                                max: 3.0,
                                onChanged: (v) =>
                                    setState(() => _previewZoom[idx] = v),
                              )
                            ]);
                          }
                          if (ext == 'pdf') {
                            return file_io.buildPdfViewer(
                                localPath: null, url: _cacheBustedUrl(url));
                          }
                          if (['mp4', 'webm', 'ogg'].contains(ext)) {
                            return Center(
                              child: ElevatedButton.icon(
                                icon: const Icon(Icons.play_circle_fill),
                                label: const Text('Reproduzir vídeo'),
                                onPressed: () => showDialog(
                                    context: context,
                                    builder: (_) => _VideoPreviewDialog(
                                        url: _cacheBustedUrl(url))),
                              ),
                            );
                          }
                          return Center(
                            child: ElevatedButton.icon(
                              icon: const Icon(Icons.open_in_new),
                              label: const Text('Abrir arquivo'),
                              onPressed: () async {
                                final uri = Uri.parse(_cacheBustedUrl(url));
                                if (await canLaunchUrl(uri))
                                  await launchUrl(uri,
                                      mode: LaunchMode.externalApplication);
                              },
                            ),
                          );
                        }),
                      )
                    ]
                  ],
                ),
              ),
              isExpanded: _expanded[idx] ?? false,
            );
          }).toList(),
        ),
        const SizedBox(height: 12),
        TextFormField(
          initialValue: form['motivoAnulacaoOrRejeicao'] ?? '',
          onChanged: (v) => form['motivoAnulacaoOrRejeicao'] = v,
          maxLines: 3,
          decoration: const InputDecoration(labelText: 'Motivo'),
        ),
        const SizedBox(height: 12),
        LayoutBuilder(builder: (context, constraints) {
          return Wrap(
            alignment: WrapAlignment.center,
            spacing: 8,
            runSpacing: 8,
            children: [
              ConstrainedBox(
                constraints: const BoxConstraints(minWidth: 80, maxWidth: 200),
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.check),
                  label: const Text('Aprovar'),
                  onPressed: () => submitValidacao(1),
                ),
              ),
              ConstrainedBox(
                constraints: const BoxConstraints(minWidth: 80, maxWidth: 200),
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.close),
                  label: const Text('Rejeitar'),
                  onPressed: () => submitValidacao(2),
                ),
              ),
              ConstrainedBox(
                constraints: const BoxConstraints(minWidth: 80, maxWidth: 200),
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.delete),
                  label: const Text('Anular'),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                  onPressed: () => submitValidacao(3),
                ),
              ),
              ConstrainedBox(
                constraints: const BoxConstraints(minWidth: 80, maxWidth: 200),
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.reply),
                  label: const Text('Retornar'),
                  onPressed: () => submitValidacao(4),
                ),
              ),
            ],
          );
        })
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Stack(children: [
          Column(children: [
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              const Text('Subscrições',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
              const SizedBox.shrink(),
            ]),
            const SizedBox(height: 12),
            TextField(
              decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.search),
                  hintText: 'Pesquisar designação'),
              onChanged: (v) {
                search = v;
                page = 1;
                fetchData();
              },
            ),
            const SizedBox(height: 8),
            Expanded(child: verificar ? _buildVerifier() : _buildList()),
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              TextButton(
                  onPressed: page > 1
                      ? () => setState(() {
                            page--;
                            fetchData();
                          })
                      : null,
                  child: const Text('Anterior')),
              Text('$page'),
              TextButton(
                  onPressed: items.length == perPage
                      ? () => setState(() {
                            page++;
                            fetchData();
                          })
                      : null,
                  child: const Text('Próximo')),
            ])
          ]),
          Positioned(
            right: 16,
            bottom: 16,
            child: FloatingActionButton(
              onPressed: () => openForm(),
              backgroundColor: Theme.of(context).primaryColor,
              child: const Icon(Icons.add),
            ),
          )
        ]),
      ),
    );
  }
}

// Small dialog widget that plays a network video using video_player
class _VideoPreviewDialog extends StatefulWidget {
  final String url;
  const _VideoPreviewDialog({required this.url, Key? key}) : super(key: key);

  @override
  State<_VideoPreviewDialog> createState() => _VideoPreviewDialogState();
}

class _VideoPreviewDialogState extends State<_VideoPreviewDialog> {
  late VideoPlayerController _controller;
  bool initialized = false;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.network(widget.url)
      ..initialize().then((_) {
        setState(() => initialized = true);
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
    return Dialog(
      child: SizedBox(
        width: MediaQuery.of(context).size.width * 0.9,
        height: MediaQuery.of(context).size.height * 0.6,
        child: Column(
          children: [
            Expanded(
              child: initialized
                  ? AspectRatio(
                      aspectRatio: _controller.value.aspectRatio,
                      child: VideoPlayer(_controller),
                    )
                  : const Center(child: CircularProgressIndicator()),
            ),
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              IconButton(
                icon: Icon(_controller.value.isPlaying
                    ? Icons.pause
                    : Icons.play_arrow),
                onPressed: () => setState(() {
                  if (_controller.value.isPlaying) {
                    _controller.pause();
                  } else {
                    _controller.play();
                  }
                }),
              ),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.of(context).pop(),
              )
            ])
          ],
        ),
      ),
    );
  }
}
