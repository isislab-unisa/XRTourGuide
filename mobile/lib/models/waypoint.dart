class Waypoint {
  final String title;
  final String subtitle;
  final String description;
  final double latitude;
  final double longitude;
  final List<String> images;
  final String category;

  Waypoint({
    required this.title,
    required this.subtitle,
    required this.description,
    required this.latitude,
    required this.longitude,
    required this.images,
    required this.category,
  });

  factory Waypoint.fromJson(Map<String, dynamic> json) {
    return Waypoint(
      title: json['title'] as String,
      subtitle: json['subtitle'] as String,
      description: json['description'] as String,
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
      images: List<String>.from(json['images'] as List),
      category: json['category'] as String,
    );
  }
}
