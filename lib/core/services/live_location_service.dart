import 'dart:async';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

/// Service for managing live location tracking with high-precision GPS
/// Provides continuous location updates for driver navigation
class LiveLocationService {
  static LiveLocationService? _instance;
  static LiveLocationService get instance => _instance ??= LiveLocationService._internal();
  
  LiveLocationService._internal();

  // Stream controllers
  final StreamController<Position> _positionStreamController = StreamController<Position>.broadcast();
  final StreamController<LocationServiceStatus> _serviceStatusController = StreamController<LocationServiceStatus>.broadcast();
  
  // Current state
  Position? _currentPosition;
  StreamSubscription<Position>? _positionSubscription;
  StreamSubscription<ServiceStatus>? _serviceStatusSubscription;
  bool _isTracking = false;
  Timer? _fallbackTimer;

  // Configuration for ultra-fast live location updates
  static const LocationSettings _locationSettings = LocationSettings(
    accuracy: LocationAccuracy.bestForNavigation, // Maximum precision for navigation
    distanceFilter: 0, // Update on any movement (no distance filter for live updates)  
    timeLimit: Duration(seconds: 2), // Ultra-fast location acquisition (2s max)
  );

  // Android-specific high-frequency GPS settings
  static final AndroidSettings _androidSettings = AndroidSettings(
    accuracy: LocationAccuracy.bestForNavigation,
    distanceFilter: 0,
    intervalDuration: Duration(milliseconds: 500), // Ultra fast updates
    forceLocationManager: true, // Use GPS directly
  );

  // Getters
  Stream<Position> get positionStream => _positionStreamController.stream;
  Stream<LocationServiceStatus> get serviceStatusStream => _serviceStatusController.stream;
  Position? get currentPosition => _currentPosition;
  bool get isTracking => _isTracking;

  /// Initialize location services and request permissions
  Future<bool> initialize() async {
    try {
      if (kDebugMode) {
        print('📍 Initializing live location service...');
      }

      // Check if location services are enabled
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (kDebugMode) {
          print('❌ Location services are disabled');
        }
        _serviceStatusController.add(LocationServiceStatus.disabled);
        return false;
      }

      // Check and request permissions
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          if (kDebugMode) {
            print('❌ Location permissions denied');
          }
          _serviceStatusController.add(LocationServiceStatus.permissionDenied);
          return false;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        if (kDebugMode) {
          print('❌ Location permissions permanently denied');
        }
        _serviceStatusController.add(LocationServiceStatus.permissionDenied);
        return false;
      }

      // Get initial position
      try {
        _currentPosition = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.bestForNavigation,
          timeLimit: const Duration(seconds: 10),
        );
        
