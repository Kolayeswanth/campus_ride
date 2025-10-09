import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/bus_route.dart';
import 'ola_maps_service.dart';
import 'real_routing_service.dart';

class LocationTrackingService extends ChangeNotifier {
  static final _instance = LocationTrackingService._internal();
  factory LocationTrackingService() => _instance;
  LocationTrackingService._internal();

  static final _client = Supabase.instance.client;
  static final FlutterLocalNotificationsPlugin _notificationsPlugin = FlutterLocalNotificationsPlugin();
  
  StreamSubscription<Position>? _positionSubscription;
  Timer? _locationUpdateTimer;
  bool _isTracking = false;
  String? _currentTripId;
  
  // Current location and route data
  Position? _currentPosition;
  List<Map<String, double>> _routePolyline = [];
  double _totalDistance = 0.0;
  DateTime? _tripStartTime;

  // Getters
  bool get isTracking => _isTracking;
  String? get currentTripId => _currentTripId;
  Position? get currentPosition => _currentPosition;
  List<Map<String, double>> get routePolyline => _routePolyline;
  double get totalDistance => _totalDistance;
  DateTime? get tripStartTime => _tripStartTime;

  /// Initialize the location tracking service
  static Future<void> initialize() async {
    await _initializeNotifications();
  }

  /// Initialize local notifications
  static Future<void> _initializeNotifications() async {
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    
    const initializationSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _notificationsPlugin.initialize(initializationSettings);
    
    // Create notification channel for Android
    const androidChannel = AndroidNotificationChannel(
      'trip_tracking_channel',
      'Trip Tracking',
      description: 'Notifications for ongoing trips',
      importance: Importance.high,
      playSound: false,
      enableVibration: false,
      showBadge: false,
    );

    await _notificationsPlugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(androidChannel);
  }

  /// Check and request location permissions
  static Future<bool> requestLocationPermission() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        print('Location services are disabled');
        return false;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      print('Current permission: $permission');
      
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        print('Permission after request: $permission');
        if (permission == LocationPermission.denied) {
          print('Location permissions are denied');
          return false;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        print('Location permissions are permanently denied');
        return false;
      }

      // For Android, try to get background location permission
      if (permission == LocationPermission.whileInUse) {
        print('Attempting to get background location permission');
        // Note: This may not work on all Android versions
        // Users might need to manually enable "Always" in app settings
      }

