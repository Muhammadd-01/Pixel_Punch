import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'face_cartoonizer.dart';

/// Finds the most prominent face in a photo using on-device ML Kit.
/// Returns null when no face is found or the platform has no ML Kit
/// (web/desktop) — callers then fall back to a centred crop.
class FaceDetectorService {
  static bool get isSupported =>
      !kIsWeb && (Platform.isAndroid || Platform.isIOS);

  Future<FaceBox?> detect(String imagePath) async {
    if (!isSupported) return null;
    final detector = FaceDetector(
      options: FaceDetectorOptions(
        enableLandmarks: true,
        enableClassification: true,
        performanceMode: FaceDetectorMode.accurate,
        minFaceSize: 0.1,
      ),
    );
    try {
      final faces =
          await detector.processImage(InputImage.fromFilePath(imagePath));
      if (faces.isEmpty) return null;
      faces.sort((a, b) => (b.boundingBox.width * b.boundingBox.height)
          .compareTo(a.boundingBox.width * a.boundingBox.height));
      final f = faces.first;
      List<double>? point(FaceLandmarkType type) {
        final p = f.landmarks[type]?.position;
        return p == null ? null : [p.x.toDouble(), p.y.toDouble()];
      }

      double? eyesOpen;
      final l = f.leftEyeOpenProbability, r = f.rightEyeOpenProbability;
      if (l != null && r != null) eyesOpen = (l + r) / 2;

      return FaceBox(
        left: f.boundingBox.left,
        top: f.boundingBox.top,
        width: f.boundingBox.width,
        height: f.boundingBox.height,
        leftEye: point(FaceLandmarkType.leftEye),
        rightEye: point(FaceLandmarkType.rightEye),
        smiling: f.smilingProbability,
        eyesOpen: eyesOpen,
        headTilt: f.headEulerAngleZ ?? 0,
      );
    } catch (e) {
      debugPrint('[FaceDetector] detection failed: $e');
      return null;
    } finally {
      await detector.close();
    }
  }
}
