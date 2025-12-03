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
  int? _modelOutputDim;
  final int dim; // dimensione embedding (es. 2048 o 1280)
  final int inputSize;

  static const double _similarityThreshold = 0.65;
  static const int _defaultTopK = 3;
  static const int _defaultInliersThreshold = 5;

  final List<List<double>> _dbEmbeddings = [];
  final List<int> _imgWpIds = [];
  final List<int> _descRows = [];
  final List<Uint8List> _descBytes = [];
  final List<List<List<double>>> _kpCoords = [];
  bool _jsonIndexLoaded = false;

  final Map<int, List<int>> _wpToImageIndexes = {};


  OfflineRecognitionService({this.dim = 2048, this.inputSize = 224});

  //Load the TFLite model from asset
  Future<void> initEmbedderFromAsset(String assetPath) async {
    try {
      final modelData = await rootBundle.load(assetPath);
      // print("MODEL DATA DEBUG: ${modelData.lengthInBytes} bytes loaded from $assetPath");
      _embedder = await Interpreter.fromBuffer(modelData.buffer.asUint8List());
      final outputShape = _embedder!.getOutputTensor(0).shape;
      _modelOutputDim = outputShape.isNotEmpty ? outputShape.last : dim;
      print('1) Interpreter loaded successfully from asset: $assetPath (output dim $_modelOutputDim)');
    } catch (e) {
      print('Error loading interpreter from asset: $e');
      rethrow;
    }
  }

  List<double> _alignEmbedding(List<double> emb) {
    final targetDim = _modelOutputDim ?? dim;
    if (emb.length == targetDim) return emb;

    if (emb.length > targetDim) {
      return emb.sublist(0, targetDim);
    }

    final aligned = List<double>.filled(targetDim, 0.0);
    for (var i = 0; i < emb.length && i < targetDim; i++) {
      aligned[i] = emb[i];
    }
    return aligned;
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
      final alignedEmb = _alignEmbedding(embList);
      final norm = math.sqrt(alignedEmb.fold<double>(0, (s,v) => s + v * v));
      final emb = norm >0 ? alignedEmb.map((e) => e / norm).toList() : alignedEmb;

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
        final imgIndex = _dbEmbeddings.length;
        _dbEmbeddings.add(emb);
        _imgWpIds.add(wpId);
        _descRows.add(rows);
        _descBytes.add(bytes);
        _kpCoords.add(coords.map((p) => [p[0], p[1]]).toList());

        if (wpId != -1) {
          _wpToImageIndexes.putIfAbsent(wpId, () => []).add(imgIndex);
        }
      }
    }

    // print("NAMETOID: ${nameToId}");

    if (_dbEmbeddings.isEmpty) {
      throw Exception("Indice offline vuoto o non valido per il tour $tourId");
    }
    _jsonIndexLoaded = true;
    print('Offline index loaded for tour $tourId with ${_dbEmbeddings.length} images.');
  }

  img.Image _preprocessImage(img.Image image) {
    final shortest = math.min(image.width, image.height);

    final scale = 256 / shortest;
    final resized = img.copyResize(
      image,
      width: (image.width * scale).round(),
      height: (image.height * scale).round(),
      interpolation: img.Interpolation.cubic,
    );
    // print("  [Dart] Resized shape: ${resized.width}x${resized.height}");

    // final cropX = ((resized.width - inputSize) / 2).round().clamp(0, resized.width - inputSize);
    // final cropY = ((resized.height - inputSize) / 2).round().clamp(0, resized.height - inputSize);
    final cropX = ((resized.width - inputSize) / 2).round();
    final cropY = ((resized.height - inputSize) / 2).round();


    return img.copyCrop(resized, x: cropX, y: cropY, width: inputSize, height: inputSize);
  }

  List<double> _extractEmbedding(img.Image image) {
    if (_embedder == null) throw Exception("Embedder not initialized");

    final processedImage = _preprocessImage(image);

    final mean = [0.485, 0.456, 0.406];
    final std = [0.229, 0.224, 0.225];

    final pixels = inputSize * inputSize;
    final floatBuffer = Float32List(pixels * 3);

    // --- DEBUG LOGGING ---
    List<String> pixelLogs = [];
    for (int i = 0; i < 10; i++) {
      final pixel = processedImage.getPixel(i, 0);
      pixelLogs.add(
        "[${pixel.r.toInt()}, ${pixel.g.toInt()}, ${pixel.b.toInt()}]",
      );
    }
    // print("  [Dart] First 10 cropped RGB pixels:\n[${pixelLogs.join(', ')}]");

    // 3. Normalize
    int bufferIndex = 0;
    for (int y = 0; y < inputSize; y++) {
      for (int x = 0; x < inputSize; x++) {
        final pixel = processedImage.getPixel(x, y);
        floatBuffer[bufferIndex++] = (pixel.r / 255.0 - mean[0]) / std[0];
        floatBuffer[bufferIndex++] = (pixel.g / 255.0 - mean[1]) / std[1];
        floatBuffer[bufferIndex++] = (pixel.b / 255.0 - mean[2]) / std[2];
      }
    }

    // --- DEBUG LOGGING ---
    // print(
    //   "  [Dart] First 30 normalized values:\n${floatBuffer.sublist(0, 30)}",
    // );

    // 4. Prepare Tensor
    // Reshape to [1, 224, 224, 3] for NHWC models
    final inputTensor = floatBuffer.reshape([1, inputSize, inputSize, 3]);

    final outputShape = _embedder!.getOutputTensor(0).shape;
    final outputBuffer = List.filled(
      outputShape.reduce((a, b) => a * b),
      0.0,
    ).reshape(outputShape);

    _embedder!.run(inputTensor, outputBuffer);

    // final embedding = (outputBuffer[0] as List).cast<double>();
    List<double> embedding = [];

    void flattenToDoubles(dynamic item) {
      if (item is List) {
        for (var subItem in item) {
          flattenToDoubles(subItem);
        }
      } else if (item is num) {
        embedding.add(item.toDouble());
      }
    }

    flattenToDoubles(outputBuffer);

    // Limita alla dimensione del modello se necessario
    final targetDim = _modelOutputDim ?? dim;
    if (embedding.length > targetDim) {
      embedding = embedding.sublist(0, targetDim);
    }

    // 5. L2 Normalize Embedding
    final n = math.sqrt(embedding.fold<double>(0, (s, e) => s + e * e));
    final normalizedEmbedding =
        n > 1e-6 ? embedding.map((e) => e / n).toList() : embedding;

    // print("  [Dart] Embedding norm: $n");
    // print(
    //   "  [Dart] First 10 embedding values:\n${normalizedEmbedding.sublist(0, 10)}",
    // );

    return normalizedEmbedding;
  }

  List<int> _topKByCosine(List<double> qEmb, int k, {List<double>? scoreOut}) {
    final N = _dbEmbeddings.length;
    final scores = List<double>.filled(N, 0.0);
    for (int i = 0; i < N; i++) {
      final db = _dbEmbeddings[i];
      final len = math.min(qEmb.length, db.length);
      double s = 0.0;
      for (int j = 0; j < len; j++) {
        s += qEmb[j] * db[j];
      }
      scores[i] = s;
    }
    if (scoreOut != null && scoreOut.length == N) {
      for (int i = 0; i < N; i++) {
        scoreOut[i] = scores[i];
      }
    }
    final idx = List<int>.generate(N, (i) => i);
    idx.sort((a,b) => scores[b].compareTo(scores[a]));
    return idx.take(math.min(k, N)).toList();
  }

  Future<int> matchFromImageBytes(
    Uint8List imageBytes, {
    int sensorOrientation = 0,
    int inliersThreshold = _defaultInliersThreshold,
    int topMatchesForRansac = 80,
    int topK = _defaultTopK,
  }) async {
    if (_embedder == null || !_jsonIndexLoaded) {
      throw Exception(
        "OFFLINE ERROR: Embedder non inizializzato o indice JSON non caricato",
      );
    }

    try {
      img.Image? queryImg = img.decodeImage(imageBytes);
      if (queryImg == null) return -1;
      if (sensorOrientation != 0) {
        queryImg = img.copyRotate(
          queryImg,
          angle: sensorOrientation.toDouble(),
        );
      }

      final Uint8List visionBytes = Uint8List.fromList(img.encodeJpg(queryImg, quality: 95));

      final qEmb = _extractEmbedding(queryImg);
      // print("QEMB: ${qEmb.length} values");
      if (qEmb.isEmpty) return -1;

      final scores = List<double>.filled(_dbEmbeddings.length, 0.0);
      final ranked = _topKByCosine(
        qEmb,
        _dbEmbeddings.length,
        scoreOut: scores,
      );

      // print("RANKED: ${ranked.length} images");

      final waypointScores = <int, double>{};
      for (final idx in ranked) {
        final wpId = _imgWpIds[idx];
        if (wpId == -1) continue;
        final score = scores[idx];
        waypointScores.update(
          wpId,
          (prev) => math.max(prev, score),
          ifAbsent: () => score,
        );
      }

      // print("WAYPOINT SCORES: ${waypointScores.length}");
      // print("WAYPOINT SCORES: ${waypointScores.entries}");

      final sortedWaypoints =
          waypointScores.entries
              .where((e) => e.value >= _similarityThreshold)
              .toList()
            ..sort((a, b) => b.value.compareTo(a.value));

      // print("SORTED WAYPOINTS: ${sortedWaypoints.length} candidates");
      if (sortedWaypoints.isEmpty) return -1;

      final orb = cv.ORB.create(nFeatures: 5000);
      final bf = cv.BFMatcher.create(type: cv.NORM_HAMMING, crossCheck: true);

      // final cv.Mat qColor = cv.imdecode(imageBytes, cv.IMREAD_COLOR);
      final cv.Mat qColor = cv.imdecode(visionBytes, cv.IMREAD_COLOR);
      // print("QCOLOR: ${qColor.rows}x${qColor.cols}");
      if (qColor.isEmpty) return -1;
      final qGray = cv.cvtColor(qColor, cv.COLOR_BGR2GRAY);
      qColor.release();

      final qKp = cv.VecKeyPoint();
      final qDesc = cv.Mat.empty();
      orb.detectAndCompute(
        qGray,
        cv.Mat.empty(),
        keypoints: qKp,
        descriptors: qDesc,
      );
      // print("QDESC: ${qDesc.rows}x${qDesc.cols}, KPs: ${qKp.size()}");
      if (qDesc.isEmpty) {
        qGray.release();
        qKp.clear();
        qDesc.release();
        return -1;
      }

      final qKey = qKp.toList();
      int bestWp = -1;
      int bestInliers = 0;

      final waypointCandidates = sortedWaypoints.take(topK);
      for (final entry in waypointCandidates) {
        final wpId = entry.key;
        final imageIdx =
            (_wpToImageIndexes[wpId] ?? const <int>[])
                .where((i) => scores[i] >= _similarityThreshold)
                .take(topK)
                .toList();
        if (imageIdx.isEmpty) continue;

        for (final i in imageIdx) {
          final dbKps = _kpCoords[i];
          final rows = _descRows[i];
          final bytes = _descBytes[i];
          if (rows < 8 || bytes.isEmpty || dbKps.isEmpty) continue;

          final dMat = cv.Mat.fromList(
            rows,
            32,
            cv.MatType(cv.MatType.CV_8U),
            bytes,
          );
          final matches = bf.match(qDesc, dMat);
          final ms = matches.toList();

          dMat.release();
          matches.clear();

          if (ms.length < inliersThreshold) continue;

          ms.sort((a, b) => a.distance.compareTo(b.distance));
          final topMatches =
              ms
                  .take(topMatchesForRansac)
                  .where(
                    (m) =>
                        m.queryIdx >= 0 &&
                        m.queryIdx < qKey.length &&
                        m.trainIdx >= 0 &&
                        m.trainIdx < dbKps.length,
                  )
                  .toList();

          final src = <cv.Point2f>[];
          final dst = <cv.Point2f>[];
          for (final m in topMatches) {
            final qp = qKey[m.queryIdx];
            final p = dbKps[m.trainIdx];
            src.add(cv.Point2f(qp.x, qp.y));
            dst.add(cv.Point2f(p[0], p[1]));
          }

          if (src.length >= inliersThreshold) {
            final srcVec = cv.VecPoint2f.fromList(src);
            final dstVec = cv.VecPoint2f.fromList(dst);
            final srcMat = cv.Mat.fromVec(srcVec);
            final dstMat = cv.Mat.fromVec(dstVec);
            final mask = cv.Mat.empty();
            final H = cv.findHomography(
              srcMat,
              dstMat,
              method: cv.RANSAC,
              ransacReprojThreshold: 5.0,
              mask: mask,
            );

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
        if (bestWp != -1) break;
      }

      qGray.release();
      qKp.clear();
      qDesc.release();

      // print("BEST INLIERS: ${bestInliers}");
      // print("BEST WP: ${bestWp}");

      return bestInliers >= inliersThreshold ? bestWp : -1;
    } catch(e) {
      print('OFFLINE ERROR: Exception during matching - $e');
      return -1;
    }
  }

  void dispose() {
    _embedder?.close();
    _embedder = null;
  }
}