        if (kDebugMode && _currentPosition != null) {
          print('📍 Initial position: ${_currentPosition!.latitude}, ${_currentPosition!.longitude}');
          print('📍 Accuracy: ${_currentPosition!.accuracy}m');
        }
      } catch (e) {
        if (kDebugMode) {
          print('⚠️ Could not get initial position: $e');
        }
      }

      // Listen to service status changes
      _serviceStatusSubscription = Geolocator.getServiceStatusStream().listen(
        (ServiceStatus status) {
          if (kDebugMode) {
            print('📍 Location service status changed: $status');
          }
          
          switch (status) {
            case ServiceStatus.enabled:
              _serviceStatusController.add(LocationServiceStatus.enabled);
              break;
            case ServiceStatus.disabled:
              _serviceStatusController.add(LocationServiceStatus.disabled);
              _stopTracking();
              break;
          }
        },
      );

      _serviceStatusController.add(LocationServiceStatus.enabled);
      
      if (kDebugMode) {
        print('✅ Live location service initialized successfully');
      }
      
      return true;
    } catch (e) {
      if (kDebugMode) {
        print('❌ Failed to initialize location service: $e');
      }
      _serviceStatusController.add(LocationServiceStatus.error);
      return false;
    }
  }

  /// Start continuous location tracking
  Future<bool> startTracking() async {
    if (_isTracking) {
      if (kDebugMode) {
        print('📍 Location tracking already active');
      }
      return true;
    }

    try {
      if (kDebugMode) {
        print('📍 Starting continuous location tracking...');
      }

      // Start position stream with platform-specific optimizations
      _positionSubscription = Geolocator.getPositionStream(
        locationSettings: Platform.isAndroid ? _androidSettings : _locationSettings,
      ).listen(
        (Position position) {
          _handlePositionUpdate(position);
        },
        onError: (error) {
          if (kDebugMode) {
            print('❌ Position stream error: $error');
          }
          _handleLocationError(error);
        },
      );

      // Start fallback timer for cases where GPS might be slow
      _startFallbackTimer();
      
      _isTracking = true;
      
      if (kDebugMode) {
        print('✅ Location tracking started successfully');
      }
      
      return true;
    } catch (e) {
      if (kDebugMode) {
        print('❌ Failed to start location tracking: $e');
      }
      return false;
    }
  }

  /// Stop location tracking
  void stopTracking() {
    _stopTracking();
    if (kDebugMode) {
      print('📍 Location tracking stopped');
    }
  }

  void _stopTracking() {
    _positionSubscription?.cancel();
    _positionSubscription = null;
    _fallbackTimer?.cancel();
    _fallbackTimer = null;
    _isTracking = false;
  }

  /// Handle position updates
  void _handlePositionUpdate(Position position) {
    _currentPosition = position;
    _positionStreamController.add(position);
    
    if (kDebugMode) {
      // Only log every 10th position to avoid spam
      if (DateTime.now().millisecondsSinceEpoch % 10000 < 1000) {
        print('📍 Position update: ${position.latitude.toStringAsFixed(6)}, ${position.longitude.toStringAsFixed(6)} ±${position.accuracy.toStringAsFixed(1)}m');
      }
    }
  }

  /// Handle location errors
  void _handleLocationError(dynamic error) {
    if (kDebugMode) {
      print('❌ Location error: $error');
    }
    
    _serviceStatusController.add(LocationServiceStatus.error);
    
    // Try to restart tracking after a delay
    Future.delayed(const Duration(seconds: 5), () {
      if (_isTracking) {
        startTracking();
      }
    });
  }

  /// Start fallback timer to periodically request location
  void _startFallbackTimer() {
    _fallbackTimer = Timer.periodic(const Duration(seconds: 5), (timer) async {
      try {
        if (_isTracking && _currentPosition == null) {
          final position = await Geolocator.getCurrentPosition(
            desiredAccuracy: LocationAccuracy.high,
            timeLimit: const Duration(seconds: 3),
          );
          _handlePositionUpdate(position);
        }
      } catch (e) {
        // Ignore fallback errors
      }
    });
  }

  /// Get current location with timeout
  Future<Position?> getCurrentLocation({Duration? timeout}) async {
    try {
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.bestForNavigation,
        timeLimit: timeout ?? const Duration(seconds: 10),
      );
      
      _currentPosition = position;
      return position;
    } catch (e) {
      if (kDebugMode) {
        print('❌ Failed to get current location: $e');
      }
      return _currentPosition; // Return last known position
    }
  }

  /// Calculate distance between current position and target
  double? getDistanceTo(LatLng target) {
    if (_currentPosition == null) return null;
    
    return Geolocator.distanceBetween(
      _currentPosition!.latitude,
      _currentPosition!.longitude,
      target.latitude,
      target.longitude,
    );
  }

  /// Calculate bearing from current position to target
  double? getBearingTo(LatLng target) {
    if (_currentPosition == null) return null;
    
    return Geolocator.bearingBetween(
      _currentPosition!.latitude,
      _currentPosition!.longitude,
      target.latitude,
      target.longitude,
    );
  }

  /// Convert Position to LatLng
  static LatLng positionToLatLng(Position position) {
    return LatLng(position.latitude, position.longitude);
  }

  /// Dispose resources
  void dispose() {
    _stopTracking();
    _serviceStatusSubscription?.cancel();
    _positionStreamController.close();
    _serviceStatusController.close();
    _instance = null;
    
    if (kDebugMode) {
      print('📍 Live location service disposed');
    }
  }
}

/// Status of location services
enum LocationServiceStatus {
  enabled,
  disabled,
  permissionDenied,
  error,
}
