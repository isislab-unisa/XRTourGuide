import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:camera/camera.dart';
import 'app_colors.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_map_location_marker/flutter_map_location_marker.dart';
import 'package:markdown_widget/markdown_widget.dart'; // Add this import
import 'dart:async';
import 'dart:math';

// Enum for recognition states
enum RecognitionState {
  ready, // Initial state - show camera button
  scanning, // Currently scanning
  success, // Recognition successful
  failure, // Recognition failed
}

class ARCameraScreen extends StatefulWidget {
  // Enhanced landmark data to include markdown content
  final String landmarkName;
  final String landmarkDescription;
  final String landmarkMarkdownContent; // New field for markdown content
  final List<String> landmarkImages;
  final double latitude;
  final double longitude;

  const ARCameraScreen({
    Key? key,
    this.landmarkName = "Santuario di Montevergine",
    this.landmarkDescription =
        "Lorem ipsum dolor sit amet, consectetur adipiscing elit. Sed do eiusmod tempor incididunt ut labore et dolore magna aliqua.",
    // Example markdown content with various formatting
    this.landmarkMarkdownContent = '''
# Santuario di Montevergine

## History
The **Santuario di Montevergine** is a revered pilgrimage site located in the mountains of Campania, Italy. Founded in the 12th century by Saint William of Vercelli, this sacred sanctuary has been a beacon of spiritual devotion for over 800 years.

### Key Historical Facts
- **Founded**: 1119 AD by Saint William of Vercelli
- **Architectural Style**: Romanesque with Gothic influences
- **Elevation**: 1,270 meters above sea level
- **UNESCO Recognition**: Part of the "Longobards in Italy" World Heritage Site

## Religious Significance
The sanctuary is dedicated to the *Madonna di Montevergine*, also known as **Mamma Schiavona** (Mother of Slaves). The miraculous icon of the Virgin Mary attracts thousands of pilgrims annually, especially during the traditional pilgrimage on September 8th.

> "This sacred mountain has witnessed centuries of prayer, devotion, and miracles." - Cardinal Giuseppe Betori

## Architecture & Art
The sanctuary complex includes:

1. **The Basilica** - Houses the miraculous icon
2. **The Museum** - Contains precious religious artifacts
3. **The Library** - Preserves ancient manuscripts
4. **The Guesthouse** - Accommodates pilgrims

### Notable Features
- Ancient frescoes dating back to the 13th century
- Baroque altar with intricate gold decorations
- Historic pipe organ from the 18th century
- Medieval bell tower with panoramic views

## Natural Environment
Situated within the **Monti Picentini Regional Park**, the sanctuary offers:

- Breathtaking mountain vistas
- Rich biodiversity with endemic flora
- Hiking trails for nature enthusiasts
- Clean mountain air and serene atmosphere

## Pilgrimage Traditions
### The Great Pilgrimage
Every year on **September 8th**, thousands of faithful undertake the traditional pilgrimage, walking through the night to reach the sanctuary at dawn. This ancient tradition symbolizes the spiritual journey from darkness to light.

### Special Celebrations
- **Easter Week**: Elaborate processions and ceremonies
- **Assumption Day** (August 15): Special blessing of the faithful
- **Christmas**: Unique nativity scenes and midnight mass

---

*For more information, visit our official website or contact the sanctuary directly.*

**Address**: Via Santuario, 1, 83013 Mercogliano AV, Italy  
**Phone**: +39 0825 72924  
**Website**: [www.santuariodimontevergine.it](https://www.santuariodimontevergine.it)
''',
    this.landmarkImages = const [
      'https://picsum.photos/300/200?random=1',
      'https://picsum.photos/300/200?random=2',
      'https://picsum.photos/300/200?random=3',
    ],
    this.latitude = 40.9333,
    this.longitude = 14.7167,
  }) : super(key: key);

