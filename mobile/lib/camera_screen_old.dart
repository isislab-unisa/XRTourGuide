import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:camera/camera.dart';
import 'app_colors.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_map_location_marker/flutter_map_location_marker.dart';
import 'package:markdown_widget/markdown_widget.dart';
import 'dart:async';
import 'dart:math';

// Enum for recognition states
enum RecognitionState {
  ready, // Initial state - show camera button
  scanning, // Currently scanning
  success, // Recognition successful
  failure, // Recognition failed,
}

String _currentMarkdownContent = "";

class ARCameraScreen extends StatefulWidget {
  // Landmark data passed to the screen
  final String landmarkName;
  final String landmarkDescription;
  final List<String> landmarkImages;
  final double latitude;
  final double longitude;

  const ARCameraScreen({
    Key? key,
    this.landmarkName = "Santuario di Montevergine",
    this.landmarkDescription = """ 
# Santuario di Montevergine

Il Santuario di Montevergine è un importante complesso monastico mariano situato a circa 1.270 metri sul livello del mare, nel massiccio del Partenio, nel comune di Mercogliano (Avellino).

## Storia

Fondato nel 1124 da San Guglielmo da Vercelli, il santuario è oggi uno dei principali luoghi di pellegrinaggio del Sud Italia, con oltre un milione di visitatori ogni anno.

## Architettura

- **Basilica**: La basilica attuale risale al XVIII secolo
- **Cripta**: Conserva importanti opere d'arte medievali
- **Museo**: Ospita preziosi manufatti storici e religiosi

## Come Arrivare

1. In auto dalla A16 uscita Avellino Ovest
2. Con la funicolare da Mercogliano
3. A piedi attraverso i sentieri del Partenio

> Il santuario è aperto tutti i giorni dalle 6:00 alle 20:00

[Visita il sito ufficiale](https://www.santuariodimontevergine.com)
""",
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

  @override
  void initState() {
    super.initState();
    _initializeCamera();
    _getCurrentLocation();
    _initializeAnimations();
    _initializeMarkdownContent();
  }

  @override
  void dispose() {
    _cameraController?.dispose();
    _sheetController.dispose();
    _pulseAnimationController.dispose();
    _successAnimationController.dispose();
    _failureAnimationController.dispose();
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

  void _initializeMarkdownContent() {
    setState(() {
      _currentMarkdownContent = widget.landmarkDescription;
    });
  }

  void _getMarkdownContent(String type) {
    //TODO: Implement logic to fetch or generate markdown content based on type
    //TODO: Rivedere implementazioni per audio, video editor e document viewer
    String newContent = '';
    switch (type) {
      case 'text':
        newContent = 'This is some text content about the landmark.';
        break;
      case 'link':
        newContent = '''
## External Links

For more information, please visit:
[Official Website](https://www.santuariodimontevergine.com) 
[Wikipedia Page](https://en.wikipedia.org/wiki/Montevergine_Sanctuary)
            ''';
        break;
      case 'image':
        newContent = """
## Landmark Image

![${widget.landmarkName} Image](${widget.landmarkImages.isNotEmpty ? widget.landmarkImages[0] : 'https://picsum.photos/300/200'}) 

This is one of the key images for this landmark.
            """;
        break;
      case 'video':
        newContent = """
## Video Tour

Unfortunately, direct video embedding might require a more complex setup or a specific markdown package feature. 

You can watch a video about the landmark here:
[Watch Video](https://www.youtube.com)
            """;
        break;
      case 'document':
        newContent = """
## Document Viewer

Download the informational brochure:
[Download PDF](https://example.com/brochure.pdf)
(Note: This is a placeholder link)
            """;
        break;
      case 'audio':
        newContent = """
## Audio Guide

Listen to an audio description:
[Play Audio Clip](https://example.com/audio_guide.mp3) 
(Note: This is a placeholder link)
            """;
        break;
    }
    _sheetController.animateTo(
      _initialSheetSize + 0.25,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );

    setState(() {
      _currentMarkdownContent = newContent;
    });
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
        curve: Curves.easeOut,
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
          _getMarkdownContent('text');
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
          _getMarkdownContent('link');
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
          _getMarkdownContent('image');
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
          _getMarkdownContent('video');
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
          _getMarkdownContent('document');
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
          _getMarkdownContent('audio');
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

              // Scrollable content
              Expanded(
                child: SingleChildScrollView(
                  controller: scrollController,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Landmark name/title
                      // Text(
                      //   widget.landmarkName,
                      //   style: const TextStyle(
                      //     fontSize: 24,
                      //     fontWeight: FontWeight.bold,
                      //     color: AppColors.textPrimary,
                      //   ),
                      // ),

                      // Description using MarkdownWidget
                      MarkdownWidget(
                        data: _currentMarkdownContent,
                        padding: const EdgeInsets.only(top: 0),
                        shrinkWrap: true,
                        config: MarkdownConfig(
                          configs: [
                            const PConfig(
                              textStyle: TextStyle(
                                fontSize: 16,
                                height: 1.5,
                                color: AppColors.textSecondary,
                              ),
                            ),
                            H1Config(
                              style: const TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            H2Config(
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            LinkConfig(
                              style: const TextStyle(
                                color: AppColors.primary,
                                decoration: TextDecoration.underline,
                              ),
                            ),
                            BlockquoteConfig(
                              sideColor: AppColors.primary.withOpacity(0.5),
                              textColor: AppColors.textSecondary.withOpacity(
                                0.8,
                              ),
                              sideWith: 4.0,
                              // adjust padding/margin if you like:
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 4,
                              ),
                              margin: const EdgeInsets.symmetric(vertical: 8),
                            ),
                          ],
                        ),
                      ),
                      // Add some bottom padding for better scrolling experience
                      const SizedBox(height: 40),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
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
