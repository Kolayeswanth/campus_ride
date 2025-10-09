import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/bus_status.dart';
import '../models/bus_route.dart';
import 'ola_maps_routing_service.dart';

/// Real-time location service for syncing driver locations with passengers
/// Uses Supabase Realtime subscriptions for live updates
class RealtimeLocationService extends ChangeNotifier {
  static RealtimeLocationService? _instance;
  static RealtimeLocationService get instance => _instance ??= RealtimeLocationService._internal();
  
  final SupabaseClient _supabase = Supabase.instance.client;
  
  RealtimeLocationService._internal();

  // Realtime subscriptions
  RealtimeChannel? _driverTripsChannel;
  RealtimeChannel? _driverLocationsChannel;
  
  // Current tracking state
  String? _trackingTripId;
  BusStatus? _currentBusStatus;
  
  // Stream controllers
  final StreamController<BusStatus> _busLocationController = 
      StreamController<BusStatus>.broadcast();
  final StreamController<List<Map<String, double>>> _routePolylineController = 
      StreamController<List<Map<String, double>>>.broadcast();
  
  // Getters
  Stream<BusStatus> get busLocationStream => _busLocationController.stream;
  Stream<List<Map<String, double>>> get routePolylineStream => _routePolylineController.stream;
  BusStatus? get currentBusStatus => _currentBusStatus;
  bool get isTracking => _trackingTripId != null;

  /// Start tracking a specific bus trip with real-time updates
  Future<bool> startTrackingBus(String tripId, BusStatus initialBus) async {
    try {
      print('🎯 Starting realtime tracking for trip: $tripId');
      
      // Stop any existing tracking
      await stopTracking();
      
      _trackingTripId = tripId;
      _currentBusStatus = initialBus;
      
      // Check if trip is active before starting tracking
      final isActive = await _checkTripStatus(tripId);
      if (!isActive) {
        print('❌ Trip $tripId is not active, cannot track');
        return false;
      }
      
      // Subscribe to driver_trips table for general trip updates
      await _subscribeToTripUpdates(tripId);
      
      // Subscribe to driver_locations table for precise location updates
      await _subscribeToLocationUpdates(tripId);
      
      // Get initial location data
      await _fetchLatestLocation(tripId);
      
      print('✅ Real-time tracking started for trip: $tripId');
      notifyListeners();
      return true;
      
    } catch (e) {
      print('❌ Failed to start tracking: $e');
      await stopTracking();
      return false;
    }
  }
  
  /// Check if trip is currently active
  Future<bool> _checkTripStatus(String tripId) async {
    try {
      final response = await _supabase
          .from('driver_trips')
          .select('status')
          .eq('id', tripId)
          .single();
      
      final status = response['status'] as String;
      final isActive = ['active', 'in_progress', 'started'].contains(status);
      
      print('🔍 Trip $tripId status: $status (Active: $isActive)');
      return isActive;
    } catch (e) {
      print('❌ Error checking trip status: $e');
      return false;
    }
  }

  /// Subscribe to driver_trips table for trip-level updates
  Future<void> _subscribeToTripUpdates(String tripId) async {
    try {
      _driverTripsChannel = _supabase
          .channel('trip_updates_$tripId')
          .onPostgresChanges(
            event: PostgresChangeEvent.update,
            schema: 'public',
            table: 'driver_trips',
            filter: PostgresChangeFilter(
              type: PostgresChangeFilterType.eq,
              column: 'id',
              value: tripId,
            ),
            callback: _handleTripUpdate,
          )
          .subscribe();
          
      print('📡 Subscribed to trip updates for: $tripId');
    } catch (e) {
      print('❌ Failed to subscribe to trip updates: $e');
    }
  }

  /// Subscribe to driver_locations table for precise location updates
  Future<void> _subscribeToLocationUpdates(String tripId) async {
    try {
      _driverLocationsChannel = _supabase
          .channel('location_updates_$tripId')
          .onPostgresChanges(
            event: PostgresChangeEvent.insert,
            schema: 'public',
            table: 'driver_locations',
            filter: PostgresChangeFilter(
              type: PostgresChangeFilterType.eq,
              column: 'trip_id',
              value: tripId,
            ),
            callback: _handleLocationUpdate,
          )
          .subscribe();
          
      print('📡 Subscribed to location updates for trip: $tripId');
    } catch (e) {
      print('❌ Failed to subscribe to location updates: $e');
    }
  }

