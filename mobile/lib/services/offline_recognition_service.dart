import 'dart:math' as math;
import 'dart:convert';
import 'dart:typed_data';
import 'dart:io';
import 'package:image/image.dart' as img;
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:opencv_dart/opencv_dart.dart' as cv;
import 'package:opencv_dart/opencv.dart' as cv1; 
import 'package:path_provider/path_provider.dart';

class OfflineRecognitionService {

  Interpreter? _embedder;
  int dim; // dimensione embedding (es. 2048 o 1280)
  int inputSize;

  final List<List<double>> _dbEmbeddings = [];
  final List<int> _imgWpIds = [];
  final List<int> _descRows = [];
  final List<Uint8List> _descBytes = [];
  final List<List<List<double>>> _kpCoords = [];
  bool _jsonIndexLoaded = false;


  OfflineRecognitionService({this.dim = 2048, this.inputSize = 224});

  Future<String> _copyAssetToTemp(String assetPath) async {
    // Se hai già il modello come asset, puoi caricarlo direttamente con rootBundle.load.
    // Qui metti un placeholder se preferisci copiare su file temporaneo.
    return assetPath;
  }

  Future<List<double>> _extractEmbedding(String imagePath) async {
    final im = await img.decodeImageFile(imagePath);
    if (im == null) return [];
    final resized = img.copyResize(im, width: inputSize, height: inputSize);
    final mean = [0.485, 0.456, 0.406];
    final std = [0.229, 0.224, 0.225];

    final input = List.filled(inputSize * inputSize * 3, 0.0);
    int idx = 0;
    for (var pixel in resized){
      final r = pixel.r / 255.0;
      final g = pixel.g / 255.0;
      final b = pixel.b / 255.0;
      input[idx++] = (r - mean[0]) / std[0];
      input[idx++] = (g - mean[1]) / std[1];
      input[idx++] = (b - mean[2]) / std[2];
    }
    final inTensor = input.reshape([1, inputSize, inputSize, 3]);
    final out = List.filled(dim, 0.0).reshape([1, dim]);
    _embedder?.run(inTensor, out);
    final v = List<double>.from(out.first);
    final n = math.sqrt(v.fold<double>(0, (s,e) => s + e*e));
    return n > 0 ? v.map((e) => e / n).toList() : v;
  }

  Future<void> initEmbedderFromAsset(String assetPath) async {
    final data = await File(await _copyAssetToTemp(assetPath)).readAsBytes();
    _embedder = await Interpreter.fromBuffer(data);
  }

