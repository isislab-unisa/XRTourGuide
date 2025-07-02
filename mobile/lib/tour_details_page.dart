// lib/screens/tour_detail_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_map_location_marker/flutter_map_location_marker.dart';
import 'package:xr_tour_guide/services/auth_service.dart';
import 'models/app_colors.dart';
import "models/waypoint.dart";
import 'models/review.dart';
import 'models/tour.dart';
import 'services/tour_service.dart';
import 'services/api_service.dart';
import 'camera_screen.dart'; // Import your camera screen
import 'package:url_launcher/url_launcher.dart'; // Import url_launcher
import 'review_list.dart'; // Import your review list screen
import 'package:flutter_riverpod/flutter_riverpod.dart';


class TourDetailScreen extends ConsumerStatefulWidget {
  final int tourId;
  final bool isGuest;

  const TourDetailScreen({
    Key? key,
    required this.tourId,
    required this.isGuest,
  }) : super(key: key);

  @override
  ConsumerState<TourDetailScreen> createState() => _TourDetailScreenState();
}

class _TourDetailScreenState extends ConsumerState<TourDetailScreen>
    with TickerProviderStateMixin {

  late TourService _tourService;
  late ApiService _apiService;

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

  Tour? _tourDetails;
  bool _isLoadingTourDetails = true;

  // Define your waypoints with coordinates
  List<Waypoint> _waypoints = [];
  bool _isLoadingWaypoints = true;

  List<Review> _reviews = [];
  bool _isLoadingReviews = true;

  double _userRating = 0.0;
  final TextEditingController _reviewController = TextEditingController();

  late LocationPermission _permission;
  Position? _currentPosition;

  @override
  void initState() {
    super.initState();
    _tourService = ref.read(tourServiceProvider);
    _apiService = ref.read(apiServiceProvider);
    _loadData();
    _checkLocationPermission();
    _incrementViewCount();
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

  Future<void> _loadData() async {
    // Load all data in parallel
    await Future.wait([
      _loadTourDetails(),
      _loadWaypoints(),
      _loadReviews(),
    ]);
  }

  Future<void> _incrementViewCount() async {
    try {
      await _apiService.incrementTourViews(widget.tourId);
    } catch (e) {
      print('Error incrementing view count: $e');
    }
  }

  Future<void> _loadTourDetails() async{
    try {
      final tour = await _tourService.getTourById(widget.tourId);
      if (mounted) {
        setState(() {
          _tourDetails = tour;
          _isLoadingTourDetails = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingTourDetails = false;
        });
        _showError('Error loading tour details');
      }
    }
  }

  Future<void> _loadWaypoints() async {
    try {
      final waypoints = await _tourService.getWaypointsByTour(widget.tourId);
      if (mounted) {
        setState(() {
          _waypoints = waypoints;
          _isLoadingWaypoints = false;
          _expandedWaypoints = List.generate(
            _waypoints.length,
            (index) => index == 0,
          );
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingWaypoints = false;
        });
        _showError('Error loading waypoints');
      }
    }
  }

  Future<void> _loadReviews() async {
    try {
      final reviews = await _tourService.getReviewByTour(
        tourId: widget.tourId,
        userId: 0, // Assuming 0 for guest users, adjust as needed
        max: 3,
      );
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
        });
        _showError('Error loading reviews');
      }
    }
  }


  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
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

   // Method to launch map application
  Future<void> _launchMapApp(double latitude, double longitude) async {
    final String googleMapsUrl =
        'https://www.google.com/maps/dir/?api=1&destination=$latitude,$longitude&travelmode=driving';
    final String appleMapsUrl =
        'http://maps.apple.com/?daddr=$latitude,$longitude';

    if (Theme.of(context).platform == TargetPlatform.iOS) {
      if (await canLaunchUrl(Uri.parse(appleMapsUrl))) {
        await launchUrl(Uri.parse(appleMapsUrl));
      } else {
        _showError('Could not launch Apple Maps');
      }
    } else {
      if (await canLaunchUrl(Uri.parse(googleMapsUrl))) {
        await launchUrl(Uri.parse(googleMapsUrl));
      } else {
        _showError('Could not launch Google Maps');
      }
    }
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
      point: LatLng(waypoint.latitude, waypoint.longitude),
      width: 60, // Increased size for better tapping
      height: 60, // Increased size for better tapping
      child: GestureDetector(
        onTap: () {
          print('Tapped on Waypoint ${index + 1}');
          _centerMap(LatLng(waypoint.latitude, waypoint.longitude));

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
        // _tourDetails!.images.length,
        1,
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

     if (_isLoadingTourDetails || _isLoadingWaypoints) {
      return Scaffold(
        appBar: AppBar(backgroundColor: Colors.white, toolbarHeight: 0.1),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

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
                  _currentPosition != null ? LatLng(_currentPosition!.latitude, _currentPosition!.longitude) : LatLng(_waypoints[0].latitude, _waypoints[0].longitude),
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
          
          if (widget.isGuest == false)
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
                    //Initialize the inference module for the tour
                    // _apiService.initializeInferenceModule(widget.tourId);
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => ARCameraScreen(tourId: widget.tourId, latitude: _tourDetails!.latitude, longitude: _tourDetails!.longitude)),
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
                                  child: Image.network(
                                    "${ApiService.basicUrl}/stream_minio_resource/?waypoint=${selectedWaypoint.id}&file=${selectedWaypoint.images[0]}",
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
                                        selectedWaypoint.title,
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
                            // const Text(
                            //   'Tour Progress',
                            //   style: TextStyle(
                            //     fontSize: 18,
                            //     fontWeight: FontWeight.bold,
                            //     color: AppColors.textPrimary,
                            //   ),
                            // ),
                            // const SizedBox(height: 8),
                            // Text(
                            //   'Waypoint ${_selectedWaypointIndex + 1} of ${_waypoints.length}',
                            //   style: const TextStyle(
                            //     fontSize: 14,
                            //     color: AppColors.textSecondary,
                            //   ),
                            // ),
                            // const SizedBox(height: 8),

                            // Progress bar
                            // Container(
                            //   height: 8,
                            //   decoration: BoxDecoration(
                            //     color: Colors.grey.shade200,
                            //     borderRadius: BorderRadius.circular(4),
                            //   ),
                            //   child: Row(
                            //     children: [
                            //       Container(
                            //         width:
                            //             MediaQuery.of(
                            //               context,
                            //             ).size.width *
                            //             (_selectedWaypointIndex + 1) /
                            //             _waypoints.length *
                            //             0.9, // Adjusted width calculation
                            //         decoration: BoxDecoration(
                            //           color: AppColors.primary,
                            //           borderRadius:
                            //               BorderRadius.circular(4),
                            //         ),
                            //       ),
                            //     ],
                            //   ),
                            // ),

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
                                        child: Image.network(
                                          "${ApiService.basicUrl}/stream_minio_resource/?waypoint=${selectedWaypoint.id}&file=${selectedWaypoint.images[index]}",
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
                            const SizedBox(height: 16),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton.icon(
                                onPressed:
                                    () => _launchMapApp(selectedWaypoint.latitude, selectedWaypoint.longitude),
                                icon: const Icon(Icons.navigation),
                                label: const Text('Navigate to this Waypoint'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.primary,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 12,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                              ),
                            ),

                            // Navigation buttons
                            // Row(
                            //   mainAxisAlignment:
                            //       MainAxisAlignment.spaceBetween,
                            //   children: [
                            //     ElevatedButton.icon(
                            //       onPressed:
                            //           _selectedWaypointIndex > 0
                            //               ? () {
                            //                 setState(() {
                            //                   _selectedWaypointIndex--;
                            //                   _centerMap(
                            //                     LatLng(_waypoints[_selectedWaypointIndex]
                            //                         .latitude, _waypoints[_selectedWaypointIndex].longitude)
                            //                   );
                            //                 });
                            //               }
                            //               : null,
                            //       icon: const Icon(Icons.arrow_back),
                            //       label: const Text('Previous'),
                            //       style: ElevatedButton.styleFrom(
                            //         backgroundColor: AppColors.primary,
                            //         foregroundColor: Colors.white,
                            //         disabledBackgroundColor:
                            //             Colors.grey.shade300,
                            //         disabledForegroundColor:
                            //             Colors.grey.shade500,
                            //       ),
                            //     ),
                            //     ElevatedButton.icon(
                            //       onPressed:
                            //           _selectedWaypointIndex <
                            //                   _waypoints.length - 1
                            //               ? () {
                            //                 setState(() {
                            //                   _selectedWaypointIndex++;
                            //                   _centerMap(
                            //                     LatLng(_waypoints[_selectedWaypointIndex]
                            //                         .latitude, _waypoints[_selectedWaypointIndex].longitude)
                            //                   );
                            //                 });
                            //               }
                            //               : null,
                            //       icon: const Icon(Icons.arrow_forward),
                            //       label: const Text('Next'),
                            //       style: ElevatedButton.styleFrom(
                            //         backgroundColor: AppColors.primary,
                            //         foregroundColor: Colors.white,
                            //         disabledBackgroundColor:
                            //             Colors.grey.shade300,
                            //         disabledForegroundColor:
                            //             Colors.grey.shade500,
                            //       ),
                            //     ),
                            //   ],
                            // ),

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
                    // itemCount: _tourDetails?.images.length,
                    itemCount: 1,
                    onPageChanged: (index) {
                      setState(() {
                        _currentImageIndex = index;
                      });
                    },
                    itemBuilder: (context, index) {
                      return Image.network(
                        // _tourDetails!.imagePath,
                        "${ApiService.basicUrl}/stream_minio_resource/?tour=${_tourDetails!.id}",
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
                      // '${_currentImageIndex + 1}/${_tourDetails?.images.length}',
                      '${_currentImageIndex + 1}/1',
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
              child: Column(
                children: [
                  Row(
                    children: [
                      Text(
                        "Created by ${_tourDetails?.creator}",
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        "Last edited: ${_tourDetails?.lastEdited}",
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),

                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start, // Ensures items align at the top
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              ...List.generate(5, (index) {
                                if (index < _tourDetails!.rating.floor()) {
                                  return const Icon(
                                    Icons.star,
                                    color: Colors.amber,
                                    size: 18,
                                  );
                                } else if (index < _tourDetails!.rating) {
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
                                '${_tourDetails!.rating.toStringAsFixed(1).toString()} (${_tourDetails!.reviewCount.toString()})',
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                              const SizedBox(width: 15),
                              //Eye icon
                              const Icon(
                                Icons.remove_red_eye,
                                size: 16,
                                color: AppColors.textSecondary,
                              ),
                              Text(
                                _tourDetails!.totViews.toString(),
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.textSecondary,
                                ),
                              )
                            ],
                          ),
                          // const SizedBox(height: 8),
                          Row(
                            children: [ 
                              Text(
                                _tourDetails!.title,
                                style: const TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              // const SizedBox(width: 135),
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
                                _tourDetails!.location,
                                style: const TextStyle(
                                  fontSize: 14,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),

                      const Spacer(),

                      if (widget.isGuest == false)
                        Padding(
                          padding: const EdgeInsets.only(top: 20.0),
                          child: Center(
                            child: ElevatedButton(
                              onPressed: () {
                                // TODO: AR Guide functionality
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => ARCameraScreen(tourId: widget.tourId, latitude: _tourDetails!.latitude, longitude: _tourDetails!.longitude),
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
                  if (_tourDetails!.category != "Interno" && _tourDetails!.category != "Cibo")
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
                        _tourDetails!.description,
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
                            fontSize: 23,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '(${_tourDetails!.reviewCount})',
                          style: const TextStyle(
                            fontSize: 16,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        const Spacer(),
                        IconButton(
                          onPressed: () {
                            _showLeaveReviewSheet(_tourDetails!.id);
                          },
                          icon: Icon(
                            Icons.add_circle,
                            color: AppColors.primary,
                            size: 60,
                            ),
                          )
                      ],
                    ),
                    // const SizedBox(height: 4),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          _tourDetails!.rating.toStringAsFixed(1).toString(),
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
                                'Based on ${_tourDetails!.reviewCount} Reviews',
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
                    //load the first two elements from _reviews
                    if (_isLoadingReviews)
                      const Center(child: CircularProgressIndicator())
                    else
                      ListView.builder(
                        shrinkWrap: true,
                        physics: NeverScrollableScrollPhysics(),
                        itemCount: _reviews.length,
                        itemBuilder: (context, index) {
                          return _buildReviewItem(
                            name: _reviews[index].user,
                            date: _reviews[index].date,
                            rating: _reviews[index].rating,
                            comment: _reviews[index].comment,
                          );
                        },
                      ),
                      const SizedBox(height: 16),
                    //  ...[
                    //   _buildReviewItem(
                    //     name: _reviews[0].user,
                    //     date: _reviews[0].date,
                    //     rating: _reviews[0].rating,
                    //     comment: _reviews[0].comment,
                    //   ),
                    //   const SizedBox(height: 16),
                    //   _buildReviewItem(
                    //     name: _reviews[1].user,
                    //     date: _reviews[1].date,
                    //     rating: _reviews[1].rating,
                    //     comment: _reviews[1].comment,
                    //   ),
                    //   const SizedBox(height: 16),
                    // ],
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => ReviewListScreen(
                                tourName: _tourDetails!.title,
                                tourId: widget.tourId,
                                isTour: true,
                                reviewCount: _tourDetails!.reviewCount,
                              ),
                            ),
                          );
                        },
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
              if (_tourDetails!.category != "INSIDE" && _tourDetails!.category != "Cibo")
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
                          initialCenter: LatLng(_waypoints[0].latitude, _waypoints[0].longitude),
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
                  waypointIndex: waypoint.id,
                  index: index,
                  title: waypoint.title,
                  subtitle: waypoint.subtitle,
                  description: waypoint.description,
                  images: waypoint.images,
                  tourCategory: _tourDetails!.category,
                  latitude: waypoint.latitude,
                  longitude: waypoint.longitude,
                  subWaypoints: waypoint.subWaypoints,
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
    required int waypointIndex,
    required int index,
    required String title,
    required String subtitle,
    required String description,
    required List<String> images,
    required String tourCategory,
    required double latitude,
    required double longitude,
    List<Waypoint>? subWaypoints,
    int? parentIndex,
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

                    for (int i = 0; i < _expandedWaypoints.length; i++) {
                      if (i != index) {
                        _expandedWaypoints[i] = false; // Collapse other waypoints
                      }
                    }

                    _expandedWaypoints[index] = !_expandedWaypoints[index];
                    _selectedWaypointIndex = index;
                    if (_selectedTab == 'Itinerario' && (tourCategory != "INSIDE" && tourCategory != "Cibo")) {
                      // Center map on waypoint when expanded in Mappa tab
                      _centerMap(LatLng(_waypoints[index].latitude, _waypoints[index].longitude));
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
                            tourCategory != "nested" ? '${index + 1}' : '${parentIndex! + 1}.${index + 1}',
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
                          title, // Using subtitle for waypoint name
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
                                  child: Image.network(
                                    //TODO: image from network
                                    "${ApiService.basicUrl}/stream_minio_resource/?waypoint=${waypointIndex}&file=${images[imageIndex]}",
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
                    // Navigate button
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () => _launchMapApp(latitude, longitude),
                        icon: const Icon(Icons.navigation),
                        label: const Text('Navigate to this Waypoint'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    ),
                    // Sub-waypoints (if any) devono avere indici secondari
                    if (subWaypoints != null && subWaypoints.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(left: 24.0, top: 8.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children:
                              subWaypoints.asMap().entries.map((entry) {
                                int subIndex = entry.key;
                                Waypoint sub = entry.value;
                                return _buildWaypointItem(
                                  waypointIndex: sub.id,
                                  index: subIndex,
                                  title: sub.title,
                                  subtitle: sub.subtitle,
                                  description: sub.description,
                                  images: sub.images,
                                  tourCategory: "nested",
                                  latitude: sub.latitude,
                                  longitude: sub.longitude,
                                  subWaypoints: sub.subWaypoints,
                                  parentIndex: index
                                );
                              }).toList(),                        
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
                      rating.toStringAsFixed(1).toString(),
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
          // GestureDetector(
          //   onTap: () {},
          //   child: const Text(
          //     'Read more',
          //     style: TextStyle(
          //       fontSize: 14,
          //       fontWeight: FontWeight.bold,
          //       color: AppColors.primary,
          //     ),
          //   ),
          // ),
        ],
      ),
    );
  }

void _showLeaveReviewSheet(int tourId) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true, // Allows the sheet to be scrollable
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        // Use a StatefulBuilder to manage the state of the stars within the sheet
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
                left: 16,
                right: 16,
                top: 16,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade300,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Center(
                      child: Text(
                        'Leave a Review',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Star rating
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(5, (index) {
                        return IconButton(
                          onPressed: () {
                            setState(() {
                              _userRating = index + 1.0;
                            });
                          },
                          icon: Icon(
                            index < _userRating
                                ? Icons.star
                                : Icons.star_border,
                            color: Colors.amber,
                            size: 55,
                          ),
                        );
                      }),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Comments:',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    // Comments text field
                    Container(
                      decoration: BoxDecoration(
                        color:
                            Colors.white, // Background color of the container
                        borderRadius: BorderRadius.circular(
                          10.0,
                        ), // Optional: rounded corners for the container
                        boxShadow: [
                          BoxShadow(
                            color: Colors.grey.withOpacity(
                              0.5,
                            ), // Color of the shadow
                            spreadRadius:
                                1, // How much the shadow should spread
                            blurRadius: 3, // How blurry the shadow should be
                            offset: Offset(0, 3), // Offset of the shadow (x, y)
                          ),
                        ],
                      ),
                      child: TextField(
                        controller: _reviewController,
                        maxLines: 5,
                        decoration: InputDecoration(
                          hintText: 'Tell us about your experience...',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    // Action buttons
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        TextButton(
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 32, vertical: 12),
                            textStyle: TextStyle(fontSize: 20),
                          ),
                          onPressed: () {
                            Navigator.pop(context); // Close the sheet
                          },
                          child: const Text('Cancel'),
                        ),
                        const SizedBox(width: 25),
                        TextButton(
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 32, vertical: 12),
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            textStyle: const TextStyle(fontSize: 20),
                          ),
                          onPressed: () {
                            final rating = _userRating;
                            final comment = _reviewController.text;

                            _apiService.leaveReview(tourId, rating, comment);
                            _loadData();

                            Navigator.pop(context); // Close the sheet

                            // Optionally, show a confirmation message
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Thank you for your review!'),
                                backgroundColor: Colors.green,
                              ),
                            );
                          },
                          child: const Text('Send'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}
