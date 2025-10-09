import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart' as latlong;

import '../../../core/services/live_location_service.dart';
import '../../../core/services/enhanced_routing_service.dart';
import '../../../core/models/driver_trip.dart';
import '../../../core/models/bus_route.dart';

/// Specialized navigation map widget for drivers with live location tracking
/// Features: Live GPS tracking, dynamic routing, camera following, route recalculation
class DriverNavigationMap extends StatefulWidget {
  final DriverTrip currentTrip;
  final BusRoute assignedRoute;
  final VoidCallback? onStopTrip;
  final Function(VoidCallback)? onMapControllerReady;

  const DriverNavigationMap({
    super.key,
    required this.currentTrip,
    required this.assignedRoute,
    this.onStopTrip,
    this.onMapControllerReady,
  });

  @override
  State<DriverNavigationMap> createState() => _DriverNavigationMapState();
}

class _DriverNavigationMapState extends State<DriverNavigationMap>
    with TickerProviderStateMixin {
  final MapController _mapController = MapController();
  final LiveLocationService _locationService = LiveLocationService.instance;
  
  // Location and routing state
  Position? _currentPosition;
  List<latlong.LatLng> _routePoints = [];
  int _currentRouteIndex = 0; // Track progress on route for polyline erasure
  StreamSubscription<Position>? _positionSubscription;
  Timer? _routeRecalculationTimer;
  
  // UI state
  bool _isLoading = true;
  bool _isFollowingDriver = true;
  DateTime? _lastRouteUpdate;
  double? _currentBearing; // For 3D map rotation based on movement direction
  double _compassHeading = 0.0; // Device compass heading
  bool _compassMode = false; // Toggle between center mode and compass mode
  
  // Animation controllers
  late AnimationController _routeAnimationController;
  late Animation<double> _routeAnimation;
  late AnimationController _driverMarkerController;
  late Animation<double> _driverMarkerRotation;

  @override
  void initState() {
    super.initState();
    print('🚗 Driver Navigation Map initialized for trip: ${widget.currentTrip.id}');
    _setupAnimations();
    _initializeNavigation();
  }

  void _setupAnimations() {
    // Route animation
    _routeAnimationController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    );
    _routeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _routeAnimationController,
      curve: Curves.easeInOut,
    ));

    // Driver marker rotation animation (smooth and responsive)
    _driverMarkerController = AnimationController(
      duration: const Duration(milliseconds: 600), // Smoother rotation animation
      vsync: this,
    );
    _driverMarkerRotation = Tween<double>(
      begin: 0.0,
      end: 0.0,
    ).animate(CurvedAnimation(
      parent: _driverMarkerController,
      curve: Curves.easeInOut,
    ));
  }

  Future<void> _initializeNavigation() async {
    try {
      setState(() => _isLoading = true);

      // Initialize location service
      final initialized = await _locationService.initialize();
      if (!initialized) {
        throw Exception('Failed to initialize location service');
      }

      // Start location tracking
      await _locationService.startTracking();
      
      // Get current position
      _currentPosition = await _locationService.getCurrentLocation();
      if (_currentPosition == null) {
        throw Exception('Could not get current location');
      }

      // Start listening to position updates
      _positionSubscription = _locationService.positionStream.listen(
        _handlePositionUpdate,
        onError: _handleLocationError,
      );

      // Calculate initial route
      await _calculateRouteFromCurrentLocation();

      // Set up route recalculation timer
      _startRouteRecalculationTimer();

      // Notify parent that map is ready
      widget.onMapControllerReady?.call(_centerOnDriverLocation);

      setState(() => _isLoading = false);
      
      print('✅ Driver navigation initialized successfully');
    } catch (e) {
      print('❌ Failed to initialize navigation: $e');
      setState(() => _isLoading = false);
    }
  }

  void _handlePositionUpdate(Position position) {
    final previousPosition = _currentPosition;
    _currentPosition = position;
    
    double? movementBearing;

    // Calculate movement bearing for 3D navigation view (Apple Maps style)
    if (previousPosition != null) {
      final distance = Geolocator.distanceBetween(
        previousPosition.latitude,
        previousPosition.longitude,
        position.latitude,
        position.longitude,
      );
      
      // Process movements with smooth interpolation (increased threshold for stability)
      if (distance > 2.0) { // Increased threshold to reduce glitchy updates
        movementBearing = Geolocator.bearingBetween(
          previousPosition.latitude,
          previousPosition.longitude,
          position.latitude,
          position.longitude,
        );
        
        // Smooth bearing updates with interpolation
        if (_currentBearing != null) {
          final bearingDiff = _normalizeBearingDifference(movementBearing - _currentBearing!);
          final smoothBearing = _currentBearing! + (bearingDiff * 0.3); // Smooth interpolation
          _currentBearing = smoothBearing;
          _compassHeading = smoothBearing;
        } else {
          _currentBearing = movementBearing;
          _compassHeading = movementBearing;
        }
        
        // Update marker rotation smoothly
        _updateDriverMarkerRotation(_currentBearing ?? movementBearing);
      }
      
      // Always update position but with smooth state change
      if (mounted) {
        setState(() {
          // Smooth position update
        });
      }
    }

    // Smooth camera following with controlled updates
    if (_isFollowingDriver && mounted) {
      // Smooth camera update with animation for better UX
      Future.delayed(const Duration(milliseconds: 100), () {
        if (mounted && _isFollowingDriver) {
          _centerOnDriverLocation(animate: true);
        }
      });
    }

    // Update UI state
    if (mounted) {
      setState(() {
        // Trigger rebuild to update marker position
      });
    }

    // Update route progress for polyline erasure
    _updateRouteProgress();

    // Check if route recalculation is needed
    _checkRouteDeviation();

    // Reduced logging for performance - only log every 10th update
    if (DateTime.now().millisecondsSinceEpoch % 5000 < 100) {
      print('🔔 Location update - position: ${position.latitude}, ${position.longitude}, accuracy: ${position.accuracy}m');
    }
  }

  void _handleLocationError(dynamic error) {
    print('❌ Location tracking error: $error');
    // Show error to user but continue trying
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('GPS tracking interrupted: $error'),
        backgroundColor: Colors.orange,
        action: SnackBarAction(
          label: 'Retry',
          onPressed: () => _locationService.startTracking(),
        ),
      ),
    );
  }

  Future<void> _calculateRouteFromCurrentLocation() async {
    if (_currentPosition == null) return;

    try {
      print('📍 Calculating OSRM route from current location to destination');
      print('  Current: ${_currentPosition!.latitude}, ${_currentPosition!.longitude}');

      // Get destination based on trip direction
      final destination = widget.currentTrip.direction == TripDirection.outbound
          ? latlong.LatLng(widget.assignedRoute.endLocation.latitude, widget.assignedRoute.endLocation.longitude)
          : latlong.LatLng(widget.assignedRoute.startLocation.latitude, widget.assignedRoute.startLocation.longitude);

      print('  Destination: ${destination.latitude}, ${destination.longitude}');

      // Recalculating route in background

      // Use OSRM routing for live navigation from current position to destination
      final result = await EnhancedRoutingService.getEnhancedRoute([
        latlong.LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
        destination,
      ]);

      final routePoints = result['route_points'] as List<latlong.LatLng>;

      if (mounted) {
        setState(() {
          _routePoints = routePoints;
          _lastRouteUpdate = DateTime.now();
        });
        _routeAnimationController.forward(from: 0.0);
        
        if (_isFollowingDriver) {
          // Instant camera update for immediate response
          _centerOnDriverLocation(animate: false);
        }
      }
    } catch (e) {
      print('❌ Failed to calculate route: $e');
      // Route calculation failed
    }
  }



  void _updateRouteProgress() {
    if (_routePoints.isEmpty || _currentPosition == null) return;

    final currentLatLng = latlong.LatLng(_currentPosition!.latitude, _currentPosition!.longitude);
    
    // Find the closest point on route and update current index
    double minDistance = double.infinity;
    int closestIndex = _currentRouteIndex;
    
    for (int i = _currentRouteIndex; i < _routePoints.length; i++) {
      final distance = Geolocator.distanceBetween(
        currentLatLng.latitude,
        currentLatLng.longitude,
        _routePoints[i].latitude,
        _routePoints[i].longitude,
      );
      
      if (distance < minDistance) {
        minDistance = distance;
        closestIndex = i;
      }
      
      // Stop searching if we're getting farther away
      if (distance > minDistance + 50) break;
    }
    
    // Update route index if we've made progress (only move forward)
    if (closestIndex > _currentRouteIndex) {
      _currentRouteIndex = closestIndex;
    }
  }

  void _checkRouteDeviation() {
    if (_routePoints.isEmpty || _currentPosition == null) return;

    final currentLatLng = latlong.LatLng(_currentPosition!.latitude, _currentPosition!.longitude);
    
    // Find closest point on route
    double minDistance = double.infinity;
    for (final point in _routePoints) {
      final distance = Geolocator.distanceBetween(
        currentLatLng.latitude,
        currentLatLng.longitude,
        point.latitude,
        point.longitude,
      );
      if (distance < minDistance) {
        minDistance = distance;
      }
    }

    // Only recalculate if driver is significantly off route (150m+ threshold for accuracy)
    if (minDistance > 150 && _lastRouteUpdate != null) {
      final timeSinceLastUpdate = DateTime.now().difference(_lastRouteUpdate!);
      if (timeSinceLastUpdate.inSeconds > 60) { // Reduce frequency to avoid constant recalculations
        print('🔄 Driver significantly off route by ${minDistance.toInt()}m, recalculating...');
        _calculateRouteFromCurrentLocation();
      }
    }
  }

  void _startRouteRecalculationTimer() {
    _routeRecalculationTimer = Timer.periodic(const Duration(minutes: 5), (timer) {
      // Reduce periodic recalculation frequency to preserve battery and performance
      if (mounted && _currentPosition != null) {
        _calculateRouteFromCurrentLocation();
      }
    });
  }

  /// Normalize bearing difference to avoid spinning more than 180 degrees
  double _normalizeBearingDifference(double diff) {
    while (diff > 180) diff -= 360;
    while (diff < -180) diff += 360;
    return diff;
  }

  void _updateDriverMarkerRotation(double bearing) {
    _driverMarkerRotation = Tween<double>(
      begin: _driverMarkerRotation.value,
      end: bearing * (math.pi / 180), // Convert to radians
    ).animate(CurvedAnimation(
      parent: _driverMarkerController,
      curve: Curves.easeInOutCubic, // Smoother animation curve
    ));
    
    _driverMarkerController.reset();
    _driverMarkerController.forward();
  }

  void _centerOnDriverLocation({bool animate = true}) {
    if (_currentPosition == null || !mounted) return;

    final targetLatLng = latlong.LatLng(_currentPosition!.latitude, _currentPosition!.longitude);
    final currentZoom = _mapController.camera.zoom;
    final targetZoom = currentZoom > 16 ? currentZoom : 18.0;
    
    try {
      // Compass mode: rotate map based on movement direction
      if (_currentBearing != null && _isFollowingDriver && _compassMode) {
        // Convert bearing to map rotation (bearing 0° = North, map rotation 0° = North up)
        final rotation = -_currentBearing!; // Negative because map rotation is counter-clockwise
        
        if (animate) {
          // Smooth animated movement with bearing rotation for compass mode
          _mapController.move(targetLatLng, targetZoom);
          _mapController.rotate(rotation);
        } else {
          // Instant movement with bearing
          _mapController.move(targetLatLng, targetZoom);
          _mapController.rotate(rotation);
        }
      } else {
        // Standard movement without rotation when not following driver or no bearing
        if (animate) {
          _mapController.move(targetLatLng, targetZoom);
        } else {
          _mapController.move(targetLatLng, targetZoom);
        }
      }
    } catch (e) {
      print('📍 Camera movement error: $e');
      // Fallback to simple move if rotation fails
      try {
        _mapController.move(targetLatLng, targetZoom);
      } catch (fallbackError) {
        print('📍 Fallback camera movement also failed: $fallbackError');
      }
    }
  }

  List<Marker> _buildMarkers() {
    final markers = <Marker>[];

    // Current position marker (driver)
    if (_currentPosition != null) {
      markers.add(
        Marker(
          point: latlong.LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
          width: 40,
          height: 40,
          child: AnimatedBuilder(
            animation: _driverMarkerRotation,
            builder: (context, child) {
              return Transform.rotate(
                angle: _driverMarkerRotation.value,
                child: Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFF007AFF),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 3),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.navigation,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
              );
            },
          ),
        ),
      );
    }

    // Destination marker
    final destination = widget.currentTrip.direction == TripDirection.outbound
        ? latlong.LatLng(widget.assignedRoute.endLocation.latitude, widget.assignedRoute.endLocation.longitude)
        : latlong.LatLng(widget.assignedRoute.startLocation.latitude, widget.assignedRoute.startLocation.longitude);

    markers.add(
      Marker(
        point: destination,
        width: 30,
        height: 30,
        child: Container(
          decoration: BoxDecoration(
            color: const Color(0xFFFF3B30),
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 2),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.25),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
        ),
      ),
    );

    return markers;
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: Colors.transparent,
        body: Center(
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 20,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF007AFF)),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Initializing Navigation...',
                  style: TextStyle(
                    color: Color(0xFF1A1A1A),
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          // Main map
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _currentPosition != null
                  ? latlong.LatLng(_currentPosition!.latitude, _currentPosition!.longitude)
                  : latlong.LatLng(widget.assignedRoute.startLocation.latitude, widget.assignedRoute.startLocation.longitude),
              initialZoom: 18.0,
              minZoom: 10.0,
              maxZoom: 20.0,
              interactionOptions: InteractionOptions(
                flags: InteractiveFlag.all, // Enable all interactions including rotation
                rotationThreshold: 20.0,
                rotationWinGestures: MultiFingerGesture.rotate,
                pinchZoomThreshold: 0.5,
                pinchMoveThreshold: 40.0,
                scrollWheelVelocity: 0.005,
              ),
              onTap: (_, __) => setState(() => _isFollowingDriver = false),
              // Disable default controls to prevent any built-in buttons
              cameraConstraint: CameraConstraint.unconstrained(),
              onMapReady: () {
                // Wait a frame for map to be fully ready
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (mounted) {
                    _centerOnDriverLocation(animate: false);
                  }
                });
              },
            ),
            children: [
              // Standard OpenStreetMap tiles
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                additionalOptions: const {
                  'attribution': '© OpenStreetMap contributors',
                },
                userAgentPackageName: 'com.campusride.campus_ride',
                tileSize: 256,
                maxZoom: 19,
              ),

              // Remaining route polyline (erases traveled sections)
              if (_routePoints.isNotEmpty)
                AnimatedBuilder(
                  animation: _routeAnimation,
                  builder: (context, child) {
                    // Show only remaining route from current position
                    final remainingPoints = _routePoints.skip(_currentRouteIndex).toList();
                    
                    return PolylineLayer(
                      polylines: [
                        // Shadow/border polyline for remaining route
                        if (remainingPoints.length > 1)
                          Polyline(
                            points: remainingPoints,
                            color: Colors.black.withOpacity(0.4),
                            strokeWidth: 8.0,
                          ),
                        // Main route polyline for remaining route only
                        if (remainingPoints.length > 1)
                          Polyline(
                            points: remainingPoints,
                            color: const Color(0xFF007AFF),
                            strokeWidth: 6.0,
                            borderColor: Colors.white,
                            borderStrokeWidth: 1.0,
                          ),
                      ],
                    );
                  },
                ),

              // Markers layer
              MarkerLayer(markers: _buildMarkers()),
            ],
          ),





          // Map control buttons (moved higher)
          Positioned(
            top: 120,
            right: 16,
            child: Column(
              children: [
                // Relocate/Follow driver button (at top)
                Container(
                  width: 48,
                  height: 48,
                  margin: const EdgeInsets.only(bottom: 8),
                  child: FloatingActionButton(
                    mini: true,
                    backgroundColor: _isFollowingDriver
                        ? const Color(0xFF007AFF)
                        : Colors.white,
                    elevation: 4,
                    onPressed: () {
                      setState(() => _isFollowingDriver = !_isFollowingDriver);
                      if (_isFollowingDriver) {
                        _centerOnDriverLocation(animate: true);
                      }
                    },
                    child: Icon(
                      Icons.my_location,
                      color: _isFollowingDriver ? Colors.white : const Color(0xFF007AFF),
                      size: 20,
                    ),
                  ),
                ),
                
                // Zoom In button
                Container(
                  width: 48,
                  height: 48,
                  margin: const EdgeInsets.only(bottom: 8),
                  child: FloatingActionButton(
                    mini: true,
                    backgroundColor: Colors.white,
                    elevation: 4,
                    onPressed: () {
                      _mapController.move(
                        _mapController.camera.center,
                        _mapController.camera.zoom + 1,
                      );
                    },
                    child: const Icon(
                      Icons.zoom_in,
                      color: Color(0xFF007AFF),
                      size: 20,
                    ),
                  ),
                ),
                
                // Zoom Out button
                Container(
                  width: 48,
                  height: 48,
                  margin: const EdgeInsets.only(bottom: 8),
                  child: FloatingActionButton(
                    mini: true,
                    backgroundColor: Colors.white,
                    elevation: 4,
                    onPressed: () {
                      _mapController.move(
                        _mapController.camera.center,
                        _mapController.camera.zoom - 1,
                      );
                    },
                    child: const Icon(
                      Icons.zoom_out,
                      color: Color(0xFF007AFF),
                      size: 20,
                    ),
                  ),
                ),
                
                // Compass widget (toggles between center and compass mode)
                Container(
                  width: 48,
                  height: 48,
                  child: FloatingActionButton(
                    mini: true,
                    backgroundColor: _compassMode ? const Color(0xFFFF3B30) : Colors.white,
                    elevation: 4,
                    onPressed: () {
                      setState(() {
                        _compassMode = !_compassMode;
                        if (_compassMode) {
                          // Enable compass mode: lock to location + rotation
                          _isFollowingDriver = true;
                          print('🧭 Compass mode enabled - map will rotate to match movement direction');
                        } else {
                          // Default mode: just center on location, reset rotation
                          _isFollowingDriver = true;
                          print('🧭 Compass mode disabled - map rotation reset to north');
                          // Reset rotation with a small delay to ensure map controller is ready
                          Future.delayed(const Duration(milliseconds: 100), () {
                            if (mounted) {
                              try {
                                _mapController.rotate(0);
                              } catch (e) {
                                print('⚠️ Could not reset map rotation: $e');
                              }
                            }
                          });
                        }
                      });
                      _centerOnDriverLocation(animate: true);
                    },
                    child: Transform.rotate(
                      angle: _compassMode ? _compassHeading * (math.pi / 180) : 0,
                      child: Icon(
                        Icons.navigation,
                        color: _compassMode ? Colors.white : const Color(0xFFFF3B30),
                        size: 20,
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

  @override
  void dispose() {
    _positionSubscription?.cancel();
    _routeRecalculationTimer?.cancel();
    _routeAnimationController.dispose();
    _driverMarkerController.dispose();
    _locationService.stopTracking();
    super.dispose();
  }
}