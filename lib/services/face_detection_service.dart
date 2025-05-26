import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:image/image.dart' as img;

/// Represents a detected face with bounding box and confidence
class FaceBox {
  final double x, y, width, height;
  final double confidence;
  final Map<String, dynamic> landmarks;

  FaceBox({
    required this.x,
    required this.y,
    required this.width,
    required this.height,
    required this.confidence,
    this.landmarks = const {},
  });

  /// Get center point of the face
  Offset get center => Offset(x + width / 2, y + height / 2);

  /// Get area of the face bounding box
  double get area => width * height;

  /// Check if this face overlaps with another face (for non-maximum suppression)
  double overlapWith(FaceBox other) {
    double left = math.max(x, other.x);
    double top = math.max(y, other.y);
    double right = math.min(x + width, other.x + other.width);
    double bottom = math.min(y + height, other.y + other.height);

    if (left < right && top < bottom) {
      double overlapArea = (right - left) * (bottom - top);
      double unionArea = area + other.area - overlapArea;
      return overlapArea / unionArea;
    }
    return 0.0;
  }

  @override
  String toString() {
    return 'FaceBox(x: ${x.toStringAsFixed(1)}, y: ${y.toStringAsFixed(1)}, '
        'w: ${width.toStringAsFixed(1)}, h: ${height.toStringAsFixed(1)}, '
        'confidence: ${confidence.toStringAsFixed(3)})';
  }
}

/// Advanced face detection service using image processing techniques
class FaceDetectionService {
  bool _isInitialized = false;

  // Detection parameters
  static const double MIN_FACE_SIZE = 20.0;
  static const double MAX_FACE_SIZE = 500.0;
  static const double CONFIDENCE_THRESHOLD = 0.5;
  static const double NMS_THRESHOLD = 0.3; // Non-maximum suppression threshold

  // Singleton pattern
  static final FaceDetectionService _instance =
      FaceDetectionService._internal();

  factory FaceDetectionService() => _instance;

  FaceDetectionService._internal();

  /// Initialize the face detection service
  Future<bool> initialize() async {
    try {
      print('Initializing Face Detection Service...');

      // Simulate initialization delay
      await Future.delayed(const Duration(milliseconds: 300));

      _isInitialized = true;
      print('Face Detection Service initialized successfully');
      print('Using advanced image processing algorithms');
      print(
        'Features: Multi-scale detection, skin color analysis, facial pattern recognition',
      );

      return true;
    } catch (e) {
      print('Failed to initialize face detection service: $e');
      return false;
    }
  }

  bool get isInitialized => _isInitialized;

  /// Detect faces in image bytes
  Future<List<FaceBox>> detectFaces(Uint8List imageBytes) async {
    try {
      if (!_isInitialized) {
        await initialize();
      }

      // Decode image
      img.Image? image = img.decodeImage(imageBytes);
      if (image == null) {
        print('Failed to decode image for face detection');
        return [];
      }

      print('Detecting faces in ${image.width}x${image.height} image...');

      return await _detectFacesInImage(image);
    } catch (e) {
      print('Error during face detection: $e');
      return [];
    }
  }

  /// Detect faces from file path
  Future<List<FaceBox>> detectFacesFromFile(String imagePath) async {
    try {
      File imageFile = File(imagePath);
      Uint8List imageBytes = await imageFile.readAsBytes();
      return await detectFaces(imageBytes);
    } catch (e) {
      print('Error reading image file for face detection: $e');
      return [];
    }
  }

  /// Main face detection algorithm
  Future<List<FaceBox>> _detectFacesInImage(img.Image image) async {
    List<FaceBox> candidates = [];

    // Multi-scale detection
    List<double> scales = [0.5, 0.75, 1.0, 1.25, 1.5];

    for (double scale in scales) {
      int scaledWidth = (image.width * scale).round();
      int scaledHeight = (image.height * scale).round();

      if (scaledWidth < 50 || scaledHeight < 50) continue;

      // Resize image for this scale
      img.Image scaledImage = img.copyResize(
        image,
        width: scaledWidth,
        height: scaledHeight,
      );

      // Detect faces at this scale
      var scaleCandidates = await _detectAtScale(scaledImage, scale);
      candidates.addAll(scaleCandidates);
    }

    // Apply non-maximum suppression to remove overlapping detections
    List<FaceBox> finalFaces = _applyNonMaximumSuppression(candidates);

    print('Detected ${finalFaces.length} faces');
    return finalFaces;
  }

