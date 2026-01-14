import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/auth_service.dart';

class AuthProvider with ChangeNotifier {
  late SharedPreferences _prefs;

  bool _isLoading = false;
  String? _error;
  String? _token;
  bool _isAuthenticated = false;
  bool _isInitializing = true;
  String? _userEmail;
  int? _userId;

  bool get isLoading => _isLoading;
  bool get isInitializing => _isInitializing;
  String? get error => _error;
  bool get isAuthenticated => _isAuthenticated;
  String? get token => _token;
  String? get userEmail => _userEmail;
  int? get userId => _userId;

  AuthProvider() {
    _initialize();
  }

  Future<void> _initialize() async {
    print('🔄 Инициализация AuthProvider...');
    _prefs = await SharedPreferences.getInstance();
    await _loadAuthData();
    _isInitializing = false;
    notifyListeners();
    print('✅ AuthProvider инициализирован');
  }

  Future<void> _loadAuthData() async {
    try {
      _token = _prefs.getString('auth_token');
      _userEmail = _prefs.getString('user_email');
      _userId = _prefs.getInt('user_id');

      print('📦 Загружаю сохраненные данные:');
      print('   Токен: ${_token != null ? "Есть" : "Нет"}');
      print('   Email: $_userEmail');
      print('   User ID: $_userId');

      if (_token != null && _token!.isNotEmpty) {
        _isAuthenticated = true;
        print('✅ Пользователь аутентифицирован (из сохраненных данных)');
      } else {
        print('ℹ️ Пользователь не аутентифицирован');
      }
    } catch (e) {
      print('❌ Ошибка загрузки данных: $e');
    }
  }

  Future<void> _saveAuthData(String token, String email, int userId) async {
    try {
      await _prefs.setString('auth_token', token);
      await _prefs.setString('user_email', email);
      await _prefs.setInt('user_id', userId);

      _token = token;
      _userEmail = email;
      _userId = userId;
      _isAuthenticated = true;

      print('💾 Данные сохранены:');
      print('   Email: $email');
      print('   User ID: $userId');
      print('   Токен сохранен: ${token.substring(0, 30)}...');
    } catch (e) {
      print('❌ Ошибка сохранения данных: $e');
    }
  }

  Future<void> _clearAuthData() async {
    try {
      await _prefs.remove('auth_token');
      await _prefs.remove('user_email');
      await _prefs.remove('user_id');

      _token = null;
      _userEmail = null;
      _userId = null;
      _isAuthenticated = false;

      print('🗑️ Данные пользователя очищены');
    } catch (e) {
      print('❌ Ошибка очистки данных: $e');
    }
  }

  Future<void> register(String email, String password) async {
    print('🚀 Начало регистрации: $email');
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      print('📤 Отправляю запрос регистрации...');
      final response = await AuthService().register(email, password);

      print('📥 Ответ регистрации: ${response.success}');

      if (response.success) {
        print('✅ Регистрация успешна! Выполняю auto-login...');

        await login(email, password);
      } else {
        _error = response.message;
        print('❌ Ошибка регистрации: $_error');
      }
    } catch (e) {
      _error = 'Ошибка сети: $e';
      print('🔥 Ошибка регистрации: $_error');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> login(String email, String password) async {
    print('🔐 Начало входа: $email');
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      print('📤 Отправляю запрос входа...');
      final response = await AuthService().login(email, password);

      print('📥 Ответ входа: ${response.success}');
      print('📊 Данные ответа: ${response.data}');

      if (response.success) {
        final data = response.data;
        if (data != null && data['access_token'] != null) {
          final token = data['access_token'];
          final userId = data['user_id'] ?? 0;

          await _saveAuthData(token, email, userId);

          print('🎉 Вход выполнен успешно!');
          print('   User ID: $userId');
          print('   Token: ${token.substring(0, 30)}...');

          notifyListeners();
        } else {
          _error = 'Токен не получен';
          print('❌ Ошибка: $_error');
          print('❌ Данные ответа: $data');
        }
      } else {
        _error = response.message;
        print('❌ Ошибка входа: $_error');
      }
    } catch (e) {
      _error = 'Ошибка сети: $e';
      print('🔥 Ошибка входа: $_error');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> logout() async {
    print('🚪 Выход из системы...');

    await _clearAuthData();

    _error = null;
    notifyListeners();

    print('✅ Выход выполнен, все данные очищены');
  }
}
