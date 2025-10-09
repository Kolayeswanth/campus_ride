import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/bus_status.dart';
import '../models/bus_route.dart';

class BusService {
  static BusService? _instance;
  static BusService get instance => _instance ??= BusService._internal();
  
  final SupabaseClient _supabase = Supabase.instance.client;
  
  BusService._internal();

  final StreamController<List<BusStatus>> _busStatusController = 
      StreamController<List<BusStatus>>.broadcast();
  final StreamController<BusStatus> _liveBusController = 
      StreamController<BusStatus>.broadcast();

  List<BusStatus> _cachedBuses = [];
  Timer? _refreshTimer;
  Timer? _liveTrackingTimer;
  String? _currentTrackedBusId;

  // Getters
  Stream<List<BusStatus>> get busStatusStream => _busStatusController.stream;
  Stream<BusStatus> get liveBusStream => _liveBusController.stream;
  List<BusStatus> get cachedBuses => _cachedBuses;

  /// Initialize the service and start periodic updates
  Future<void> initialize() async {
    try {
      await fetchAllBuses();
      _startPeriodicRefresh();
      if (kDebugMode) {
        print('🚌 BusService initialized successfully');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Failed to initialize BusService: $e');
      }
    }
  }

  /// Fetch all buses for the user's college
  Future<List<BusStatus>> fetchAllBuses({String? collegeId}) async {
    try {
      if (kDebugMode) {
        print('🔄 Fetching all buses for college: $collegeId');
      }

      if (collegeId == null) {
        if (kDebugMode) {
          print('❌ No college ID provided');
        }
        return [];
      }

      // Query bus routes for the college
      final routesResponse = await _supabase
          .from('bus_routes')
          .select('*')
          .eq('college_id', collegeId)
          .eq('is_active', true);

      if (kDebugMode) {
        print('📍 Found ${routesResponse.length} routes for college');
      }

      _cachedBuses = [];

      // For each route, get active trips and create bus status
      for (final routeData in routesResponse) {
        final route = BusRoute.fromJson(routeData);
        
        // Query active trips for this route
        final tripsResponse = await _supabase
            .from('driver_trips')
            .select('''
              *,
              user_profiles!driver_trips_driver_id_fkey(display_name)
            ''')
            .eq('route_id', route.id)
            .neq('status', 'completed');

        if (tripsResponse.isNotEmpty) {
          // Create buses from active trips
          for (final tripData in tripsResponse) {
            final busStatus = BusStatus(
              id: tripData['id'],
              route: route,
              status: _mapTripStatusToBusStatus(tripData['status']),
              currentLatitude: tripData['current_latitude']?.toDouble() ?? route.startLocation.latitude,
              currentLongitude: tripData['current_longitude']?.toDouble() ?? route.startLocation.longitude,
              bearingDegrees: tripData['bearing_degrees']?.toInt(),
              currentSpeedKmh: tripData['current_speed_kmh']?.toDouble(),
              passengerCount: tripData['passenger_count'] ?? 0,
              maxCapacity: tripData['max_capacity'] ?? 50,
              busNumber: tripData['bus_number'] ?? 'Unknown',
              driverName: tripData['user_profiles']?['display_name'] ?? 'Unknown Driver',
              hasAssignedDriver: true,
              estimatedArrival: DateTime.now().add(const Duration(minutes: 15)),
              lastUpdateTime: tripData['updated_at'] != null 
                  ? DateTime.parse(tripData['updated_at']) 
                  : DateTime.now(),
            );

            _cachedBuses.add(busStatus);
          }
        } else {
          // Create placeholder bus for routes without active trips
          final placeholderBus = BusStatus(
            id: 'placeholder_${route.id}',
            route: route,
            status: BusCurrentStatus.inactive,
            currentLatitude: route.startLocation.latitude,
            currentLongitude: route.startLocation.longitude,
            passengerCount: 0,
            maxCapacity: 50,
            busNumber: 'Bus ${_cachedBuses.length + 1}',
            driverName: 'No driver assigned',
            hasAssignedDriver: false,
            lastUpdateTime: null, // This makes it offline
          );

          _cachedBuses.add(placeholderBus);
        }
      }

      // Sort: Active buses first, then inactive
      _cachedBuses.sort((a, b) {
        if (a.isActive && !b.isActive) return -1;
        if (!a.isActive && b.isActive) return 1;
        if (a.isOnline && !b.isOnline) return -1;
        if (!a.isOnline && b.isOnline) return 1;
        return a.route.routeName.compareTo(b.route.routeName);
      });

      _busStatusController.add(_cachedBuses);
      
      if (kDebugMode) {
        print('✅ Fetched ${_cachedBuses.length} buses for college');
        print('📊 Active: ${_cachedBuses.where((b) => b.isActive).length}');
        print('📊 Online: ${_cachedBuses.where((b) => b.isOnline).length}');
      }

      return _cachedBuses;
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error fetching buses: $e');
      }
      
      // Return cached data if available
      if (_cachedBuses.isNotEmpty) {
        _busStatusController.add(_cachedBuses);
        return _cachedBuses;
      }
      
      // Return mock data for development
      return _getMockBuses();
    }
  }

  /// Start live tracking for a specific bus
  Future<void> startLiveTracking(String busId) async {
    _currentTrackedBusId = busId;
    
    if (kDebugMode) {
      print('🎯 Starting live tracking for bus: $busId');
    }

    // Initial fetch
    await _fetchBusLiveStatus(busId);
    
    // Start periodic updates every 2 seconds for smooth tracking
    _liveTrackingTimer?.cancel();
    _liveTrackingTimer = Timer.periodic(const Duration(seconds: 2), (timer) async {
      if (_currentTrackedBusId == busId) {
        await _fetchBusLiveStatus(busId);
      } else {
        timer.cancel();
      }
    });
  }

  /// Stop live tracking
  void stopLiveTracking() {
    if (kDebugMode) {
      print('⏹️ Stopping live tracking');
    }
    
    _currentTrackedBusId = null;
    _liveTrackingTimer?.cancel();
    _liveTrackingTimer = null;
  }

  /// Fetch live status for a specific bus
  Future<void> _fetchBusLiveStatus(String busId) async {
    try {
      // Get the trip details
      final tripResponse = await _supabase
          .from('driver_trips')
          .select('''
            *,
            bus_routes(*),
            user_profiles!driver_trips_driver_id_fkey(display_name)
          ''')
          .eq('id', busId)
          .single();

      // Get latest location (for future use if needed for more accurate tracking)
      // final locationResponse = await _supabase...

      final route = BusRoute.fromJson(tripResponse['bus_routes']);
      
      final busStatus = BusStatus(
        id: tripResponse['id'],
        route: route,
        status: _mapTripStatusToBusStatus(tripResponse['status']),
        currentLatitude: tripResponse['current_latitude']?.toDouble() ?? route.startLocation.latitude,
        currentLongitude: tripResponse['current_longitude']?.toDouble() ?? route.startLocation.longitude,
        bearingDegrees: tripResponse['bearing_degrees']?.toInt(),
        currentSpeedKmh: tripResponse['current_speed_kmh']?.toDouble(),
        passengerCount: tripResponse['passenger_count'] ?? 0,
        maxCapacity: tripResponse['max_capacity'] ?? 50,
        busNumber: tripResponse['bus_number'] ?? 'Unknown',
        driverName: tripResponse['user_profiles']?['display_name'] ?? 'Unknown Driver',
        hasAssignedDriver: true,
        estimatedArrival: DateTime.now().add(const Duration(minutes: 15)),
        lastUpdateTime: tripResponse['updated_at'] != null 
            ? DateTime.parse(tripResponse['updated_at']) 
            : DateTime.now(),
      );
      
      // Update cached data
      final index = _cachedBuses.indexWhere((b) => b.id == busId);
      if (index != -1) {
        _cachedBuses[index] = busStatus;
        _busStatusController.add(_cachedBuses);
      }
      
      // Emit live update
      _liveBusController.add(busStatus);
      
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error fetching live status: $e');
      }
    }
  }

  /// Get buses by status
  List<BusStatus> getBusesByStatus(BusCurrentStatus status) {
    return _cachedBuses.where((bus) => bus.status == status).toList();
  }

  /// Get active buses
  List<BusStatus> getActiveBuses() {
    return _cachedBuses.where((bus) => bus.isActive && bus.isOnline).toList();
  }

  /// Get inactive buses
  List<BusStatus> getInactiveBuses() {
    return _cachedBuses.where((bus) => !bus.isActive || !bus.isOnline).toList();
  }

  /// Search buses by route name or bus number
  List<BusStatus> searchBuses(String query) {
    if (query.isEmpty) return _cachedBuses;
    
    final lowerQuery = query.toLowerCase();
    return _cachedBuses.where((bus) {
      return bus.route.routeName.toLowerCase().contains(lowerQuery) ||
             bus.busNumber?.toLowerCase().contains(lowerQuery) == true ||
             bus.route.startName.toLowerCase().contains(lowerQuery) ||
             bus.route.endName.toLowerCase().contains(lowerQuery);
    }).toList();
  }

  /// Start periodic refresh every 30 seconds
  void _startPeriodicRefresh() {
    _refreshTimer?.cancel();
    _refreshTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      fetchAllBuses();
    });
  }

  /// Calculate estimated arrival time
  Future<DateTime?> calculateEstimatedArrival(String busId, double userLat, double userLng) async {
    try {
      final bus = _cachedBuses.firstWhere((b) => b.id == busId);
      
      if (!bus.hasLiveLocation || bus.currentSpeedKmh == null) {
        return null;
      }

      final distance = Geolocator.distanceBetween(
        bus.currentLatitude!,
        bus.currentLongitude!,
        userLat,
        userLng,
      );

      // Convert distance from meters to kilometers
      final distanceKm = distance / 1000;
      
      // Use current speed or average speed of 30 km/h
      final speedKmh = bus.currentSpeedKmh! > 0 ? bus.currentSpeedKmh! : 30.0;
      
      // Calculate time in hours, then convert to minutes
      final timeHours = distanceKm / speedKmh;
      final timeMinutes = timeHours * 60;
      
      return DateTime.now().add(Duration(minutes: timeMinutes.round()));
      
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error calculating ETA: $e');
      }
      return null;
    }
  }

  /// Mock data for development
  List<BusStatus> _getMockBuses() {
    return [
      BusStatus(
        id: '1',
        route: BusRoute(
          id: 'route1',
          collegeId: 'college1',
          routeName: 'Main Campus - City Center',
          routeCode: 'MC01',
          startName: 'Main Campus',
          endName: 'City Center',
          startLocation: const LatLng(16.5449, 81.4969),
          endLocation: const LatLng(16.5214, 81.7173),
          distanceKm: 25.5,
          estimatedDurationMinutes: 45,
          isActive: true,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
        status: BusCurrentStatus.active,
        busNumber: 'CRB001',
        passengerCount: 32,
        maxCapacity: 50,
        currentLatitude: 16.5425,
        currentLongitude: 81.4970,
        currentSpeedKmh: 45.0,
        bearingDegrees: 125,
        lastUpdateTime: DateTime.now().subtract(const Duration(minutes: 1)),
        driverName: 'Rajesh Kumar',
        driverPhone: '+91 9876543210',
        hasAssignedDriver: true,
        recentlyPassedLocation: 'GVMC Circle',
      ),
      BusStatus(
        id: '2',
        route: BusRoute(
          id: 'route2',
          collegeId: 'college1',
          routeName: 'North Campus - Beach Road',
          routeCode: 'NC02',
          startName: 'North Campus',
          endName: 'Beach Road',
          startLocation: const LatLng(16.5500, 81.5000),
          endLocation: const LatLng(16.5100, 81.7000),
          distanceKm: 20.0,
          estimatedDurationMinutes: 35,
          isActive: true,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
        status: BusCurrentStatus.inactive,
        busNumber: 'CRB002',
        passengerCount: 0,
        maxCapacity: 45,
        lastUpdateTime: DateTime.now().subtract(const Duration(hours: 2)),
        hasAssignedDriver: false,
      ),
    ];
  }

  /// Helper method to map trip status to bus status
  BusCurrentStatus _mapTripStatusToBusStatus(String? tripStatus) {
    switch (tripStatus) {
      case 'active':
      case 'in_progress':
        return BusCurrentStatus.active;
      case 'scheduled':
      case 'paused':
        return BusCurrentStatus.inactive;
      case 'maintenance':
        return BusCurrentStatus.maintenance;
      default:
        return BusCurrentStatus.offline;
    }
  }

  /// Dispose resources
  void dispose() {
    _refreshTimer?.cancel();
    _liveTrackingTimer?.cancel();
    _busStatusController.close();
    _liveBusController.close();
  }
}