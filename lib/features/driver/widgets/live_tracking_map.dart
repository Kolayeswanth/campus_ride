import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart' as latlong;
import 'package:provider/provider.dart';

import '../../../core/services/location_tracking_service.dart';
import '../../../core/services/real_routing_service.dart';
import '../../../core/services/ola_maps_routing_service.dart';
import '../../../core/models/driver_trip.dart';
import '../../../core/models/bus_route.dart';

class LiveTrackingMap extends StatefulWidget {
  final DriverTrip currentTrip;
  final VoidCallback? onStopTrip;
  final VoidCallback? onPauseTrip;
  final VoidCallback? onResumeTrip;
  final Function(VoidCallback)? onMapControllerReady;

  const LiveTrackingMap({
    super.key,
    required this.currentTrip,
    this.onStopTrip,
    this.onPauseTrip,
    this.onResumeTrip,
    this.onMapControllerReady,
  });

  @override
  State<LiveTrackingMap> createState() => _LiveTrackingMapState();
}

class _LiveTrackingMapState extends State<LiveTrackingMap> {
  final MapController _mapController = MapController();
  List<latlong.LatLng> _routePoints = [];
  List<latlong.LatLng> _dynamicRoutePoints = [];
  Position? _currentPosition;
  Timer? _positionTimer;
  bool _isLoading = true;
  bool _isFollowingDriver = true; // Enable automatic following by default
  LocationTrackingService? _locationService;
  DateTime? _lastRouteUpdate; // Track when we last updated the route

  @override
  void initState() {
    super.initState();
    print('🗺️ MAP WIDGET INIT - Trip ID: ${widget.currentTrip.id}');
    _initializeMap();
    
    // Expose the center function to parent widget
    widget.onMapControllerReady?.call(_centerMapOnCurrentPosition);
  }

  @override
  void dispose() {
    _positionTimer?.cancel();
    _locationService?.removeListener(_onLocationServiceUpdate);
    super.dispose();
  }

