import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:xr_tour_guide/models/tour.dart';
import 'package:xr_tour_guide/models/category.dart';
import 'package:xr_tour_guide/models/waypoint.dart';
import 'package:xr_tour_guide/models/review.dart';
import "package:xr_tour_guide/models/user.dart";
import 'package:dio/dio.dart';
import 'secure_storage_service.dart';
import 'auth_service.dart';
import 'api_service.dart';

final tourServiceProvider = Provider<TourService>((ref) {
  final apiService = ref.read(apiServiceProvider);
  return TourService(apiService);
});

class TourService {
  // Instance of ApiService to handle API calls
  final ApiService apiService;
  TourService(this.apiService);

  // Simulate API call to get nearby tours
  Future<List<Tour>> getNearbyTours() async {
    try {
      final response = await apiService.getNearbyTours();
      if (response.statusCode == 200) {
        final data = response.data as List;
        return data.map((tour) => Tour.fromJson(tour)).toList();
      } else {
        throw Exception('Failed to load tours');
      }
    } catch (e) {
      print("Nearby Tours Retrieval error: $e");
      rethrow;
    }
  }

    Future<Tour> getTourById(int tourId) async {
      try {
        final response = await apiService.getTourDetails(tourId);
        if (response.statusCode == 200) {
          final data = response.data;
          return Tour.fromJson(data);
        } else {
          throw Exception('Failed to load tour details');
        }
      } catch (e) {
        print("Tour Details Retrieval error: $e");
        rethrow;
      }
  }

  Future<List<Tour>> getToursByCategory(String category) async {
    try {
      final response = await apiService.getTourByCategory(category);
      if (response.statusCode == 200) {
        final data = response.data as List;
        return data.map((tour) => Tour.fromJson(tour)).toList();
      } else {
        throw Exception('Failed to load tours');
      }
    } catch (e) {
      print("Tours By category Retrieval error: $e");
      rethrow;
    }
  }

  Future<List<Tour>> getToursBySearchTerm(String searchTerm) async {
    try {
      final response = await apiService.getTourBySearchTerm(
        searchTerm.toLowerCase(),
      );
      if (response.statusCode == 200) {
        final data = response.data as List;
        return data.map((tour) => Tour.fromJson(tour)).toList();
      } else {
        throw Exception('Failed to load tours');
      }
    } catch (e) {
      print("Nearby Tours Retrieval error: $e");
      rethrow;
    }
  }

  Future<List<Waypoint>> getWaypointsByTour(int tourId) async {
    try {
      final response = await apiService.getTourWaypoints(tourId);
      if (response.statusCode == 200) {
        final data = response.data;
        final waypointData = data["waypoints"] as List;
        return waypointData.map((waypoint) => Waypoint.fromJson(waypoint)).toList();
      } else {
        throw Exception('Failed to load tour waypoints');
      }
    } catch (e) {
      print("Tour Waypoints Retrieval error: $e");
      rethrow;
    }
  }

  Future<List<Review>> getReviewByTour({int? tourId, int? userId, required int max}) async {
    List<Review> reviews = [];
    try {
      final response = await apiService.getTourReviews(tourId!);
      if (response.statusCode == 200) {
        final data = response.data as List;
        reviews = data.map((review) => Review.fromJson(review)).toList();
      } else {
        throw Exception('Failed to load tour reviews');
      }     
    } catch (e) {
      print("Tour Reviews Retrieval error: $e");
      rethrow; 
    }

    // Return only the first 'max' reviews
    if (max > reviews.length) {
      max = reviews.length; // Adjust max to the length of the list if out of bounds
    }
    if (max < 0) {
      max = 0; // Ensure max is not negative
    }
    if (max == 0) {
      //return all reviews if max is 0
      return reviews.toList();
    } else {
      return reviews.take(max).toList();
    }
  }

  // Simulate API call to get categories
  Future<List<Category>> getCategories() async {
    // Simulate network delay
    await Future.delayed(const Duration(milliseconds: 500));

    // Mock data
    return [
      Category(name: 'INSIDE', image: 'assets/interior.jpg'),
      Category(name: 'OUTSIDE', image: 'assets/exterior.jpg'),
      Category(name: 'MIXED', image: 'assets/int-exterior.jpg'),
    ];
  }

Future<User> getUserDetails() async {
  try {
    final response = await apiService.getProfileDetails();
    if (response.statusCode == 200) {
      final data = response.data;
      return User(
        id: data['id'],
        name: data['first_name'],
        surname: data['last_name'],
        mail: data['email'],
        city: "Avellino",
        token: "abc",
        description: data['description'] ?? '',
        reviewCount: data['review_count'] ?? 0,
      );
    } else {
      throw Exception('Failed to load user details');
    }
  } catch (e) {
    print("User Details Retrieval error: $e");
    rethrow;
  }
  //TODO: Gestire errore 401 per token non riconosciuto
}

  Future<List<Review>> getReviewByUser(int max) async {
    List<Review> reviews = [];
    try {
      final response = await apiService.getUserReviews();
      if (response.statusCode == 200) {
        final data = response.data as List;
        reviews = data.map((review) => Review.fromJson(review)).toList();
      } else {
        throw Exception('Failed to load user reviews');
      }
    } catch (e) {
      print("User Reviews Retrieval error: $e");
      rethrow;
    }

        // Return only the first 'max' reviews
    if (max > reviews.length) {
      max =
          reviews
              .length; // Adjust max to the length of the list if out of bounds
    }
    if (max < 0) {
      max = 0; // Ensure max is not negative
    }
    if (max == 0) {
      //return all reviews if max is 0
      return reviews.toList();
    } else {
      return reviews.take(max).toList();
    }
  }

  Future<Map<String, dynamic>> getResourceByWaypointAndType(int waypointId, String type) async {
    Map<String, dynamic> resource = {};
    try {
      final response = await apiService.loadResource(waypointId, type);
      if (response.statusCode == 200) {
        resource = response.data as Map<String, dynamic>;
      } else {
        throw Exception('Failed to load resource of type $type for waypoint $waypointId');
      }
    } catch (e) {
      print("Resource Retrieval error: $e");
      rethrow;
    }

    return resource;
  }



}
