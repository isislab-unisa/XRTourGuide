import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'app_colors.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({Key? key}) : super(key: key);

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen>
    with SingleTickerProviderStateMixin {
  // Controller for the search text field
  final TextEditingController _searchController = TextEditingController();

  // Animation controller for the entrance animation
  late AnimationController _animationController;

  // Animation for the search bar and content
  late Animation<double> _searchBarAnimation;
  late Animation<double> _contentAnimation;

  // List of popular destinations with their icons and descriptions
  final List<Map<String, String>> _popularDestinations = [
    {'name': 'Nearby', 'description': '', 'icon': 'assets/icons/nearby.png'},
    {'name': 'Europe', 'description': '', 'icon': 'assets/icons/europe.png'},
    {
      'name': 'Paris',
      'description': 'City of arts',
      'icon': 'assets/icons/paris.png',
    },
    {
      'name': 'Rome',
      'description': 'History lives here',
      'icon': 'assets/icons/rome.png',
    },
    {
      'name': 'Rio De Janeiro',
      'description': 'Joy shines here',
      'icon': 'assets/icons/rio.png',
    },
    {
      'name': 'Dubai',
      'description': 'Dream rise here',
      'icon': 'assets/icons/dubai.png',
    },
    {
      'name': 'London',
      'description': 'City of culture',
      'icon': 'assets/icons/london.png',
    },
    {
      'name': 'Beijing',
      'description': 'Lives in tradition',
      'icon': 'assets/icons/beijing.png',
    },
    {
      'name': 'Sydney',
      'description': 'Vibes soar here',
      'icon': 'assets/icons/sydney.png',
    },
    {
      'name': 'Amsterdam',
      'description': 'City of Flowers',
      'icon': 'assets/icons/amsterdam.png',
    },
    {
      'name': 'Berlin',
      'description': 'City of arts',
      'icon': 'assets/icons/berlin.png',
    },
    {
      'name': 'Ankara',
      'description': 'City of arts',
      'icon': 'assets/icons/ankara.png',
    },
    {
      'name': 'Pisa',
      'description': 'City of arts',
      'icon': 'assets/icons/pisa.png',
    },
    {
      'name': 'Washington',
      'description': 'City of arts',
      'icon': 'assets/icons/washington.png',
    },
    {
      'name': 'Malaysia',
      'description': 'Family friendly',
      'icon': 'assets/icons/malaysia.png',
    },
    {
      'name': 'Barcelona',
      'description': 'City of arts',
      'icon': 'assets/icons/barcelona.png',
    },
    {
      'name': 'Florence',
      'description': 'City of arts',
      'icon': 'assets/icons/florence.png',
    },
    {
      'name': 'Delhi',
      'description': 'City of color',
      'icon': 'assets/icons/delhi.png',
    },
    {
      'name': 'Dhaka',
      'description': 'City of arts',
      'icon': 'assets/icons/dhaka.png',
    },
    {
      'name': 'Istanbul',
      'description': 'City of arts',
      'icon': 'assets/icons/istanbul.png',
    },
    {
      'name': 'Egypt',
      'description': 'City of arts',
      'icon': 'assets/icons/egypt.png',
    },
    {
      'name': 'Japan',
      'description': 'City of arts',
      'icon': 'assets/icons/japan.png',
    },
  ];

  @override
  void initState() {
    super.initState();

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
                        setState(() {});
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
                      itemCount: _popularDestinations.length,
                      itemBuilder: (context, index) {
                        final destination = _popularDestinations[index];
                        return _buildDestinationItem(
                          destination['name']!,
                          destination['description']!,
                          destination['icon']!,
                          onTap: () {
                            // Handle destination selection
                            print(
                              'Selected destination: ${destination['name']}',
                            );
                            // TODO: Navigate to destination details or search results
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
    String description,
    String iconPath, {
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
                // Use a placeholder icon if the asset is not available
                child: Image.asset(
                  iconPath,
                  width: 24,
                  height: 24,
                  errorBuilder: (context, error, stackTrace) {
                    return Icon(
                      Icons.location_city,
                      color: AppColors.textSecondary.withOpacity(0.7),
                      size: 24,
                    );
                  },
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
                  if (description.isNotEmpty)
                    Text(
                      description,
                      style: TextStyle(
                        fontSize: 14,
                        color: AppColors.textSecondary.withOpacity(0.7),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
