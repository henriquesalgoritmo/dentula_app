import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shop_app/screens/init_screen.dart';

import 'routes.dart';
import 'theme.dart';
import 'providers/auth_provider.dart';
import 'navigation_service.dart';
import 'route_guard.dart';
import 'screens/home/home_screen.dart';
import 'screens/splash/splash_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  runApp(
    ChangeNotifierProvider<AuthProvider>(
      create: (_) => AuthProvider(),
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    final String initial =
        auth.isLoggedIn ? InitScreen.routeName : SplashScreen.routeName;

    return MaterialApp(
      navigatorKey: navigatorKey,
      navigatorObservers: [routeObserver],
      debugShowCheckedModeBanner: false,
      title: 'The Flutter Way - Template',
      theme: AppTheme.lightTheme(context),
      initialRoute: initial,
      onGenerateRoute: generateRoute,
      // keep routes map as fallback for named routes resolution inside generator
      routes: routes,
    );
  }
}
