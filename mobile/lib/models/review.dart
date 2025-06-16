class Review {
  final int id;
  final String date;
  final String comment;
  final double rating;
  final String user;

  Review({
    required this.id,
    required this.date,
    required this.comment,
    required this.rating,
    required this.user,
  });

  factory Review.fromJson(Map<String, dynamic> json) {
    return Review(
      id: json['id'] as int,
      date: json['creation_date'] as String,
      comment: json['comment'] as String,
      rating: (json['rating'] as num).toDouble(),
      user: json['user_name'] as String,
    );
  }
}
