// mobile/lib/services/offline_storage_service.dart
import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:xr_tour_guide/services/auth_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/tour.dart';
import '../models/waypoint.dart';
import 'api_service.dart';

final offlineStorageServiceProvider = Provider<OfflineStorageService>((ref) {
  final apiService = ref.read(apiServiceProvider);
  return OfflineStorageService(apiService);
});

class OfflineStorageService {
  final ApiService apiService;
  final Dio _dio = Dio();

  OfflineStorageService(this.apiService);

  static const String _offlineToursKey = 'offline_tours';
  static const String _tourDataFolder = 'offline_tours_data';

  // Get offline tours directory
  Future<Directory> get _offlineDirectory async {
    final appDir = await getApplicationDocumentsDirectory();
    final offlineDir = Directory('${appDir.path}/$_tourDataFolder');
    if (!await offlineDir.exists()) {
      await offlineDir.create(recursive: true);
    }
    return offlineDir;
  }

  // Download and store a tour offline
  Future<bool> downloadTourOffline(int tourId) async {
    //TODO: Download della mappa in pmtiles
    try {
      // 1. Get tour details
      final tourResponse = await apiService.getTourDetails(tourId);
      final tour = Tour.fromJson(tourResponse.data);

      // 2. Get tour waypoints
      final waypointsResponse = await apiService.getTourWaypoints(tourId);
      final waypointsData = waypointsResponse.data;

      // 3. Create tour directory
      final offlineDir = await _offlineDirectory;
      print("Offline directory: ${offlineDir.absolute.path}");
      final tourDir = Directory('${offlineDir.path}/tour_$tourId');
      print("Tour directory: ${tourDir.path}");
      if (!await tourDir.exists()) {
        await tourDir.create(recursive: true);
      }

      // 4. Download tour default image
      await _downloadImage("${ApiService.basicUrl}/stream_minio_resource/?attachment=True&tour=${tour.id}", '${tourDir.path}/default_image.jpg');

      // 5. Process waypoints and download their resources
      List<Map<String, dynamic>> processedWaypoints = [];

      for (var waypointData in waypointsData['waypoints']) {
        final waypoint = Waypoint.fromJson(waypointData);
        final processedWaypoint = await _processWaypointOffline(
          waypoint,
          tourDir,
        );
        processedWaypoints.add(processedWaypoint);
      }

      // 6. Process sub-tours if any
      List<Map<String, dynamic>>? processedSubTours;
      if (waypointsData['sub_tours'] != null) {
        processedSubTours = [];
        for (var subTourData in waypointsData['sub_tours']) {
          final subTourInfo = subTourData['sub_tour'];
          final subWaypoints = subTourData['waypoints'] as List;

          List<Map<String, dynamic>> processedSubWaypoints = [];
          for (var subWaypointData in subWaypoints) {
            final subWaypoint = Waypoint.fromJson(subWaypointData);
            final processedSubWaypoint = await _processWaypointOffline(
              subWaypoint,
              tourDir,
            );
            processedSubWaypoints.add(processedSubWaypoint);
          }

          processedSubTours.add({
            'sub_tour': subTourInfo,
            'waypoints': processedSubWaypoints,
          });
        }
      }

      // 7. Save tour data locally
      final tourData = {
        'tour': tour.toJson(),
        'waypoints': processedWaypoints,
        'sub_tours': processedSubTours,
        'downloaded_at': DateTime.now().toIso8601String(),
        'version': '1.0',
      };

      final tourDataFile = File('${tourDir.path}/tour_data.json');
      await tourDataFile.writeAsString(jsonEncode(tourData));

      //Save training_data
      await _downloadOfflineIndex(tourId, tourDir);

      // 8. Update offline tours list
      await _updateOfflineToursList(tourId, tour);

      return true;
    } catch (e) {
      print('Error downloading tour offline: $e');
      // Clean up partial download
      await removeTourOffline(tourId);
      return false;
    }
  }

