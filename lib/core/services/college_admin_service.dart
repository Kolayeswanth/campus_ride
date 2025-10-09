import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/bus_route.dart';

class CollegeAdminService {
  static final _client = Supabase.instance.client;

  // Get current user's college ID
  static Future<String?> getCurrentUserCollegeId() async {
    try {
      final user = _client.auth.currentUser;
      if (user == null) return null;

      final response = await _client
          .from('user_profiles')
          .select('college_id')
          .eq('id', user.id)
          .single();

      return response['college_id'];
    } catch (e) {
      print('Error getting user college ID: $e');
      return null;
    }
  }

  // Dashboard Stats for College Admin
  static Future<Map<String, dynamic>> getDashboardStats() async {
    try {
      final collegeId = await getCurrentUserCollegeId();
      if (collegeId == null) {
        return {
          'activeDrivers': 0,
          'totalRoutes': 0,
          'activeTrips': 0,
          'totalStudents': 0,
        };
      }

      // Get active drivers in this college
      final driversResponse = await _client
          .from('user_profiles')
          .select('id')
          .eq('role', 'driver')
          .eq('college_id', collegeId)
          .eq('is_active', true)
          .count(CountOption.exact);

      // Get total routes for this college
      final routesResponse = await _client
          .from('bus_routes')
          .select('id')
          .eq('college_id', collegeId)
          .eq('is_active', true)
          .count(CountOption.exact);

      // Get active trips for this college's routes
      final activeTripsResponse = await _client
          .from('driver_trips')
          .select('id, bus_routes!inner(college_id)')
          .eq('status', 'active')
          .eq('bus_routes.college_id', collegeId)
          .count(CountOption.exact);

      // Get total students/passengers in this college
      final studentsResponse = await _client
          .from('user_profiles')
          .select('id')
          .eq('role', 'passenger')
          .eq('college_id', collegeId)
          .eq('is_active', true)
          .count(CountOption.exact);

      return {
        'activeDrivers': driversResponse.count,
        'totalRoutes': routesResponse.count,
        'activeTrips': activeTripsResponse.count,
        'totalStudents': studentsResponse.count,
      };
    } catch (e) {
      print('Error fetching dashboard stats: $e');
      return {
        'activeDrivers': 0,
        'totalRoutes': 0,
        'activeTrips': 0,
        'totalStudents': 0,
      };
    }
  }

  // Get recent activity for college
  static Future<List<Map<String, dynamic>>> getRecentActivity() async {
    try {
      final collegeId = await getCurrentUserCollegeId();
      if (collegeId == null) return [];

      List<Map<String, dynamic>> activities = [];

      // Get recent driver registrations
      final recentDrivers = await _client
          .from('user_profiles')
          .select('display_name, created_at')
          .eq('role', 'driver')
          .eq('college_id', collegeId)
          .order('created_at', ascending: false)
          .limit(3);

      for (var driver in recentDrivers) {
        activities.add({
          'type': 'driver_registered',
          'title': 'New Driver Registered',
          'subtitle': '${driver['display_name'] ?? 'Driver'} joined the system',
          'time': _formatTimeAgo(DateTime.parse(driver['created_at'])),
          'icon': 'person_add',
          'color': 'green',
        });
      }

      // Get recent route updates
      final recentRoutes = await _client
          .from('bus_routes')
          .select('route_name, updated_at')
          .eq('college_id', collegeId)
          .order('updated_at', ascending: false)
          .limit(3);

      for (var route in recentRoutes) {
        activities.add({
          'type': 'route_updated',
          'title': 'Route Updated',
          'subtitle': '${route['route_name']} route was modified',
          'time': _formatTimeAgo(DateTime.parse(route['updated_at'])),
          'icon': 'route',
          'color': 'blue',
        });
      }

      // Get recent completed trips
      final recentTrips = await _client
          .from('driver_trips')
          .select('''
            actual_end_time,
            bus_routes!inner(route_name, college_id)
          ''')
          .eq('status', 'completed')
          .eq('bus_routes.college_id', collegeId)
          .order('actual_end_time', ascending: false)
          .limit(2);

      for (var trip in recentTrips) {
        activities.add({
          'type': 'trip_completed',
          'title': 'Trip Completed',
          'subtitle': '${trip['bus_routes']['route_name']} route completed',
          'time': _formatTimeAgo(DateTime.parse(trip['actual_end_time'])),
          'icon': 'check_circle',
          'color': 'orange',
        });
      }

      // Sort by time and return top 5
      activities.sort((a, b) => a['time'].toString().compareTo(b['time'].toString()));
      return activities.take(5).toList();
    } catch (e) {
      print('Error fetching recent activity: $e');
      return [];
    }
  }

