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
    // Simulate network delay
    // await Future.delayed(const Duration(seconds: 1));

    // // Mock data
    // return [
    //   Tour(
    //     id: 1,
    //     title: 'Montevergine',
    //     description:
    //         'Il Santuario di Montevergine è un importante complesso monastico mariano situato a circa 1.270 metri sul livello del mare, nel massiccio del Partenio, nel comune di Mercogliano (Avellino). Fondato nel 1124 da San Guglielmo da Vercelli, il santuario è oggi uno dei principali luoghi di pellegrinaggio del Sud Italia, con oltre un milione di visitatori ogni anno.',
    //     imagePath: 'assets/montevergine.jpg',
    //     category: 'Natura',
    //     subcategory: 'Montagna',
    //     rating: 4.5,
    //     reviewCount: 675,
    //     images: [
    //       'assets/montevergine.jpg',
    //       'assets/acquedotto.jpg',
    //       'assets/cibo_example.jpg',
    //     ],
    //     location: 'Avellino, Campania',
    //     latitude: 40.9333,
    //     longitude: 14.7167,
    //     creator: 'TourGuide Team',
    //     lastEdited: '2023-10-01',
    //     totViews: 1500,
    //   ),
    //   Tour(
    //     id: 2,
    //     title: 'Acquedotto Romano',
    //     description: 'Discover the beauty of this amazing destination.',
    //     imagePath: 'assets/acquedotto.jpg',
    //     category: 'Storia',
    //     subcategory: 'Archeologia',
    //     rating: 4.3,
    //     reviewCount: 425,
    //     images: [
    //       'assets/acquedotto.jpg',
    //       'assets/montevergine.jpg',
    //       'assets/cibo_example.jpg',
    //     ],
    //     location: 'Avellino, Campania',
    //     latitude: 40.9147,
    //     longitude: 14.7927,
    //     creator: 'TourGuide Team',
    //     lastEdited: '2023-10-01',
    //     totViews: 1200,
    //   ),
    // ];

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
    // Simulate network delay
    await Future.delayed(const Duration(seconds: 1));

    // Mock data
    return Tour(
      id: 1,
      title: 'Montevergine',
      description:
          'Il Santuario di Montevergine è un importante complesso monastico mariano situato a circa 1.270 metri sul livello del mare, nel massiccio del Partenio, nel comune di Mercogliano (Avellino). Fondato nel 1124 da San Guglielmo da Vercelli, il santuario è oggi uno dei principali luoghi di pellegrinaggio del Sud Italia, con oltre un milione di visitatori ogni anno.',
      imagePath: 'assets/montevergine.jpg',
      category: 'Natura',
      subcategory: 'Montagna',
      rating: 4.5,
      reviewCount: 675,
      images: [
        'assets/montevergine.jpg',
        'assets/acquedotto.jpg',
        'assets/cibo_example.jpg',
      ],
      location: 'Avellino, Campania',
      latitude: 40.9333,
      longitude: 14.7167,
      creator: 'TourGuide Team',
      lastEdited: '2023-10-01',
      totViews: 1500,
    );
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
        subcategory: 'Montagna',
        rating: 4.5,
        reviewCount: 675,
        images: [
          'assets/montevergine.jpg',
          'assets/acquedotto.jpg',
          'assets/cibo_example.jpg',
        ],
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
        subcategory: 'Archeologia',
        rating: 4.3,
        reviewCount: 425,
        images: [
          'assets/acquedotto.jpg',
          'assets/montevergine.jpg',
          'assets/cibo_example.jpg',
        ],
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
  // Simulate network delay
    await Future.delayed(const Duration(seconds: 1));

    // Mock data
    return [
      Waypoint(
        title: 'Tappa 1',
        subtitle: 'Santuario di Montevergine',
        description:
            'Il Santuario di Montevergine è un importante complesso monastico mariano situato a circa 1.270 metri sul livello del mare, nel massiccio del Partenio, nel comune di Mercogliano (Avellino). Fondato nel 1124 da San Guglielmo da Vercelli, il santuario è oggi uno dei principali luoghi di pellegrinaggio del Sud Italia, con oltre un milione di visitatori ogni anno.',
        images: ['assets/montevergine.jpg', 'assets/montevergine.jpg'],
        latitude: 40.93579072684478,
        longitude: 14.728316097194247,
        category: "Edificio Religioso",
      ),
      Waypoint(
        title: 'Tappa 2',
        subtitle: 'Funicolare',
        description: 'Stazione di arrivo della funicolare.',
        images: [],
        latitude: 40.93228115205057,
        longitude: 14.73164203632444,
        category: "Trasporto",
      ),
      Waypoint(
        title: 'Tappa 3',
        subtitle: 'Postazione TV',
        description: 'Postazione TV per il canale Monte Vergine Trocchio.',
        latitude: 40.93416159407318,
        longitude: 14.72459319140844,
        images: [],
        category: "Infrastruttura",
      ),
      Waypoint(
        title: 'Tappa 4',
        subtitle: 'Vetta Montevergine',
        description: 'Vetta della montagna.',
        latitude: 40.94001346036333,
        longitude: 14.724761197705648,
        images: [],
        category: "Natura",
      ),
      Waypoint(
        title: 'Tappa 5',
        subtitle: 'Cappella dello scalzatoio',
        description: 'Cappella Lorem ipsu dorem.',
        latitude: 40.9355568038218,
        longitude: 14.737636977690212,
        images: [],
        category: "Edificio Religioso",
      ),
    ];
  }

  Future<List<Review>> getReviewByTour({int? tourId, int? userId, required int max}) async {
    //TODO: Add logic for tour or user

    // Simulate network delay
    await Future.delayed(const Duration(seconds: 1));

    // Mock data
    List<Review> reviews = [
      Review(
        name: 'Giorgia',
        date: 'Oct 24, 2024',
        comment:
            'The tour schedule was nicely arranged, yet we felt rushed and couldn\'t fully savor our time at Disneyland. It would have been...',
        rating: 4.2,
        imageUrl: "",
      ),
      Review(
        name: 'John',
        date: 'Oct 24, 2024',
        comment:
            'The historical sites were breathtaking, but the queues were long and it was...',
        rating: 4.5,
        imageUrl: "",
      ),
      Review(
        name: 'Mike',
        date: 'Oct 24, 2024',
        comment:
            'The tour schedule was nicely arranged, yet we felt rushed and couldn\'t fully savor our time at Disneyland. It would have been...',
        rating: 4.0,
        imageUrl: "",
      ),
      Review(
        name: 'John',
        date: 'Oct 24, 2024',
        comment:
            'The tour schedule was nicely arranged, yet we felt rushed and couldn\'t fully savor our time at Disneyland. It would have been...',
        rating: 5.0,
        imageUrl: "",
      ),
      Review(
        name: 'Alice',
        date: 'Oct 24, 2024',
        comment:
            'The tour was well-organized and the guide was knowledgeable. However, I wish we had more time at each location.',
        rating: 4.7,
        imageUrl: "",
      ),
      Review(
        name: 'Luca',
        date: 'Oct 24, 2024',
        comment:
            'An unforgettable experience! The views were stunning and the guide was very friendly.',
        rating: 5.0,
        imageUrl: "",
      ),
      Review(
        name: 'Sara',
        date: 'Oct 24, 2024',
        comment:
            'The tour was informative, but the pace was a bit too fast for my liking. I would have preferred more time to explore each site.',
        rating: 3.8,
        imageUrl: "",
      ),
    ];

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
        subcategory: 'Tradizionale',
        rating: 4.8,
        reviewCount: 312,
        images: [
          'assets/cibo_example.jpg',
          'assets/montevergine.jpg',
          'assets/acquedotto.jpg',
        ],
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
  // Simulate network delay
  // await Future.delayed(const Duration(seconds: 1));

  // // Mock user data
  // return User(
  //   id: 1,
  //   name: 'Mario',
  //   surname: 'Rossi',
  //   mail: 'test@mail.com',
  //   city: 'Avellino',
  //   token: 'sample_token',
  //   description: 'Appassionato di storia e cultura locale.',
  //   reviewCount: 10,
  // );
  // print("Token: $token");
  // if (token == null) {
  //   throw Exception('User not authenticated');
  // }

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

  Future<List<Review>> getReviewByUser() async {
    // Simulate network delay
    await Future.delayed(const Duration(seconds: 1));

    // Mock data
    return [
      Review(
        name: 'Mario',
        date: 'Oct 24, 2024',
        comment:
            'The tour schedule was nicely arranged, yet we felt rushed and couldn\'t fully savor our time at Disneyland. It would have been...',
        rating: 4.2,
        imageUrl: "",
      ),
      Review(
        name: 'Mario',
        date: 'Oct 24, 2024',
        comment:
            'The historical sites were breathtaking, but the queues were long and it was...',
        rating: 4.5,
        imageUrl: "",
      ),
      Review(
        name: 'Mario',
        date: 'Oct 24, 2024',
        comment:
            'The tour schedule was nicely arranged, yet we felt rushed and couldn\'t fully savor our time at Disneyland. It would have been...',
        rating: 4.0,
        imageUrl: "",
      ),
      Review(
        name: 'Mario',
        date: 'Oct 24, 2024',
        comment:
            'The tour schedule was nicely arranged, yet we felt rushed and couldn\'t fully savor our time at Disneyland. It would have been...',
        rating: 5.0,
        imageUrl: "",
      ),
    ];
  }

  


}
