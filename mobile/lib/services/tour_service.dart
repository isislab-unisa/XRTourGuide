import 'package:xr_tour_guide/models/tour.dart';
import 'package:xr_tour_guide/models/category.dart';
import 'package:xr_tour_guide/models/waypoint.dart';
import 'package:xr_tour_guide/models/review.dart';
import "package:xr_tour_guide/models/user.dart";

class TourService {
  // Simulate API call to get nearby tours
  Future<List<Tour>> getNearbyTours() async {
    // Simulate network delay
    await Future.delayed(const Duration(seconds: 1));

    // Mock data
    return [
      Tour(
        id: 'tour_1',
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
        id: 'tour_2',
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

  Future<List<Waypoint>> getWaypointsByTour() async {
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

  Future<List<Review>> getReviewByTour() async {
    // Simulate network delay
    await Future.delayed(const Duration(seconds: 1));

    // Mock data
    return [
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
    ];
  }



  // Simulate API call to get cooking tours
  Future<List<Tour>> getCookingTours() async {
    // Simulate network delay
    await Future.delayed(const Duration(seconds: 1));

    // Mock data
    return [
      Tour(
        id: 'tour_3',
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
      Category(name: 'Natura', image: 'assets/natura_categoria.jpg'),
      Category(name: 'Città', image: 'assets/citta_categoria.jpg'),
      Category(name: 'Cultura', image: 'assets/wine_category.jpg'),
      Category(name: 'Cibo', image: 'assets/cibo_example.jpg'),
    ];
  }

  Future<User> getUserDetails() async {
    // Simulate network delay
    await Future.delayed(const Duration(seconds: 1));

    // Mock user data
    return User(
      name: 'Mario',
      surname: 'Rossi',
      mail: 'test@mail.com',
      city: 'Avellino',
      token: 'sample_token',
      description: 'Appassionato di storia e cultura locale.',
      reviewCount: 10,
    );
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
