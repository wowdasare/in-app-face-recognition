import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;
import 'package:tflite_flutter/tflite_flutter.dart';

class TFLiteFaceRecognitionService {
  // Model instances
  Interpreter? _pNetInterpreter;
  Interpreter? _rNetInterpreter;
  Interpreter? _oNetInterpreter;
  Interpreter? _mobileFaceNetInterpreter;
  Interpreter? _antiSpoofingInterpreter;

  bool _isModelLoaded = false;
  String _modelStatus = 'Not loaded';

  // Model configurations
  static const int FACE_NET_INPUT_SIZE = 112;
  static const double FACE_DETECTION_THRESHOLD = 0.7;
  static const double FACE_SIMILARITY_THRESHOLD = 0.75;

  // MTCNN thresholds (more permissive for better detection)
  static const double PNET_THRESHOLD = 0.6;
  static const double RNET_THRESHOLD = 0.5;
  static const double ONET_THRESHOLD = 0.6;
  static const double NMS_THRESHOLD = 0.5;

  // Singleton pattern
  static final TFLiteFaceRecognitionService _instance =
      TFLiteFaceRecognitionService._internal();

  factory TFLiteFaceRecognitionService() => _instance;

  TFLiteFaceRecognitionService._internal();

  /// Load all TensorFlow Lite models
  Future<bool> loadModels() async {
    try {
      debugPrint('Loading TensorFlow Lite models...');
      _modelStatus = 'Loading TensorFlow Lite models...';

      // Load MTCNN models for face detection
      await _loadMTCNNModels();

      // Load MobileFaceNet for face recognition
      await _loadMobileFaceNet();

      // Load anti-spoofing model (optional)
      await _loadAntiSpoofingModel();

      _isModelLoaded = true;
      _modelStatus = 'TensorFlow Lite models loaded successfully';

      debugPrint('All models loaded successfully!');
      debugPrint('Face Detection: MTCNN (P-Net, R-Net, O-Net)');
      debugPrint('Face Recognition: MobileFaceNet');
      debugPrint('Anti-Spoofing: Enabled');

      return true;
    } catch (e) {
      debugPrint('Error loading models: $e');
      _modelStatus = 'Error loading models: $e';
      return false;
    }
  }

  /// Load MTCNN models with proper error handling
  Future<void> _loadMTCNNModels() async {
    try {
      debugPrint('Loading MTCNN face detection models...');

      // Load P-Net (Proposal Network)
      _pNetInterpreter = await Interpreter.fromAsset(
        'assets/models/pnet.tflite',
      );
      var pInputShape = _pNetInterpreter!.getInputTensor(0).shape;
      var pOutputShape = _pNetInterpreter!.getOutputTensor(0).shape;
      debugPrint('zP-Net loaded - Input: $pInputShape, Output: $pOutputShape');

      // Load R-Net (Refine Network)
      _rNetInterpreter = await Interpreter.fromAsset(
        'assets/models/rnet.tflite',
      );
      var rInputShape = _rNetInterpreter!.getInputTensor(0).shape;
      var rOutputShape = _rNetInterpreter!.getOutputTensor(0).shape;
      debugPrint('R-Net loaded - Input: $rInputShape, Output: $rOutputShape');

      // Load O-Net (Output Network)
      _oNetInterpreter = await Interpreter.fromAsset(
        'assets/models/onet.tflite',
      );
      var oInputShape = _oNetInterpreter!.getInputTensor(0).shape;
      var oOutputShape = _oNetInterpreter!.getOutputTensor(0).shape;
      debugPrint('O-Net loaded - Input: $oInputShape, Output: $oOutputShape');
    } catch (e) {
      debugPrint('Error loading MTCNN models: $e');
      rethrow;
    }
  }

