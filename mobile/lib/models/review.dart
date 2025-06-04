class Review {
  final String name;
  final String date;
  final String comment;
  final double rating;
  final String imageUrl;

  Review({
    required this.name,
    required this.date,
    required this.comment,
    required this.rating,
    required this.imageUrl,
  });

  factory Review.fromJson(Map<String, dynamic> json) {
    return Review(
      name: json['title'] as String,
      date: json['subtitle'] as String,
      comment: json['description'] as String,
      rating: (json['latitude'] as num).toDouble(),
      imageUrl: json['category'] as String,
    );
  }
}
