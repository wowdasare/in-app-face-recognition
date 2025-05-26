import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';

import '../services/face_recognition_service.dart';

class FaceRecognitionWidget extends StatefulWidget {
  const FaceRecognitionWidget({super.key});

  @override
  _FaceRecognitionWidgetState createState() => _FaceRecognitionWidgetState();
}

class _FaceRecognitionWidgetState extends State<FaceRecognitionWidget> {
  final FaceRecognitionService _faceRecognition = FaceRecognitionService();
  final ImagePicker _picker = ImagePicker();

  File? _image1, _image2;
  List<double>? _embedding1, _embedding2;
  String _result = '';
  bool _isLoading = false;
  bool _modelsLoaded = false;

  @override
  void initState() {
    super.initState();
    _initializeModels();
  }

  Future<void> _initializeModels() async {
    setState(() {
      _isLoading = true;
    });

    try {
      await _faceRecognition.loadModel();
      setState(() {
        _modelsLoaded = true;
        _isLoading = false;
      });
      _showMessage('✓ Face recognition models loaded successfully');
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      _showMessage('❌ Failed to load models: $e');
    }
  }

  Future<void> _showImageSourceDialog(int imageNumber) async {
    if (!_modelsLoaded) {
      _showMessage('Please wait for models to load first');
      return;
    }

    showModalBottomSheet(
      context: context,
      builder: (BuildContext context) {
        return SafeArea(
          child: Wrap(
            children: [
              ListTile(
                leading: const Icon(Icons.camera_alt, color: Colors.blue),
                title: const Text('Take Selfie'),
                subtitle: const Text('Use front camera'),
                onTap: () {
                  Navigator.of(context).pop();
                  _pickImage(imageNumber, ImageSource.camera);
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_library, color: Colors.green),
                title: const Text('Choose from Gallery'),
                subtitle: const Text('Select existing photo'),
                onTap: () {
                  Navigator.of(context).pop();
                  _pickImage(imageNumber, ImageSource.gallery);
                },
              ),
              ListTile(
                leading: const Icon(Icons.cancel, color: Colors.grey),
                title: const Text('Cancel'),
                onTap: () {
                  Navigator.of(context).pop();
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _pickImage(int imageNumber, ImageSource source) async {
    try {
      // Check permissions
      if (source == ImageSource.camera) {
        final cameraStatus = await Permission.camera.request();
        if (!cameraStatus.isGranted) {
          _showMessage('Camera permission is required');
          return;
        }
      } else {
        final photoStatus = await Permission.photos.request();
        if (!photoStatus.isGranted) {
          _showMessage('Photo library access is required');
          return;
        }
      }

      final XFile? image = await _picker.pickImage(
        source: source,
        imageQuality: 85,
        preferredCameraDevice: CameraDevice.front,
        maxWidth: 1024,
        maxHeight: 1024,
      );

      if (image != null) {
        setState(() {
          _isLoading = true;
          if (imageNumber == 1) {
            _image1 = File(image.path);
            _embedding1 = null;
          } else {
            _image2 = File(image.path);
            _embedding2 = null;
          }
        });

        try {
          _showMessage('🔍 Processing face...');

          // Get face embedding
          List<double>? embedding = await _faceRecognition
              .getFaceEmbeddingFromPath(image.path);

          setState(() {
            if (imageNumber == 1) {
              _embedding1 = embedding;
            } else {
              _embedding2 = embedding;
            }
            _isLoading = false;
          });

          if (embedding == null) {
            _showMessage(
              '❌ No face detected. Try better lighting and center your face',
            );
          } else {
            _showMessage('✓ Face processed successfully!');
            _compareImages();
          }
        } catch (e) {
          setState(() {
            _isLoading = false;
          });
          _showMessage('❌ Error processing image: $e');
        }
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      _showMessage('❌ Error accessing camera/gallery: $e');
    }
  }

  void _compareImages() {
    if (_embedding1 != null && _embedding2 != null) {
      final similarity = _faceRecognition.calculateSimilarity(
        _embedding1!,
        _embedding2!,
      );
      final distance = _faceRecognition.calculateDistance(
        _embedding1!,
        _embedding2!,
      );
      final samePerson = _faceRecognition.areSamePerson(
        _embedding1!,
        _embedding2!,
      );

      setState(() {
        _result = '''
📊 Face Comparison Results

Cosine Similarity: ${(similarity * 100).toStringAsFixed(2)}%
Euclidean Distance: ${distance.toStringAsFixed(4)}
Match Result: ${samePerson ? '✅ SAME PERSON' : '❌ DIFFERENT PERSON'}

Threshold: 50% similarity
Model: MobileFaceNet
''';
      });

      // Show result in snackbar too
      final resultText =
          samePerson
              ? '✅ SAME PERSON (${(similarity * 100).toStringAsFixed(1)}%)'
              : '❌ DIFFERENT PERSON (${(similarity * 100).toStringAsFixed(1)}%)';
      _showMessage(resultText);
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), duration: const Duration(seconds: 3)),
    );
  }

  void _clearImages() {
    setState(() {
      _image1 = null;
      _image2 = null;
      _embedding1 = null;
      _embedding2 = null;
      _result = '';
    });
    _showMessage('🗑️ Images cleared');
  }

  Widget _buildImageContainer(
    int imageNumber,
    File? image,
    List<double>? embedding,
  ) {
    return GestureDetector(
      onTap: () => _showImageSourceDialog(imageNumber),
      child: Container(
        height: 200,
        decoration: BoxDecoration(
          border: Border.all(
            color:
                embedding != null
                    ? Colors.green
                    : _isLoading
                    ? Colors.orange
                    : Colors.grey,
            width: 2,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child:
              image != null
                  ? Stack(
                    fit: StackFit.expand,
                    children: [
                      Image.file(image, fit: BoxFit.cover),
                      if (embedding != null)
                        Positioned(
                          top: 8,
                          right: 8,
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: Colors.green,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(
                              Icons.check,
                              color: Colors.white,
                              size: 16,
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
                        color: _modelsLoaded ? Colors.blue : Colors.grey,
                      ),
                      const SizedBox(height: 8),
                      const Icon(
                        Icons.camera_alt,
                        size: 20,
                        color: Colors.grey,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _modelsLoaded
                            ? 'Tap to take photo\nor select image'
                            : 'Loading models...',
                        style: const TextStyle(
                          color: Colors.grey,
                          fontSize: 12,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Face Recognition'),
        backgroundColor: Colors.blue,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _initializeModels,
            tooltip: 'Reload Models',
          ),
          IconButton(
            icon: const Icon(Icons.clear),
            onPressed: _clearImages,
            tooltip: 'Clear Images',
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // Status indicator
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _modelsLoaded ? Colors.green[50] : Colors.orange[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color:
                      _modelsLoaded ? Colors.green[200]! : Colors.orange[200]!,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    _modelsLoaded ? Icons.check_circle : Icons.hourglass_empty,
                    color: _modelsLoaded ? Colors.green : Colors.orange,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _modelsLoaded
                          ? 'Ready! Tap images below to start face comparison'
                          : 'Loading MobileFaceNet model...',
                      style: TextStyle(
                        color:
                            _modelsLoaded
                                ? Colors.green[700]
                                : Colors.orange[700],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Image containers
            Row(
              children: [
                Expanded(
                  child: Column(
                    children: [
                      _buildImageContainer(1, _image1, _embedding1),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text('Image 1'),
                          if (_embedding1 != null) ...[
                            const SizedBox(width: 4),
                            const Icon(
                              Icons.verified,
                              color: Colors.green,
                              size: 16,
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    children: [
                      _buildImageContainer(2, _image2, _embedding2),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text('Image 2'),
                          if (_embedding2 != null) ...[
                            const SizedBox(width: 4),
                            const Icon(
                              Icons.verified,
                              color: Colors.green,
                              size: 16,
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 20),

            // Loading indicator
            if (_isLoading)
              const Column(
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 8),
                  Text('Processing...'),
                ],
              ),

            // Results
            if (_result.isNotEmpty && !_isLoading)
              Expanded(
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.grey[50],
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey[300]!),
                  ),
                  child: SingleChildScrollView(
                    child: Text(
                      _result,
                      style: const TextStyle(
                        fontSize: 14,
                        fontFamily: 'monospace',
                        height: 1.4,
                      ),
                    ),
                  ),
                ),
              ),

            // Tips when no results
            if (_result.isEmpty && !_isLoading && _modelsLoaded)
              Expanded(
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.blue[50],
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.blue[200]!),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.lightbulb, color: Colors.blue[700]),
                          const SizedBox(width: 8),
                          Text(
                            'Tips for Best Results:',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.blue[700],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        '📸 Use good lighting (natural light works best)\n'
                        '👤 Face should be clearly visible and centered\n'
                        '😊 Look directly at the camera\n'
                        '📏 Keep reasonable distance from camera\n'
                        '🚫 Avoid sunglasses or face coverings\n'
                        '🔄 Try multiple photos if detection fails\n'
                        '🤳 Use front camera for selfies',
                        style: TextStyle(fontSize: 14, height: 1.5),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
      floatingActionButton:
          _modelsLoaded
              ? FloatingActionButton.extended(
                onPressed: _quickSelfieTest,
                icon: const Icon(Icons.camera_front),
                label: const Text('Quick Test'),
                backgroundColor: Colors.green,
              )
              : null,
    );
  }

  Future<void> _quickSelfieTest() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Quick Selfie Test'),
            content: const Text(
              'This will take two selfies in sequence to test face recognition. '
              'Make sure you have good lighting!',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Start Test'),
              ),
            ],
          ),
    );

    if (confirmed == true) {
      _clearImages();
      _showMessage('📷 Taking first selfie...');
      await _pickImage(1, ImageSource.camera);

      if (_embedding1 != null) {
        await Future.delayed(const Duration(seconds: 2));
        _showMessage('📷 Taking second selfie...');
        await _pickImage(2, ImageSource.camera);
      }
    }
  }

  @override
  void dispose() {
    _faceRecognition.dispose();
    super.dispose();
  }
}
