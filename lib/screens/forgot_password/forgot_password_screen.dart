import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'components/forgot_pass_form.dart';
import '../../providers/auth_provider.dart';

class ForgotPasswordScreen extends StatelessWidget {
  static String routeName = "/forgot_password";

  const ForgotPasswordScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text("Recuperar palavra-passe"),
        automaticallyImplyLeading: !auth.isLoggedIn,
      ),
      body: const SizedBox(
        width: double.infinity,
        child: SingleChildScrollView(
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              children: [
                SizedBox(height: 16),
                Text(
                  "Recuperar palavra-passe",
                  style: TextStyle(
                    fontSize: 24,
                    color: Colors.black,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Text(
                  "Insira o seu email e enviaremos um link\npara recuperar a sua conta",
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 32),
                ForgotPassForm(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