  // Process a single waypoint for offline storage
  Future<Map<String, dynamic>> _processWaypointOffline(
    Waypoint waypoint,
    Directory tourDir,
  ) async {
    final waypointDir = Directory('${tourDir.path}/waypoint_${waypoint.id}');
    if (!await waypointDir.exists()) {
      await waypointDir.create(recursive: true);
    }

    final processedWaypoint = waypoint.toJson();

    // Download waypoint images
    List<String> localImages = [];
    final imagesResponse = await apiService.loadResource(waypoint.id, "images");
    Map<String, dynamic> imagesContent = imagesResponse.data as Map<String, dynamic>;
    print("Images content: $imagesContent");
    if (imagesContent['readme'] != null) {
      List<String> imagesLinks = extractMarkdownLinks(imagesContent['readme']);
      print("Extracted image links: $imagesLinks");
      for (int i = 0; i < imagesLinks.length; i++) {
        final imageUrl = imagesLinks[i];
        print("Downloading image: $imageUrl");
        final localPath = '${waypointDir.path}/image_$i.jpg';

        if (await _downloadImage(imageUrl, localPath)) {
          localImages.add(localPath);
        }
      }
      processedWaypoint['local_images'] = localImages;
    }

    // Download resources if available
    final resources = await _downloadWaypointResources(waypoint, waypointDir);
    processedWaypoint['local_resources'] = resources;

    return processedWaypoint;
  }

  // Download waypoint resources (text, audio, video, pdf)
  Future<Map<String, String?>> _downloadWaypointResources(
    Waypoint waypoint,
    Directory waypointDir,
  ) async {
    Map<String, String?> localResources = {
      'readme': null,
      'audio': null,
      'video': null,
      'pdf': null,
    };

    // Download text/readme and links
    try {
      final readmeResponse = await apiService.loadResource(
        waypoint.id,
        'readme',
      );
      Map<String, dynamic> content = readmeResponse.data as Map<String, dynamic>;

      if (content['readme'] != null) {
        final readmeFile = File('${waypointDir.path}/readme.md');
        await readmeFile.writeAsString(content['readme']);
        localResources['readme'] = readmeFile.path;
      }

      final responseLink = await apiService.loadResource(waypoint.id, "links");
      Map<String, dynamic> linksContent = responseLink.data as Map<String, dynamic>;
      if (linksContent['links'] != null) {
        final linksFile = File('${waypointDir.path}/links.json');
        await linksFile.writeAsString(jsonEncode(linksContent['links']));
        localResources['links'] = linksFile.path;
      }

    } catch (e) {
      print('No readme for waypoint ${waypoint.id}');
    }

    // Download other resources (audio, video, pdf)
    final resourceTypes = ['audio', 'video', 'pdf'];
    for (String type in resourceTypes) {
      try {
        final response = await apiService.loadResource(waypoint.id, type);
        Map<String, dynamic> content = response.data as Map<String, dynamic>;
        final resourceUrl = _addAttachmentParam(content[type]);
        final localPath = '${waypointDir.path}/$type.$type';

        if (await _downloadFile(resourceUrl, localPath)) {
          localResources[type] = localPath;
        }
      } catch (e) {
        print('No $type for waypoint ${waypoint.id}');
      }
    }

    return localResources;
  }

  Future<void> _downloadOfflineIndex(int tourId, Directory tourDir) async {
    try {
      final url = '${ApiService.basicUrl}/download_model?tour=$tourId';
      final file = File('${tourDir.path}/training_data.json');
      final response = await _dio.get(url, options: Options(responseType: ResponseType.json));
      final data = response.data;
      await file.writeAsString(jsonEncode(data));
    } catch (e) {
      print('Error downloading offline index: $e');
    }
  }

  List<String> extractMarkdownLinks(String text) {
    final regex = RegExp(
      r'''!?\[[^\]]*\]\(\s*([^\s)]+)(?:\s+(?:\"[^\"]*\"|'[^']*'))?\s*\)''',
      multiLine: true,
    );
    final matches = regex.allMatches(text);
    return matches.map((m) {
      final rawUrl = m.group(1)!.trim();
      final abs = _toAbsoluteUrl(rawUrl);
      return _addAttachmentParam(abs);
    }).toList();
  }

  // Converte URL relativo in assoluto usando ApiService.basicUrl
  String _toAbsoluteUrl(String url) {
    if (url.startsWith('http://') || url.startsWith('https://')) return url;
    final base = ApiService.basicUrl; // es: https://example.com
    if (url.startsWith('/')) return '$base$url';
    return '$base/$url';
  }
  String _addAttachmentParam(String url) {
    // Avoid adding if there's already an attachment param
    if (RegExp(r'(^|[\?&])attachment=').hasMatch(url)) return url;

    final hashIndex = url.indexOf('#');
    final fragment = (hashIndex >= 0) ? url.substring(hashIndex) : '';
    final main = (hashIndex >= 0) ? url.substring(0, hashIndex) : url;

    final qIndex = main.indexOf('?');
    if (qIndex == -1) {
      // no query: append
      return '$main?attachment=True$fragment';
    } else {
      // has query: insert right after first '?'
      return main.replaceFirst('?', '?attachment=True&') + fragment;
    }
  }


