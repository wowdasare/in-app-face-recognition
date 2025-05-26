import 'dart:io';
import 'dart:typed_data';

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
  String _statusMessage = '';

  @override
  void initState() {
    super.initState();
    _initializeModel();
  }

  Future<void> _initializeModel() async {
    setState(() {
      _isLoading = true;
      _statusMessage = 'Loading face recognition model...';
    });

    try {
      await _faceRecognition.loadModel();
      setState(() {
        _statusMessage = 'Ready! Tap images to select from gallery.';
      });
    } catch (e) {
      setState(() {
        _statusMessage =
            'Model loading failed. Using test mode. Tap images to select.';
      });
    }

    setState(() {
      _isLoading = false;
    });
  }

  Future<bool> _requestPermissions() async {
    try {
      if (Platform.isAndroid) {
        // Try modern permissions first (Android 13+)
        PermissionStatus photosStatus = await Permission.photos.request();
        if (photosStatus.isGranted) {
          return true;
        }

        // Fall back to storage permission (older Android)
        PermissionStatus storageStatus = await Permission.storage.request();
        return storageStatus.isGranted;
      } else if (Platform.isIOS) {
        PermissionStatus status = await Permission.photos.request();
        return status.isGranted;
      }

      return true; // For other platforms
    } catch (e) {
      print('Error requesting permissions: $e');
      return false;
    }
  }

  Future<void> _showPermissionDialog() async {
    return showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Permission Required'),
          content: Text(
            'This app needs access to your photos to select images for face recognition. '
            'Please grant permission in the app settings.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                openAppSettings();
              },
              child: Text('Settings'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _pickImage(int imageNumber) async {
    setState(() {
      _statusMessage = 'Checking permissions...';
    });

    // Check and request permissions
    bool hasPermission = await _requestPermissions();

    if (!hasPermission) {
      setState(() {
        _statusMessage =
            'Permission denied. Please grant permission to access photos.';
      });
      await _showPermissionDialog();
      return;
    }

    setState(() {
      _isLoading = true;
      _statusMessage = 'Opening gallery...';
    });

    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );

      if (image != null) {
        setState(() {
          _statusMessage = 'Processing image...';
          if (imageNumber == 1) {
            _image1 = File(image.path);
          } else {
            _image2 = File(image.path);
          }
        });

        // Get embedding
        Uint8List imageBytes = await File(image.path).readAsBytes();
        List<double>? embedding = await _faceRecognition.getFaceEmbedding(
          imageBytes,
        );

        setState(() {
          if (imageNumber == 1) {
            _embedding1 = embedding;
          } else {
            _embedding2 = embedding;
          }
          _statusMessage =
              embedding != null
                  ? 'Image processed successfully! ${_embedding1 != null && _embedding2 != null ? "Ready to compare." : "Select another image to compare."}'
                  : 'Failed to process image';
        });

        _compareImages();
      } else {
        setState(() {
          _statusMessage = 'No image selected';
        });
      }
    } catch (e) {
      setState(() {
        _statusMessage = 'Error: ${e.toString()}';
      });
      print('Error picking image: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _compareImages() {
    if (_embedding1 != null && _embedding2 != null) {
      try {
        double similarity = _faceRecognition.calculateSimilarity(
          _embedding1!,
          _embedding2!,
        );
        double distance = _faceRecognition.calculateDistance(
          _embedding1!,
          _embedding2!,
        );
        bool samePerson = _faceRecognition.areSamePerson(
          _embedding1!,
          _embedding2!,
        );

        setState(() {
          _result = '''
Similarity: ${(similarity * 100).toStringAsFixed(2)}%
Distance: ${distance.toStringAsFixed(4)}
Same Person: ${samePerson ? 'YES' : 'NO'}
Confidence: ${samePerson ? 'High' : 'Low'}
''';
          _statusMessage = 'Comparison completed!';
        });
      } catch (e) {
        setState(() {
          _result = 'Error comparing images: $e';
          _statusMessage = 'Comparison failed';
        });
      }
    }
  }

  void _clearImages() {
    setState(() {
      _image1 = null;
      _image2 = null;
      _embedding1 = null;
      _embedding2 = null;
      _result = '';
      _statusMessage = 'Images cleared. Tap images to select from gallery.';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Face Recognition'),
        backgroundColor: Colors.blue,
        actions: [
          IconButton(
            onPressed: _clearImages,
            icon: Icon(Icons.clear_all),
            tooltip: 'Clear all images',
          ),
        ],
      ),
      body: Padding(
        padding: EdgeInsets.all(16.0),
        child: Column(
          children: [
            // Status message
            if (_statusMessage.isNotEmpty)
              Container(
                width: double.infinity,
                padding: EdgeInsets.all(12),
                margin: EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: _getStatusColor(),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: _getStatusBorderColor()),
                ),
                child: Text(
                  _statusMessage,
                  style: TextStyle(
                    color: _getStatusTextColor(),
                    fontWeight: FontWeight.w500,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),

            // Image selection row
            Row(
              children: [
                Expanded(child: _buildImageSelector(1, _image1)),
                SizedBox(width: 16),
                Expanded(child: _buildImageSelector(2, _image2)),
              ],
            ),

            SizedBox(height: 20),

            // Loading indicator
            if (_isLoading)
              Column(
                children: [CircularProgressIndicator(), SizedBox(height: 16)],
              ),

            // Results
            if (_result.isNotEmpty)
              Container(
                width: double.infinity,
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.green[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.green[300]!),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Comparison Results:',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.green[700],
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(_result, style: TextStyle(fontSize: 14)),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Color _getStatusColor() {
    if (_statusMessage.contains('Error') || _statusMessage.contains('failed')) {
      return Colors.red[50]!;
    } else if (_statusMessage.contains('successfully') ||
        _statusMessage.contains('completed')) {
      return Colors.green[50]!;
    } else {
      return Colors.blue[50]!;
    }
  }

  Color _getStatusBorderColor() {
    if (_statusMessage.contains('Error') || _statusMessage.contains('failed')) {
      return Colors.red[200]!;
    } else if (_statusMessage.contains('successfully') ||
        _statusMessage.contains('completed')) {
      return Colors.green[200]!;
    } else {
      return Colors.blue[200]!;
    }
  }

  Color _getStatusTextColor() {
    if (_statusMessage.contains('Error') || _statusMessage.contains('failed')) {
      return Colors.red[700]!;
    } else if (_statusMessage.contains('successfully') ||
        _statusMessage.contains('completed')) {
      return Colors.green[700]!;
    } else {
      return Colors.blue[700]!;
    }
  }

  Widget _buildImageSelector(int imageNumber, File? image) {
    return Column(
      children: [
        GestureDetector(
          onTap: () => _pickImage(imageNumber),
          child: Container(
            height: 200,
            decoration: BoxDecoration(
              border: Border.all(
                color: image != null ? Colors.green : Colors.grey,
                width: 2,
              ),
              borderRadius: BorderRadius.circular(8),
            ),
            child:
                image != null
                    ? ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: Image.file(
                        image,
                        fit: BoxFit.cover,
                        width: double.infinity,
                      ),
                    )
                    : Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.add_a_photo,
                          size: 50,
                          color: Colors.grey[600],
                        ),
                        SizedBox(height: 8),
                        Text(
                          'Tap to select',
                          style: TextStyle(color: Colors.grey[600]),
                        ),
                      ],
                    ),
          ),
        ),
        SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'Image $imageNumber',
              style: TextStyle(
                fontWeight: FontWeight.w500,
                color: image != null ? Colors.green[700] : Colors.grey[600],
              ),
            ),
            if (image != null) ...[
              SizedBox(width: 8),
              Icon(Icons.check_circle, color: Colors.green, size: 16),
            ],
          ],
        ),
      ],
    );
  }

  @override
  void dispose() {
    _faceRecognition.dispose();
  }
}
