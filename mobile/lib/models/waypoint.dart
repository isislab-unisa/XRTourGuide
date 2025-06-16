class Waypoint {
  final int id;
  final String title;
  final String subtitle;
  final String description;
  final double latitude;
  final double longitude;
  final List<String> images;
  final String category;

  Waypoint({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.description,
    required this.latitude,
    required this.longitude,
    required this.images,
    required this.category,
  });

  factory Waypoint.fromJson(Map<String, dynamic> json) {
    final imagesJson = json['images'] as List<dynamic>?;
    return Waypoint(
      id: json['id'] as int,
      title: json['title'] as String,
      subtitle: "",
      description: json['description'] as String,
      latitude: (json['lat'] as num).toDouble(),
      longitude: (json['lon'] as num).toDouble(),
      images: imagesJson!.map((img) => img["image_name"] as String).toList(),
      // images: [],
      category: json['category'] != null ? json['category'] as String : "Generale",
    );
  }
}
