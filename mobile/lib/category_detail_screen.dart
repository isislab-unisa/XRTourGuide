import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:xr_tour_guide/models/tour.dart';
import 'models/app_colors.dart';
import 'elements/travel_list_item_card.dart';
import 'tour_details_page.dart';

class CategoryDetailScreen extends StatelessWidget {
  final String categoryName;
  final List<Tour> tours;
  final bool isGuest;

  const CategoryDetailScreen({
    Key? key,
    required this.categoryName,
    required this.tours,
    required this.isGuest,
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
                  imagePath: tour.imagePath,
                  title: tour.title,
                  description: tour.description,
                  cardWidth: screenWidth - 40, // Full width minus padding
                  fullWidth: true,
                  imageHeight: 180,
                  category: tour.subcategory,
                  rating: tour.rating,
                  reviewCount: tour.reviewCount,
                  // isFavorite: tour['isFavorite'] ?? false,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder:
                            (context) => TourDetailScreen(
                              tourId: tour.id,
                              tourName: tour.title,
                              location: tour.location,
                              rating: tour.rating,
                              reviewCount: tour.reviewCount,
                              images: [
                                tour.imagePath,
                                'assets/acquedotto.jpg',
                                'assets/cibo_example.jpg',
                              ],
                              category: tour.subcategory,
                              description: tour.description,
                              creator: tour.creator,
                              lastEdited: tour.lastEdited,
                              totViews: tour.totViews.toString(),
                              latitude: tour.latitude,
                              longitude: tour.longitude,
                              isGuest: isGuest,
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