  // Get drivers for this college
  static Future<List<Map<String, dynamic>>> getCollegeDrivers() async {
    try {
      final collegeId = await getCurrentUserCollegeId();
      if (collegeId == null) return [];

      final response = await _client
          .from('user_profiles')
          .select('id, display_name, email, phone_number, is_active, created_at, employee_id')
          .eq('role', 'driver')
          .eq('college_id', collegeId)
          .order('created_at', ascending: false);

      // Now manually fetch route information for drivers who have assignments
      List<Map<String, dynamic>> driversWithRoutes = [];
      
      for (final driver in response) {
        Map<String, dynamic> driverData = {
          'id': driver['id'],
          'name': driver['display_name'] ?? 'Unknown Driver',
          'email': driver['email'] ?? '',
          'phone': driver['phone_number'] ?? '',
          'isActive': driver['is_active'] ?? false,
          'joinDate': _formatDate(DateTime.parse(driver['created_at'])),
          'assignedRoute': null,
        };

        // If driver has an assigned route (stored in employee_id temporarily)
        if (driver['employee_id'] != null) {
          try {
            final routeResponse = await _client
                .from('bus_routes')
                .select('id, route_name, route_code')
                .eq('id', driver['employee_id'])
                .single();
            
            driverData['assignedRoute'] = routeResponse;
          } catch (e) {
            print('Error fetching route for driver ${driver['id']}: $e');
            // Keep assignedRoute as null if route not found
          }
        }

        driversWithRoutes.add(driverData);
      }

      return driversWithRoutes;
    } catch (e) {
      print('Error fetching college drivers: $e');
      return [];
    }
  }

  // Get routes for this college
  static Future<List<Map<String, dynamic>>> getCollegeRoutes() async {
    try {
      final collegeId = await getCurrentUserCollegeId();
      if (collegeId == null) return [];

      final response = await _client
          .from('bus_routes')
          .select('id, route_name, route_code, start_name, end_name, is_active')
          .eq('college_id', collegeId)
          .order('route_name');

      return response.map<Map<String, dynamic>>((route) => {
        'id': route['id'],
        'routeName': route['route_name'] ?? 'Unknown Route',
        'routeCode': route['route_code'] ?? '',
        'startName': route['start_name'] ?? '',
        'endName': route['end_name'] ?? '',
        'isActive': route['is_active'] ?? false,
      }).toList();
    } catch (e) {
      print('Error fetching college routes: $e');
      return [];
    }
  }

  // Get active trips for this college
  static Future<List<Map<String, dynamic>>> getActiveTrips() async {
    try {
      final collegeId = await getCurrentUserCollegeId();
      if (collegeId == null) return [];

      final response = await _client
          .from('driver_trips')
          .select('''
            id,
            status,
            current_latitude,
            current_longitude,
            passenger_count,
            bus_number,
            bus_routes!inner(route_name, college_id),
            user_profiles!inner(display_name)
          ''')
          .eq('status', 'active')
          .eq('bus_routes.college_id', collegeId);

      return response.map<Map<String, dynamic>>((trip) => {
        'id': trip['id'],
        'routeName': trip['bus_routes']['route_name'] ?? 'Unknown Route',
        'driverName': trip['user_profiles']['display_name'] ?? 'Unknown Driver',
        'busNumber': trip['bus_number'] ?? 'N/A',
        'passengerCount': trip['passenger_count'] ?? 0,
        'latitude': trip['current_latitude'],
        'longitude': trip['current_longitude'],
      }).toList();
    } catch (e) {
      print('Error fetching active trips: $e');
      return [];
    }
  }