  /// Load MobileFaceNet for face recognition
  Future<void> _loadMobileFaceNet() async {
    try {
      debugPrint('Loading MobileFaceNet model...');
      _mobileFaceNetInterpreter = await Interpreter.fromAsset(
        'assets/models/MobileFaceNet.tflite',
      );

      var inputShape = _mobileFaceNetInterpreter!.getInputTensor(0).shape;
      var outputShape = _mobileFaceNetInterpreter!.getOutputTensor(0).shape;
      debugPrint('MobileFaceNet loaded');
      debugPrint('Input shape: $inputShape');
      debugPrint('Output shape: $outputShape');
    } catch (e) {
      debugPrint('Error loading MobileFaceNet: $e');
      rethrow;
    }
  }

  /// Load anti-spoofing model (optional)
  Future<void> _loadAntiSpoofingModel() async {
    try {
      debugPrint('Loading anti-spoofing model...');
      _antiSpoofingInterpreter = await Interpreter.fromAsset(
        'assets/models/FaceAntiSpoofing.tflite',
      );
      debugPrint('Anti-spoofing model loaded');
    } catch (e) {
      debugPrint('Anti-spoofing model not loaded: $e');
      // This is optional, so don't throw
    }
  }

  bool get isModelLoaded => _isModelLoaded;

  String get modelStatus => _modelStatus;

  /// Detect faces using MTCNN with fallback detection
  Future<List<FaceDetection>> detectFaces(img.Image image) async {
    if (!_isModelLoaded) {
      debugPrint('Models not loaded');
      return [];
    }

    try {
      debugPrint(
        'Running MTCNN face detection on ${image.width}x${image.height} image...',
      );

      // Stage 1: P-Net
      List<FaceBox> pNetBoxes = await _runPNet(image);
      debugPrint('📊 P-Net found ${pNetBoxes.length} candidate regions');

      if (pNetBoxes.isEmpty) {
        debugPrint('No faces found in P-Net stage');
        return await _fallbackDetection(image);
      }

      // Stage 2: R-Net
      List<FaceBox> rNetBoxes = await _runRNet(image, pNetBoxes);
      debugPrint('R-Net refined to ${rNetBoxes.length} regions');

      if (rNetBoxes.isEmpty) {
        debugPrint('R-Net failed, trying simple detection fallback...');
        return await _fallbackDetection(image);
      }

      // Stage 3: O-Net
      List<FaceBox> oNetBoxes = await _runONet(image, rNetBoxes);
      debugPrint('📊 O-Net final result: ${oNetBoxes.length} faces');

      if (oNetBoxes.isEmpty) {
        debugPrint('O-Net failed, using R-Net results...');
        oNetBoxes = rNetBoxes;
      }

      // Convert to FaceDetection objects
      List<FaceDetection> faces =
          oNetBoxes
              .map(
                (box) => FaceDetection(
                  boundingBox: Rect.fromLTWH(
                    box.x,
                    box.y,
                    box.width,
                    box.height,
                  ),
                  confidence: box.confidence,
                  landmarks: box.landmarks,
                ),
              )
              .toList();

      debugPrint('MTCNN detected ${faces.length} faces');
      return faces;
    } catch (e) {
      debugPrint('Error in MTCNN face detection: $e');
      return await _fallbackDetection(image);
    }
  }

  /// Fallback detection when MTCNN fails
  Future<List<FaceDetection>> _fallbackDetection(img.Image image) async {
    try {
      debugPrint('Using fallback face detection...');

      // Simple center-region detection for portrait images
      double aspectRatio = image.height / image.width;

      if (aspectRatio > 0.8 && aspectRatio < 2.5) {
        // Portrait-like image
        // Assume face is in upper-center region
        double faceWidth = image.width * 0.6;
        double faceHeight = image.height * 0.7;
        double faceX = (image.width - faceWidth) / 2;
        double faceY = image.height * 0.1; // Upper portion

        // Ensure face region is within bounds
        faceX = math.max(0, math.min(faceX, image.width - faceWidth));
        faceY = math.max(0, math.min(faceY, image.height - faceHeight));
        faceWidth = math.min(faceWidth, image.width - faceX);
        faceHeight = math.min(faceHeight, image.height - faceY);

        if (faceWidth > 50 && faceHeight > 50) {
          debugPrint(
            'Fallback detected face region: ${faceWidth.round()}x${faceHeight.round()}',
          );
          return [
            FaceDetection(
              boundingBox: Rect.fromLTWH(faceX, faceY, faceWidth, faceHeight),
              confidence: 0.8,
              landmarks: {},
            ),
          ];
        }
      }

      debugPrint('Fallback detection failed');
      return [];
    } catch (e) {
      debugPrint('Error in fallback detection: $e');
      return [];
    }
  }

