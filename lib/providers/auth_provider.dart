import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AuthProvider with ChangeNotifier {
  static const _tokenKey = 'token';
  static const _userKey = 'user';

  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();

  String? _token;
  Map<String, dynamic>? _user;

  AuthProvider({String? token, Map<String, dynamic>? user}) {
    _token = token;
    _user = user;
  }

  String? get token => _token;
  Map<String, dynamic>? get user => _user;
  bool get isLoggedIn => _token != null && _token!.isNotEmpty;

  Future<void> login(
      {required String token, Map<String, dynamic>? user}) async {
    _token = token;
    _user = user;
    try {
      // persist token securely
      await _secureStorage.write(key: _tokenKey, value: token);
      // persist user data in shared preferences (not sensitive)
      final prefs = await SharedPreferences.getInstance();
      if (user != null) await prefs.setString(_userKey, jsonEncode(user));
    } catch (e) {
      if (kDebugMode) {
        // ignore: avoid_print
        print('AuthProvider: could not persist login: $e');
      }
    }
    notifyListeners();
  }

  Future<void> logout() async {
    _token = null;
    _user = null;
    try {
      await _secureStorage.delete(key: _tokenKey);
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_userKey);
    } catch (e) {
      if (kDebugMode) {
        // ignore: avoid_print
        print('AuthProvider: could not clear prefs: $e');
      }
    }
    notifyListeners();
  }

  /// Load token and user from storage into this provider
  Future<void> loadFromPrefs() async {
    try {
      final token = await _secureStorage.read(key: _tokenKey);
      Map<String, dynamic>? user;
      final prefs = await SharedPreferences.getInstance();
      final userJson = prefs.getString(_userKey);
      if (userJson != null && userJson.isNotEmpty) {
        try {
          user = jsonDecode(userJson) as Map<String, dynamic>;
        } catch (_) {
          user = null;
        }
      }

      _token = token;
      _user = user;
    } catch (e) {
      if (kDebugMode) {
        // ignore: avoid_print
        print('AuthProvider: error loading prefs: $e');
      }
      _token = null;
      _user = null;
    }
    notifyListeners();
  }

  static Future<AuthProvider> fromPrefs() async {
    final provider = AuthProvider();
    await provider.loadFromPrefs();
    return provider;
  }
}