  // Get analytics data for this college
  static Future<Map<String, dynamic>> getAnalyticsData() async {
    try {
      final collegeId = await getCurrentUserCollegeId();
      if (collegeId == null) return {};

      // Get trip analytics for the last 30 days
      final thirtyDaysAgo = DateTime.now().subtract(const Duration(days: 30));
      
      final response = await _client
          .from('trip_analytics')
          .select('''
            actual_duration_minutes,
            distance_covered_km,
            passenger_count,
            delay_minutes,
            date,
            bus_routes!inner(college_id)
          ''')
          .eq('bus_routes.college_id', collegeId)
          .gte('date', thirtyDaysAgo.toIso8601String().split('T')[0]);

      if (response.isEmpty) {
        return {
          'totalTrips': 0,
          'averageDuration': 0,
          'totalDistance': 0,
          'averagePassengers': 0,
          'averageDelay': 0,
        };
      }

      final totalTrips = response.length;
      final totalDuration = response.fold<int>(0, (sum, item) => sum + ((item['actual_duration_minutes'] as num?) ?? 0).toInt());
      final totalDistance = response.fold<double>(0.0, (sum, item) => sum + ((item['distance_covered_km'] as num?) ?? 0.0).toDouble());
      final totalPassengers = response.fold<int>(0, (sum, item) => sum + ((item['passenger_count'] as num?) ?? 0).toInt());
      final totalDelay = response.fold<int>(0, (sum, item) => sum + ((item['delay_minutes'] as num?) ?? 0).toInt());

      return {
        'totalTrips': totalTrips,
        'averageDuration': totalTrips > 0 ? (totalDuration / totalTrips).round() : 0,
        'totalDistance': totalDistance,
        'averagePassengers': totalTrips > 0 ? (totalPassengers / totalTrips).round() : 0,
        'averageDelay': totalTrips > 0 ? (totalDelay / totalTrips).round() : 0,
      };
    } catch (e) {
      print('Error fetching analytics data: $e');
      return {
        'totalTrips': 0,
        'averageDuration': 0,
        'totalDistance': 0,
        'averagePassengers': 0,
        'averageDelay': 0,
      };
    }
  }

