import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shop_app/screens/init_screen.dart';
import 'package:shop_app/screens/sign_in/sign_in_screen.dart';

import '../../providers/auth_provider.dart';

class LoadingScreen extends StatefulWidget {
  static String routeName = '/loading';

  const LoadingScreen({super.key});

  @override
  State<LoadingScreen> createState() => _LoadingScreenState();
}

class _LoadingScreenState extends State<LoadingScreen> {
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _initAuth();
  }

  Future<void> _initAuth() async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    await auth.loadFromPrefs();

    if (auth.isLoggedIn) {
      Navigator.pushReplacementNamed(context, InitScreen.routeName);
    } else {
      Navigator.pushReplacementNamed(context, SignInScreen.routeName);
    }
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: CircularProgressIndicator(),
      ),
    );
  }
}
