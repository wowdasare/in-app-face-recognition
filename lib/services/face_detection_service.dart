import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:image/image.dart' as img;
import 'package:tflite_flutter/tflite_flutter.dart';

class FaceBox {
  final double x, y, width, height;
  final double confidence;

  FaceBox(this.x, this.y, this.width, this.height, this.confidence);
}

class FaceRecognitionService {
  Interpreter? _mobileFaceNet;
  Interpreter? _pnet, _rnet, _onet;

  static const int INPUT_SIZE = 112;
  static const int EMBEDDING_SIZE = 512;

  bool _modelsLoaded = false;

  // Load all models
  Future<void> loadModel() async {
    if (_modelsLoaded) return;

    try {
      print('Loading face recognition models...');

      // Load MobileFaceNet for face recognition
      _mobileFaceNet = await Interpreter.fromAsset(
        'assets/models/MobileFaceNet.tflite',
      );
      print('✓ MobileFaceNet loaded');

      // Load MTCNN models for face detection (optional - can work without them)
      try {
        _pnet = await Interpreter.fromAsset('assets/models/pnet.tflite');
        _rnet = await Interpreter.fromAsset('assets/models/rnet.tflite');
        _onet = await Interpreter.fromAsset('assets/models/onet.tflite');
        print('✓ MTCNN models loaded');
      } catch (e) {
        print('⚠ MTCNN models not loaded (using simple detection): $e');
      }

      _modelsLoaded = true;
      print('All models loaded successfully');
    } catch (e) {
      print('❌ Failed to load models: $e');
      rethrow;
    }
  }

  // Main method: Get face embedding from file path
  Future<List<double>?> getFaceEmbeddingFromPath(String imagePath) async {
    try {
      print('Processing image: $imagePath');

      // Load image
      final imageBytes = await File(imagePath).readAsBytes();
      final image = img.decodeImage(imageBytes);

      if (image == null) {
        print('❌ Failed to decode image');
        return null;
      }

      return await _processImageForEmbedding(image);
    } catch (e) {
      print('❌ Error processing image: $e');
      return null;
    }
  }

  // Get face embedding from image bytes
  Future<List<double>?> getFaceEmbedding(Uint8List imageBytes) async {
    try {
      final image = img.decodeImage(imageBytes);
      if (image == null) {
        print('❌ Failed to decode image bytes');
        return null;
      }

      return await _processImageForEmbedding(image);
    } catch (e) {
      print('❌ Error processing image bytes: $e');
      return null;
    }
  }

  // Process image and extract face embedding
  Future<List<double>?> _processImageForEmbedding(img.Image image) async {
    if (!_modelsLoaded) {
      await loadModel();
    }

    try {
      // Step 1: Detect face (simplified detection)
      final faceRegion = _detectAndCropFace(image);
      if (faceRegion == null) {
        print('❌ No face detected in image');
        return null;
      }

      print('✓ Face detected and cropped');

      // Step 2: Get embedding from face region
      return await _getFaceEmbeddingFromCroppedFace(faceRegion);
    } catch (e) {
      print('❌ Error in face processing: $e');
      return null;
    }
  }

  // Simple face detection and cropping
  img.Image? _detectAndCropFace(img.Image image) {
    try {
      // Simple center-crop approach for face detection
      // In a production app, you'd use the MTCNN models here

      final size = min(image.width, image.height);
      final centerX = image.width ~/ 2;
      final centerY = (image.height * 0.45).round(); // Slightly above center

      final cropSize = (size * 0.7).round(); // 70% of image size
      final x = (centerX - cropSize ~/ 2).clamp(0, image.width - cropSize);
      final y = (centerY - cropSize ~/ 2).clamp(0, image.height - cropSize);

      // Crop face region
      final croppedFace = img.copyCrop(
        image,
        x: x,
        y: y,
        width: cropSize,
        height: cropSize,
      );

      // Resize to 112x112 for MobileFaceNet
      return img.copyResize(
        croppedFace,
        width: INPUT_SIZE,
        height: INPUT_SIZE,
        interpolation: img.Interpolation.linear,
      );
    } catch (e) {
      print('❌ Error in face detection: $e');
      return null;
    }
  }

