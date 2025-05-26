import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:image/image.dart' as img;

class FaceRecognitionService {
  bool _isModelLoaded = false;

  static const int INPUT_SIZE = 112;
  static const int EMBEDDING_SIZE = 512;

  // Singleton pattern
  static final FaceRecognitionService _instance =
      FaceRecognitionService._internal();

  factory FaceRecognitionService() => _instance;

  FaceRecognitionService._internal();

  // Initialize the service (mock mode for demo)
  Future<bool> loadModel() async {
    try {
      print('Initializing Face Recognition Service (Demo Mode)...');

      // Simulate model loading delay
      await Future.delayed(const Duration(milliseconds: 500));

      _isModelLoaded = true;
      print('Face Recognition Service initialized successfully');
      print('Mode: Demo/Mock (no TensorFlow Lite required)');
      print(
        'Features: Image processing, similarity calculation, face comparison',
      );
      return true;
    } catch (e) {
      print('Failed to initialize face recognition service: $e');
      _isModelLoaded = true; // Still allow demo mode
      return true;
    }
  }

  bool get isModelLoaded => _isModelLoaded;

  // Generate sophisticated mock embedding based on actual image features
  List<double> _generateAdvancedMockEmbedding(img.Image image) {
    // Calculate various image features for realistic embeddings
    var features = _extractImageFeatures(image);

    // Create deterministic seed from image content
    String imageHash = _calculateImageHash(image);
    var random = math.Random(imageHash.hashCode);

    List<double> embedding = [];

    // Use extracted features to create structured embedding
    for (int i = 0; i < EMBEDDING_SIZE; i++) {
      double value;

      if (i < 50) {
        // First 50 values based on brightness patterns
        value =
            features['brightness']! * math.sin(i * 0.1) +
            (random.nextDouble() - 0.5) * 0.3;
      } else if (i < 100) {
        // Next 50 based on color distribution
        value =
            features['colorVariance']! * math.cos(i * 0.1) +
            (random.nextDouble() - 0.5) * 0.3;
      } else if (i < 150) {
        // Edge patterns
        value =
            features['edgeDensity']! * math.sin(i * 0.2) +
            (random.nextDouble() - 0.5) * 0.2;
      } else if (i < 200) {
        // Texture features
        value =
            features['textureComplexity']! * math.cos(i * 0.15) +
            (random.nextDouble() - 0.5) * 0.2;
      } else if (i < 300) {
        // Spatial features
        value =
            features['spatialDistribution']! * math.sin(i * 0.05) +
            (random.nextDouble() - 0.5) * 0.4;
      } else {
        // Random but correlated features
        value =
            math.sin(i * 0.1 + features['brightness']!) * 0.6 +
            (random.nextDouble() - 0.5) * 0.4;
      }

      embedding.add(value);
    }

    return embedding;
  }

  // Extract meaningful features from image for embedding generation
  Map<String, double> _extractImageFeatures(img.Image image) {
    double totalBrightness = 0;
    double totalColorVariance = 0;
    double edgeCount = 0;
    double textureComplexity = 0;

    List<List<double>> brightnessGrid = [];
    int gridSize = 8; // 8x8 grid for spatial analysis

    // Initialize brightness grid
    for (int i = 0; i < gridSize; i++) {
      brightnessGrid.add(List.filled(gridSize, 0.0));
    }

    int pixelCount = 0;
    List<int> colorHistogram = List.filled(256, 0);

    // Analyze image in patches for better feature extraction
    int stepX = math.max(1, image.width ~/ 50);
    int stepY = math.max(1, image.height ~/ 50);

    for (int y = 0; y < image.height; y += stepY) {
      for (int x = 0; x < image.width; x += stepX) {
        img.Pixel pixel = image.getPixel(x, y);

        // Calculate brightness
        double brightness = (pixel.r + pixel.g + pixel.b) / (3.0 * 255.0);
        totalBrightness += brightness;

        // Update brightness grid for spatial analysis
        int gridX = (x * gridSize) ~/ image.width;
        int gridY = (y * gridSize) ~/ image.height;
        gridX = math.min(gridX, gridSize - 1);
        gridY = math.min(gridY, gridSize - 1);
        brightnessGrid[gridY][gridX] += brightness;

        // Color variance calculation
        double avgColor = (pixel.r + pixel.g + pixel.b) / 3.0;
        double colorVar =
            ((pixel.r - avgColor).abs() +
                (pixel.g - avgColor).abs() +
                (pixel.b - avgColor).abs()) /
            3.0;
        totalColorVariance += colorVar;

        // Simple edge detection (compare with neighboring pixels)
        if (x > 0 && y > 0) {
          img.Pixel leftPixel = image.getPixel(x - stepX, y);
          img.Pixel topPixel = image.getPixel(x, y - stepY);

          double edgeStrength =
              ((pixel.r - leftPixel.r).abs() + (pixel.r - topPixel.r).abs()) /
              2.0;
          if (edgeStrength > 30) edgeCount++;
        }

        // Histogram for texture analysis
        int grayValue = ((pixel.r + pixel.g + pixel.b) / 3).round();
        colorHistogram[math.min(grayValue, 255)]++;

        pixelCount++;
      }
    }

    // Calculate texture complexity from histogram
    for (int i = 1; i < colorHistogram.length; i++) {
      textureComplexity += (colorHistogram[i] - colorHistogram[i - 1]).abs();
    }

    // Calculate spatial distribution variance
    double spatialVariance = 0;
    double avgGridBrightness = totalBrightness / pixelCount;
    for (var row in brightnessGrid) {
      for (var value in row) {
        spatialVariance +=
            (value - avgGridBrightness) * (value - avgGridBrightness);
      }
    }
    spatialVariance /= (gridSize * gridSize);

    return {
      'brightness': totalBrightness / pixelCount,
      'colorVariance': totalColorVariance / (pixelCount * 255.0),
      'edgeDensity': edgeCount / pixelCount,
      'textureComplexity':
          textureComplexity / (colorHistogram.length * pixelCount),
      'spatialDistribution': spatialVariance,
    };
  }

