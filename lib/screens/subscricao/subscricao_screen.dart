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
import 'package:shop_app/utils/logging.dart' as logging;

import '../../api_config.dart';
import 'package:shop_app/screens/pdf_viewer/pdf_viewer_screen.dart';
import '../../providers/auth_provider.dart';
import 'components/subscricao_card.dart';

class SubscricaoScreen extends StatefulWidget {
  final Map<String, dynamic>? initialPacote;
  const SubscricaoScreen({super.key, this.initialPacote});

  static String routeName = "/subscricao";

  @override
  State<SubscricaoScreen> createState() => _SubscricaoScreenState();
}

class _SubscricaoScreenState extends State<SubscricaoScreen> {
  int page = 1;
  int perPage = 100;
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
  // (preview UI removed; keep only expansion and external open)
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
    // If opened with an initial pacote, open the subscription form after first frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (widget.initialPacote != null) {
        openForm(pacote: widget.initialPacote);
      }
    });
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
      debugPrint('fetchData: GET $uri');
      debugPrint('fetchData: headers: $headers');
      final resp = await http.get(uri, headers: headers);
      debugPrint('fetchData: status=${resp.statusCode}');
      // Print full response body (UTF-8 safe) for debugging
      try {
        final full = utf8.decode(resp.bodyBytes, allowMalformed: true);
        debugPrint('fetchData: fullBody=' + full);
      } catch (e) {
        debugPrint('fetchData: body (fallback)=${resp.body}');
      }
      if (resp.statusCode == 200) {
        final body = jsonDecode(resp.body);
        setState(() {
          items = body['data'] ?? [];
          total = body['total'] ?? items.length;
        });
      } else {
        debugPrint(
            'fetchData: ERROR status=${resp.statusCode} body=${logging.responseBodyPreview(resp)}');
        if (mounted) {
          final msg = _extractErrorMessageFromResponse(
              resp, 'Erro ao buscar subscrições');
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text(msg)));
        }
      }
    } catch (e, st) {
      debugPrint('fetchData: EXCEPTION $e');
      debugPrint('$st');
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
      form['id'] = item['id'];
      form['user_id'] = item['user_id'];
      form['pacote_id'] = item['pacote_id'];
      form['comprovante_pagamento_subscricao'] =
          item['comprovante_pagamento_subscricao'] ?? [];
      form['motivoAnulacaoOrRejeicao'] = '';
      // Print URLs dos comprobativos
      _printProvavelUrls();
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

    // Open verifier in a fullscreen dialog on top of the current screen.
    await showDialog(
      context: context,
      builder: (d) => Dialog(
        insetPadding: EdgeInsets.zero,
        child: SizedBox(
          width: MediaQuery.of(context).size.width,
          height: MediaQuery.of(context).size.height,
          child: Scaffold(
            appBar: AppBar(
              title: Text('Visualizar Subscrição #${form['id']}'),
              leading: IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.of(d).pop(),
              ),
            ),
            body: _buildVerifier(),
          ),
        ),
      ),
    );
    // ensure inline verifier flag is false after dialog closes
    if (mounted) setState(() => verificar = false);
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
      debugPrint('deleteItem: DELETE $uri');
      debugPrint('deleteItem: headers: $headers');
      final resp = await http.delete(uri, headers: headers);
      debugPrint(
          'deleteItem: status=${resp.statusCode} body=${logging.responseBodyPreview(resp)}');
      if (resp.statusCode == 200) {
        if (mounted)
          ScaffoldMessenger.of(context)
              .showSnackBar(const SnackBar(content: Text('Excluído')));
        await fetchData();
      } else {
        debugPrint(
            'deleteItem: ERROR status=${resp.statusCode} body=${logging.responseBodyPreview(resp)}');
        // Try to decode a meaningful error message (UTF-8 safe) from the response
        String msg = 'Erro ao excluir';
        try {
          final decoded = utf8.decode(resp.bodyBytes, allowMalformed: true);
          final parsed = jsonDecode(decoded);
          if (parsed is Map) {
            if (parsed['message'] != null) {
              msg = parsed['message'].toString();
            } else if (parsed['errors'] != null && parsed['errors'] is Map) {
              final errors = parsed['errors'] as Map;
              for (final v in errors.values) {
                if (v is List && v.isNotEmpty) {
                  msg = v.first.toString();
                  break;
                }
                if (v is String && v.isNotEmpty) {
                  msg = v;
                  break;
                }
              }
            }
          }
        } catch (_) {
          // ignore and fall back to generic message
        }

        if (mounted)
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text(msg)));
      }
    } catch (e) {
      debugPrint('deleteItem: EXCEPTION $e');
      debugPrint(StackTrace.current.toString());
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
      debugPrint('submitValidacao: PUT $uri');
      debugPrint('submitValidacao: headers: $headers');
      debugPrint('submitValidacao: body: ${jsonEncode(body)}');
      final resp = await http.put(uri,
          headers: {...headers, 'Content-Type': 'application/json'},
          body: jsonEncode(body));
      debugPrint(
          'submitValidacao: status=${resp.statusCode} body=${logging.responseBodyPreview(resp)}');
      if (resp.statusCode == 200) {
        if (mounted)
          ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Operação realizada')));
        setState(() => verificar = false);
        await fetchData();
      } else {
        debugPrint(
            'submitValidacao: ERROR status=${resp.statusCode} body=${logging.responseBodyPreview(resp)}');
        if (mounted) {
          final msg =
              _extractErrorMessageFromResponse(resp, 'Erro na operação');
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text(msg)));
        }
      }
    } catch (e) {
      debugPrint('submitValidacao: EXCEPTION $e');
      debugPrint(StackTrace.current.toString());
      if (mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Erro na operação')));
    }
  }

  Future<void> openForm({Map<String, dynamic>? pacote}) async {
    final formKey = GlobalKey<FormState>();
    // If opening with an initial pacote but pacotes list is not loaded yet,
    // load it so the DropdownButtonFormField can show the selected pacote.
    if (pacote != null && (pacotes.isEmpty)) {
      await fetchPacotes();
    }
    final formData = <String, dynamic>{
      'cliente_id': null,
      'pacote_id': pacote != null ? pacote['id'] : null,
      'preco': pacote != null ? pacote['preco']?.toString() ?? '' : '',
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
                      /* Cliente selection disabled temporarily.
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
                        */
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
                        onChanged: (v) => setStateDialog(() {
                          formData['pacote_id'] = v;
                          // set preco from selected pacote immediately
                          try {
                            for (final p in pacotes) {
                              final pid = p['id'] is int
                                  ? p['id'] as int
                                  : int.tryParse(p['id'].toString()) ?? -1;
                              if (pid == (v ?? -1)) {
                                formData['preco'] =
                                    p['preco']?.toString() ?? '';
                                break;
                              }
                            }
                          } catch (_) {}
                        }),
                        validator: (v) => v == null ? 'Obrigatório' : null,
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        key: ValueKey(
                            formData['pacote_id']?.toString() ?? 'preco'),
                        initialValue: formData['preco'],
                        readOnly: true,
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
                    // Use logged-in user id for user_id (cliente selection disabled)
                    try {
                      final auth =
                          Provider.of<AuthProvider>(context, listen: false);
                      final dynamic uid = auth.user != null
                          ? (auth.user!['id'] ?? auth.user!['user_id'])
                          : null;
                      request.fields['user_id'] = (uid ?? '').toString();
                    } catch (_) {
                      request.fields['user_id'] =
                          (formData['cliente_id'] ?? '').toString();
                    }
                    request.fields['pacote_id'] =
                        (formData['pacote_id'] ?? '').toString();
                    request.fields['preco'] =
                        (formData['preco'] ?? '').toString();

                    for (final file in selectedFiles) {
                      try {
                        if (kIsWeb) {
                          final bytes = await file.readAsBytes();
                          request.files.add(http.MultipartFile.fromBytes(
                              'files[]', bytes,
                              filename: file.name));
                        } else {
                          request.files.add(await http.MultipartFile.fromPath(
                              'files[]', file.path,
                              filename: file.name));
                        }
                      } catch (_) {}
                    }

                    final streamed = await request.send();
                    final resp = await http.Response.fromStream(streamed);
                    debugPrint('openForm: POST ${request.url}');
                    debugPrint('openForm: fields=${request.fields}');
                    debugPrint(
                        'openForm: files=${request.files.map((f) => f.filename).toList()}');
                    debugPrint(
                        'openForm: status=${resp.statusCode} body=${logging.responseBodyPreview(resp)}');
                    if (resp.statusCode == 200 || resp.statusCode == 201) {
                      if (mounted)
                        ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Subscrição criada')));
                      Navigator.of(dialogCtx).pop();
                      await fetchData();
                    } else {
                      debugPrint(
                          'openForm: ERROR status=${resp.statusCode} body=${logging.responseBodyPreview(resp)}');
                      if (mounted) {
                        final msg = _extractErrorMessageFromResponse(
                            resp, 'Erro ao criar subscrição');
                        ScaffoldMessenger.of(context)
                            .showSnackBar(SnackBar(content: Text(msg)));
                      }
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
      debugPrint('fetchPacotes: GET $uri');
      debugPrint('fetchPacotes: headers: $headers');
      final resp = await http.get(uri, headers: headers);
      debugPrint(
          'fetchPacotes: status=${resp.statusCode} body=${logging.responseBodyPreview(resp)}');
      if (resp.statusCode == 200) {
        final body = jsonDecode(resp.body);
        setState(() => pacotes = body['data'] ?? (body is List ? body : []));
      } else {
        debugPrint(
            'fetchPacotes: ERROR status=${resp.statusCode} body=${logging.responseBodyPreview(resp)}');
        if (mounted) {
          final msg = _extractErrorMessageFromResponse(
              resp, 'Erro ao carregar pacotes');
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text(msg)));
        }
        setState(() => pacotes = []);
      }
    } catch (e, st) {
      debugPrint('fetchPacotes: EXCEPTION $e');
      debugPrint('$st');
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
      debugPrint('fetchClientes: GET $uri');
      debugPrint('fetchClientes: headers: $headers');
      final resp = await http.get(uri, headers: headers);
      debugPrint(
          'fetchClientes: status=${resp.statusCode} body=${logging.responseBodyPreview(resp)}');
      if (resp.statusCode == 200) {
        final body = jsonDecode(resp.body);
        setState(() => clientes = body['data'] ?? (body is List ? body : []));
      } else {
        debugPrint(
            'fetchClientes: ERROR status=${resp.statusCode} body=${logging.responseBodyPreview(resp)}');
        if (mounted) {
          final msg = _extractErrorMessageFromResponse(
              resp, 'Erro ao carregar clientes');
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text(msg)));
        }
        setState(() => clientes = []);
      }
    } catch (e, st) {
      debugPrint('fetchClientes: EXCEPTION $e');
      debugPrint('$st');
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
      debugPrint('fetchBancos: GET $uri');
      debugPrint('fetchBancos: headers: $headers');
      final resp = await http.get(uri, headers: headers);
      debugPrint(
          'fetchBancos: status=${resp.statusCode} body=${logging.responseBodyPreview(resp)}');
      if (resp.statusCode == 200) {
        final body = jsonDecode(resp.body);
        setState(() => bancos = body['data'] ?? (body is List ? body : []));
      } else {
        debugPrint(
            'fetchBancos: ERROR status=${resp.statusCode} body=${logging.responseBodyPreview(resp)}');
        if (mounted) {
          final msg =
              _extractErrorMessageFromResponse(resp, 'Erro ao carregar bancos');
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text(msg)));
        }
        setState(() => bancos = []);
      }
    } catch (e, st) {
      debugPrint('fetchBancos: EXCEPTION $e');
      debugPrint('$st');
      setState(() => bancos = []);
    }
  }

  Widget _buildList() {
    if (loading) return const Center(child: CircularProgressIndicator());
    if (items.isEmpty)
      return Center(
          child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Text(
          'Ainda não fez pagamento de uma subscrição',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
      ));
    final width = MediaQuery.of(context).size.width;
    final isMobile = width < 600;

    if (isMobile) {
      // Use ListView on mobile so each card sizes to its content (automatic height)
      return RefreshIndicator(
        onRefresh: fetchData,
        child: ListView.builder(
          padding: const EdgeInsets.only(bottom: 88, top: 8),
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

            return Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
              child: InkWell(
                onTap: () => editItem(it),
                child: SubscricaoCard(
                  id: it['id'],
                  designacao: it['designacao'] ?? '',
                  cliente: it['user']?['name'] ?? '-',
                  pacoteInfo:
                      '${pacote['designacao'] ?? '-'}, Preço: ${it['preco'] ?? '-'} AKZ',
                  status: statusStr,
                  onTap: () => editItem(it),
                  onDelete: () => deleteItem(it),
                  imageUrl: (pacote != null &&
                          (pacote['path_capa'] ?? '').toString().isNotEmpty)
                      ? _proxyImageUrl(pacote['path_capa'].toString())
                      : (it['comprovante_pagamento_subscricao'] is List &&
                              (it['comprovante_pagamento_subscricao'] as List)
                                  .isNotEmpty)
                          ? _buildFileUrl(
                              ((it['comprovante_pagamento_subscricao'] as List)
                                          .first['path'] ??
                                      '')
                                  .toString())
                          : null,
                ),
              ),
            );
          },
        ),
      );
    }

    final crossAxisCount = 2;
    final childAspectRatio = 3 / 2;

    return RefreshIndicator(
      onRefresh: fetchData,
      child: GridView.builder(
        padding: const EdgeInsets.only(bottom: 88, top: 8),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: crossAxisCount,
          mainAxisSpacing: 8,
          crossAxisSpacing: 8,
          childAspectRatio: childAspectRatio,
        ),
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

          return Padding(
            padding: const EdgeInsets.all(4.0),
            child: InkWell(
              onTap: () => editItem(it),
              child: SubscricaoCard(
                id: it['id'],
                designacao: it['designacao'] ?? '',
                cliente: it['user']?['name'] ?? '-',
                pacoteInfo:
                    '${pacote['designacao'] ?? '-'}, Preço: ${it['preco'] ?? '-'} AKZ',
                status: statusStr,
                onTap: () => editItem(it),
                onDelete: () => deleteItem(it),
                imageUrl: (pacote != null &&
                        (pacote['path_capa'] ?? '').toString().isNotEmpty)
                    ? _proxyImageUrl(pacote['path_capa'].toString())
                    : (it['comprovante_pagamento_subscricao'] is List &&
                            (it['comprovante_pagamento_subscricao'] as List)
                                .isNotEmpty)
                        ? _buildFileUrl(
                            ((it['comprovante_pagamento_subscricao'] as List)
                                        .first['path'] ??
                                    '')
                                .toString())
                        : null,
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _previewFile(String path) async {
    if (path.isEmpty) return;
    final ext = path.split('.').last.toLowerCase();
    final url = (ext == 'pdf') ? _proxyImageUrl(path) : _buildFileUrl(path);
    String cacheBusted(String u) {
      final ts = DateTime.now().millisecondsSinceEpoch;
      if (u.contains('?')) return '$u&_t=$ts';
      return '$u?_t=$ts';
    }

    // ext already computed above
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
      // Use proxy URL so web client gets proper CORS headers
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
                                  if (mounted) {
                                    final msg =
                                        _extractErrorMessageFromResponse(
                                            resp, 'Erro ao descarregar');
                                    ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(content: Text(msg)));
                                  }
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

  String _toProxyPdf(String raw) {
    if (raw.startsWith('http')) {
      if (raw.contains('/storage/') || raw.contains('/uploads/')) {
        final idx = raw.indexOf('/storage/') + '/storage/'.length;
        final path = idx > '/storage/'.length ? raw.substring(idx) : raw;
        return '${getApiBaseUrl()}proxy-image/$path';
      }
      return raw;
    }
    final p = raw.replaceAll(RegExp(r'^/+'), '');
    return '${getApiBaseUrl()}proxy-image/$p';
  }

  void _openPdfViewerWithUrl(String raw) {
    final url = _toProxyPdf(raw);
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'PDF',
      transitionDuration: const Duration(milliseconds: 200),
      pageBuilder: (context, animation, secondaryAnimation) {
        return SafeArea(
          child: SizedBox(
            width: MediaQuery.of(context).size.width,
            height: MediaQuery.of(context).size.height,
            child: Scaffold(
              body: PdfViewerScreen(pdfUrl: url),
            ),
          ),
        );
      },
    );
  }

  // Build file URL matching backend expected format (id/extension)
  String _buildFileUrl(String path) {
    if (path.isEmpty) return '';
    // If the stored path looks like an uploads/storage path, prefer the proxy-image route
    final lower = path.toLowerCase();
    if (lower.contains('uploads/') ||
        lower.contains('/storage/') ||
        lower.startsWith('uploads')) {
      var p = path.replaceAll(RegExp(r'^/+'), '');
      final base = getApiBaseUrl();
      var root = base.replaceAll(RegExp(r'\/$'), '');
      return '$root/proxy-image/$p';
    }
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

  // Extract a useful error message from an HTTP response, decoding UTF-8 safely.
  String _extractErrorMessageFromResponse(http.Response? resp,
      [String fallback = 'Erro']) {
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
          } else if (errors is List && errors.isNotEmpty) {
            return errors.first.toString();
          }
        }
      }
      if (parsed is String && parsed.isNotEmpty) return parsed;
      if (decoded.isNotEmpty) return decoded;
    } catch (_) {
      // ignore and fall back
    }
    try {
      final fallbackBody = utf8.decode(resp.bodyBytes, allowMalformed: true);
      if (fallbackBody.isNotEmpty) return fallbackBody;
    } catch (_) {}
    return fallback;
  }

  // response body preview moved to lib/utils/logging.dart

  void _printProvavelUrls() {
    final comprovantes =
        (form['comprovante_pagamento_subscricao'] as List<dynamic>?) ?? [];
    print('=== URLs DOS COMPROBATIVOS ===');
    print('Total de comprobativos: ${comprovantes.length}');
    for (int i = 0; i < comprovantes.length; i++) {
      final c = comprovantes[i] as Map<String, dynamic>;
      final path = (c['path'] ?? '').toString();
      final proxy = _buildFileUrl(path);
      final direct = (path.isNotEmpty) ? _buildFileUrl(path) : '';
      print('Comprobativo ${i + 1}: $proxy');
    }
    print('==============================');
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
        StatefulBuilder(builder: (context, setStateDialog) {
          return ExpansionPanelList(
            expansionCallback: (panelIndex, isExpanded) => setStateDialog(() {
              final newVal = !isExpanded;
              _expanded[panelIndex] = newVal;
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
                    onTap: () => setStateDialog(() {
                      final newVal = !(_expanded[idx] ?? false);
                      _expanded[idx] = newVal;
                    }),
                    trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                      IconButton(
                        icon: const Icon(Icons.open_in_new),
                        onPressed: () async {
                          final ext = path.split('.').last.toLowerCase();
                          if (ext == 'pdf') {
                            _openPdfViewerWithUrl(path);
                          } else {
                            // images / other files: use preview handler (opens externally)
                            await _previewFile(path);
                          }
                        },
                      ),
                    ]),
                  );
                },
                body: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Data (somente leitura)
                      AbsorbPointer(
                        child: TextFormField(
                          controller: TextEditingController(
                              text: _formatDisplayDate(
                                  c['data_movimento']?.toString() ?? '')),
                          decoration: const InputDecoration(labelText: 'Data'),
                          readOnly: true,
                        ),
                      ),
                      const SizedBox(height: 8),
                      // Valor (somente leitura)
                      TextFormField(
                        initialValue: c['valor']?.toString() ?? '',
                        decoration: const InputDecoration(labelText: 'Valor'),
                        readOnly: true,
                      ),
                      const SizedBox(height: 8),
                      // Banco (somente leitura / disabled)
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
                          return DropdownMenuItem(
                              value: id, child: Text(label));
                        }).toList(),
                        decoration: const InputDecoration(labelText: 'Banco'),
                        onChanged: null,
                        disabledHint: Builder(builder: (ctx) {
                          try {
                            final id = c['coordenadas_bancaria_id'];
                            final found = bancos.firstWhere(
                                (b) => b['id'].toString() == id?.toString(),
                                orElse: () => null);
                            final label = found != null
                                ? (found['nome'] ?? found['name'] ?? '')
                                : '';
                            return Text(label);
                          } catch (_) {
                            return const SizedBox.shrink();
                          }
                        }),
                      ),
                      const SizedBox(height: 8),
                      // Nº Transação (somente leitura)
                      TextFormField(
                        initialValue: c['numero_transaccao']?.toString() ?? '',
                        decoration:
                            const InputDecoration(labelText: 'Nº Transação'),
                        readOnly: true,
                      ),
                    ],
                  ),
                ),
                isExpanded: _expanded[idx] ?? false,
              );
            }).toList(),
          );
        }),
        const SizedBox(height: 12),
        TextFormField(
          initialValue: form['motivoAnulacaoOrRejeicao'] ?? '',
          readOnly: true,
          maxLines: 3,
          decoration: const InputDecoration(labelText: 'Motivo'),
        ),
        const SizedBox(height: 12),
        LayoutBuilder(builder: (context, constraints) {
          return Wrap(
            alignment: WrapAlignment.center,
            spacing: 8,
            runSpacing: 8,
            // children: [
            //   ConstrainedBox(
            //     constraints: const BoxConstraints(minWidth: 80, maxWidth: 200),
            //     child: ElevatedButton.icon(
            //       icon: const Icon(Icons.check),
            //       label: const Text('Aprovar'),
            //       onPressed: () => submitValidacao(1),
            //     ),
            //   ),
            //   ConstrainedBox(
            //     constraints: const BoxConstraints(minWidth: 80, maxWidth: 200),
            //     child: ElevatedButton.icon(
            //       icon: const Icon(Icons.close),
            //       label: const Text('Rejeitar'),
            //       onPressed: () => submitValidacao(2),
            //     ),
            //   ),
            //   ConstrainedBox(
            //     constraints: const BoxConstraints(minWidth: 80, maxWidth: 200),
            //     child: ElevatedButton.icon(
            //       icon: const Icon(Icons.delete),
            //       label: const Text('Anular'),
            //       style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            //       onPressed: () => submitValidacao(3),
            //     ),
            //   ),
            //   ConstrainedBox(
            //     constraints: const BoxConstraints(minWidth: 80, maxWidth: 200),
            //     child: ElevatedButton.icon(
            //       icon: const Icon(Icons.reply),
            //       label: const Text('Retornar'),
            //       onPressed: () => submitValidacao(4),
            //     ),
            //   ),
            // ],
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
              if (verificar)
                Row(children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back),
                    onPressed: () => setState(() => verificar = false),
                  ),
                  const SizedBox(width: 8),
                  const Text('Visualizar Subscrição',
                      style:
                          TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                ])
              else
                const Text('Subscrições',
                    style:
                        TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
              const SizedBox.shrink(),
            ]),
            const SizedBox(height: 12),
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
          if (!verificar)
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

String _proxyImageUrl(String path) {
  final base = getApiBaseUrl();
  var root = base.replaceAll(RegExp(r'\/$'), '');
  return '$root/proxy-image/$path';
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
