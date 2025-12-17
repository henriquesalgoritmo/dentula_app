import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:provider/provider.dart';

import '../../../components/custom_surfix_icon.dart';
import '../../../components/form_error.dart';
import '../../../constants.dart';
import '../../../api_config.dart';
import '../../../providers/auth_provider.dart';
import '../../verification/verification_screen.dart';

class SignUpForm extends StatefulWidget {
  const SignUpForm({super.key});

  @override
  _SignUpFormState createState() => _SignUpFormState();
}

class _SignUpFormState extends State<SignUpForm> {
  final _formKey = GlobalKey<FormState>();

  String? name;
  String? email;
  String? password;
  String? conform_password;
  String? telefone;
  int? tipoUserId;
  String? codigoAfilhao;
  bool privacyPolicies = false;

  final List<String?> errors = [];

  List<Map<String, dynamic>> tiposUser = [];
  bool isLoading = false;

  @override
  void initState() {
    super.initState();
    // Ensure loading flag is false by default and fetch tipos
    isLoading = false;
    debugPrint('SignUpForm.initState isLoading=$isLoading');
    _fetchTiposUser();
  }

  Future<void> _fetchTiposUser() async {
    final String url = '${getApiBaseUrl()}tiposUsersExterno';
    try {
      final resp = await http.get(Uri.parse(url));
      if (resp.statusCode == 200) {
        final body = jsonDecode(resp.body);
        debugPrint('Fddddd : $body');
        if (body is List) {
          tiposUser = List<Map<String, dynamic>>.from(body);
          setState(() {});
        }
      }
    } catch (e) {
      debugPrint('Failed to load tiposUser: $e');
    }
  }

  void addError({String? error}) {
    if (!errors.contains(error)) {
      setState(() {
        errors.add(error);
      });
    }
  }

