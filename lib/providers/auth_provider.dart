import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AuthProvider with ChangeNotifier {
  static const _tokenKey = 'token';
  static const _userKey = 'user';
  static const _selectedCountryKey = 'selected_country_id';
  static const _selectedCountryNameKey = 'selected_country_name';

  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();

  String? _token;
  Map<String, dynamic>? _user;
  int? _selectedCountryId;
  String? _selectedCountryName;

  AuthProvider({String? token, Map<String, dynamic>? user}) {
    _token = token;
    _user = user;
  }

  String? get token => _token;
  Map<String, dynamic>? get user => _user;
  int? get selectedCountryId => _selectedCountryId;
  String? get selectedCountryName => _selectedCountryName;
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

  Future<void> updateUser(Map<String, dynamic>? user) async {
    _user = user;
    try {
      final prefs = await SharedPreferences.getInstance();
      if (user != null) await prefs.setString(_userKey, jsonEncode(user));
    } catch (e) {
      if (kDebugMode) {
        // ignore: avoid_print
        print('AuthProvider: could not persist user update: $e');
      }
    }
    notifyListeners();
  }

  /// Set selected country id and optional name (persist and notify)
  Future<void> setSelectedCountry(int? countryId, {String? countryName}) async {
    _selectedCountryId = countryId;
    _selectedCountryName = countryName;
    try {
      final prefs = await SharedPreferences.getInstance();
      if (countryId == null) {
        await prefs.remove(_selectedCountryKey);
        await prefs.remove(_selectedCountryNameKey);
      } else {
        await prefs.setInt(_selectedCountryKey, countryId);
        if (countryName != null) {
          await prefs.setString(_selectedCountryNameKey, countryName);
        }
      }
    } catch (e) {
      if (kDebugMode)
        print('AuthProvider: could not persist selected country: $e');
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
      final countryId = prefs.getInt(_selectedCountryKey);
      final countryName = prefs.getString(_selectedCountryNameKey);
      _selectedCountryId = countryId;
      _selectedCountryName = countryName;
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
