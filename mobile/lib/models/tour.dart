class Tour {
  final String id;
  final String title;
  final String description;
  final String imagePath;
  final String category;
  final String subcategory;
  final double rating;
  final int reviewCount;
  final List<String> images;
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
    required this.subcategory,
    required this.rating,
    required this.reviewCount,
    required this.images,
    required this.location,
    required this.latitude,
    required this.longitude,
    required this.creator,
    required this.lastEdited,
    required this.totViews,
  });

  factory Tour.fromJson(Map<String, dynamic> json) {
    return Tour(
      id: json['id'] as String,
      title: json['title'] as String,
      description: json['description'] as String,
      imagePath: json['imagePath'] as String,
      category: json['category'] as String,
      subcategory: json['subcategory'] as String,
      rating: (json['rating'] as num).toDouble(),
      reviewCount: json['reviewCount'] as int,
      images: List<String>.from(json['images'] as List),
      location: json['location'] as String,
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
      creator: json['creator'] as String,
      lastEdited: json['lastEdited'] as String,
      totViews: json['totViews'] as int,
    );
  }
}
