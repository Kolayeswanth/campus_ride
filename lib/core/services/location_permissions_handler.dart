import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:geolocator/geolocator.dart';
import 'dart:io';

/// Comprehensive permissions handler for background location tracking
class LocationPermissionsHandler {
  static const List<Permission> _requiredPermissions = [
    Permission.location,
    Permission.locationAlways,
    Permission.notification,
  ];

  /// Check if all required permissions are granted
  static Future<bool> hasAllPermissions() async {
    try {
      // Check basic location permission
      final LocationPermission locationPermission = await Geolocator.checkPermission();
      if (locationPermission == LocationPermission.denied ||
          locationPermission == LocationPermission.deniedForever) {
        return false;
      }

      // Check background location permission (Android 10+)
      if (Platform.isAndroid) {
        final androidInfo = await DeviceInfoPlugin().androidInfo;
        if (androidInfo.version.sdkInt >= 29) { // Android 10+
          final backgroundLocation = await Permission.locationAlways.status;
          if (!backgroundLocation.isGranted) {
            return false;
          }
        }
      }

      // Check notification permission (Android 13+)
      if (Platform.isAndroid) {
        final androidInfo = await DeviceInfoPlugin().androidInfo;
        if (androidInfo.version.sdkInt >= 33) { // Android 13+
          final notification = await Permission.notification.status;
          if (!notification.isGranted) {
            return false;
          }
        }
      }

      return true;
    } catch (e) {
      print('❌ Error checking permissions: $e');
      return false;
    }
  }

  /// Request all necessary permissions with user-friendly dialogs
  static Future<bool> requestAllPermissions(BuildContext context) async {
    try {
      print('📋 Requesting location permissions for background tracking');

      // Step 1: Request basic location permission first
      final basicLocationResult = await _requestBasicLocationPermission(context);
      if (!basicLocationResult) {
        return false;
      }

      // Step 2: Request background location permission (Android 10+)
      if (Platform.isAndroid) {
        final androidInfo = await DeviceInfoPlugin().androidInfo;
        if (androidInfo.version.sdkInt >= 29) {
          final backgroundResult = await _requestBackgroundLocationPermission(context);
          if (!backgroundResult) {
            return false;
          }
        }
      }

      // Step 3: Request notification permission (Android 13+)
      if (Platform.isAndroid) {
        final androidInfo = await DeviceInfoPlugin().androidInfo;
        if (androidInfo.version.sdkInt >= 33) {
          final notificationResult = await _requestNotificationPermission(context);
          if (!notificationResult) {
            return false;
          }
        }
      }

      // Step 4: Request battery optimization exemption
      await _requestBatteryOptimizationExemption(context);

      print('✅ All permissions granted successfully');
      return true;

    } catch (e) {
      print('❌ Error requesting permissions: $e');
      return false;
    }
  }

  /// Request basic location permission
  static Future<bool> _requestBasicLocationPermission(BuildContext context) async {
    // Show explanation dialog first
    final shouldRequest = await _showPermissionDialog(
      context,
      'Location Permission Required',
      'Campus Ride needs access to your location to track your bus route and provide real-time updates to passengers.',
      'Allow Location Access',
    );

    if (!shouldRequest) return false;

    // Request using Geolocator for better handling
    LocationPermission permission = await Geolocator.requestPermission();

    if (permission == LocationPermission.denied) {
      await _showPermissionDeniedDialog(
        context,
        'Location Access Denied',
        'Location permission is required for driver navigation and passenger tracking. Please enable it in app settings.',
      );
      return false;
    }

    if (permission == LocationPermission.deniedForever) {
      await _showSettingsDialog(
        context,
        'Location Permission Permanently Denied',
        'Please enable location access in app settings to continue.',
      );
      return false;
    }

    return permission == LocationPermission.whileInUse || permission == LocationPermission.always;
  }

  /// Request background location permission (Android 10+)
  static Future<bool> _requestBackgroundLocationPermission(BuildContext context) async {
    final shouldRequest = await _showPermissionDialog(
      context,
      'Background Location Required',
      'To track your location when the app is closed, Campus Ride needs "Allow all the time" location permission. This ensures passengers get real-time bus updates even when you switch apps.',
      'Enable Background Location',
    );

    if (!shouldRequest) return false;

    final result = await Permission.locationAlways.request();

    if (result.isDenied) {
      await _showPermissionDeniedDialog(
        context,
        'Background Location Denied',
        'Background location is required to track your bus location when the app is not active. Please select "Allow all the time" in the next dialog.',
      );
      // Try again
      final retryResult = await Permission.locationAlways.request();
      return retryResult.isGranted;
    }

    if (result.isPermanentlyDenied) {
      await _showSettingsDialog(
        context,
        'Background Location Blocked',
        'Please go to app settings and change location permission to "Allow all the time".',
      );
      return false;
    }

    return result.isGranted;
  }

