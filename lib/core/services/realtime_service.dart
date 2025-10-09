import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class RealtimeService extends ChangeNotifier {
  final SupabaseClient _supabase = Supabase.instance.client;
  
  Map<String, Map<String, dynamic>> _activeTrips = {};
  Map<String, Map<String, dynamic>> _driverLocations = {};
  Set<String> _routesInUse = {};
  
  RealtimeChannel? _tripsSubscription;
  RealtimeChannel? _locationsSubscription;
  
  Map<String, Map<String, dynamic>> get activeTrips => _activeTrips;
  Map<String, Map<String, dynamic>> get driverLocations => _driverLocations;
  Set<String> get routesInUse => _routesInUse;

  void initializeSubscriptions({String? collegeCode}) {
    subscribeToActiveTrips();
    subscribeToDriverLocations();
    if (collegeCode != null) {
      subscribeToRouteStatus(collegeCode: collegeCode);
    }
  }

  void subscribeToActiveTrips() {
    _tripsSubscription?.unsubscribe();
    
    _tripsSubscription = _supabase
        .channel('active_trips')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'driver_trips',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'status',
            value: 'active',
          ),
          callback: (payload) {
            _handleTripsChange(payload);
          },
        )
        .subscribe();
  }

  void subscribeToDriverLocations() {
    _locationsSubscription?.unsubscribe();
    
    _locationsSubscription = _supabase
        .channel('driver_locations')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'driver_trip_locations',
          callback: (payload) {
            _handleLocationUpdate(payload);
          },
        )
        .subscribe();
  }

  void subscribeToRouteStatus({required String collegeCode}) {
    // Additional subscription for route-specific updates
  }

  void _handleTripsChange(PostgresChangePayload payload) {
    try {
      final record = payload.newRecord;
      if (record.isNotEmpty) {
        final tripId = record['id'] as String;
        
        if (payload.eventType == PostgresChangeEvent.insert ||
            payload.eventType == PostgresChangeEvent.update) {
          _activeTrips[tripId] = record;
          final routeId = record['route_id'] as String?;
          if (routeId != null) {
            _routesInUse.add(routeId);
          }
        } else if (payload.eventType == PostgresChangeEvent.delete) {
          _activeTrips.remove(tripId);
          // Note: We don't remove from routesInUse here as there might be other active trips
          _refreshRoutesInUse();
        }
        
        notifyListeners();
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error handling trips change: $e');
      }
    }
  }

  void _handleLocationUpdate(PostgresChangePayload payload) {
    try {
      final record = payload.newRecord;
      if (record.isNotEmpty) {
        final tripId = record['trip_id'] as String;
        _driverLocations[tripId] = record;
        notifyListeners();
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error handling location update: $e');
      }
    }
  }

  void _refreshRoutesInUse() {
    _routesInUse.clear();
    for (final trip in _activeTrips.values) {
      final routeId = trip['route_id'] as String?;
      if (routeId != null) {
        _routesInUse.add(routeId);
      }
    }
  }

  int getActiveTripsCount() {
    return _activeTrips.length;
  }

  bool isRouteInUse(String routeId) {
    return _routesInUse.contains(routeId);
  }

  Map<String, dynamic>? getDriverLocation(String tripId) {
    return _driverLocations[tripId];
  }

  Map<String, dynamic>? getLatestDriverLocation(String tripId) {
    final location = _driverLocations[tripId];
    if (location == null) return null;
    
    final timestamp = DateTime.tryParse(location['ts'] as String? ?? '');
    if (timestamp == null) return location;
    
    final ageSeconds = DateTime.now().difference(timestamp).inSeconds;
    final isRecent = ageSeconds < 300; // Consider recent if less than 5 minutes old
    
    return {
      ...location,
      'age_seconds': ageSeconds,
      'is_recent': isRecent,
    };
  }

  bool isDriverLocationAvailable(String tripId) {
    final location = getLatestDriverLocation(tripId);
    return location?['is_recent'] == true;
  }

  List<Map<String, dynamic>> getActiveTripsForDriver(String driverId) {
    return _activeTrips.values
        .where((trip) => trip['driver_id'] == driverId)
        .toList();
  }

  Map<String, dynamic> getActiveTripsStats() {
    final totalTrips = _activeTrips.length;
    final routesWithActiveTrips = _routesInUse.length;
    final tripsWithRecentLocation = _driverLocations.values
        .where((location) {
          final timestamp = DateTime.tryParse(location['ts'] as String? ?? '');
          if (timestamp == null) return false;
          return DateTime.now().difference(timestamp).inSeconds < 300;
        })
        .length;

    return {
      'total_active_trips': totalTrips,
      'routes_in_use': routesWithActiveTrips,
      'trips_with_recent_location': tripsWithRecentLocation,
      'last_updated': DateTime.now().toIso8601String(),
    };
  }

  void refreshCollegeFilter() {
    // Refresh subscriptions with updated college filter
    // Implementation would depend on how college filtering is handled
  }

  Future<void> loadInitialData() async {
    try {
      // Load active trips
      final tripsResponse = await _supabase
          .from('driver_trips')
          .select('*, bus_routes(*)')
          .eq('status', 'active');

      _activeTrips.clear();
      _routesInUse.clear();
      
      for (final trip in tripsResponse) {
        final tripId = trip['id'] as String;
        _activeTrips[tripId] = trip;
        
        final routeId = trip['route_id'] as String?;
        if (routeId != null) {
          _routesInUse.add(routeId);
        }
      }

      // Load recent driver locations
      if (_activeTrips.isNotEmpty) {
        final locationsResponse = await _supabase
            .from('driver_trip_locations')
            .select()
            .inFilter('trip_id', _activeTrips.keys.toList())
            .gte('ts', DateTime.now().subtract(const Duration(minutes: 10)).toIso8601String())
            .order('ts', ascending: false);

        _driverLocations.clear();
        
        // Keep only the most recent location for each trip
        final processedTrips = <String>{};
        for (final location in locationsResponse) {
          final tripId = location['trip_id'] as String;
          if (!processedTrips.contains(tripId)) {
            _driverLocations[tripId] = location;
            processedTrips.add(tripId);
          }
        }
      }

      notifyListeners();
    } catch (e) {
      if (kDebugMode) {
        print('Error loading initial realtime data: $e');
      }
    }
  }

  @override
  void dispose() {
    _tripsSubscription?.unsubscribe();
    _locationsSubscription?.unsubscribe();
    super.dispose();
  }
}