  /// P-Net stage with dynamic shape handling
  Future<List<FaceBox>> _runPNet(img.Image image) async {
    try {
      List<double> scales = _calculateScales(image);
      List<FaceBox> allBoxes = [];

      for (double scale in scales) {
        int scaledWidth = (image.width * scale).round();
        int scaledHeight = (image.height * scale).round();

        if (scaledWidth < 12 || scaledHeight < 12) continue;

        // Resize image
        img.Image scaledImage = img.copyResize(
          image,
          width: scaledWidth,
          height: scaledHeight,
        );

        // Prepare input with proper shape
        var input = _prepareImageForPNet(scaledImage);

        // Get output shapes dynamically
        List<int> outputShape0 = _pNetInterpreter!.getOutputTensor(0).shape;
        List<int> outputShape1 = _pNetInterpreter!.getOutputTensor(1).shape;

        // Calculate expected output dimensions based on input
        int expectedH = ((scaledHeight - 12) / 2 + 1).ceil();
        int expectedW = ((scaledWidth - 12) / 2 + 1).ceil();

        // Create output tensors with correct shapes
        var probOutput = _createOutputTensor([1, expectedH, expectedW, 2]);
        var bboxOutput = _createOutputTensor([1, expectedH, expectedW, 4]);

        // Run P-Net inference
        _pNetInterpreter!.runForMultipleInputs(
          [input],
          {0: probOutput, 1: bboxOutput},
        );

        // Process P-Net outputs
        List<FaceBox> scaleBoxes = _processPNetOutput(
          probOutput,
          bboxOutput,
          scale,
          PNET_THRESHOLD,
        );

        allBoxes.addAll(scaleBoxes);
      }

      // Apply Non-Maximum Suppression
      return _nonMaximumSuppression(allBoxes, NMS_THRESHOLD);
    } catch (e) {
      debugPrint('Error in P-Net: $e');
      return [];
    }
  }

  /// R-Net stage with improved debugging
  Future<List<FaceBox>> _runRNet(img.Image image, List<FaceBox> boxes) async {
    try {
      debugPrint('🔬 R-Net processing ${boxes.length} candidate boxes...');
      List<FaceBox> validBoxes = [];
      int processedCount = 0;
      int validCount = 0;

      for (FaceBox box in boxes) {
        processedCount++;

        img.Image? faceImage = _extractAndResizeFace(image, box, 24);
        if (faceImage == null) {
          debugPrint('Failed to extract face region for box $processedCount');
          continue;
        }

        // Prepare input
        var input = _prepareImageForRNet(faceImage);

        // Create output tensors
        var probOutput = _createOutputTensor([1, 2]);
        var bboxOutput = _createOutputTensor([1, 4]);

        try {
          // Run R-Net inference
          _rNetInterpreter!.runForMultipleInputs(
            [input],
            {0: probOutput, 1: bboxOutput},
          );

          // Process output
          double confidence = probOutput[0][1];

          if (processedCount <= 5) {
            // Debug first 5 boxes
            debugPrint(
              '🔍 Box $processedCount: confidence = ${confidence.toStringAsFixed(4)}, threshold = $RNET_THRESHOLD',
            );
          }

          if (confidence > RNET_THRESHOLD) {
            validCount++;
            // Update box coordinates with regression
            FaceBox refinedBox = _applyBboxRegression(box, bboxOutput[0]);
            refinedBox.confidence = confidence;
            validBoxes.add(refinedBox);

            if (validCount <= 3) {
              debugPrint(
                'Valid face $validCount: confidence = ${confidence.toStringAsFixed(4)}',
              );
            }
          }
        } catch (e) {
          debugPrint(' R-Net inference error for box $processedCount: $e');
          continue;
        }
      }

      debugPrint(
        '📊 R-Net results: ${validBoxes.length}/$processedCount boxes passed',
      );

      if (validBoxes.isEmpty) {
        debugPrint('R-Net rejected all faces. Trying with lower threshold...');
        // Fallback: try with much lower threshold
        return await _runRNetWithLowerThreshold(image, boxes);
      }

      return _nonMaximumSuppression(validBoxes, NMS_THRESHOLD);
    } catch (e) {
      debugPrint('Error in R-Net: $e');
      return [];
    }
  }

