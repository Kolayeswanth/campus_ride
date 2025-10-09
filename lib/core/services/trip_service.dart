import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/bus_route.dart';
import '../models/driver_trip.dart';
import 'ola_maps_service.dart';
import 'location_tracking_service.dart';
import 'background_location_service.dart';

class TripService extends ChangeNotifier {
  final SupabaseClient _supabase = Supabase.instance.client;
  final LocationTrackingService _locationService = LocationTrackingService();
  
  List<BusRoute> _routes = [];
  BusRoute? _selectedRoute;
  DriverTrip? _currentTrip;
  bool _isLiveLocationSharing = false;
  List<DriverTrip> _tripHistory = [];
  DateTime? _lastRouteRefresh;

  List<BusRoute> get routes => _routes;
  BusRoute? get selectedRoute => _selectedRoute;
  DriverTrip? get currentTrip => _currentTrip;
  bool get isLiveLocationSharing => _isLiveLocationSharing;
  List<DriverTrip> get tripHistory => _tripHistory;

  Future<void> loadRoutes() async {
    await fetchDriverRoutes(forceRefresh: true);
  }

  Future<List<BusRoute>> fetchDriverRoutes({bool forceRefresh = false}) async {
    try {
      if (!forceRefresh && !shouldRefreshRoutes()) {
        return _routes;
      }

      final response = await _supabase
          .from('bus_routes')
          .select()
          .eq('is_active', true)
          .order('route_name');

      _routes = response
          .map<BusRoute>((json) => BusRoute.fromJson(json))
          .toList();
      
      _lastRouteRefresh = DateTime.now();
      notifyListeners();
      return _routes;
    } catch (e) {
      if (kDebugMode) {
        print('Error fetching driver routes: $e');
      }
      return _routes;
    }
  }

  Future<List<BusRoute>> refreshRoutes() async {
    return await fetchDriverRoutes(forceRefresh: true);
  }

  void clearRouteCache() {
    _lastRouteRefresh = null;
    _routes.clear();
    notifyListeners();
  }

  bool shouldRefreshRoutes() {
    if (_lastRouteRefresh == null) return true;
    final now = DateTime.now();
    return now.difference(_lastRouteRefresh!).inMinutes > 15; // Refresh every 15 minutes
  }

  void selectRoute(BusRoute route) {
    _selectedRoute = route;
    notifyListeners();
  }

  Future<List<LatLng>> calculateRoute(LatLng start, LatLng end) async {
    try {
      final response = await OlaMapsService.getDirections([start, end]);
      return response['route_points'] as List<LatLng>;
    } catch (e) {
      if (kDebugMode) {
        print('Error calculating route: $e');
      }
      return [];
    }
  }

  Future<Map<String, dynamic>?> fetchRouteInfo(String routeId) async {
    try {
      final response = await _supabase
          .from('bus_routes')
          .select()
          .eq('id', routeId)
          .single();
      
      return response;
    } catch (e) {
      if (kDebugMode) {
        print('Error fetching route info: $e');
      }
      return null;
    }
  }

  Future<List<Map<String, dynamic>>> searchBuses(String query) async {
    try {
      final response = await _supabase
          .from('bus_routes')
          .select('*, buses!inner(*)')
          .or('route_name.ilike.%$query%,buses.number.ilike.%$query%')
          .eq('is_active', true);
      
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      if (kDebugMode) {
        print('Error searching buses: $e');
      }
      return [];
    }
  }

  Future<void> updateBusLocation(
    String busId,
    double lat,
    double lng, {
    double? heading,
    double? speed,
  }) async {
    if (_currentTrip == null) return;

    try {
      final locationData = {
        'trip_id': _currentTrip!.id,
        'ts': DateTime.now().toIso8601String(),
        'lat': lat,
        'lng': lng,
        'heading': heading,
        'speed_mps': speed,
      };

      await _supabase.from('driver_trip_locations').insert(locationData);
    } catch (e) {
      if (kDebugMode) {
        print('Error updating bus location: $e');
      }
    }
  }

  Future<String?> getVillageName(LatLng location) async {
    try {
      return await OlaMapsService.getLocationName(location);
    } catch (e) {
      if (kDebugMode) {
        print('Error getting village name: $e');
      }
      return null;
    }
  }

  Future<List<Map<String, dynamic>>> getCrossedVillages(String tripId) async {
    try {
      // This would query a villages table or use geocoding to get crossed villages
      // For now, return empty list
      return [];
    } catch (e) {
      if (kDebugMode) {
        print('Error getting crossed villages: $e');
      }
      return [];
    }
  }

  Future<LatLng?> getVillageCenter(String villageName) async {
    try {
      // TODO: Implement searchLocations method in OlaMapsService or use alternative
      // final results = await OlaMapsService.searchLocations(villageName);
      // if (results.isNotEmpty) {
      //   final result = results.first;
      //   return LatLng(result['lat'] as double, result['lng'] as double);
      // }
      return null;
    } catch (e) {
      if (kDebugMode) {
        print('Error getting village center: $e');
      }
      return null;
    }
  }

