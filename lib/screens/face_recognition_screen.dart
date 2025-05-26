import 'dart:io';
import 'dart:typed_data';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:in_app_face_recognition/services/face_recognition_service.dart';
import 'package:in_app_face_recognition/widgets/camera_preview.dart';
import 'package:in_app_face_recognition/widgets/comparison_widget.dart'
    show ComparisonResultWidget;
import 'package:permission_handler/permission_handler.dart';

class FaceRecognitionScreen extends StatefulWidget {
  final List<CameraDescription> cameras;

  const FaceRecognitionScreen({super.key, required this.cameras});

  @override
  State<FaceRecognitionScreen> createState() => _FaceRecognitionScreenState();
}

class _FaceRecognitionScreenState extends State<FaceRecognitionScreen>
    with TickerProviderStateMixin {
  final FaceRecognitionService _faceRecognitionService =
      FaceRecognitionService();
  final ImagePicker _imagePicker = ImagePicker();

  CameraController? _cameraController;
  bool _isCameraInitialized = false;
  bool _isLoading = false;

  // Face recognition data
  File? _image1;
  File? _image2;
  List<double>? _embedding1;
  List<double>? _embedding2;
  Map<String, dynamic>? _comparisonResult;

  // Animation controllers
  late AnimationController _fadeController;
  late AnimationController _scaleController;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _initializeServices();
  }

  void _initializeAnimations() {
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _scaleController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
  }

  Future<void> _initializeServices() async {
    setState(() => _isLoading = true);

    // Load face recognition model
    await _faceRecognitionService.loadModel();

    // Initialize camera if available
    if (widget.cameras.isNotEmpty) {
      await _initializeCamera();
    }

    setState(() => _isLoading = false);
  }

  Future<void> _initializeCamera() async {
    try {
      // Request camera permission
      var status = await Permission.camera.request();
      if (status != PermissionStatus.granted) {
        _showSnackBar('Camera permission denied');
        return;
      }

      // Initialize camera controller
      _cameraController = CameraController(
        widget.cameras.first,
        ResolutionPreset.medium,
        enableAudio: false,
      );

      await _cameraController!.initialize();

      if (mounted) {
        setState(() => _isCameraInitialized = true);
      }
    } catch (e) {
      print('Error initializing camera: $e');
      _showSnackBar('Failed to initialize camera');
    }
  }

  Future<void> _captureImage(int imageSlot) async {
    if (!_isCameraInitialized || _cameraController == null) {
      _showSnackBar('Camera not initialized');
      return;
    }

    try {
      setState(() => _isLoading = true);

      final XFile image = await _cameraController!.takePicture();
      final File imageFile = File(image.path);

      await _processImage(imageFile, imageSlot);

      _scaleController.forward().then((_) => _scaleController.reverse());
    } catch (e) {
      print('Error capturing image: $e');
      _showSnackBar('Failed to capture image');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _pickImageFromGallery(int imageSlot) async {
    try {
      setState(() => _isLoading = true);

      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );

      if (image != null) {
        final File imageFile = File(image.path);
        await _processImage(imageFile, imageSlot);
      }
    } catch (e) {
      print('Error picking image: $e');
      _showSnackBar('Failed to pick image');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _processImage(File imageFile, int imageSlot) async {
    try {
      // Read image bytes
      Uint8List imageBytes = await imageFile.readAsBytes();

      // Get face embedding
      List<double>? embedding = await _faceRecognitionService.getFaceEmbedding(
        imageBytes,
      );

      if (embedding == null) {
        _showSnackBar('Failed to process face in image');
        return;
      }

      setState(() {
        if (imageSlot == 1) {
          _image1 = imageFile;
          _embedding1 = embedding;
        } else {
          _image2 = imageFile;
          _embedding2 = embedding;
        }

        // Clear previous comparison result
        _comparisonResult = null;
      });

      // Auto-compare if both images are available
      if (_embedding1 != null && _embedding2 != null) {
        _compareImages();
      }

      _fadeController.forward();
    } catch (e) {
      print('Error processing image: $e');
      _showSnackBar('Error processing image');
    }
  }

  void _compareImages() {
    if (_embedding1 == null || _embedding2 == null) {
      _showSnackBar('Please select both images first');
      return;
    }

    final result = _faceRecognitionService.verifyFaces(
      _embedding1!,
      _embedding2!,
    );

    setState(() => _comparisonResult = result);

    // Show result snackbar
    final bool isMatch = result['match'] as bool;
    final double confidence = result['confidence'] as double;

    _showSnackBar(
      isMatch
          ? 'Match found! Confidence: ${(confidence * 100).toStringAsFixed(1)}%'
          : 'No match. Confidence: ${(confidence * 100).toStringAsFixed(1)}%',
      isMatch ? Colors.green : Colors.red,
    );
  }

  void _clearImages() {
    setState(() {
      _image1 = null;
      _image2 = null;
      _embedding1 = null;
      _embedding2 = null;
      _comparisonResult = null;
    });

    _fadeController.reset();
  }

  void _showSnackBar(String message, [Color? backgroundColor]) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: backgroundColor,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Face Recognition'),
        backgroundColor: Colors.blue.shade600,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.clear_all),
            onPressed: _clearImages,
            tooltip: 'Clear all images',
          ),
        ],
      ),
      body:
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : Column(
                children: [
                  // Camera preview or status
                  Container(
                    height: 200,
                    margin: const EdgeInsets.all(16),
                    child:
                        _isCameraInitialized
                            ? CameraPreviewWidget(
                              controller: _cameraController!,
                              onCapture: _captureImage,
                            )
                            : _buildCameraStatusWidget(),
                  ),

                  // Image comparison section
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          // Image selection row
                          Row(
                            children: [
                              _buildImageSlot(1, _image1),
                              const SizedBox(width: 16),
                              _buildImageSlot(2, _image2),
                            ],
                          ),

                          const SizedBox(height: 24),

                          // Compare button
                          SizedBox(
                            width: double.infinity,
                            height: 48,
                            child: ElevatedButton.icon(
                              onPressed:
                                  _embedding1 != null && _embedding2 != null
                                      ? _compareImages
                                      : null,
                              icon: const Icon(Icons.compare_arrows),
                              label: const Text('Compare Faces'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.blue.shade600,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                            ),
                          ),

                          const SizedBox(height: 24),

                          // Comparison result
                          if (_comparisonResult != null)
                            FadeTransition(
                              opacity: _fadeController,
                              child: ComparisonResultWidget(
                                result: _comparisonResult!,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
    );
  }

  Widget _buildCameraStatusWidget() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey.shade200,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.camera_alt, size: 48, color: Colors.grey),
            SizedBox(height: 8),
            Text(
              'Camera not available',
              style: TextStyle(color: Colors.grey, fontSize: 16),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImageSlot(int slot, File? image) {
    return Expanded(
      child: ScaleTransition(
        scale: Tween<double>(begin: 1.0, end: 0.95).animate(_scaleController),
        child: Container(
          height: 200,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade300, width: 2),
            color: Colors.grey.shade50,
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child:
                image != null
                    ? Stack(
                      fit: StackFit.expand,
                      children: [
                        Image.file(image, fit: BoxFit.cover),
                        Positioned(
                          top: 8,
                          right: 8,
                          child: Container(
                            decoration: const BoxDecoration(
                              color: Colors.black54,
                              shape: BoxShape.circle,
                            ),
                            child: IconButton(
                              icon: const Icon(
                                Icons.close,
                                color: Colors.white,
                                size: 20,
                              ),
                              onPressed:
                                  () => setState(() {
                                    if (slot == 1) {
                                      _image1 = null;
                                      _embedding1 = null;
                                    } else {
                                      _image2 = null;
                                      _embedding2 = null;
                                    }
                                    _comparisonResult = null;
                                  }),
                            ),
                          ),
                        ),
                      ],
                    )
                    : Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.add_a_photo,
                          size: 40,
                          color: Colors.grey.shade600,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Image $slot',
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            IconButton(
                              onPressed:
                                  _isCameraInitialized
                                      ? () => _captureImage(slot)
                                      : null,
                              icon: const Icon(Icons.camera_alt),
                              tooltip: 'Take photo',
                            ),
                            IconButton(
                              onPressed: () => _pickImageFromGallery(slot),
                              icon: const Icon(Icons.photo_library),
                              tooltip: 'Pick from gallery',
                            ),
                          ],
                        ),
                      ],
                    ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _cameraController?.dispose();
    _fadeController.dispose();
    _scaleController.dispose();
    super.dispose();
  }
}
