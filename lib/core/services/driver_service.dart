import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/driver_trip.dart';
import '../models/bus_route.dart';
import 'location_tracking_service.dart';
import 'background_location_service.dart';
import 'location_permissions_handler.dart';

class DriverService {
  static final _client = Supabase.instance.client;

  // Get current driver's profile and assigned route
  static Future<Map<String, dynamic>?> getDriverProfile() async {
    try {
      final user = _client.auth.currentUser;
      if (user == null) return null;

      final profileResponse = await _client
          .from('user_profiles')
          .select('id, display_name, email, phone_number, is_active, employee_id, college_id')
          .eq('id', user.id)
          .eq('role', 'driver')
          .single();

      Map<String, dynamic> driverData = {
        'id': profileResponse['id'],
        'name': profileResponse['display_name'] ?? 'Driver',
        'email': profileResponse['email'] ?? '',
        'phone': profileResponse['phone_number'] ?? '',
        'isActive': profileResponse['is_active'] ?? false,
        'collegeId': profileResponse['college_id'],
        'assignedRoute': null,
      };

      // If driver has an assigned route (stored in employee_id temporarily)
      if (profileResponse['employee_id'] != null) {
        try {
          final routeResponse = await _client
              .from('bus_routes')
              .select('*')
              .eq('id', profileResponse['employee_id'])
              .single();
          
          driverData['assignedRoute'] = BusRoute.fromJson(routeResponse);
        } catch (e) {
          print('Error fetching assigned route: $e');
          // Keep assignedRoute as null if route not found
        }
      }

      return driverData;
    } catch (e) {
      print('Error fetching driver profile: $e');
      return null;
    }
  }

  // Get driver's current active trip
  static Future<DriverTrip?> getCurrentTrip() async {
    try {
      final user = _client.auth.currentUser;
      if (user == null) return null;

      final response = await _client
          .from('driver_trips')
          .select('*, bus_routes(*)')
          .eq('driver_id', user.id)
          .or('status.eq.active,status.eq.scheduled') // Remove paused until enum is added
          .order('created_at', ascending: false)
          .limit(1);

      if (response.isEmpty) return null;

      return DriverTrip.fromJson(response.first);
    } catch (e) {
      print('Error fetching current trip: $e');
      return null;
    }
  }

  // Get driver's trip history
  static Future<List<DriverTrip>> getTripHistory({int limit = 10}) async {
    try {
      final user = _client.auth.currentUser;
      if (user == null) return [];

      final response = await _client
          .from('driver_trips')
          .select('*, bus_routes(*)')
          .eq('driver_id', user.id)
          .order('created_at', ascending: false) // Use created_at as fallback
          .limit(limit);

      return response.map((trip) => DriverTrip.fromJson(trip)).toList();
    } catch (e) {
      print('Error fetching trip history: $e');
      return [];
    }
  }



