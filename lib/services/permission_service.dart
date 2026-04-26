import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

class PermissionService {
  //  NOTIFICATIONS
  // Call this once when the app first loads (in main.dart or AuthWrapper)
  static Future<void> requestNotificationPermission(BuildContext context) async {
    final status = await Permission.notification.status;
    if (status.isDenied) {
      final result = await Permission.notification.request();
      if (result.isPermanentlyDenied && context.mounted) {
        _showSettingsDialog(
          context,
          title: 'Notifications Disabled',
          message:
              'Enable notifications so ReadLoop can remind you to read daily.',
        );
      }
    }
  }

  // CAMERA (ISBN Scanner)
  // Returns true if permission granted, false otherwise
  static Future<bool> requestCameraPermission(BuildContext context) async {
    final status = await Permission.camera.status;
    if (status.isGranted) return true;

    final result = await Permission.camera.request();
    if (result.isGranted) return true;

    if (result.isPermanentlyDenied && context.mounted) {
      _showSettingsDialog(
        context,
        title: 'Camera Permission Required',
        message: 'ReadLoop needs camera access to scan ISBN barcodes.',
      );
    } else if (result.isDenied && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Camera permission denied. Tap again to retry.'),
          backgroundColor: Colors.orange,
        ),
      );
    }
    return false;
  }

  static Future<bool> requestPhotosPermission(BuildContext context) async {
    // On Android 11 and below, use storage permission
    // On Android 13+, use photos permission
    Permission photoPermission;
    
    if (await Permission.photos.status == PermissionStatus.permanentlyDenied) {
      // Already permanently denied — go straight to settings
      if (context.mounted) {
        _showSettingsDialog(
          context,
          title: 'Photo Access Required',
          message: 'ReadLoop needs access to your photos. Please enable it in Settings.',
        );
      }
      return false;
    }

    // Try storage first (works on Android 11), then photos (Android 13+)
    final storageStatus = await Permission.storage.status;
    if (storageStatus.isGranted) return true;
    
    final storageResult = await Permission.storage.request();
    if (storageResult.isGranted) return true;

    // If storage didn't work, try photos permission (Android 13+)
    final photosResult = await Permission.photos.request();
    if (photosResult.isGranted || photosResult.isLimited) return true;

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Photo permission denied. Go to Settings → Apps → ReadLoop → Permissions → Storage → Allow'),
          backgroundColor: Colors.orange,
          duration: Duration(seconds: 4),
        ),
      );
    }
    return false;
  }

  //  LOCATION (Discover Circles) 
  // Returns true if permission granted, false otherwise
  static Future<bool> requestLocationPermission(BuildContext context) async {
    final status = await Permission.locationWhenInUse.status;
    if (status.isGranted) return true;

    final result = await Permission.locationWhenInUse.request();
    if (result.isGranted) return true;

    if (result.isPermanentlyDenied && context.mounted) {
      _showSettingsDialog(
        context,
        title: 'Location Permission Required',
        message:
            'Enable location so ReadLoop can find reading circles near you.',
      );
    } else if (result.isDenied && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content:
              Text('Location permission denied. Tap the banner to retry.'),
          backgroundColor: Colors.orange,
        ),
      );
    }
    return false;
  }

  //  SETTINGS DIALOG 
  // Shown when permission is permanently denied — directs user to Settings
  static void _showSettingsDialog(
    BuildContext context, {
    required String title,
    required String message,
  }) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Not now'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              openAppSettings(); // Opens phone Settings for this app
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue.shade600,
              foregroundColor: Colors.white,
            ),
            child: const Text('Open Settings'),
          ),
        ],
      ),
    );
  }
}