  Future<void> initIndexForTour(int tourId) async {
    final appDir = await getApplicationDocumentsDirectory();
    final tourDir = Directory('${appDir.path}/offline_tours_data/tour_$tourId');
    final indexJsonFile = File('${tourDir.path}/training_data.json');
    if (!await indexJsonFile.exists()) {
      throw Exception('Index file not found for tour $tourId');
    }
    final tourDataFile = File('${tourDir.path}/tour_data.json');
    if (!await tourDataFile.exists()) {
      throw Exception('tour_data.json non trovato per tour con ID : $tourId');
    }

    final tourData = jsonDecode(await tourDataFile.readAsString()) as Map<String, dynamic>;
    final Map<String, int> nameToId = {};

    final wps = (tourData["waypoints"] as List?) ?? [];
    for (final w in wps) {
      final title = (w['title'] ?? '').toString();
      final id = (w["id"] as num).toInt();
      if (title.isNotEmpty) nameToId[title] = id;
    }

    final subTours = (tourData['sub_tours'] as List?) ?? [];
    for (final st in subTours) {
      final swps = (st['waypoints'] as List?) ?? [];
      for (final w in swps) {
        final title = (w['title'] ?? '').toString();
        final id = (w["id"] as num).toInt();
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
      final String wpName = m['waypoint_name']?.toString() ?? '';
      final int wpId = nameToId[wpName] ?? -1;

      final embList = (m['embedding'] as List).map((e) => (e as num).toDouble()).toList();
      final norm = math.sqrt(embList.fold<double>(0, (s,v) => s + v*v));
      final emb = norm > 0 ? embList.map((v) => v / norm).toList() : embList;

      final kps = (m['keypoints'] as List?) ?? const [];
      final coords = <List<double>>[];
      for (final k in kps) {
        final kk = k as List;
        final pt = kk[0] as List;
        coords.add([(pt[0] as num).toDouble(), (pt[1] as num).toDouble()]);
      }

      final rows = (m["desc_rows"] as num?)?.toInt() ?? 0;
      final cols = (m["desc_cols"] as num?)?.toInt() ?? 0;
      Uint8List bytes = Uint8List(0);
      if (rows > 0 && cols > 0) {
        final b64 = (m['descriptors_b64'] ?? '') as String;
        if (b64.isNotEmpty){
          bytes = base64Decode(b64);
          if (bytes.length != rows * cols) {
            bytes = Uint8List(0);
          }
        }
      }

      if (emb.isNotEmpty && coords.length ==rows){
        _dbEmbeddings.add(emb);
        _imgWpIds.add(wpId);
        _descRows.add(rows);
        _descBytes.add(bytes);
        _kpCoords.add(coords.map((p) => [p[0], p[1]]).toList());
      }
    }

    if (_dbEmbeddings.isEmpty) {
      throw Exception('Nessun dato di training valido trovato per tour con ID : $tourId');
    }
    _jsonIndexLoaded = true;
  }

  // Seleziona i top-K via similarità coseno
  List<int> _topKByCosine(List<double> qEmb, int k) {
    final N = _dbEmbeddings.length;
    final scores = List<double>.filled(N, 0.0);
    for (int i = 0; i < N; i++) {
      final db = _dbEmbeddings[i];
      double s = 0.0;
      for (int j = 0; j < db.length && j < qEmb.length; j++) {
        s += db[j] * qEmb[j];
      }
      scores[i] = s;
    }
    final idx = List<int>.generate(N, (i) => i);
    idx.sort((a, b) => scores[b].compareTo(scores[a]));
    return idx.take(math.min(k, N)).toList();
  }

//   Future<int> match(
//     String queryImagePath, {
//     int inliersThreshold = 10,
//     int topMatchesForRansac = 80,
//     int topK = 10,
//   }) async {
//     if (_embedder == null || !_jsonIndexLoaded) {
//       throw Exception('Embedder o Index JSON non inizializzati');
//     }

//     // 1) Embedding query
//     final qEmb = await _extractEmbedding(queryImagePath);
//     if (qEmb.isEmpty) return -1;

//     // 2) Top-K candidati per similarità coseno
//     final topIdx = _topKByCosine(qEmb, topK);

//     // 3) ORB per query
//     final orb = cv.ORB.create(nFeatures: 5000);
//     final bf = cv.BFMatcher.create(type: cv1.NORM_HAMMING, crossCheck: true);
//     final qColor = cv.imread(queryImagePath);
//     if (qColor.isEmpty) {
//       qColor.release();
//       return -1;
//     }
//     final qGray = cv.Mat.empty();
//     cv.cvtColor(qColor, cv.COLOR_BGR2GRAY, dst: qGray);
//     final qKp = cv.VecKeyPoint();
//     final qDesc = cv.Mat.empty();
//     orb.detectAndCompute(
//       qGray,
//       cv.Mat.empty(),
//       keypoints: qKp,
//       description: qDesc,
//     );
//     if (qDesc.isEmpty) {
//       qColor.release();
//       qGray.release();
//       qDesc.release();
//       return -1;
//     }

//     // 4) Verifica geometrica sui top-K
//     int bestWp = -1, bestInliers = 0;
//     final qKey = qKp.toList();

//     for (final i in topIdx) {
//       final rows = _descRows[i];
//       final bytes = _descBytes[i];
//       if (rows < 8 || bytes.isEmpty) continue;

//       // Costruisci Mat descriptors candidato [rows, 32] CV_8U
//       final dMat = cv.Mat.fromBytes(rows, 32, cv.CV_8U, bytes);

//       // Match BF
//       final matches = cv.MatOfDMatch();
//       bf.match(qDesc, dMat, matches);
//       final ms = matches.toList();
//       dMat.release();
//       if (ms.length < 8) continue;

//       ms.sort((a, b) => a.distance.compareTo(b.distance));
//       final top = ms.take(topMatchesForRansac).toList();

//       // Costruisci punti
//       final src = <cv.Point2f>[];
//       final dst = <cv.Point2f>[];
//       final coords = _kpCoords[i];
//       for (final m in top) {
//         final qp = qKey[m.queryIdx].pt;
//         final p2 = coords[m.trainIdx];
//         src.add(cv.Point2f(qp.x, qp.y));
//         dst.add(cv.Point2f(p2[0], p2[1]));
//       }

//       if (src.length >= 8) {
//         final srcMat = cv.MatOfPoint2f.fromList(src);
//         final dstMat = cv.MatOfPoint2f.fromList(dst);
//         final mask = cv.Mat();
//         final H = cv.findHomography(srcMat, dstMat, cv.RANSAC, 5.0, mask);
//         if (!H.empty) {
//           final inliers = cv.countNonZero(mask);
//           if (inliers > bestInliers) {
//             bestInliers = inliers;
//             bestWp = _imgWpIds[i];
//           }
//         }
//         srcMat.release();
//         dstMat.release();
//         mask.release();
//         H.release();
//       }
//     }

//     qColor.release();
//     qGray.release();
//     qKp.release();
//     qDesc.release();
//     return bestInliers >= inliersThreshold ? bestWp : -1;
//   }

}
