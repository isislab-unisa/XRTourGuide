import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'secure_storage_service.dart';
import 'package:dio/dio.dart';
import 'api_service.dart';

enum AuthStatus { authenticated, unauthenticated, loading, registering }

final authServiceProvider = ChangeNotifierProvider<AuthService>((ref) {
  return AuthService(ref);
});

final apiServiceProvider = Provider<ApiService>((ref) {
  return ApiService(ref);
});


class AuthService extends ChangeNotifier {
  final Ref ref;
  late final ApiService apiService;
  final SecureStorageService _storageService = SecureStorageService();
  AuthStatus _authStatus = AuthStatus.loading;
  AuthStatus get authStatus => _authStatus;

  String? _loginErrorMessage;
  String? get loginErrorMessage=> _loginErrorMessage;


  AuthService(this.ref) {
    apiService = ref.read(apiServiceProvider);
    _checkAuthStatus();
  }

  // Future<void> _checkAuthStatus() async {
  //   final accessToken = await _storageService.getAccessToken();
  //   if (accessToken != null) {
  //     _authStatus = AuthStatus.authenticated;
  //   } else {
  //     _authStatus = AuthStatus.unauthenticated;
  //   }
  //   notifyListeners();
  // }

  Future<void> _checkAuthStatus() async {
    _authStatus = AuthStatus.loading;
    notifyListeners();

    final accessToken = await _storageService.getAccessToken();
    final refreshToken = await _storageService.getRefreshToken();

    final serverUp = await apiService.pingServer(timeout: const Duration(seconds: 2));

    if (serverUp) {
      if (refreshToken != null) {
        final refreshed = await _refreshAccessTokenSilently(timeout: const Duration(seconds: 5));
        if (refreshed) {
          _authStatus = AuthStatus.authenticated;
        } else {
          await _storageService.deleteAllTokens();
          _authStatus = AuthStatus.unauthenticated;
        }
      } else {
        _authStatus = AuthStatus.unauthenticated;
      }
    } else {
      if (accessToken != null) {
        _authStatus = AuthStatus.authenticated;
      } else {
        _authStatus = AuthStatus.unauthenticated;
      }
    }
    notifyListeners();
  }

  Future<bool> _refreshAccessTokenSilently({Duration timeout = const Duration(seconds: 4)}) async{
    try{
      final refreshToken = await _storageService.getRefreshToken();
      if (refreshToken == null) return false;

      final response = await apiService.dio.post(
        '/api/token/refresh/',
        data: {"refresh": refreshToken},
        options: Options(
          validateStatus: (s) => s == 200 || s == 401,
          sendTimeout: timeout,
          receiveTimeout: timeout,
        ),
      );

      if (response.statusCode == 200){
        final newAccess = response.data["access"] as String?;
        if (newAccess == null) return false;
        await _storageService.saveTokens(accessToken: newAccess, refreshToken: refreshToken);
        return true;
      }
      return false;
    }catch (e) {
      return false;
    }
  }

  Future<void> login(String email, String password) async {
    // _authStatus = AuthStatus.loading;
    // notifyListeners();

    try {
      final response = await apiService.login(email, password);
      if (response.statusCode == 401) {
        // _authStatus = AuthStatus.unauthenticated;
        _loginErrorMessage = "Email or password is incorrect";
        // notifyListeners();
        throw Exception(_loginErrorMessage);
      }

      final accessToken = response.data['access'];
      final refreshToken = response.data['refresh'];

      await _storageService.saveTokens(
        accessToken: accessToken,
        refreshToken: refreshToken,
      );
      _authStatus = AuthStatus.authenticated;
      notifyListeners();
    } catch (e) {
      print("Login Error: $e");
      // _authStatus = AuthStatus.unauthenticated;
      _loginErrorMessage ??= "An error occurred during login. Please try again.";
      // notifyListeners();
      rethrow;
    }
  }

  Future<void> register(String username, String password, String name, String surname, String mail, String description, String city) async {
    _authStatus = AuthStatus.loading;
    notifyListeners();

    try {
      // final response = await dio.post('/register/',
      //  data: {'username': username, 'password': password, 'first_name': name, 'last_name': surname, 'email': mail, 'description': description, 'city': city});
      final response = await apiService.register(
        username,
        password,
        name,
        surname,
        mail,
        description,
        city,
      );
      // Simulate a network request
      // await Future.delayed(const Duration(seconds: 1));


      _authStatus = AuthStatus.registering;
    } catch (e) {
      _authStatus = AuthStatus.unauthenticated;
    }
    notifyListeners();
  }

  Future<void> deleteAccount(
    String password,
  ) async {

    try {
      final response = await apiService.deleteAccount(
        password,
      );
      _authStatus = AuthStatus.unauthenticated;
    } catch (e) {
      print("Delete account error: $e");
      _authStatus = AuthStatus.authenticated;
    }
    notifyListeners();
  }

  Future<void> updatePassword(String oldPassword, String newPassword) async {
    try {
      final response = await apiService.updatePassword(oldPassword, newPassword);
    } catch (e) {
      print("Change Password error: $e");
    }
  }

  Future<void> updateAccount(String firstName, String lastName, String mail, String description) async {
    try {
      final response = await apiService.updateAccount(
        firstName,
        lastName,
        mail,
        description,
      );
    } catch (e) {
      print("Update Account error: $e");
    }
  }

  Future<Response> resetPassword(String email) async {
    try {
      final response = await apiService.resetPassword(email);
      return response;
      // Handle response if needed
    } catch (e) {
      print("Reset Password error: $e");
      rethrow;
    }
  }


  Future<void> logout() async {
    print("Logout Called");
    _authStatus = AuthStatus.loading;
    notifyListeners();

    await _storageService.deleteAllTokens();
    _authStatus = AuthStatus.unauthenticated;
    notifyListeners();
  }
}
