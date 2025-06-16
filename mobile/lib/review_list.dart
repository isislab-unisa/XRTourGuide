// main.dart or lib/screens/review_list_screen.dart (wherever ReviewListScreen is defined)
import 'package:flutter/material.dart';
import '/models/app_colors.dart'; // Adjust path as needed
import '/models/review.dart'; // Adjust path as needed
import '/services/tour_service.dart'; // Adjust path as needed


class ReviewListScreen extends StatefulWidget {
  final int? tourId;
  final int? userId;
  final int reviewCount;
  final String? tourName;
  final bool isTour;
  const ReviewListScreen({
    super.key,
    this.tourId,
    this.userId,
    required this.reviewCount,
    this.tourName,
    required this.isTour
  });

  @override
  _ReviewListScreenState createState() => _ReviewListScreenState();
}

class _ReviewListScreenState extends State<ReviewListScreen> {
  final TourService _tourService = TourService();

  List<Review> _reviews = [];
  bool _isLoadingReviews = true;
  String? _error; // Renamed from _error to _errorMessage for clarity with _showError

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    // Reset error state on new load attempt
    setState(() {
      _error = null;
      _isLoadingReviews = true; // Ensure loading state is true when reloading
    });
    // Load all data in parallel
    // In this case, only reviews are loaded, but you can add more futures.
    await Future.wait([_loadReviews()]);
  }

  Future<void> _loadReviews() async {
    List<Review> reviews;
    try {
      if (widget.isTour) {
        reviews = await _tourService.getReviewByTour(
          tourId: widget.tourId ?? 0,
          userId: widget.userId ?? 0,
          max: widget.reviewCount,
        ); // Use reviewCount or default to 10 
      }else {
        reviews = await _tourService.getReviewByUser(
          widget.reviewCount,
        ); // Use reviewCount or default to 10
      }
      if (mounted) {
        setState(() {
          _reviews = reviews;
          _isLoadingReviews = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingReviews = false;
          _error =
              'Error loading reviews: ${e.toString()}'; // Set error message in state
        });
        _showError('Error loading reviews. Please try again.'); // Show SnackBar
      }
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  // The _buildReviewItem method, now integrated into the state class
  Widget _buildReviewItem({
    required String name,
    required String date,
    required double rating,
    required String comment,
    String imageUrl = "",
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // User avatar
              CircleAvatar(
                radius: 20,
                backgroundImage:
                    imageUrl.isNotEmpty ? AssetImage(imageUrl) : null,
                child:
                    imageUrl.isEmpty
                        ? const Icon(
                          Icons.person,
                          size: 24,
                          color: AppColors.textSecondary,
                        )
                        : null,
              ),
              const SizedBox(width: 12),

              // User name and date
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    Text(
                      date,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),

              // Rating
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.amber.shade100,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.star, color: Colors.amber, size: 16),
                    const SizedBox(width: 4),
                    Text(
                      rating.toString(),
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Review comment
          Text(
            comment,
            style: const TextStyle(
              fontSize: 14,
              color: AppColors.textSecondary,
              height: 1.5,
            ),
          ),

          const SizedBox(height: 8),

          // Read more button
          GestureDetector(
            onTap: () {},
            child: const Text(
              'Read more',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: AppColors.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () {
            Navigator.pop(context); // Example: Pop the current screen
          },
        ),
        titleSpacing: 0,
        title: Padding(
          padding: const EdgeInsets.only(left: 8.0),
          child: Row(
            children: [
              if (widget.isTour)
                Text(
                  'Montevergine',
                  style: TextStyle(
                    color: Colors.black,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(width: 8),
              Text(
                '${_reviews.length} Review', // Display dynamic count
                style: TextStyle(color: Colors.grey[600], fontSize: 16),
              ),
            ],
          ),
        ),
      ),
      body:
          _isLoadingReviews
              ? Center(child: CircularProgressIndicator())
              : _error != null
              ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        _error!, // Display error message from state
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.red),
                      ),
                      SizedBox(height: 10),
                      ElevatedButton(
                        onPressed: _loadData, // Retry loading all data
                        child: Text('Retry'),
                      ),
                    ],
                  ),
                ),
              )
              : _reviews.isEmpty
              ? Center(child: Text('No reviews available.'))
              : ListView.separated(
                padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 10.0),
                itemCount: _reviews.length,
                itemBuilder: (context, index) {
                  final review = _reviews[index];
                  return _buildReviewItem(
                    name: review.user,
                    date: review.date,
                    rating: review.rating,
                    comment: review.comment, // Use 'comment' field
                  );
                },
                separatorBuilder: (context, index) => const SizedBox(height: 16),
              ),
    );
  }
}
