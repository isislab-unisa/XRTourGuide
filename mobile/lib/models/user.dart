import 'dart:ffi';

class User {
  final int id;
  final String name;
  final String surname;
  final String mail;
  final String city;
  final String token;
  final String description;
  int reviewCount = 0;

  User({
    required this.id,
    required this.name,
    required this.surname,
    required this.mail,
    required this.city,
    required this.token,
    required this.description,
    this.reviewCount = 0,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'] as int,
      name: json['title'] as String,
      surname: json['subtitle'] as String,
      mail: json['description'] as String,
      city: json['latitude'] as String,
      token: json['category'] as String,
      description: json['subcategory'] as String,
      reviewCount: json['reviewCount'] as int,
    );
  }
}
