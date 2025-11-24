import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:camera/camera.dart';
import 'models/app_colors.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_map_location_marker/flutter_map_location_marker.dart';
import 'package:markdown_widget/markdown_widget.dart'; // Keep this for text/link/image
import 'dart:async';
import 'dart:math';
import 'services/auth_service.dart';
import 'services/tour_service.dart';
import 'services/api_service.dart';
import 'services/local_state_service.dart';
import 'models/waypoint.dart';
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:easy_localization/easy_localization.dart";
import 'services/offline_tour_service.dart';
import "dart:io";
import "package:path_provider/path_provider.dart";
import 'package:flutter_map_pmtiles/flutter_map_pmtiles.dart';
import 'services/offline_recognition_service.dart';
import 'dart:typed_data';
import 'package:image/image.dart' as img;





// New imports for media players/viewers
import 'elements/pdf_viewer.dart';
import 'elements/audio_player.dart';
import 'elements/video_player.dart';

// Enum for recognition states
enum RecognitionState {
  ready, // Initial state - show camera button
  scanning, // Currently scanning
  success, // Recognition successful
  failure, // Recognition failed,
}

// _currentMarkdownContent is kept to build markdown strings for MarkdownWidget
String _currentMarkdownContent = "";
// This new variable will hold the actual Widget to display in the sheet
Widget? _currentActiveContent;

class ARCameraScreen extends ConsumerStatefulWidget {
  // Landmark data passed to the screen
  String landmarkName;
  String landmarkDescription;
  List<String> landmarkImages;
  final double latitude;
  final double longitude;
  final int tourId;
  final bool isOffline;

  ARCameraScreen({
    Key? key,
    required this.tourId,
    this.landmarkName = "",
    this.landmarkDescription = """
""",
    this.landmarkImages = const [],
    required this.latitude,
    required this.longitude,
    this.isOffline = false,
  }) : super(key: key);

  @override
  ConsumerState<ARCameraScreen> createState() => _ARCameraScreenState();
}

