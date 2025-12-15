import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'navigation_service.dart';
import 'providers/auth_provider.dart';
import 'routes.dart' as app_routes;
import 'screens/sign_in/sign_in_screen.dart';

/// Centralized route generator that enforces auth checks for protected routes.
Route<dynamic>? generateRoute(RouteSettings settings) {
  // resolve builder from the existing routes map
  final builder = app_routes.routes[settings.name];

  // Determine if route is protected
  const protected = <String>{
    '/',
    '/profile',
    '/home',
    '/products',
    '/details',
    '/cart',
  };

  final ctx = navigatorKey.currentContext;
  bool loggedIn = false;
  if (ctx != null) {
    try {
      final auth = Provider.of<AuthProvider>(ctx, listen: false);
      loggedIn = auth.isLoggedIn;
    } catch (_) {
      loggedIn = false;
    }
  }

  // If route is protected and user is not logged, redirect to SignInScreen
  if (protected.contains(settings.name) && !loggedIn) {
    return MaterialPageRoute(
        builder: (_) => const SignInScreen(), settings: settings);
  }

  if (builder != null) {
    return MaterialPageRoute(builder: builder, settings: settings);
  }

  // Fallback: unknown route -> try to open sign in
  return MaterialPageRoute(
      builder: (_) => const SignInScreen(), settings: settings);
}
