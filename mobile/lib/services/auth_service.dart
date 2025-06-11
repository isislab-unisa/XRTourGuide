import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'secure_storage_service.dart';
import 'package:dio/dio.dart';

enum AuthStatus { authenticated, unauthenticated, loading, registering }

final authServiceProvider = ChangeNotifierProvider<AuthService>((ref) {
  return AuthService();
});

final dio = Dio(BaseOptions(baseUrl: 'http://172.16.15.149:80'));

class AuthService extends ChangeNotifier {
  final SecureStorageService _storageService = SecureStorageService();
  AuthStatus _authStatus = AuthStatus.loading;
  AuthStatus get authStatus => _authStatus;

  AuthService() {
    _checkAuthStatus();
  }

  Future<void> _checkAuthStatus() async {
    final accessToken = await _storageService.getAccessToken();
    if (accessToken != null) {
      _authStatus = AuthStatus.authenticated;
    } else {
      _authStatus = AuthStatus.unauthenticated;
    }
    notifyListeners();
  }

  Future<void> login(String email, String password) async {
    _authStatus = AuthStatus.loading;
    notifyListeners();

    try {
      final response = await dio.post('/api/token/', data: {'username': email, 'password': password});
      final accessToken = response.data['access'];
      final refreshToken = response.data['refresh'];

      //TODO: Gestire errore 401 per username e o password sbagliati

      await _storageService.saveTokens(
        accessToken: accessToken,
        refreshToken: refreshToken,
      );
      _authStatus = AuthStatus.authenticated;
    } catch (e) {
      print("Login error: $e");
      _authStatus = AuthStatus.unauthenticated;
    }
    notifyListeners();
  }

  Future<void> register(String username, String password, String name, String surname, String mail, String description, String city) async {
    _authStatus = AuthStatus.loading;
    notifyListeners();

    try {
      //TODO: Replace with actual API call
      final response = await dio.post('/register/',
       data: {'username': username, 'password': password, 'first_name': name, 'last_name': surname, 'email': mail, 'description': description, 'city': city});
      // final accessToken = response.data['accessToken'];
      // final refreshToken = response.data['refreshToken'];

      // Simulate a network request
      // await Future.delayed(const Duration(seconds: 1));


      _authStatus = AuthStatus.registering;
    } catch (e) {
      _authStatus = AuthStatus.unauthenticated;
    }
    notifyListeners();
  }

  Future<void> logout() async {
    _authStatus = AuthStatus.loading;
    notifyListeners();

    await _storageService.deleteAllTokens();
    _authStatus = AuthStatus.unauthenticated;
    notifyListeners();
  }
}