  void removeError({String? error}) {
    if (errors.contains(error)) {
      setState(() {
        errors.remove(error);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      child: Column(
        children: [
          // Name
          TextFormField(
            keyboardType: TextInputType.text,
            onSaved: (newValue) => name = newValue,
            decoration: const InputDecoration(
              labelText: "Nome",
              hintText: "Insira o seu nome",
              floatingLabelBehavior: FloatingLabelBehavior.always,
            ),
            validator: (value) {
              if (value == null || value.isEmpty)
                return 'Por favor insira o seu nome';
              return null;
            },
          ),
          const SizedBox(height: 16),

          // Email (optional)
          TextFormField(
            keyboardType: TextInputType.emailAddress,
            onSaved: (newValue) => email = newValue,
            onChanged: (value) {
              if (value.isNotEmpty) {
                removeError(error: kInvalidEmailError);
                removeError(error: kEmailOrPhoneNullError);
              }
            },
            validator: (value) {
              if (value != null &&
                  value.isNotEmpty &&
                  !emailValidatorRegExp.hasMatch(value)) {
                addError(error: kInvalidEmailError);
                return "";
              }
              return null;
            },
            decoration: const InputDecoration(
              labelText: "Email",
              hintText: "Insira o seu email",
              floatingLabelBehavior: FloatingLabelBehavior.always,
              suffixIcon: CustomSurffixIcon(svgIcon: "assets/icons/Mail.svg"),
            ),
          ),
          const SizedBox(height: 12),

          // Telefone (after Email)
          TextFormField(
            keyboardType: TextInputType.phone,
            onSaved: (newValue) => telefone = newValue,
            onChanged: (value) {
              if (value.isNotEmpty) {
                removeError(error: kPhoneNumberNullError);
                removeError(error: kEmailOrPhoneNullError);
              }
            },
            decoration: const InputDecoration(
              labelText: "Telefone",
              hintText: "Insira o seu telefone",
              floatingLabelBehavior: FloatingLabelBehavior.always,
            ),
          ),
          const SizedBox(height: 20),

          // Password
          TextFormField(
            obscureText: true,
            onSaved: (newValue) => password = newValue,
            onChanged: (value) {
              if (value.isNotEmpty) {
                removeError(error: kPassNullError);
              } else if (value.length >= 8) {
                removeError(error: kShortPassError);
              }
              password = value;
            },
            validator: (value) {
              if (value == null || value.isEmpty) {
                addError(error: kPassNullError);
                return "";
              } else if (value.length < 8) {
                addError(error: kShortPassError);
                return "";
              }
              return null;
            },
            decoration: const InputDecoration(
              labelText: "Palavra-passe",
              hintText: "Insira a sua palavra-passe",
              floatingLabelBehavior: FloatingLabelBehavior.always,
              suffixIcon: CustomSurffixIcon(svgIcon: "assets/icons/Lock.svg"),
            ),
          ),
          const SizedBox(height: 20),

          // Confirm Password
          TextFormField(
            obscureText: true,
            onSaved: (newValue) => conform_password = newValue,
            onChanged: (value) {
              if (value.isNotEmpty) {
                removeError(error: kPassNullError);
              } else if (value.isNotEmpty && password == conform_password) {
                removeError(error: kMatchPassError);
              }
              conform_password = value;
            },
            validator: (value) {
              if (value == null || value.isEmpty) {
                addError(error: kPassNullError);
                return "";
              } else if ((password != value)) {
                addError(error: kMatchPassError);
                return "";
              }
              return null;
            },
            decoration: const InputDecoration(
              labelText: "Confirmar palavra-passe",
              hintText: "Reinsira a palavra-passe",
              floatingLabelBehavior: FloatingLabelBehavior.always,
              suffixIcon: CustomSurffixIcon(svgIcon: "assets/icons/Lock.svg"),
            ),
          ),
          FormError(errors: errors),
          const SizedBox(height: 16),

          // Tipo user select
          DropdownButtonFormField<int>(
            value: tipoUserId,
            items: tiposUser
                .map((t) => DropdownMenuItem<int>(
                      value: t['id'] is int
                          ? t['id'] as int
                          : int.parse(t['id'].toString()),
                      child: Text(t['designacao']?.toString() ??
                          t['name']?.toString() ??
                          'Tipo'),
                    ))
                .toList(),
            onChanged: (v) => setState(() => tipoUserId = v),
            decoration: const InputDecoration(labelText: 'Tipo Utilizador'),
          ),
          const SizedBox(height: 12),

          // Codigo Afilhao
          TextFormField(
            keyboardType: TextInputType.text,
            onSaved: (newValue) => codigoAfilhao = newValue,
            decoration: const InputDecoration(
              labelText: "Código de Afiliado",
              hintText: "Insira o código",
              floatingLabelBehavior: FloatingLabelBehavior.always,
            ),
          ),

          const SizedBox(height: 12),

          // Privacy checkbox
          CheckboxListTile(
            value: privacyPolicies,
            onChanged: (v) => setState(() => privacyPolicies = v ?? false),
            title:
                const Text('Eu concordo com Política de Privacidade e Termo'),
            controlAffinity: ListTileControlAffinity.leading,
          ),
          const SizedBox(height: 20),

          ElevatedButton(
            onPressed: isLoading
                ? null
                : () async {
                    if (!_formKey.currentState!.validate()) return;
                    _formKey.currentState!.save();

                    // Require at least email or telefone
                    if ((email == null || email!.isEmpty) &&
                        (telefone == null || telefone!.isEmpty)) {
                      addError(error: kEmailOrPhoneNullError);
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                          content: Text('Por favor insira email ou telefone')));
                      return;
                    }

                    if (!privacyPolicies) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                          content: Text(
                              'Você precisa aceitar a política de privacidade.')));
                      return;
                    }
                    await _submitRegister();
                  },
            child: isLoading
                ? const SizedBox(
                    height: 18,
                    width: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : const Text("Inscrição"),
          ),
        ],
      ),
    );
  }

  Future<void> _submitRegister() async {
    final scaffold = ScaffoldMessenger.of(context);
    final String url = '${getApiBaseUrl()}register';

    final payload = {
      'name': name ?? '',
      'email': email ?? '',
      'password': password ?? '',
      'password_confirmation': conform_password ?? '',
      'telefone': telefone ?? '',
      'tipo_user_id': tipoUserId,
      'codigoAfilhao': codigoAfilhao ?? '',
    };

    try {
      debugPrint('REGISTER REQUEST -> POST $url');
      debugPrint('REGISTER payload: ${jsonEncode(payload)}');

      final resp = await http.post(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(payload),
      );

      debugPrint('REGISTER status: ${resp.statusCode}');
      debugPrint('REGISTER body: ${resp.body}');

      if (resp.statusCode == 200 || resp.statusCode == 201) {
        final body = jsonDecode(resp.body);
        final token = body['token'];
        final user = body['user'];

        if (token != null) {
          final auth = Provider.of<AuthProvider>(context, listen: false);
          await auth.login(
              token: token.toString(),
              user: (user is Map) ? user as Map<String, dynamic> : null);
          // navigate to verification screen if user not verified
          final isVerified =
              (user is Map) && (user['data_verificacao_conta'] != null);
          if (!isVerified) {
            // choose best identifier: prefer valid email, then telefone
            String identifierValue = '';
            if (user is Map) {
              final Map<String, dynamic> u = user as Map<String, dynamic>;
              if (u['email'] != null && u['email'].toString().contains('@')) {
                identifierValue = u['email'].toString();
              } else if (u['telefone'] != null &&
                  u['telefone'].toString().trim().isNotEmpty) {
                identifierValue = u['telefone'].toString();
              }
            }
            Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                    builder: (_) =>
                        VerificationScreen(identifier: identifierValue)));
            return;
          }
        }

        scaffold.showSnackBar(
            const SnackBar(content: Text('Usuário registrado com sucesso!')));
        Navigator.pushReplacementNamed(context, '/');
        return;
      }

      if (resp.statusCode == 422) {
        final body = jsonDecode(resp.body);
        if (body is Map) {
          final first = body.values.first;
          if (first is List && first.isNotEmpty) {
            scaffold.showSnackBar(SnackBar(content: Text(first[0].toString())));
            return;
          }
        }
      }

      scaffold
          .showSnackBar(const SnackBar(content: Text('Erro ao registrar.')));
    } catch (e) {
      debugPrint('Register error: $e');
      scaffold.showSnackBar(SnackBar(content: Text('Erro ao registrar: $e')));
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }
}
