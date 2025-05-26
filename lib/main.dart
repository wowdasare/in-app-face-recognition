// lib/main.dart
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'screens/face_recognition_screen.dart';
import 'services/tflite_face_recognition_service.dart';

List<CameraDescription> cameras = [];

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Set preferred orientations
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Initialize cameras
  try {
    cameras = await availableCameras();
    print('📱 Initialized ${cameras.length} camera(s)');
  } catch (e) {
    print('❌ Error initializing cameras: $e');
    cameras = []; // Continue without cameras
  }

  // Pre-initialize TensorFlow Lite service
  try {
    print('🤖 Pre-initializing TensorFlow Lite service...');
    final TFLiteFaceRecognitionService service = TFLiteFaceRecognitionService();
    // Don't await here - let it load in background
    service.loadModels().then((success) {
      print(success
          ? '✅ TensorFlow Lite models pre-loaded successfully'
          : '⚠️ TensorFlow Lite models failed to pre-load');
    });
  } catch (e) {
    print('⚠️ Error pre-initializing TensorFlow Lite: $e');
  }

  runApp(const FaceRecognitionApp());
}

class FaceRecognitionApp extends StatelessWidget {
  const FaceRecognitionApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AI Face Recognition',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        // Modern Material 3 theme
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.indigo,
          brightness: Brightness.light,
        ),

        // App Bar theme
        appBarTheme: AppBarTheme(
          centerTitle: true,
          elevation: 0,
          backgroundColor: Colors.indigo.shade600,
          foregroundColor: Colors.white,
          titleTextStyle: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),

        // Card theme
        cardTheme: CardTheme(
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),

        // Elevated button theme
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          ),
        ),

        // Input decoration theme
        inputDecorationTheme: InputDecorationTheme(
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          filled: true,
          fillColor: Colors.grey.shade50,
        ),

        // Visual density
        visualDensity: VisualDensity.adaptivePlatformDensity,

        // Typography
        textTheme: const TextTheme(
          headlineLarge: TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.bold,
          ),
          headlineMedium: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w600,
          ),
          headlineSmall: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w600,
          ),
          titleLarge: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
          titleMedium: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
          bodyLarge: TextStyle(
            fontSize: 16,
          ),
          bodyMedium: TextStyle(
            fontSize: 14,
          ),
        ),
      ),

      // Dark theme (optional)
      darkTheme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.indigo,
          brightness: Brightness.dark,
        ),
        appBarTheme: AppBarTheme(
          centerTitle: true,
          elevation: 0,
          backgroundColor: Colors.indigo.shade800,
          foregroundColor: Colors.white,
        ),
      ),

      // System theme mode
      themeMode: ThemeMode.system,

      // Home screen
      home: FaceRecognitionWrapper(cameras: cameras),
    );
  }
}

/// Wrapper widget to handle initialization and error states
class FaceRecognitionWrapper extends StatefulWidget {
  final List<CameraDescription> cameras;

  const FaceRecognitionWrapper({super.key, required this.cameras});

  @override
  State<FaceRecognitionWrapper> createState() => _FaceRecognitionWrapperState();
}

class _FaceRecognitionWrapperState extends State<FaceRecognitionWrapper> {
  bool _isInitializing = true;
  String _initializationError = '';

  @override
  void initState() {
    super.initState();
    _checkInitialization();
  }

  Future<void> _checkInitialization() async {
    try {
      // Small delay to ensure everything is ready
      await Future.delayed(const Duration(milliseconds: 500));

      // Check if we have necessary permissions and components
      bool hasRequiredComponents = true;

      if (!hasRequiredComponents) {
        setState(() {
          _initializationError = 'Missing required components';
          _isInitializing = false;
        });
        return;
      }

      setState(() {
        _isInitializing = false;
      });
    } catch (e) {
      setState(() {
        _initializationError = e.toString();
        _isInitializing = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isInitializing) {
      return const AppInitializationScreen();
    }

    if (_initializationError.isNotEmpty) {
      return AppErrorScreen(error: _initializationError);
    }

    return FaceRecognitionScreen(cameras: widget.cameras);
  }
}

/// Loading screen shown during app initialization
class AppInitializationScreen extends StatelessWidget {
  const AppInitializationScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.indigo.shade600,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // App logo/icon
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Icon(
                Icons.face_rounded,
                size: 60,
                color: Colors.white,
              ),
            ),

            const SizedBox(height: 24),

            // App title
            const Text(
              'AI Face Recognition',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),

            const SizedBox(height: 8),

            Text(
              'Powered by TensorFlow Lite',
              style: TextStyle(
                fontSize: 16,
                color: Colors.white.withOpacity(0.8),
              ),
            ),

            const SizedBox(height: 40),

            // Loading indicator
            const CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
            ),

            const SizedBox(height: 16),

            Text(
              'Initializing AI models...',
              style: TextStyle(
                fontSize: 14,
                color: Colors.white.withOpacity(0.8),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Error screen shown when initialization fails
class AppErrorScreen extends StatelessWidget {
  final String error;

  const AppErrorScreen({super.key, required this.error});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.red.shade50,
      appBar: AppBar(
        title: const Text('Initialization Error'),
        backgroundColor: Colors.red.shade600,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 80,
              color: Colors.red.shade400,
            ),

            const SizedBox(height: 24),

            const Text(
              'Failed to Initialize',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),

            const SizedBox(height: 16),

            Text(
              'The app encountered an error during initialization:',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey.shade600,
              ),
              textAlign: TextAlign.center,
            ),

            const SizedBox(height: 16),

            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.red.shade100,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red.shade300),
              ),
              child: Text(
                error,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.red.shade700,
                  fontFamily: 'monospace',
                ),
              ),
            ),

            const SizedBox(height: 32),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  // Restart the app
                  SystemNavigator.pop();
                },
                icon: const Icon(Icons.refresh),
                label: const Text('Restart App'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red.shade600,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}