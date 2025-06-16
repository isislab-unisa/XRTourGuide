import 'package:xr_tour_guide/models/tour.dart';
import 'package:xr_tour_guide/models/category.dart';
import 'package:xr_tour_guide/models/waypoint.dart';
import 'package:xr_tour_guide/models/review.dart';
import "package:xr_tour_guide/models/user.dart";
import 'package:dio/dio.dart';
import 'secure_storage_service.dart';
import 'auth_service.dart';
import 'api_service.dart';

class TourService {
  // Instance of ApiService to handle API calls
  final apiService = ApiService();

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
    // Simulate network delay
    await Future.delayed(const Duration(seconds: 1));

    // Mock data
    return [
      Tour(
        id: 1,
        title: 'Montevergine',
        description:
            'Il Santuario di Montevergine è un importante complesso monastico mariano situato a circa 1.270 metri sul livello del mare, nel massiccio del Partenio, nel comune di Mercogliano (Avellino). Fondato nel 1124 da San Guglielmo da Vercelli, il santuario è oggi uno dei principali luoghi di pellegrinaggio del Sud Italia, con oltre un milione di visitatori ogni anno.',
        imagePath: 'assets/montevergine.jpg',
        category: 'Natura',
        rating: 4.5,
        reviewCount: 675,
        location: 'Avellino, Campania',
        latitude: 40.9333,
        longitude: 14.7167,
        creator: 'TourGuide Team',
        lastEdited: '2023-10-01',
        totViews: 1500,
      ),
      Tour(
        id: 2,
        title: 'Acquedotto Romano',
        description: 'Discover the beauty of this amazing destination.',
        imagePath: 'assets/acquedotto.jpg',
        category: 'Storia',
        rating: 4.3,
        reviewCount: 425,
        location: 'Avellino, Campania',
        latitude: 40.9147,
        longitude: 14.7927,
        creator: 'TourGuide Team',
        lastEdited: '2023-10-01',
        totViews: 1200,
      ),
    ];
  }


  Future<List<Map<String, String>>> getToursBySearchTerm(String searchTerm) async {
    // Simulate network delay
    await Future.delayed(const Duration(seconds: 1));

    if (searchTerm.isEmpty) {
      return [];
    }
    // Mock data
    return [
      {"id": "2", "title": "Acquedotto Romano"},
      {"id": "1", "title": "Montevergine"},
    ];
  }




  Future<List<Waypoint>> getWaypointsByTour(int tourId) async {
    try {
      final response = await apiService.getTourWaypoints(tourId);
      if (response.statusCode == 200) {
        final data = response.data as List;
        return data.map((waypoint) => Waypoint.fromJson(waypoint)).toList();
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



  // Simulate API call to get cooking tours
  Future<List<Tour>> getCookingTours() async {
    // Simulate network delay
    await Future.delayed(const Duration(seconds: 1));

    // Mock data
    return [
      Tour(
        id: 3,
        title: 'Cucina Tipica Irpina',
        description: 'Experience traditional Irpinian cuisine.',
        imagePath: 'assets/cibo_example.jpg',
        category: 'Cibo',
        rating: 4.8,
        reviewCount: 312,
        location: 'Avellino, Campania',
        latitude: 40.9147,
        longitude: 14.7927,
        creator: 'TourGuide Team',
        lastEdited: '2023-10-01',
        totViews: 800,
      ),
    ];
  }

  // Simulate API call to get categories
  Future<List<Category>> getCategories() async {
    // Simulate network delay
    await Future.delayed(const Duration(milliseconds: 500));

    // Mock data
    return [
      Category(name: 'Interior', image: 'assets/interior.jpg'),
      Category(name: 'Exterior', image: 'assets/exterior.jpg'),
      Category(name: 'Mixed', image: 'assets/int-exterior.jpg'),
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


}