  /// Handle driver trip updates (status changes, general updates)
  void _handleTripUpdate(PostgresChangePayload payload) {
    try {
      print('🔄 Trip update received: ${payload.newRecord}');
      
      if (_currentBusStatus != null) {
        final updatedData = payload.newRecord;
        
        // Update current position from trip data
        final lat = updatedData['current_latitude'] as double?;
        final lng = updatedData['current_longitude'] as double?;
        final speed = updatedData['current_speed_kmh'] as double?;
        final bearing = updatedData['bearing_degrees'] as int?;
        
        if (lat != null && lng != null) {
          // Create updated bus status
          final updatedBus = BusStatus(
            id: _currentBusStatus!.id,
            route: _currentBusStatus!.route,
            status: _mapTripStatusToBusStatus(updatedData['status'] as String),
            currentLatitude: lat,
            currentLongitude: lng,
            currentSpeedKmh: speed,
            bearingDegrees: bearing,
            lastUpdateTime: DateTime.now(),
            busNumber: _currentBusStatus!.busNumber,
            driverName: _currentBusStatus!.driverName,
            hasAssignedDriver: _currentBusStatus!.hasAssignedDriver,
            passengerCount: updatedData['passenger_count'] ?? _currentBusStatus!.passengerCount,
            maxCapacity: updatedData['max_capacity'] ?? _currentBusStatus!.maxCapacity,
          );
          
          _currentBusStatus = updatedBus;
          _busLocationController.add(updatedBus);
          
          print('📍 Bus location updated: $lat, $lng (Speed: ${speed ?? 0} km/h)');
        }
        
        // Check if trip ended
        final status = updatedData['status'] as String;
        if (['completed', 'cancelled', 'inactive'].contains(status)) {
          print('🏁 Trip ended with status: $status');
          stopTracking();
        }
      }
    } catch (e) {
      print('❌ Error handling trip update: $e');
    }
  }

  /// Handle driver location updates (high frequency updates)
  void _handleLocationUpdate(PostgresChangePayload payload) {
    try {
      print('📍 Location update received: ${payload.newRecord}');
      
      if (_currentBusStatus != null) {
        final locationData = payload.newRecord;
        
        final lat = locationData['latitude'] as double;
        final lng = locationData['longitude'] as double;
        final speed = locationData['speed_kmh'] as double?;
        final bearing = locationData['bearing_degrees'] as int?;
        final timestamp = DateTime.parse(locationData['location_timestamp'] as String);
        
        // Create updated bus status with precise location
        final updatedBus = BusStatus(
          id: _currentBusStatus!.id,
          route: _currentBusStatus!.route,
          status: _currentBusStatus!.status,
          currentLatitude: lat,
          currentLongitude: lng,
          currentSpeedKmh: speed ?? _currentBusStatus!.currentSpeedKmh,
          bearingDegrees: bearing ?? _currentBusStatus!.bearingDegrees,
          lastUpdateTime: timestamp,
          busNumber: _currentBusStatus!.busNumber,
          driverName: _currentBusStatus!.driverName,
          hasAssignedDriver: _currentBusStatus!.hasAssignedDriver,
          passengerCount: _currentBusStatus!.passengerCount,
          maxCapacity: _currentBusStatus!.maxCapacity,
        );
        
        _currentBusStatus = updatedBus;
        _busLocationController.add(updatedBus);
        
        print('🎯 Precise location update: $lat, $lng (${DateTime.now().millisecondsSinceEpoch})');
        
        // Fetch updated route polyline from current position
        _fetchRoutePolyline(lat, lng);
      }
    } catch (e) {
      print('❌ Error handling location update: $e');
    }
  }

  /// Fetch initial/latest location for the trip
  Future<void> _fetchLatestLocation(String tripId) async {
    try {
      // Get latest location from driver_locations
      final locationResponse = await _supabase
          .from('driver_locations')
          .select('*')
          .eq('trip_id', tripId)
          .order('location_timestamp', ascending: false)
          .limit(1);
      
      if (locationResponse.isNotEmpty && _currentBusStatus != null) {
        final locationData = locationResponse.first;
        
        final updatedBus = BusStatus(
          id: _currentBusStatus!.id,
          route: _currentBusStatus!.route,
          status: _currentBusStatus!.status,
          currentLatitude: locationData['latitude'] as double,
          currentLongitude: locationData['longitude'] as double,
          currentSpeedKmh: locationData['speed_kmh'] as double?,
          bearingDegrees: locationData['bearing_degrees'] as int?,
          lastUpdateTime: DateTime.parse(locationData['location_timestamp'] as String),
          busNumber: _currentBusStatus!.busNumber,
          driverName: _currentBusStatus!.driverName,
          hasAssignedDriver: _currentBusStatus!.hasAssignedDriver,
          passengerCount: _currentBusStatus!.passengerCount,
          maxCapacity: _currentBusStatus!.maxCapacity,
        );
        
        _currentBusStatus = updatedBus;
        _busLocationController.add(updatedBus);
        
        print('📍 Latest location fetched: ${updatedBus.currentLatitude}, ${updatedBus.currentLongitude}');
        
        // Get route polyline from this position
        _fetchRoutePolyline(updatedBus.currentLatitude!, updatedBus.currentLongitude!);
      }
    } catch (e) {
      print('❌ Error fetching latest location: $e');
    }
  }