  // Calculate a hash of the image content for deterministic embedding generation
  String _calculateImageHash(img.Image image) {
    // Sample key pixels to create a content-based hash
    List<int> hashData = [];

    int stepX = math.max(1, image.width ~/ 16);
    int stepY = math.max(1, image.height ~/ 16);

    for (int y = 0; y < image.height; y += stepY) {
      for (int x = 0; x < image.width; x += stepX) {
        img.Pixel pixel = image.getPixel(x, y);
        hashData.add(pixel.r.round());
        hashData.add(pixel.g.round());
        hashData.add(pixel.b.round());
      }
    }

    // Create MD5 hash of the pixel data
    var digest = md5.convert(hashData);
    return digest.toString();
  }

  // Get face embedding from image bytes
  Future<List<double>?> getFaceEmbedding(Uint8List imageBytes) async {
    try {
      // Decode image
      img.Image? image = img.decodeImage(imageBytes);
      if (image == null) {
        print('Failed to decode image');
        return null;
      }

      print('Processing image: ${image.width}x${image.height} (Demo Mode)');

      // If service is not loaded, try to load it
      if (!_isModelLoaded) {
        print('Service not loaded, attempting to initialize...');
        await loadModel();
      }

      // Generate sophisticated mock embedding
      print('Generating advanced face embedding from image features...');
      var embedding = _generateAdvancedMockEmbedding(image);
      return _normalizeEmbedding(embedding);
    } catch (e) {
      print('Error getting face embedding: $e');
      return null;
    }
  }

  // Process image from file path
  Future<List<double>?> getFaceEmbeddingFromFile(String imagePath) async {
    try {
      File imageFile = File(imagePath);
      Uint8List imageBytes = await imageFile.readAsBytes();
      return await getFaceEmbedding(imageBytes);
    } catch (e) {
      print('Error reading image file: $e');
      return null;
    }
  }

  // Normalize embedding vector to unit length
  List<double> _normalizeEmbedding(List<double> embedding) {
    double norm = 0.0;
    for (double value in embedding) {
      norm += value * value;
    }
    norm = math.sqrt(norm);

    if (norm == 0.0) {
      print('Warning: Zero norm embedding');
      return embedding;
    }

    return embedding.map((value) => value / norm).toList();
  }

  // Calculate cosine similarity between two embeddings
  double calculateSimilarity(List<double> embedding1, List<double> embedding2) {
    if (embedding1.length != embedding2.length) {
      print(
        'Embedding size mismatch: ${embedding1.length} vs ${embedding2.length}',
      );
      return 0.0;
    }

    double dotProduct = 0.0;
    for (int i = 0; i < embedding1.length; i++) {
      dotProduct += embedding1[i] * embedding2[i];
    }

    // Clamp to [-1, 1] to handle floating point errors
    return math.max(-1.0, math.min(1.0, dotProduct));
  }

  // Calculate Euclidean distance between embeddings
  double calculateDistance(List<double> embedding1, List<double> embedding2) {
    if (embedding1.length != embedding2.length) {
      return double.infinity;
    }

    double distance = 0.0;
    for (int i = 0; i < embedding1.length; i++) {
      double diff = embedding1[i] - embedding2[i];
      distance += diff * diff;
    }

    return math.sqrt(distance);
  }

  // Check if two faces belong to the same person
  bool areSamePerson(
    List<double> embedding1,
    List<double> embedding2, {
    double threshold = 0.6,
  }) {
    double similarity = calculateSimilarity(embedding1, embedding2);
    print(
      'Similarity: ${similarity.toStringAsFixed(4)}, Threshold: $threshold',
    );
    return similarity > threshold;
  }

  // Get face verification result with detailed metrics
  Map<String, dynamic> verifyFaces(
    List<double> embedding1,
    List<double> embedding2, {
    double threshold = 0.6,
  }) {
    double similarity = calculateSimilarity(embedding1, embedding2);
    double distance = calculateDistance(embedding1, embedding2);
    bool match = similarity > threshold;

    return {
      'similarity': similarity,
      'distance': distance,
      'match': match,
      'confidence': similarity,
      'threshold': threshold,
      'mode': 'demo',
    };
  }

  // Dispose resources
  void dispose() {
    _isModelLoaded = false;
    print('Face Recognition Service disposed');
  }
}
