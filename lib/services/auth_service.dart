import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../models/user_model.dart';
import '../utils/api_config.dart';

class AuthService {
  // Singleton
  AuthService._privateConstructor();
  static final AuthService instance = AuthService._privateConstructor();

  final String _baseUrl = '${ApiConfig.baseUrl}/auth';

  // SharedPreferences keys
  static const String _keyToken = 'auth_token';
  static const String _keyUsername = 'auth_username';
  static const String _keyRole = 'auth_role';

  String? _token;
  String? _username;
  String? _role;

  // ─── Getters ──────────────────────────────────────────────

  String? get token => _token;
  String? get username => _username;
  String? get role => _role;
  bool get isLoggedIn => _token != null && _token!.isNotEmpty;
  bool get isParent => _role == 'parent';
  bool get isChild => _role == 'child';

  Map<String, String> get authHeaders => {
        'Content-Type': 'application/json',
        if (_token != null) 'Authorization': 'Bearer $_token',
      };

  // ─── Initialise (load persisted session) ──────────────────

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _token = prefs.getString(_keyToken);
    _username = prefs.getString(_keyUsername);
    _role = prefs.getString(_keyRole);
    debugPrint('🔐 AuthService init — logged in: $isLoggedIn, role: $_role');
  }

  // ─── Signup ───────────────────────────────────────────────

  /// Registers a new parent account. Returns a success message.
  /// The backend sends a verification email automatically.
  Future<String> signup(String username, String email, String password) async {
    final response = await http.post(
      Uri.parse('$_baseUrl/signup'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'username': username,
        'email': email,
        'password': password,
      }),
    );

    final body = jsonDecode(response.body);

    if (response.statusCode == 201) {
      return body['message'] as String? ?? 'Registration successful';
    } else {
      throw Exception(
        body['error'] ?? body['message'] ?? 'Signup failed',
      );
    }
  }

  // ─── Login ────────────────────────────────────────────────

  /// Logs in with username/email + password.
  /// Persists the JWT token, username, and role.
  Future<UserModel> login(String identifier, String password) async {
    final response = await http.post(
      Uri.parse('$_baseUrl/login'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'identifier': identifier,
        'password': password,
      }),
    );

    final body = jsonDecode(response.body);

    if (response.statusCode == 200) {
      final user = UserModel.fromJson(body);
      await _persistSession(user);
      return user;
    } else {
      throw Exception(
        body['error'] ?? body['message'] ?? 'Login failed',
      );
    }
  }

  // ─── Forgot Password ─────────────────────────────────────

  /// Sends a password reset email.
  Future<String> forgotPassword(String email) async {
    final response = await http.post(
      Uri.parse('$_baseUrl/forgot-password'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email}),
    );

    final body = jsonDecode(response.body);

    if (response.statusCode == 200) {
      return body['message'] as String? ?? 'Reset link sent';
    } else {
      throw Exception(
        body['error'] ?? body['message'] ?? 'Request failed',
      );
    }
  }

  // ─── Get User Profile ─────────────────────────────────────

  /// Fetches user profile (requires auth).
  Future<Map<String, dynamic>> getUser(String username) async {
    final response = await http.get(
      Uri.parse('$_baseUrl/$username'),
      headers: authHeaders,
    );

    final body = jsonDecode(response.body);

    if (response.statusCode == 200) {
      return body as Map<String, dynamic>;
    } else {
      throw Exception(
        body['error'] ?? body['message'] ?? 'Failed to fetch user',
      );
    }
  }

  // ─── Register Child ───────────────────────────────────────

  /// Registers a child account (parent-only, requires auth + verified).
  Future<Map<String, dynamic>> registerChild(
    String username,
    String email,
    String password,
  ) async {
    final response = await http.post(
      Uri.parse('$_baseUrl/children'),
      headers: authHeaders,
      body: jsonEncode({
        'username': username,
        'email': email,
        'password': password,
      }),
    );

    final body = jsonDecode(response.body);

    if (response.statusCode == 201) {
      return body as Map<String, dynamic>;
    } else {
      throw Exception(
        body['error'] ?? body['message'] ?? 'Child registration failed',
      );
    }
  }

  /// Fetches the list of children for the authenticated parent.
  Future<List<Map<String, dynamic>>> getChildren() async {
    final response = await http.get(
      Uri.parse('$_baseUrl/children'),
      headers: authHeaders,
    );

    final body = jsonDecode(response.body);

    if (response.statusCode == 200) {
      final List<dynamic> list = body['children'] ?? [];
      return list.cast<Map<String, dynamic>>();
    } else {
      throw Exception(
        body['error'] ?? body['message'] ?? 'Failed to fetch children',
      );
    }
  }

  // ─── Logout ───────────────────────────────────────────────

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyToken);
    await prefs.remove(_keyUsername);
    await prefs.remove(_keyRole);
    _token = null;
    _username = null;
    _role = null;
    debugPrint('🔓 Logged out');
  }

  // ─── Internal helpers ─────────────────────────────────────

  Future<void> _persistSession(UserModel user) async {
    _token = user.token;
    _username = user.username;
    _role = user.role;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyToken, user.token);
    await prefs.setString(_keyUsername, user.username);
    await prefs.setString(_keyRole, user.role);
  }
}