  /// Detect faces at a specific scale
  Future<List<FaceBox>> _detectAtScale(
    img.Image scaledImage,
    double scale,
  ) async {
    List<FaceBox> faces = [];

    // Convert to grayscale for processing
    img.Image grayImage = img.grayscale(scaledImage);

    // Calculate integral image for faster window-based calculations
    List<List<int>> integralImage = _calculateIntegralImage(grayImage);

    // Sliding window detection
    int windowSize = 24; // Base window size
    int step = math.max(4, windowSize ~/ 6);

    for (int y = 0; y + windowSize < grayImage.height; y += step) {
      for (int x = 0; x + windowSize < grayImage.width; x += step) {
        // Extract features from current window
        var features = _extractHaarLikeFeatures(
          integralImage,
          x,
          y,
          windowSize,
        );

        // Classify as face or non-face
        double confidence = _classifyWindow(
          features,
          grayImage,
          x,
          y,
          windowSize,
        );

        if (confidence > CONFIDENCE_THRESHOLD) {
          // Additional verification with skin color and facial patterns
          double skinConfidence = _verifySkinColor(
            scaledImage,
            x,
            y,
            windowSize,
          );
          double patternConfidence = _verifyFacialPatterns(
            grayImage,
            x,
            y,
            windowSize,
          );

          // Combined confidence score
          double finalConfidence =
              (confidence * 0.5 +
                  skinConfidence * 0.3 +
                  patternConfidence * 0.2);

          if (finalConfidence > CONFIDENCE_THRESHOLD) {
            // Scale coordinates back to original image size
            double originalX = x / scale;
            double originalY = y / scale;
            double originalWidth = windowSize / scale;
            double originalHeight = windowSize / scale;

            faces.add(
              FaceBox(
                x: originalX,
                y: originalY,
                width: originalWidth,
                height: originalHeight,
                confidence: finalConfidence,
              ),
            );
          }
        }
      }
    }

    return faces;
  }

  /// Calculate integral image for fast rectangle sum calculations
  List<List<int>> _calculateIntegralImage(img.Image grayImage) {
    int width = grayImage.width;
    int height = grayImage.height;

    List<List<int>> integral = List.generate(
      height + 1,
      (i) => List.filled(width + 1, 0),
    );

    for (int y = 1; y <= height; y++) {
      for (int x = 1; x <= width; x++) {
        img.Pixel pixel = grayImage.getPixel(x - 1, y - 1);
        int intensity = pixel.r.round(); // Grayscale value

        integral[y][x] =
            intensity +
            integral[y - 1][x] +
            integral[y][x - 1] -
            integral[y - 1][x - 1];
      }
    }

    return integral;
  }

  /// Extract Haar-like features from integral image
  Map<String, double> _extractHaarLikeFeatures(
    List<List<int>> integralImage,
    int x,
    int y,
    int size,
  ) {
    Map<String, double> features = {};

    // Feature 1: Eye region (darker) vs cheek region (lighter)
    int eyeRegionSum = _getRectangleSum(
      integralImage,
      x + size ~/ 4,
      y + size ~/ 4,
      size ~/ 2,
      size ~/ 4,
    );
    int cheekRegionSum = _getRectangleSum(
      integralImage,
      x + size ~/ 4,
      y + size * 3 ~/ 4,
      size ~/ 2,
      size ~/ 4,
    );
    features['eye_cheek_contrast'] = (cheekRegionSum - eyeRegionSum).toDouble();

    // Feature 2: Nose bridge (lighter) vs eye region (darker)
    int noseBridgeSum = _getRectangleSum(
      integralImage,
      x + size * 2 ~/ 5,
      y + size * 2 ~/ 5,
      size ~/ 5,
      size ~/ 3,
    );
    features['nose_eye_contrast'] = (noseBridgeSum - eyeRegionSum).toDouble();

    // Feature 3: Mouth region vs surrounding area
    int mouthSum = _getRectangleSum(
      integralImage,
      x + size ~/ 3,
      y + size * 2 ~/ 3,
      size ~/ 3,
      size ~/ 6,
    );
    int surroundingSum = _getRectangleSum(
      integralImage,
      x + size ~/ 4,
      y + size * 3 ~/ 4,
      size ~/ 2,
      size ~/ 8,
    );
    features['mouth_contrast'] = (surroundingSum - mouthSum).toDouble();

    // Feature 4: Vertical symmetry
    int leftHalfSum = _getRectangleSum(integralImage, x, y, size ~/ 2, size);
    int rightHalfSum = _getRectangleSum(
      integralImage,
      x + size ~/ 2,
      y,
      size ~/ 2,
      size,
    );
    features['vertical_symmetry'] =
        1.0 -
        (leftHalfSum - rightHalfSum).abs() /
            math.max(leftHalfSum, rightHalfSum);

    // Feature 5: Forehead vs lower face
    int foreheadSum = _getRectangleSum(integralImage, x, y, size, size ~/ 3);
    int lowerFaceSum = _getRectangleSum(
      integralImage,
      x,
      y + size * 2 ~/ 3,
      size,
      size ~/ 3,
    );
    features['forehead_contrast'] = (foreheadSum - lowerFaceSum).toDouble();

    return features;
  }

