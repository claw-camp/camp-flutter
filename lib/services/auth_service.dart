import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class AuthService extends ChangeNotifier {
  static const _baseUrl = 'http://119.91.123.2';
  static const _keyUsername = 'camp_username';
  static const _keyCampKey = 'camp_key';

  String? _campKey;
  String? _username;
  bool _initialized = false;

  String? get campKey => _campKey;
  String? get username => _username;
  bool get isLoggedIn => _campKey != null;

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _campKey = prefs.getString(_keyCampKey);
    _username = prefs.getString(_keyUsername);
    _initialized = true;
    notifyListeners();
  }

  // 用 campKey 直接登录（跳过 username/password）
  Future<void> loginWithCampKey(String campKey) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyCampKey, campKey);
    await prefs.setString(_keyUsername, 'user');
    _campKey = campKey;
    _username = 'user';
    notifyListeners();
  }

  // 用 username + password 登录
  Future<Map<String, dynamic>> loginWithPassword(String username, String password) async {
    final res = await http.post(
      Uri.parse('$_baseUrl/api/login'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'username': username, 'password': password}),
    );
    final data = jsonDecode(res.body);
    if (res.statusCode == 200 && data['success'] == true) {
      final key = data['user']['campKey'] as String;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_keyCampKey, key);
      await prefs.setString(_keyUsername, username);
      _campKey = key;
      _username = username;
      notifyListeners();
      return {'success': true};
    }
    return {'success': false, 'error': data['error'] ?? '登录失败'};
  }

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyCampKey);
    await prefs.remove(_keyUsername);
    _campKey = null;
    _username = null;
    notifyListeners();
  }
}