  @override
  State<ARCameraScreen> createState() => _ARCameraScreenState();
}
class _ARCameraScreenState extends State<ARCameraScreen>
    with TickerProviderStateMixin {
  // Camera controller
  CameraController? _cameraController;
  List<CameraDescription>? _cameras;
  bool _isCameraInitialized = false;

  // Recognition state
  RecognitionState _recognitionState = RecognitionState.ready;

  // Animation controllers
  late AnimationController _pulseAnimationController;
  late AnimationController _successAnimationController;
  late AnimationController _failureAnimationController;
  late Animation<double> _pulseAnimation;
  late Animation<double> _successAnimation;
  late Animation<double> _failureAnimation;

  // Controller for the draggable sheet
  final DraggableScrollableController _sheetController =
      DraggableScrollableController();

  // Initial size of the draggable sheet (30% of screen height)
  final double _initialSheetSize = 0.1;
  final double _minSheetSize = 0.1;
  final double _maxSheetSize = 0.8;

  // Flutter Map controller for the mini-map
  final MapController _mapController = MapController();

  // Current position for location tracking
  Position? _currentPosition;

  // Manual animation progress for AR overlays
  double _arOverlayProgress = 0.0;

  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _initializeCamera();
    _getCurrentLocation();
    _initializeAnimations();

    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _cameraController?.dispose();
    _sheetController.dispose();
    _pulseAnimationController.dispose();
    _successAnimationController.dispose();
    _failureAnimationController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  // Initialize camera
  Future<void> _initializeCamera() async {
    try {
      _cameras = await availableCameras();
      if (_cameras != null && _cameras!.isNotEmpty) {
        _cameraController = CameraController(
          _cameras![0], // Use the first camera (usually back camera)
          ResolutionPreset.high,
          enableAudio: false,
        );

        await _cameraController!.initialize();
        if (mounted) {
          setState(() {
            _isCameraInitialized = true;
          });
        }
      }
    } catch (e) {
      print('Error initializing camera: $e');
    }
  }

  // Initialize animations
  void _initializeAnimations() {
    // Pulse animation for scanning state
    _pulseAnimationController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    _pulseAnimation = Tween<double>(begin: 0.8, end: 1.2).animate(
      CurvedAnimation(
        parent: _pulseAnimationController,
        curve: Curves.easeInOut,
      ),
    );

    // Success animation
    _successAnimationController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );
    _successAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _successAnimationController,
        curve: Curves.easeOut, // Changed from Curves.elasticOut
      ),
    );

    // Add listener to debug animation progress
    _successAnimation.addListener(() {});

    // Failure animation
    _failureAnimationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _failureAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _failureAnimationController,
        curve: Curves.bounceOut,
      ),
    );
  }

  // Get current location for the map
  void _getCurrentLocation() async {
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.whileInUse ||
          permission == LocationPermission.always) {
        Position position = await Geolocator.getCurrentPosition();
        if (mounted) {
          setState(() {
            _currentPosition = position;
          });
        }
      }
    } catch (e) {
      print('Error getting location: $e');
    }
  }

  // Start recognition process with animations
  void _startRecognition() async {
    setState(() {
      _recognitionState = RecognitionState.scanning;
    });

    // Start pulse animation
    _pulseAnimationController.repeat(reverse: true);

    // Simulate recognition process (replace with actual ML/AR logic)
    await Future.delayed(const Duration(seconds: 3));

    // Stop pulse animation
    _pulseAnimationController.stop();

    // Force success for debugging - ALWAYS SUCCESS
    //TODO: Replace with actual recognition logic
    bool recognitionSuccess = true;
    print('Recognition result: $recognitionSuccess');

    if (recognitionSuccess) {
      setState(() {
        _recognitionState = RecognitionState.success;
      });

      // Start the central button animation
      _successAnimationController.reset();
      _successAnimationController.forward();

      // Start AR overlays with manual timer-based animation
      _startAROverlayAnimation();

      // Auto-reset after 30 seconds for testing
      Timer(const Duration(seconds: 30), () {
        if (mounted) {
          _resetRecognition();
        }
      });
    } else {
      setState(() {
        _recognitionState = RecognitionState.failure;
      });
      _failureAnimationController.forward();

      // Auto-reset after 3 seconds
      Timer(const Duration(seconds: 3), () {
        if (mounted) {
          _resetRecognition();
        }
      });
    }
  }

  // Manual AR overlay animation using Timer
  void _startAROverlayAnimation() {
    _arOverlayProgress = 0.0;

    Timer.periodic(const Duration(milliseconds: 50), (timer) {
      if (!mounted || _recognitionState != RecognitionState.success) {
        timer.cancel();
        return;
      }

      setState(() {
        _arOverlayProgress += 0.05; // Increase by 5% every 50ms
      });

      if (_arOverlayProgress >= 1.0) {
        _arOverlayProgress = 1.0;
        timer.cancel();
      }
    });
  }

  // Reset recognition to initial state with animation
  void _resetRecognition() async {
    // Reset manual AR overlay progress
    _arOverlayProgress = 0.0;

    // Animate out current state
    if (_recognitionState == RecognitionState.success) {
      await _successAnimationController.reverse();
    } else if (_recognitionState == RecognitionState.failure) {
      await _failureAnimationController.reverse();
    }

    setState(() {
      _recognitionState = RecognitionState.ready;
    });

    _successAnimationController.reset();
    _failureAnimationController.reset();
    _pulseAnimationController.reset();
  }

  // Navigate back to previous screen
  void _navigateBack(BuildContext context) {
    Navigator.of(context).pop();
  }

  // Build the camera background with live feed
  Widget _buildCameraBackground() {
    if (!_isCameraInitialized || _cameraController == null) {
      return Container(
        width: double.infinity,
        height: double.infinity,
        color: Colors.black,
        child: const Center(
          child: CircularProgressIndicator(color: Colors.white),
        ),
      );
    }

    return SizedBox(
      width: double.infinity,
      height: double.infinity,
      child: CameraPreview(_cameraController!),
    );
  }

  // Build the central recognition widget with smooth transitions
  Widget _buildCentralRecognitionWidget() {
    return Center(
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 600),
        transitionBuilder: (Widget child, Animation<double> animation) {
          return ScaleTransition(
            scale: animation,
            child: FadeTransition(opacity: animation, child: child),
          );
        },
        child: Container(
          key: ValueKey(_recognitionState),
          child: _buildStateWidget(),
        ),
      ),
    );
  }

  // Build the appropriate widget for current state
  Widget _buildStateWidget() {
    switch (_recognitionState) {
      case RecognitionState.ready:
        return _buildReadyState();
      case RecognitionState.scanning:
        return _buildScanningState();
      case RecognitionState.success:
        return _buildSuccessState();
      case RecognitionState.failure:
        return _buildFailureState();
    }
  }

  // Build ready state (blue camera button)
  Widget _buildReadyState() {
    return Center(
      child: GestureDetector(
        onTap: _startRecognition,
        child: Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            color: Colors.blue,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Colors.blue.withOpacity(0.3),
                blurRadius: 20,
                spreadRadius: 5,
              ),
            ],
          ),
          child: const Icon(Icons.camera_alt, color: Colors.white, size: 40),
        ),
      ),
    );
  }

  // Build scanning state (pulsing camera button)
  Widget _buildScanningState() {
    return Center(
      child: AnimatedBuilder(
        animation: _pulseAnimation,
        builder: (context, child) {
          return Transform.scale(
            scale: _pulseAnimation.value,
            child: Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: Colors.blue,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.blue.withOpacity(0.5),
                    blurRadius: 30,
                    spreadRadius: 10,
                  ),
                ],
              ),
              child: const Icon(Icons.search, color: Colors.white, size: 40),
            ),
          );
        },
      ),
    );
  }

  // Build success state (green checkmark with animated AR overlays)
  Widget _buildSuccessState() {
    // Get screen dimensions
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

    // Center of the screen (and thus, the central button)
    final centerX = screenWidth / 2;
    final centerY = screenHeight / 2;

    // Configuration for AR overlay elements
    final double arIconRadius =
        screenWidth * 0.28; // Radius for the AR icons circle
    final double iconSize = 70.0; // Size of the _buildSimpleAROverlay widget

    // Define your AR elements with their properties and desired angles (in radians)
    // Angles: 0 is to the right, PI/2 is bottom, PI is left, -PI/2 (or 3*PI/2) is top.
    final List<Map<String, dynamic>> arElementsData = [
      {
        'angle': -pi / 2,
        'assetPath': 'assets/icons/text.png',
        'delay': 0.0,
        'label': 'Text',
        'isVisible': true,
        'onTapAction': () {
          print('Text Info icon tapped!');
          // TODO: Implement action for Text Info (e.g., show more details)
        },
      }, // Top
      {
        'angle': -pi / 4.5,
        'assetPath': 'assets/icons/link.png',
        'delay': 0.1,
        'label': 'Link',
        'isVisible': true,
        'onTapAction': () {
          print('Link Info icon tapped!');
          // TODO: Implement action for Text Info (e.g., show more details)
        },
      }, // Top-right
      {
        'angle': pi / 4.5,
        'assetPath': 'assets/icons/image.png',
        'delay': 0.2,
        'label': 'Image',
        'isVisible': true,
        'onTapAction': () {
          print('Image Info icon tapped!');
          // TODO: Implement action for Text Info (e.g., show more details)
        },
      }, // Bottom-right
      {
        'angle': pi / 2,
        'assetPath': 'assets/icons/video.png',
        'delay': 0.3,
        'label': 'Video',
        'isVisible': true,
        'onTapAction': () {
          print('Video Info icon tapped!');
          // TODO: Implement action for Text Info (e.g., show more details)
        },
      }, // Bottom
      {
        'angle': 2 * pi / 2.5,
        'assetPath': 'assets/icons/document.png',
        'delay': 0.4,
        'label': 'Doc',
        'isVisible': true,
        'onTapAction': () {
          print('Doc Info icon tapped!');
          // TODO: Implement action for Text Info (e.g., show more details)
        },
      }, // Bottom-left
      {
        'angle': -2 * pi / 2.5,
        'assetPath': 'assets/icons/audio.png',
        'delay': 0.5,
        'label': 'Audio',
        'isVisible': true,
        'onTapAction': () {
          print('Audio Info icon tapped!');
          // TODO: Implement action for Text Info (e.g., show more details)
        },
      }, // Top-left
    ];

    return Stack(
      children: [
        // Central success indicator with morphing animation
        Center(
          child: AnimatedBuilder(
            animation: _successAnimation,
            builder: (context, child) {
              return Transform.scale(
                scale: _successAnimation.value,
                child: Container(
                  width: 65,
                  height: 65,
                  decoration: BoxDecoration(
                    color: Color.lerp(
                      Colors.blue,
                      Colors.green,
                      _successAnimation.value,
                    ),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color:
                            Color.lerp(
                              Colors.blue.withOpacity(0.3),
                              Colors.green.withOpacity(0.3),
                              _successAnimation.value,
                            )!,
                        blurRadius: 20 + (10 * _successAnimation.value),
                        spreadRadius: 5 + (5 * _successAnimation.value),
                      ),
                    ],
                  ),
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 300),
                    child: Icon(
                      _successAnimation.value > 0.5
                          ? Icons.check
                          : Icons.search,
                      key: ValueKey(_successAnimation.value > 0.5),
                      color: Colors.white,
                      size: 40,
                    ),
                  ),
                ),
              );
            },
          ),
        ),

        // AR overlay elements positioned around the center
        ...arElementsData.map((elementData) {
          final double angle = elementData['angle'];
          final double x = centerX + arIconRadius * cos(angle);
          final double y = centerY + arIconRadius * sin(angle);

          return Positioned(
            left:
                x - (iconSize / 2), // Adjust for icon's own width to center it
            top:
                y - (iconSize / 2), // Adjust for icon's own height to center it
            child: _buildSimpleAROverlay(
              delay: elementData['delay'],
              isVisible: elementData['isVisible'],
              assetPath: elementData['assetPath'],
              onTap: elementData['onTapAction'],
              iconSize: iconSize, // Use the same size for all icons
            ),
          );
        }).toList(),
      ],
    );
  }

  Widget _buildSimpleAROverlay({
    required double delay,
    required String assetPath, // Path to your custom icon in the assets folder
    required bool isVisible, // Controls if the overlay is shown
    VoidCallback? onTap, // Callback for tap events
    double iconSize = 50.0, // Size of the icon (width and height)
  }) {
    // If not visible, return an empty widget
    if (!isVisible) {
      return const SizedBox.shrink();
    }

    // Animation logic based on _arOverlayProgress (from your state) and individual delay
    // Ensure _arOverlayProgress is accessible here, typically from your State class
    double opacity = _arOverlayProgress >= delay ? 1.0 : 0.0;
    double scale = _arOverlayProgress >= delay ? 1.0 : 0.0;

    // Optional: For debugging animation and visibility
    // print('AR Overlay - asset: $assetPath, delay: $delay, progress: $_arOverlayProgress, opacity: $opacity, scale: $scale, isVisible: $isVisible');

    return Transform.scale(
      scale: scale,
      child: Opacity(
        opacity: opacity,
        child: GestureDetector(
          onTap: onTap,
          behavior:
              HitTestBehavior
                  .opaque, // Ensures the tap area is consistent even if the image has transparency
          child: Image.asset(
            assetPath,
            width: iconSize,
            height: iconSize,
            fit: BoxFit.contain, // Adjust BoxFit as needed
            // Optional: Add an error builder in case the asset fails to load
            errorBuilder: (context, error, stackTrace) {
              print('Error loading asset: $assetPath, $error');
              return Icon(
                Icons.broken_image, // Placeholder for broken image
                size: iconSize,
                color: Colors.red, // Or any color you prefer for the error icon
              );
            },
          ),
        ),
      ),
    );
  }

  // Build failure state (red prohibition symbol with shake animation)
  Widget _buildFailureState() {
    return Center(
      child: AnimatedBuilder(
        animation: _failureAnimation,
        builder: (context, child) {
          // Add shake effect
          double shake = 0;
          if (_failureAnimation.value > 0.1 && _failureAnimation.value < 0.9) {
            shake =
                (sin(_failureAnimation.value * 20) * 3) *
                (1 - _failureAnimation.value); // Diminishing shake
          }

          return Transform.translate(
            offset: Offset(shake, 0),
            child: Transform.scale(
              scale: _failureAnimation.value,
              child: Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: Color.lerp(
                    Colors.blue,
                    Colors.red,
                    _failureAnimation.value,
                  ),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color:
                          Color.lerp(
                            Colors.blue.withOpacity(0.3),
                            Colors.red.withOpacity(0.3),
                            _failureAnimation.value,
                          )!,
                      blurRadius: 20 + (10 * _failureAnimation.value),
                      spreadRadius: 5 + (5 * _failureAnimation.value),
                    ),
                  ],
                ),
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  child: Icon(
                    _failureAnimation.value > 0.5 ? Icons.block : Icons.search,
                    key: ValueKey(_failureAnimation.value > 0.5),
                    color: Colors.white,
                    size: 40,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  // Build AR overlay icon
  Widget _buildAROverlayIcon(IconData icon, Color color, String emoji) {
    return FadeTransition(
      opacity: _successAnimation,
      child: Container(
        width: 50,
        height: 50,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(8),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.3),
              blurRadius: 10,
              spreadRadius: 2,
            ),
          ],
        ),
        child: Center(
          child: Text(
            emoji,
            style: const TextStyle(fontSize: 24, color: Colors.white),
          ),
        ),
      ),
    );
  }

  // Build the back button in top left
  Widget _buildBackButton(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;

    return Positioned(
      top: MediaQuery.of(context).padding.top + 25,
      left: 15,
      child: Container(
        width: screenWidth * 0.15,
        height: screenHeight * 0.07,
        decoration: BoxDecoration(
          color: AppColors.background.withOpacity(0.9),
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: AppColors.cardShadow,
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: IconButton(
          onPressed: () => _navigateBack(context),
          icon: const Icon(
            Icons.arrow_back,
            color: AppColors.textPrimary,
            size: 28,
          ),
          padding: EdgeInsets.zero,
        ),
      ),
    );
  }

  // Build the mini map in top right using flutter_map
  Widget _buildMiniMap(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final mapSize = screenWidth * 0.35; // 35% of screen width

    return Positioned(
      top: MediaQuery.of(context).padding.top + 16,
      right: 16,
      child: Container(
        width: mapSize,
        height: mapSize * 0.7, // Rectangular aspect ratio
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: AppColors.cardShadow,
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              // Center on the landmark location
              initialCenter: LatLng(widget.latitude, widget.longitude),
              // More zoomed in than the detail screen (16.0 vs 13.0)
              initialZoom: 13.0,
              // Disable interactions for mini-map
              interactionOptions: const InteractionOptions(
                flags: InteractiveFlag.none, // Disable all interactions
              ),
            ),
            children: [
              // Base map layer
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.example.app',
              ),

              // Current location marker (if available)
              if (_currentPosition != null)
                CurrentLocationLayer(
                  style: LocationMarkerStyle(
                    marker: Container(
                      decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.6),
                        shape: BoxShape.circle,
                      ),
                      padding: const EdgeInsets.all(4),
                      child: const Center(
                        child: Icon(
                          Icons.person_pin_circle,
                          color: Colors.white,
                          size: 12,
                        ),
                      ),
                    ),
                    markerSize: const Size.square(24), // Smaller for mini-map
                    accuracyCircleColor: AppColors.primary.withOpacity(0.2),
                    headingSectorColor: AppColors.primary.withOpacity(0.6),
                  ),
                ),

              // Landmark marker
              MarkerLayer(
                markers: [
                  Marker(
                    point: LatLng(widget.latitude, widget.longitude),
                    width: 30, // Smaller marker for mini-map
                    height: 30,
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.red.withOpacity(0.8),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.3),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: const Center(
                        child: Icon(
                          Icons.location_on,
                          color: Colors.white,
                          size: 16,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Build the draggable bottom sheet with landmark information
  // Widget _buildDraggableSheet(BuildContext context) {
  //   return DraggableScrollableSheet(
  //     controller: _sheetController,
  //     initialChildSize: _initialSheetSize,
  //     minChildSize: _minSheetSize,
  //     maxChildSize: _maxSheetSize,
  //     builder: (context, scrollController) {
  //       return Container(
  //         decoration: const BoxDecoration(
  //           color: AppColors.background,
  //           borderRadius: BorderRadius.only(
  //             topLeft: Radius.circular(20),
  //             topRight: Radius.circular(20),
  //           ),
  //           boxShadow: [
  //             BoxShadow(
  //               color: AppColors.cardShadow,
  //               blurRadius: 10,
  //               offset: Offset(0, -2),
  //             ),
  //           ],
  //         ),
  //         child: Column(
  //           children: [
  //             // Drag handle
  //             Container(
  //               margin: const EdgeInsets.only(top: 12, bottom: 8),
  //               width: 40,
  //               height: 4,
  //               decoration: BoxDecoration(
  //                 color: AppColors.divider,
  //                 borderRadius: BorderRadius.circular(2),
  //               ),
  //             ),

  //             // Scrollable content
  //             Expanded(
  //               child: SingleChildScrollView(
  //                 controller: scrollController,
  //                 padding: const EdgeInsets.symmetric(horizontal: 20),
  //                 child: Column(
  //                   crossAxisAlignment: CrossAxisAlignment.start,
  //                   children: [
  //                     // Landmark name/title
  //                     Text(
  //                       widget.landmarkName,
  //                       style: const TextStyle(
  //                         fontSize: 24,
  //                         fontWeight: FontWeight.bold,
  //                         color: AppColors.textPrimary,
  //                       ),
  //                     ),

  //                     // const SizedBox(height: 20),

  //                     // // Recognition status indicator
  //                     // Container(
  //                     //   padding: const EdgeInsets.symmetric(
  //                     //     horizontal: 12,
  //                     //     vertical: 8,
  //                     //   ),
  //                     //   decoration: BoxDecoration(
  //                     //     color: _getStatusColor().withOpacity(0.1),
  //                     //     borderRadius: BorderRadius.circular(20),
  //                     //     border: Border.all(
  //                     //       color: _getStatusColor(),
  //                     //       width: 1,
  //                     //     ),
  //                     //   ),
  //                     //   child: Row(
  //                     //     mainAxisSize: MainAxisSize.min,
  //                     //     children: [
  //                     //       Icon(
  //                     //         _getStatusIcon(),
  //                     //         color: _getStatusColor(),
  //                     //         size: 16,
  //                     //       ),
  //                     //       const SizedBox(width: 8),
  //                     //       Text(
  //                     //         _getStatusText(),
  //                     //         style: TextStyle(
  //                     //           color: _getStatusColor(),
  //                     //           fontWeight: FontWeight.w500,
  //                     //           fontSize: 14,
  //                     //         ),
  //                     //       ),
  //                     //     ],
  //                     //   ),
  //                     // ),
  //                     const SizedBox(height: 20),

  //                     // Description section header
  //                     const Text(
  //                       'Description',
  //                       style: TextStyle(
  //                         fontSize: 18,
  //                         fontWeight: FontWeight.w600,
  //                         color: AppColors.textPrimary,
  //                       ),
  //                     ),

  //                     const SizedBox(height: 12),

  //                     // Description text
  //                     Text(
  //                       widget.landmarkDescription,
  //                       style: const TextStyle(
  //                         fontSize: 16,
  //                         height: 1.5,
  //                         color: AppColors.textSecondary,
  //                       ),
  //                     ),

  //                     const SizedBox(height: 24),

  //                     // Photos section
  //                     const Text(
  //                       'Photos',
  //                       style: TextStyle(
  //                         fontSize: 18,
  //                         fontWeight: FontWeight.w600,
  //                         color: AppColors.textPrimary,
  //                       ),
  //                     ),

  //                     const SizedBox(height: 12),

  //                     // Photo grid
  //                     _buildPhotoGrid(),

  //                     // Add some bottom padding for better scrolling experience
  //                     const SizedBox(height: 40),
  //                   ],
  //                 ),
  //               ),
  //             ),
  //           ],
  //         ),
  //       );
  //     },
  //   );
  // }

  // Enhanced build method for the draggable sheet with markdown support
  Widget _buildDraggableSheet(BuildContext context) {
    return DraggableScrollableSheet(
      controller: _sheetController,
      initialChildSize: _initialSheetSize,
      minChildSize: _minSheetSize,
      maxChildSize: _maxSheetSize,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: AppColors.background,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(20),
              topRight: Radius.circular(20),
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.cardShadow,
                blurRadius: 10,
                offset: Offset(0, -2),
              ),
            ],
          ),
          child: Column(
            children: [
              // Drag handle
              Container(
                margin: const EdgeInsets.only(top: 12, bottom: 8),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.divider,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),

              // Tab bar for switching between different content views
              TabBar(
                controller: _tabController,
                labelColor: AppColors.primary,
                unselectedLabelColor: AppColors.textSecondary,
                indicatorColor: AppColors.primary,
                labelStyle: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
                tabs: const [
                  Tab(text: 'Overview'),
                  Tab(text: 'Details'),
                  Tab(text: 'Photos'),
                ],
              ),

              // Scrollable tab content
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    // Overview tab - basic information
                    _buildOverviewTab(scrollController),

                    // Details tab - markdown content
                    _buildMarkdownTab(scrollController),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // Build the overview tab with basic landmark information
  Widget _buildOverviewTab(ScrollController scrollController) {
    return SingleChildScrollView(
      controller: scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 16),

          // Landmark name/title
          Text(
            widget.landmarkName,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),

          const SizedBox(height: 20),

          // Quick stats card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: AppColors.primary.withOpacity(0.2),
                width: 1,
              ),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.location_on,
                      color: AppColors.primary,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Latitude: ${widget.latitude.toStringAsFixed(4)}°',
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(
                      Icons.location_on,
                      color: AppColors.primary,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Longitude: ${widget.longitude.toStringAsFixed(4)}°',
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // Description section
          const Text(
            'Quick Description',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),

          const SizedBox(height: 12),

          Text(
            widget.landmarkDescription,
            style: const TextStyle(
              fontSize: 16,
              height: 1.5,
              color: AppColors.textSecondary,
            ),
          ),

          const SizedBox(height: 40),
        ],
      ),
    );
  }

  // Build the markdown tab with rich formatted content
  Widget _buildMarkdownTab(ScrollController scrollController) {
    return SingleChildScrollView(
      controller: scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        children: [
          const SizedBox(height: 16),

          // Markdown widget with custom styling
          MarkdownWidget(
            data: widget.landmarkMarkdownContent,
            shrinkWrap: true,
            selectable: true, // Allow text selection
            config: MarkdownConfig(
              configs: [
                // Configure heading styles
                const H1Config(
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                    height: 1.3,
                  ),
                ),
                const H2Config(
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                    height: 1.3,
                  ),
                ),
                const H3Config(
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                    height: 1.3,
                  ),
                ),

                // Configure paragraph styling
                const PConfig(
                  textStyle: TextStyle(
                    fontSize: 16,
                    height: 1.6,
                    color: AppColors.textSecondary,
                  ),
                ),

                // Configure list styling
                const UlConfig(
                  marker: '•',
                  markerStyle: TextStyle(
                    color: AppColors.primary,
                    fontSize: 16,
                  ),
                ),
                const OlConfig(
                  markerStyle: TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),

                // Configure blockquote styling
                BlockquoteConfig(
                  blockquoteStyle: const TextStyle(
                    fontStyle: FontStyle.italic,
                    color: AppColors.textSecondary,
                    fontSize: 16,
                  ),
                  background: AppColors.lightGrey.withOpacity(0.3),
                  padding: const EdgeInsets.all(16),
                  margin: const EdgeInsets.symmetric(vertical: 12),
                  radius: const Radius.circular(8),
                  borderLeft: const BorderSide(
                    color: AppColors.primary,
                    width: 4,
                  ),
                ),

                // Configure code block styling
                const PreConfig(
                  background: AppColors.lightGrey,
                  padding: EdgeInsets.all(12),
                  margin: EdgeInsets.symmetric(vertical: 12),
                  borderRadius: BorderRadius.all(Radius.circular(8)),
                  textStyle: TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 14,
                    color: AppColors.textPrimary,
                  ),
                ),

                // Configure table styling
                const TableConfig(
                  defaultColumnWidth: FlexColumnWidth(1.0),
                  decoration: BoxDecoration(
                    border: Border(
                      bottom: BorderSide(color: AppColors.divider),
                    ),
                  ),
                ),

                // Configure link styling
                LinkConfig(
                  style: const TextStyle(
                    color: AppColors.primary,
                    decoration: TextDecoration.underline,
                  ),
                  onTap: (url) {
                    // Handle link taps - you can implement URL launching here
                    print('Link tapped: $url');
                    // For example: launch(url);
                  },
                ),

                // Configure horizontal rule styling
                const HrConfig(
                  height: 1,
                  color: AppColors.divider,
                  margin: EdgeInsets.symmetric(vertical: 20),
                ),
              ],
            ),
          ),

          const SizedBox(height: 40),
        ],
      ),
    );
  }

  // Get status color based on recognition state
  Color _getStatusColor() {
    switch (_recognitionState) {
      case RecognitionState.ready:
        return Colors.blue;
      case RecognitionState.scanning:
        return Colors.orange;
      case RecognitionState.success:
        return Colors.green;
      case RecognitionState.failure:
        return Colors.red;
    }
  }

  // Get status icon based on recognition state
  IconData _getStatusIcon() {
    switch (_recognitionState) {
      case RecognitionState.ready:
        return Icons.camera_alt;
      case RecognitionState.scanning:
        return Icons.search;
      case RecognitionState.success:
        return Icons.check_circle;
      case RecognitionState.failure:
        return Icons.error;
    }
  }

  // Get status text based on recognition state
  String _getStatusText() {
    switch (_recognitionState) {
      case RecognitionState.ready:
        return 'Tap to scan';
      case RecognitionState.scanning:
        return 'Scanning...';
      case RecognitionState.success:
        return 'Recognition successful';
      case RecognitionState.failure:
        return 'Recognition failed';
    }
  }

  // Build a grid of photos
  Widget _buildPhotoGrid() {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 1.2,
      ),
      itemCount: widget.landmarkImages.length,
      itemBuilder: (context, index) {
        return _buildPhotoCard(widget.landmarkImages[index], index);
      },
    );
  }

  // Build individual photo card
  Widget _buildPhotoCard(String imageUrl, int index) {
    return GestureDetector(
      onTap: () {
        // Show full-screen image viewer
        _showImageViewer(imageUrl, index);
      },
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: AppColors.cardShadow,
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Image.network(
            imageUrl,
            fit: BoxFit.cover,
            loadingBuilder: (context, child, loadingProgress) {
              if (loadingProgress == null) return child;
              return Container(
                color: AppColors.lightGrey,
                child: const Center(
                  child: CircularProgressIndicator(color: AppColors.primary),
                ),
              );
            },
            errorBuilder: (context, error, stackTrace) {
              return Container(
                color: AppColors.lightGrey,
                child: const Icon(
                  Icons.image_not_supported,
                  color: AppColors.textSecondary,
                  size: 40,
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  // Show full-screen image viewer
  void _showImageViewer(String imageUrl, int initialIndex) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder:
            (context) => _FullScreenImageViewer(
              images: widget.landmarkImages,
              initialIndex: initialIndex,
            ),
      ),
    );
  }

  // @override
  // Widget build(BuildContext context) {
  //   return Scaffold(
  //     backgroundColor: Colors.black, // Black background for camera feel
  //     extendBodyBehindAppBar: true,
  //     body: Stack(
  //       children: [
  //         // Live camera background
  //         _buildCameraBackground(),

  //         // Central recognition widget overlay
  //         _buildCentralRecognitionWidget(),

  //         // Back button (top left)
  //         _buildBackButton(context),

  //         // Mini map (top right)
  //         _buildMiniMap(context),

  //         // Draggable bottom sheet with landmark info
  //         _buildDraggableSheet(context),
  //       ],
  //     ),
  //   );
  // }

  @override
  Widget build(BuildContext context) {
    // Define the size for the static semi-transparent circle
    // It should be large enough to encompass the largest state of the central button (e.g., ready state button size 80)
    final double staticOuterCircleSize =
        250.0; // Example size, adjust as needed

    return Scaffold(
      backgroundColor: Colors.black, // Black background for camera feel
      extendBodyBehindAppBar: true,
      body: Stack(
        children: [
          // Live camera background
          _buildCameraBackground(),

          // --- Static Semi-transparent Circle (added here) ---
          Center(
            // Use Center to position it in the middle of the screen
            child: Container(
              width: staticOuterCircleSize,
              height: staticOuterCircleSize,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: Colors.black.withOpacity(0.2), // Subtle border
                  width: 4,
                ),
              ),
            ),
          ),
          // --- End Static Semi-transparent Circle ---

          // Central recognition widget overlay (will be on top of the static circle)
          _buildCentralRecognitionWidget(),

          // Back button (top left)
          _buildBackButton(context),

          // Mini map (top right)
          _buildMiniMap(context),

          // Draggable bottom sheet with landmark info
          _buildDraggableSheet(context),
        ],
      ),
    );
  }
}