  // Start a new trip with the assigned route
  static Future<DriverTrip?> startTrip({
    required String routeId,
    String? busNumber,
    TripDirection direction = TripDirection.outbound,
  }) async {
    try {
      final user = _client.auth.currentUser;
      if (user == null) throw Exception('User not authenticated');

      // 1. FIRST: Check background location permissions
      print('🔐 Checking location permissions for background tracking...');
      
      final hasPermissions = await LocationPermissionsHandler.hasAllPermissions();
      if (!hasPermissions) {
        print('⚠️ Background location permissions not fully granted, but continuing with trip');
        print('Note: Background tracking may not work optimally without all permissions');
      } else {
        print('✅ All location permissions granted for background tracking');
      }

      // Get the base route first
      final baseRouteResponse = await _client
          .from('bus_routes')
          .select('*')
          .eq('id', routeId)
          .single();
      
      // For inbound trips, try to find the return route
      // This looks for routes where start/end are swapped
      Map<String, dynamic> routeResponse = baseRouteResponse;
      
      if (direction == TripDirection.inbound) {
        try {
          // Look for a route that goes in the opposite direction
          // (end_name of base route = start_name of return route, and vice versa)
          final returnRoutes = await _client
              .from('bus_routes')
              .select('*')
              .eq('start_name', baseRouteResponse['end_name'])
              .eq('end_name', baseRouteResponse['start_name'])
              .eq('is_active', true);
          
          if (returnRoutes.isNotEmpty) {
            routeResponse = returnRoutes.first;
            print('🔄 Found return route: ${routeResponse['route_name']} (${routeResponse['route_code']})');
          } else {
            print('⚠️ No return route found, using base route with reversed coordinates');
          }
        } catch (e) {
          print('⚠️ Error finding return route: $e, using base route with reversed coordinates');
        }
      }

      final tripData = {
        'driver_id': user.id,
        'route_id': routeId,
        'bus_id': busNumber,
        'status': TripStatus.active.name,
        'trip_type': direction.name, // Use trip_type column
        'started_at': DateTime.now().toIso8601String(),
        'actual_start_time': DateTime.now().toIso8601String(),
        'scheduled_start_time': DateTime.now().toIso8601String(),
      };

      final response = await _client
          .from('driver_trips')
          .insert(tripData)
          .select('*, bus_routes(*)')
          .single();

      final trip = DriverTrip.fromJson(response);

      // 2. Initialize and start background location service
      print('🎯 Starting background location service for trip: ${trip.id}');
      try {
        await BackgroundLocationService.initialize();
        await BackgroundLocationService.startTracking(trip);
        print('✅ Background location service started successfully');
      } catch (e) {
        print('⚠️ Background location service failed to start: $e');
        // Continue with foreground tracking only
      }

      // 3. Start foreground location tracking with route data
      final locationService = LocationTrackingService();
      
      // Check if we found a different route for inbound, or need to reverse coordinates
      Map<String, dynamic> routeData;
      final bool usingDifferentRoute = (direction == TripDirection.inbound && 
                                       routeResponse['id'] != baseRouteResponse['id']);
      
      if (direction == TripDirection.inbound && !usingDifferentRoute) {
        // Using same route but reversed coordinates
        routeData = {
          'start_latitude': routeResponse['end_latitude'], // Reversed
          'start_longitude': routeResponse['end_longitude'], // Reversed
          'end_latitude': routeResponse['start_latitude'], // Reversed
          'end_longitude': routeResponse['start_longitude'], // Reversed
          'polyline_data': routeResponse['polyline_data'],
          'route_points': routeResponse['route_points'],
          'is_return_trip': true,
          'using_different_route': false,
        };
      } else {
        // Using route as-is (either outbound or different inbound route)
        routeData = {
          'start_latitude': routeResponse['start_latitude'],
          'start_longitude': routeResponse['start_longitude'],
          'end_latitude': routeResponse['end_latitude'],
          'end_longitude': routeResponse['end_longitude'],
          'polyline_data': routeResponse['polyline_data'],
          'route_points': routeResponse['route_points'],
          'is_return_trip': direction == TripDirection.inbound,
          'using_different_route': usingDifferentRoute,
        };
      }

      final locationStarted = await locationService.startTracking(
        trip.id,
        routeData: routeData,
      );

      if (!locationStarted) {
        print('Warning: Location tracking failed to start - continuing with trip creation');
        // Note: We continue with trip creation even if location tracking fails
        // The user can still manually manage the trip
      }

      return trip;
    } catch (e) {
      print('Error starting trip: $e');
      throw Exception('Failed to start trip: ${e.toString()}');
    }
  }

  // End current trip
  static Future<bool> endTrip(String tripId, {String? notes}) async {
    try {
      // 1. Stop background location service
      print('🛑 Stopping background location service for trip: $tripId');
      try {
        await BackgroundLocationService.stopTracking();
        print('✅ Background location service stopped successfully');
      } catch (e) {
        print('⚠️ Error stopping background location service: $e');
        // Continue with ending the trip
      }

      // 2. Stop foreground location tracking
      final locationService = LocationTrackingService();
      await locationService.stopTracking();

      // 3. Update trip status in database
      await _client
          .from('driver_trips')
          .update({
            'status': TripStatus.completed.name,
            'actual_end_time': DateTime.now().toIso8601String(),
            'driver_notes': notes,
          })
          .eq('id', tripId);

      print('🏁 Trip $tripId ended successfully');
      return true;
    } catch (e) {
      print('Error ending trip: $e');
      return false;
    }
  }

