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

  /// Sends a 6-digit password reset code to the user's email.
  Future<String> forgotPassword(String email) async {
    final response = await http.post(
      Uri.parse('$_baseUrl/forgot-password'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email.trim().toLowerCase()}),
    );

    final body = jsonDecode(response.body);

    if (response.statusCode == 200) {
      return body['message'] as String? ?? 'Verification code sent';
    } else {
      throw Exception(
        body['error'] ?? body['message'] ?? 'Request failed',
      );
    }
  }

  /// Resets password using the email verification code.
  Future<String> resetPasswordWithCode({
    required String email,
    required String code,
    required String newPassword,
  }) async {
    final response = await http.post(
      Uri.parse('$_baseUrl/reset-password'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'email': email.trim().toLowerCase(),
        'code': code.trim(),
        'newPassword': newPassword,
      }),
    );

    final body = jsonDecode(response.body);

    if (response.statusCode == 200) {
      return body['message'] as String? ?? 'Password reset successfully';
    } else {
      throw Exception(
        body['error'] ?? body['message'] ?? 'Password reset failed',
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

  /// Fetches the authenticated user's profile.
  Future<Map<String, dynamic>> getProfile() async {
    final response = await http.get(
      Uri.parse('$_baseUrl/me'),
      headers: authHeaders,
    );
    final body = jsonDecode(response.body);
    if (response.statusCode == 200) {
      return body['user'] as Map<String, dynamic>;
    }
    throw Exception(body['error'] ?? body['message'] ?? 'Failed to load profile');
  }

  /// Updates username and/or email. Requires current password.
  Future<Map<String, dynamic>> updateProfile({
    String? username,
    String? email,
    required String currentPassword,
  }) async {
    final response = await http.put(
      Uri.parse('$_baseUrl/me'),
      headers: authHeaders,
      body: jsonEncode({
        if (username != null) 'username': username,
        if (email != null) 'email': email,
        'currentPassword': currentPassword,
      }),
    );
    final body = jsonDecode(response.body);
    if (response.statusCode == 200) {
      if (body['token'] != null) {
        await _updateSession(
          token: body['token'] as String,
          username: body['username'] as String? ?? _username!,
          role: body['role'] as String? ?? _role!,
        );
      }
      return body as Map<String, dynamic>;
    }
    throw Exception(body['error'] ?? body['message'] ?? 'Failed to update profile');
  }

  /// Changes the account password.
  Future<String> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    final response = await http.put(
      Uri.parse('$_baseUrl/me/password'),
      headers: authHeaders,
      body: jsonEncode({
        'currentPassword': currentPassword,
        'newPassword': newPassword,
      }),
    );
    final body = jsonDecode(response.body);
    if (response.statusCode == 200) {
      return body['message'] as String? ?? 'Password changed successfully';
    }
    throw Exception(body['error'] ?? body['message'] ?? 'Failed to change password');
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

  /// Fetches a child's profile (parent-only).
  Future<Map<String, dynamic>> getChildProfile(String childId) async {
    final response = await http.get(
      Uri.parse('$_baseUrl/children/$childId/profile'),
      headers: authHeaders,
    );
    final body = jsonDecode(response.body);
    if (response.statusCode == 200) {
      return body['user'] as Map<String, dynamic>;
    }
    throw Exception(body['error'] ?? body['message'] ?? 'Failed to load child profile');
  }

  /// Updates a child's username and/or email (parent-only).
  Future<Map<String, dynamic>> updateChildProfile(
    String childId, {
    String? username,
    String? email,
  }) async {
    final response = await http.put(
      Uri.parse('$_baseUrl/children/$childId/profile'),
      headers: authHeaders,
      body: jsonEncode({
        if (username != null) 'username': username,
        if (email != null) 'email': email,
      }),
    );
    final body = jsonDecode(response.body);
    if (response.statusCode == 200) {
      return body as Map<String, dynamic>;
    }
    throw Exception(body['error'] ?? body['message'] ?? 'Failed to update child profile');
  }

  /// Resets a child's password (parent-only).
  Future<String> resetChildPassword(String childId, String newPassword) async {
    final response = await http.put(
      Uri.parse('$_baseUrl/children/$childId/password'),
      headers: authHeaders,
      body: jsonEncode({'newPassword': newPassword}),
    );
    final body = jsonDecode(response.body);
    if (response.statusCode == 200) {
      return body['message'] as String? ?? 'Child password updated successfully';
    }
    throw Exception(body['error'] ?? body['message'] ?? 'Failed to reset child password');
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
    await _updateSession(token: user.token, username: user.username, role: user.role);
  }

  Future<void> _updateSession({
    required String token,
    required String username,
    required String role,
  }) async {
    _token = token;
    _username = username;
    _role = role;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyToken, token);
    await prefs.setString(_keyUsername, username);
    await prefs.setString(_keyRole, role);
  }
}