  /// Fetch route polyline from current driver position to destination using real roads
  Future<void> _fetchRoutePolyline(double currentLat, double currentLng) async {
    try {
      if (_currentBusStatus == null) return;
      
      // Get route information
      final route = _currentBusStatus!.route;
      final endLat = route.endLocation.latitude;
      final endLng = route.endLocation.longitude;
      
      print('🛣️ Fetching real route from ($currentLat, $currentLng) to ($endLat, $endLng)');
      
      // Use OlaMaps routing service for actual road-based routing
      try {
        final waypoints = [
          LatLng(currentLat, currentLng), // Current driver position
          LatLng(endLat, endLng), // Destination
        ];
        
        final directionsResponse = await OlaMapsRoutingService.getDirections(
          waypoints,
          profile: 'driving',
          geometries: 'polyline6',
          steps: false, // We just need the overall route
        );
        
        if (directionsResponse['routes'] != null && 
            directionsResponse['routes'].isNotEmpty) {
          
          final routeData = directionsResponse['routes'][0];
          final geometry = routeData['geometry'] as String?;
          
          if (geometry != null) {
            // Decode polyline and convert to coordinates
            final coordinates = OlaMapsRoutingService.decodePolyline(geometry);
            final polylinePoints = coordinates.map((coord) => {
              'latitude': coord.latitude,
              'longitude': coord.longitude,
            }).toList();
            
            _routePolylineController.add(polylinePoints);
            
            final distance = (routeData['distance'] as num?)?.toDouble() ?? 0.0;
            final duration = (routeData['duration'] as num?)?.toDouble() ?? 0.0;
            
            print('✅ Real road route loaded: ${polylinePoints.length} points, ${(distance / 1000).toStringAsFixed(1)}km, ${(duration / 60).toStringAsFixed(0)}min');
            return;
          }
        }
        
        // Fallback to straight line if routing fails
        print('⚠️ Routing API failed, using straight line fallback');
        
      } catch (routingError) {
        print('❌ Routing service error: $routingError');
      }
      
      // Fallback: create straight line polyline
      final polylinePoints = <Map<String, double>>[
        {'latitude': currentLat, 'longitude': currentLng},
        {'latitude': endLat, 'longitude': endLng},
      ];
      
      _routePolylineController.add(polylinePoints);
      
      print('� Fallback straight line route from ($currentLat, $currentLng) to ($endLat, $endLng)');
    } catch (e) {
      print('❌ Error fetching route polyline: $e');
    }
  }

  /// Map trip status string to BusCurrentStatus enum
  BusCurrentStatus _mapTripStatusToBusStatus(String tripStatus) {
    switch (tripStatus.toLowerCase()) {
      case 'active':
      case 'in_progress':
      case 'started':
        return BusCurrentStatus.active;
      case 'scheduled':
        return BusCurrentStatus.inactive;
      case 'completed':
      case 'cancelled':
        return BusCurrentStatus.offline;
      default:
        return BusCurrentStatus.inactive;
    }
  }

  /// Stop tracking and cleanup subscriptions
  Future<void> stopTracking() async {
    try {
      print('🛑 Stopping real-time tracking');
      
      await _driverTripsChannel?.unsubscribe();
      await _driverLocationsChannel?.unsubscribe();
      
      _driverTripsChannel = null;
      _driverLocationsChannel = null;
      _trackingTripId = null;
      _currentBusStatus = null;
      
      notifyListeners();
      
      print('✅ Real-time tracking stopped');
    } catch (e) {
      print('❌ Error stopping tracking: $e');
    }
  }

  /// Dispose and cleanup
  @override
  void dispose() {
    stopTracking();
    _busLocationController.close();
    _routePolylineController.close();
    super.dispose();
  }
}