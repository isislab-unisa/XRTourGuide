import 'package:dio/dio.dart';
import 'secure_storage_service.dart';
import 'auth_service.dart';

class ApiService {
  final Dio _dio;
  final SecureStorageService _storageService = SecureStorageService();
  final AuthService _authService = AuthService();

  ApiService() : _dio = Dio(BaseOptions(baseUrl: 'http://172.16.15.148:80')) {
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {

          final excludedPaths = [
            '/api/token/',
            '/api/token/refresh/',
            '/register/',
          ];

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
    try {
      final response = await dio.post(
        '/api/token/',
        data: {'username': email, 'password': password},
      );
      return response;
    } catch (e) {
      print('Failed to login: $e');
      rethrow;
    }
  }

  Future<Response> register(String username, String password, String name, String surname, String mail, String description, String city) async {
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


}
