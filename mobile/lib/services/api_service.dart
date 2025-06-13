import 'package:dio/dio.dart';
import 'secure_storage_service.dart';
import 'auth_service.dart';

class ApiService {
  final Dio _dio;
  final SecureStorageService _storageService = SecureStorageService();
  final AuthService _authService = AuthService();

  final excludedPaths = [
  '/api/token/',
  '/api/token/refresh/',
  '/register/',
  ];


  ApiService() : _dio = Dio(BaseOptions(baseUrl: 'http://172.16.15.146:80')) {
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {

          print("Request: ${options.method} ${options.path}");

          if (excludedPaths.any((path) => options.path.startsWith(path))) {
            return handler.next(options); // Skip adding token for excluded paths
          }

          final accessToken = await _storageService.getAccessToken();
          if (accessToken != null) {
            options.headers['Authorization'] = 'Bearer $accessToken';
          }
          return handler.next(options);
        },
        onError: (DioException e, handler) async {
          if (excludedPaths.any((path) => e.requestOptions.path.startsWith(path))) {
              return handler.next(e); // Salta il refresh per questi endpoint
          }

          print("Error Refresh: ${e.message}");
          if (e.response?.statusCode == 401) {
            final newAccessToken = await _refreshToken();
            if (newAccessToken != null) {
              e.requestOptions.headers['Authorization'] =
                  'Bearer $newAccessToken';
              return handler.resolve(await _dio.fetch(e.requestOptions));
            }
          }
          return handler.next(e);
        },
      ),
    );
  }

  Dio get dio => _dio;

  Future<String?> _refreshToken() async {
    try {
      final refreshToken = await _storageService.getRefreshToken();
      if (refreshToken == null) return null;

      final response = await _dio.post(
        '/api/token/refresh/',
        data: {'refresh': refreshToken},
      );
      final newAccessToken = response.data['access'];
      // final newRefreshToken = response.data['refreshToken'];

      await _storageService.saveTokens(
        accessToken: newAccessToken,
        refreshToken: refreshToken,
      );
      return newAccessToken;
    } catch (e) {
      // If refresh fails, log the user out
      await _storageService.deleteAllTokens();
      await _authService.logout();
      return null;
    }
  }

  Future<Response> getProfileDetails() async {
    try {
      final response = await dio.get(
        '/profile_details/',
      );
      return response;
    } catch (e) {
      print('Failed to fetch profile details: $e');
      rethrow;
    }
  }

  Future<Response> login(String email, String password) async {
    //TODO Vedere come criptare la password durante la chiamata
    try {
      final response = await dio.post(
        '/api/token/',
        data: {'username': email, 'password': password},
        options: Options(
          validateStatus: (status) => status == 200 || status == 401, // Allow 401 for invalid credentials
        ),
      );
      return response;
    } catch (e) {
      print('Failed to login: $e');
      rethrow;
    }
  }

  Future<Response> register(String username, String password, String name, String surname, String mail, String description, String city) async {
    //TODO Vedere come criptare la password durante la chiamata
    try {
      final response = await dio.post(
        '/register/',
        data: {
          'username': username,
          'password': password,
          'first_name': name,
          'last_name': surname,
          'email': mail,
          'description': description,
          'city': city,
        },
      );
      return response;
    } catch (e) {
      print('Failed to register: $e');
      rethrow;
    }
  }

  Future<Response> updateAccount(String name, String surname, String mail, String description) async {
    try {
      final response = await dio.post(
        '/update_profile/',
        data: {
          'firstName': name,
          'lastName': surname,
          'description': description,
          'email': mail,
        },
      );
      return response;
    } catch (e) {
      print('Failed to update profile: $e');
      rethrow;
    }
  }


  Future<Response> updatePassword(String oldPassword, String newPassword) async {
    //TODO Vedere come criptare la password durante la chiamata
    try {
      final response = await dio.post(
        '/update_password/',
        data: {
          'oldPassword': oldPassword,
          'newPassword': newPassword,
        },
      );
      return response;
    } catch (e) {
      print('Failed to update password: $e');
      rethrow;
    }
  }

  Future<Response> deleteAccount(String password) async {
    //TODO Vedere come criptare la password durante la chiamata
    try {
      final response = await dio.post(
        '/delete_account/',
        data: {
          'password': password,
        },
      );
      return response;
    } catch (e) {
      print('Failed to delete profile: $e');
      rethrow;
    }
  }
  
  Future<Response> getNearbyTours() async {
    try {
      final response = await dio.get('/tour_list/');
      return response;
    } catch (e) {
      print('Failed to fetch tours: $e');
      rethrow;
    }
  }



}
