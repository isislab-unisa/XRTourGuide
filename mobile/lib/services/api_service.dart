import 'package:dio/dio.dart';
import "dart:io";
import 'secure_storage_service.dart';
import 'auth_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';


class ApiService {
  final Dio _dio;
  final SecureStorageService _storageService = SecureStorageService();
  final Ref ref;
  // final AuthService _authService = AuthService();


  final excludedPaths = [
  '/api/token/',
  '/api/token/refresh/',
  '/register/',
  '/tour_list/',
  '/get_waypoint_resources/',
  ];

  // static const String basicUrl = 'http://172.16.15.145:80';
  static const String basicUrl = 'http://172.16.15.145:80';


  ApiService(this.ref) : _dio = Dio(BaseOptions(baseUrl: basicUrl)) {
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {

          print("Request: ${options.method} ${options.path}");

          if (excludedPaths.any((path) => options.path.startsWith(path))) {
            print("Skipping bearer token");
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
            String? newAccessToken = "";
            try {
              newAccessToken = await _refreshToken();
            }catch (refreshError) {
              print("Refresh Token Error: $refreshError");
              // If refresh fails, log the user out
              // await _storageService.deleteAllTokens();
              await ref.read(authServiceProvider).logout();
              return handler.reject(e); // Reject the error after logout
            }
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
      if (refreshToken == null) {
        await ref.read(authServiceProvider).logout();
        return null; // No refresh token available, user should be logged out
      }

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
      print("Refresh Token Error: $e");
      await ref.read(authServiceProvider).logout();
      return null;
    }
  }

  Future<bool> pingServer({Duration timeout = const Duration(seconds: 2)}) async {

    final uri = Uri.parse(dio.options.baseUrl);
    final host = uri.host;
    final port = uri.hasPort ? uri.port : (uri.scheme == "https" ? 443 : 80);

    print("URI: ${uri}");
    print("HOST: ${host}");
    print("PORT: ${port}");

    try {
      final socket = await Socket.connect(host, port, timeout: timeout);
      socket.destroy();
    } catch (e) {
      print('Ping failed: $e');
      return false;
    }

    try {
      final response = await dio.head(
        "/tour_list/",
        options: Options(
          sendTimeout: timeout,
          receiveTimeout: timeout,
          validateStatus: (status) => status != null && status < 600, // Accept any status code less than 500
        ),
      );
      return true;
    } on DioException catch(e) {
      if (e.type == DioExceptionType.sendTimeout || e.type == DioExceptionType.receiveTimeout) {
        print('Ping timeout: $e');
        return false;
      } 
      return true;
    } catch (_) {
      return false;
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

  Future<Response> resetPassword(String email) async {
    try {
      final response = await dio.post(
        '/forgot-password/',
        data: {
          'email': email,
        },
      );
      return response;
    } catch (e) {
      print('Failed to reset password: $e');
      rethrow;
    }
  }

  Future<Response> deleteAccount(String password) async {
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
  
  Future<Response> getAllNearbyTours(int timeout) async {
    try {
      Response response;
      if (timeout > 0) {
        response = await dio.get("/tour_list/", options: Options(sendTimeout: Duration(seconds: timeout)));
      } else {
        response = await dio.get('/tour_list/');
      }
      return response;
    } catch (e) {
      print('Failed to fetch tours: $e');
      rethrow;
    }
  }

  Future<Response> getNearbyTours(int timeout, double latitude, double longitude) async {
    try {
      Response response;
      if (timeout > 0) {
        response = await dio.get(
          "/tour_list/?lon=$longitude&lat=$latitude",
          options: Options(sendTimeout: Duration(seconds: timeout)),
        );
      } else {
        response = await dio.get('/tour_list/?lon=$longitude&lat=$latitude');
      }
      return response;
    } catch (e) {
      print('Failed to fetch tours: $e');
      rethrow;
    }
  }


  Future<Response> getTourBySearchTerm(String searchTerm) async {
    try {
      final response = await dio.get("/tour_list/?searchTerm=$searchTerm");
      return response;
    } catch (e) {
      print('Failed to fetch tours: $e');
      rethrow;
    }
  }


  Future<Response> getTourByCategory(String category) async {
    try {
      final response = await dio.get("/tour_list/?category=$category");
      return response;
    } catch (e) {
      print('Failed to fetch tours: $e');
      rethrow;
    }
  }


  Future<Response> getTourDetails(int tourId) async {
    try {
      final response = await dio.get('/tour_details/$tourId/');
      return response;
    } catch (e) {
      print('Failed to fetch tour details: $e');
      rethrow;
    }
  }

  Future<Response> getTourReviews(int tourId) async {
    try {
      final response = await dio.get('/get_reviews_by_tour_id/$tourId/');
      return response;
    } catch (e) {
      print('Failed to fetch tour reviews: $e');
      rethrow;
    }
  }

  Future<Response> getUserReviews() async {
    try {
      final response = await dio.get('/get_reviews_by_user');
      return response;
    } catch (e) {
      print('Failed to fetch tour reviews: $e');
      rethrow;
    }
  }



  Future<Response> getTourWaypoints(int tourId) async {
    try {
      final response = await dio.get('/tour_waypoints/$tourId');
      return response;
    } catch (e) {
      print('Failed to fetch tour categories: $e');
      rethrow;
    }
  }

  Future<Response> incrementTourViews(int waypointId) async {
    try {
      final response = await dio.post('/increment_view_count/',
      data: {
        'tour_id': waypointId,
      });
      return response;
    } catch (e) {
      print('Failed to incvrement tour views: $e');
      rethrow;
    }
  }

  Future<Response> leaveReview(int tourId, double rating, String comment) async {
    try {
      final response = await dio.post('/create_review/',
      data: {
        'tour_id': tourId, 
        'rating': rating, 
        'comment': comment
      });
      return response;
    } catch (e) {
      print('Failed to fetch tour categories: $e');
      rethrow;
    }
  }

  Future<Response> initializeInferenceModule(int tourId) async {
    try {
      final response = await dio.get('/load_model/$tourId');
      return response;
    } catch (e) {
      print('Failed to fetch tour categories: $e');
      rethrow;
    }
  }

  Future<Response> inference(String imageBase64, int tourId) async {
    try {
      final formData = FormData.fromMap({
        'img': imageBase64,
        'tour_id': tourId,
      });

      var results_data = {};
      final response = await dio.post('/inference/', data: formData);
      // if (response.data.get("result") == -1) {
      //   results_data["result"] = -1;
      //   results_data["available_resources"] = response.data.get("available_resources");
      // } else {
      //   return response.data["result"];
      // }
      return response;
    } catch (e) {
      print('Failed inference: $e');
      rethrow;
    }
  }
    
    Future<Response> loadResource(int waypointId, String resourceType) async {
    try {
      final response = await dio.get('/get_waypoint_resources/',
        queryParameters: {
          'waypoint_id': waypointId,
          'resource_type': resourceType,
        }
      );
      return response;
    } catch (e) {
      print('Failed to fetch tour resources: $e');
      rethrow;
    }
  }




}