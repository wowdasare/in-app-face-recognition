import 'package:flutter/material.dart';

import 'widgets/face_recognition_widget.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Face Recognition App',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: FaceRecognitionWidget(),
    );
  }
}