  /// Request notification permission (Android 13+)
  static Future<bool> _requestNotificationPermission(BuildContext context) async {
    final shouldRequest = await _showPermissionDialog(
      context,
      'Notification Permission',
      'Campus Ride needs to show notifications to keep you informed about trip status and provide quick actions to end trips.',
      'Allow Notifications',
    );

    if (!shouldRequest) return false;

    final result = await Permission.notification.request();

    if (result.isDenied) {
      await _showPermissionDeniedDialog(
        context,
        'Notifications Disabled',
        'Notifications help you stay informed about your active trips. You can enable them later in app settings.',
      );
    }

    return result.isGranted || result.isDenied; // Don't block on notifications
  }

  /// Request battery optimization exemption
  static Future<void> _requestBatteryOptimizationExemption(BuildContext context) async {
    if (!Platform.isAndroid) return;

    try {
      final shouldRequest = await _showPermissionDialog(
        context,
        'Battery Optimization',
        'To ensure reliable location tracking, please disable battery optimization for Campus Ride. This prevents the system from stopping location updates to save battery.',
        'Optimize Settings',
      );

      if (shouldRequest) {
        // Request to ignore battery optimizations
        final result = await Permission.ignoreBatteryOptimizations.request();
        
        if (result.isDenied || result.isPermanentlyDenied) {
          await _showBatteryOptimizationDialog(context);
        }
      }
    } catch (e) {
      print('❌ Error requesting battery optimization exemption: $e');
    }
  }

  /// Show permission explanation dialog
  static Future<bool> _showPermissionDialog(
    BuildContext context,
    String title,
    String message,
    String confirmText,
  ) async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.blue.shade100,
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.location_on, color: Colors.blue.shade700),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          content: Text(
            message,
            style: const TextStyle(fontSize: 16, height: 1.4),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue.shade600,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: Text(confirmText),
            ),
          ],
        );
      },
    );

    return result ?? false;
  }

  /// Show permission denied dialog
  static Future<void> _showPermissionDeniedDialog(
    BuildContext context,
    String title,
    String message,
  ) async {
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.orange.shade100,
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.warning, color: Colors.orange.shade700),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          content: Text(
            message,
            style: const TextStyle(fontSize: 16, height: 1.4),
          ),
          actions: [
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange.shade600,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
  }

  /// Show settings dialog for permanently denied permissions
  static Future<void> _showSettingsDialog(
    BuildContext context,
    String title,
    String message,
  ) async {
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.red.shade100,
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.settings, color: Colors.red.shade700),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          content: Text(
            message,
            style: const TextStyle(fontSize: 16, height: 1.4),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                openAppSettings();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue.shade600,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: const Text('Open Settings'),
            ),
          ],
        );
      },
    );
  }

  /// Show battery optimization dialog
  static Future<void> _showBatteryOptimizationDialog(BuildContext context) async {
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.green.shade100,
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.battery_full, color: Colors.green.shade700),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Battery Optimization',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          content: const Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'For reliable background location tracking, please:',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
              ),
              SizedBox(height: 12),
              Text(
                '1. Find "Campus Ride" in the battery optimization list\n'
                '2. Tap on it and select "Don\'t optimize"\n'
                '3. This ensures location tracking continues when the app is closed',
                style: TextStyle(fontSize: 14, height: 1.5),
              ),
            ],
          ),
          actions: [
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green.shade600,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: const Text('Got it'),
            ),
          ],
        );
      },
    );
  }

  /// Get permission status summary for debugging
  static Future<Map<String, String>> getPermissionStatus() async {
    final Map<String, String> status = {};

    try {
      // Basic location
      final LocationPermission locationPermission = await Geolocator.checkPermission();
      status['Location'] = locationPermission.name;

      // Background location
      final backgroundLocation = await Permission.locationAlways.status;
      status['Background Location'] = backgroundLocation.name;

      // Notification
      final notification = await Permission.notification.status;
      status['Notifications'] = notification.name;

      // Battery optimization
      final batteryOptimization = await Permission.ignoreBatteryOptimizations.status;
      status['Battery Optimization'] = batteryOptimization.name;

      // Device info
      if (Platform.isAndroid) {
        final androidInfo = await DeviceInfoPlugin().androidInfo;
        status['Android Version'] = 'API ${androidInfo.version.sdkInt}';
      }

    } catch (e) {
      status['Error'] = e.toString();
    }

    return status;
  }
}