  // Download an image file
  Future<bool> _downloadImage(String url, String localPath) async {
    try {
      final response = await _dio.download(url, localPath);
      return response.statusCode == 200;
    } catch (e) {
      print('Error downloading image $url: $e');
      return false;
    }
  }

  // Download a general file
  Future<bool> _downloadFile(String url, String localPath) async {
    try {
      final response = await _dio.download(url, localPath);
      return response.statusCode == 200;
    } catch (e) {
      print('Error downloading file $url: $e');
      return false;
    }
  }

  // Update the list of offline tours
  Future<void> _updateOfflineToursList(int tourId, Tour tour) async {
    final prefs = await SharedPreferences.getInstance();
    final offlineToursJson = prefs.getStringList(_offlineToursKey) ?? [];

    final offlineTour = {
      'id': tourId,
      'title': tour.title,
      'description': tour.description,
      'downloaded_at': DateTime.now().toIso8601String(),
    };

    // Remove existing entry if present
    offlineToursJson.removeWhere((tourJson) {
      final tourData = jsonDecode(tourJson);
      return tourData['id'] == tourId;
    });

    // Add new entry
    offlineToursJson.add(jsonEncode(offlineTour));

    await prefs.setStringList(_offlineToursKey, offlineToursJson);
  }

  // Get list of offline tours
  Future<List<Map<String, dynamic>>> getOfflineTours() async {
    final prefs = await SharedPreferences.getInstance();
    final offlineToursJson = prefs.getStringList(_offlineToursKey) ?? [];

    return offlineToursJson
        .map((tourJson) => jsonDecode(tourJson) as Map<String, dynamic>)
        .toList();
  }

  // Check if a tour is available offline
  Future<bool> isTourAvailableOffline(int tourId) async {
    final offlineTours = await getOfflineTours();
    return offlineTours.any((tour) => tour['id'] == tourId);
  }

  // Get offline tour data
  Future<Map<String, dynamic>?> getOfflineTourData(int tourId) async {
    try {
      final offlineDir = await _offlineDirectory;
      final tourDataFile = File(
        '${offlineDir.path}/tour_$tourId/tour_data.json',
      );

      if (await tourDataFile.exists()) {
        final jsonString = await tourDataFile.readAsString();
        return jsonDecode(jsonString);
      }
      return null;
    } catch (e) {
      print('Error reading offline tour data: $e');
      return null;
    }
  }

  // Remove a tour from offline storage
  Future<bool> removeTourOffline(int tourId) async {
    try {
      // Remove tour directory
      final offlineDir = await _offlineDirectory;
      final tourDir = Directory('${offlineDir.path}/tour_$tourId');
      if (await tourDir.exists()) {
        await tourDir.delete(recursive: true);
      }

      // Update offline tours list
      final prefs = await SharedPreferences.getInstance();
      final offlineToursJson = prefs.getStringList(_offlineToursKey) ?? [];
      offlineToursJson.removeWhere((tourJson) {
        final tourData = jsonDecode(tourJson);
        return tourData['id'] == tourId;
      });
      await prefs.setStringList(_offlineToursKey, offlineToursJson);

      return true;
    } catch (e) {
      print('Error removing offline tour: $e');
      return false;
    }
  }

  // Get offline storage size
  Future<int> getOfflineStorageSize() async {
    try {
      final offlineDir = await _offlineDirectory;
      if (!await offlineDir.exists()) return 0;

      int totalSize = 0;
      await for (FileSystemEntity entity in offlineDir.list(recursive: true)) {
        if (entity is File) {
          totalSize += await entity.length();
        }
      }
      return totalSize;
    } catch (e) {
      print('Error calculating storage size: $e');
      return 0;
    }
  }

  // Clear all offline data
  Future<bool> clearAllOfflineData() async {
    try {
      final offlineDir = await _offlineDirectory;
      if (await offlineDir.exists()) {
        await offlineDir.delete(recursive: true);
      }

      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_offlineToursKey);

      return true;
    } catch (e) {
      print('Error clearing offline data: $e');
      return false;
    }
  }
}