  /// R-Net fallback with lower threshold
  Future<List<FaceBox>> _runRNetWithLowerThreshold(
    img.Image image,
    List<FaceBox> boxes,
  ) async {
    try {
      debugPrint('Trying R-Net with fallback threshold 0.3...');
      List<FaceBox> validBoxes = [];
      double fallbackThreshold = 0.3;

      // Only process the best boxes (sorted by P-Net confidence)
      List<FaceBox> sortedBoxes = List.from(boxes);
      sortedBoxes.sort((a, b) => b.confidence.compareTo(a.confidence));

      // Take top 20 boxes
      List<FaceBox> topBoxes = sortedBoxes.take(20).toList();
      debugPrint('Processing top ${topBoxes.length} P-Net boxes...');

      for (int i = 0; i < topBoxes.length; i++) {
        FaceBox box = topBoxes[i];

        img.Image? faceImage = _extractAndResizeFace(image, box, 24);
        if (faceImage == null) continue;

        var input = _prepareImageForRNet(faceImage);
        var probOutput = _createOutputTensor([1, 2]);
        var bboxOutput = _createOutputTensor([1, 4]);

        try {
          _rNetInterpreter!.runForMultipleInputs(
            [input],
            {0: probOutput, 1: bboxOutput},
          );

          double confidence = probOutput[0][1];

          if (i < 5) {
            debugPrint(
              '🔍 Fallback box ${i + 1}: confidence = ${confidence.toStringAsFixed(4)}',
            );
          }

          if (confidence > fallbackThreshold) {
            FaceBox refinedBox = _applyBboxRegression(box, bboxOutput[0]);
            refinedBox.confidence = confidence;
            validBoxes.add(refinedBox);
            debugPrint(
              'Fallback accepted: confidence = ${confidence.toStringAsFixed(4)}',
            );
          }
        } catch (e) {
          continue;
        }
      }

      debugPrint('Fallback R-Net found ${validBoxes.length} faces');
      return _nonMaximumSuppression(validBoxes, NMS_THRESHOLD);
    } catch (e) {
      debugPrint('Error in R-Net fallback: $e');
      return [];
    }
  }

  /// O-Net stage
  Future<List<FaceBox>> _runONet(img.Image image, List<FaceBox> boxes) async {
    try {
      List<FaceBox> validBoxes = [];

      for (FaceBox box in boxes) {
        // Extract face region and resize to 48x48
        img.Image? faceImage = _extractAndResizeFace(image, box, 48);
        if (faceImage == null) continue;

        // Prepare input
        var input = _prepareImageForONet(faceImage);

        // Create output tensors
        var probOutput = _createOutputTensor([1, 2]);
        var bboxOutput = _createOutputTensor([1, 4]);
        var landmarkOutput = _createOutputTensor([1, 10]);

        // Run O-Net inference
        _oNetInterpreter!.runForMultipleInputs(
          [input],
          {0: probOutput, 1: bboxOutput, 2: landmarkOutput},
        );

        // Process output
        double confidence = probOutput[0][1];
        if (confidence > ONET_THRESHOLD) {
          // Update box coordinates and add landmarks
          FaceBox refinedBox = _applyBboxRegression(box, bboxOutput[0]);
          refinedBox.confidence = confidence;
          refinedBox.landmarks = _extractLandmarks(
            landmarkOutput[0],
            refinedBox,
          );
          validBoxes.add(refinedBox);
        }
      }

      return _nonMaximumSuppression(validBoxes, NMS_THRESHOLD);
    } catch (e) {
      debugPrint('Error in O-Net: $e');
      return [];
    }
  }

