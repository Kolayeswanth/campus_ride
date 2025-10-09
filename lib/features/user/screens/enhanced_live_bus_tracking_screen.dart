import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' as latlong;

import '../../../core/models/bus_status.dart';
import '../../../core/services/enhanced_realtime_location_service.dart';
import '../../../core/services/enhanced_routing_service.dart';
import '../../../core/services/ola_maps_api_service.dart';

/// Enhanced Live Bus Tracking Screen with proper road routing and location updates
class EnhancedLiveBusTrackingScreen extends StatefulWidget {
  final BusStatus bus;

  const EnhancedLiveBusTrackingScreen({
    super.key,
    required this.bus,
  });

  @override
  State<EnhancedLiveBusTrackingScreen> createState() => _EnhancedLiveBusTrackingScreenState();
}

class _EnhancedLiveBusTrackingScreenState extends State<EnhancedLiveBusTrackingScreen>
    with TickerProviderStateMixin {
  final MapController _mapController = MapController();
  final EnhancedRealtimeLocationService _realtimeService = EnhancedRealtimeLocationService.instance;

  late BusStatus _currentBusStatus;
  
  // Location and routing state
  List<latlong.LatLng> _routePoints = [];
  latlong.LatLng? _driverPosition;
  StreamSubscription<BusStatus>? _busStatusSubscription;
  Timer? _refreshTimer;
  Timer? _locationUpdateTimer;
  
  // Location updates and place names
  String _currentPlaceName = 'Fetching location...';
  String _lastUpdateTime = 'Just now';
  List<LocationUpdate> _recentLocations = [];
  
  // UI state
  bool _isLoading = true;
  bool _isFollowingBus = true;
  bool _showLocationHistory = false;
  
  // Animation controllers
  late AnimationController _busMarkerController;
  late AnimationController _mapMoveController;
  late Animation<double> _busMarkerRotation;
  
  // Animation state
  double _currentBearing = 0.0;

  @override
  void initState() {
    super.initState();
    _currentBusStatus = widget.bus;
    
    if (widget.bus.bearingDegrees != null) {
      _currentBearing = widget.bus.bearingDegrees!.toDouble();
    }
    
    _setupAnimations();
    _initializeTracking();
  }

  void _setupAnimations() {
    _busMarkerController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _busMarkerRotation = Tween<double>(
      begin: 0.0,
      end: 0.0,
    ).animate(CurvedAnimation(
      parent: _busMarkerController,
      curve: Curves.easeInOut,
    ));
    
    _mapMoveController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
  }

  Future<void> _initializeTracking() async {
    try {
      setState(() => _isLoading = true);
      print('🎯 Starting enhanced real-time tracking for bus: ${widget.bus.id}');
      
      // Start real-time location tracking
      final success = await _realtimeService.startTrackingBus(widget.bus.id, widget.bus);
      
      if (!success) {
        throw Exception('Bus is not currently active or available for tracking');
      }
      
      // Listen to real-time bus location updates
      _busStatusSubscription = _realtimeService.busLocationStream.listen(_handleBusUpdate);
      
      // Initial route calculation
      await _calculateRoadRoute();
      
      // Start location update timer for place names and timestamps
      _startLocationUpdateTimer();
      
      setState(() => _isLoading = false);
      
      // Center map on bus location
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _centerMapOnBus();
      });
      
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        _showErrorSnackBar('Failed to start tracking: $e');
      }
    }
  }

  void _handleBusUpdate(BusStatus busStatus) {
    if (mounted && busStatus.hasLiveLocation) {
      final newPosition = latlong.LatLng(
        busStatus.currentLatitude!,
        busStatus.currentLongitude!,
      );

      print('🚌 Enhanced bus location update: ${busStatus.currentLatitude}, ${busStatus.currentLongitude}');

      // Update position
      _animateBusPosition(newPosition);
      
      // Update bearing if available
      if (busStatus.bearingDegrees != null && 
          busStatus.bearingDegrees != _currentBusStatus.bearingDegrees) {
        _animateBusRotation(busStatus.bearingDegrees!.toDouble());
      }
      
      // Follow bus on map
      if (_isFollowingBus) {
        _animateMapToPosition(newPosition);
      }

      // Update bus status
      setState(() {
        _currentBusStatus = busStatus;
      });
      
      // Recalculate route with new position
      _calculateRoadRoute();
      
      // Update place name
      _updateCurrentPlaceName(newPosition);
      
      // Add to location history
      _addLocationUpdate(newPosition, busStatus.currentSpeedKmh ?? 0.0);
    }
  }

  Future<void> _calculateRoadRoute() async {
    try {
      if (!_currentBusStatus.hasLiveLocation) return;
      
      final startPoint = latlong.LatLng(
        _currentBusStatus.currentLatitude!,
        _currentBusStatus.currentLongitude!,
      );
      final endPoint = latlong.LatLng(
        _currentBusStatus.route.endLocation.latitude,
        _currentBusStatus.route.endLocation.longitude,
      );

      print('🛣️ Calculating road route using OpenRouteService');
      
      // Use EnhancedRoutingService for proper road routing
      final directions = await EnhancedRoutingService.getEnhancedRoute([
        startPoint,
        endPoint,
      ]);
      
      if (directions['route_points'] != null) {
        final routePoints = directions['route_points'] as List<latlong.LatLng>;
        
        setState(() {
          _routePoints = routePoints;
          _driverPosition = startPoint;
        });
        
        print('✅ Road route calculated: ${routePoints.length} points, ${directions['distance_km']?.toStringAsFixed(1)}km');
      }
    } catch (e) {
      print('❌ Road routing failed: $e, using straight line');
      // Fallback to straight line
      final startPoint = latlong.LatLng(
        _currentBusStatus.currentLatitude!,
        _currentBusStatus.currentLongitude!,
      );
      final endPoint = latlong.LatLng(
        _currentBusStatus.route.endLocation.latitude,
        _currentBusStatus.route.endLocation.longitude,
      );
      
      setState(() {
        _routePoints = [startPoint, endPoint];
        _driverPosition = startPoint;
      });
    }
  }

  Future<void> _updateCurrentPlaceName(latlong.LatLng position) async {
    try {
      // Use Ola Maps reverse geocoding to get place name
      final results = await OlaMapsApiService.reverseGeocode(
        location: '${position.latitude},${position.longitude}',
      );
      
      if (results.isNotEmpty) {
        final place = results.first;
        String placeName = 'Unknown location';
        
        // Try to get a readable place name
        if (place['name'] != null) {
          placeName = place['name'];
        } else if (place['display_name'] != null) {
          placeName = place['display_name'];
        } else if (place['road'] != null) {
          placeName = place['road'];
          if (place['suburb'] != null) {
            placeName += ', ${place['suburb']}';
          }
        }
        
        setState(() {
          _currentPlaceName = placeName;
          _lastUpdateTime = _formatUpdateTime(DateTime.now());
        });
      }
    } catch (e) {
      print('❌ Failed to get place name: $e');
      setState(() {
        _currentPlaceName = 'Location update';
        _lastUpdateTime = _formatUpdateTime(DateTime.now());
      });
    }
  }

  void _addLocationUpdate(latlong.LatLng position, double speed) {
    final update = LocationUpdate(
      position: position,
      timestamp: DateTime.now(),
      speed: speed,
      placeName: _currentPlaceName,
    );
    
    setState(() {
      _recentLocations.insert(0, update);
      // Keep only last 10 updates
      if (_recentLocations.length > 10) {
        _recentLocations = _recentLocations.take(10).toList();
      }
    });
  }

  String _formatUpdateTime(DateTime time) {
    final now = DateTime.now();
    final diff = now.difference(time).inMinutes;
    
    if (diff == 0) {
      return 'Just now';
    } else if (diff == 1) {
      return '1 minute ago';
    } else {
      return '$diff minutes ago';
    }
  }

  void _startLocationUpdateTimer() {
    _locationUpdateTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      if (mounted) {
        setState(() {
          _lastUpdateTime = _formatUpdateTime(_recentLocations.isNotEmpty 
              ? _recentLocations.first.timestamp 
              : DateTime.now());
        });
      }
    });
  }

  void _animateBusPosition(latlong.LatLng newPosition) {
    if (_driverPosition != null) {
      setState(() {
        _driverPosition = newPosition;
      });
    } else {
      setState(() {
        _driverPosition = newPosition;
      });
    }
  }

  void _animateBusRotation(double newBearing) {
    final currentBearing = _currentBearing;
    final bearingDiff = _normalizeAngleDifference(newBearing - currentBearing);
    
    _busMarkerRotation = Tween<double>(
      begin: currentBearing * (math.pi / 180),
      end: (currentBearing + bearingDiff) * (math.pi / 180),
    ).animate(CurvedAnimation(
      parent: _busMarkerController,
      curve: Curves.easeInOut,
    ));
    
    _busMarkerController.reset();
    _busMarkerController.forward().then((_) {
      _currentBearing = newBearing;
    });
  }

  void _animateMapToPosition(latlong.LatLng newPosition) {
    try {
      Future.delayed(const Duration(milliseconds: 200), () {
        if (mounted && _isFollowingBus) {
          _mapController.move(
            newPosition,
            _mapController.camera.zoom,
          );
        }
      });
    } catch (e) {
      print('Map animation error: $e');
    }
  }

  double _normalizeAngleDifference(double diff) {
    while (diff > 180) diff -= 360;
    while (diff < -180) diff += 360;
    return diff;
  }

  void _centerMapOnBus() {
    if (_currentBusStatus.hasLiveLocation) {
      try {
        Future.delayed(const Duration(milliseconds: 100), () {
          if (mounted) {
            _mapController.move(
              latlong.LatLng(
                _currentBusStatus.currentLatitude!,
                _currentBusStatus.currentLongitude!,
              ),
              17.0,
            );
          }
        });
      } catch (e) {
        print('Map controller error: $e');
      }
    }
  }

  void _showErrorSnackBar(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 4),
        ),
      );
    }
  }

  Widget _buildLocationUpdateCard() {
    return Container(
      margin: const EdgeInsets.all(16),
      child: Card(
        elevation: 8,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.blue.shade50,
                Colors.white,
              ],
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade100,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.location_on,
                        color: Colors.blue.shade700,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Current Location',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Colors.grey.shade700,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _currentPlaceName,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: Colors.black87,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    TextButton(
                      onPressed: () {
                        setState(() {
                          _showLocationHistory = !_showLocationHistory;
                        });
                      },
                      child: Text(
                        _showLocationHistory ? 'Hide' : 'History',
                        style: TextStyle(
                          color: Colors.blue.shade600,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(
                      Icons.schedule,
                      size: 16,
                      color: Colors.grey.shade600,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Updated $_lastUpdateTime',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                    const Spacer(),
                    if (_currentBusStatus.currentSpeedKmh != null)
                      Row(
                        children: [
                          Icon(
                            Icons.speed,
                            size: 16,
                            color: Colors.grey.shade600,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${_currentBusStatus.currentSpeedKmh!.toStringAsFixed(0)} km/h',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
                if (_showLocationHistory && _recentLocations.isNotEmpty) ...[
                  const Divider(height: 24),
                  Text(
                    'Recent Locations',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey.shade700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  ...(_recentLocations.take(5).map((update) => _buildLocationHistoryItem(update))),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLocationHistoryItem(LocationUpdate update) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(
            Icons.circle,
            size: 8,
            color: Colors.blue.shade300,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              update.placeName.isNotEmpty ? update.placeName : 'Location update',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade700,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Text(
            _formatUpdateTime(update.timestamp),
            style: TextStyle(
              fontSize: 10,
              color: Colors.grey.shade500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBusMarker() {
    return AnimatedBuilder(
      animation: _busMarkerRotation,
      builder: (context, child) {
        return Transform.rotate(
          angle: _busMarkerRotation.value,
          child: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Colors.blue.shade600,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 3),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.3),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: const Icon(
              Icons.directions_bus,
              color: Colors.white,
              size: 20,
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: Text(
          '${_currentBusStatus.route.routeName} - Live Tracking',
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 18,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: Colors.black87,
        systemOverlayStyle: const SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.dark,
        ),
        actions: [
          IconButton(
            icon: Icon(
              _isFollowingBus ? Icons.my_location : Icons.location_searching,
              color: _isFollowingBus ? Colors.blue.shade600 : Colors.grey,
            ),
            onPressed: () {
              setState(() {
                _isFollowingBus = !_isFollowingBus;
              });
              if (_isFollowingBus) {
                _centerMapOnBus();
              }
            },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Starting live tracking...'),
                ],
              ),
            )
          : Stack(
              children: [
                FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(
                    initialCenter: _currentBusStatus.hasLiveLocation
                        ? latlong.LatLng(
                            _currentBusStatus.currentLatitude!,
                            _currentBusStatus.currentLongitude!,
                          )
                        : latlong.LatLng(
                            _currentBusStatus.route.startLocation.latitude,
                            _currentBusStatus.route.startLocation.longitude,
                          ),
                    initialZoom: 17.0,
                    minZoom: 3.0,
                    maxZoom: 20.0,
                  ),
                  children: [
                    TileLayer(
                      urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'com.campusride.campus_ride',
                    ),
                    // Route polyline
                    if (_routePoints.isNotEmpty)
                      PolylineLayer(
                        polylines: [
                          Polyline(
                            points: _routePoints,
                            strokeWidth: 5,
                            color: Colors.blue.shade600,
                          ),
                        ],
                      ),
                    // Bus marker
                    if (_driverPosition != null)
                      MarkerLayer(
                        markers: [
                          Marker(
                            point: _driverPosition!,
                            width: 40,
                            height: 40,
                            alignment: Alignment.center,
                            child: _buildBusMarker(),
                          ),
                        ],
                      ),
                    // Destination marker
                    MarkerLayer(
                      markers: [
                        Marker(
                          point: latlong.LatLng(
                            _currentBusStatus.route.endLocation.latitude,
                            _currentBusStatus.route.endLocation.longitude,
                          ),
                          width: 40,
                          height: 40,
                          alignment: Alignment.center,
                          child: Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: Colors.red.shade600,
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 3),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.3),
                                  blurRadius: 6,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: const Icon(
                              Icons.flag,
                              color: Colors.white,
                              size: 20,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                // Location update card
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: _buildLocationUpdateCard(),
                ),
              ],
            ),
    );
  }

  @override
  void dispose() {
    _busStatusSubscription?.cancel();
    _refreshTimer?.cancel();
    _locationUpdateTimer?.cancel();
    _busMarkerController.dispose();
    _mapMoveController.dispose();
    _realtimeService.stopTracking();
    super.dispose();
  }
}

/// Model for location updates with timestamp and place information
class LocationUpdate {
  final latlong.LatLng position;
  final DateTime timestamp;
  final double speed;
  final String placeName;

  LocationUpdate({
    required this.position,
    required this.timestamp,
    required this.speed,
    required this.placeName,
  });
}