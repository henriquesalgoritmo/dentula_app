import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../components/socal_card.dart';
import '../../constants.dart';
import 'components/sign_up_form.dart';
import '../../providers/auth_provider.dart';

class SignUpScreen extends StatelessWidget {
  static String routeName = "/sign_up";

  const SignUpScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text("Registar"),
        automaticallyImplyLeading: !auth.isLoggedIn,
      ),
      body: SafeArea(
        child: SizedBox(
          width: double.infinity,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: SingleChildScrollView(
              child: Column(
                children: [
                  const SizedBox(height: 16),
                  const Text("Criar Conta", style: headingStyle),
                  const Text(
                    "Complete os seus dados ou continue\ncom uma rede social",
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  const SignUpForm(),
                  const SizedBox(height: 16),
                  // Social icons hidden (not available)
                  const SizedBox.shrink(),
                  const SizedBox(height: 16),
                  Text(
                    'Ao continuar confirma que concorda\ncom os nossos Termos e Condições',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodySmall,
                  )
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
