import 'package:permission_handler/permission_handler.dart';

class CameraPermissionService {
  static Future<bool> requestCameraPermission() async {
    var status = await Permission.camera.status;

    if (status.isDenied) {
      // Request permission
      status = await Permission.camera.request();
    }

    return status.isGranted;
  }

  static Future<bool> requestStoragePermission() async {
    var status = await Permission.storage.status;

    if (status.isDenied) {
      // Request permission
      status = await Permission.storage.request();
    }

    return status.isGranted;
  }

  static Future<bool> requestPhotosPermission() async {
    var status = await Permission.photos.status;

    if (status.isDenied) {
      // Request permission
      status = await Permission.photos.request();
    }

    return status.isGranted;
  }

  static Future<Map<String, bool>> requestAllPermissions() async {
    final results =
        await [
          Permission.camera,
          Permission.photos,
          Permission.storage,
        ].request();

    return {
      'camera': results[Permission.camera]?.isGranted ?? false,
      'photos': results[Permission.photos]?.isGranted ?? false,
      'storage': results[Permission.storage]?.isGranted ?? false,
    };
  }
}