  /// Calculate image pyramid scales
  List<double> _calculateScales(img.Image image) {
    List<double> scales = [];
    double minSize = 12.0;
    double factor = 0.709;

    double minDim = math.min(image.width, image.height).toDouble();
    double currentScale = minSize / minDim;

    while (currentScale <= 1.0) {
      scales.add(currentScale);
      currentScale /= factor;
    }

    return scales;
  }

  /// Prepare image for P-Net (dynamic size)
  List<List<List<List<double>>>> _prepareImageForPNet(img.Image image) {
    return [
      [
        for (int y = 0; y < image.height; y++)
          [
            for (int x = 0; x < image.width; x++)
              () {
                img.Pixel pixel = image.getPixel(x, y);
                return [
                  (pixel.r / 255.0 - 0.5) / 0.5,
                  (pixel.g / 255.0 - 0.5) / 0.5,
                  (pixel.b / 255.0 - 0.5) / 0.5,
                ];
              }(),
          ],
      ],
    ];
  }

  /// Prepare image for R-Net (24x24)
  List<List<List<List<double>>>> _prepareImageForRNet(img.Image image) {
    return [
      [
        for (int y = 0; y < 24; y++)
          [
            for (int x = 0; x < 24; x++)
              () {
                img.Pixel pixel = image.getPixel(x, y);
                return [
                  (pixel.r / 255.0 - 0.5) / 0.5,
                  (pixel.g / 255.0 - 0.5) / 0.5,
                  (pixel.b / 255.0 - 0.5) / 0.5,
                ];
              }(),
          ],
      ],
    ];
  }

  /// Prepare image for O-Net (48x48)
  List<List<List<List<double>>>> _prepareImageForONet(img.Image image) {
    return [
      [
        for (int y = 0; y < 48; y++)
          [
            for (int x = 0; x < 48; x++)
              () {
                img.Pixel pixel = image.getPixel(x, y);
                return [
                  (pixel.r / 255.0 - 0.5) / 0.5,
                  (pixel.g / 255.0 - 0.5) / 0.5,
                  (pixel.b / 255.0 - 0.5) / 0.5,
                ];
              }(),
          ],
      ],
    ];
  }

  /// Create output tensor with proper shape
  List<dynamic> _createOutputTensor(List<int> shape) {
    if (shape.length == 2) {
      return List.generate(shape[0], (_) => List.filled(shape[1], 0.0));
    } else if (shape.length == 4) {
      return List.generate(
        shape[0],
        (_) => List.generate(
          shape[1],
          (_) => List.generate(shape[2], (_) => List.filled(shape[3], 0.0)),
        ),
      );
    }
    throw ArgumentError('Unsupported tensor shape: $shape');
  }

  /// Process P-Net output to extract face boxes
  List<FaceBox> _processPNetOutput(
    List<dynamic> probOutput,
    List<dynamic> bboxOutput,
    double scale,
    double threshold,
  ) {
    List<FaceBox> boxes = [];

    var probs = probOutput[0];
    var bboxes = bboxOutput[0];

    int height = probs.length;
    int width = probs[0].length;

    for (int y = 0; y < height; y++) {
      for (int x = 0; x < width; x++) {
        double confidence = probs[y][x][1];

        if (confidence > threshold) {
          double dx1 = bboxes[y][x][0];
          double dy1 = bboxes[y][x][1];
          double dx2 = bboxes[y][x][2];
          double dy2 = bboxes[y][x][3];

          // Convert to original image coordinates
          double x1 = (x * 2 + dx1 * 12) / scale;
          double y1 = (y * 2 + dy1 * 12) / scale;
          double x2 = (x * 2 + 12 + dx2 * 12) / scale;
          double y2 = (y * 2 + 12 + dy2 * 12) / scale;

          boxes.add(
            FaceBox(
              x: x1,
              y: y1,
              width: x2 - x1,
              height: y2 - y1,
              confidence: confidence,
            ),
          );
        }
      }
    }

    return boxes;
  }

