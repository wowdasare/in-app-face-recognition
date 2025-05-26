import 'dart:math';
import 'dart:typed_data';

import 'package:image/image.dart' as img;
import 'package:tflite_flutter/tflite_flutter.dart';

class FaceRecognitionService {
  Interpreter? _interpreter;
  static const int INPUT_SIZE = 112;
  static const int EMBEDDING_SIZE = 512;

  // Initialize the MobileFaceNet model
  Future<void> loadModel() async {
    try {
      _interpreter = await Interpreter.fromAsset(
        'assets/models/MobileFaceNet.tflite',
      );
      print('MobileFaceNet model loaded successfully');
    } catch (e) {
      print('Failed to load MobileFaceNet model: $e');
      rethrow;
    }
  }

  // Process image from file path - main method for widget
  Future<List<double>?> getFaceEmbeddingFromPath(String imagePath) async {
    try {
      // Read image file
      final imageFile = await img.decodeImageFile(imagePath);
      if (imageFile == null) {
        print('Failed to decode image: $imagePath');
        return null;
      }

      // Convert to bytes and process
      final imageBytes = Uint8List.fromList(img.encodeJpg(imageFile));
      return await getFaceEmbedding(imageBytes);
    } catch (e) {
      print('Error getting face embedding from path: $e');
      return null;
    }
  }

  // Get face embedding from image bytes
  Future<List<double>?> getFaceEmbedding(Uint8List imageBytes) async {
    if (_interpreter == null) {
      await loadModel();
    }

    try {
      // Decode image
      img.Image? image = img.decodeImage(imageBytes);
      if (image == null) {
        print('Failed to decode image bytes');
        return null;
      }

      // Preprocess image for MobileFaceNet
      final input = _preprocessImage(image);

      // Prepare input tensor [1, 112, 112, 3]
      final inputTensor = [
        input.reshape([1, INPUT_SIZE, INPUT_SIZE, 3]),
      ];

      // Prepare output tensor [1, 512]
      final outputTensor = List.generate(
        1,
        (index) => List.filled(EMBEDDING_SIZE, 0.0),
      );

      // Run inference
      _interpreter!.run(inputTensor[0], outputTensor);

      // Extract and normalize embedding
      List<double> embedding = List<double>.from(outputTensor[0]);
      return _normalizeEmbedding(embedding);
    } catch (e) {
      print('Error getting face embedding: $e');
      return null;
    }
  }

  // Preprocess image for MobileFaceNet (112x112, normalized to [-1, 1])
  List<List<List<List<double>>>> _preprocessImage(img.Image image) {
    // Resize to 112x112
    img.Image resized = img.copyResize(
      image,
      width: INPUT_SIZE,
      height: INPUT_SIZE,
      interpolation: img.Interpolation.linear,
    );

    // Create 4D tensor [1, 112, 112, 3]
    List<List<List<List<double>>>> inputTensor = List.generate(
      1,
      (batch) => List.generate(
        INPUT_SIZE,
        (y) => List.generate(INPUT_SIZE, (x) => List.generate(3, (c) => 0.0)),
      ),
    );

    // Fill tensor with normalized pixel values
    for (int y = 0; y < INPUT_SIZE; y++) {
      for (int x = 0; x < INPUT_SIZE; x++) {
        final pixel = resized.getPixel(x, y);

        // Normalize RGB values to [-1, 1] range
        inputTensor[0][y][x][0] = (pixel.r / 255.0) * 2.0 - 1.0; // Red
        inputTensor[0][y][x][1] = (pixel.g / 255.0) * 2.0 - 1.0; // Green
        inputTensor[0][y][x][2] = (pixel.b / 255.0) * 2.0 - 1.0; // Blue
      }
    }

    return inputTensor;
  }

  // Normalize embedding vector to unit length
  List<double> _normalizeEmbedding(List<double> embedding) {
    double norm = 0.0;
    for (double value in embedding) {
      norm += value * value;
    }
    norm = sqrt(norm);

    if (norm == 0.0 || norm.isNaN) {
      print('Warning: Invalid embedding norm');
      return embedding;
    }

    return embedding.map((value) => value / norm).toList();
  }

  // Calculate cosine similarity between two embeddings (higher = more similar)
  double calculateSimilarity(List<double> embedding1, List<double> embedding2) {
    if (embedding1.length != embedding2.length) {
      print('Warning: Embedding length mismatch');
      return 0.0;
    }

    double dotProduct = 0.0;
    for (int i = 0; i < embedding1.length; i++) {
      dotProduct += embedding1[i] * embedding2[i];
    }

    // Since embeddings are normalized, dot product equals cosine similarity
    return dotProduct.clamp(-1.0, 1.0);
  }

  // Calculate Euclidean distance (lower = more similar)
  double calculateDistance(List<double> embedding1, List<double> embedding2) {
    if (embedding1.length != embedding2.length) {
      print('Warning: Embedding length mismatch for distance');
      return double.infinity;
    }

    double distance = 0.0;
    for (int i = 0; i < embedding1.length; i++) {
      double diff = embedding1[i] - embedding2[i];
      distance += diff * diff;
    }

    return sqrt(distance);
  }

  // Determine if two faces belong to the same person
  bool areSamePerson(
    List<double> embedding1,
    List<double> embedding2, {
    double threshold = 0.5, // Cosine similarity threshold for MobileFaceNet
  }) {
    double similarity = calculateSimilarity(embedding1, embedding2);
    print(
      'Similarity: ${similarity.toStringAsFixed(4)}, Threshold: $threshold',
    );
    return similarity > threshold;
  }

  void dispose() {
    _interpreter?.close();
    print('FaceRecognitionService disposed');
  }
}