  // Pause current trip
  static Future<bool> pauseTrip(String tripId) async {
    try {
      // Pause location tracking
      final locationService = LocationTrackingService();
      await locationService.pauseTracking();

      // Use scheduled status as fallback until paused enum is available
      await _client
          .from('driver_trips')
          .update({
            'status': 'scheduled', // Fallback until paused enum is added
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', tripId);

      return true;
    } catch (e) {
      print('Error pausing trip: $e');
      return false;
    }
  }

  // Resume paused trip
  static Future<bool> resumeTrip(String tripId) async {
    try {
      // Resume location tracking
      final locationService = LocationTrackingService();
      await locationService.resumeTracking();

      await _client
          .from('driver_trips')
          .update({
            'status': TripStatus.active.name,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', tripId);

      return true;
    } catch (e) {
      print('Error resuming trip: $e');
      return false;
    }
  }

  // Get today's trip statistics
  static Future<Map<String, dynamic>> getTodayStats() async {
    try {
      final user = _client.auth.currentUser;
      if (user == null) return _emptyStats();

      // Try using the database function first
      try {
        final result = await _client.rpc('get_driver_trip_stats', params: {
          'driver_uuid': user.id,
        });
        return result ?? _emptyStats();
      } catch (e) {
        print('Database function not available, using fallback: $e');
      }

      // Fallback to direct query
      final today = DateTime.now();
      final startOfDay = DateTime(today.year, today.month, today.day);
      final endOfDay = startOfDay.add(const Duration(days: 1));

      final response = await _client
          .from('driver_trips')
          .select('status, created_at, total_distance_m, trip_distance_km') // Use available columns
          .eq('driver_id', user.id)
          .gte('created_at', startOfDay.toIso8601String())
          .lt('created_at', endOfDay.toIso8601String());

      int completedTrips = 0;
      double totalDistance = 0;
      int totalDuration = 0;

      for (final trip in response) {
        if (trip['status'] == TripStatus.completed.name) {
          completedTrips++;
          
          // Try multiple distance fields
          double? distance;
          if (trip['total_distance_m'] != null) {
            distance = (trip['total_distance_m'] as num).toDouble();
          } else if (trip['trip_distance_km'] != null) {
            distance = (trip['trip_distance_km'] as num).toDouble() * 1000; // Convert km to m
          }
          
          if (distance != null) {
            totalDistance += distance;
          }
          
          // Calculate duration from timestamps if total_duration_s not available
          if (trip['total_duration_s'] != null) {
            totalDuration += (trip['total_duration_s'] as num).toInt();
          } else if (trip['actual_end_time'] != null && trip['actual_start_time'] != null) {
            try {
              final endTime = DateTime.parse(trip['actual_end_time']);
              final startTime = DateTime.parse(trip['actual_start_time']);
              totalDuration += endTime.difference(startTime).inSeconds;
            } catch (e) {
              print('Error calculating duration from timestamps: $e');
            }
          }
        }
      }

      final avgSpeed = totalDuration > 0 ? (totalDistance / 1000) / (totalDuration / 3600.0) : 0.0;

      return {
        'totalTrips': response.length,
        'completedTrips': completedTrips,
        'totalDistanceKm': totalDistance / 1000,
        'totalDurationMinutes': totalDuration / 60,
        'avgSpeed': avgSpeed,
      };
    } catch (e) {
      print('Error fetching today stats: $e');
      return _emptyStats();
    }
  }

  static Map<String, dynamic> _emptyStats() {
    return {
      'totalTrips': 0,
      'completedTrips': 0,
      'totalDistanceKm': 0.0,
      'totalDurationMinutes': 0.0,
      'avgSpeed': 0.0,
    };
  }
}