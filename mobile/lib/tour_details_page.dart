// lib/screens/tour_detail_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_map_location_marker/flutter_map_location_marker.dart';
import 'dart:math' as math;
import 'app_colors.dart';
import 'camera_screen.dart'; // Import your camera screen

// Define a class for your waypoints
class Waypoint {
  final String title;
  final String subtitle;
  final String description;
  final LatLng location;
  final List<String> images;
  final String category; // Added category field

  Waypoint({
    required this.title,
    required this.subtitle,
    required this.description,
    required this.location,
    required this.images,
    this.category = '', // Default empty category
  });
}

class TourDetailScreen extends StatefulWidget {
  final String tourId;
  final String tourName;
  final String location;
  final double rating;
  final int reviewCount;
  final List<String> images;
  final String category;
  final String description;
  final double latitude;
  final double longitude;

  const TourDetailScreen({
    Key? key,
    required this.tourId,
    required this.tourName,
    required this.location,
    required this.rating,
    required this.reviewCount,
    required this.images,
    required this.category,
    required this.description,
    this.latitude = 40.93579072684478,
    this.longitude = 14.728316097194247,
  }) : super(key: key);

  @override
  State<TourDetailScreen> createState() => _TourDetailScreenState();
}

class _TourDetailScreenState extends State<TourDetailScreen>
    with TickerProviderStateMixin {
  String _selectedTab = 'About';
  late List<bool> _expandedWaypoints;
  int _currentImageIndex = 0;
  late PageController _pageController;
  final MapController _mapController = MapController();

  // Selected waypoint for the itinerary view
  int _selectedWaypointIndex = 0;
  int _selectedWaypointIndexMappa = 0;

  // Animation controllers
  late AnimationController _mapAnimationController;
  late Animation<double> _mapAnimation;

  // Bottom sheet controller for itinerary view
  late DraggableScrollableController _sheetController;
  double _sheetMinSize = 0.15; // Initial height ratio
  double _sheetMaxSize = 0.4; // Maximum height ratio (This will be adjusted in the Itinerario view)

  // Define your waypoints with coordinates
  final List<Waypoint> _waypoints = [
    Waypoint(
      title: 'Tappa 1',
      subtitle: 'Santuario di Montevergine',
      description:
          'Il Santuario di Montevergine è un importante complesso monastico mariano situato a circa 1.270 metri sul livello del mare, nel massiccio del Partenio, nel comune di Mercogliano (Avellino). Fondato nel 1124 da San Guglielmo da Vercelli, il santuario è oggi uno dei principali luoghi di pellegrinaggio del Sud Italia, con oltre un milione di visitatori ogni anno.',
      location: LatLng(40.93579072684478, 14.728316097194247),
      images: ['assets/montevergine.jpg', 'assets/montevergine.jpg'],
      category: 'Cultural',
    ),
    Waypoint(
      title: 'Tappa 2',
      subtitle: 'Funicolare',
      description:
          'Stazione di arrivo della funicolare.',
      location: LatLng(40.93228115205057, 14.73164203632444),
      images: [],
      category: 'Cultural',
    ),
    Waypoint(
      title: 'Tappa 3',
      subtitle: 'Postazione TV',
      description:
          'Postazione TV per il canale Monte Vergine Trocchio.',
      location: LatLng(40.93416159407318, 14.72459319140844),
      images: [],
      category: 'Historical',
    ),
    Waypoint(
      title: 'Tappa 4',
      subtitle: 'Vetta Montevergine',
      description:
          'Vetta della montagna.',
      location: LatLng(40.94001346036333, 14.724761197705648),
      images: [],
      category: 'Historical',
    ),
    Waypoint(
      title: 'Tappa 5',
      subtitle: 'Cappella dello scalzatoio',
      description:
          'Cappella Lorem ipsu dorem.',
      location: LatLng(40.9355568038218, 14.737636977690212),
      images: [],
      category: 'Religious',
    ),
  ];

  late LocationPermission _permission;
  Position? _currentPosition;

  @override
  void initState() {
    super.initState();
    _expandedWaypoints = List.generate(
      _waypoints.length,
      (index) => index == 0,
    );
    _checkLocationPermission();
    _pageController = PageController();

    // Initialize animation controllers
    _mapAnimationController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );

    _mapAnimation = CurvedAnimation(
      parent: _mapAnimationController,
      curve: Curves.easeInOut,
    );

    // Initialize bottom sheet controller
    _sheetController = DraggableScrollableController();
  }

  @override
  void dispose() {
    _pageController.dispose();
    _mapAnimationController.dispose();
    _sheetController.dispose();
    super.dispose();
  }

  Future<void> _checkLocationPermission() async {
    _permission = await Geolocator.checkPermission();
    if (_permission == LocationPermission.denied) {
      _permission = await Geolocator.requestPermission();
      if (_permission == LocationPermission.denied) {
        print('Location permissions are denied.');
        return;
      }
    }

    if (_permission == LocationPermission.deniedForever) {
      print(
        'Location permissions are permanently denied. Please enable them in settings.',
      );
      return;
    }

    _getCurrentLocation();
  }

  void _getCurrentLocation() {
    Geolocator.getPositionStream().listen((Position position) {
      if (mounted) {
        setState(() {
          _currentPosition = position;
        });
      }
    });
  }

  void _centerMap(LatLng latLng) {
    _mapController.move(latLng, _mapController.camera.zoom);
  }

  // Method to build a waypoint marker for the map view
  Marker _buildWaypointMarker(
    int index,
    Waypoint waypoint, {
    bool isItineraryView = false,
  }) {
    final bool isSelected = _selectedWaypointIndex == index && isItineraryView;
    final bool isSelectedMappa = _selectedWaypointIndexMappa == index && !isItineraryView;


    return Marker(
      point: waypoint.location,
      width: 60, // Increased size for better tapping
      height: 60, // Increased size for better tapping
      child: GestureDetector(
        onTap: () {
          print('Tapped on Waypoint ${index + 1}');
          _centerMap(waypoint.location);

          if (!isItineraryView) {
            setState(() {
              _selectedWaypointIndexMappa = index;
            });
            // Animate the bottom sheet to show more details
            // We can adjust the sheet size based on the selected waypoint if needed,
            // but for now, let's rely on the snap points.
            _sheetController.animateTo(
              _sheetMinSize + 0.25,
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOut,
            );
          } else {
            setState(() {
              _selectedWaypointIndex = index;
              for (int i = 0; i < _expandedWaypoints.length; i++) {
                _expandedWaypoints[i] = (i == index);
              }
            });
          }
        },
        child: Stack(
          children: [
            // Shadow for depth
            if (isItineraryView)
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Container(
                  height: 4,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.3),
                        blurRadius: 8,
                        spreadRadius: 1,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                ),
              ),

            // Marker container
            Container(
              width: isSelectedMappa ? 60 : (isSelected ? 52 :(isItineraryView ? 40 : 32)),
              height: isSelectedMappa ? 60 : (isSelected ? 52 : (isItineraryView ? 40 : 32)),
              decoration: BoxDecoration(
                color: isSelected | isSelectedMappa ? Colors.green.withOpacity(0.5) : AppColors.primary.withOpacity(0.5),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Center(
                child: Text(
                  '${index + 1}',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: isSelectedMappa ? 25 : (isSelected ? 22 : (isItineraryView ? 16 : 14)),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Build image gallery indicator dots
  Widget _buildImageIndicator() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(
        widget.images.length,
        (index) => Container(
          width: 8,
          height: 8,
          margin: const EdgeInsets.symmetric(horizontal: 4),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color:
                _currentImageIndex == index
                    ? AppColors.primary
                    : Colors.white.withOpacity(0.5),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;

    // Conditionally render the content based on the selected tab
    Widget mainContent;
    if (_selectedTab == 'Mappa') {
      // Mappa view: Full-screen map with a draggable sheet on top
      mainContent = Stack(
        children: [
          // Full-screen map
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter:
                  // _waypoints[0].location, // Start with first waypoint
                  _currentPosition != null ? LatLng(_currentPosition!.latitude, _currentPosition!.longitude) : _waypoints[0].location,
              initialZoom: 13.0,
              interactionOptions: const InteractionOptions(
                flags: InteractiveFlag.all,
              ),
            ),
            children: [
              // Base map layer
              TileLayer(
                urlTemplate:
                    'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.example.app',
              ),

              // Waypoint markers
              MarkerLayer(
                markers:
                    _waypoints.asMap().entries.map((entry) {
                      int index = entry.key;
                      Waypoint waypoint = entry.value;
                      return _buildWaypointMarker(
                        index,
                        waypoint,
                        isItineraryView: false,
                      );
                    }).toList(),
              ),

              // Current location marker
              if (_currentPosition != null)
                CurrentLocationLayer(
                  style: LocationMarkerStyle(
                    marker: Container(
                      decoration: BoxDecoration(
                        color: Colors.blue.withOpacity(0.6),
                        shape: BoxShape.circle,
                      ),
                      padding: const EdgeInsets.all(8),
                      child: const Center(
                        child: Icon(
                          Icons.person_pin_circle,
                          color: Colors.white,
                          size: 18,
                        ),
                      ),
                    ),
                    markerSize: const Size.square(40),
                    accuracyCircleColor: Colors.blue.withOpacity(0.3),
                    headingSectorColor: Colors.blue.withOpacity(0.8),
                  ),
                ),
            ],
          ),

          // Back button (positioned on top of the map)
          Positioned(
            top: MediaQuery.of(context).padding.top - 15,
            left: 16,
            child: Container(
              width: screenWidth * 0.15,
              height: screenHeight * 0.07,
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: IconButton(
                icon: const Icon(
                  Icons.arrow_back,
                  color: AppColors.textPrimary,
                  size: 28,
                ),
                onPressed: () {
                  // Go back to previous screen or tab
                  setState(() {
                    _selectedTab = 'About'; // Or 'Mappa' depending on desired flow
                  });
                  _mapAnimationController.reverse();
                },
              ),
            ),
          ),

          Positioned(
            top: MediaQuery.of(context).padding.top - 15,
            right: 16,
            child: Container(
              width: screenWidth * 0.15,
              height: screenHeight * 0.07,
              decoration: BoxDecoration(
                color: Colors.blue.shade700,
                shape: BoxShape.circle,
              ),
              child: IconButton(
                icon: const Icon(Icons.camera_alt, color: Colors.white, size: 28,),
                onPressed: () {
                  // TODO: Camera functionality
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => ARCameraScreen()),
                  );
                  print(
                    'Open camera for AR at waypoint ${_selectedWaypointIndex + 1}',
                  );
                },
              ),
            ),

          ),


          // Bottom sheet with waypoint info
          DraggableScrollableSheet(
            controller: _sheetController, // Attach the controller
            initialChildSize: _sheetMinSize, // Start with 15% of screen height
            minChildSize: 0.1, // Can collapse to 10% of screen height
            maxChildSize: 1.0, // Can expand to FULL screen height (100%)
            snap: true, // Snap to specific sizes
            snapSizes: const [
              0.1,
              0.3,
              0.6,
              1.0,
            ], // Snap points including full screen
            builder: (context, scrollController) {
              final selectedWaypoint =
                  _waypoints[_selectedWaypointIndexMappa];

              return Container(
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(
                    top: Radius.circular(20),
                  ),
                ),
                child: CustomScrollView(
                  controller: scrollController,
                  slivers: [
                    // Handle indicator and header (always visible)
                    SliverToBoxAdapter(
                      child: Column(
                        children: [
                          // Handle indicator
                          Center(
                            child: Container(
                              margin: const EdgeInsets.only(
                                top: 12,
                                bottom: 8,
                              ),
                              width: 40,
                              height: 4,
                              decoration: BoxDecoration(
                                color: Colors.grey.withOpacity(0.3),
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                          ),

                          // Waypoint header
                          Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Row(
                              children: [
                                // Waypoint image
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(
                                    12,
                                  ),
                                  child: Image.asset(
                                    selectedWaypoint.images.isNotEmpty
                                        ? selectedWaypoint.images[0]
                                        : 'assets/montevergine.jpg', // Fallback image
                                    width: 80,
                                    height: 80,
                                    fit: BoxFit.cover,
                                  ),
                                ),
                                const SizedBox(width: 16),

                                // Waypoint info
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        selectedWaypoint.category,
                                        style: const TextStyle(
                                          fontSize: 14,
                                          color:
                                              AppColors.textSecondary,
                                        ),
                                      ),
                                      Text(
                                        selectedWaypoint.subtitle,
                                        style: const TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                          color: AppColors.textPrimary,
                                        ),
                                      ),
                                      Text(
                                        'Tap on markers to navigate',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey.shade600,
                                          fontStyle: FontStyle.italic,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),

                          // Divider
                          Divider(
                            height: 1,
                            thickness: 1,
                            color: Colors.grey.withOpacity(0.2),
                          ),
                        ],
                      ),
                    ),

                    // Expanded content (visible when sheet is dragged up)
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Description section
                            const Text(
                              'Description',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              selectedWaypoint.description,
                              style: const TextStyle(
                                fontSize: 16,
                                height: 1.5,
                                color: AppColors.textSecondary,
                              ),
                            ),

                            const SizedBox(height: 24),

                            // Tour progress
                            const Text(
                              'Tour Progress',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Waypoint ${_selectedWaypointIndex + 1} of ${_waypoints.length}',
                              style: const TextStyle(
                                fontSize: 14,
                                color: AppColors.textSecondary,
                              ),
                            ),
                            const SizedBox(height: 8),

                            // Progress bar
                            Container(
                              height: 8,
                              decoration: BoxDecoration(
                                color: Colors.grey.shade200,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width:
                                        MediaQuery.of(
                                          context,
                                        ).size.width *
                                        (_selectedWaypointIndex + 1) /
                                        _waypoints.length *
                                        0.9, // Adjusted width calculation
                                    decoration: BoxDecoration(
                                      color: AppColors.primary,
                                      borderRadius:
                                          BorderRadius.circular(4),
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            const SizedBox(height: 24),

                            // Photos section
                            if (selectedWaypoint.images.isNotEmpty) ...[
                              const Text(
                                'Photos',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              const SizedBox(height: 12),
                              SizedBox(
                                height: 200,
                                child: ListView.builder(
                                  scrollDirection: Axis.horizontal,
                                  itemCount:
                                      selectedWaypoint.images.length,
                                  itemBuilder: (context, index) {
                                    return Padding(
                                      padding: const EdgeInsets.only(
                                        right: 12,
                                      ),
                                      child: ClipRRect(
                                        borderRadius:
                                            BorderRadius.circular(12),
                                        child: Image.asset(
                                          selectedWaypoint
                                              .images[index],
                                          width: 250,
                                          height: 200,
                                          fit: BoxFit.cover,
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ),
                              const SizedBox(height: 24),
                            ],

                            // Navigation buttons
                            Row(
                              mainAxisAlignment:
                                  MainAxisAlignment.spaceBetween,
                              children: [
                                ElevatedButton.icon(
                                  onPressed:
                                      _selectedWaypointIndex > 0
                                          ? () {
                                            setState(() {
                                              _selectedWaypointIndex--;
                                              _centerMap(
                                                _waypoints[_selectedWaypointIndex]
                                                    .location,
                                              );
                                            });
                                          }
                                          : null,
                                  icon: const Icon(Icons.arrow_back),
                                  label: const Text('Previous'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppColors.primary,
                                    foregroundColor: Colors.white,
                                    disabledBackgroundColor:
                                        Colors.grey.shade300,
                                    disabledForegroundColor:
                                        Colors.grey.shade500,
                                  ),
                                ),
                                ElevatedButton.icon(
                                  onPressed:
                                      _selectedWaypointIndex <
                                              _waypoints.length - 1
                                          ? () {
                                            setState(() {
                                              _selectedWaypointIndex++;
                                              _centerMap(
                                                _waypoints[_selectedWaypointIndex]
                                                    .location,
                                              );
                                            });
                                          }
                                          : null,
                                  icon: const Icon(Icons.arrow_forward),
                                  label: const Text('Next'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppColors.primary,
                                    foregroundColor: Colors.white,
                                    disabledBackgroundColor:
                                        Colors.grey.shade300,
                                    disabledForegroundColor:
                                        Colors.grey.shade500,
                                  ),
                                ),
                              ],
                            ),

                            // Additional information
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  )
                ],
              );
    } else {
      // About and Mappa views: Standard scrollable content
      mainContent = SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(), // Enable scrolling for these tabs
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image gallery with pagination
            Stack(
              children: [
                // Image gallery
                SizedBox(
                  height: 300,
                  width: double.infinity,
                  child: PageView.builder(
                    controller: _pageController,
                    itemCount: widget.images.length,
                    onPageChanged: (index) {
                      setState(() {
                        _currentImageIndex = index;
                      });
                    },
                    itemBuilder: (context, index) {
                      return Image.asset(
                        widget.images[index],
                        fit: BoxFit.cover,
                      );
                    },
                  ),
                ),

                // Status bar area
                Container(
                  height: MediaQuery.of(context).padding.top,
                  color: Colors.transparent,
                ),

                // Back button
                Positioned(
                  top: MediaQuery.of(context).padding.top - 15,
                  left: 16,
                  child: Container(
                    width: screenWidth * 0.15,
                    height: screenHeight * 0.07,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: IconButton(
                      icon: const Icon(
                        Icons.arrow_back,
                        color: AppColors.textPrimary,
                        size: 28
                      ),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ),
                ),

                // Image counter
                Positioned(
                  bottom: 16,
                  right: 16,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.6),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text(
                      '${_currentImageIndex + 1}/${widget.images.length}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),

                // Image indicator dots
                Positioned(
                  bottom: 16,
                  left: 0,
                  right: 0,
                  child: _buildImageIndicator(),
                ),
              ],
            ),

            // Category, title, and rating
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.category,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      Row(
                        children: [
                          ...List.generate(5, (index) {
                            if (index < widget.rating.floor()) {
                              return const Icon(
                                Icons.star,
                                color: Colors.amber,
                                size: 18,
                              );
                            } else if (index < widget.rating) {
                              return const Icon(
                                Icons.star_half,
                                color: Colors.amber,
                                size: 18,
                              );
                            } else {
                              return const Icon(
                                Icons.star_border,
                                color: Colors.amber,
                                size: 18,
                              );
                            }
                          }),
                          const SizedBox(width: 8),
                          Text(
                            '${widget.rating} (${widget.reviewCount.toString()})',
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                      // const SizedBox(height: 8),
                      Row(
                        children: [ 
                          Text(
                            widget.tourName,
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(width: 135),
                        ],
                      ),
                      Row(
                        children: [
                          const Icon(
                            Icons.location_on,
                            size: 16,
                            color: AppColors.textSecondary,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            widget.location,
                            style: const TextStyle(
                              fontSize: 14,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  Padding(
                    padding: const EdgeInsets.only(top: 20.0),
                    child: Center(
                      child: ElevatedButton(
                        onPressed: () {
                          // TODO: AR Guide functionality
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => ARCameraScreen(),
                            ),
                          );
                          print('Activate AR Guide');
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 30,
                            vertical: 10,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(40),
                          ),
                          elevation: 0,
                        ),
                        child: const Icon(
                          Icons.camera_alt,
                          size: 28,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Navigation tabs (Conditionally shown here)
            Padding( // Tabs are always inside the SingleChildScrollView for About/Mappa
              padding: const EdgeInsets.symmetric(horizontal: 15.0),
              child: Row(
                children: [
                  _buildNavTab(
                    icon: Icons.info_outline,
                    label: 'About',
                    isSelected: _selectedTab == 'About',
                    onTap: () {
                      setState(() {
                        _selectedTab = 'About';
                      });
                    },
                  ),
                  SizedBox(width: 10),
                  _buildNavTab(
                    icon: Icons.route_outlined,
                    label: 'Itinerario',
                    isSelected: _selectedTab == 'Itinerario',
                    onTap: () {
                      setState(() {
                        _selectedTab = 'Itinerario';
                      });
                    },
                  ),
                  SizedBox(width: 10),
                  if (widget.category != "Interno" && widget.category != "Cibo")
                    _buildNavTab(
                      icon: Icons.map_outlined,
                      label: 'Mappa',
                      // buttonColor: Color.fromARGB(255, 255, 191, 0),
                      // buttonColor: Color.fromARGB(255, 195, 247, 58),
                      buttonColor: Color.fromARGB(255, 178, 237, 197),
                      isSelected: _selectedTab == 'Mappa',
                      onTap: () {
                        setState(() {
                          _selectedTab = 'Mappa';
                        });
                        // Start the animation when switching to Mappa
                        _mapAnimationController.forward();
                      },
                    ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Content based on selected tab (About or Mappa)
            if (_selectedTab == 'About') ...[
              // Tour highlights
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Container(
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
                      const Text(
                        'Tour Highlights:',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        widget.description,
                        style: const TextStyle(
                          fontSize: 14,
                          color: AppColors.textSecondary,
                          height: 1.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              // Verified reviews section
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Text(
                          'Verified Reviews',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '(${widget.reviewCount})',
                          style: const TextStyle(
                            fontSize: 16,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          widget.rating.toString(),
                          style: const TextStyle(
                            fontSize: 48,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Icon(
                                    Icons.star,
                                    color: Colors.amber,
                                    size: 18,
                                  ),
                                  const Icon(
                                    Icons.star,
                                    color: Colors.amber,
                                    size: 18,
                                  ),
                                  const Icon(
                                    Icons.star,
                                    color: Colors.amber,
                                    size: 18,
                                  ),
                                  const Icon(
                                    Icons.star,
                                    color: Colors.amber,
                                    size: 18,
                                  ),
                                  const Icon(
                                    Icons.star_half,
                                    color: Colors.amber,
                                    size: 18,
                                  ),
                                ],
                              ),
                              Text(
                                'Based on ${widget.reviewCount} Reviews',
                                style: const TextStyle(
                                  fontSize: 14,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _buildReviewItem(
                      name: 'Gorgia',
                      date: 'Oct 24, 2024',
                      rating: 4.2,
                      comment:
                          'The tour schedule was nicely arranged, yet we felt rushed and couldn\'t fully savor our time at Disneyland. It would have been...',
                      imageUrl: "",
                    ),
                    const SizedBox(height: 16),
                    _buildReviewItem(
                      name: 'John',
                      date: 'Oct 24, 2024',
                      rating: 4.8,
                      comment:
                          'The historical sites were breathtaking, but the queues were long and it was...',
                      imageUrl: "",
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton(
                        onPressed: () {},
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: AppColors.primary),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              'More',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: AppColors.primary,
                              ),
                            ),
                            SizedBox(width: 4),
                            Icon(
                              Icons.keyboard_arrow_down,
                              size: 20,
                              color: AppColors.primary,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ] else if (_selectedTab == 'Itinerario') ...[
              if (widget.category != "Interno" && widget.category != "Cibo")
                // Interactive Map view using flutter_map
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Container(
                    height: 300, // Fixed height for the map in Mappa tab
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: FlutterMap(
                        mapController: _mapController,
                        options: MapOptions(
                          initialCenter: _waypoints[0].location,
                          initialZoom: 13.0,
                          interactionOptions: const InteractionOptions(
                            flags: InteractiveFlag.all,
                          ),
                        ),
                        children: [
                          // Base map layer
                          TileLayer(
                            urlTemplate:
                                'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                            userAgentPackageName: 'com.example.app',
                          ),

                          // Current location marker
                          if (_currentPosition != null)
                            CurrentLocationLayer(
                              style: LocationMarkerStyle(
                                marker: Container(
                                  decoration: BoxDecoration(
                                    color: AppColors.primary.withOpacity(0.6),
                                    shape: BoxShape.circle,
                                  ),
                                  padding: const EdgeInsets.all(8),
                                  child: const Center(
                                    child: Icon(
                                      Icons.person_pin_circle,
                                      color: Colors.white,
                                      size: 18,
                                    ),
                                  ),
                                ),
                                markerSize: const Size.square(40),
                                accuracyCircleColor: AppColors.primary
                                    .withOpacity(0.3),
                                headingSectorColor: AppColors.primary
                                    .withOpacity(0.8),
                              ),
                            ),

                          // Waypoints markers
                          MarkerLayer(
                            markers:
                                _waypoints.asMap().entries.map((entry) {
                                  int index = entry.key;
                                  Waypoint waypoint = entry.value;
                                  return _buildWaypointMarker(
                                    index,
                                    waypoint,
                                    isItineraryView: true,
                                  );
                                }).toList(),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

              // Waypoints list
              ..._waypoints.asMap().entries.map((entry) {
                int index = entry.key;
                Waypoint waypoint = entry.value;
                return _buildWaypointItem(
                  index: index,
                  title: waypoint.title,
                  subtitle: waypoint.subtitle,
                  description: waypoint.description,
                  images: waypoint.images,
                  tourCategory: widget.category,
                );
              }).toList(),
            ],

            // Add space at the bottom for non-Itinerario tabs
            const SizedBox(height: 40),
          ],
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white, // o AppColors.background
        toolbarHeight: 0.1,
      ),
      body: mainContent, // Directly use the conditionally rendered content
    );
  }

  Widget _buildNavTab({
    required IconData icon,
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
    Color? buttonColor,
  }) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: buttonColor ?? (isSelected ? AppColors.primary : Colors.transparent),
            // color: isSelected ? AppColors.primary : Colors.transparent,
            borderRadius: BorderRadius.circular(24),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 20,
                color:
                    buttonColor != null
                        ? Colors.black
                        : (isSelected ? Colors.black : AppColors.textSecondary),
              ),
              const SizedBox(width: 8),
                Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  color: buttonColor != null
                    ? Colors.black
                    : (isSelected ? Colors.black : AppColors.textSecondary),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildWaypointItem({
    required int index,
    required String title,
    required String subtitle,
    required String description,
    required List<String> images,
    required String tourCategory,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Column(
        children: [
          // Waypoint header with 3D effect
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.08),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () {
                  setState(() {
                    _expandedWaypoints[index] = !_expandedWaypoints[index];
                    _selectedWaypointIndex = index;
                    if (_selectedTab == 'Itinerario' && (tourCategory != "Interno" && tourCategory != "Cibo")) {
                      // Center map on waypoint when expanded in Mappa tab
                      _centerMap(_waypoints[index].location);
                    }
                  });
                },
                borderRadius: BorderRadius.circular(12),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16.0,
                    vertical: 16.0,
                  ),
                  child: Row(
                    children: [
                      // Waypoint number with primary color
                      Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 1.5),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.2),
                              blurRadius: 3,
                              offset: const Offset(0, 1),
                            ),
                          ],
                        ),
                        child: Center(
                          child: Text(
                            '${index + 1}',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),

                      // Waypoint name with secondary color
                      Expanded(
                        child: Text(
                          subtitle, // Using subtitle for waypoint name
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ),

                      // Expand/collapse icon
                      Icon(
                        _expandedWaypoints[index]
                            ? Icons.keyboard_arrow_up
                            : Icons.keyboard_arrow_down,
                        color: AppColors.textSecondary,
                        size: 24,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // Waypoint content (expanded) with 3D effect
          if (_expandedWaypoints[index])
            Container(
              margin: const EdgeInsets.fromLTRB(16.0, 0, 16.0, 8.0),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.08),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Description
                    Text(
                      description,
                      style: const TextStyle(
                        fontSize: 14,
                        color: AppColors.textSecondary,
                        height: 1.5,
                      ),
                    ),

                    // Images (if any)
                    if (images.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 16.0),
                        child: SizedBox(
                          height: 100,
                          child: ListView.builder(
                            scrollDirection: Axis.horizontal,
                            itemCount: images.length,
                            itemBuilder: (context, imageIndex) {
                              return Padding(
                                padding: const EdgeInsets.only(right: 8.0),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(8.0),
                                  child: Image.asset(
                                    images[imageIndex],
                                    height: 100,
                                    width: 150,
                                    fit: BoxFit.cover,
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

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
}