  /// Get sum of pixels in rectangle using integral image
  int _getRectangleSum(
    List<List<int>> integralImage,
    int x,
    int y,
    int width,
    int height,
  ) {
    if (x < 0 ||
        y < 0 ||
        x + width >= integralImage[0].length ||
        y + height >= integralImage.length) {
      return 0;
    }

    return integralImage[y + height][x + width] -
        integralImage[y][x + width] -
        integralImage[y + height][x] +
        integralImage[y][x];
  }

  /// Classify window as face or non-face based on features
  double _classifyWindow(
    Map<String, double> features,
    img.Image grayImage,
    int x,
    int y,
    int size,
  ) {
    double score = 0.0;
    int validFeatures = 0;

    // Check eye-cheek contrast (eyes should be darker than cheeks)
    if (features['eye_cheek_contrast']! > 0) {
      score += 0.3;
    }
    validFeatures++;

    // Check nose-eye contrast
    if (features['nose_eye_contrast']! > 0) {
      score += 0.2;
    }
    validFeatures++;

    // Check vertical symmetry (faces should be somewhat symmetric)
    if (features['vertical_symmetry']! > 0.7) {
      score += 0.25;
    }
    validFeatures++;

    // Check forehead contrast
    if (features['forehead_contrast']! > 0) {
      score += 0.15;
    }
    validFeatures++;

    // Additional checks for face-like proportions
    double aspectRatio = 1.0; // Assuming square window, but could be adjusted
    if (aspectRatio > 0.8 && aspectRatio < 1.3) {
      score += 0.1;
    }

    return score;
  }

  /// Verify skin color in the detected region
  double _verifySkinColor(img.Image colorImage, int x, int y, int size) {
    int skinPixels = 0;
    int totalPixels = 0;

    // Sample pixels in the face region
    int step = math.max(1, size ~/ 8);

    for (int dy = 0; dy < size; dy += step) {
      for (int dx = 0; dx < size; dx += step) {
        if (x + dx < colorImage.width && y + dy < colorImage.height) {
          img.Pixel pixel = colorImage.getPixel(x + dx, y + dy);

          if (_isSkinColor(pixel.r, pixel.g, pixel.b)) {
            skinPixels++;
          }
          totalPixels++;
        }
      }
    }

    return totalPixels > 0 ? skinPixels / totalPixels : 0.0;
  }

  /// Check if RGB values represent skin color
  bool _isSkinColor(num r, num g, num b) {
    // Simple skin color detection in RGB space
    // These ranges work for various skin tones
    return (r > 95 && g > 40 && b > 20) &&
        (r > g && r > b) &&
        (r - g > 15) &&
        (r.abs() - b.abs() > 15);
  }

  /// Verify facial patterns (eye and mouth regions)
  double _verifyFacialPatterns(img.Image grayImage, int x, int y, int size) {
    double patternScore = 0.0;

    // Check for eye-like patterns (dark horizontal regions in upper third)
    int eyeY = y + size ~/ 4;
    int eyeHeight = size ~/ 8;

    // Left eye region
    int leftEyeX = x + size ~/ 4;
    int leftEyeWidth = size ~/ 6;
    double leftEyeDarkness = _calculateRegionDarkness(
      grayImage,
      leftEyeX,
      eyeY,
      leftEyeWidth,
      eyeHeight,
    );

    // Right eye region
    int rightEyeX = x + size * 2 ~/ 3;
    int rightEyeWidth = size ~/ 6;
    double rightEyeDarkness = _calculateRegionDarkness(
      grayImage,
      rightEyeX,
      eyeY,
      rightEyeWidth,
      eyeHeight,
    );

    // Eyes should be darker than average
    if (leftEyeDarkness < 0.6 && rightEyeDarkness < 0.6) {
      patternScore += 0.4;
    }

    // Check for mouth-like pattern (horizontal dark region in lower third)
    int mouthY = y + size * 2 ~/ 3;
    int mouthX = x + size ~/ 3;
    int mouthWidth = size ~/ 3;
    int mouthHeight = size ~/ 10;

    double mouthDarkness = _calculateRegionDarkness(
      grayImage,
      mouthX,
      mouthY,
      mouthWidth,
      mouthHeight,
    );

    if (mouthDarkness < 0.7) {
      patternScore += 0.3;
    }

    // Check for nose region (lighter vertical region in center)
    int noseX = x + size * 2 ~/ 5;
    int noseY = y + size * 2 ~/ 5;
    int noseWidth = size ~/ 5;
    int noseHeight = size ~/ 3;

    double noseBrightness = _calculateRegionBrightness(
      grayImage,
      noseX,
      noseY,
      noseWidth,
      noseHeight,
    );

    if (noseBrightness > 0.4) {
      patternScore += 0.3;
    }

    return patternScore;
  }

