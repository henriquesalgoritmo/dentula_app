import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../../../components/custom_surfix_icon.dart';
import '../../../components/form_error.dart';
import '../../../components/no_account_text.dart';
import '../../../constants.dart';
import '../../../api_config.dart';

class ForgotPassForm extends StatefulWidget {
  const ForgotPassForm({super.key});

  @override
  _ForgotPassFormState createState() => _ForgotPassFormState();
}

class _ForgotPassFormState extends State<ForgotPassForm> {
  final _formKey = GlobalKey<FormState>();
  List<String> errors = [];
  String? identifier;
  String? code;
  String? password;
  String? passwordConfirm;
  int _step = 0; // 0 = enter identifier, 1 = enter code + new password
  bool _loading = false;
  final TextEditingController _codeController = TextEditingController();
  final FocusNode _codeFocus = FocusNode();

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      child: Column(
        children: [
          if (_step == 0) ...[
            TextFormField(
              keyboardType: TextInputType.text,
              onSaved: (newValue) => identifier = newValue,
              onChanged: (value) {
                if (value.isNotEmpty && errors.contains(kEmailNullError)) {
                  setState(() {
                    errors.remove(kEmailNullError);
                  });
                }
                return;
              },
              validator: (value) {
                if (value == null || value.isEmpty) {
                  if (!errors.contains(kEmailNullError)) {
                    setState(() => errors.add(kEmailNullError));
                  }
                }
                return null;
              },
              decoration: const InputDecoration(
                labelText: "Email ou Telefone",
                hintText: "Insira o seu email ou número de telefone",
                floatingLabelBehavior: FloatingLabelBehavior.always,
                suffixIcon: CustomSurffixIcon(svgIcon: "assets/icons/Mail.svg"),
              ),
            ),
          ] else ...[
            TextFormField(
              controller: _codeController,
              focusNode: _codeFocus,
              keyboardType: TextInputType.number,
              onChanged: (value) {
                if (value.isNotEmpty && errors.contains('code')) {
                  setState(() => errors.remove('code'));
                }
                return;
              },
              validator: (value) {
                if (value == null || value.isEmpty) {
                  if (!errors.contains('code'))
                    setState(() => errors.add('code'));
                }
                return null;
              },
              decoration: const InputDecoration(
                labelText: "Código",
                hintText: "Insira o código recebido",
                floatingLabelBehavior: FloatingLabelBehavior.always,
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              obscureText: true,
              onSaved: (v) => password = v,
              onChanged: (v) {
                if (v.isNotEmpty && errors.contains(kPassNullError)) {
                  setState(() => errors.remove(kPassNullError));
                }
                return;
              },
              decoration: const InputDecoration(
                labelText: "Nova palavra-passe",
                hintText: "Digite a nova palavra-passe",
                floatingLabelBehavior: FloatingLabelBehavior.always,
                suffixIcon: CustomSurffixIcon(svgIcon: "assets/icons/Lock.svg"),
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              obscureText: true,
              onSaved: (v) => passwordConfirm = v,
              decoration: const InputDecoration(
                labelText: "Confirmar palavra-passe",
                hintText: "Repita a palavra-passe",
                floatingLabelBehavior: FloatingLabelBehavior.always,
                suffixIcon: CustomSurffixIcon(svgIcon: "assets/icons/Lock.svg"),
              ),
            ),
          ],
          const SizedBox(height: 8),
          FormError(errors: errors),
          const SizedBox(height: 8),
          if (_loading) const CircularProgressIndicator(),
          if (!_loading)
            ElevatedButton(
              onPressed: () async {
                if (!_formKey.currentState!.validate()) return;
                _formKey.currentState!.save();
                code = _codeController.text.trim();
                setState(() => _loading = true);
                try {
                  if (_step == 0) {
                    // request code
                    final url = '${getApiBaseUrl()}resend-verification';
                    final resp = await http.post(Uri.parse(url),
                        body: {'email_or_telefone': identifier ?? ''});
                    if (resp.statusCode == 200) {
                      setState(() {
                        _step = 1;
                        errors.clear();
                        // clear and focus code field so user can type received code
                        _codeController.clear();
                        FocusScope.of(context).requestFocus(_codeFocus);
                      });
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                          content: Text('Código enviado se a conta existir')));
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Erro: ${resp.body}')));
                    }
                  } else {
                    // submit reset
                    final url = '${getApiBaseUrl()}reset-password';
                    final resp = await http.post(Uri.parse(url), body: {
                      'email_or_telefone': identifier ?? '',
                      'code': code ?? _codeController.text.trim(),
                      'password': password ?? '',
                      'password_confirmation': passwordConfirm ?? ''
                    });
                    if (resp.statusCode == 200) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                          content: Text('Senha redefinida com sucesso')));
                      Navigator.of(context).pop();
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Erro: ${resp.body}')));
                    }
                  }
                } catch (e) {
                  ScaffoldMessenger.of(context)
                      .showSnackBar(SnackBar(content: Text('Erro: $e')));
                } finally {
                  setState(() => _loading = false);
                }
              },
              child: Text(_step == 0 ? 'Enviar código' : 'Redefinir senha'),
            ),
          const SizedBox(height: 16),
          const NoAccountText(),
        ],
      ),
    );
  }
}
