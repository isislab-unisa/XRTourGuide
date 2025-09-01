class Tour {
  final int id;
  final String title;
  final String description;
  final String imagePath;
  final String category;
  final double rating;
  final int reviewCount;
  // final List<String> images;
  final String location;
  final double latitude;
  final double longitude;
  final String creator;
  final String lastEdited;
  final int totViews;

  Tour({
    required this.id,
    required this.title,
    required this.description,
    required this.imagePath,
    required this.category,
    required this.rating,
    required this.reviewCount,
    // required this.images,
    required this.location,
    required this.latitude,
    required this.longitude,
    required this.creator,
    required this.lastEdited,
    required this.totViews,
  });

  factory Tour.fromJson(Map<String, dynamic> json) {
    return Tour(
      id: json['id'] as int,
      title: json['title'] as String,
      description: json['description'] as String,
      imagePath: json['default_img'] as String,
      category: json['category'] as String,
      rating: (json['rating'] as num).toDouble(),
      reviewCount: json['rating_counter'] as int,
      // images: List<String>.from(json['images'] as List),
      location: json['place'] as String,
      latitude: (json['lat'] as num).toDouble(),
      longitude: (json['lon'] as num).toDouble(),
      creator: json['user_name'] as String,
      lastEdited: json['l_edited'] as String, //da rivedere
      totViews: json['tot_view'] as int,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'default_img': imagePath,
      'category': category,
      'rating': rating,
      'rating_counter': reviewCount,
      // 'images': images,
      'place': location,
      'lat': latitude,
      'lon': longitude,
      'user_name': creator,
      'l_edited': lastEdited,
      'tot_view': totViews,
    };
  }
}
