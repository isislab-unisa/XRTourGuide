import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // Import for SystemChrome
import "package:splash_master/splash_master.dart"; // Import for SplashMaster

// Import the external files
import 'app_colors.dart';
import 'travel_list_item_card.dart';
import 'tour_details_page.dart';
import "category_detail_screen.dart";
import "search_screen.dart";
import 'main.dart';
import 'user_profile.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SplashMaster.initialize();
  // Ensure the status bar is transparent and the UI can extend behind it
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.black, // Make status bar transparent
      statusBarIconBrightness:
          Brightness.dark, // Set icons to dark for light backgrounds
      statusBarBrightness:
          Brightness.light, // Set brightness for iOS status bar
    ),
  );
    SplashMaster.resume();

  runApp(const MyApp());
}

// The root of your application.
// class MyApp extends StatelessWidget {
//   const MyApp({Key? key}) : super(key: key);

//   @override
//   Widget build(BuildContext context) {
//     return MaterialApp(
//       // Application title, shown in the task switcher.
//       title: 'Travel Explorer UI',
//       // Hide the debug banner in the corner.
//       debugShowCheckedModeBanner: false,
//       // Define the application's theme.
//       theme: ThemeData(
//         primarySwatch: Colors.blue, // Primary color for the app
//         // Adaptive visual density helps widgets look good on different platforms.
//         visualDensity: VisualDensity.adaptivePlatformDensity,
//         // Set the primary color to our app's primary color
//         primaryColor: AppColors.primary,
//         // Set the accent color to our app's accent color
//         colorScheme: ColorScheme.fromSwatch().copyWith(
//           secondary: AppColors.accent,
//         ),
//       ),
//       // The home screen of the application.
//       home: const TravelExplorerScreen(),
//     );
//   }
// }

// The main screen widget, a StatelessWidget as the content is static for this example.
class TravelExplorerScreen extends StatelessWidget {
  const TravelExplorerScreen({Key? key}) : super(key: key);