  // Helper methods
  static String _formatTimeAgo(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inDays > 0) {
      return '${difference.inDays} day${difference.inDays > 1 ? 's' : ''} ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours} hour${difference.inHours > 1 ? 's' : ''} ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes} minute${difference.inMinutes > 1 ? 's' : ''} ago';
    } else {
      return 'Just now';
    }
  }

  static String _formatDate(DateTime dateTime) {
    return '${dateTime.day}/${dateTime.month}/${dateTime.year}';
  }

  // Add a new driver to the college
  static Future<Map<String, dynamic>> addDriver({
    required String name,
    required String email,
    required String password,
    String? phone,
  }) async {
    try {
      final collegeId = await getCurrentUserCollegeId();
      if (collegeId == null) {
        print('Error: No college ID found for current user');
        return {'success': false, 'error': 'No college ID found for current user'};
      }

      // Create authentication user in Supabase Auth
      final authResponse = await _client.auth.signUp(
        email: email,
        password: password,
      );

      if (authResponse.user != null) {
        // Create user profile for the driver
        await _client.from('user_profiles').insert({
          'id': authResponse.user!.id,
          'email': email,
          'display_name': name,
          'phone_number': phone ?? '',
          'role': 'driver',
          'college_id': collegeId,
          'is_active': true,
        });

        print('Driver added successfully: $name');
        
        return {
          'success': true,
          'temp_password': password,
          'message': 'Driver created successfully with authentication account'
        };
      } else {
        print('Failed to create authentication user for driver: $name');
        return {
          'success': false, 
          'error': 'Failed to create authentication account for driver'
        };
      }
      
    } catch (e) {
      print('Error adding driver: $e');
      
      String errorMessage = 'Failed to add driver';
      
      // Show more detailed error information
      if (e.toString().contains('User already registered')) {
        errorMessage = 'A user with this email already exists';
      } else if (e.toString().contains('permission denied')) {
        errorMessage = 'Permission denied. Please check your admin rights.';
      } else if (e.toString().contains('foreign key constraint')) {
        errorMessage = 'Database constraint error. Please run the latest SQL fixes.';
      } else if (e.toString().contains('email')) {
        errorMessage = 'Invalid email address format';
      } else {
        errorMessage = e.toString();
      }
      
      return {'success': false, 'error': errorMessage};
    }
  }

  // Create authentication user for existing driver profile
  static Future<Map<String, dynamic>> createAuthForExistingDriver({
    required String driverId,
    required String email,
    required String password,
  }) async {
    try {
      final collegeId = await getCurrentUserCollegeId();
      if (collegeId == null) {
        return {'success': false, 'error': 'No college ID found for current user'};
      }

      // Check if the driver profile exists and belongs to this college
      await _client
          .from('user_profiles')
          .select('id, email, display_name')
          .eq('id', driverId)
          .eq('college_id', collegeId)
          .eq('role', 'driver')
          .single();

      // Create authentication user
      final authResponse = await _client.auth.signUp(
        email: email,
        password: password,
      );

      if (authResponse.user != null) {
        // Update the existing user profile with the new auth user ID
        await _client
            .from('user_profiles')
            .update({
              'id': authResponse.user!.id,
              'updated_at': DateTime.now().toIso8601String(),
            })
            .eq('id', driverId);

        return {
          'success': true,
          'temp_password': password,
          'message': 'Authentication account created successfully for existing driver'
        };
      } else {
        return {
          'success': false,
          'error': 'Failed to create authentication account'
        };
      }
    } catch (e) {
      print('Error creating auth for existing driver: $e');
      String errorMessage = 'Failed to create authentication account';
      
      if (e.toString().contains('User already registered')) {
        errorMessage = 'Authentication account already exists for this email';
      } else if (e.toString().contains('email')) {
        errorMessage = 'Invalid email address format';
      } else {
        errorMessage = e.toString();
      }
      
      return {'success': false, 'error': errorMessage};
    }
  }

  // Toggle driver active status
  static Future<bool> toggleDriverStatus(String driverId) async {
    try {
      final collegeId = await getCurrentUserCollegeId();
      if (collegeId == null) return false;

      // First, get the current status
      final currentDriver = await _client
          .from('user_profiles')
          .select('is_active')
          .eq('id', driverId)
          .eq('college_id', collegeId)
          .eq('role', 'driver')
          .single();

      final currentStatus = currentDriver['is_active'] ?? false;
      final newStatus = !currentStatus;

      // Update the status
      await _client
          .from('user_profiles')
          .update({
            'is_active': newStatus,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', driverId)
          .eq('college_id', collegeId);

      print('Driver status updated successfully');
      return true;
    } catch (e) {
      print('Error toggling driver status: $e');
      return false;
    }
  }

  // Remove a driver from the college
  static Future<Map<String, dynamic>> removeDriver(String driverId) async {
    try {
      final collegeId = await getCurrentUserCollegeId();
      if (collegeId == null) {
        return {'success': false, 'error': 'No college ID found for current user'};
      }

      // First, check if driver has any active trips (using correct table name)
      final activeTrips = await _client
          .from('driver_trips')
          .select('id')
          .eq('driver_id', driverId)
          .or('status.eq.scheduled,status.eq.in_progress');

      if (activeTrips.isNotEmpty) {
        return {
          'success': false, 
          'error': 'Cannot remove driver with active trips. Please complete or cancel active trips first.'
        };
      }

      // Get driver profile info before deletion
      final driverProfile = await _client
          .from('user_profiles')
          .select('email, display_name')
          .eq('id', driverId)
          .eq('college_id', collegeId)
          .eq('role', 'driver')
          .single();

      // Clear any assigned route from the driver profile
      await _client
          .from('user_profiles')
          .update({
            'employee_id': null, // Clear route assignment
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', driverId)
          .eq('college_id', collegeId);

      // Delete the Supabase authentication account using database function
      try {
        final deleteResult = await _client.rpc('delete_user_account', params: {
          'user_id': driverId,
        });
        
        if (deleteResult != null && deleteResult['success'] == true) {
          print('Authentication account deleted successfully');
        } else {
          print('Warning: Could not delete authentication account: ${deleteResult?['error']}');
          // Continue with profile deletion even if auth deletion fails
        }
      } catch (e) {
        print('Warning: Failed to delete authentication account: $e');
        // Continue with profile deletion even if auth deletion fails
      }

      // Delete the user profile record completely
      await _client
          .from('user_profiles')
          .delete()
          .eq('id', driverId)
          .eq('college_id', collegeId);

      print('Driver removed successfully: ${driverProfile['display_name']}');
      return {
        'success': true, 
        'message': 'Driver ${driverProfile['display_name']} removed successfully'
      };
    } catch (e) {
      print('Error removing driver: $e');
      String errorMessage = 'Failed to remove driver';
      
      if (e.toString().contains('not found') || e.toString().contains('no rows')) {
        errorMessage = 'Driver not found or already removed';
      } else if (e.toString().contains('foreign key constraint')) {
        errorMessage = 'Cannot remove driver due to data dependencies';
      }
      
      return {'success': false, 'error': errorMessage};
    }
  }

  // Update driver information
  static Future<bool> updateDriver({
    required String driverId,
    required String name,
    required String email,
    String? phone,
  }) async {
    try {
      final collegeId = await getCurrentUserCollegeId();
      if (collegeId == null) return false;

      await _client
          .from('user_profiles')
          .update({
            'display_name': name,
            'email': email,
            'phone_number': phone ?? '',
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', driverId)
          .eq('college_id', collegeId);

      print('Driver updated successfully');
      return true;
    } catch (e) {
      print('Error updating driver: $e');
      return false;
    }
  }

  // Add Bus Route
  static Future<bool> addBusRoute({
    required String routeName,
    required String routeCode,
    required String startName,
    required String endName,
    required LatLng startLocation,
    required LatLng endLocation,
    required List<LatLng> waypoints,
    double? distanceKm,
    int? durationMinutes,
    String? polylineData,
    List<LatLng>? routePoints,
    List<Map<String, dynamic>>? routeInstructions,
    dynamic startLocationDetails,
    dynamic endLocationDetails,
    List<dynamic>? viaLocationDetails,
  }) async {
    try {
      final collegeId = await getCurrentUserCollegeId();
      if (collegeId == null) {
        print('Error: No college ID found for current user');
        return false;
      }

      // Convert waypoints to comprehensive JSON format
      final waypointsJson = waypoints.isNotEmpty ? waypoints.asMap().entries.map((entry) => {
        'index': entry.key,
        'lat': entry.value.latitude,
        'lng': entry.value.longitude,
        'name': viaLocationDetails != null && entry.key < viaLocationDetails.length && viaLocationDetails[entry.key] != null
            ? (viaLocationDetails[entry.key].displayName?.split(',')?.first?.trim() ?? 'Waypoint ${entry.key + 1}')
            : 'Waypoint ${entry.key + 1}',
        'address': viaLocationDetails != null && entry.key < viaLocationDetails.length && viaLocationDetails[entry.key] != null
            ? (viaLocationDetails[entry.key].displayName ?? '')
            : '',
      }).toList() : null;

      // Convert route points to detailed JSON format
      final routePointsJson = routePoints?.asMap().entries.map((entry) => {
        'index': entry.key,
        'lat': entry.value.latitude,
        'lng': entry.value.longitude,
        'timestamp': DateTime.now().millisecondsSinceEpoch + (entry.key * 1000), // Sequential timestamps
      }).toList();

      // Create comprehensive route metadata
      final routeMetadata = {
        'route_source': 'ola_maps_directions',
        'total_points': routePoints?.length ?? 0,
        'has_instructions': routeInstructions?.isNotEmpty ?? false,
        'instructions_count': routeInstructions?.length ?? 0,
        'start_location_details': startLocationDetails != null ? {
          'name': startLocationDetails.displayName?.split(',')?.first?.trim() ?? startName,
          'full_address': startLocationDetails.displayName ?? '',
          'lat': startLocationDetails.latitude,
          'lng': startLocationDetails.longitude,
          'place_id': startLocationDetails.placeId ?? '',
        } : null,
        'end_location_details': endLocationDetails != null ? {
          'name': endLocationDetails.displayName?.split(',')?.first?.trim() ?? endName,
          'full_address': endLocationDetails.displayName ?? '',
          'lat': endLocationDetails.latitude,
          'lng': endLocationDetails.longitude,
          'place_id': endLocationDetails.placeId ?? '',
        } : null,
        'generated_at': DateTime.now().toIso8601String(),
        'route_quality': routePoints != null && routePoints.length > 50 ? 'high' : 'standard',
      };

      // Create default schedule template
      final scheduleTemplate = {
        'weekdays': {
          'morning': {
            'enabled': true,
            'departure_times': ['07:00', '08:00', '09:00'],
            'frequency_minutes': 60,
          },
          'evening': {
            'enabled': true,
            'departure_times': ['16:00', '17:00', '18:00'],
            'frequency_minutes': 60,
          }
        },
        'weekends': {
          'enabled': false,
          'departure_times': [],
          'frequency_minutes': 120,
        },
        'holidays': {
          'enabled': false,
          'special_schedule': false,
        },
        'last_updated': DateTime.now().toIso8601String(),
      };

      await _client.from('bus_routes').insert({
        'college_id': collegeId,
        'route_name': routeName,
        'route_code': routeCode.isEmpty ? null : routeCode,
        'start_name': startName,
        'end_name': endName,
        'start_latitude': startLocation.latitude,
        'start_longitude': startLocation.longitude,
        'end_latitude': endLocation.latitude,
        'end_longitude': endLocation.longitude,
        'waypoints': waypointsJson,
        'distance_km': distanceKm,
        'estimated_duration_minutes': durationMinutes,
        'polyline_data': polylineData,
        'route_points': {
          'points': routePointsJson,
          'instructions': routeInstructions,
          'metadata': routeMetadata,
        },
        'schedule': scheduleTemplate,
        'is_active': true,
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      });

      print('✅ Bus route added successfully: $routeName');
      return true;
    } catch (e) {
      print('❌ Error adding bus route: $e');
      print('🔍 Route details: name=$routeName, distance=$distanceKm, duration=$durationMinutes');
      print('📍 Coordinates: start=(${startLocation.latitude}, ${startLocation.longitude}), end=(${endLocation.latitude}, ${endLocation.longitude})');
      if (e.toString().contains('Check constraint')) {
        print('🚨 Likely constraint violation - check distance_km > 0 and estimated_duration_minutes > 0');
      }
      return false;
    }
  }

  // Get unassigned routes for the college
  static Future<List<Map<String, dynamic>>> getUnassignedRoutes() async {
    try {
      final collegeId = await getCurrentUserCollegeId();
      if (collegeId == null) return [];

      // Get all active routes for this college
      final allRoutes = await _client
          .from('bus_routes')
          .select('*')
          .eq('college_id', collegeId)
          .eq('is_active', true)
          .order('route_name');

      // Get all assigned route IDs (stored in employee_id field temporarily)
      final assignedRoutes = await _client
          .from('user_profiles')
          .select('employee_id')
          .eq('role', 'driver')
          .eq('college_id', collegeId)
          .not('employee_id', 'is', null);

      final assignedRouteIds = assignedRoutes
          .map((driver) => driver['employee_id'] as String?)
          .where((id) => id != null)
          .toSet();

      // Filter out assigned routes
      final unassignedRoutes = allRoutes
          .where((route) => !assignedRouteIds.contains(route['id']))
          .toList();

      return List<Map<String, dynamic>>.from(unassignedRoutes);
    } catch (e) {
      print('Error fetching unassigned routes: $e');
      return [];
    }
  }

  // Assign route to driver 
  static Future<bool> assignRouteToDriver({
    required String driverId,
    required String routeId,
  }) async {
    try {
      final collegeId = await getCurrentUserCollegeId();
      if (collegeId == null) return false;

      // Since we don't have assigned_route_id column yet, we'll use employee_id field temporarily
      // TODO: Add proper assigned_route_id column to user_profiles table
      await _client
          .from('user_profiles')
          .update({
            'employee_id': routeId, // Temporary storage in employee_id field
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', driverId)
          .eq('college_id', collegeId);

      print('Route $routeId assigned to driver $driverId');
      return true;
    } catch (e) {
      print('Error assigning route to driver: $e');
      return false;
    }
  }

  // Unassign route from driver
  static Future<bool> unassignRouteFromDriver({
    required String driverId,
  }) async {
    try {
      final collegeId = await getCurrentUserCollegeId();
      if (collegeId == null) return false;

      // Clear the employee_id field (temporary storage)
      await _client
          .from('user_profiles')
          .update({
            'employee_id': null,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', driverId)
          .eq('college_id', collegeId);

      print('Route unassigned from driver $driverId');
      return true;
    } catch (e) {
      print('Error unassigning route from driver: $e');
      return false;
    }
  }

}