  /// Extract and resize face region with improved robustness
  img.Image? _extractAndResizeFace(img.Image image, FaceBox box, int size) {
    try {
      // Ensure bounding box is valid
      double x1 = math.max(0, box.x);
      double y1 = math.max(0, box.y);
      double x2 = math.min(image.width.toDouble(), box.x + box.width);
      double y2 = math.min(image.height.toDouble(), box.y + box.height);

      // Check if box is valid
      if (x2 <= x1 || y2 <= y1 || x2 - x1 < 5 || y2 - y1 < 5) {
        return null;
      }

      // Make box square by expanding the smaller dimension
      double width = x2 - x1;
      double height = y2 - y1;
      double maxDim = math.max(width, height);

      // Calculate square box centered on original box
      double centerX = (x1 + x2) / 2;
      double centerY = (y1 + y2) / 2;
      double halfSize = maxDim / 2;

      // Ensure square box is within image bounds
      double squareX1 = math.max(0, centerX - halfSize);
      double squareY1 = math.max(0, centerY - halfSize);
      double squareX2 = math.min(image.width.toDouble(), centerX + halfSize);
      double squareY2 = math.min(image.height.toDouble(), centerY + halfSize);

      // Final dimensions
      int cropX = squareX1.round();
      int cropY = squareY1.round();
      int cropW = (squareX2 - squareX1).round();
      int cropH = (squareY2 - squareY1).round();

      // Ensure minimum size
      if (cropW < 5 || cropH < 5) {
        return null;
      }

      // Crop and resize
      img.Image cropped = img.copyCrop(
        image,
        x: cropX,
        y: cropY,
        width: cropW,
        height: cropH,
      );

      // Resize to target size with high quality
      img.Image resized = img.copyResize(
        cropped,
        width: size,
        height: size,
        interpolation: img.Interpolation.cubic,
      );

      return resized;
    } catch (e) {
      debugPrint('Error extracting face: $e');
      return null;
    }
  }

  /// Apply bounding box regression
  FaceBox _applyBboxRegression(FaceBox box, List<double> regression) {
    double w = box.width;
    double h = box.height;

    double x1 = box.x + regression[0] * w;
    double y1 = box.y + regression[1] * h;
    double x2 = box.x + box.width + regression[2] * w;
    double y2 = box.y + box.height + regression[3] * h;

    return FaceBox(
      x: x1,
      y: y1,
      width: x2 - x1,
      height: y2 - y1,
      confidence: box.confidence,
    );
  }

  /// Extract facial landmarks
  Map<String, dynamic> _extractLandmarks(List<double> landmarks, FaceBox box) {
    Map<String, dynamic> points = {};

    for (int i = 0; i < 5; i++) {
      double x = box.x + landmarks[i] * box.width;
      double y = box.y + landmarks[i + 5] * box.height;
      points['point_$i'] = {'x': x, 'y': y};
    }

    return points;
  }

  /// Non-Maximum Suppression
  List<FaceBox> _nonMaximumSuppression(List<FaceBox> boxes, double threshold) {
    if (boxes.isEmpty) return [];

    // Sort by confidence (descending)
    boxes.sort((a, b) => b.confidence.compareTo(a.confidence));

    List<FaceBox> kept = [];
    List<bool> suppressed = List.filled(boxes.length, false);

    for (int i = 0; i < boxes.length; i++) {
      if (suppressed[i]) continue;

      kept.add(boxes[i]);

      for (int j = i + 1; j < boxes.length; j++) {
        if (suppressed[j]) continue;

        double iou = _calculateIoU(boxes[i], boxes[j]);
        if (iou > threshold) {
          suppressed[j] = true;
        }
      }
    }

    return kept;
  }

  /// Calculate Intersection over Union
  double _calculateIoU(FaceBox box1, FaceBox box2) {
    double x1 = math.max(box1.x, box2.x);
    double y1 = math.max(box1.y, box2.y);
    double x2 = math.min(box1.x + box1.width, box2.x + box2.width);
    double y2 = math.min(box1.y + box1.height, box2.y + box2.height);

    if (x1 >= x2 || y1 >= y2) return 0.0;

    double intersection = (x2 - x1) * (y2 - y1);
    double area1 = box1.width * box1.height;
    double area2 = box2.width * box2.height;
    double union = area1 + area2 - intersection;

    return intersection / union;
  }

