import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';

import '../../../providers/auth_provider.dart';
import 'package:flutter/services.dart';
import 'package:shop_app/api_config.dart';

import '../../../components/custom_surfix_icon.dart';
import '../../../components/form_error.dart';
import '../../../constants.dart';
import '../../../helper/keyboard.dart';
import '../../forgot_password/forgot_password_screen.dart';
import '../../verification/verification_screen.dart';
// login_success_screen not used here

class SignForm extends StatefulWidget {
  const SignForm({super.key});

  @override
  _SignFormState createState() => _SignFormState();
}

class _SignFormState extends State<SignForm> {
  final _formKey = GlobalKey<FormState>();
  String? emailOrUsername;
  String? password;
  bool? remember = false;
  bool isLoading = false;
  final List<String?> errors = [];

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
          TextFormField(
            keyboardType: TextInputType.emailAddress,
            onSaved: (newValue) => emailOrUsername = newValue,
            onChanged: (value) {
              if (value.isNotEmpty) {
                removeError(error: kEmailNullError);
              }
              // if value looks like an email and is valid, remove invalid email error
              else if (value.contains('@') &&
                  emailValidatorRegExp.hasMatch(value)) {
                removeError(error: kInvalidEmailError);
              }
              return;
            },
            validator: (value) {
              if (value == null || value.isEmpty) {
                addError(error: kEmailNullError);
                return "";
              }
              // if user provided an email address, validate its format
              if (value.contains('@') &&
                  !emailValidatorRegExp.hasMatch(value)) {
                addError(error: kInvalidEmailError);
                return "";
              }
              return null;
            },
            decoration: const InputDecoration(
              labelText: "Email or Username",
              hintText: "Enter your email or username",
              floatingLabelBehavior: FloatingLabelBehavior.always,
              suffixIcon: CustomSurffixIcon(svgIcon: "assets/icons/Mail.svg"),
            ),
          ),
          const SizedBox(height: 20),
          TextFormField(
            obscureText: true,
            onSaved: (newValue) => password = newValue,
            onChanged: (value) {
              if (value.isNotEmpty) {
                removeError(error: kPassNullError);
              } else if (value.length >= 3) {
                removeError(error: kShortPassError);
              }
              return;
            },
            validator: (value) {
              if (value!.isEmpty) {
                addError(error: kPassNullError);
                return "";
              } else if (value.length < 3) {
                addError(error: kShortPassError);
                return "";
              }
              return null;
            },
            decoration: const InputDecoration(
              labelText: "Password",
              hintText: "Enter your password",
              // If  you are using latest version of flutter then lable text and hint text shown like this
              // if you r using flutter less then 1.20.* then maybe this is not working properly
              floatingLabelBehavior: FloatingLabelBehavior.always,
              suffixIcon: CustomSurffixIcon(svgIcon: "assets/icons/Lock.svg"),
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Checkbox(
                value: remember,
                activeColor: kPrimaryColor,
                onChanged: (value) {
                  setState(() {
                    remember = value;
                  });
                },
              ),
              const Text("Remember me"),
              const Spacer(),
              GestureDetector(
                onTap: () => Navigator.pushNamed(
                    context, ForgotPasswordScreen.routeName),
                child: const Text(
                  "Forgot Password",
                  style: TextStyle(decoration: TextDecoration.underline),
                ),
              )
            ],
          ),
          FormError(errors: errors),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: isLoading
                ? null
                : () async {
                    if (_formKey.currentState!.validate()) {
                      _formKey.currentState!.save();
                      KeyboardUtil.hideKeyboard(context);
                      await _submitLogin();
                    }
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
                : const Text("Continue"),
          ),
        ],
      ),
    );
  }

  Future<void> _submitLogin() async {
    if (isLoading) return;
    setState(() => isLoading = true);
    final scaffold = ScaffoldMessenger.of(context);
    // Build URL using global API config (adjusts for Android emulator)
    final String url = '${getApiBaseUrl()}login';

    try {
      final payload = {
        'email_or_username': emailOrUsername ?? '',
        'password': password ?? '',
        'remember': remember ?? false,
      };
      final String payloadJson = jsonEncode(payload);

      debugPrint('LOGIN REQUEST -> POST $url');
      debugPrint('LOGIN REQUEST payload: $payloadJson');

      final response = await http.post(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
        body: payloadJson,
      );

      final int status = response.statusCode;
      debugPrint('LOGIN RESPONSE status: $status');
      debugPrint('LOGIN RESPONSE headers: ${response.headers}');
      // Use debugPrint to avoid truncation of long bodies in some consoles
      debugPrint('LOGIN RESPONSE body: ${response.body}');
      dynamic body;
      if (response.body.isNotEmpty) {
        try {
          body = jsonDecode(response.body);
        } on FormatException catch (_) {
          // Response wasn't JSON (could be HTML error page or plain text)
          body = response.body;
        }
      } else {
        body = {};
      }

      if (status == 200 || status == 201) {
        final token =
            (body is Map && body.containsKey('token')) ? body['token'] : null;
        final user =
            (body is Map && body.containsKey('user')) ? body['user'] : null;

        // Update centralized AuthProvider (and persist inside it)
        try {
          final auth = Provider.of<AuthProvider>(context, listen: false);
          if (token != null) {
            await auth.login(
                token: token.toString(),
                user: (user is Map) ? user as Map<String, dynamic> : null);
          }
        } catch (e) {
          // If provider isn't available for some reason, fall back to local prefs
          try {
            final prefs = await SharedPreferences.getInstance();
            if (token != null) await prefs.setString('token', token);
            if (user != null) await prefs.setString('user', jsonEncode(user));
          } catch (e) {
            debugPrint('Error while saving preferences fallback: $e');
          }
        }

        scaffold.showSnackBar(
            const SnackBar(content: Text('Usuário logado com sucesso!')));

        // Navigate to root/home
        Navigator.pushReplacementNamed(context, '/');
        return;
      }

      // If account not verified, backend returns 403 with needs_verification flag
      if (status == 403) {
        try {
          final needs = (body is Map && body['needs_verification'] != null)
              ? body['needs_verification']
              : null;
          final msg = (body is Map && body['message'] != null)
              ? body['message'].toString()
              : 'Conta não verificada';
          // Navigate to verification screen with provided identifier
          Navigator.of(context).pushReplacement(MaterialPageRoute(
              builder: (_) =>
                  VerificationScreen(identifier: emailOrUsername ?? '')));
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text(msg)));
          return;
        } catch (e) {
          // ignore
        }
      }

      // Validation errors (Laravel typically returns 422 with field errors)
      if (status == 422 && body is Map) {
        // body might be { "email": ["..."], ... }
        final firstError = body.values.first;
        if (firstError is List && firstError.isNotEmpty) {
          scaffold
              .showSnackBar(SnackBar(content: Text(firstError[0].toString())));
          return;
        }
      }

      // Unauthorized
      if (status == 401) {
        final msg = (body is Map && body['message'] != null)
            ? body['message'].toString()
            : response.body.toString();
        scaffold.showSnackBar(SnackBar(content: Text(msg)));
        return;
      }

      // If body is a plain string (non-JSON), show it; otherwise a generic message
      if (body is String && body.isNotEmpty) {
        scaffold.showSnackBar(SnackBar(content: Text(body)));
      } else {
        scaffold.showSnackBar(const SnackBar(
            content: Text('Erro inesperado ao logar. Tente novamente.')));
      }
    } catch (e) {
      debugPrint('erros gerado $e');
      scaffold.showSnackBar(SnackBar(content: Text('Erro ao fazer login: $e')));
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }
}
