import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'app_colors.dart';
import 'travel_list_item_card.dart';
import 'tour_details_page.dart';

class CategoryDetailScreen extends StatelessWidget {
  final String categoryName;
  final List<Map<String, dynamic>> tours;

  const CategoryDetailScreen({
    Key? key,
    required this.categoryName,
    required this.tours,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;

    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.of(context).pop(),
        ),
        systemOverlayStyle: const SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.dark,
        ),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Add some space at the top for the status bar and app bar
          SizedBox(height: MediaQuery.of(context).padding.top + 56),

          // Category title and results count
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 20.0,
              vertical: 10.0,
            ),
            child: Text(
              '$categoryName ${tours.length} Risultati',
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
          ),

          // List of tours
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 20.0),
              itemCount: tours.length,
              itemBuilder: (context, index) {
                final tour = tours[index];
                return TravelListItemCard(
                  imagePath: tour['imagePath'],
                  title: tour['title'],
                  description:
                      'Discover the beauty of this amazing destination.',
                  cardWidth: screenWidth - 40, // Full width minus padding
                  fullWidth: true,
                  imageHeight: 180,
                  category: tour['subcategory'],
                  rating: tour['rating'],
                  reviewCount: tour['reviewCount'],
                  // isFavorite: tour['isFavorite'] ?? false,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder:
                            (context) => TourDetailScreen(
                              tourId: 'tour_${index + 1}',
                              tourName: tour['title'],
                              location: 'Location ${index + 1}',
                              rating: tour['rating'],
                              reviewCount: tour['reviewCount'],
                              images: [
                                tour['imagePath'],
                                'assets/acquedotto.jpg',
                                'assets/cibo_example.jpg',
                              ],
                              category: tour['subcategory'],
                              description:
                                  'Discover the beauty and history of this amazing destination with our guided tour.',
                            ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
