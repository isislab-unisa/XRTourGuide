import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:xr_tour_guide/models/tour.dart';
import 'models/app_colors.dart';
import 'elements/travel_list_item_card.dart';
import 'tour_details_page.dart';
import 'services/tour_service.dart';


class CategoryDetailScreen extends StatefulWidget {
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
  State<CategoryDetailScreen> createState() => _CategoryDetailScreenState();
}

class _CategoryDetailScreenState extends State<CategoryDetailScreen> {

  final TourService _tourService = TourService();

  List<Tour>? _categoriesTour;
  bool _isLoading = true;

  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    // Load all data in parallel
    await Future.wait([
      _loadCategoryTours(),
    ]);
  }

  Future<void> _loadCategoryTours() async {
    try {
      final tours = await _tourService.getToursByCategory(widget.categoryName);
      if (mounted) {
        setState(() {
          _categoriesTour = tours;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        _showError('Error loading nearby tours');
      }
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }




  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;

    if (_isLoading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

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
              '${widget.categoryName} ${widget.tours.length} Risultati',
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
              itemCount: _categoriesTour?.length,
              itemBuilder: (context, index) {
                final tour = _categoriesTour![index];
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
                              isGuest: widget.isGuest,
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
