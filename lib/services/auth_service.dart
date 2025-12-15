import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

class AuthService {
  static const String _usersKey = 'registered_users';
  static const String _currentUserKey = 'current_user';
  static const String _isLoggedInKey = 'is_logged_in';

  // ============================
  // REGISTER USER
  // ============================
  static Future<Map<String, dynamic>> register({
    required String name,
    required String email,
    required String password,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Get existing users
      List<Map<String, dynamic>> users = await _getUsers();

      // Check if email already exists
      bool emailExists = users.any((user) => user['email'] == email);
      if (emailExists) {
        return {
          'success': false,
          'message': 'Email sudah terdaftar',
        };
      }

      // Add new user
      Map<String, dynamic> newUser = {
        'name': name,
        'email': email,
        'password': password, // In production, hash this!
        'createdAt': DateTime.now().toIso8601String(),
      };

      users.add(newUser);

      // Save users
      await prefs.setString(_usersKey, json.encode(users));

      return {
        'success': true,
        'message': 'Registrasi berhasil! Silakan login.',
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'Error: $e',
      };
    }
  }

  // ============================
  // LOGIN USER
  // ============================
  static Future<Map<String, dynamic>> login({
    required String email,
    required String password,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Get existing users
      List<Map<String, dynamic>> users = await _getUsers();

      // Find user
      Map<String, dynamic>? user = users.firstWhere(
            (user) => user['email'] == email && user['password'] == password,
        orElse: () => {},
      );

      if (user.isEmpty) {
        return {
          'success': false,
          'message': 'Email atau password salah',
        };
      }

      // Save current user and login status
      await prefs.setString(_currentUserKey, json.encode(user));
      await prefs.setBool(_isLoggedInKey, true);

      return {
        'success': true,
        'message': 'Login berhasil!',
        'user': user,
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'Error: $e',
      };
    }
  }

  // ============================
  // LOGOUT USER
  // ============================
  static Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_currentUserKey);
    await prefs.setBool(_isLoggedInKey, false);
  }

  // ============================
  // CHECK LOGIN STATUS
  // ============================
  static Future<bool> isLoggedIn() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_isLoggedInKey) ?? false;
  }

  // ============================
  // GET CURRENT USER
  // ============================
  static Future<Map<String, dynamic>?> getCurrentUser() async {
    final prefs = await SharedPreferences.getInstance();
    String? userJson = prefs.getString(_currentUserKey);

    if (userJson == null) return null;

    return json.decode(userJson);
  }

  // ============================
  // HELPER: GET ALL USERS
  // ============================
  static Future<List<Map<String, dynamic>>> _getUsers() async {
    final prefs = await SharedPreferences.getInstance();
    String? usersJson = prefs.getString(_usersKey);

    if (usersJson == null) return [];

    List<dynamic> usersList = json.decode(usersJson);
    return usersList.cast<Map<String, dynamic>>();
  }

  // ============================
  // VALIDATION HELPERS
  // ============================
  static String? validateEmail(String? value) {
    if (value == null || value.isEmpty) {
      return 'Email tidak boleh kosong';
    }

    final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
    if (!emailRegex.hasMatch(value)) {
      return 'Format email tidak valid';
    }

    return null;
  }

  static String? validatePassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Password tidak boleh kosong';
    }

    if (value.length < 6) {
      return 'Password minimal 6 karakter';
    }

    return null;
  }

  static String? validateName(String? value) {
    if (value == null || value.isEmpty) {
      return 'Nama tidak boleh kosong';
    }

    if (value.length < 3) {
      return 'Nama minimal 3 karakter';
    }

    return null;
  }
}