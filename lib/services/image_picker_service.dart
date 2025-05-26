import 'dart:io';
import 'dart:typed_data';

import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';

class ImagePickerService {
  static final ImagePicker _picker = ImagePicker();

  /// Pick image from gallery with permission handling
  static Future<File?> pickImageFromGallery({
    int maxWidth = 1024,
    int maxHeight = 1024,
    int imageQuality = 90,
  }) async {
    try {
      // Request permissions based on platform
      bool hasPermission = await _requestGalleryPermission();

      if (!hasPermission) {
        print('Gallery permission denied');
        return null;
      }

      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: maxWidth.toDouble(),
        maxHeight: maxHeight.toDouble(),
        imageQuality: imageQuality,
      );

      if (image != null) {
        return File(image.path);
      }

      return null;
    } catch (e) {
      print('Error picking image from gallery: $e');
      return null;
    }
  }

  /// Take photo with camera with permission handling
  static Future<File?> takePicture({
    int maxWidth = 1024,
    int maxHeight = 1024,
    int imageQuality = 90,
  }) async {
    try {
      // Request camera permission
      bool hasPermission = await _requestCameraPermission();

      if (!hasPermission) {
        print('Camera permission denied');
        return null;
      }

      final XFile? image = await _picker.pickImage(
        source: ImageSource.camera,
        maxWidth: maxWidth.toDouble(),
        maxHeight: maxHeight.toDouble(),
        imageQuality: imageQuality,
      );

      if (image != null) {
        return File(image.path);
      }

      return null;
    } catch (e) {
      print('Error taking picture: $e');
      return null;
    }
  }

  /// Get image as bytes
  static Future<Uint8List?> getImageBytes(File imageFile) async {
    try {
      return await imageFile.readAsBytes();
    } catch (e) {
      print('Error reading image bytes: $e');
      return null;
    }
  }

  /// Request gallery permission based on platform
  static Future<bool> _requestGalleryPermission() async {
    try {
      if (Platform.isAndroid) {
        // For Android 13+ (API 33+), use photos permission
        var photosStatus = await Permission.photos.status;
        if (photosStatus.isGranted) {
          return true;
        }

        if (photosStatus.isDenied) {
          photosStatus = await Permission.photos.request();
          if (photosStatus.isGranted) {
            return true;
          }
        }

        // Fallback to storage permission for older Android versions
        var storageStatus = await Permission.storage.status;
        if (storageStatus.isGranted) {
          return true;
        }

        if (storageStatus.isDenied) {
          storageStatus = await Permission.storage.request();
          return storageStatus.isGranted;
        }

        return false;
      } else if (Platform.isIOS) {
        var status = await Permission.photos.status;
        if (status.isGranted) {
          return true;
        }

        if (status.isDenied) {
          status = await Permission.photos.request();
          return status.isGranted;
        }

        return false;
      }

      // For other platforms, assume permission is granted
      return true;
    } catch (e) {
      print('Error requesting gallery permission: $e');
      return false;
    }
  }

  /// Request camera permission
  static Future<bool> _requestCameraPermission() async {
    try {
      var status = await Permission.camera.status;
      if (status.isGranted) {
        return true;
      }

      if (status.isDenied) {
        status = await Permission.camera.request();
        return status.isGranted;
      }

      return false;
    } catch (e) {
      print('Error requesting camera permission: $e');
      return false;
    }
  }

  /// Check if all required permissions are granted
  static Future<Map<String, bool>> checkPermissions() async {
    Map<String, bool> permissions = {};

    try {
      permissions['camera'] = await Permission.camera.isGranted;

      if (Platform.isAndroid) {
        permissions['photos'] = await Permission.photos.isGranted;
        permissions['storage'] = await Permission.storage.isGranted;
      } else if (Platform.isIOS) {
        permissions['photos'] = await Permission.photos.isGranted;
      }
    } catch (e) {
      print('Error checking permissions: $e');
    }

    return permissions;
  }

  /// Open app settings for manual permission management
  static Future<void> openAppSettings() async {
    try {
      await openAppSettings();
    } catch (e) {
      print('Error opening app settings: $e');
    }
  }
}
