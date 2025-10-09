import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:geolocator/geolocator.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/driver_trip.dart';

/// Background Location Service for continuous GPS tracking when app is closed
/// Runs as a foreground service with persistent notification
class BackgroundLocationService {
  static const String channelId = 'campus_ride_location_channel';
  static const String channelName = 'Campus Ride Location Tracking';
  static const int notificationId = 888;
  
  static final FlutterLocalNotificationsPlugin _notifications = 
      FlutterLocalNotificationsPlugin();
  
  static bool _isInitialized = false;
  static Timer? _locationTimer;
  static String? _currentTripId;
  static String? _routeName;

  /// Initialize the background service
  static Future<void> initialize() async {
    if (_isInitialized) return;

    print('🚀 Initializing Background Location Service');

    final service = FlutterBackgroundService();

    // Create notification channel
    await _createNotificationChannel();

    await service.configure(
      iosConfiguration: IosConfiguration(
        autoStart: false,
        onForeground: _onStart,
        onBackground: _onIosBackground,
      ),
      androidConfiguration: AndroidConfiguration(
        onStart: _onStart,
        isForegroundMode: true,
        autoStart: false,
        autoStartOnBoot: false,
        notificationChannelId: channelId,
        initialNotificationTitle: 'Campus Ride Driver',
        initialNotificationContent: 'Location tracking initialized',
        foregroundServiceNotificationId: notificationId,
      ),
    );

    _isInitialized = true;
    print('✅ Background Location Service initialized');
  }

  /// Create notification channel for location tracking
  static Future<void> _createNotificationChannel() async {
    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      channelId,
      channelName,
      description: 'Tracks driver location during active trips',
      importance: Importance.high,
      enableVibration: false,
      playSound: false,
    );

