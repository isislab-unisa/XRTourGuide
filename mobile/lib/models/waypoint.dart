class Waypoint {
  final int id;
  final String title;
  final String subtitle;
  final String description;
  final double latitude;
  final double longitude;
  final List<String> images;
  final String category;
  final List<Waypoint>? subWaypoints;

  Waypoint({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.description,
    required this.latitude,
    required this.longitude,
    required this.images,
    required this.category,
    this.subWaypoints,
  });

  factory Waypoint.fromJson(Map<String, dynamic> json) {
    final imagesJson = json['images'] as List<dynamic>?;

    // Supporta sia List<Map>{image_name} (online) che List<String> (offline)
    final images = (imagesJson ?? [])
            .map<String>((img) {
              if (img is Map<String, dynamic> && img.containsKey('image_name')) {
                final name = img['image_name'];
                return name as String;
              } else if (img is String) {
                return img;
              } else {
                return '';
              }
            })
            .where((s) => s.isNotEmpty)
            .toList();

    return Waypoint(
      id: json['id'] as int,
      title: json['title'] as String,
      subtitle: "",
      description: json['description'] as String,
      latitude: (json['lat'] as num).toDouble(),
      longitude: (json['lon'] as num).toDouble(),
      // images: imagesJson!.map((img) => img["image_name"] as String).toList(),
      images: images,
      // images: [],
      category: json['category'] != null ? json['category'] as String : "Generale",
      subWaypoints: json["sub_waypoints"] != null ? (json['sub_waypoints'] as List<dynamic>?)
          ?.map((sub) => Waypoint.fromJson(sub as Map<String, dynamic>))
          .toList() : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'subtitle': subtitle,
      'description': description,
      'lat': latitude,
      'lon': longitude,
      'images': images,
      'category': category,
      'sub_waypoints': subWaypoints?.map((wp) => wp.toJson()).toList(),
    };
  }

  List<Waypoint> getAllWaypoints() {
    List<Waypoint> allWaypoints = [this];
    if (subWaypoints != null) {
      for (var subWaypoint in subWaypoints!) {
        allWaypoints.addAll(subWaypoint.getAllWaypoints());
      }
    }
    return allWaypoints;
  }
}