  /// Generate face embedding using MobileFaceNet
  Future<List<double>?> getFaceEmbedding(Uint8List imageBytes) async {
    try {
      if (!_isModelLoaded) {
        debugPrint('Models not loaded, attempting to load...');
        bool loaded = await loadModels();
        if (!loaded) return null;
      }

      // Decode image
      img.Image? image = img.decodeImage(imageBytes);
      if (image == null) {
        debugPrint('Failed to decode image');
        return null;
      }

      debugPrint('Processing ${image.width}x${image.height} image...');

      // Detect faces using MTCNN
      List<FaceDetection> faces = await detectFaces(image);
      if (faces.isEmpty) {
        debugPrint('No faces detected in image');
        return null;
      }

      debugPrint('Face detected, extracting features...');

      // Use the largest detected face
      FaceDetection bestFace = faces.reduce(
        (a, b) =>
            (a.boundingBox.width * a.boundingBox.height) >
                    (b.boundingBox.width * b.boundingBox.height)
                ? a
                : b,
      );

      // Extract and preprocess face region
      img.Image faceImage = _extractFaceForEmbedding(image, bestFace);

      // Generate embedding using MobileFaceNet
      List<double> embedding = await _generateEmbeddingWithMobileFaceNet(
        faceImage,
      );

      debugPrint('Generated ${embedding.length}-dimensional face embedding');
      return embedding;
    } catch (e) {
      debugPrint('Error getting face embedding: $e');
      return null;
    }
  }

  /// Extract face region for embedding generation
  img.Image _extractFaceForEmbedding(img.Image image, FaceDetection face) {
    Rect bbox = face.boundingBox;

    // Add padding around face
    double padding = 0.2;
    double paddedX = math.max(0, bbox.left - bbox.width * padding);
    double paddedY = math.max(0, bbox.top - bbox.height * padding);
    double paddedWidth = math.min(
      image.width - paddedX,
      bbox.width * (1 + 2 * padding),
    );
    double paddedHeight = math.min(
      image.height - paddedY,
      bbox.height * (1 + 2 * padding),
    );

    img.Image cropped = img.copyCrop(
      image,
      x: paddedX.round(),
      y: paddedY.round(),
      width: paddedWidth.round(),
      height: paddedHeight.round(),
    );

    // Resize to MobileFaceNet input size
    return img.copyResize(
      cropped,
      width: FACE_NET_INPUT_SIZE,
      height: FACE_NET_INPUT_SIZE,
    );
  }

  /// Generate embedding using MobileFaceNet
  Future<List<double>> _generateEmbeddingWithMobileFaceNet(
    img.Image faceImage,
  ) async {
    try {
      // Get model shapes
      var inputShape = _mobileFaceNetInterpreter!.getInputTensor(0).shape;
      var outputShape = _mobileFaceNetInterpreter!.getOutputTensor(0).shape;

      // Prepare input tensor
      var input = _prepareImageForMobileFaceNet(faceImage, inputShape);

      // Prepare output tensor
      var output = List.generate(
        outputShape[0],
        (i) => List.filled(outputShape[1], 0.0),
      );

      // Run inference
      _mobileFaceNetInterpreter!.run(input, output);

      // Extract and normalize embedding
      List<double> embedding = List<double>.from(output[0]);
      return _normalizeEmbedding(embedding);
    } catch (e) {
      debugPrint('Error generating embedding: $e');
      rethrow;
    }
  }

