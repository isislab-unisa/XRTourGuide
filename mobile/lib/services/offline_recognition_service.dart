import 'dart:math' as math;
import 'dart:convert';
import 'dart:typed_data';
import 'dart:io';
import 'package:flutter/services.dart' show rootBundle;
import 'package:image/image.dart' as img;
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:opencv_dart/opencv_dart.dart' as cv;
import 'package:path_provider/path_provider.dart';
import "package:camera/camera.dart";

class OfflineRecognitionService {

  Interpreter? _embedder;
  final int dim; // dimensione embedding (es. 2048 o 1280)
  final int inputSize;

  final List<List<double>> _dbEmbeddings = [];
  final List<int> _imgWpIds = [];
  final List<int> _descRows = [];
  final List<Uint8List> _descBytes = [];
  final List<List<List<double>>> _kpCoords = [];
  bool _jsonIndexLoaded = false;


  OfflineRecognitionService({this.dim = 2048, this.inputSize = 224});

  //Load the TFLite model from asset
  Future<void> initEmbedderFromAsset(String assetPath) async {
    try {
      final modelData = await rootBundle.load(assetPath);
      _embedder = await Interpreter.fromBuffer(modelData.buffer.asUint8List());
      print('Interpreter loaded successfully from asset: $assetPath');
    } catch (e) {
      print('Error loading interpreter from asset: $e');
      rethrow;
    }
  }

  //Load the offline JSON index
  Future<void> initIndexForTour(int tourId) async {
    final appDir = await getApplicationDocumentsDirectory();
    final tourDir = Directory('${appDir.path}/offline_tours_data/tour_$tourId');

    final indexJsonFile = File('${tourDir.path}/training_data.json');
    if (!await indexJsonFile.exists()) {
      print('Index JSON file not found for tour $tourId at ${indexJsonFile.path}');
      return;
    }

    final tourDataFile = File('${tourDir.path}/tour_data.json');
    if (!await tourDataFile.exists()) {
      print('Tour data JSON file not found for tour $tourId at ${tourDataFile.path}');
      return;
    }

    final tourData = jsonDecode(await tourDataFile.readAsString()) as Map<String, dynamic>;
    final Map<String, int> nameToId = {};
    final wps = (tourData['waypoints'] as List?) ?? [];
    for (final w in wps) {
      final id = (w['id'] as num).toInt();
      final title = (w['title'] ?? '').toString();
      if (title.isNotEmpty) nameToId[title] = id;
    }
    final subTours = (tourData['sub_tours'] as List?) ?? [];
    for (final st in subTours) {
      final wps = (st['waypoints'] as List?) ?? [];
      for (final w in wps) {
        final id = (w['id'] as num).toInt();
        final title = (w['title'] ?? '').toString();
        if (title.isNotEmpty) nameToId[title] = id;
      }
    }

    _dbEmbeddings.clear();
    _imgWpIds.clear();
    _descRows.clear();
    _descBytes.clear();
    _kpCoords.clear();

    final List<dynamic> items = jsonDecode(await indexJsonFile.readAsString()) as List<dynamic>;
    for (final it in items) {
      final m = it as Map<String, dynamic>;
      final String wpName = m["waypoint_name"]?.toString() ?? '';
      final int wpId = nameToId[wpName] ?? -1;

      final embList = (m["embedding"] as List).map((e) => (e as num).toDouble()).toList();
      final norm = math.sqrt(embList.fold<double>(0, (s,v) => s + v * v));
      final emb = norm >0 ? embList.map((e) => e / norm).toList() : embList;

      final kps = (m['keypoints'] as List?)?? const [];
      final coords = <List<double>>[];
      for (final k in kps) {
        final kk = k as List;
        final pt = kk[0] as List;
        coords.add([(pt[0] as num).toDouble(), (pt[1] as num).toDouble()]);
      }

      final rows = (m['desc_rows'] as num?)?.toInt() ?? 0;
      final cols = (m['desc_cols'] as num?)?.toInt() ?? 0;
      Uint8List bytes = Uint8List(0);
      if (rows > 0 && cols > 0) {
        final b64 = (m["descriptors_b64"] ?? '') as String;
        if (b64.isNotEmpty) {
          bytes = base64Decode(b64);
          if (bytes.length != rows * cols) {
            print('Warning: descriptor bytes length mismatch for waypoint $wpName');
            bytes = Uint8List(0);
          }
        }
      }

      if (emb.isNotEmpty && coords.length == rows){
        _dbEmbeddings.add(emb);
        _imgWpIds.add(wpId);
        _descRows.add(rows);
        _descBytes.add(bytes);
        _kpCoords.add(coords.map((p) => [p[0], p[1]]).toList());
      }
    }

    if (_dbEmbeddings.isEmpty) {
      throw Exception("Indice offline vuoto o non valido per il tour $tourId");
    }
    _jsonIndexLoaded = true;
    print('Offline index loaded for tour $tourId with ${_dbEmbeddings.length} images.');
  }

