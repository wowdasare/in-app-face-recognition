import 'dart:typed_data';

import 'tflite_face_recognition_service.dart';

class FaceRecognitionService {
  final TFLiteFaceRecognitionService _tfliteService =
      TFLiteFaceRecognitionService();

  /// Load the face recognition model
  Future<bool> loadModel() async {
    return await _tfliteService.loadModels();
  }

  bool get isModelLoaded => _tfliteService.isModelLoaded;

  String get modelStatus => _tfliteService.modelStatus;

  /// Get face embedding from image bytes
  Future<List<double>?> getFaceEmbedding(Uint8List imageBytes) async {
    return await _tfliteService.getFaceEmbedding(imageBytes);
  }

  /// Calculate similarity between two embeddings
  double calculateSimilarity(List<double> embedding1, List<double> embedding2) {
    return _tfliteService.calculateSimilarity(embedding1, embedding2);
  }

  /// Calculate distance between two embeddings
  double calculateDistance(List<double> embedding1, List<double> embedding2) {
    return _tfliteService.calculateDistance(embedding1, embedding2);
  }

  /// Check if two faces are the same person
  bool areSamePerson(
    List<double> embedding1,
    List<double> embedding2, {
    double threshold = 0.75,
  }) {
    double similarity = calculateSimilarity(embedding1, embedding2);
    return similarity > threshold;
  }

  /// Verify faces with detailed results
  Map<String, dynamic> verifyFaces(
    List<double> embedding1,
    List<double> embedding2, {
    double threshold = 0.75,
  }) {
    return _tfliteService.verifyFaces(
      embedding1,
      embedding2,
      threshold: threshold,
    );
  }

  void dispose() {
    _tfliteService.dispose();
  }
}
