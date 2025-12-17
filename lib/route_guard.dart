import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'navigation_service.dart';
import 'providers/auth_provider.dart';
import 'routes.dart' as app_routes;
import 'screens/sign_in/sign_in_screen.dart';
import 'config/access_restrictions.dart';
import 'screens/init_screen.dart';

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

  // Block routes that require a purchased pacote: if user is logged in but
  // has no pacoteIds, redirect to the InitScreen (which will show the
  // 'Ver Pacotes' placeholder in the bottom tabs).
  if (loggedIn && blockedRoutesWhenNoPacote.contains(settings.name)) {
    try {
      final auth = Provider.of<AuthProvider>(ctx!, listen: false);
      final user = auth.user;
      var hasPacote = false;
      if (user != null) {
        for (final k in user.keys) {
          final lk = k.toString().toLowerCase();
          if (lk.contains('pacote')) {
            final v = user[k];
            if (v is List && v.isNotEmpty) hasPacote = true;
            if (v is String && v.trim().isNotEmpty) {
              if (v.trim().startsWith('[') && v.trim().endsWith(']')) {
                if (v.trim().length > 2) hasPacote = true;
              } else {
                hasPacote = true;
              }
            }
          }
        }
      }

      if (!hasPacote) {
        return MaterialPageRoute(
            builder: (_) => const InitScreen(), settings: settings);
      }
    } catch (_) {
      // fail open: allow route if something goes wrong reading user
    }
  }

  if (builder != null) {
    return MaterialPageRoute(builder: builder, settings: settings);
  }

  // Fallback: unknown route -> try to open sign in
  return MaterialPageRoute(
      builder: (_) => const SignInScreen(), settings: settings);
}