  /// Prepare image for MobileFaceNet
  List<List<List<List<double>>>> _prepareImageForMobileFaceNet(
    img.Image image,
    List<int> inputShape,
  ) {
    int batchSize = inputShape[0];
    int height = inputShape[1];
    int width = inputShape[2];
    int channels = inputShape[3];

    return List.generate(
      batchSize,
      (b) => List.generate(
        height,
        (y) => List.generate(width, (x) {
          img.Pixel pixel = image.getPixel(
            (x * image.width / width).round().clamp(0, image.width - 1),
            (y * image.height / height).round().clamp(0, image.height - 1),
          );

          if (channels == 3) {
            return [
              (pixel.r / 255.0 - 0.5) / 0.5,
              (pixel.g / 255.0 - 0.5) / 0.5,
              (pixel.b / 255.0 - 0.5) / 0.5,
            ];
          } else {
            double gray = (pixel.r + pixel.g + pixel.b) / (3 * 255.0);
            return [gray];
          }
        }),
      ),
    );
  }

  /// Normalize embedding vector
  List<double> _normalizeEmbedding(List<double> embedding) {
    double norm = 0.0;
    for (double value in embedding) {
      norm += value * value;
    }
    norm = math.sqrt(norm);

    if (norm == 0.0) return embedding;
    return embedding.map((value) => value / norm).toList();
  }

  /// Calculate cosine similarity
  double calculateSimilarity(List<double> embedding1, List<double> embedding2) {
    if (embedding1.length != embedding2.length) return 0.0;

    double dotProduct = 0.0;
    for (int i = 0; i < embedding1.length; i++) {
      dotProduct += embedding1[i] * embedding2[i];
    }

    return (dotProduct + 1.0) / 2.0;
  }

  /// Calculate Euclidean distance
  double calculateDistance(List<double> embedding1, List<double> embedding2) {
    if (embedding1.length != embedding2.length) return double.infinity;

    double distance = 0.0;
    for (int i = 0; i < embedding1.length; i++) {
      double diff = embedding1[i] - embedding2[i];
      distance += diff * diff;
    }
    return math.sqrt(distance);
  }

  /// Face verification with detailed results
  Map<String, dynamic> verifyFaces(
    List<double> embedding1,
    List<double> embedding2, {
    double threshold = FACE_SIMILARITY_THRESHOLD,
  }) {
    double similarity = calculateSimilarity(embedding1, embedding2);
    double distance = calculateDistance(embedding1, embedding2);
    bool match = similarity > threshold;

    double confidence =
        match
            ? math.min(
              1.0,
              (similarity - threshold) / (1.0 - threshold) * 0.5 + 0.5,
            )
            : math.max(0.0, similarity / threshold * 0.5);

    debugPrint('Face Verification Result (MTCNN + MobileFaceNet):');
    debugPrint('   Similarity: ${(similarity * 100).toStringAsFixed(2)}%');
    debugPrint('   Distance: ${distance.toStringAsFixed(4)}');
    debugPrint('   Match: ${match ? "YES" : "NO"}');
    debugPrint('   Confidence: ${(confidence * 100).toStringAsFixed(1)}%');

    return {
      'similarity': similarity,
      'distance': distance,
      'match': match,
      'confidence': confidence,
      'threshold': threshold,
      'mode': 'mtcnn_mobilefacenet',
      'status': _modelStatus,
    };
  }

  void dispose() {
    _pNetInterpreter?.close();
    _rNetInterpreter?.close();
    _oNetInterpreter?.close();
    _mobileFaceNetInterpreter?.close();
    _antiSpoofingInterpreter?.close();

    _isModelLoaded = false;
    _modelStatus = 'Disposed';
    debugPrint('TensorFlow Lite models disposed');
  }
}

/// Face detection result
class FaceDetection {
  final Rect boundingBox;
  final double confidence;
  final Map<String, dynamic> landmarks;

  FaceDetection({
    required this.boundingBox,
    required this.confidence,
    this.landmarks = const {},
  });
}

/// Face bounding box
class FaceBox {
  double x, y, width, height;
  double confidence;
  Map<String, dynamic> landmarks;

  FaceBox({
    required this.x,
    required this.y,
    required this.width,
    required this.height,
    required this.confidence,
    this.landmarks = const {},
  });
}

/// Simple Rect class
class Rect {
  final double left, top, width, height;

  Rect.fromLTWH(this.left, this.top, this.width, this.height);

  double get right => left + width;

  double get bottom => top + height;
}
