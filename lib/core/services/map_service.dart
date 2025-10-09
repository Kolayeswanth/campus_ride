import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/bus_route.dart';


class MapService extends ChangeNotifier {
  // TODO: Implement proper OLA Maps controller when SDK is available
  // OlaMapController? _mapController;
  dynamic _mapController;
  LatLng? _userLocation;
  LatLng? _selectedLocation;
  double _currentZoom = 15.0;
  final SupabaseClient _supabase = Supabase.instance.client;
  
  final Map<String, Map<String, dynamic>> _markers = {};
  final Map<String, Map<String, dynamic>> _routes = {};
  final Map<String, Function> _busLocationSubscriptions = {};

  LatLng? get userLocation => _userLocation;
  LatLng? get selectedLocation => _selectedLocation;
  double get currentZoom => _currentZoom;

  void onMapCreated(dynamic controller) {
    _mapController = controller;
    initializeMap();
  }

  Future<void> initializeMap() async {
    if (_mapController == null) return;
    
    try {
      // Apply Apple Maps-like styling
      await applyAppleMapsStyle();
      
      // Get current location
      await _getCurrentLocation();
      
      if (kDebugMode) {
        print('Map initialized successfully');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error initializing map: $e');
      }
    }
  }

  Future<void> _getCurrentLocation() async {
    try {
      final permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        final requestPermission = await Geolocator.requestPermission();
        if (requestPermission == LocationPermission.denied) {
          return;
        }
      }

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      
      _userLocation = LatLng(position.latitude, position.longitude);
      await updateUserLocationOnMap(position);
      notifyListeners();
    } catch (e) {
      if (kDebugMode) {
        print('Error getting current location: $e');
      }
    }
  }

  void updateUserLocation(Position position) {
    _userLocation = LatLng(position.latitude, position.longitude);
    updateUserLocationOnMap(position);
    notifyListeners();
  }

  Future<void> updateUserLocationOnMap(Position position) async {
    if (_mapController == null) return;
    
    try {
      final location = LatLng(position.latitude, position.longitude);
      
      // Add/update user location marker
      await addMarker(
        location,
        {'type': 'user_location'},
        title: 'Your Location',
        iconColor: Colors.blue.value.toRadixString(16),
      );
      
      // Move camera to user location
      await moveCameraToPosition(location);
    } catch (e) {
      if (kDebugMode) {
        print('Error updating user location on map: $e');
      }
    }
  }

  Future<void> moveCameraToPosition(LatLng position) async {
    if (_mapController == null) return;
    
    try {
      await _mapController!.moveCamera(position, zoom: _currentZoom);
    } catch (e) {
      if (kDebugMode) {
        print('Error moving camera: $e');
      }
    }
  }

  Future<void> moveToLocation(LatLng location, {double? zoom}) async {
    if (_mapController == null) return;
    
    try {
      final targetZoom = zoom ?? _currentZoom;
      await _mapController!.moveCamera(location, zoom: targetZoom);
      _currentZoom = targetZoom;
    } catch (e) {
      if (kDebugMode) {
        print('Error moving to location: $e');
      }
    }
  }

  void setSelectedLocation(LatLng? location) {
    _selectedLocation = location;
    notifyListeners();
  }

  void setZoom(double zoom) {
    _currentZoom = zoom;
    notifyListeners();
  }

  Future<void> addMarker(
    LatLng position,
    Map<String, dynamic> data, {
    String? title,
    String? iconColor,
  }) async {
    if (_mapController == null) return;
    
    try {
      final markerId = data['id'] as String? ?? 
          '${position.latitude}-${position.longitude}';
      
      _markers[markerId] = {
        'position': position,
        'data': data,
        'title': title,
        'iconColor': iconColor,
      };
      
      await _mapController!.addMarker(
        markerId,
        position,
        title: title,
        iconColor: iconColor,
      );
    } catch (e) {
      if (kDebugMode) {
        print('Error adding marker: $e');
      }
    }
  }

  Future<void> updateMarker(
    String markerId,
    LatLng position, {
    Map<String, dynamic>? data,
    double? heading,
  }) async {
    if (_mapController == null) return;
    
    try {
      if (_markers.containsKey(markerId)) {
        _markers[markerId]!['position'] = position;
        if (data != null) {
          _markers[markerId]!['data'] = {..._markers[markerId]!['data'], ...data};
        }
        if (heading != null) {
          _markers[markerId]!['heading'] = heading;
        }
        
        // Remove and re-add marker (in a real implementation, update would be more efficient)
        await _mapController!.removeMarker(markerId);
        await _mapController!.addMarker(
          markerId,
          position,
          title: _markers[markerId]!['title'],
          iconColor: _markers[markerId]!['iconColor'],
        );
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error updating marker: $e');
      }
    }
  }

  Future<void> removeMarkerById(String markerId) async {
    if (_mapController == null) return;
    
    try {
      _markers.remove(markerId);
      await _mapController!.removeMarker(markerId);
    } catch (e) {
      if (kDebugMode) {
        print('Error removing marker: $e');
      }
    }
  }

  Future<void> clearMarkers() async {
    if (_mapController == null) return;
    
    try {
      for (final markerId in _markers.keys) {
        await _mapController!.removeMarker(markerId);
      }
      _markers.clear();
    } catch (e) {
      if (kDebugMode) {
        print('Error clearing markers: $e');
      }
    }
  }

  Future<void> addRoute(
    List<LatLng> points,
    Map<String, dynamic> data, {
    int width = 5,
    Color color = Colors.blue,
  }) async {
    if (_mapController == null || points.isEmpty) return;
    
    try {
      final routeId = data['id'] as String? ?? 
          DateTime.now().millisecondsSinceEpoch.toString();
      
      _routes[routeId] = {
        'points': points,
        'data': data,
        'width': width,
        'color': color,
      };
      
      await _mapController!.addPolyline(
        routeId,
        points,
        width: width,
        color: '#${color.value.toRadixString(16).padLeft(8, '0')}',
      );
    } catch (e) {
      if (kDebugMode) {
        print('Error adding route: $e');
      }
    }
  }

  Future<void> removeRouteById(String routeId) async {
    if (_mapController == null) return;
    
    try {
      _routes.remove(routeId);
      await _mapController!.removePolyline(routeId);
    } catch (e) {
      if (kDebugMode) {
        print('Error removing route: $e');
      }
    }
  }

  Future<void> clearRoutes() async {
    if (_mapController == null) return;
    
    try {
      for (final routeId in _routes.keys) {
        await _mapController!.removePolyline(routeId);
      }
      _routes.clear();
    } catch (e) {
      if (kDebugMode) {
        print('Error clearing routes: $e');
      }
    }
  }

  Future<void> fitBounds(List<LatLng> points, {double padding = 50}) async {
    if (_mapController == null || points.isEmpty) return;
    
    try {
      await _mapController!.fitBounds(points, padding: padding);
    } catch (e) {
      if (kDebugMode) {
        print('Error fitting bounds: $e');
      }
    }
  }

  Future<void> applyAppleMapsStyle() async {
    try {
      // Apply Apple Maps-like visual styling to Ola Maps
      final styleConfig = {
        'theme': 'light',
        'primaryColor': '#007AFF',
        'roadColor': '#FFFFFF',
        'buildingColor': '#F2F2F7',
        'waterColor': '#007AFF',
        'parkColor': '#34C759',
        'transitColor': '#5856D6',
      };
      
      // This would be passed to the Ola Maps SDK
      if (kDebugMode) {
        print('Applied Apple Maps style with config: $styleConfig');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error applying map style: $e');
      }
    }
  }

  Future<LatLng> getCurrentLocation() async {
    if (_userLocation != null) return _userLocation!;
    
    await _getCurrentLocation();
    return _userLocation ?? const LatLng(12.9716, 77.5946); // Default to Bangalore
  }

  void subscribeToBusLocation(String busId) {
    try {
      // Subscribe to real-time location updates for a specific bus from Supabase
      final subscription = _supabase
          .from('driver_trip_locations')
          .stream(primaryKey: ['id'])
          .eq('trip_id', busId)
          .order('ts', ascending: false)
          .limit(1)
          .listen((data) {
            if (data.isNotEmpty) {
              final locationData = data.first;
              final busLocation = LatLng(
                locationData['lat'] as double,
                locationData['lng'] as double,
              );
              
              // Update bus marker on map
              _updateBusMarkerPosition(busId, busLocation);
              
              if (kDebugMode) {
                print('Updated bus $busId location: $busLocation');
              }
            }
          });
      
      _busLocationSubscriptions[busId] = subscription.cancel;
      
      if (kDebugMode) {
        print('Subscribed to real-time location updates for bus: $busId');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error subscribing to bus location: $e');
      }
    }
  }

  void unsubscribeFromBusLocation(String busId) {
    final cancelFunction = _busLocationSubscriptions.remove(busId);
    if (cancelFunction != null) {
      cancelFunction();
    }
  }

  void _updateBusMarkerPosition(String busId, LatLng position) {
    if (_mapController != null) {
      _mapController!.updateMarker(
        'bus_$busId',
        position: position,
        rotation: 0.0, // This would be calculated from heading
      );
      
      if (kDebugMode) {
        print('Updated bus marker position for $busId: $position');
      }
    }
  }

  void subscribeToRouteBuses(String routeId) {
    // Subscribe to all buses on a specific route
    if (kDebugMode) {
      print('Subscribing to route buses: $routeId');
    }
  }

  Future<void> initializeOfflineMode() async {
    if (kDebugMode) {
      print('Initializing offline mode');
    }
  }

  Future<void> switchToOfflineMode() async {
    if (kDebugMode) {
      print('Switching to offline mode');
    }
  }

  Future<void> switchToOnlineMode() async {
    if (kDebugMode) {
      print('Switching to online mode');
    }
  }

  Future<List<Map<String, dynamic>>> getOfflineRoutes() async {
    // Return cached offline routes
    return [];
  }

  Future<List<Map<String, dynamic>>> getOfflineEmergencyContacts() async {
    // Return cached emergency contacts
    return [];
  }

  Future<void> updateNavigationFeatures(LatLng currentLocation) async {
    // Update navigation-related features
    if (kDebugMode) {
      print('Updating navigation features for: $currentLocation');
    }
  }

  void updateLaneGuidance(Map<String, dynamic> guidance) {
    // Update lane guidance display
    if (kDebugMode) {
      print('Updating lane guidance: $guidance');
    }
  }

  void clearNavigationData() {
    // Clear all navigation-related data
    if (kDebugMode) {
      print('Clearing navigation data');
    }
  }

  @override
  void dispose() {
    _busLocationSubscriptions.clear();
    super.dispose();
  }
}