  img.Image? _convertCameraImage(CameraImage cameraImage) {
    try {
      if (cameraImage.format.group == ImageFormatGroup.yuv420) {
        return _convertYUV420(cameraImage);
      } else if (cameraImage.format.group == ImageFormatGroup.bgra8888) {
        return _convertBGRA8888(cameraImage);
      } else {
        print('Unsupported image format: ${cameraImage.format.group}');
        return null;
      }
    } catch (e) {
      print('Error converting camera image: $e');
      return null;
    }
  }

  img.Image _convertBGRA8888(CameraImage cameraImage) {
    return img.Image.fromBytes(
      width: cameraImage.width,
      height: cameraImage.height,
      bytes: cameraImage.planes[0].bytes.buffer,
      order: img.ChannelOrder.bgra,
    );
  }

  img.Image _convertYUV420(CameraImage cameraImage) {
    final width = cameraImage.width;
    final height = cameraImage.height;
    final uvRowStride = cameraImage.planes[1].bytesPerRow;
    final uvPixelStride = cameraImage.planes[1].bytesPerPixel!;

    final outImg = img.Image(width: width, height: height);
    final yPlane = cameraImage.planes[0].bytes;
    final uPlane = cameraImage.planes[1].bytes;
    final vPlane = cameraImage.planes[2].bytes;

    for (int y = 0; y < height; y++) {
      final int yRow = y * width;
      final int uvRow = (y / 2).floor() * uvRowStride;

      for (int x = 0; x < width; x++) {
        final uvIndex = (x / 2).floor() * uvPixelStride;
        final int yIndex = yRow + x;

        final yValue = yPlane[yIndex];
        final uValue = uPlane[uvRow + uvIndex];
        final vValue = vPlane[uvRow + uvIndex];

        final r = (yValue + 1.402 * (vValue - 128)).round();
        final g = (yValue - 0.344136 * (uValue - 128) - 0.714136 * (vValue - 128)).round();
        final b = (yValue + 1.772 * (uValue - 128)).round();

        outImg.setPixelRgb(x, y, r.clamp(0, 255), g.clamp(0, 255), b.clamp(0, 255));
      }
    }
    return outImg;
  }

  //Extraction of embedding for query image
  List<double> _extractEmbedding(img.Image image) {
    final resized = img.copyResize(image, width: inputSize, height: inputSize);
    final mean = [0.485, 0.456, 0.406];
    final std = [0.229, 0.224, 0.225];

    final input = Float32List(1 * inputSize * inputSize * 3);
    int bufferIndex = 0;
    for (int y = 0; y < inputSize; y++) {
      for (int x = 0; x < inputSize; x++) {
        final pixel = resized.getPixel(x, y);
        input[bufferIndex++] = (pixel.rNormalized - mean[0]) / std[0];
        input[bufferIndex++] = (pixel.gNormalized - mean[1]) / std[1];
        input[bufferIndex++] = (pixel.bNormalized - mean[2]) / std[2];
      }
    }

    final inTensor = input.reshape([1, inputSize, inputSize, 3]);
    final out = List.filled(dim, 0.0).reshape([1, dim]);
    _embedder?.run(inTensor, out);

    final v = List<double>.from(out.first);
    final n = math.sqrt(v.fold<double>(0, (s, e) => s + e * e));
    return n > 1e-6 ? v.map((e) => e / n).toList() : v;
  }