      print('Location permission granted: $permission');
      return permission == LocationPermission.whileInUse || 
             permission == LocationPermission.always;
    } catch (e) {
      print('Error requesting location permission: $e');
      return false;
    }
  }

  /// Start tracking location for a specific trip
  Future<bool> startTracking(String tripId, {Map<String, dynamic>? routeData}) async {
    try {
      // Check location permissions
      final hasPermission = await requestLocationPermission();
      if (!hasPermission) {
        throw Exception('Location permission denied');
      }

      _currentTripId = tripId;
      _isTracking = true;
      _tripStartTime = DateTime.now();
      _totalDistance = 0.0;
      _routePolyline.clear();

      // Get route polyline if route data is provided
      if (routeData != null) {
        await _fetchRoutePolyline(routeData);
      }

      // Start location updates
      await _startLocationUpdates();

      // Show persistent notification
      await _showTrackingNotification();

      // Update trip status in database
      await _updateTripStatus(tripId, 'active');

      return true;
    } catch (e) {
      print('Error starting location tracking: $e');
      _isTracking = false;
      _currentTripId = null;
      return false;
    }
  }

  /// Stop tracking location
  Future<void> stopTracking() async {
    try {
      _isTracking = false;
      
      // Cancel location subscription
      await _positionSubscription?.cancel();
      _positionSubscription = null;
      
      // Cancel timer
      _locationUpdateTimer?.cancel();
      _locationUpdateTimer = null;

      // Hide notification
      await _notificationsPlugin.cancel(1);

      // Update trip status in database
      if (_currentTripId != null) {
        await _updateTripStatus(_currentTripId!, 'completed');
        await _saveTripSummary();
      }

      // Reset tracking data
      _currentTripId = null;
      _currentPosition = null;
      _routePolyline.clear();
      _totalDistance = 0.0;
      _tripStartTime = null;

      notifyListeners();
    } catch (e) {
      print('Error stopping location tracking: $e');
    }
  }

  /// Pause tracking (for temporary stops)
  Future<void> pauseTracking() async {
    if (!_isTracking || _currentTripId == null) return;

    try {
      await _positionSubscription?.cancel();
      _positionSubscription = null;
      
      _locationUpdateTimer?.cancel();
      _locationUpdateTimer = null;

      await _updateTripStatus(_currentTripId!, 'paused');
      await _showPausedNotification();
      notifyListeners();
    } catch (e) {
      print('Error pausing location tracking: $e');
    }
  }

  /// Resume tracking after pause
  Future<void> resumeTracking() async {
    if (!_isTracking || _currentTripId == null) return;

    try {
      await _startLocationUpdates();
      await _updateTripStatus(_currentTripId!, 'active');
      await _showTrackingNotification();
      notifyListeners();
    } catch (e) {
      print('Error resuming location tracking: $e');
    }
  }

  /// Start location updates with high accuracy
  Future<void> _startLocationUpdates() async {
    const locationSettings = LocationSettings(
      accuracy: LocationAccuracy.bestForNavigation,
      distanceFilter: 5, // Update every 5 meters
    );

    _positionSubscription = Geolocator.getPositionStream(
      locationSettings: locationSettings,
    ).listen(
      _onLocationUpdate,
      onError: (error) {
        print('Location stream error: $error');
      },
    );

    // Also set up a timer for regular database updates even if location doesn't change much
    _locationUpdateTimer = Timer.periodic(
      const Duration(seconds: 15),
      (_) => _updateLocationInDatabase(),
    );
  }

  /// Handle location updates
  void _onLocationUpdate(Position position) {
    final previousPosition = _currentPosition;
    _currentPosition = position;

    // Calculate distance traveled
    if (previousPosition != null) {
      final distance = Geolocator.distanceBetween(
        previousPosition.latitude,
        previousPosition.longitude,
        position.latitude,
        position.longitude,
      );
      _totalDistance += distance / 1000; // Convert to kilometers
    }

    // Add to route polyline
    _routePolyline.add({
      'latitude': position.latitude,
      'longitude': position.longitude,
    });

    // Keep only recent polyline points to avoid memory issues
    if (_routePolyline.length > 1000) {
      _routePolyline.removeRange(0, _routePolyline.length - 1000);
    }

    // Update location in database
    _updateLocationInDatabase();
    
    print('🔔 LocationTrackingService notifying listeners - position: ${position.latitude}, ${position.longitude}');
    notifyListeners();
  }

  /// Update current location in database
  Future<void> _updateLocationInDatabase() async {
    if (_currentPosition == null || _currentTripId == null) return;

    try {
      final locationData = {
        'driver_id': _client.auth.currentUser?.id,
        'trip_id': _currentTripId,
        'latitude': _currentPosition!.latitude,
        'longitude': _currentPosition!.longitude,
        'location_timestamp': DateTime.now().toIso8601String(),
      };

      // Add optional fields that might not exist yet
      try {
        locationData.addAll({
          'accuracy_meters': _currentPosition!.accuracy,
          'speed_kmh': (_currentPosition!.speed * 3.6), // Convert m/s to km/h
          'bearing_degrees': _currentPosition!.heading.round(),
          'altitude': _currentPosition!.altitude,
          'is_moving': (_currentPosition!.speed > 0.5), // Moving if speed > 0.5 m/s
        });
      } catch (e) {
        // Optional columns don't exist, continue with basic data
      }

      await _client.from('driver_locations').insert(locationData);
      
      // Also update current trip with latest location
      await _client.from('driver_trips').update({
        'current_latitude': _currentPosition!.latitude,
        'current_longitude': _currentPosition!.longitude,
        'current_speed_kmh': (_currentPosition!.speed * 3.6),
        'bearing_degrees': _currentPosition!.heading.round(),
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', _currentTripId!);
      
    } catch (e) {
      print('Error updating location in database: $e');
      
      // Try fallback to location_history table if driver_locations doesn't exist
      try {
        await _client.from('location_history').insert({
          'trip_id': _currentTripId,
          'latitude': _currentPosition!.latitude,
          'longitude': _currentPosition!.longitude,
          'speed_kmh': (_currentPosition!.speed * 3.6),
          'bearing_degrees': _currentPosition!.heading.round(),
          'accuracy_meters': _currentPosition!.accuracy,
          'recorded_at': DateTime.now().toIso8601String(),
        });
      } catch (fallbackError) {
        print('Fallback location update also failed: $fallbackError');
      }
    }
  }

  /// Fetch route polyline using route_points from database or fallback methods
  Future<void> _fetchRoutePolyline(Map<String, dynamic> routeData) async {
    try {
      final startLat = routeData['start_latitude'];
      final startLng = routeData['start_longitude'];
      final endLat = routeData['end_latitude'];
      final endLng = routeData['end_longitude'];
      final routePoints = routeData['route_points'];
      final polylineData = routeData['polyline_data'];
      final usingDifferentRoute = routeData['using_different_route'] ?? false;
      final isReturnTrip = routeData['is_return_trip'] ?? false;

      print('📍 _fetchRoutePolyline called with data:');
      print('   Start: $startLat, $startLng');
      print('   End: $endLat, $endLng');
      print('   Route points type: ${routePoints?.runtimeType}');
      print('   Route points content: $routePoints');
      print('   Using different route: $usingDifferentRoute');
      print('   Is return trip: $isReturnTrip');

      if (startLat == null || startLng == null || endLat == null || endLng == null) {
        print('⚠️ Missing coordinate data, cannot load route');
        return;
      }

      // Priority 1: Use comprehensive route_points from bus_routes table
      if (routePoints != null) {
        try {
          List<Map<String, double>> points = [];
          
          if (routePoints is List) {
            // Handle route_points as List of coordinate arrays or objects
            for (var point in routePoints) {
              if (point is List && point.length >= 2) {
                // Format: [[lat, lng], [lat, lng], ...]
                points.add({
                  'latitude': point[0].toDouble(),
                  'longitude': point[1].toDouble(),
                });
              } else if (point is Map) {
                // Format: [{"lat": 12.34, "lng": 56.78}, ...]
                final lat = point['lat']?.toDouble() ?? point['latitude']?.toDouble();
                final lng = point['lng']?.toDouble() ?? point['longitude']?.toDouble();
                if (lat != null && lng != null) {
                  points.add({
                    'latitude': lat,
                    'longitude': lng,
                  });
                }
              }
            }
          } else if (routePoints is Map) {
            // Handle route_points as Map object (possibly PostgreSQL JSON)
            print('🔍 Parsing route_points Map object...');
            
            // Try different possible structures in the Map
            if (routePoints.containsKey('coordinates') && routePoints['coordinates'] is List) {
              // Format: {"coordinates": [[lat, lng], [lat, lng], ...]}
              final coordinates = routePoints['coordinates'] as List;
              for (var point in coordinates) {
                if (point is List && point.length >= 2) {
                  points.add({
                    'latitude': point[0].toDouble(),
                    'longitude': point[1].toDouble(),
                  });
                }
              }
            } else if (routePoints.containsKey('points') && routePoints['points'] is List) {
              // Format: {"points": [{"lat": 12.34, "lng": 56.78}, ...]}
              final pointsList = routePoints['points'] as List;
              for (var point in pointsList) {
                if (point is Map) {
                  final lat = point['lat']?.toDouble() ?? point['latitude']?.toDouble();
                  final lng = point['lng']?.toDouble() ?? point['longitude']?.toDouble();
                  if (lat != null && lng != null) {
                    points.add({
                      'latitude': lat,
                      'longitude': lng,
                    });
                  }
                }
              }
            } else {
              // Try to parse the Map directly as a JSON structure
              try {
                final jsonString = json.encode(routePoints);
                final decoded = json.decode(jsonString);
                if (decoded is List) {
                  for (var point in decoded) {
                    if (point is List && point.length >= 2) {
                      points.add({
                        'latitude': point[0].toDouble(),
                        'longitude': point[1].toDouble(),
                      });
                    }
                  }
                }
              } catch (e) {
                print('Error re-parsing route_points Map: $e');
              }
            }
          } else if (routePoints is String && routePoints.isNotEmpty) {
            // Handle route_points as JSON string
            try {
              final decoded = json.decode(routePoints);
              if (decoded is List) {
                for (var point in decoded) {
                  if (point is List && point.length >= 2) {
                    points.add({
                      'latitude': point[0].toDouble(),
                      'longitude': point[1].toDouble(),
                    });
                  }
                }
              }
            } catch (e) {
              print('Error parsing route_points JSON: $e');
            }
          }

          if (points.isNotEmpty) {
            // If this is a return trip and we're not using a different route, reverse the points
            if (isReturnTrip && !usingDifferentRoute) {
              points = points.reversed.toList();
              print('📍 Reversed route points for return trip');
            }
            
            // Validate that we have enough points for proper route visualization
            if (points.length < 5) {
              print('⚠️ Route has only ${points.length} points, fetching enhanced route...');
              // Fall through to fetch a better route
            } else {
              _routePolyline.addAll(points);
              print('📍 ✅ Loaded ${points.length} comprehensive route points from database');
              
              // Validate the route points
              final start = points.first;
              final end = points.last;
              print('📍 Route validation:');
              print('   First point: ${start['latitude']}, ${start['longitude']}');
              print('   Last point: ${end['latitude']}, ${end['longitude']}');
              print('   Total route points: ${points.length}');
              return;
            }
          } else {
            print('⚠️ route_points data exists but no valid coordinates found');
          }
        } catch (e) {
          print('Error processing route_points from database: $e');
        }
      }

      // Priority 2: Use existing polyline_data from database
      if (polylineData != null && polylineData.toString().isNotEmpty) {
        try {
          final points = _decodePolyline(polylineData.toString());
          if (points.isNotEmpty) {
            _routePolyline.addAll(points);
            print('📍 Loaded ${points.length} points from stored polyline data');
            return;
          }
        } catch (e) {
          print('Error decoding stored polyline: $e');
        }
      }

      // Priority 3: Fetch from OLA Maps API as fallback
      print('📍 Fetching route from OLA Maps API...');
      
      final routeResponse = await OlaMapsService.generateRoute(
        start: LatLng(startLat, startLng),
        end: LatLng(endLat, endLng),
      );

      if (routeResponse['route_points'] != null) {
        final routePointsList = routeResponse['route_points'] as List<LatLng>;
        final points = routePointsList.map((point) => {
          'latitude': point.latitude,
          'longitude': point.longitude,
        }).toList();
        
        _routePolyline.addAll(points);
        print('📍 Fetched ${points.length} points from OLA Maps API');
      } else {
        throw Exception('OLA Maps API returned no route points');
      }
    } catch (e) {
      print('Error fetching route polyline: $e');
      // Create a road-following fallback route
      await _createFallbackRoute(routeData);
    }
  }

  Future<void> _createFallbackRoute(Map<String, dynamic> routeData) async {
    try {
      final startLat = routeData['start_latitude'] as double;
      final startLng = routeData['start_longitude'] as double;
      final endLat = routeData['end_latitude'] as double;
      final endLng = routeData['end_longitude'] as double;

      print('📍 Creating road-following fallback route...');
      
      // Try to use RealRoutingService for road-following route
      try {
        final routeResponse = await RealRoutingService.getDirections([
          LatLng(startLat, startLng),
          LatLng(endLat, endLng),
        ]);
        
        if (routeResponse['success'] == true && routeResponse['route_points'] != null) {
          final routePoints = routeResponse['route_points'] as List<LatLng>;
          final points = routePoints.map((point) => {
            'latitude': point.latitude,
            'longitude': point.longitude,
          }).toList();
          
          _routePolyline.addAll(points);
          print('📍 ✅ Created road-following fallback route with ${points.length} points');
          return;
        }
      } catch (e) {
        print('Road routing service failed: $e');
      }
      
      // If road routing fails, create enhanced curved route (not straight line)
      print('📍 Creating enhanced curved fallback route...');
      final points = _generateEnhancedCurvedRoute(
        LatLng(startLat, startLng), 
        LatLng(endLat, endLng)
      );
      
      _routePolyline.addAll(points);
      print('📍 Created enhanced curved route with ${points.length} points');
    } catch (e) {
      print('Error creating fallback route: $e');
      
      // Final fallback - simple straight line
      _createSimpleStraightRoute(routeData);
    }
  }

  /// Generate enhanced curved route that follows road-like patterns
  List<Map<String, double>> _generateEnhancedCurvedRoute(LatLng start, LatLng end) {
    final points = <Map<String, double>>[];
    
    // Calculate distance for number of points
    final distance = _calculateDistance(start.latitude, start.longitude, end.latitude, end.longitude);
    final numPoints = (distance * 10).round().clamp(20, 100); // More points for longer distances
    
    // Add start point
    points.add({'latitude': start.latitude, 'longitude': start.longitude});
    
    // Create curved intermediate points
    for (int i = 1; i < numPoints - 1; i++) {
      final ratio = i / (numPoints - 1);
      
      // Linear interpolation
      var lat = start.latitude + (end.latitude - start.latitude) * ratio;
      var lng = start.longitude + (end.longitude - start.longitude) * ratio;
      
      // Add curve variation (simulate road curvature)
      final curveIntensity = 0.002; // Adjust for more/less curve
      final curveOffset = math.sin(ratio * math.pi * 3) * curveIntensity;
      
      // Apply curve perpendicular to the direct path
      final bearing = math.atan2(end.longitude - start.longitude, end.latitude - start.latitude);
      final perpBearing = bearing + math.pi / 2;
      
      lat += math.cos(perpBearing) * curveOffset;
      lng += math.sin(perpBearing) * curveOffset;
      
      points.add({'latitude': lat, 'longitude': lng});
    }
    
    // Add end point
    points.add({'latitude': end.latitude, 'longitude': end.longitude});
    
    return points;
  }

  /// Simple straight line as absolute final fallback
  void _createSimpleStraightRoute(Map<String, dynamic> routeData) {
    try {
      final startLat = routeData['start_latitude'] as double;
      final startLng = routeData['start_longitude'] as double;
      final endLat = routeData['end_latitude'] as double;
      final endLng = routeData['end_longitude'] as double;

      const int segments = 15;
      for (int i = 0; i <= segments; i++) {
        final ratio = i / segments;
        final lat = startLat + (endLat - startLat) * ratio;
        final lng = startLng + (endLng - startLng) * ratio;
        
        _routePolyline.add({
          'latitude': lat,
          'longitude': lng,
        });
      }
      print('📍 Created simple straight fallback route with ${_routePolyline.length} points');
    } catch (e) {
      print('Error creating simple fallback route: $e');
    }
  }

  /// Calculate distance between two points in kilometers
  double _calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    const double earthRadius = 6371; // Earth radius in kilometers
    final double dLat = _degreesToRadians(lat2 - lat1);
    final double dLon = _degreesToRadians(lon2 - lon1);
    final double a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_degreesToRadians(lat1)) * math.cos(_degreesToRadians(lat2)) *
        math.sin(dLon / 2) * math.sin(dLon / 2);
    final double c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return earthRadius * c;
  }

  double _degreesToRadians(double degrees) {
    return degrees * math.pi / 180;
  }

  /// Decode polyline string to list of coordinates
  List<Map<String, double>> _decodePolyline(String encoded) {
    List<Map<String, double>> points = [];
    int index = 0;
    int len = encoded.length;
    int lat = 0;
    int lng = 0;

    while (index < len) {
      int b, shift = 0, result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      int dlat = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      lat += dlat;

      shift = 0;
      result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      int dlng = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      lng += dlng;

      points.add({
        'latitude': (lat / 1E5),
        'longitude': (lng / 1E5),
      });
    }

    return points;
  }

  /// Show persistent tracking notification
  Future<void> _showTrackingNotification() async {
    const androidDetails = AndroidNotificationDetails(
      'trip_tracking_channel',
      'Trip Tracking',
      channelDescription: 'Ongoing trip tracking',
      importance: Importance.high,
      priority: Priority.high,
      ongoing: true,
      autoCancel: false,
      showWhen: false,
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: false,
      presentBadge: false,
      presentSound: false,
    );

    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _notificationsPlugin.show(
      1,
      'Trip is Live',
      'Your trip location is being shared. Trip in progress to destination.',
      details,
    );
  }

  /// Show paused notification
  Future<void> _showPausedNotification() async {
    const androidDetails = AndroidNotificationDetails(
      'trip_tracking_channel',
      'Trip Tracking',
      channelDescription: 'Trip paused',
      importance: Importance.high,
      priority: Priority.high,
      ongoing: true,
      autoCancel: false,
      showWhen: false,
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: false,
      presentBadge: false,
      presentSound: false,
    );

    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _notificationsPlugin.show(
      1,
      'Trip Paused',
      'Trip is paused. Resume from the app.',
      details,
    );
  }

  /// Update trip status in database using the safe database function
  Future<void> _updateTripStatus(String tripId, String status) async {
    try {
      // Skip paused status until database is updated
      if (status == 'paused') {
        print('Skipping paused status update - enum not available yet');
        return;
      }
      
      // Calculate duration if we have tracking data
      int? durationSeconds;
      if (_tripStartTime != null && (status == 'completed')) {
        durationSeconds = DateTime.now().difference(_tripStartTime!).inSeconds;
      }
      
      // Try using the database function for safe status updates
      try {
        final result = await _client.rpc('update_trip_status', params: {
          'trip_uuid': tripId,
          'new_status': status,
          'duration_seconds': durationSeconds,
        });
        
        if (result == false) {
          throw Exception('Failed to update trip status - not authorized or trip not found');
        }
        return; // Success, exit early
      } catch (rpcError) {
        print('RPC function not available: $rpcError');
        // Continue to fallback
      }
      
      // Fallback to direct table update
      final updateData = <String, dynamic>{
        'status': status,
        'updated_at': DateTime.now().toIso8601String(),
      };
      
      // Add timing fields based on status
      if (status == 'active' && _tripStartTime != null) {
        updateData['started_at'] = _tripStartTime!.toIso8601String();
        updateData['actual_start_time'] = _tripStartTime!.toIso8601String();
      } else if (status == 'completed') {
        updateData['actual_end_time'] = DateTime.now().toIso8601String();
        // Only add duration if column exists
        if (_tripStartTime != null) {
          final durationS = DateTime.now().difference(_tripStartTime!).inSeconds;
          try {
            updateData['total_duration_s'] = durationS;
          } catch (e) {
            print('total_duration_s column not available: $e');
            // Don't include this field if column doesn't exist
            updateData.remove('total_duration_s');
          }
        }
      }
      
      await _client.from('driver_trips').update(updateData).eq('id', tripId);
    } catch (e) {
      print('Error updating trip status: $e');
    }
  }

  /// Save trip summary when completed
  Future<void> _saveTripSummary() async {
    if (_currentTripId == null || _tripStartTime == null) return;

    try {
      final endTime = DateTime.now();
      final duration = endTime.difference(_tripStartTime!).inMinutes;

      // Try to update with new schema columns
      final updateData = <String, dynamic>{
        'actual_end_time': endTime.toIso8601String(),
        'status': 'completed',
      };

      // Add optional new columns if they exist
      try {
        updateData.addAll({
          'total_distance_m': (_totalDistance * 1000).round(), // Convert km to meters
          'trip_distance_km': _totalDistance,
          'total_duration_s': duration * 60, // Convert minutes to seconds
          'route_polyline': json.encode(_routePolyline),
          'average_speed_kmh': duration > 0 ? (_totalDistance / (duration / 60.0)) : 0.0,
          'trip_metadata': json.encode({
            'duration_minutes': duration,
            'total_points': _routePolyline.length,
            'tracking_completed_at': endTime.toIso8601String(),
            'final_distance_km': _totalDistance,
          }),
        });
      } catch (e) {
        // New columns don't exist yet, continue with basic update
      }

      await _client.from('driver_trips').update(updateData).eq('id', _currentTripId!);
    } catch (e) {
      print('Error saving trip summary: $e');
      // Fallback to basic status update
      try {
        await _client.from('driver_trips').update({
          'status': 'completed',
          'actual_end_time': DateTime.now().toIso8601String(),
        }).eq('id', _currentTripId!);
      } catch (fallbackError) {
        print('Fallback trip summary save also failed: $fallbackError');
      }
    }
  }

  /// Get current trip statistics
  Map<String, dynamic> getTripStats() {
    if (!_isTracking || _tripStartTime == null) {
      return {
        'isActive': false,
        'distance': 0.0,
        'duration': 0,
        'averageSpeed': 0.0,
      };
    }

    final duration = DateTime.now().difference(_tripStartTime!).inMinutes;
    final averageSpeed = duration > 0 ? (_totalDistance / (duration / 60.0)) : 0.0;

    return {
      'isActive': true,
      'distance': _totalDistance,
      'duration': duration,
      'averageSpeed': averageSpeed,
      'currentSpeed': _currentPosition?.speed ?? 0.0,
    };
  }

  /// Get today's trip statistics from database
  Future<Map<String, dynamic>> getTodayStats() async {
    try {
      final driverId = _client.auth.currentUser?.id;
      if (driverId == null) return {};

      final result = await _client.rpc('get_driver_trip_stats', params: {
        'driver_uuid': driverId,
        'date_filter': DateTime.now().toIso8601String().split('T')[0], // Today's date
      });

      if (result != null && result.isNotEmpty) {
        final stats = result.first;
        return {
          'totalTrips': stats['total_trips'] ?? 0,
          'totalDistance': stats['total_distance_km'] ?? 0.0,
          'totalDuration': stats['total_duration_minutes'] ?? 0,
          'averageSpeed': stats['average_speed_kmh'] ?? 0.0,
          'activeTripId': stats['active_trip_id'],
        };
      }

      return {};
    } catch (e) {
      print('Error fetching today stats: $e');
      return {};
    }
  }

  /// Get latest driver location
  Future<Map<String, dynamic>?> getLatestLocation() async {
    try {
      final driverId = _client.auth.currentUser?.id;
      if (driverId == null) return null;

      final result = await _client.rpc('get_latest_driver_location', params: {
        'driver_uuid': driverId,
      });

      if (result != null && result.isNotEmpty) {
        return result.first;
      }

      return null;
    } catch (e) {
      print('Error fetching latest location: $e');
      return null;
    }
  }

  /// Clean up resources
  @override
  void dispose() {
    _positionSubscription?.cancel();
    _locationUpdateTimer?.cancel();
    super.dispose();
  }
}