  /// Calculate average darkness (0=white, 1=black) of a region
  double _calculateRegionDarkness(
    img.Image grayImage,
    int x,
    int y,
    int width,
    int height,
  ) {
    if (x < 0 ||
        y < 0 ||
        x + width > grayImage.width ||
        y + height > grayImage.height) {
      return 0.5; // Neutral value for out-of-bounds
    }

    double totalIntensity = 0;
    int pixelCount = 0;

    for (int dy = 0; dy < height; dy++) {
      for (int dx = 0; dx < width; dx++) {
        img.Pixel pixel = grayImage.getPixel(x + dx, y + dy);
        totalIntensity += pixel.r; // In grayscale, r=g=b
        pixelCount++;
      }
    }

    double averageIntensity = totalIntensity / pixelCount;
    return 1.0 - (averageIntensity / 255.0); // Convert to darkness (0-1)
  }

  /// Calculate average brightness (0=black, 1=white) of a region
  double _calculateRegionBrightness(
    img.Image grayImage,
    int x,
    int y,
    int width,
    int height,
  ) {
    return 1.0 - _calculateRegionDarkness(grayImage, x, y, width, height);
  }

  /// Apply non-maximum suppression to remove overlapping detections
  List<FaceBox> _applyNonMaximumSuppression(List<FaceBox> faces) {
    if (faces.isEmpty) return faces;

    // Sort by confidence (highest first)
    faces.sort((a, b) => b.confidence.compareTo(a.confidence));

    List<FaceBox> finalFaces = [];
    List<bool> suppressed = List.filled(faces.length, false);

    for (int i = 0; i < faces.length; i++) {
      if (suppressed[i]) continue;

      finalFaces.add(faces[i]);

      // Suppress overlapping faces with lower confidence
      for (int j = i + 1; j < faces.length; j++) {
        if (!suppressed[j]) {
          double overlap = faces[i].overlapWith(faces[j]);
          if (overlap > NMS_THRESHOLD) {
            suppressed[j] = true;
          }
        }
      }
    }

    return finalFaces;
  }

  /// Get the largest detected face (most likely to be the primary subject)
  FaceBox? getLargestFace(List<FaceBox> faces) {
    if (faces.isEmpty) return null;

    FaceBox largest = faces.first;
    for (var face in faces) {
      if (face.area > largest.area) {
        largest = face;
      }
    }
    return largest;
  }

  /// Get the most confident face detection
  FaceBox? getMostConfidentFace(List<FaceBox> faces) {
    if (faces.isEmpty) return null;

    FaceBox mostConfident = faces.first;
    for (var face in faces) {
      if (face.confidence > mostConfident.confidence) {
        mostConfident = face;
      }
    }
    return mostConfident;
  }

  /// Extract face region from image
  img.Image? extractFaceRegion(
    img.Image sourceImage,
    FaceBox faceBox, {
    double padding = 0.2,
  }) {
    try {
      // Add padding around the face
      double paddedX = math.max(0, faceBox.x - faceBox.width * padding);
      double paddedY = math.max(0, faceBox.y - faceBox.height * padding);
      double paddedWidth = math.min(
        sourceImage.width - paddedX,
        faceBox.width * (1 + 2 * padding),
      );
      double paddedHeight = math.min(
        sourceImage.height - paddedY,
        faceBox.height * (1 + 2 * padding),
      );

      return img.copyCrop(
        sourceImage,
        x: paddedX.round(),
        y: paddedY.round(),
        width: paddedWidth.round(),
        height: paddedHeight.round(),
      );
    } catch (e) {
      print('Error extracting face region: $e');
      return null;
    }
  }

  /// Dispose resources
  void dispose() {
    _isInitialized = false;
    print('Face Detection Service disposed');
  }
}
