import 'dart:typed_data';

import 'package:image/image.dart' as img;
import 'package:tflite_flutter/tflite_flutter.dart';

class FaceRecognitionService {
  Interpreter? _interpreter;
  static const int INPUT_SIZE = 112;
  static const int EMBEDDING_SIZE = 512;

  // Initialize the model
  Future<void> loadModel() async {
    try {
      _interpreter = await Interpreter.fromAsset(
        'assets/models/MobileFaceNet.tflite',
      );
      print('MobileFaceNet model loaded successfully');
    } catch (e) {
      print('Failed to load model: $e');
    }
  }

  // Preprocess image for MobileFaceNet
  Float32List _preprocessImage(img.Image image) {
    // Resize to 112x112
    img.Image resized = img.copyResize(
      image,
      width: INPUT_SIZE,
      height: INPUT_SIZE,
    );

    // Convert to Float32List and normalize to [-1, 1]
    Float32List inputBytes = Float32List(1 * INPUT_SIZE * INPUT_SIZE * 3);
    int pixelIndex = 0;

    for (int y = 0; y < INPUT_SIZE; y++) {
      for (int x = 0; x < INPUT_SIZE; x++) {
        img.Pixel pixel = resized.getPixel(x, y);

        // Normalize RGB values to [-1, 1]
        inputBytes[pixelIndex++] = (pixel.r / 255.0 * 2.0 - 1.0);
        inputBytes[pixelIndex++] = (pixel.g / 255.0 * 2.0 - 1.0);
        inputBytes[pixelIndex++] = (pixel.b / 255.0 * 2.0 - 1.0);
      }
    }

    return inputBytes;
  }

  // Get face embedding
  Future<List<double>?> getFaceEmbedding(Uint8List imageBytes) async {
    if (_interpreter == null) {
      await loadModel();
    }

    try {
      // Decode image
      img.Image? image = img.decodeImage(imageBytes);
      if (image == null) return null;

      // Preprocess
      Float32List input = _preprocessImage(image);

      // Prepare input tensor [1, 112, 112, 3]
      var inputTensor = input.reshape([1, INPUT_SIZE, INPUT_SIZE, 3]);

      // Prepare output tensor [1, 512]
      var outputTensor = List.filled(
        1 * EMBEDDING_SIZE,
        0.0,
      ).reshape([1, EMBEDDING_SIZE]);

      // Run inference
      _interpreter!.run(inputTensor, outputTensor);

      // Return normalized embedding
      List<double> embedding = List<double>.from(outputTensor[0]);
      return _normalizeEmbedding(embedding);
    } catch (e) {
      print('Error getting face embedding: $e');
      return null;
    }
  }

  // Normalize embedding vector
  List<double> _normalizeEmbedding(List<double> embedding) {
    double norm = 0.0;
    for (double value in embedding) {
      norm += value * value;
    }
    norm = sqrt(norm);

    return embedding.map((value) => value / norm).toList();
  }

  // Calculate cosine similarity between two embeddings
  double calculateSimilarity(List<double> embedding1, List<double> embedding2) {
    if (embedding1.length != embedding2.length) return 0.0;

    double dotProduct = 0.0;
    for (int i = 0; i < embedding1.length; i++) {
      dotProduct += embedding1[i] * embedding2[i];
    }

    return dotProduct; // Already normalized embeddings
  }

  // Calculate Euclidean distance
  double calculateDistance(List<double> embedding1, List<double> embedding2) {
    if (embedding1.length != embedding2.length) return double.infinity;

    double distance = 0.0;
    for (int i = 0; i < embedding1.length; i++) {
      double diff = embedding1[i] - embedding2[i];
      distance += diff * diff;
    }

    return sqrt(distance);
  }

  // Check if two faces are the same person
  bool areSamePerson(
    List<double> embedding1,
    List<double> embedding2, {
    double threshold = 0.5,
  }) {
    double similarity = calculateSimilarity(embedding1, embedding2);
    return similarity > threshold;
  }

  void dispose() {
    _interpreter?.close();
  }
}

// Helper function
double sqrt(double x) => x < 0 ? 0 : x.abs() * 1.0;