    await _notifications
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);
  }

  /// Start location tracking for a specific trip
  static Future<void> startTracking(DriverTrip trip) async {
    if (!_isInitialized) {
      await initialize();
    }

    print('🎯 Starting background location tracking for trip: ${trip.id}');

    _currentTripId = trip.id;
    _routeName = trip.route?.routeName ?? 'Campus Route';

    // Save trip info to shared preferences for background access
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('active_trip_id', trip.id);
    await prefs.setString('active_route_name', _routeName!);
    await prefs.setString('trip_start_time', trip.startedAt.toIso8601String());

    // Start the background service
    final service = FlutterBackgroundService();
    final isRunning = await service.isRunning();
    
    if (!isRunning) {
      await service.startService();
    }

    // Send trip data to background service
    service.invoke('startLocationTracking', {
      'tripId': trip.id,
      'routeName': _routeName,
      'startTime': trip.startedAt.toIso8601String(),
    });

    print('✅ Background location tracking started');
  }

  /// Stop location tracking
  static Future<void> stopTracking() async {
    print('🛑 Stopping background location tracking');

    _locationTimer?.cancel();
    _locationTimer = null;
    _currentTripId = null;
    _routeName = null;

    // Clear shared preferences
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('active_trip_id');
    await prefs.remove('active_route_name');
    await prefs.remove('trip_start_time');

    // Stop the background service
    final service = FlutterBackgroundService();
    service.invoke('stopLocationTracking');
    
    // Cancel notification
    await _notifications.cancel(notificationId);

    print('✅ Background location tracking stopped');
  }

  /// Check if location tracking is currently active
  static Future<bool> isTracking() async {
    final prefs = await SharedPreferences.getInstance();
    final activeTripId = prefs.getString('active_trip_id');
    return activeTripId != null;
  }

  /// Get current active trip info
  static Future<Map<String, dynamic>?> getActiveTripInfo() async {
    final prefs = await SharedPreferences.getInstance();
    final tripId = prefs.getString('active_trip_id');
    final routeName = prefs.getString('active_route_name');
    final startTime = prefs.getString('trip_start_time');

    if (tripId != null) {
      return {
        'tripId': tripId,
        'routeName': routeName,
        'startTime': startTime,
      };
    }

    return null;
  }

  /// Background service entry point
  @pragma('vm:entry-point')
  static void _onStart(ServiceInstance service) async {
    print('🔄 Background service started');

    // Register message handler
    service.on('startLocationTracking').listen((event) async {
      final data = event!;
      await _startLocationUpdates(service, data);
    });

    service.on('stopLocationTracking').listen((event) async {
      await _stopLocationUpdates(service);
    });

    // Initialize Supabase for background operations
    try {
      await _initializeSupabaseForBackground();
      print('✅ Supabase initialized in background service');
    } catch (e) {
      print('❌ Failed to initialize Supabase in background: $e');
    }
  }

  /// iOS background handler
  @pragma('vm:entry-point')
  static Future<bool> _onIosBackground(ServiceInstance service) async {
    print('📱 iOS background mode activated');
    return true;
  }

  /// Initialize Supabase for background operations
  static Future<void> _initializeSupabaseForBackground() async {
    // Read Supabase config from shared preferences (set during app initialization)
    final prefs = await SharedPreferences.getInstance();
    final supabaseUrl = prefs.getString('supabase_url') ?? 
        const String.fromEnvironment('SUPABASE_URL', defaultValue: '');
    final supabaseAnonKey = prefs.getString('supabase_anon_key') ?? 
        const String.fromEnvironment('SUPABASE_ANON_KEY', defaultValue: '');

    if (supabaseUrl.isEmpty || supabaseAnonKey.isEmpty) {
      throw Exception('Supabase configuration not found for background service');
    }

    await Supabase.initialize(
      url: supabaseUrl,
      anonKey: supabaseAnonKey,
      debug: false, // Disable debug in background
    );
  }

  /// Start location updates in background
  static Future<void> _startLocationUpdates(ServiceInstance service, Map<String, dynamic> tripData) async {
    final tripId = tripData['tripId'] as String;
    final routeName = tripData['routeName'] as String;

    print('📍 Starting location updates for trip: $tripId');

    _locationTimer?.cancel();
    _locationTimer = Timer.periodic(const Duration(seconds: 15), (timer) async {
      await _sendLocationUpdate(service, tripId, routeName);
    });

    // Send initial location
    await _sendLocationUpdate(service, tripId, routeName);
  }

  /// Stop location updates in background
  static Future<void> _stopLocationUpdates(ServiceInstance service) async {
    print('🛑 Stopping background location updates');
    _locationTimer?.cancel();
    _locationTimer = null;
    
    // Update notification to show stopped status
    await _updateNotification(
      'Trip Ended',
      'Location tracking stopped',
      showStopButton: false,
    );

    // Auto-remove notification after 3 seconds
    Timer(const Duration(seconds: 3), () async {
      await _notifications.cancel(notificationId);
      service.stopSelf();
    });
  }

  /// Send location update to Supabase
  static Future<void> _sendLocationUpdate(ServiceInstance service, String tripId, String routeName) async {
    try {
      // Get current location
      final Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      print('📍 Background location: ${position.latitude}, ${position.longitude}');

      // Calculate bearing if we have previous position
      double? bearing;
      final prefs = await SharedPreferences.getInstance();
      final prevLat = prefs.getDouble('prev_latitude');
      final prevLng = prefs.getDouble('prev_longitude');

      if (prevLat != null && prevLng != null) {
        bearing = Geolocator.bearingBetween(
          prevLat, prevLng, 
          position.latitude, position.longitude,
        );
      }

      // Save current position for next bearing calculation
      await prefs.setDouble('prev_latitude', position.latitude);
      await prefs.setDouble('prev_longitude', position.longitude);

      // Update Supabase with new location
      await _updateLocationInDatabase(tripId, position, bearing);

      // Update notification with current status
      final duration = _getTripDuration();
      await _updateNotification(
        'Active Trip - $routeName',
        'Location updated • $duration • ${position.speed.toStringAsFixed(0)} km/h',
        showStopButton: true,
      );

      // Notify foreground app if running
      service.invoke('locationUpdate', {
        'latitude': position.latitude,
        'longitude': position.longitude,
        'speed': position.speed * 3.6, // Convert m/s to km/h
        'bearing': bearing,
        'timestamp': DateTime.now().toIso8601String(),
      });

    } catch (e) {
      print('❌ Error sending location update: $e');
      
      // Update notification with error status
      await _updateNotification(
        'Location Error - $routeName',
        'Failed to get location • Check GPS settings',
        showStopButton: true,
      );
    }
  }

  /// Update location in Supabase database
  static Future<void> _updateLocationInDatabase(String tripId, Position position, double? bearing) async {
    try {
      final supabase = Supabase.instance.client;

      // Insert into driver_locations table
      await supabase.from('driver_locations').insert({
        'trip_id': tripId,
        'latitude': position.latitude,
        'longitude': position.longitude,
        'speed_kmh': position.speed * 3.6, // Convert m/s to km/h
        'bearing_degrees': bearing?.round(),
        'location_timestamp': DateTime.now().toIso8601String(),
        'accuracy_meters': position.accuracy,
      });

      // Update driver_trips table with current position
      await supabase.from('driver_trips').update({
        'current_latitude': position.latitude,
        'current_longitude': position.longitude,
        'current_speed_kmh': position.speed * 3.6,
        'bearing_degrees': bearing?.round(),
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', tripId);

      print('✅ Location updated in database');

    } catch (e) {
      print('❌ Database update failed: $e');
      // Don't throw - continue with location tracking even if database fails
    }
  }

  /// Get trip duration string
  static String _getTripDuration() {
    try {
      final prefs = SharedPreferences.getInstance();
      prefs.then((prefs) {
        final startTimeStr = prefs.getString('trip_start_time');
        if (startTimeStr != null) {
          final startTime = DateTime.parse(startTimeStr);
          final duration = DateTime.now().difference(startTime);
          
          if (duration.inHours > 0) {
            return '${duration.inHours}h ${duration.inMinutes % 60}m';
          } else {
            return '${duration.inMinutes}m';
          }
        }
      });
      return 'Active';
    } catch (e) {
      return 'Active';
    }
  }

  /// Update persistent notification
  static Future<void> _updateNotification(String title, String body, {bool showStopButton = false}) async {
    const NotificationDetails notificationDetails = NotificationDetails(
      android: AndroidNotificationDetails(
        channelId,
        channelName,
        channelDescription: 'Tracks driver location during active trips',
        importance: Importance.high,
        priority: Priority.high,
        ongoing: true,
        autoCancel: false,
        showWhen: true,
        icon: '@mipmap/ic_launcher',
        color: Color(0xFF3B82F6), // Blue color
      ),
    );

    await _notifications.show(
      notificationId,
      title,
      body,
      notificationDetails,
    );
  }

  /// Handle notification actions
  static Future<void> handleNotificationAction(String action) async {
    switch (action) {
      case 'stop_trip':
        await stopTracking();
        // TODO: Also end the trip in the database
        break;
      case 'open_app':
        // The app will open automatically when notification is tapped
        break;
    }
  }
}