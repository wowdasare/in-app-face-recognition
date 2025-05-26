// lib/screens/face_recognition_screen.dart
import 'dart:io';
import 'dart:typed_data';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';

import '../services/face_recognition_service.dart';
import '../widgets/comparison_widget.dart';
import '../widgets/model_debug_widget.dart';

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
  bool _isInitializing = true;
  bool _isProcessing = false;

  // Face recognition data
  File? _image1;
  File? _image2;
  List<double>? _embedding1;
  List<double>? _embedding2;
  Map<String, dynamic>? _comparisonResult;

  // Animation controllers
  late AnimationController _loadingController;
  late AnimationController _resultController;
  late AnimationController _pulseController;
  late AnimationController _fadeController;

  String _statusMessage = 'Initializing...';
  String _modelStatus = 'Loading';

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _initializeServices();
  }

  void _initializeAnimations() {
    _loadingController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat();

    _resultController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );

    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
  }

  Future<void> _initializeServices() async {
    setState(() {
      _isInitializing = true;
      _statusMessage = 'Loading AI models for face recognition...';
      _modelStatus = 'Loading';
    });

    try {
      // Load face recognition models
      bool modelLoaded = await _faceRecognitionService.loadModel();

      setState(() {
        _modelStatus = _faceRecognitionService.modelStatus;
        _statusMessage =
            modelLoaded
                ? 'AI models loaded successfully! Ready for face recognition.'
                : 'Model loading failed - using fallback mode.';
      });

      // Initialize camera if available
      if (widget.cameras.isNotEmpty) {
        await _initializeCamera();
      } else {
        setState(() {
          _statusMessage =
              'AI ready! No camera available - use gallery to select images.';
        });
      }

      _fadeController.forward();
    } catch (e) {
      print('Error initializing services: $e');
      setState(() {
        _statusMessage = 'Initialization error: ${e.toString()}';
        _modelStatus = 'Error';
      });
    } finally {
      setState(() {
        _isInitializing = false;
      });
    }
  }

  Future<void> _initializeCamera() async {
    try {
      var status = await Permission.camera.request();
      if (status != PermissionStatus.granted) {
        setState(() {
          _statusMessage = 'Camera permission denied. Using gallery mode only.';
        });
        return;
      }

      _cameraController = CameraController(
        widget.cameras.first,
        ResolutionPreset.medium,
        enableAudio: false,
      );

      await _cameraController!.initialize();

      if (mounted) {
        setState(() {
          _isCameraInitialized = true;
          _statusMessage = 'Ready! Camera and AI models loaded successfully.';
        });
      }
    } catch (e) {
      print('Error initializing camera: $e');
      setState(() {
        _statusMessage =
            'Camera initialization failed. Using gallery mode only.';
      });
    }
  }

  Future<void> _captureImage(int imageSlot) async {
    if (!_isCameraInitialized || _cameraController == null) {
      _showSnackBar('Camera not available', Colors.orange);
      return;
    }

    try {
      setState(() {
        _isProcessing = true;
        _statusMessage = 'Capturing image...';
      });

      final XFile image = await _cameraController!.takePicture();
      final File imageFile = File(image.path);

      await _processImage(imageFile, imageSlot);
    } catch (e) {
      print('Error capturing image: $e');
      _showSnackBar('Failed to capture image: ${e.toString()}', Colors.red);
      setState(() => _isProcessing = false);
    }
  }

  Future<void> _pickImageFromGallery(int imageSlot) async {
    try {
      setState(() {
        _isProcessing = true;
        _statusMessage = 'Opening gallery...';
      });

      // Check permissions
      bool hasPermission = await _requestGalleryPermission();
      if (!hasPermission) {
        setState(() {
          _statusMessage =
              'Gallery permission denied. Please grant permission in settings.';
          _isProcessing = false;
        });
        _showSnackBar(
          'Permission denied. Please grant gallery access.',
          Colors.red,
        );
        return;
      }

      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 90,
      );

      if (image != null) {
        final File imageFile = File(image.path);
        await _processImage(imageFile, imageSlot);
      } else {
        setState(() {
          _isProcessing = false;
          _statusMessage = 'No image selected';
        });
      }
    } catch (e) {
      print('Error picking image: $e');
      _showSnackBar('Failed to pick image: ${e.toString()}', Colors.red);
      setState(() => _isProcessing = false);
    }
  }

  Future<bool> _requestGalleryPermission() async {
    try {
      if (Platform.isAndroid) {
        // Try modern permissions first (Android 13+)
        PermissionStatus photosStatus = await Permission.photos.status;
        if (photosStatus.isGranted) return true;

        if (photosStatus.isDenied) {
          photosStatus = await Permission.photos.request();
          if (photosStatus.isGranted) return true;
        }

        // Fall back to storage permission (older Android)
        PermissionStatus storageStatus = await Permission.storage.status;
        if (storageStatus.isGranted) return true;

        if (storageStatus.isDenied) {
          storageStatus = await Permission.storage.request();
          return storageStatus.isGranted;
        }

        return false;
      } else if (Platform.isIOS) {
        PermissionStatus status = await Permission.photos.status;
        if (status.isGranted) return true;

        if (status.isDenied) {
          status = await Permission.photos.request();
          return status.isGranted;
        }

        return false;
      }

      return true; // For other platforms
    } catch (e) {
      print('Error requesting gallery permission: $e');
      return false;
    }
  }

  Future<void> _processImage(File imageFile, int imageSlot) async {
    try {
      setState(() {
        _statusMessage = 'Processing image with AI...';
      });

      Uint8List imageBytes = await imageFile.readAsBytes();
      List<double>? embedding = await _faceRecognitionService.getFaceEmbedding(
        imageBytes,
      );

      if (embedding == null) {
        _showSnackBar(
          'No face detected in image. Please try another image with a clear face.',
          Colors.red,
        );
        setState(() {
          _isProcessing = false;
          _statusMessage =
              'Face detection failed. Try another image with a clear face.';
        });
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
        _comparisonResult = null;
        _isProcessing = false;
        _statusMessage =
            'Face processed successfully! ${_image1 != null && _image2 != null ? 'Ready to compare faces.' : 'Add another image to compare.'}';
      });

      if (_embedding1 != null && _embedding2 != null) {
        await Future.delayed(const Duration(milliseconds: 500));
        _compareImages();
      }

      _pulseController.forward().then((_) => _pulseController.reverse());
    } catch (e) {
      print('Error processing image: $e');
      _showSnackBar('Error processing image: ${e.toString()}', Colors.red);
      setState(() {
        _isProcessing = false;
        _statusMessage = 'Error processing image. Please try again.';
      });
    }
  }

  Future<void> _compareImages() async {
    if (_embedding1 == null || _embedding2 == null) {
      _showSnackBar('Please select both images first', Colors.orange);
      return;
    }

    setState(() {
      _isProcessing = true;
      _statusMessage = 'Comparing faces with AI...';
    });

    try {
      await Future.delayed(const Duration(milliseconds: 800));

      final result = _faceRecognitionService.verifyFaces(
        _embedding1!,
        _embedding2!,
      );

      setState(() {
        _comparisonResult = result;
        _isProcessing = false;

        final bool isMatch = result['match'] as bool;
        final double confidence = result['confidence'] as double;
        final double similarity = result['similarity'] as double;

        _statusMessage =
            isMatch
                ? 'Face match found! Confidence: ${(confidence * 100).toStringAsFixed(1)}%'
                : 'No face match. Similarity: ${(similarity * 100).toStringAsFixed(1)}%';
      });

      _resultController.forward();

      final bool isMatch = result['match'] as bool;
      final double similarity = result['similarity'] as double;

      _showSnackBar(
        isMatch
            ? '✅ Faces match! Similarity: ${(similarity * 100).toStringAsFixed(1)}%'
            : '❌ Different faces. Similarity: ${(similarity * 100).toStringAsFixed(1)}%',
        isMatch ? Colors.green : Colors.red,
      );
    } catch (e) {
      setState(() {
        _isProcessing = false;
        _statusMessage = 'Comparison failed: ${e.toString()}';
      });
      _showSnackBar('Comparison failed: ${e.toString()}', Colors.red);
    }
  }

  void _clearImages() {
    setState(() {
      _image1 = null;
      _image2 = null;
      _embedding1 = null;
      _embedding2 = null;
      _comparisonResult = null;
      _statusMessage = 'Images cleared. Ready for new face recognition task.';
    });

    _resultController.reset();
    _showSnackBar('All images cleared', Colors.blue);
  }

  void _showSnackBar(String message, Color backgroundColor) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: const TextStyle(fontWeight: FontWeight.w500),
        ),
        backgroundColor: backgroundColor,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text(
          'AI Face Recognition',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        backgroundColor: Colors.indigo.shade600,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          // Debug button
          IconButton(
            icon: const Icon(Icons.bug_report),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const ModelDebugWidget(),
                ),
              );
            },
            tooltip: 'Model Debug Tool',
          ),
          if (_image1 != null || _image2 != null)
            IconButton(
              icon: const Icon(Icons.clear_all_rounded),
              onPressed: _clearImages,
              tooltip: 'Clear all images',
            ),
        ],
      ),
      body: _isInitializing ? _buildInitializingScreen() : _buildMainContent(),
    );
  }

  Widget _buildInitializingScreen() {
    return Center(
      child: Container(
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        margin: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedBuilder(
              animation: _loadingController,
              builder: (context, child) {
                return Transform.rotate(
                  angle: _loadingController.value * 2 * 3.14159,
                  child: Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Colors.indigo.shade400, Colors.blue.shade400],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.face,
                      color: Colors.white,
                      size: 30,
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 24),
            Text(
              'AI Face Recognition',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.indigo.shade700,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              _statusMessage,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color:
                    _modelStatus.contains('successfully') ||
                            _modelStatus.contains('Loaded')
                        ? Colors.green.shade100
                        : Colors.orange.shade100,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color:
                      _modelStatus.contains('successfully') ||
                              _modelStatus.contains('Loaded')
                          ? Colors.green.shade300
                          : Colors.orange.shade300,
                ),
              ),
              child: Text(
                'Status: $_modelStatus',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color:
                      _modelStatus.contains('successfully') ||
                              _modelStatus.contains('Loaded')
                          ? Colors.green.shade700
                          : Colors.orange.shade700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMainContent() {
    return FadeTransition(
      opacity: _fadeController,
      child: Column(
        children: [
          _buildStatusBar(),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  _buildImageSelectionSection(),
                  const SizedBox(height: 24),
                  _buildCompareButton(),
                  const SizedBox(height: 24),
                  if (_comparisonResult != null)
                    FadeTransition(
                      opacity: _resultController,
                      child: ComparisonResultWidget(result: _comparisonResult!),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBar() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.indigo.shade600, Colors.blue.shade600],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              _isProcessing ? Icons.psychology : Icons.check_circle,
              color: Colors.white,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _isProcessing ? 'AI Processing...' : 'Ready',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  _statusMessage,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.9),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          if (_isProcessing)
            const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildImageSelectionSection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.compare_arrows, color: Colors.indigo.shade600),
              const SizedBox(width: 8),
              Text(
                'Select Images to Compare',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey.shade800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(child: _buildImageSlot(1, _image1, _embedding1)),
              const SizedBox(width: 16),
              Expanded(child: _buildImageSlot(2, _image2, _embedding2)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildImageSlot(int slot, File? image, List<double>? embedding) {
    bool hasImage = image != null;
    bool isProcessed = embedding != null;

    return AnimatedBuilder(
      animation: _pulseController,
      builder: (context, child) {
        double scale =
            hasImage && isProcessed
                ? 1.0 + (_pulseController.value * 0.05)
                : 1.0;

        return Transform.scale(
          scale: scale,
          child: Container(
            height: 200,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color:
                    hasImage
                        ? (isProcessed
                            ? Colors.green.shade300
                            : Colors.blue.shade300)
                        : Colors.grey.shade300,
                width: 2,
              ),
              color: hasImage ? null : Colors.grey.shade50,
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child:
                  hasImage
                      ? _buildImageContent(slot, image, isProcessed)
                      : _buildEmptySlot(slot),
            ),
          ),
        );
      },
    );
  }

  Widget _buildImageContent(int slot, File image, bool isProcessed) {
    return Stack(
      fit: StackFit.expand,
      children: [
        Image.file(image, fit: BoxFit.cover),

        // Status badge
        Positioned(
          top: 8,
          left: 8,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: isProcessed ? Colors.green : Colors.blue,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  isProcessed ? Icons.check : Icons.hourglass_top,
                  color: Colors.white,
                  size: 12,
                ),
                const SizedBox(width: 4),
                Text(
                  isProcessed ? 'AI Ready' : 'Processing',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),

        // Remove button
        Positioned(
          top: 8,
          right: 8,
          child: GestureDetector(
            onTap: () {
              setState(() {
                if (slot == 1) {
                  _image1 = null;
                  _embedding1 = null;
                } else {
                  _image2 = null;
                  _embedding2 = null;
                }
                _comparisonResult = null;
              });
            },
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: const BoxDecoration(
                color: Colors.black54,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.close, color: Colors.white, size: 16),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildEmptySlot(int slot) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          Icons.add_photo_alternate_outlined,
          size: 40,
          color: Colors.grey.shade400,
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
            if (_isCameraInitialized)
              _buildActionButton(
                icon: Icons.camera_alt,
                label: 'Camera',
                onPressed: () => _captureImage(slot),
              ),
            _buildActionButton(
              icon: Icons.photo_library,
              label: 'Gallery',
              onPressed: () => _pickImageFromGallery(slot),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
  }) {
    return Column(
      children: [
        ElevatedButton(
          onPressed: _isProcessing ? null : onPressed,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.indigo.shade600,
            foregroundColor: Colors.white,
            shape: const CircleBorder(),
            padding: const EdgeInsets.all(12),
          ),
          child: Icon(icon, size: 20),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
        ),
      ],
    );
  }

  Widget _buildCompareButton() {
    bool canCompare =
        _embedding1 != null && _embedding2 != null && !_isProcessing;

    return SizedBox(
      width: double.infinity,
      height: 50,
      child: ElevatedButton.icon(
        onPressed: canCompare ? _compareImages : null,
        icon: Icon(_isProcessing ? Icons.psychology : Icons.compare_arrows),
        label: Text(
          _isProcessing ? 'AI Processing...' : 'Compare Faces with AI',
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.indigo.shade600,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: canCompare ? 2 : 0,
        ),
      ),
    );
  }

  @override
  void dispose() {
    _cameraController?.dispose();
    _loadingController.dispose();
    _resultController.dispose();
    _pulseController.dispose();
    _fadeController.dispose();
    _faceRecognitionService.dispose();
    super.dispose();
  }
}