  List<int> _topKByCosine(List<double> qEmb, int k) {
    final N = _dbEmbeddings.length;
    final scores = List<double>.filled(N, 0.0);
    for (int i = 0; i < N; i++) {
      final db = _dbEmbeddings[i];
      double s = 0.0;
      for (int j = 0; j < db.length; j++) {
        s += qEmb[j] * db[j];
      }
      scores[i] = s;
    }
    final idx = List<int>.generate(N, (i) => i);
    idx.sort((a,b) => scores[b].compareTo(scores[a]));
    return idx.take(math.min(k, N)).toList();
  }

  //Matching function
  Future<int> match(
    CameraImage cameraImage,
    int sensorOrientation, {
      int inliersThreshold = 15,
      int topMatchesForRansac = 80,
      int topK = 10,
    }) async {
      if (_embedder == null || !_jsonIndexLoaded) {
        throw Exception("Embedder non inizializzato o indice JSON non caricato");
      }

      img.Image? queryImg = _convertCameraImage(cameraImage);
      if (queryImg == null) {
        print('Failed to convert camera image.');
        return -1;
      }

      final angle = sensorOrientation.toDouble();
      if (angle != 0) {
        queryImg = img.copyRotate(queryImg, angle: angle);
      }

      final qEmb = _extractEmbedding(queryImg);
      if (qEmb.isEmpty) {
        print('Failed to extract embedding from query image.');
        return -1;
      }

      final topIdx = _topKByCosine(qEmb, topK);

      final orb = cv.ORB.create(nFeatures: 5000);
      final bf = cv.BFMatcher.create(type: cv.NORM_HAMMING, crossCheck: true);

      final Uint8List pngBytes = img.encodePng(queryImg);
      final cv.Mat qColor = cv.imdecode(pngBytes, cv.IMREAD_COLOR);
      if (qColor.isEmpty) {
        print('Failed to decode query image to Mat.');
        return -1;
      }

      final qGray = cv.cvtColor(qColor, cv.COLOR_BGR2GRAY);
      qColor.release();

      final qKp = cv.VecKeyPoint();
      final qDesc = cv.Mat.empty();
      orb.detectAndCompute(qGray, cv.Mat.empty(), keypoints: qKp, description: qDesc);

      if (qDesc.isEmpty) {
        qGray.release();
        qKp.clear();
        qDesc.release();
        return -1;
      }

      int bestWp = -1, bestInliers = 0;
      final qKey = qKp.toList();

      for (final i in topIdx) {
        final rows = _descRows[i];
        final bytes = _descBytes[i];
        if (rows < 8 || bytes.isEmpty) continue;

        final dMat = cv.Mat.fromList(rows, 32, cv.MatType(cv.MatType.CV_8U), bytes);
        final matches = bf.match(qDesc, dMat);
        final ms = matches.toList();

        dMat.release();
        matches.clear();

        if (ms.length < 8) continue;

        ms.sort((a, b) => a.distance.compareTo(b.distance));
        final top = ms.take(topMatchesForRansac).toList();

        final src = <cv.Point2f>[];
        final dst = <cv.Point2f>[];
        final coords = _kpCoords[i];
        for (final m in top) {
          final qp = qKey[m.queryIdx];
          final p2 = coords[m.trainIdx];
          src.add(cv.Point2f(qp.x, qp.y));
          dst.add(cv.Point2f(p2[0], p2[1]));
        }

        if (src.length >= 8) {
          final srcVec = cv.VecPoint2f.fromList(src);
          final dstVec = cv.VecPoint2f.fromList(dst);
          final srcMat = cv.Mat.fromVec(srcVec);
          final dstMat = cv.Mat.fromVec(dstVec);
          final mask = cv.Mat.empty();
          final H = cv.findHomography(srcMat, dstMat, method: cv.RANSAC, ransacReprojThreshold : 5.0, mask: mask);

          if (!H.isEmpty) {
            final inliers = cv.countNonZero(mask);
            if (inliers > bestInliers) {
              bestInliers = inliers;
              bestWp = _imgWpIds[i];
            }
          }

          srcMat.release();
          dstMat.release();
          mask.release();
          H.release();
        }
      }

      qGray.release();
      qKp.clear();
      qDesc.release();

      return bestInliers >= inliersThreshold ? bestWp : -1;
    }

  void dispose() {
    _embedder?.close();
    _embedder = null;
  }
}