  Future<void> storeCrossedVillage(String villageName, DateTime timestamp) async {
    // Store crossed village data
    // Implementation would depend on the specific requirements
  }

  Future<DriverTrip?> startDriverTrip({
    required String routeId,
    String? busNumber,
    BusRoute? route,
  }) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) {
        throw Exception('User not authenticated');
      }

      final tripData = {
        'driver_id': userId,
        'route_id': routeId,
        'status': TripStatus.active.name,
        'direction': TripDirection.outbound.name,
        'started_at': DateTime.now().toIso8601String(),
      };

      final response = await _supabase
          .from('driver_trips')
          .insert(tripData)
          .select()
          .single();

      _currentTrip = DriverTrip.fromJson(response);
      _isLiveLocationSharing = true;
      
      // Start location tracking
      await startTripTracking();
      
      notifyListeners();
      return _currentTrip;
    } catch (e) {
      if (kDebugMode) {
        print('Error starting driver trip: $e');
      }
      return null;
    }
  }

  Future<void> startReturnTrip() async {
    if (_currentTrip == null) return;

    try {
      // Update the current trip to return direction
      final updatedTripData = {
        'direction': TripDirection.inbound.name,
        'updated_at': DateTime.now().toIso8601String(),
      };

      await _supabase
          .from('driver_trips')
          .update(updatedTripData)
          .eq('id', _currentTrip!.id);

      _currentTrip = _currentTrip!.copyWith(
        direction: TripDirection.inbound,
      );

      notifyListeners();
    } catch (e) {
      if (kDebugMode) {
        print('Error starting return trip: $e');
      }
    }
  }

  Future<bool> endDriverTrip() async {
    if (_currentTrip == null) return false;

    try {
      final endData = {
        'status': TripStatus.completed.name,
        'ended_at': DateTime.now().toIso8601String(),
      };

      await _supabase
          .from('driver_trips')
          .update(endData)
          .eq('id', _currentTrip!.id);

      await stopTripTracking();
      
      _currentTrip = null;
      _isLiveLocationSharing = false;
      
      // Refresh trip history
      await fetchDriverTripHistory();
      
      notifyListeners();
      return true;
    } catch (e) {
      if (kDebugMode) {
        print('Error ending driver trip: $e');
      }
      return false;
    }
  }

  Future<Map<String, dynamic>?> getTripDetails(String tripId) async {
    try {
      final response = await _supabase
          .from('driver_trips')
          .select('*, bus_routes(*)')
          .eq('id', tripId)
          .single();
      
      return response;
    } catch (e) {
      if (kDebugMode) {
        print('Error getting trip details: $e');
      }
      return null;
    }
  }

  Future<void> fetchDriverTripHistory() async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return;

      final response = await _supabase
          .from('driver_trips')
          .select('*, bus_routes(*)')
          .eq('driver_id', userId)
          .eq('status', TripStatus.completed.name)
          .order('started_at', ascending: false)
          .limit(20);

      _tripHistory = response
          .map<DriverTrip>((json) => DriverTrip.fromJson(json))
          .toList();
      
      notifyListeners();
    } catch (e) {
      if (kDebugMode) {
        print('Error fetching trip history: $e');
      }
    }
  }

  Future<List<DriverTrip>> getTripHistory() async {
    if (_tripHistory.isEmpty) {
      await fetchDriverTripHistory();
    }
    return _tripHistory;
  }

  Future<void> startTripTracking() async {
    if (_currentTrip == null) return;
    
    try {
      // Initialize background location service
      await BackgroundLocationService.initialize();
      
      // Start background location tracking
      await BackgroundLocationService.startTracking(_currentTrip!);
      
      // Initialize and start real location tracking (for in-app use)
      final success = await _locationService.startTracking(_currentTrip!.id);
      
      if (success) {
        _isLiveLocationSharing = true;
        if (kDebugMode) {
          print('Started location tracking (foreground + background) for trip: ${_currentTrip?.id}');
        }
      } else {
        if (kDebugMode) {
          print('Failed to start foreground location tracking, but background tracking is active');
        }
      }
      
      notifyListeners();
    } catch (e) {
      if (kDebugMode) {
        print('Error starting location tracking: $e');
      }
    }
  }

  Future<void> stopTripTracking() async {
    try {
      // Stop background location service
      await BackgroundLocationService.stopTracking();
      
      // Stop foreground location tracking
      await _locationService.stopTracking();
      _isLiveLocationSharing = false;
      
      if (kDebugMode) {
        print('Stopped location tracking (foreground + background)');
      }
      
      notifyListeners();
    } catch (e) {
      if (kDebugMode) {
        print('Error stopping location tracking: $e');
      }
    }
  }

  void dismissVillageNotification() {
    // Implementation for dismissing village notifications
  }

  @override
  void dispose() {
    stopTripTracking();
    super.dispose();
  }
}
