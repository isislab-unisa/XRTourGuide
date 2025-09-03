import 'package:opencv_dart/opencv.dart';
import 'package:opencv_dart/opencv_dart.dart' as cv;

Future<void> sanityCheckOpenCv() async {
  try {
    final orb = cv.ORB.create(nFeatures: 5000);
    final bf = cv.BFMatcher.create(type: NORM_HAMMING, crossCheck: true);
    // findHomography verrà usata con MatOfPoint2f
    print('OpenCV OK: features2d + calib3d disponibili.');
  } catch (e) {
    print('Moduli mancanti (features2d/calib3d): $e');
  }
}