  void _initializeMap() async {
    try {
      // Get LocationTrackingService instance and setup listener
      _locationService = Provider.of<LocationTrackingService>(context, listen: false);
      _locationService?.addListener(_onLocationServiceUpdate);
      print('🎧 Location service listener added - tracking: ${_locationService?.isTracking}');
      
      // Force get current position immediately
      await _getCurrentPositionNow();
      
      // Load route points from service
      await _loadRoutePoints();
      
      // Get initial position from service
      await _updateCurrentPosition();
      
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        
        // Delay map operations until after the widget is fully rendered
        await Future.delayed(const Duration(milliseconds: 500));
        
        // Always try to center on current position first
        if (_currentPosition != null) {
          print('🎯 MAP INIT - Centering on current position: ${_currentPosition!.latitude}, ${_currentPosition!.longitude}');
          _centerMapOnCurrentPosition();
        } else if (_routePoints.isNotEmpty) {
          print('🎯 MAP INIT - No current position, using route start');
          _fitMapToRoute();
        }
      }
      
    } catch (e) {
      print('Error initializing map: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _loadRoutePoints() async {
    try {
      print('📍 LOADING ROUTE POINTS FROM TRIP DATA...');
      print('📍 DEBUG - Trip ID: ${widget.currentTrip.id}');
      print('📍 DEBUG - Trip route ID: ${widget.currentTrip.routeId}');
      print('📍 DEBUG - Trip route object: ${widget.currentTrip.route}');
      print('📍 DEBUG - Trip direction: ${widget.currentTrip.direction}');
      
      // Check if we have route data from the trip
      if (widget.currentTrip.route != null) {
        final route = widget.currentTrip.route!;
        print('📍 Trip route found: ${route.routeName}');
        print('📍 Start: ${route.startLocation.latitude}, ${route.startLocation.longitude}');
        print('📍 End: ${route.endLocation.latitude}, ${route.endLocation.longitude}');
        
        List<latlong.LatLng> points = [];
        
        // If we have waypoints, use them
        if (route.waypoints != null && route.waypoints!.isNotEmpty) {
          print('📍 Using waypoints (${route.waypoints!.length} points)');
          points = route.waypoints!.map((wp) => latlong.LatLng(wp.latitude, wp.longitude)).toList();
        } else {
          // Fallback: create simple route from start to end
          print('📍 No waypoints found, creating simple start->end route');
          points = [
            latlong.LatLng(route.startLocation.latitude, route.startLocation.longitude),
            latlong.LatLng(route.endLocation.latitude, route.endLocation.longitude),
          ];
        }
        
        setState(() {
          _routePoints = points;
          // Initially show the full route
          _dynamicRoutePoints = List.from(points);
        });
        
        print('📍 Route points loaded: ${_routePoints.length}');
        if (_routePoints.isNotEmpty) {
          print('📍 First point: ${_routePoints.first.latitude}, ${_routePoints.first.longitude}');
          print('📍 Last point (ACTUAL DESTINATION): ${_routePoints.last.latitude}, ${_routePoints.last.longitude}');
        }
        
        // Skip Apple Maps style routing for now to avoid dual polylines
        print('📍 Skipping Apple Maps routing to avoid dual polylines - using full route');
        // TODO: Implement proper Apple Maps style routing later
      } else {
        print('⚠️ No route data found in currentTrip');
        print('📍 ATTEMPTING TO LOAD ROUTE FROM LOCATION SERVICE...');
        
        // Try to get route from LocationTrackingService as fallback
        final locationService = Provider.of<LocationTrackingService>(context, listen: false);
        final serviceRoutePolyline = locationService.routePolyline;
        
        if (serviceRoutePolyline.isNotEmpty) {
          print('📍 Found ${serviceRoutePolyline.length} points in LocationTrackingService');
          // Convert from List<Map<String, double>> to List<LatLng>
          final convertedPoints = serviceRoutePolyline.map((point) {
            final lat = point['latitude'] ?? point['lat'] ?? 0.0;
            final lng = point['longitude'] ?? point['lng'] ?? 0.0;
            return latlong.LatLng(lat, lng);
          }).toList();

          // Check if last point is current position (wrong destination)
          if (convertedPoints.length > 1 && _currentPosition != null) {
            final lastPoint = convertedPoints.last;
            final currentLat = _currentPosition!.latitude;
            final currentLng = _currentPosition!.longitude;
            
            // If last point matches current position, it means the service added current position incorrectly
            const double tolerance = 0.0001;
            if ((lastPoint.latitude - currentLat).abs() < tolerance && 
                (lastPoint.longitude - currentLng).abs() < tolerance) {
              print('📍 FIXING DESTINATION - Last point was current position, removing it');
              convertedPoints.removeLast(); // Remove the incorrect current position
              print('📍 Corrected route now has ${convertedPoints.length} points');
              print('📍 ACTUAL DESTINATION: ${convertedPoints.last.latitude}, ${convertedPoints.last.longitude}');
            }
          }

          setState(() {
            _routePoints = convertedPoints;
            _dynamicRoutePoints = List.from(convertedPoints);
          });
          
          print('📍 ROUTE LOADED FROM SERVICE - ${_routePoints.length} points');
          if (_routePoints.isNotEmpty) {
            print('📍 First point: ${_routePoints.first.latitude}, ${_routePoints.first.longitude}');
            print('📍 Last point (CORRECTED DESTINATION): ${_routePoints.last.latitude}, ${_routePoints.last.longitude}');
          }
        } else {
          print('⚠️ No route data available from service or trip');
          print('📍 Trying to get route data from trip route ID: ${widget.currentTrip.routeId}');
          
          // Try to load route data based on trip direction and route ID
          await _loadRouteFromTripData();
        }
      }
    } catch (e) {
      print('Error loading route points: $e');
    }
  }

  /// Load route data based on trip information when normal loading fails
  Future<void> _loadRouteFromTripData() async {
    try {
      print('📍 ATTEMPTING TO LOAD ROUTE FROM TRIP DATA DIRECTLY...');
      print('📍 Trip Route ID: ${widget.currentTrip.routeId}');
      print('📍 Trip Direction: ${widget.currentTrip.direction}');
      
      // Try to restart location tracking to reload route data
      print('📍 Attempting to restart location service to reload route...');
      
      final locationService = Provider.of<LocationTrackingService>(context, listen: false);
      
      // Check if tracking is already running, if not try to restart
      if (!locationService.isTracking) {
        print('📍 Location service not tracking, this might be why route is empty');
      }
      
      // For now, create a minimal fallback until proper route loading is implemented
      final currentLat = _currentPosition?.latitude ?? 16.5425678;
      final currentLng = _currentPosition?.longitude ?? 81.4969305;
      
      // Create a minimal route from current position
      // In production, this should query the database for the actual route
      setState(() {
        _routePoints = [
          latlong.LatLng(currentLat, currentLng), // Start from current position
          latlong.LatLng(currentLat + 0.005, currentLng + 0.005), // Simple destination 500m away
        ];
        _dynamicRoutePoints = List.from(_routePoints);
      });
      
      print('📍 TEMPORARY FALLBACK ROUTE CREATED - ${_routePoints.length} points');
      print('📍 Start: $currentLat, $currentLng (Current position)');
      print('📍 End: ${currentLat + 0.005}, ${currentLng + 0.005} (Temporary destination)');
      print('⚠️  ROUTE DATA NEEDS TO BE PROPERLY LOADED FROM DATABASE');
      print('📍 Trip Route ID: ${widget.currentTrip.routeId}');
      print('📍 Trip Direction: ${widget.currentTrip.direction}'); 
      
      // Show error to user that route needs to be reloaded
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Route data lost. Please restart the trip to reload route information.'),
            backgroundColor: Colors.orange,
            duration: Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      print('Error loading route from trip data: $e');
      // Final fallback - minimal route
      final currentLat = _currentPosition?.latitude ?? 16.5425678;
      final currentLng = _currentPosition?.longitude ?? 81.4969305;
      
      setState(() {
        _routePoints = [
          latlong.LatLng(currentLat, currentLng),
          latlong.LatLng(currentLat + 0.001, currentLng + 0.001),
        ];
        _dynamicRoutePoints = List.from(_routePoints);
      });
      
      print('📍 MINIMAL FALLBACK ROUTE CREATED');
    }
  }

  Future<void> _getCurrentPositionNow() async {
    try {
      print('📍 Getting fresh position for map initialization...');
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 5),
      );
      
      if (mounted) {
        setState(() {
          _currentPosition = position;
        });
      }
      print('📍 Fresh position obtained: ${position.latitude}, ${position.longitude}');
    } catch (e) {
      print('📍 Failed to get fresh position: $e');
    }
  }

  /// Listener for LocationTrackingService updates
  void _onLocationServiceUpdate() {
    if (!mounted || _locationService == null) {
      print('🚫 Location service update skipped - mounted: $mounted, service: ${_locationService != null}');
      return;
    }
    
    final position = _locationService!.currentPosition;
    print('🔄 Location service notified - position available: ${position != null}');
    
    if (position != null) {
      _updateCurrentPositionFromService(position);
    }
  }

  /// Update position from location service and automatically follow driver
  void _updateCurrentPositionFromService(Position position) {
    try {
      final isFirstUpdate = _currentPosition == null;
      final shouldCenterMap = isFirstUpdate || _isFollowingDriver;
      
      print('🔄 REAL-TIME POSITION UPDATE - New position: ${position.latitude}, ${position.longitude}');
      print('🔄 Auto-follow enabled: $_isFollowingDriver, Should center: $shouldCenterMap');
      
      setState(() {
        _currentPosition = position;
      });

      // Skip Apple Maps style routing for now to avoid dual polylines
      // TODO: Implement proper single-polyline Apple Maps style routing
      print('📍 Current position updated - skipping dual polyline Apple Maps routing');

      // Automatically center map on current position if following is enabled
      if (shouldCenterMap) {
        print('🎯 AUTO-FOLLOWING - Centering map on driver position');
        Future.microtask(() => _centerMapOnCurrentPosition());
      } else {
        print('📍 Position updated but not centering (auto-follow disabled)');
      }
    } catch (e) {
      print('Error updating position from service: $e');
    }
  }

  @deprecated
  void _startLocationUpdates() {
    // This method is no longer used - we now listen to LocationTrackingService directly
    // Kept for backward compatibility but should be removed in future cleanup
  }

  @deprecated  
  Future<void> _updateCurrentPosition() async {
    // This method is no longer used - we now listen to LocationTrackingService directly
    // Kept for backward compatibility but should be removed in future cleanup
  }

  /// Apple Maps style route update - get fresh road route from current position to destination
  void _updateAppleMapsStyleRoute() {
    if (_currentPosition == null) {
      print('🍎 SKIPPING APPLE ROUTE UPDATE - No current position');
      return;
    }

    // Get the actual destination from route points (corrected destination)
    latlong.LatLng? destination;
    
    if (_routePoints.isNotEmpty) {
      // Use the corrected route points destination (should be actual destination now)
      destination = _routePoints.last;
      print('🍎 Using CORRECTED route destination: ${destination.latitude}, ${destination.longitude}');
    } else if (widget.currentTrip.route != null) {
      // Fallback to trip destination if available
      final route = widget.currentTrip.route!;
      destination = latlong.LatLng(route.endLocation.latitude, route.endLocation.longitude);
      print('🍎 Using trip route destination: ${destination.latitude}, ${destination.longitude}');
    } else {
      print('🍎 SKIPPING APPLE ROUTE UPDATE - No destination available');
      return;
    }

    // Verify destination is different from current position
    final currentLatLng = latlong.LatLng(_currentPosition!.latitude, _currentPosition!.longitude);
    const double tolerance = 0.0001;
    if ((currentLatLng.latitude - destination.latitude).abs() < tolerance && 
        (currentLatLng.longitude - destination.longitude).abs() < tolerance) {
      print('🍎 SKIPPING - Already at destination (within ${tolerance * 111000}m)');
      return;
    }

    // Throttle route requests to avoid too many API calls (max once per 30 seconds)
    final now = DateTime.now();
    if (_lastRouteUpdate != null && 
        now.difference(_lastRouteUpdate!).inSeconds < 30) {
      print('🍎 THROTTLING: Route updated ${now.difference(_lastRouteUpdate!).inSeconds}s ago, skipping');
      return;
    }

    print('🍎 UPDATING APPLE MAPS STYLE ROUTE');
    print('🍎 Current: ${currentLatLng.latitude}, ${currentLatLng.longitude}');
    print('🍎 Destination: ${destination.latitude}, ${destination.longitude}');
    
    // Check if current position is too close to destination (within 50 meters)
    final distanceToDestination = _calculateDistance(currentLatLng, destination);
    if (distanceToDestination < 0.05) { // Less than 50 meters
      print('🍎 SKIPPING: Too close to destination (${(distanceToDestination * 1000).toStringAsFixed(0)}m)');
      return;
    }
    
    _lastRouteUpdate = now;
    
    // Get fresh road route from current position to destination using admin service
    _getFreshRoadRouteFromCurrentPosition(currentLatLng, destination);
  }

  /// Get fresh road route from current position to destination (like admin screen)
  Future<void> _getFreshRoadRouteFromCurrentPosition(latlong.LatLng currentPos, latlong.LatLng destination) async {
    try {
      print('🛣️ REQUESTING FRESH ROAD ROUTE FROM CURRENT POSITION...');
      
      // Use OlaMapsRoutingService like in admin screen
      final directions = await OlaMapsRoutingService.getDirections([
        LatLng(currentPos.latitude, currentPos.longitude),
        LatLng(destination.latitude, destination.longitude),
      ], profile: 'driving', vehicleType: 'car');
      
      if (directions.isNotEmpty && 
          directions['route_points'] != null && 
          (directions['route_points'] as List).isNotEmpty) {
        
        final freshRoutePoints = directions['route_points'] as List<LatLng>;
        final convertedPoints = freshRoutePoints.map((point) => 
          latlong.LatLng(point.latitude, point.longitude)
        ).toList();
        
        final oldPointsCount = _dynamicRoutePoints.length;
        setState(() {
          // Replace with fresh road route from current position to destination
          _dynamicRoutePoints = convertedPoints;
        });
        
        print('🍎 ✅ FRESH ROAD ROUTE LOADED: ${convertedPoints.length} points');
        print('🍎 Was: $oldPointsCount points, Now: ${_dynamicRoutePoints.length} points');
        print('🍎 Route shows ONLY road from current position → destination');
        
        // Also update the distance info if available
        final distance = directions['distance_km'] as double?;
        final duration = directions['duration_minutes'] as double?;
        if (distance != null && duration != null) {
          print('🛣️ Route info: ${distance.toStringAsFixed(1)}km, ${duration.toStringAsFixed(0)}min');
        }
      } else {
        print('🍎 ❌ Fresh road route request failed - using fallback');
        _fallbackToRemainingRoute(currentPos);
      }
    } catch (e) {
      print('🍎 ❌ Error getting fresh road route: $e');
      _fallbackToRemainingRoute(currentPos);
    }
  }

  /// Fallback method if road routing service fails
  void _fallbackToRemainingRoute(latlong.LatLng currentPos) {
    // Find the closest point on existing route and show remaining path
    double minDistance = double.infinity;
    int closestIndex = 0;
    
    for (int i = 0; i < _routePoints.length; i++) {
      final distance = _calculateDistance(currentPos, _routePoints[i]);
      if (distance < minDistance) {
        minDistance = distance;
        closestIndex = i;
      }
    }
    
    List<latlong.LatLng> remainingRoute = [currentPos];
    final startIndex = (closestIndex + 2).clamp(0, _routePoints.length - 1);
    if (startIndex < _routePoints.length) {
      remainingRoute.addAll(_routePoints.sublist(startIndex));
    }
    
    setState(() {
      _dynamicRoutePoints = remainingRoute;
    });
    
    print('🍎 FALLBACK: Using remaining route points from current position');
  }

  latlong.LatLng _getClosestPointOnSegment(latlong.LatLng point, latlong.LatLng segmentStart, latlong.LatLng segmentEnd) {
    final dx = segmentEnd.longitude - segmentStart.longitude;
    final dy = segmentEnd.latitude - segmentStart.latitude;
    
    if (dx == 0 && dy == 0) return segmentStart;
    
    final t = ((point.longitude - segmentStart.longitude) * dx + (point.latitude - segmentStart.latitude) * dy) / (dx * dx + dy * dy);
    final clampedT = t.clamp(0.0, 1.0);
    
    return latlong.LatLng(
      segmentStart.latitude + clampedT * dy,
      segmentStart.longitude + clampedT * dx,
    );
  }

  double _calculateDistance(latlong.LatLng point1, latlong.LatLng point2) {
    return Geolocator.distanceBetween(point1.latitude, point1.longitude, point2.latitude, point2.longitude);
  }

  double _calculateProgressOnSegment(latlong.LatLng point, latlong.LatLng segmentStart, latlong.LatLng segmentEnd) {
    final dx = segmentEnd.longitude - segmentStart.longitude;
    final dy = segmentEnd.latitude - segmentStart.latitude;
    
    if (dx == 0 && dy == 0) return 0.0;
    
    final t = ((point.longitude - segmentStart.longitude) * dx + (point.latitude - segmentStart.latitude) * dy) / (dx * dx + dy * dy);
    return t.clamp(0.0, 1.0);
  }

  bool _isMovingForward(latlong.LatLng prevPos, latlong.LatLng currentPos, int routeIndex) {
    if (routeIndex >= _routePoints.length - 1) return false;
    
    final routeDirection = latlong.LatLng(
      _routePoints[routeIndex + 1].latitude - _routePoints[routeIndex].latitude,
      _routePoints[routeIndex + 1].longitude - _routePoints[routeIndex].longitude,
    );
    
    final movementDirection = latlong.LatLng(
      currentPos.latitude - prevPos.latitude,
      currentPos.longitude - prevPos.longitude,
    );
    
    // Calculate dot product to determine if moving in same direction as route
    final dotProduct = (routeDirection.latitude * movementDirection.latitude) + 
                      (routeDirection.longitude * movementDirection.longitude);
    
    return dotProduct > 0;
  }

  List<latlong.LatLng> _calculateDynamicRoute(int currentIndex, double progressOnSegment, bool movingForward) {
    List<latlong.LatLng> dynamicPoints = [];
    
    if (movingForward) {
      // Show route from current position to end
      // Add interpolated current position on segment
      if (currentIndex < _routePoints.length - 1) {
        final segmentStart = _routePoints[currentIndex];
        final segmentEnd = _routePoints[currentIndex + 1];
        final currentPointOnRoute = latlong.LatLng(
          segmentStart.latitude + progressOnSegment * (segmentEnd.latitude - segmentStart.latitude),
          segmentStart.longitude + progressOnSegment * (segmentEnd.longitude - segmentStart.longitude),
        );
        dynamicPoints.add(currentPointOnRoute);
        
        // Add remaining points in route
        for (int i = currentIndex + 1; i < _routePoints.length; i++) {
          dynamicPoints.add(_routePoints[i]);
        }
      }
    } else {
      // Show route from start to current position
      // Add points from start to current segment
      for (int i = 0; i <= currentIndex; i++) {
        dynamicPoints.add(_routePoints[i]);
      }
      
      // Add interpolated current position on segment
      if (currentIndex < _routePoints.length - 1) {
        final segmentStart = _routePoints[currentIndex];
        final segmentEnd = _routePoints[currentIndex + 1];
        final currentPointOnRoute = latlong.LatLng(
          segmentStart.latitude + progressOnSegment * (segmentEnd.latitude - segmentStart.latitude),
          segmentStart.longitude + progressOnSegment * (segmentEnd.longitude - segmentStart.longitude),
        );
        dynamicPoints.add(currentPointOnRoute);
      }
    }
    
    return dynamicPoints;
  }

  void _fitMapToRoute() {
    final pointsToFit = _dynamicRoutePoints.isNotEmpty ? _dynamicRoutePoints : _routePoints;
    if (pointsToFit.isEmpty) return;
    
    try {
      // Calculate bounds manually since LatLngBounds.fromPoints might not be available
      double minLat = pointsToFit.first.latitude;
      double maxLat = pointsToFit.first.latitude;
      double minLng = pointsToFit.first.longitude;
      double maxLng = pointsToFit.first.longitude;
      
      for (final point in pointsToFit) {
        minLat = minLat < point.latitude ? minLat : point.latitude;
        maxLat = maxLat > point.latitude ? maxLat : point.latitude;
        minLng = minLng < point.longitude ? minLng : point.longitude;
        maxLng = maxLng > point.longitude ? maxLng : point.longitude;
      }
      
      final bounds = LatLngBounds(
        latlong.LatLng(minLat, minLng),
        latlong.LatLng(maxLat, maxLng),
      );
      
      _mapController.fitCamera(
        CameraFit.bounds(
          bounds: bounds,
          padding: const EdgeInsets.all(50),
        ),
      );
    } catch (e) {
      print('Error fitting map to route: $e');
    }
  }

  /// Request a fresh dynamic route from current position to destination
  Future<void> _requestDynamicRouteFromCurrentPosition() async {
    if (_currentPosition == null || _routePoints.isEmpty) return;
    
    try {
      // Use the last point in our route as destination (even if it's sparse)
      final destination = _routePoints.last;
      final currentPos = latlong.LatLng(_currentPosition!.latitude, _currentPosition!.longitude);
      
      print('🛣️ REQUESTING FRESH ROUTE: ${currentPos.latitude}, ${currentPos.longitude} → ${destination.latitude}, ${destination.longitude}');
      
      // Import and use RealRoutingService for fresh road route
      final routeResponse = await RealRoutingService.getDirections([
        LatLng(currentPos.latitude, currentPos.longitude),
        LatLng(destination.latitude, destination.longitude),
      ]);
      
      if (routeResponse['success'] == true && routeResponse['route_points'] != null) {
        final freshRoutePoints = routeResponse['route_points'] as List<LatLng>;
        final convertedPoints = freshRoutePoints.map((point) => 
          latlong.LatLng(point.latitude, point.longitude)
        ).toList();
        
        setState(() {
          _routePoints = convertedPoints; // Replace with fresh detailed route
          _dynamicRoutePoints = List.from(convertedPoints); // Initialize dynamic route
        });
        
        print('🛣️ ✅ FRESH ROUTE LOADED: ${convertedPoints.length} detailed points');
      } else {
        print('🛣️ ❌ Fresh route request failed, keeping existing route');
      }
    } catch (e) {
      print('🛣️ Error requesting fresh route: $e');
    }
  }

  void _centerMapOnCurrentPosition() {
    if (_currentPosition == null) {
      print('📍 RELOCATE - No current position available');
      return;
    }
    
    try {
      final targetPosition = latlong.LatLng(_currentPosition!.latitude, _currentPosition!.longitude);
      print('📍 AUTO-CENTER - Moving map to: ${_currentPosition!.latitude}, ${_currentPosition!.longitude}');
      
      // Use smooth animated move for better UX
      _mapController.move(targetPosition, 16.0);
      
      // Enable following mode when manually relocating
      _isFollowingDriver = true;
    } catch (e) {
      print('Error centering map: $e');
    }
  }

  /// Toggle automatic driver following mode
  void _toggleFollowingMode() {
    setState(() {
      _isFollowingDriver = !_isFollowingDriver;
    });
    
    if (_isFollowingDriver && _currentPosition != null) {
      // If enabling follow mode, immediately center on current position
      _centerMapOnCurrentPosition();
    }
    
    print('📍 FOLLOW MODE ${_isFollowingDriver ? 'ENABLED' : 'DISABLED'}');
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: Colors.grey[100],
        ),
        child: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text(
                'Loading map...',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Stack(
        children: [
          // Clean map without overlays
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _currentPosition != null 
                  ? latlong.LatLng(_currentPosition!.latitude, _currentPosition!.longitude)
                  : (_routePoints.isNotEmpty 
                      ? _routePoints.first 
                      : const latlong.LatLng(12.9716, 77.5946)), // Bangalore fallback
              initialZoom: 15.0,
              interactionOptions: const InteractionOptions(
                flags: InteractiveFlag.pinchZoom | 
                       InteractiveFlag.drag | 
                       InteractiveFlag.doubleTapZoom,
              ),
              onPositionChanged: (position, hasGesture) {
                // Disable auto-following when user manually drags the map
                if (hasGesture && _isFollowingDriver) {
                  setState(() {
                    _isFollowingDriver = false;
                  });
                  print('📍 AUTO-FOLLOW DISABLED - User manually panned map');
                }
              },
            ),
            children: [
              // OpenStreetMap tiles
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.example.campus_ride',
                maxZoom: 19,
              ),
              
              // Route polyline - Apple Maps style (ONLY show road from current position to destination)
              if (_dynamicRoutePoints.isNotEmpty)
                PolylineLayer(
                  polylines: [
                    // Shadow/Border polyline
                    Polyline(
                      points: _dynamicRoutePoints,
                      color: Colors.black.withOpacity(0.4),
                      strokeWidth: 10.0,
                    ),
                    // Main route polyline - Apple Maps blue
                    Polyline(
                      points: _dynamicRoutePoints,
                      color: const Color(0xFF007AFF),
                      strokeWidth: 7.0,
                    ),
                    // Inner highlight
                    Polyline(
                      points: _dynamicRoutePoints,
                      color: const Color(0xFF4DA6FF),
                      strokeWidth: 4.0,
                    ),
                  ],
                ),
              
              // Markers
              MarkerLayer(
                markers: [
                  // Destination marker - Apple Maps style (only show destination, not start)
                  if (_routePoints.isNotEmpty)
                  if (_routePoints.length > 1)
                    Marker(
                      point: _routePoints.last,
                      child: Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: const Color(0xFFFF3B30),
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.2),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.flag,
                          color: Colors.white,
                          size: 18,
                        ),
                      ),
                    ),
                  
                  // Current position marker - Apple Maps style
                  if (_currentPosition != null)
                    Marker(
                      point: latlong.LatLng(
                        _currentPosition!.latitude,
                        _currentPosition!.longitude,
                      ),
                      child: _AppleMapsLocationMarker(),
                    ),
                ],
              ),
            ],
          ),
          
          // Map control buttons - positioned in top-right corner
          Positioned(
            top: 16,
            right: 16,
            child: Column(
              children: [
                // Following mode toggle button
                Material(
                  elevation: 8,
                  borderRadius: BorderRadius.circular(28),
                  child: Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: _isFollowingDriver ? const Color(0xFF007AFF) : Colors.white,
                      borderRadius: BorderRadius.circular(28),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(28),
                      onTap: _toggleFollowingMode,
                      child: Icon(
                        _isFollowingDriver ? Icons.gps_fixed : Icons.gps_not_fixed,
                        color: _isFollowingDriver ? Colors.white : const Color(0xFF007AFF),
                        size: 28,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                // Manual relocate button
                Material(
                  elevation: 8,
                  borderRadius: BorderRadius.circular(28),
                  child: Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(28),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(28),
                      onTap: _centerMapOnCurrentPosition,
                      child: const Icon(
                        Icons.my_location,
                        color: Color(0xFF007AFF),
                        size: 28,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

        ],
      ),
    );
  }

  Widget _AppleMapsLocationMarker() {
    return Stack(
      alignment: Alignment.center,
      children: [
        // Outer pulsing ring
        TweenAnimationBuilder<double>(
          tween: Tween(begin: 0.0, end: 1.0),
          duration: const Duration(seconds: 2),
          curve: Curves.easeOut,
          builder: (context, value, child) {
            return Container(
              width: 60 * value,
              height: 60 * value,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF007AFF).withOpacity(0.3 * (1 - value)),
                border: Border.all(
                  color: const Color(0xFF007AFF).withOpacity(0.5 * (1 - value)),
                  width: 2,
                ),
              ),
            );
          },
          onEnd: () {
            // Restart animation
            if (mounted) {
              setState(() {});
            }
          },
        ),
        // Inner stable dot
        Container(
          width: 20,
          height: 20,
          decoration: BoxDecoration(
            color: const Color(0xFF007AFF),
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 3),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
        ),
      ],
    );
  }
}