class _ARCameraScreenState extends ConsumerState<ARCameraScreen>
    with TickerProviderStateMixin {

  late ApiService _apiService;
  late LocalStateService _localStateService;
  late OfflineStorageService _offlineService;
  OfflineRecognitionService? _offlineRecognitionService;
  bool _isProcessingFrame = false;


  // Camera controller
  CameraController? _cameraController;
  List<CameraDescription>? _cameras;
  bool _isCameraInitialized = false;

  // Recognition state
  RecognitionState _recognitionState = RecognitionState.ready;

  int _recognizedWaypointId = -1; // Store recognized waypoint ID
  Map<String, dynamic> _availableResources = {}; // Store available resources

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

  // Initial size of the draggable sheet (10% of screen height)
  final double _initialSheetSize = 0.1;
  final double _minSheetSize = 0.1;
  final double _maxSheetSize = 0.8;

  // Flutter Map controller for the mini-map
  final MapController _mapController = MapController();

  // Current position for location tracking
  Position? _currentPosition;

  // Manual animation progress for AR overlays
  double _arOverlayProgress = 0.0;

  late TourService _tourService;

  List<Waypoint> _waypoints = [];
  Map<int, List<String>> _offlineImagesByWaypoint = {};
  Map<int, Map<String, dynamic>> _offlineResourcesByWaypoint = {};

  bool _isLoadingWaypoints = true;

  String? _pmtilesPath;
  late Future<PmTilesTileProvider> _futureTileProvider;


  @override
  void initState() {
    super.initState();
    _tourService = ref.read(tourServiceProvider);
    _apiService = ref.read(apiServiceProvider);
    _localStateService = LocalStateService();
    _offlineService = ref.read(offlineStorageServiceProvider);
    _initializeCamera();
    _getCurrentLocation();
    _initializeAnimations();
    _setInitialContent();
    if (widget.isOffline) {
      _initOfflineMap();
      _initializeOfflineRecognizer();
    } // Set initial content
  }

  @override
  void dispose() {
    _cameraController?.stopImageStream();
    _cameraController?.dispose();
    _sheetController.dispose();
    _pulseAnimationController.dispose();
    _successAnimationController.dispose();
    _failureAnimationController.dispose();
    _offlineRecognitionService?.dispose();
    super.dispose();
  }

  Future<void> _initOfflineMap() async {
    final dir = await getApplicationDocumentsDirectory();
    final path = '${dir.path}/offline_tours_data/tour_${widget.tourId}/map.pmtiles';
    if (await File(path).exists()) {
      setState(() {
        _pmtilesPath = path;
        _futureTileProvider = PmTilesTileProvider.fromSource(_pmtilesPath!);
      });
    } else {
      print("PMTiles file not found at $path");
    }
  }

  Widget _baseMapLayer() {
    if (widget.isOffline && _pmtilesPath != null) {
      return FutureBuilder<PmTilesTileProvider>(
        future: _futureTileProvider,
        builder: (context, snapshot) {
          if (snapshot.hasData) {
            return TileLayer(
              tileProvider: snapshot.data!,
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
            );
          }
          // You might want to show a loader or a fallback here
          // return const SizedBox.shrink();
          if (snapshot.hasError) {
            debugPrint(snapshot.error.toString());
            debugPrintStack(stackTrace: snapshot.stackTrace);
            return Center(child: Text(snapshot.error.toString()));
          }
          return const Center(child: CircularProgressIndicator());
        },
      );
    }

    return TileLayer(
      urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
      userAgentPackageName: 'com.isislab.xrtourguide',
      tileProvider: NetworkTileProvider(),
    );
  }

  Future<void> _initializeOfflineRecognizer() async {
    try {
      _offlineRecognitionService = OfflineRecognitionService();
      await _offlineRecognitionService!.initEmbedderFromAsset('assets/models/ResNet50.tflite');
      await _offlineRecognitionService!.initIndexForTour(widget.tourId);
      print('Offline recognizer initialized for tour ${widget.tourId}');
    } catch (e) {
      print('Error initializing offline recognizer: $e');
      _showError('Error initializing offline recognizer.');
    }
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
          imageFormatGroup: ImageFormatGroup.yuv420,
        );

        await _cameraController!.initialize();
        if (!mounted) return;


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

  void _handleRecognitionSuccess(int waypointId, Map<String, dynamic> availableResources, bool isOffline) async {

    _waypoints.forEach((waypoint) {
      if (waypoint.id == waypointId && waypoint.subWaypoints == null) {
        widget.landmarkName = waypoint.title;
        widget.landmarkImages = waypoint.images;
        widget.landmarkDescription = waypoint.description;
      }
    });

    _pulseAnimationController.stop();
    // await _localStateService.addScannedWaypoint(
    //   widget.tourId,
    //   waypointId as int,
    // );


    setState(() {
      _recognizedWaypointId = waypointId;
      _availableResources = availableResources;
      _currentMarkdownContent = "# ${widget.landmarkName}\n\n${widget.landmarkDescription}";
      _currentActiveContent = MarkdownWidget(
        data: _currentMarkdownContent,
        config: _buildMarkdownConfig(),
        padding: const EdgeInsets.only(top: 0),
        shrinkWrap: true,
      );
      _recognitionState = RecognitionState.success;
    });
    _successAnimationController.reset();
    _successAnimationController.forward();
    _startAROverlayAnimation();
    // await _checkTourCompletion();
  }

  // Helper to build MarkdownConfig once
  MarkdownConfig _buildMarkdownConfig() {
    return MarkdownConfig(
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
        ImgConfig(
          builder: (url, attributes) {
            // Gestisci immagini locali con protocollo file://
            if (url.startsWith('file://')) {
              final localPath = url.substring(7); // Rimuovi 'file://'
              return Container(
                margin: const EdgeInsets.symmetric(vertical: 8),
                child: Image.file(
                  File(localPath),
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        children: [
                          const Icon(
                            Icons.broken_image,
                            size: 48,
                            color: Colors.grey,
                          ),
                          const SizedBox(height: 8),
                          Text('Image not found: ${localPath.split('/').last}'),
                        ],
                      ),
                    );
                  },
                ),
              );
            } else {
              // Immagini remote (modalità online)
              return Container(
                margin: const EdgeInsets.symmetric(vertical: 8),
                child: Image.network(
                  url,
                  fit: BoxFit.contain,
                  loadingBuilder: (context, child, loadingProgress) {
                    if (loadingProgress == null) return child;
                    return const Center(child: CircularProgressIndicator());
                  },
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Column(
                        children: [
                          Icon(
                            Icons.broken_image,
                            size: 48,
                            color: Colors.grey,
                          ),
                          SizedBox(height: 8),
                          Text('Failed to load image'),
                        ],
                      ),
                    );
                  },
                ),
              );
            }
          },
        ),
        BlockquoteConfig(
          sideColor: AppColors.primary.withOpacity(0.5),
          textColor: AppColors.textSecondary.withOpacity(0.8),
          sideWith: 4.0,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          margin: const EdgeInsets.symmetric(vertical: 8),
        ),
      ],
    );
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }


  Future<void> _getTourWaypoints() async{
    if (!widget.isOffline) {
      try {
        final waypoints = await _tourService.getWaypointsByTour(widget.tourId);
        if (mounted) {
          setState(() {
            _waypoints = [];
            for (var waypoint in waypoints) {
              _waypoints.add(waypoint);
              if (waypoint.subWaypoints != null){
                _waypoints.addAll(waypoint.subWaypoints!);
              }
            }
            _isLoadingWaypoints = false;
          });
        }
      } catch (e) {
        if (mounted){
          setState(() {
            _isLoadingWaypoints = false;
          });
        }
        _showError('Failed to load waypoints: $e');
      }
    } else {
      try {
        final offlineData = await _offlineService.getOfflineTourData(widget.tourId);
        if (offlineData != null) {
          final List wps = (offlineData['waypoints'] as List?) ?? [];
          final List subTours = (offlineData['sub_tours'] as List?) ?? [];

          final List<Waypoint> mainWaypoints = wps.map<Waypoint>((wp) => Waypoint.fromJson(wp as Map<String, dynamic>)).toList();
          final List<Waypoint> subTourWaypoints = <Waypoint>[];

          for (final st in subTours) {
            final subTourInfo = st['sub_tour'] as Map<String, dynamic>?;
            if (subTourInfo == null) continue;

            final subWpJson = (st['waypoints'] as List?) ?? [];
            final subWps = subWpJson.map<Waypoint>((wp) => Waypoint.fromJson(wp as Map<String, dynamic>)).toList();

            subTourWaypoints.addAll(subWps);
          }

          print("Loading images and resources for offline waypoints...");

          final Map<int, List<String>> imagesByWp = {};
          final Map<int, Map<String, dynamic>> resourcesByWp = {};
          for (final wp in wps) {
            final id = (wp['id'] as num).toInt();
            final localImages =
                (wp['local_images'] as List?)?.cast<String>() ?? <String>[];
            final local_resources = wp["local_resources"] as Map<String, dynamic>?;

            imagesByWp[id] = localImages;
            resourcesByWp[id] = local_resources!;
          }
          for (final st in subTours) {
            final List subWp = (st['waypoints'] as List?) ?? [];
            for (final wp in subWp) {
              final id = (wp['id'] as num).toInt();
              final localImages = (wp['local_images'] as List?)?.cast<String>() ?? <String>[];
              final local_resources = wp["local_resources"] as Map<String, dynamic>?;

              imagesByWp[id] = localImages;
              resourcesByWp[id] = local_resources!;
            }
          }


          if (mounted) {
            setState(() {
              _waypoints = [...mainWaypoints, ...subTourWaypoints];
              _offlineImagesByWaypoint = imagesByWp;
              _offlineResourcesByWaypoint = resourcesByWp;
              _isLoadingWaypoints = false;
            });
          }
        }
      } catch (e) {
        if (mounted) {
          setState(() {
            _isLoadingWaypoints = false;
          });
        }
        print("Failed to load offline waypoints: $e");
        _showError('Failed to load offline waypoints: $e');

      }
    }
  }

  // Set the initial content for the draggable sheet
  void _setInitialContent() {
    setState(() {
      _getTourWaypoints();
      _currentMarkdownContent = """ 
      """;
      _currentActiveContent = MarkdownWidget(
        data: _currentMarkdownContent,
        config: _buildMarkdownConfig(),
        padding: const EdgeInsets.only(top: 0),
        shrinkWrap: true,
      );
    });
  }

  String _processImageContent(String content) {
    if (content.isEmpty) return content;

    // Definisci il prefisso che vuoi aggiungere (ad esempio il base URL del tuo server)
    String baseUrl = ApiService.basicUrl;

    // Split il contenuto in righe
    List<String> lines = content.split('\n');

    // Processa ogni riga
    List<String> processedLines =
        lines.map((line) {
          line = line.trim();

          // Controlla se la riga contiene un'immagine markdown
          if (line.startsWith('![') &&
              line.contains('](/stream_minio_resource/')) {
            // Estrai il numero dell'immagine e il percorso
            RegExp regex = RegExp(
              r'!\[(\d+)\]\((/stream_minio_resource/[^)]+)\)',
            );
            Match? match = regex.firstMatch(line);

            if (match != null) {
              String imageNumber = match.group(1)!;
              String imagePath = match.group(2)!;

              // Ricostruisci la riga con il prefisso
              return '![$imageNumber]($baseUrl$imagePath)';
            }
          }

          return line;
        }).toList();

    // Ricomponi il contenuto
    return processedLines.join('\n');
  }

  // Update draggable sheet content based on type
  Future<void> _updateDraggableSheetContent(String type, int waypointId) async {
    // This will hold the content that goes into the _currentActiveContent
    Widget? contentToDisplay;
    Map<String, dynamic> content = {};

    var queryType = type;
    if (type == "text"){
      queryType = "readme";
    }
    if (type == "link") {
      queryType = "links";
    }
    if (type == "document") {
      queryType = "pdf";
    }
    if (type == "image"){
      queryType = "images";
    }

    try {
      if (widget.isOffline) {
        // if(_offlineResourcesByWaypoint.containsKey(waypointId)) {
        //   content = _offlineResourcesByWaypoint[waypointId]!;
        // } else {
        //   throw Exception("No offline resources found for waypoint $waypointId");
        // }
        final resources = _offlineResourcesByWaypoint[waypointId] ?? {};
        final images = _offlineImagesByWaypoint[waypointId] ?? [];

        // Crea un oggetto content con i path locali
        content = {
          'readme': resources['readme'],
          'links': resources['links'],
          'pdf': resources['pdf'],
          'video': resources['video'],
          'audio': resources['audio'],
          'images': images, // Lista di path immagini locali
        };

      } else {
        final response = await _tourService.getResourceByWaypointAndType(
          waypointId,
          queryType,
        );
        content = response as Map<String, dynamic>;
      }
    } catch (e) {
      print("error retrieving content: $e");
      type = 'error';
    }

    switch (type) {
      case 'text':
        if (widget.isOffline) {
          final readmePath = content['readme'] ?? '';
          String readmeContent = '';

          if (readmePath.isNotEmpty) {
            try {
              final file = File(readmePath);
              if (await file.exists()) {
                readmeContent = await file.readAsString();
              } else {
                readmeContent = 'No readme file found offline.';
              }
            } catch (e) {
              print("Error reading readme file: $e");
              readmeContent = 'Error reading readme file: $e';
            }
          } else {
            readmeContent = 'No readme available for this waypoint.';
          }
          _currentMarkdownContent = readmeContent;
        } else {
          _currentMarkdownContent = content['readme'] ?? '';
        }

        contentToDisplay = MarkdownWidget(
          data: _currentMarkdownContent,
          config: _buildMarkdownConfig(),
          padding: const EdgeInsets.only(top: 0),
          shrinkWrap: true,
        );
        break;

      case 'link':
        if (widget.isOffline) {
          final linksPath = content['links'] ?? '';
          String linksContent = '';

          if (linksPath.isNotEmpty) {
            try {
              final file = File(linksPath);
              if (await file.exists()) {
                linksContent = await file.readAsString();
              } else {
                linksContent = 'No links file found offline.';
              }
            } catch (e) {
              print("Error reading links file: $e");
              linksContent = 'Error reading links file: $e';
            }
          } else {
            linksContent = 'No links available for this waypoint.';
          }
          _currentMarkdownContent = linksContent;

        } else {
          _currentMarkdownContent = content['links'] ?? '';
        }

        contentToDisplay = MarkdownWidget(
          data: _currentMarkdownContent,
          config: _buildMarkdownConfig(),
          padding: const EdgeInsets.only(top: 0),
          shrinkWrap: true,
        );
        break;

      case 'image':
        if (widget.isOffline) {
          final localImages = content['images'] as List<String>? ?? [];
          if (localImages.isNotEmpty) {
            String imageContent = "#${widget.landmarkName}\n\n";
            for (int i = 0; i < localImages.length; i++) {
              final imagePath = localImages[i];
              imageContent += "![Image ${i + 1}](file://$imagePath)\n\n";
            }
            _currentMarkdownContent = imageContent;
          } else {
            _currentMarkdownContent = "#${widget.landmarkName}\n\nNo images available for this waypoint.";
          }
        } else {
          _currentMarkdownContent = _processImageContent(content['readme'] ?? '');
        }

        contentToDisplay = MarkdownWidget(
          data: _currentMarkdownContent,
          config: _buildMarkdownConfig(),
          padding: const EdgeInsets.only(top: 0),
          shrinkWrap: true,
        );
        break;

      case 'video':
        if (widget.isOffline) {
          final videoPath = content['video'] ?? '';
          if (videoPath.isNotEmpty) {
            contentToDisplay = VideoPlayerWidget(
              videoUrl: videoPath,
              isLocalFile: true,
            );
          } else {
            contentToDisplay = const Center(
              child: Text(
                'No video available for this waypoint.',
                style: TextStyle(color: AppColors.textPrimary),
              ),
            );
          }

        } else {
          contentToDisplay = VideoPlayerWidget(
            videoUrl:
                content['video'] ?? 'https://flutter.github.io/assets-for-api-docs/assets/videos/butterfly.mp4',
                isLocalFile: false,
          );
        }
        break;

      case 'document':
        if (widget.isOffline) {
          final pdfPath = content['pdf'] ?? '';
          if (pdfPath.isNotEmpty) {
            contentToDisplay = PdfViewerWidget(
              pdfUrl: pdfPath,
              isLocalFile: true,
            );
          } else {
            contentToDisplay = const Center(
              child: Text(
                'No PDF document available for this waypoint.',
                style: TextStyle(color: AppColors.textPrimary),
              ),
            );
          }

        } else {
          contentToDisplay = PdfViewerWidget(
            pdfUrl:
                content['pdf'] ?? 'https://www.antennahouse.com/hubfs/xsl-fo-sample/pdf/basic-link-1.pdf',
            isLocalFile: false,
          );
        }
        break;

      case 'audio':
        if (widget.isOffline) {
          final audioPath = content['audio'] ?? '';
          if (audioPath.isNotEmpty) {
            contentToDisplay = AudioPlayerWidget(
              audioUrl: audioPath,
              isLocalFile: true,
            );
          } else {
            contentToDisplay = const Center(
              child: Text(
                'No audio available for this waypoint.',
                style: TextStyle(color: AppColors.textPrimary),
              ),
            );
          }
        } else {
          contentToDisplay = AudioPlayerWidget(
            audioUrl:
                content['audio'] ?? 'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-1.mp3',
            isLocalFile: false,
          );

        }
        break;

      case 'error':
        contentToDisplay = Center(
          child: Text(
            'No content available for "$queryType".',
            style: const TextStyle(color: AppColors.textPrimary),
          ),
        );
    }

    _sheetController.animateTo(
      _initialSheetSize + 0.25,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );

    setState(() {
      _currentActiveContent = contentToDisplay;
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
      _currentMarkdownContent = """
      """;
    });

    // Start pulse animation
    _pulseAnimationController.repeat(reverse: true);

    try {
      final XFile file = await _cameraController!.takePicture();
      var bytes = await file.readAsBytes();

      img.Image? capturedImage = img.decodeImage(bytes);
      if (capturedImage == null) {
        throw Exception("Failed to decode captured image");
      }

      final int orientation = _cameraController!.description.sensorOrientation;
      print("Sensor Orientation: $orientation");

      if (orientation != 0) {
        capturedImage = img.copyRotate(capturedImage, angle: orientation.toDouble());
      }


      final dir = await getApplicationDocumentsDirectory();
      final testPath = '${dir.path}/test_flutter_photo.jpg';
      await File(testPath).writeAsBytes(img.encodeJpg(capturedImage));
      print("Saved test image to $testPath");

      int waypointId = -1;
      Map<String, dynamic> availableResources = {};

      if (widget.isOffline) {
        print("OFFLINE RECOGNITION");
        if(_offlineRecognitionService == null) {
          throw Exception("Offline Recognition Service not initialized");
        }
        final rotatedBytes = Uint8List.fromList(img.encodeJpg(capturedImage));
        waypointId = await _offlineRecognitionService!.matchFromImageBytes(bytes, sensorOrientation: 0);
        print("WAYPOINT ID: ${waypointId}");
        if (waypointId != -1) {
          availableResources = {
            "readme": 0,
            "links": 0,
            "images": 0,
            "video": 0,
            "pdf": 0,
            "audio": 0,
          };
          final images = _offlineImagesByWaypoint[waypointId] ?? [];
          if (images.isNotEmpty) {
            availableResources["images"] = 1;
          }
          final resources = _offlineResourcesByWaypoint[waypointId] ?? {};
          resources.forEach((key, value) {
            if (value is String && value.isNotEmpty) {
              availableResources[key] = 1;
            }
          });

          }
      } else {
        final String base64Image = base64Encode(bytes);
        final result = await _apiService.inference(base64Image, widget.tourId);
        waypointId = result.data["result"] ?? -1;
        availableResources = result.data["available_resources"] ?? {};
      }

      _pulseAnimationController.stop();
      
      final success = waypointId != -1;
      if (success) {
        _handleRecognitionSuccess(waypointId, availableResources, widget.isOffline);
      } else {
        setState(() => _recognitionState = RecognitionState.failure);
        _failureAnimationController.forward();
        Timer(const Duration(seconds: 3), () {
          if (mounted) _resetRecognition();
        });
      }
    } catch(e) {
      print("Error during recognition: $e");
      _showError("Recognition failed: $e");
      setState(() => _recognitionState = RecognitionState.failure);
      _failureAnimationController.forward();
      Timer(const Duration(seconds: 3), () {
        if (mounted) _resetRecognition();
      });
    }
  }

  // NUOVO: Verifica se il tour è completato
  Future<void> _checkTourCompletion() async {
    try {
      // Ottieni tutti gli ID dei waypoint del tour corrente
      List<int> allWaypointIds =
          _waypoints.map((waypoint) => waypoint.id).toList();

      // Aggiungi anche gli ID dei sub-waypoint se presenti
      for (var waypoint in _waypoints) {
        if (waypoint.subWaypoints != null) {
          allWaypointIds.addAll(waypoint.subWaypoints!.map((sub) => sub.id));
        }
      }

      print("All waypoint IDs: $allWaypointIds");

      // Verifica se il tour è completato
      final isCompleted = await _localStateService.checkTourCompletion(
        widget.tourId,
        allWaypointIds,
      );

      if (isCompleted && mounted) {
        _showTourCompletedDialog();
      }
    } catch (e) {
      print('Error checking tour completion: $e');
    }
  }

  // NUOVO: Mostra dialog di tour completato
  void _showTourCompletedDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('congratulations'.tr()),
          content: Text(
            'tour_completed'.tr(),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                // Navigator.of(context).pop(); // Torna alla schermata precedente
              },
              child: Text('continue'.tr()),
            ),
          ],
        );
      },
    );
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
    const closingDuration = Duration(milliseconds: 300);


    // Animate out current state
    if (_recognitionState == RecognitionState.success) {
      _successAnimationController.duration = closingDuration;
      await _successAnimationController.reverse();
      _successAnimationController.duration = const Duration(milliseconds: 1200);
    } else if (_recognitionState == RecognitionState.failure) {
      _failureAnimationController.duration = closingDuration;
      await _failureAnimationController.reverse();
      _failureAnimationController.duration = const Duration(milliseconds: 800);
    }

    _sheetController.animateTo(
      _initialSheetSize,
      duration: const Duration(milliseconds: 100),
      curve: Curves.easeInOut,
    );


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
        'isVisible': _availableResources["readme"] == 1,
        'onTapAction': () {
          print('Text Info icon tapped!');
          _updateDraggableSheetContent('text', _recognizedWaypointId);
        },
      }, // Top
      {
        'angle': -pi / 4.5,
        'assetPath': 'assets/icons/link.png',
        'delay': 0.1,
        'label': 'Link',
        'isVisible': _availableResources["links"] == 1,
        'onTapAction': () {
          print('Link Info icon tapped!');
          _updateDraggableSheetContent('link', _recognizedWaypointId);
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
          _updateDraggableSheetContent('image', _recognizedWaypointId);
        },
      }, // Bottom-right
      {
        'angle': pi / 2,
        'assetPath': 'assets/icons/video.png',
        'delay': 0.3,
        'label': 'Video',
        'isVisible': _availableResources["video"] == 1,
        'onTapAction': () {
          print('Video Info icon tapped!');
          _updateDraggableSheetContent('video', _recognizedWaypointId);
        },
      }, // Bottom
      {
        'angle': 2 * pi / 2.5,
        'assetPath': 'assets/icons/document.png',
        'delay': 0.4,
        'label': 'Doc',
        'isVisible': _availableResources["pdf"] == 1,
        'onTapAction': () {
          print('Doc Info icon tapped!');
          _updateDraggableSheetContent('document', _recognizedWaypointId);
        },
      }, // Bottom-left
      {
        'angle': -2 * pi / 2.5,
        'assetPath': 'assets/icons/audio.png',
        'delay': 0.5,
        'label': 'Audio',
        'isVisible': _availableResources["audio"] == 1,
        'onTapAction': () {
          print('Audio Info icon tapped!');
          _updateDraggableSheetContent('audio', _recognizedWaypointId);
        },
      }, // Top-left
      {
        'angle': -2 * pi / 1.01,
        'assetPath': 'assets/icons/back_icon.png',
        'delay': 0.2,
        'label': 'Close',
        'isVisible': true, // Initially hidden"
        'onTapAction': () {
          print('Close icon tapped!');
          _resetRecognition();
        },
      }, // Right
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
                        color: Color.lerp(
                          Colors.blue.withOpacity(0.3),
                          Colors.green.withOpacity(0.3),
                          _successAnimation.value,
                        )!.withOpacity(0.5),
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
          final double radiusMultiplier = elementData["label"] == 'Close'
              ? 1.15 // Close icon is closer to the center
              : 1.0; // Other icons are at full radius
          final double x = centerX + arIconRadius * radiusMultiplier * cos(angle);
          final double y = centerY + arIconRadius * radiusMultiplier * sin(angle);

          return Positioned(
            left:
                x - (iconSize / 2), // Adjust for icon's own width to center it
            top:
                y - (iconSize / 2), // Adjust for icon's own height to center it
            child: _buildSimpleAROverlay(
              label: elementData['label'],
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
    required String label, // Label for the AR overlay
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

    if (label == 'Close') {
      // Special case for the close icon
      iconSize = 50.0;
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
                      color: Color.lerp(
                        Colors.blue.withOpacity(0.3),
                        Colors.red.withOpacity(0.3),
                        _failureAnimation.value,
                      )!.withOpacity(0.5),
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
    final mapSize = screenWidth * 0.35;

    return Positioned(
      top: MediaQuery.of(context).padding.top + 16,
      right: 16,
      child: Container(
        width: mapSize,
        height: mapSize * 0.7,
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
          child:
              _isLoadingWaypoints
                  ? Container(
                    color: Colors.grey[300],
                    child: const Center(
                      child: CircularProgressIndicator(
                        color: AppColors.primary,
                        strokeWidth: 2,
                      ),
                    ),
                  )
                  : _buildMapContent(context),
        ),
      ),
    );
  }

  Widget _buildMapContent(BuildContext context) {
    // Ora che i waypoint sono caricati, calcola quelli vicini
    List<Waypoint> nearbyWaypoints = [];

    if (_currentPosition != null && _waypoints.isNotEmpty) {
      // Calcola le distanze per tutti i waypoint
      List<Map<String, dynamic>> waypointsWithDistance =
          _waypoints.map((waypoint) {
            final distance =
                Geolocator.distanceBetween(
                  _currentPosition!.latitude,
                  _currentPosition!.longitude,
                  waypoint.latitude,
                  waypoint.longitude,
                ) /
                1000; // Converti da metri a km

            return {'waypoint': waypoint, 'distance': distance};
          }).toList();

      // Ordina per distanza (dal più vicino al più lontano)
      waypointsWithDistance.sort(
        (a, b) => a['distance'].compareTo(b['distance']),
      );

      // Prendi solo i primi 5 waypoint più vicini
      nearbyWaypoints =
          waypointsWithDistance
              .take(5)
              .map((item) => item['waypoint'] as Waypoint)
              .toList();
    } else if (_waypoints.isNotEmpty) {
      // Se non hai posizione corrente, mostra i primi 5 waypoint
      nearbyWaypoints = _waypoints.take(5).toList();
    }

    // Calcola il centro della mappa
    LatLng mapCenter;
    if (_currentPosition != null) {
      mapCenter = LatLng(
        _currentPosition!.latitude,
        _currentPosition!.longitude,
      );
    } else if (nearbyWaypoints.isNotEmpty) {
      // Calcola il centro medio dei waypoint
      double avgLat =
          nearbyWaypoints.map((w) => w.latitude).reduce((a, b) => a + b) /
          nearbyWaypoints.length;
      double avgLng =
          nearbyWaypoints.map((w) => w.longitude).reduce((a, b) => a + b) /
          nearbyWaypoints.length;
      mapCenter = LatLng(avgLat, avgLng);
    } else {
      // Fallback: usa le coordinate del landmark originale
      mapCenter = LatLng(widget.latitude, widget.longitude);
    }

    // List<LatLng> pointsForBounds = _waypoints
    //     .map((w) => LatLng(w.latitude, w.longitude))
    //     .toList();

    //   if (_currentPosition != null) {
    //     pointsForBounds.add(
    //       LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
    //     );
    //   }

    //   if (pointsForBounds.isEmpty) {
    //     pointsForBounds.add(LatLng(widget.latitude, widget.longitude));
    //   }

    //   final bounds = LatLngBounds.fromPoints(pointsForBounds);

    return FlutterMap(
      mapController: _mapController,
      options: MapOptions(
        initialCenter: mapCenter,
        initialZoom: 12.0,
        interactionOptions: const InteractionOptions(
          flags: InteractiveFlag.none,
        ),
      ),
      children: [
        // Base map layer
        _baseMapLayer(),
        // TileLayer(
        //   urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
        //   userAgentPackageName: 'com.isislab.xrtourguide',
        // ),

        // Current location marker (se disponibile)
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
              markerSize: const Size.square(24),
              accuracyCircleColor: AppColors.primary.withOpacity(0.2),
              headingSectorColor: AppColors.primary.withOpacity(0.6),
            ),
          ),

        // Waypoint markers (solo se ci sono waypoint caricati)
        if (nearbyWaypoints.isNotEmpty)
          MarkerLayer(
            markers:
                nearbyWaypoints.asMap().entries.map((entry) {
                  final index = entry.key;
                  final waypoint = entry.value;

                  return Marker(
                    point: LatLng(waypoint.latitude, waypoint.longitude),
                    width: 28,
                    height: 28,
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.blue.withOpacity(0.8),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.3),
                            blurRadius: 3,
                            offset: const Offset(0, 1),
                          ),
                        ],
                      ),
                      child: Center(
                        child: Text(
                          '${index + 1}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 10,
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
          ),
      ],
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
                child:
                    _currentActiveContent != null
                        ? SingleChildScrollView(
                          controller: scrollController,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 10,
                          ), // Adjust padding
                          child: _currentActiveContent!,
                        )
                        : Center(
                          child: Text(
                            'Select content type.',
                            style: Theme.of(context).textTheme.titleLarge
                                ?.copyWith(color: AppColors.textPrimary),
                          ),
                        ),
              ),
            ],
          ),
        );
      },
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

// Full-screen image viewer widget (kept as it was part of the original code,
// but not directly used by _updateDraggableSheetContent for 'image' type now)
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