  // Extract embedding from preprocessed face image
  Future<List<double>?> _getFaceEmbeddingFromCroppedFace(
    img.Image faceImage,
  ) async {
    try {
      // Preprocess image for MobileFaceNet
      final input = _preprocessImageForMobileFaceNet(faceImage);

      // Prepare output
      final output = List.filled(
        EMBEDDING_SIZE,
        0.0,
      ).reshape([1, EMBEDDING_SIZE]);

      // Run inference
      _mobileFaceNet!.run(input, output);

      // Extract and normalize embedding
      final embedding = List<double>.from(output[0]);
      final normalizedEmbedding = _normalizeEmbedding(embedding);

      print('✓ Generated ${normalizedEmbedding.length}D embedding');
      return normalizedEmbedding;
    } catch (e) {
      print('❌ Error generating embedding: $e');
      return null;
    }
  }

  // Preprocess image for MobileFaceNet (112x112, normalized to [-1, 1])
  List<List<List<List<double>>>> _preprocessImageForMobileFaceNet(
    img.Image image,
  ) {
    // Ensure image is 112x112
    if (image.width != INPUT_SIZE || image.height != INPUT_SIZE) {
      image = img.copyResize(image, width: INPUT_SIZE, height: INPUT_SIZE);
    }

    // Create input tensor [1, 112, 112, 3]
    final input = List.generate(
      1,
      (_) => List.generate(
        INPUT_SIZE,
        (y) => List.generate(INPUT_SIZE, (x) => List.generate(3, (_) => 0.0)),
      ),
    );

    // Fill tensor with normalized pixel values
    for (int y = 0; y < INPUT_SIZE; y++) {
      for (int x = 0; x < INPUT_SIZE; x++) {
        final pixel = image.getPixel(x, y);

        // Normalize to [-1, 1] range as expected by MobileFaceNet
        input[0][y][x][0] = (pixel.r / 255.0) * 2.0 - 1.0; // Red
        input[0][y][x][1] = (pixel.g / 255.0) * 2.0 - 1.0; // Green
        input[0][y][x][2] = (pixel.b / 255.0) * 2.0 - 1.0; // Blue
      }
    }

    return input;
  }

  // Normalize embedding to unit vector
  List<double> _normalizeEmbedding(List<double> embedding) {
    double norm = 0.0;
    for (final value in embedding) {
      norm += value * value;
    }
    norm = sqrt(norm);

    if (norm == 0.0 || norm.isNaN || norm.isInfinite) {
      print('⚠ Warning: Invalid embedding norm: $norm');
      return embedding;
    }

    return embedding.map((value) => value / norm).toList();
  }

  // Calculate cosine similarity (range: -1 to 1, higher = more similar)
  double calculateSimilarity(List<double> embedding1, List<double> embedding2) {
    if (embedding1.length != embedding2.length) {
      print(
        '⚠ Warning: Embedding size mismatch: ${embedding1.length} vs ${embedding2.length}',
      );
      return 0.0;
    }

    double dotProduct = 0.0;
    for (int i = 0; i < embedding1.length; i++) {
      dotProduct += embedding1[i] * embedding2[i];
    }

    return dotProduct.clamp(-1.0, 1.0);
  }

  // Calculate Euclidean distance (lower = more similar)
  double calculateDistance(List<double> embedding1, List<double> embedding2) {
    if (embedding1.length != embedding2.length) {
      return double.infinity;
    }

    double distance = 0.0;
    for (int i = 0; i < embedding1.length; i++) {
      final diff = embedding1[i] - embedding2[i];
      distance += diff * diff;
    }

    return sqrt(distance);
  }

  // Determine if faces belong to same person
  bool areSamePerson(
    List<double> embedding1,
    List<double> embedding2, {
    double threshold = 0.5, // Cosine similarity threshold
  }) {
    final similarity = calculateSimilarity(embedding1, embedding2);
    final distance = calculateDistance(embedding1, embedding2);

    print(
      '📊 Similarity: ${(similarity * 100).toStringAsFixed(1)}% | '
      'Distance: ${distance.toStringAsFixed(3)} | '
      'Threshold: ${(threshold * 100).toStringAsFixed(1)}%',
    );

    return similarity > threshold;
  }

  void dispose() {
    try {
      _mobileFaceNet?.close();
      _pnet?.close();
      _rnet?.close();
      _onet?.close();
      print('✓ Face recognition models disposed');
    } catch (e) {
      print('⚠ Error disposing models: $e');
    }
  }
}
