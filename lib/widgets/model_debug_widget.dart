// lib/widgets/model_debug_widget.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/tflite_face_recognition_service.dart';

class ModelDebugWidget extends StatefulWidget {
  const ModelDebugWidget({super.key});

  @override
  State<ModelDebugWidget> createState() => _ModelDebugWidgetState();
}

class _ModelDebugWidgetState extends State<ModelDebugWidget> {
  final TFLiteFaceRecognitionService _service = TFLiteFaceRecognitionService();

  bool _isLoading = false;
  String _status = 'Ready to test models';
  List<String> _logs = [];
  Map<String, bool> _modelStatus = {};

  @override
  void initState() {
    super.initState();
    _checkInitialStatus();
  }

  void _checkInitialStatus() {
    setState(() {
      _status = _service.isModelLoaded
          ? 'Models are loaded: ${_service.modelStatus}'
          : 'Models not loaded yet';

      _modelStatus = {
        'TensorFlow Lite': _service.isModelLoaded,
        'Status': _service.isModelLoaded,
      };
    });
  }

  Future<void> _testModelLoading() async {
    setState(() {
      _isLoading = true;
      _logs.clear();
      _status = 'Testing model loading...';
    });

    try {
      _addLog('🚀 Starting model loading test...');

      // Check if assets exist
      await _checkAssetExistence();

      // Try to load models
      _addLog('📥 Loading TensorFlow Lite models...');
      bool success = await _service.loadModels();

      if (success) {
        _addLog('✅ Models loaded successfully!');
        _addLog('📊 Model Status: ${_service.modelStatus}');

        setState(() {
          _status = 'All models loaded successfully';
          _modelStatus = {
            'P-Net (MTCNN)': true,
            'R-Net (MTCNN)': true,
            'O-Net (MTCNN)': true,
            'MobileFaceNet': true,
            'Anti-Spoofing': true,
          };
        });
      } else {
        _addLog('❌ Model loading failed');
        setState(() {
          _status = 'Model loading failed';
        });
      }

    } catch (e) {
      _addLog('💥 Error during testing: $e');
      setState(() {
        _status = 'Error: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _checkAssetExistence() async {
    List<String> modelPaths = [
      'assets/models/pnet.tflite',
      'assets/models/rnet.tflite',
      'assets/models/onet.tflite',
      'assets/models/MobileFaceNet.tflite',
      'assets/models/FaceAntiSpoofing.tflite',
    ];

    _addLog('🔍 Checking asset existence...');

    for (String path in modelPaths) {
      try {
        final ByteData data = await rootBundle.load(path);
        _addLog('✅ Found: $path (${data.lengthInBytes} bytes)');
      } catch (e) {
        _addLog('❌ Missing: $path - Error: $e');
      }
    }
  }

  void _addLog(String message) {
    setState(() {
      _logs.add('${DateTime.now().toString().substring(11, 19)}: $message');
    });
    print(message);
  }

  void _clearLogs() {
    setState(() {
      _logs.clear();
      _status = 'Logs cleared';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Model Debug Tool'),
        backgroundColor: Colors.orange.shade600,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _isLoading ? null : _testModelLoading,
          ),
          IconButton(
            icon: const Icon(Icons.clear),
            onPressed: _clearLogs,
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Status card
            Card(
              color: _service.isModelLoaded ? Colors.green.shade50 : Colors.orange.shade50,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          _service.isModelLoaded ? Icons.check_circle : Icons.warning,
                          color: _service.isModelLoaded ? Colors.green : Colors.orange,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Model Status',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: _service.isModelLoaded ? Colors.green.shade700 : Colors.orange.shade700,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _status,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade700,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Model status grid
            if (_modelStatus.isNotEmpty) ...[
              const Text(
                'Individual Models:',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  childAspectRatio: 3,
                  crossAxisSpacing: 8,
                  mainAxisSpacing: 8,
                ),
                itemCount: _modelStatus.length,
                itemBuilder: (context, index) {
                  String key = _modelStatus.keys.elementAt(index);
                  bool status = _modelStatus[key]!;

                  return Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: status ? Colors.green.shade100 : Colors.red.shade100,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: status ? Colors.green.shade300 : Colors.red.shade300,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          status ? Icons.check : Icons.close,
                          color: status ? Colors.green.shade700 : Colors.red.shade700,
                          size: 16,
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            key,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: status ? Colors.green.shade700 : Colors.red.shade700,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
              const SizedBox(height: 16),
            ],

            // Test button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isLoading ? null : _testModelLoading,
                icon: _isLoading
                    ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
                    : const Icon(Icons.play_arrow),
                label: Text(_isLoading ? 'Testing...' : 'Test Model Loading'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange.shade600,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Logs section
            const Text(
              'Debug Logs:',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),

            Expanded(
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: _logs.isEmpty
                    ? const Center(
                  child: Text(
                    'No logs yet. Tap "Test Model Loading" to start.',
                    style: TextStyle(
                      color: Colors.grey,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                )
                    : ListView.builder(
                  itemCount: _logs.length,
                  itemBuilder: (context, index) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Text(
                        _logs[index],
                        style: const TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 12,
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}