  // Extracted method for creating a category item with customizable name and image
  Widget buildCategoryItem({
    required BuildContext context,
    required int index,
    required double width,
    required String categoryName,
    required String imagePath,
    EdgeInsets? margin,
  }) {
    // Sample tour data for this category
    final List<Map<String, dynamic>> categoryTours = [
      {
        'imagePath': 'assets/acquedotto.jpg',
        'title': 'Exploring the Wonders of Sri Lanka',
        'subcategory': 'Outdoor Adventures',
        'rating': 4.8,
        'reviewCount': 1550,
        'hasBadge': false,
        'isFavorite': false,
      },
      {
        'imagePath': 'assets/acquedotto.jpg',
        'title': 'Alpine Europe in 12 Days',
        'subcategory': 'Nature',
        'rating': 4.7,
        'reviewCount': 1250,
        'hasBadge': false,
        'isFavorite': false,
      },
      {
        'imagePath': 'assets/acquedotto.jpg',
        'title': 'Self-Guided Hiking Tours',
        'subcategory': 'Nature',
        'rating': 4.5,
        'reviewCount': 800,
        'hasBadge': false,
        'isFavorite': false,
      },
      {
        'imagePath': 'assets/acquedotto.jpg',
        'title': 'Provence Lavender Tours',
        'subcategory': 'Outdoor Adventures',
        'rating': 4.3,
        'reviewCount': 900,
        'hasBadge': false,
        'isFavorite': false,
      },
      {
        'imagePath': 'assets/acquedotto.jpg',
        'title': 'Cycling Austria Tour',
        'subcategory': 'Sport & Adventures',
        'rating': 4.0,
        'reviewCount': 70,
        'hasBadge': true,
        'isFavorite': true,
      },
    ];

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder:
                (context) => CategoryDetailScreen(
                  categoryName: categoryName,
                  tours: categoryTours,
                ),
          ),
        );
      },
      child: Container(
        // Responsive width for each category item.
        width: width,
        // Add left margin to the first item and right margin to all items.
        margin:
            margin ??
            EdgeInsets.only(left: index == 0 ? 20.0 : 0.0, right: 10.0),
        decoration: BoxDecoration(
          // Rounded corners for the container.
          borderRadius: BorderRadius.circular(10.0),
          // Use the provided image path for the background
          image: DecorationImage(
            image: AssetImage(imagePath),
            fit: BoxFit.cover,
          ),
        ),
        // Use a Stack to place text on top of the background.
        child: Stack(
          children: [
            // Add a dark overlay to make text more readable on top of images.
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10.0),
                  color:
                      AppColors.darkOverlay, // Using AppColors for the overlay
                ),
              ),
            ),
            // Center the category name text.
            Center(
              child: Text(
                categoryName, // Use the provided category name
                style: const TextStyle(
                  color:
                      Colors
                          .white, // Text color for readability on dark overlay
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // MediaQuery provides information about the device's screen size and other properties.
    // We use this to make the layout responsive.
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;

    final List<Map<String, String>> categories = [
      {'name': 'Natura', 'image': 'assets/natura_categoria.jpg'},
      {'name': 'Città', 'image': 'assets/citta_categoria.jpg'},
      {'name': 'Cultura', 'image': 'assets/wine_category.jpg'},
      {'name': 'Cibo', 'image': 'assets/cibo_example.jpg'},
    ];

    return Scaffold(
      // Extends the body to be behind the app bar. This is crucial for the
      // image to go all the way to the top of the screen, under the status bar.
      extendBodyBehindAppBar: false,
      // App Bar White to avoid confusion with the background image.
      appBar: AppBar(
          title: Text(
            "XRTOURGUIDE",
            style: TextStyle(
              fontSize: screenWidth * 0.06,
              fontWeight: FontWeight.bold,
              fontFamily: "point_panther", // opzionale, se vuoi il font custom
            ),
          ),
          backgroundColor: Colors.white, // o AppColors.background
          foregroundColor: Colors.black, // colore testo/icona
          elevation: 0, // nessuna ombra, stile moderno
          centerTitle: true, // titolo centrato
        ),
      // The main content of the screen. Wrapped in SingleChildScrollView to make it scrollable.
      body: SingleChildScrollView(
        // Arrange children vertically.
        child: Column(
          // Align children to the start (left) of the column.
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Area for the background image at the top with the title bar
            Stack(
              children: [
                // Background image container
                Container(
                  // Set height as a fraction of the screen height for responsiveness.
                  height: screenHeight * 0.25, // Takes up 30% of screen height
                  // Set width to the full screen width.
                  width: screenWidth,
                  decoration: const BoxDecoration(
                    image: DecorationImage(
                      image: AssetImage(
                        'assets/background_app.jpg',
                      ), // Placeholder asset path
                      fit: BoxFit.cover, // Cover the entire container area
                    ),
                  ),
                  child: Stack(
                    // Stack allows placing widgets on top of each other.
                    children: [
                      // Optional: Add a gradient overlay to blend the image with the content below.
                      Positioned.fill(
                        // Positioned.fill makes this container fill the parent Stack.
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Colors.transparent, // Start with transparent
                                AppColors
                                    .lightOverlay, // Using AppColors for semi-transparent white
                                AppColors
                                    .background, // Using AppColors for white background
                              ],
                              // Stops define where each color in the gradient is at.
                              stops: const [
                                0.6,
                                0.8,
                                1.0,
                              ], // Gradient effect starts at 60%, ends at 100%
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Title bar that scrolls with content
                // Positioned(
                //   top:
                //       MediaQuery.of(context).padding.top +
                //       20, // Add padding for status bar
                //   left: 0,
                //   right: 0,
                //   child: Padding(
                //     padding: const EdgeInsets.symmetric(horizontal: 20.0),
                //     child: Container(
                //       // Wrap the Row in a Container for the semi-transparent panel
                //       padding: const EdgeInsets.symmetric(
                //         vertical: 8.0,
                //         horizontal: 12.0,
                //       ),
                //       child: SizedBox(
                //         height: screenHeight * 0.225,
                //         child: Column(
                //           mainAxisAlignment: MainAxisAlignment.end,
                //           children: [
                //             Text(
                //               "XRTOURGUIDE",
                //               style: TextStyle(
                //                 fontSize: screenWidth * 0.08,
                //                 fontWeight: FontWeight.bold,
                //                 color: Colors.black.withOpacity(0.8),
                //                 fontFamily: "point_panther",
                //               ),
                //             ),
                //           ],
                //         ),
                //       ),
                //     ),
                //   ),
                // ),
              ],
            ),

            // Search Bar Section.
            Padding(
              // Add horizontal and vertical padding around the search bar.
              padding: const EdgeInsets.symmetric(
                horizontal: 20.0,
                vertical: 10.0,
              ),
              // child: TextField(
              //   decoration: InputDecoration(
              //     hintText: 'What do you want to see?', // Placeholder text
              //     prefixIcon: Icon(
              //       Icons.search,
              //       color:
              //           AppColors
              //               .textSecondary, // Using AppColors for icon color
              //     ), // Search icon at the beginning
              //     // Define the border style. OutlineInputBorder creates a border around the field.
              //     border: OutlineInputBorder(
              //       borderRadius: BorderRadius.circular(
              //         30.0,
              //       ), // Rounded corners
              //       borderSide: BorderSide.none, // No visible border line
              //     ),
              //     filled: true, // Fill the background with a color
              //     fillColor:
              //         AppColors
              //             .searchBarBackground, // Using AppColors for search bar background
              //     // Adjust content padding inside the TextField.
              //     contentPadding: const EdgeInsets.symmetric(
              //       vertical: 0,
              //       horizontal: 20,
              //     ),
              //   ),
              // ),
              child: GestureDetector(
                onTap: () {
                  // Navigate to the search screen with a page route animation
                  Navigator.of(context).push(
                    PageRouteBuilder(
                      pageBuilder: (context, animation, secondaryAnimation) => const SearchScreen(),
                      transitionsBuilder: (context, animation, secondaryAnimation, child) {
                        // Define custom transition animations
                        const begin = Offset(0.0, 0.05);
                        const end = Offset.zero;
                        const curve = Curves.easeInOut;
                        
                        // Create a slide animation for the new screen
                        var slideAnimation = Tween(begin: begin, end: end).animate(
                          CurvedAnimation(parent: animation, curve: curve),
                        );
                        
                        // Create a fade animation for the new screen
                        var fadeAnimation = Tween(begin: 0.0, end: 1.0).animate(
                          CurvedAnimation(parent: animation, curve: curve),
                        );
                        
                        // Apply both animations
                        return FadeTransition(
                          opacity: fadeAnimation,
                          child: SlideTransition(
                            position: slideAnimation,
                            child: child,
                          ),
                        );
                      },
                      // Make the transition slightly faster
                      transitionDuration: const Duration(milliseconds: 250),
                    ),
                  );
                },
                // Create a non-editable search bar that looks like a TextField
                child: Container(
                  height: 50,
                  decoration: BoxDecoration(
                    color: AppColors.searchBarBackground,
                    borderRadius: BorderRadius.circular(30.0),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: Row(
                      children: [
                        Icon(
                          Icons.search,
                          color: AppColors.textSecondary,
                        ),
                        const SizedBox(width: 12),
                        Text(
                          'What do you want to see?',
                          style: TextStyle(
                            color: AppColors.textSecondary.withOpacity(0.7),
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            // Horizontal List 1: Exploring the Wonders of Sri Lanka.
            Padding(
              // Add vertical padding to separate this section.
              padding: const EdgeInsets.symmetric(vertical: 10.0),
              child: Column(
                // Align children to the start (left).
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Section Title.
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20.0,
                      vertical: 10.0,
                    ),
                    child: Text(
                      'Tours around you',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color:
                            AppColors
                                .textPrimary, // Using AppColors for text color
                      ),
                    ),
                  ),
                  // SizedBox with a fixed height for the horizontal ListView.
                  // Setting a height is necessary for a horizontal ListView within a Column.
                  SizedBox(
                    // Responsive height for the horizontal list using a fraction of screenHeight.
                    height:
                        screenHeight * 0.25, // Takes up 25% of screen height
                    // ListView.builder is used for efficient rendering of a potentially large list.
                    child: ListView.builder(
                      // Set the scroll direction to horizontal.
                      scrollDirection: Axis.horizontal,
                      // The number of items in the list. Replace with your actual data count.
                      itemCount: 5, // Example: 5 items
                      // itemBuilder creates each item in the list.
                      itemBuilder: (context, index) {
                        // Use the reusable TravelListItemCard widget.
                        return Padding(
                          // Add left padding to the first item and right padding to all items
                          // for spacing between cards.
                          padding: EdgeInsets.only(
                            left: index == 0 ? 20.0 : 0.0,
                            right: 15.0,
                          ),
                          child: TravelListItemCard(
                            // Pass dummy data or data from your model here.
                            imagePath:
                                index == 0
                                    ? 'assets/montevergine.jpg'
                                    : 'assets/acquedotto.jpg', // Placeholder asset path
                            title:
                                index == 0
                                    ? 'Montevergine'
                                    : 'Destination ${index + 1}', // Placeholder title
                            description:
                                'Discover the beauty of this place.', // Placeholder description
                            cardWidth:
                                screenWidth *
                                0.6, // Responsive width for the card
                            imageHeight: 140,
                            category: "Natura",
                            rating: 4.5,
                            reviewCount: 675,

                            onTap: () {
                              // Handle card tap
                              // print('Tapped on destination ${index + 1}');
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder:
                                      (context) => TourDetailScreen(
                                        tourId: 'tour_${index + 1}',
                                        tourName:
                                            index == 0
                                                ? 'Montevergine'
                                                : 'Destination ${index + 1}',
                                        location:
                                            index == 0
                                                ? 'Avellino, Campania'
                                                : 'Location ${index + 1}',
                                        rating:
                                            index == 0
                                                ? 4.5
                                                : 4.0 + (index * 0.1),
                                        reviewCount:
                                            index == 0
                                                ? 675
                                                : 100 + (index * 25),
                                        images: [
                                            index == 0
                                                ? 'assets/montevergine.jpg'
                                                : 'assets/acquedotto.jpg',
                                              "assets/acquedotto.jpg",
                                              "assets/cibo_example.jpg",
                                        ],
                                        category:
                                            index == 0
                                                ? 'Natura'
                                                : 'Interno',
                                        description:
                                            index == 0
                                                ? 'Il Santuario di Montevergine è un importante complesso monastico mariano situato a circa 1.270 metri sul livello del mare, nel massiccio del Partenio, nel comune di Mercogliano (Avellino). Fondato nel 1124 da San Guglielmo da Vercelli, il santuario è oggi uno dei principali luoghi di pellegrinaggio del Sud Italia, con oltre un milione di visitatori ogni anno.'
                                                : 'Discover the beauty and history of this amazing destination with our guided tour.',
                                      ),
                                ),
                              );
                            },
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),

            // Horizontal Category Section (Resembling the image more closely).
            Padding(
              // Add vertical and horizontal padding.
              padding: const EdgeInsets.symmetric(
                vertical: 10.0,
                horizontal: 20.0,
              ),
              child: Row(
                // Space out the title and the "See More" button.
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Categories',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color:
                          AppColors
                              .textPrimary, // Using AppColors for text color
                    ),
                  ),
                  // Button to see more categories.
                  TextButton(
                    onPressed: () {
                      // TODO: Implement action to navigate to a categories screen.
                      print('See More Categories tapped');
                    },
                    child: Text(
                      'See More',
                      style: TextStyle(
                        color: AppColors.primary,
                      ), // Using AppColors for button text color
                    ),
                  ),
                ],
              ),
            ),
            // SizedBox with a fixed height for the horizontal list of categories.
            SizedBox(
              // Responsive height for the category list.
              height:
                  screenHeight *
                  0.12, // Adjust height as needed to fit the design
              child: ListView.builder(
                // Set scroll direction to horizontal.
                scrollDirection: Axis.horizontal,
                // Number of category items.
                itemCount: categories.length,
                itemBuilder: (context, index) {
                  // Use the extracted method to create category items with the data from our list
                  return buildCategoryItem(
                    context: context,
                    index: index,
                    width: screenWidth * 0.4,
                    categoryName: categories[index]['name']!,
                    imagePath: categories[index]['image']!,
                  );
                },
              ),
            ),

            // Horizontal List 2: A modern culinary Journey.
            Padding(
              // Add vertical padding.
              padding: const EdgeInsets.symmetric(vertical: 10.0),
              child: Column(
                // Align children to the start (left).
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Section Title.
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20.0,
                      vertical: 10.0,
                    ),
                    child: Text(
                      'Cooking Tours around you',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color:
                            AppColors
                                .textPrimary, // Using AppColors for text color
                      ),
                    ),
                  ),
                  // SizedBox with a fixed height for the horizontal ListView.
                  SizedBox(
                    // Responsive height for the horizontal list.
                    height: screenHeight * 0.3, // Takes up 30% of screen height
                    child: ListView.builder(
                      // Set scroll direction to horizontal.
                      scrollDirection: Axis.horizontal,
                      // Number of items in the list. Replace with your actual data count.
                      itemCount: 4, // Example: 4 items
                      itemBuilder: (context, index) {
                        // Use the reusable TravelListItemCard widget.
                        return Padding(
                          // Add left padding to the first item and right padding to all items
                          // for spacing between cards.
                          padding: EdgeInsets.only(
                            left: index == 0 ? 20.0 : 0.0,
                            right: 15.0,
                          ),
                          child: TravelListItemCard(
                            // Pass dummy data or data from your model here.
                            imagePath:
                                'assets/cibo_example.jpg', // Placeholder asset path
                            title: 'Dish ${index + 1}', // Placeholder title
                            description:
                                'A delightful culinary experience.', // Placeholder description
                            cardWidth:
                                screenWidth *
                                0.6, // Responsive width for the card
                            imageHeight: 180,
                            category: "Cibo",
                            rating: 4.5,
                            reviewCount: 675,

                            onTap: () {
                              // Handle card tap
                              // print('Tapped on destination ${index + 1}');
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder:
                                      (context) => TourDetailScreen(
                                        tourId: 'tour_${index + 1}',
                                        tourName:
                                            index == 0
                                                ? 'Cucina Tipica'
                                                : 'Destination ${index + 1}',
                                        location:
                                            index == 0
                                                ? 'Avellino, Campania'
                                                : 'Location ${index + 1}',
                                        rating:
                                            index == 0
                                                ? 4.5
                                                : 4.0 + (index * 0.1),
                                        reviewCount:
                                            index == 0
                                                ? 675
                                                : 100 + (index * 25),
                                        images: [
                                          "assets/cibo_example.jpg",
                                        ],
                                        category: 'Cibo',
                                        description: 'Discover the beauty and history of this amazing destination with our guided tour.',
                                      ),
                                ),
                              );
                            },
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
            // You can add more sections here following the same patterns.
            // Example: Another horizontal list, a vertical list, etc.
            SizedBox(height: 20), // Add some space at the bottom
          ],
        ),
      ),
      // Bottom navigation bar.
      bottomNavigationBar: BottomNavigationBar(
        items: const <BottomNavigationBarItem>[
          // Define each item in the bottom navigation bar.
          BottomNavigationBarItem(icon: Icon(Icons.search), label: 'Explore'),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_outline),
            label: 'Profile',
          ),
        ],
        currentIndex: 0, // Index of the currently selected item (Explore).
        selectedItemColor:
            AppColors.navActive, // Using AppColors for selected item color
        unselectedItemColor:
            AppColors.navInactive, // Using AppColors for unselected item color
        showUnselectedLabels:
            true, // Show labels for items that are not selected.
        onTap: (int index) {
          // TODO: Implement navigation logic based on the tapped item index.
          print('Bottom navigation item tapped: $index');
          if (index == 0) {
            // Already on main page, do nothing or maybe pop to root if needed
            Navigator.of(context).popUntil((route) => route.isFirst);
          } else if (index == 1) {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) => UserProfileScreen(), // Make sure AuthScreen is imported
              ),
            );
          }
        },
      ),
    );
  }
}
