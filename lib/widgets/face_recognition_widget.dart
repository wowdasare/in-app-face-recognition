import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

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

  @override
  void initState() {
    super.initState();
    _initializeModel();
  }

  Future<void> _initializeModel() async {
    await _faceRecognition.loadModel();
  }

  Future<void> _pickImage(int imageNumber) async {
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery);

    if (image != null) {
      setState(() {
        _isLoading = true;
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
        _isLoading = false;
      });

      _compareImages();
    }
  }

  void _compareImages() {
    if (_embedding1 != null && _embedding2 != null) {
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
''';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Face Recognition'),
        backgroundColor: Colors.blue,
      ),
      body: Padding(
        padding: EdgeInsets.all(16.0),
        child: Column(
          children: [
            // Image selection row
            Row(
              children: [
                Expanded(
                  child: Column(
                    children: [
                      GestureDetector(
                        onTap: () => _pickImage(1),
                        child: Container(
                          height: 200,
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child:
                              _image1 != null
                                  ? Image.file(_image1!, fit: BoxFit.cover)
                                  : Icon(Icons.add_a_photo, size: 50),
                        ),
                      ),
                      SizedBox(height: 8),
                      Text('Select Image 1'),
                    ],
                  ),
                ),
                SizedBox(width: 16),
                Expanded(
                  child: Column(
                    children: [
                      GestureDetector(
                        onTap: () => _pickImage(2),
                        child: Container(
                          height: 200,
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child:
                              _image2 != null
                                  ? Image.file(_image2!, fit: BoxFit.cover)
                                  : Icon(Icons.add_a_photo, size: 50),
                        ),
                      ),
                      SizedBox(height: 8),
                      Text('Select Image 2'),
                    ],
                  ),
                ),
              ],
            ),

            SizedBox(height: 20),

            // Loading indicator
            if (_isLoading) CircularProgressIndicator(),

            // Results
            if (_result.isNotEmpty)
              Container(
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(_result, style: TextStyle(fontSize: 16)),
              ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _faceRecognition.dispose();
    super.dispose();
  }
}
