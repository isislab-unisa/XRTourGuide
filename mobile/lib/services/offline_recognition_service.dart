import 'dart:math' as math;
import 'dart:convert';
import 'dart:typed_data';
import 'dart:io';
import 'package:image/image.dart' as img;
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:opencv_dart/opencv_dart.dart' as cv;
import 'package:opencv_dart/opencv.dart';
import 'package:path_provider/path_provider.dart';

class OfflineRecognitionService {

  Interpreter? _embedder;
  Interpreter? _index;
  int dim; // dimensione embedding (es. 2048 o 1280)
  int inputSize;

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
    final indexFile = File('${tourDir.path}/offline_index.tflite');
    if (!await indexFile.exists()) {
      throw Exception('Index file not found for tour $tourId');
    }
    _index = await Interpreter.fromFile(indexFile);
  }

  Future<int> match(
    String queryImagePath, {
      int inliersThreshold = 10,
      int topMatchesForRansac = 80,
    }) async {
      if (_embedder == null || _index == null) {
        throw Exception('Embedder or Index not initialized');
      }

      //Embedding query
      final qEmb = await _extractEmbedding(queryImagePath);

      //Query indice 
      // Output order (come definito nel converter): 
      // 0: indices[int32 k], 1: scores[float k], 2: wp_ids[int32 k],
      // 3: kp_counts[int32 k], 4: kp_coords[float k,M,2], 5: desc[uint8 k,M,32]
      final outputs = <int, Object> {
        0: List.filled(10, 0).reshape([10]),
        1: List.filled(10, 0.0).reshape([10]),
        2: List.filled(10, 0).reshape([10]),
        3: List.filled(10, 0).reshape([10]),
        4: List.filled(10*512 * 2, 0.0).reshape([10,512,2]),
        5: List.filled(10*512*32, 0).reshape([10,512,32]),
      };
      _index!.runForMultipleInputs([qEmb.reshape([dim])], outputs);

      final topK = (outputs[0] as List<int>).length;
      final wpIds = (outputs[2] as List<int>);
      final kpCounts = (outputs[3] as List<int>);
      final kpCoords = (outputs[4] as List<List<List<double>>>);
      final descArr = (outputs[5] as List<List<List<int>>>);

      final orb = cv.ORB.create(nFeatures: 5000);
      final bf = cv.BFMatcher.create(type: NORM_HAMMING, crossCheck: true);
      final qColor = cv.imread(queryImagePath);
      if (qColor.isEmpty) {
        qColor.release();
        return -1;
      }
      final qGray = cv.Mat.empty();
      cv.cvtColor(qColor, cv.COLOR_BGR2GRAY, dst: qGray);
      final qKp = cv.VecKeyPoint();
      final qDesc = cv.Mat.empty();
      orb.detectAndCompute(qGray, cv.Mat.empty(), keypoints: qKp, description: qDesc);
      if (qDesc.isEmpty) {
        qColor.release();
        qGray.release();
        qDesc.release();
        return -1;
      }
          // 4) Verifica geometrica sui top-k
      int bestWp = -1, bestInliers = 0;
      final qKey = qKp.toList();

      for (int i = 0; i < topK; i++) {
        final rows = kpCounts[i];
        if (rows < 8) continue;

        // Costruisci Mat descriptors candidato [rows, 32] CV_8U
        final flat = <int>[];
        for (int r = 0; r < rows; r++) {
          flat.addAll(descArr[i][r].take(32)); // 32 byte
        }
        final dMat = cv.Mat.fromBytes(
          rows,
          32,
          cv.CV_8U,
          Uint8List.fromList(flat),
        );

        // Match BF
        final matches = cv.MatOfDMatch();
        bf.match(qDesc, dMat, matches);
        final ms = matches.toList();
        dMat.release();
        if (ms.length < 8) continue;

        ms.sort((a, b) => a.distance.compareTo(b.distance));
        final top = ms.take(topMatchesForRansac).toList();

        // Costruisci punti
        final src = <cv.Point2f>[];
        final dst = <cv.Point2f>[];
        for (final m in top) {
          final qp = qKey[m.queryIdx].pt;
          final p2 = kpCoords[i][m.trainIdx];
          src.add(cv.Point2f(qp.x, qp.y));
          dst.add(cv.Point2f(p2[0], p2[1]));
        }

        if (src.length >= 8) {
          final srcMat = cv.MatOfPoint2f.fromList(src);
          final dstMat = cv.MatOfPoint2f.fromList(dst);
          final mask = cv.Mat();
          final H = cv.findHomography(srcMat, dstMat, cv.RANSAC, 5.0, mask);
          if (!H.empty) {
            final inliers = cv.countNonZero(mask);
            if (inliers > bestInliers) {
              bestInliers = inliers;
              bestWp = wpIds[i];
            }
          }
          srcMat.release();
          dstMat.release();
          mask.release();
          H.release();
        }
      }

      qColor.release();
      qGray.release();
      qKp.release();
      qDesc.release();
      return bestInliers >= inliersThreshold ? bestWp : -1;
    }


}