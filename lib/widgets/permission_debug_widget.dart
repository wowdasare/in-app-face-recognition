// import 'dart:io';
// import 'package:flutter/material.dart';
// import 'package:permission_handler/permission_handler.dart';
//
// class PermissionDebugWidget extends StatefulWidget {
//   @override
//   _PermissionDebugWidgetState createState() => _PermissionDebugWidgetState();
// }
//
// class _PermissionDebugWidgetState extends State<PermissionDebugWidget> {
//   Map<String, String> _permissionStatus = {};
//   String _deviceInfo = '';
//   bool _isLoading = false;
//
//   @override
//   void initState() {
//     super.initState();
//     _checkAllPermissions();
//   }
//
//   Future<void> _checkAllPermissions() async {
//     setState(() => _isLoading = true);
//
//     try {
//       // Get device info
//       final deviceInfo = DeviceInfoPlugin();
//       if (Platform.isAndroid) {
//         final androidInfo = await deviceInfo.androidInfo;
//         _deviceInfo = 'Android ${androidInfo.version.release} (SDK ${androidInfo.version.sdkInt})';
//       } else if (Platform.isIOS) {
//         final iosInfo = await deviceInfo.iosInfo;
//         _deviceInfo = 'iOS ${iosInfo.systemVersion}';
//       }
//
//       // Check permissions
//       Map<String, String> status = {};
//
//       if (Platform.isAndroid) {
//         status['Storage'] = (await Permission.storage.status).toString();
//         status['Photos'] = (await Permission.photos.status).toString();
//         status['Camera'] = (await Permission.camera.status).toString();
//         status['ManageExternalStorage'] = (await Permission.manageExternalStorage.status).toString();
//       } else if (Platform.isIOS) {
//         status['Photos'] = (await Permission.photos.status).toString();
//         status['Camera'] = (await Permission.camera.status).toString();
//       }
//
//       setState(() {
//         _permissionStatus = status;
//         _isLoading = false;
//       });
//     } catch (e) {
//       setState(() {
//         _deviceInfo = 'Error getting device info: $e';
//         _isLoading = false;
//       });
//     }
//   }
//
//   Future<void> _requestPermission(Permission permission) async {
//     final status = await permission.request();
//     await _checkAllPermissions();
//
//     ScaffoldMessenger.of(context).showSnackBar(
//       SnackBar(
//         content: Text('Permission result: ${status.toString()}'),
//         backgroundColor: status.isGranted ? Colors.green : Colors.red,
//       ),
//     );
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(
//         title: Text('Permission Debug'),
//         backgroundColor: Colors.orange,
//       ),
//       body: Padding(
//         padding: EdgeInsets.all(16.0),
//         child: Column(
//           crossAxisAlignment: CrossAxisAlignment.start,
//           children: [
//             // Device Info
//             Card(
//               child: Padding(
//                 padding: EdgeInsets.all(16.0),
//                 child: Column(
//                   crossAxisAlignment: CrossAxisAlignment.start,
//                   children: [
//                     Text(
//                       'Device Information',
//                       style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
//                     ),
//                     SizedBox(height: 8),
//                     Text(_deviceInfo),
//                     Text('Platform: ${Platform.operatingSystem}'),
//                   ],
//                 ),
//               ),
//             ),
//
//             SizedBox(height: 16),
//
//             // Permissions
//             Card(
//               child: Padding(
//                 padding: EdgeInsets.all(16.0),
//                 child: Column(
//                   crossAxisAlignment: CrossAxisAlignment.start,
//                   children: [
//                     Row(
//                       mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                       children: [
//                         Text(
//                           'Permission Status',
//                           style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
//                         ),
//                         IconButton(
//                           onPressed: _checkAllPermissions,
//                           icon: Icon(Icons.refresh),
//                         ),
//                       ],
//                     ),
//                     if (_isLoading)
//                       Center(child: CircularProgressIndicator())
//                     else
//                       ..._permissionStatus.entries.map((entry) =>
//                           ListTile(
//                             title: Text(entry.key),
//                             subtitle: Text(entry.value),
//                             trailing: _getPermissionIcon(entry.value),
//                             onTap: () => _requestPermission(_getPermissionFromName(entry.key)),
//                           ),
//                       ).toList(),
//                   ],
//                 ),
//               ),
//             ),
//
//             SizedBox(height: 16),
//
//             // Action buttons
//             Row(
//               children: [
//                 Expanded(
//                   child: ElevatedButton(
//                     onPressed: () => openAppSettings(),
//                     child: Text('Open App Settings'),
//                   ),
//                 ),
//                 SizedBox(width: 16),
//                 Expanded(
//                   child: ElevatedButton(
//                     onPressed: _requestAllPermissions,
//                     child: Text('Request All'),
//                   ),
//                 ),
//               ],
//             ),
//
//             SizedBox(height: 16),
//
//             // Instructions
//             Card(
//               color: Colors.blue[50],
//               child: Padding(
//                 padding: EdgeInsets.all(16.0),
//                 child: Column(
//                   crossAxisAlignment: CrossAxisAlignment.start,
//                   children: [
//                     Text(
//                       'Instructions:',
//                       style: TextStyle(fontWeight: FontWeight.bold),
//                     ),
//                     SizedBox(height: 8),
//                     Text('1. Check if permissions are granted (green checkmark)'),
//                     Text('2. Tap on any permission to request it'),
//                     Text('3. If denied, use "Open App Settings" to manually enable'),
//                     Text('4. For Android 13+, you need "Photos" permission'),
//                     Text('5. For older Android, you need "Storage" permission'),
//                   ],
//                 ),
//               ),
//             ),
//           ],
//         ),
//       ),
//     );
//   }
//
//   Widget _getPermissionIcon(String status) {
//     if (status.contains('granted')) {
//       return Icon(Icons.check_circle, color: Colors.green);
//     } else if (status.contains('denied')) {
//       return Icon(Icons.cancel, color: Colors.red);
//     } else {
//       return Icon(Icons.help_outline, color: Colors.orange);
//     }
//   }
//
//   Permission _getPermissionFromName(String name) {
//     switch (name) {
//       case 'Storage':
//         return Permission.storage;
//       case 'Photos':
//         return Permission.photos;
//       case 'Camera':
//         return Permission.camera;
//       case 'ManageExternalStorage':
//         return Permission.manageExternalStorage;
//       default:
//         return Permission.storage;
//     }
//   }
//
//   Future<void> _requestAllPermissions() async {
//     setState(() => _isLoading = true);
//
//     if (Platform.isAndroid) {
//       await [
//         Permission.storage,
//         Permission.photos,
//         Permission.camera,
//       ].request();
//     } else if (Platform.isIOS) {
//       await [
//         Permission.photos,
//         Permission.camera,
//       ].request();
//     }
//
//     await _checkAllPermissions();
//   }
// }