// Full-screen image viewer widget
class _FullScreenImageViewer extends StatefulWidget {
  final List<String> images;
  final int initialIndex;

  const _FullScreenImageViewer({
    required this.images,
    required this.initialIndex,
  });

  @override
  State<_FullScreenImageViewer> createState() => _FullScreenImageViewerState();
}

class _FullScreenImageViewerState extends State<_FullScreenImageViewer> {
  late PageController _pageController;
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          '${_currentIndex + 1} of ${widget.images.length}',
          style: const TextStyle(color: Colors.white),
        ),
        centerTitle: true,
      ),
      body: PageView.builder(
        controller: _pageController,
        onPageChanged: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        itemCount: widget.images.length,
        itemBuilder: (context, index) {
          return Center(
            child: InteractiveViewer(
              child: Image.network(
                widget.images[index],
                fit: BoxFit.contain,
                loadingBuilder: (context, child, loadingProgress) {
                  if (loadingProgress == null) return child;
                  return const Center(
                    child: CircularProgressIndicator(color: Colors.white),
                  );
                },
                errorBuilder: (context, error, stackTrace) {
                  return const Center(
                    child: Icon(
                      Icons.image_not_supported,
                      color: Colors.white,
                      size: 60,
                    ),
                  );
                },
              ),
            ),
          );
        },
      ),
    );
  }
}
