import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'models/app_colors.dart';
import 'services/tour_service.dart';
import 'tour_details_page.dart';
import 'models/tour.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class SearchScreen extends ConsumerStatefulWidget {
  final bool isGuest;
  const SearchScreen({Key? key, required this.isGuest}) : super(key: key);

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen>
    with SingleTickerProviderStateMixin {

  late TourService _tourService;

  // Controller for the search text field
  final TextEditingController _searchController = TextEditingController();

  // Animation controller for the entrance animation
  late AnimationController _animationController;

  // Animation for the search bar and content
  late Animation<double> _searchBarAnimation;
  late Animation<double> _contentAnimation;

  late List<Tour> _filteredDestinations;
  bool _isLoading = true;


  @override
  void initState() {
    super.initState();
    _tourService = ref.read(tourServiceProvider);
    // Initialize filtered destinations with an empty list
    _filteredDestinations = [];

    // Initialize animation controller with duration
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );

    // Create animations for search bar and content with different curves
    _searchBarAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOut,
    );

    _contentAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    );

    // Start the animation when the screen is built
    _animationController.forward();
  }

  Future<void> _loadData() async {
    // Load all data in parallel
    await Future.wait([_loadSearchResults("")]);
  }


  Future<void> _loadSearchResults(String searchTerm) async {
    try {
      final tours = await _tourService.getToursBySearchTerm(searchTerm);
      if (mounted) {
        setState(() {
          _filteredDestinations = tours;
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

  void _onSearchChanged(String value) {
    // Update the search results based on the input
    _loadSearchResults(value);
  }


  @override
  void dispose() {
    // Clean up controllers when the widget is disposed
    _searchController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Get screen dimensions for responsive layout
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

    return Scaffold(
      // Set background color from AppColors
      backgroundColor: AppColors.background,

      // Make the app bar transparent and extend content behind it
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        // Back button with custom color
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
          onPressed: () {
            // Run the animation in reverse before popping the screen
            _animationController.reverse().then((_) {
              Navigator.of(context).pop();
            });
          },
        ),
        // Set status bar style
        systemOverlayStyle: const SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.dark,
        ),
        // Center title with animation
        title: FadeTransition(
          opacity: _searchBarAnimation,
          child: const Text(
            'Search',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 16),

              // Animated search bar
              SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(0, -0.1),
                  end: Offset.zero,
                ).animate(_searchBarAnimation),
                child: FadeTransition(
                  opacity: _searchBarAnimation,
                  child: Container(
                    // Responsive width based on screen size
                    width: screenWidth - 32,
                    height: 50,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(25),
                      border: Border.all(color: AppColors.border),
                      // Add subtle shadow
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 10,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: TextField(
                      controller: _searchController,
                      // Auto focus when screen opens
                      autofocus: true,
                      decoration: InputDecoration(
                        hintText: 'Search destinations',
                        hintStyle: TextStyle(
                          color: AppColors.textSecondary.withOpacity(0.7),
                          fontSize: 16,
                        ),
                        prefixIcon: const Icon(
                          Icons.search,
                          color: AppColors.textSecondary,
                        ),
                        // Clear button
                        suffixIcon:
                            _searchController.text.isNotEmpty
                                ? IconButton(
                                  icon: const Icon(
                                    Icons.clear,
                                    color: AppColors.textSecondary,
                                  ),
                                  onPressed: () {
                                    _searchController.clear();
                                    // Refresh the UI
                                    setState(() {});
                                  },
                                )
                                : null,
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(
                          vertical: 15,
                          horizontal: 20,
                        ),
                      ),
                      onChanged: (value) {
                        // Refresh UI when text changes to show/hide clear button
                        //TODO: Implement search logic here
                        _onSearchChanged(value);
                        // setState(() {});
                      },
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // Animated content - Popular destinations list
              Expanded(
                child: SlideTransition(
                  position: Tween<Offset>(
                    begin: const Offset(0, 0.1),
                    end: Offset.zero,
                  ).animate(_contentAnimation),
                  child: FadeTransition(
                    opacity: _contentAnimation,
                    child: ListView.builder(
                      itemCount: _filteredDestinations.length,
                      itemBuilder: (context, index) {
                        final destination = _filteredDestinations[index];
                        return _buildDestinationItem(
                          destination.title,
                          destination.id,
                          onTap: () {
                            // Handle destination selection
                            print(
                              'Selected destination: ${destination.title}',
                            );
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder:
                                    (context) => TourDetailScreen(
                                      tourId: destination.id,
                                      isGuest: widget.isGuest,
                                    ),
                              ),
                            );
                          },
                        );
                      },
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Helper method to build each destination item
  Widget _buildDestinationItem(
    String name,
    int id,{
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      // Use custom splash color
      splashColor: AppColors.primary.withOpacity(0.1),
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 8.0),
        child: Row(
          children: [
            // Destination icon
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppColors.lightGrey,
                borderRadius: BorderRadius.circular(20),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: Icon(
                  Icons.location_city,
                  color: AppColors.textSecondary.withOpacity(0.7),
                  size: 24,
                ),
              ),
            ),
            const SizedBox(width: 16),
            // Destination name and description
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Destination name
                  Text(
                    name,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  // Show description if available
                  // if (description.isNotEmpty)
                  //   Text(
                  //     description,
                  //     style: TextStyle(
                  //       fontSize: 14,
                  //       color: AppColors.textSecondary.withOpacity(0.7),
                  //     ),
                  //   ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
