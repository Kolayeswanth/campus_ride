import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' as latlong;

import '../../../core/models/bus_status.dart';
import '../../../core/services/realtime_location_service.dart';

/// Custom Tween for smooth LatLng interpolation
class LatLngTween extends Tween<latlong.LatLng> {
  LatLngTween({required latlong.LatLng begin, required latlong.LatLng end})
      : super(begin: begin, end: end);

  @override
  latlong.LatLng lerp(double t) {
    final lat = begin!.latitude + (end!.latitude - begin!.latitude) * t;
    final lng = begin!.longitude + (end!.longitude - begin!.longitude) * t;
    return latlong.LatLng(lat, lng);
  }
}

class LiveBusTrackingScreen extends StatefulWidget {
  final BusStatus bus;

  const LiveBusTrackingScreen({
    super.key,
    required this.bus,
  });

  @override
  State<LiveBusTrackingScreen> createState() => _LiveBusTrackingScreenState();
}

class _LiveBusTrackingScreenState extends State<LiveBusTrackingScreen>
    with TickerProviderStateMixin {
  final MapController _mapController = MapController();
  final RealtimeLocationService _realtimeService = RealtimeLocationService.instance;

  late BusStatus _currentBusStatus;
  
  // Location and routing state
  List<latlong.LatLng> _routePoints = [];
  StreamSubscription<BusStatus>? _busStatusSubscription;
  StreamSubscription<List<Map<String, double>>>? _routeSubscription;
  Timer? _refreshTimer;
  
  // UI state
  bool _isLoading = true;
  bool _isFollowingBus = true;
  
  // Animation controllers
  late AnimationController _busMarkerController;
  late AnimationController _mapMoveController;
  late AnimationController _compassController;
  late Animation<double> _busMarkerRotation;
  late Animation<latlong.LatLng> _busPositionAnimation;
  late Animation<double> _compassRotation;
  
  // Animation state
  latlong.LatLng? _animatedPosition;
  double _currentBearing = 0.0;

  @override
  void initState() {
    super.initState();
    _currentBusStatus = widget.bus;
    
    // Initialize bearing if available
    if (widget.bus.bearingDegrees != null) {
      _currentBearing = widget.bus.bearingDegrees!.toDouble();
    }
    
    _setupAnimations();
    _initializeTracking();
  }

  void _setupAnimations() {
    // Bus marker rotation animation (smooth bearing changes)
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
    
    // Map movement animation (smooth position transitions)
    _mapMoveController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
    
    // Compass rotation animation (smooth compass movements)
    _compassController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _compassRotation = Tween<double>(
      begin: 0.0,
      end: 0.0,
    ).animate(CurvedAnimation(
      parent: _compassController,
      curve: Curves.easeInOut,
    ));
  }

  Future<void> _initializeTracking() async {
    try {
      setState(() => _isLoading = true);
      print('🎯 Starting real-time tracking for bus: ${widget.bus.id}');
      
      // Start real-time location tracking
      final success = await _realtimeService.startTrackingBus(widget.bus.id, widget.bus);
      
      if (!success) {
        throw Exception('Bus is not currently active or available for tracking');
      }
      
      // Listen to real-time bus location updates
      _busStatusSubscription = _realtimeService.busLocationStream.listen(_handleBusUpdate);
      
      // Listen to real-time route polyline updates
      _routeSubscription = _realtimeService.routePolylineStream.listen(_handleRouteUpdate);
      
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
      
      print('🚌 Bus location update: ${busStatus.currentLatitude}, ${busStatus.currentLongitude}');

      // Smooth position animation
      _animateBusPosition(newPosition);
      
      // Smooth bearing animation
      if (busStatus.bearingDegrees != null && 
          busStatus.bearingDegrees != _currentBusStatus.bearingDegrees) {
        _animateBusRotation(busStatus.bearingDegrees!.toDouble());
      }
      
      // Update compass bearing smoothly
      if (busStatus.bearingDegrees != null) {
        _animateCompass(busStatus.bearingDegrees!.toDouble());
      }
      
      // Smooth map following animation
      if (_isFollowingBus) {
        _animateMapToPosition(newPosition);
      }

      // Update bus status after animations start
      setState(() {
        _currentBusStatus = busStatus;
      });
    }
  }

  void _handleRouteUpdate(List<Map<String, double>> routePoints) {
    if (mounted) {
      final newRoutePoints = routePoints.map((point) => 
        latlong.LatLng(point['latitude']!, point['longitude']!)
      ).toList();
      
      // Animate route update smoothly
      _animateRouteUpdate(newRoutePoints);
      
      print('🛣️ Route polyline updated with ${routePoints.length} points');
    }
  }

  /// Smooth animation for route polyline updates
  void _animateRouteUpdate(List<latlong.LatLng> newRoutePoints) {
    // Simple fade transition for route updates
    setState(() {
      _routePoints = newRoutePoints;
    });
  }

  void _updateBusMarkerRotation(double bearing) {
    _busMarkerRotation = Tween<double>(
      begin: _busMarkerRotation.value,
      end: bearing * (math.pi / 180), // Convert degrees to radians
    ).animate(CurvedAnimation(
      parent: _busMarkerController,
      curve: Curves.easeInOut,
    ));
    _busMarkerController.reset();
    _busMarkerController.forward();
  }

  /// Smooth animation for bus position updates
  void _animateBusPosition(latlong.LatLng newPosition) {
    if (_driverPosition != null) {
      // Create smooth position animation
      _busPositionAnimation = LatLngTween(
        begin: _driverPosition!,
        end: newPosition,
      ).animate(CurvedAnimation(
        parent: _mapMoveController,
        curve: Curves.easeInOut,
      ));
      
      // Listen to animation updates
      _mapMoveController.addListener(() {
        if (mounted) {
          setState(() {
            _animatedPosition = _busPositionAnimation.value;
            _driverPosition = _animatedPosition;
          });
        }
      });
      
      _mapMoveController.reset();
      _mapMoveController.forward();
    } else {
      // First position update - no animation needed
      setState(() {
        _driverPosition = newPosition;
        _animatedPosition = newPosition;
      });
    }
  }

  /// Smooth animation for bus rotation/bearing changes
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

  /// Smooth animation for compass rotation
  void _animateCompass(double newBearing) {
    final currentCompassBearing = _compassRotation.value * (180 / math.pi);
    final bearingDiff = _normalizeAngleDifference(newBearing - currentCompassBearing);
    
    _compassRotation = Tween<double>(
      begin: currentCompassBearing * (math.pi / 180),
      end: (currentCompassBearing + bearingDiff) * (math.pi / 180),
    ).animate(CurvedAnimation(
      parent: _compassController,
      curve: Curves.easeInOut,
    ));
    
    _compassController.reset();
    _compassController.forward();
  }

  /// Smooth animation for map movement when following bus
  void _animateMapToPosition(latlong.LatLng newPosition) {
    try {
      // Use a delayed smooth transition for map movement
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

  /// Normalize angle difference to avoid spinning more than 180 degrees
  double _normalizeAngleDifference(double diff) {
    while (diff > 180) diff -= 360;
    while (diff < -180) diff += 360;
    return diff;
  }

  Future<void> _loadRoutePolyline() async {
    try {
      // Create route from current bus location to destination
      if (_currentBusStatus.hasLiveLocation) {
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
    } catch (e) {
      print('Error loading route polyline: $e');
    }
  }

  // Real-time updates have replaced the periodic refresh
  // The RealtimeLocationService now handles all location updates automatically

  void _centerMapOnBus() {
    if (_currentBusStatus.hasLiveLocation) {
      try {
        // Add a small delay to ensure map is rendered
        Future.delayed(const Duration(milliseconds: 100), () {
          if (mounted) {
            _mapController.move(
              latlong.LatLng(
                _currentBusStatus.currentLatitude!,
                _currentBusStatus.currentLongitude!,
              ),
              17.0, // Zoom level similar to Apple Maps navigation
            );
          }
        });
      } catch (e) {
        print('Map controller error: $e');
      }
    }
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  /// Build animated compass widget showing bus direction
  Widget _buildCompassWidget() {
    return AnimatedBuilder(
      animation: _compassRotation,
      builder: (context, child) {
        return Container(
          width: 60,
          height: 60,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.9),
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Compass background
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: const Color(0xFF007AFF).withOpacity(0.3),
                    width: 2,
                  ),
                ),
              ),
              // North indicator (fixed)
              Positioned(
                top: 8,
                child: Container(
                  width: 2,
                  height: 8,
                  color: Colors.red,
                ),
              ),
              // Compass needle (animated)
              Transform.rotate(
                angle: _compassRotation.value,
                child: Icon(
                  Icons.navigation,
                  color: const Color(0xFF007AFF),
                  size: 24,
                ),
              ),
              // Direction text
              Positioned(
                bottom: 4,
                child: Text(
                  '${(_currentBearing).round()}°',
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1A1A1A),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  /// Build speed widget showing current bus speed
  Widget _buildSpeedWidget() {
    final speed = _currentBusStatus.currentSpeedKmh ?? 0.0;
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.9),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.speed,
            color: speed > 0 ? const Color(0xFF007AFF) : Colors.grey,
            size: 16,
          ),
          const SizedBox(width: 4),
          AnimatedDefaultTextStyle(
            duration: const Duration(milliseconds: 300),
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: speed > 0 ? const Color(0xFF007AFF) : Colors.grey,
            ),
            child: Text('${speed.round()} km/h'),
          ),
        ],
      ),
    );
  }

  latlong.LatLng? _driverPosition;

  List<Marker> _buildMarkers() {
    final markers = <Marker>[];

    // Use animated position for smooth movement
    final markerPosition = _animatedPosition ?? _driverPosition;
    
    if (markerPosition != null) {
      markers.add(
        Marker(
          point: markerPosition,
          width: 50,
          height: 50,
          child: AnimatedBuilder(
            animation: Listenable.merge([_busMarkerRotation, _mapMoveController]),
            builder: (context, child) {
              return AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOut,
                child: Transform.rotate(
                  angle: _busMarkerRotation.value,
                  child: Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFF007AFF),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 3),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.3),
                          blurRadius: 12,
                          offset: const Offset(0, 3),
                        ),
                        BoxShadow(
                          color: const Color(0xFF007AFF).withOpacity(0.5),
                          blurRadius: 20,
                          offset: const Offset(0, 0),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.directions_bus_rounded,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      );
      
      // Add a subtle pulsing effect around the bus marker
      markers.add(
        Marker(
          point: markerPosition,
          width: 80,
          height: 80,
          child: AnimatedBuilder(
            animation: _mapMoveController,
            builder: (context, child) {
              return Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: const Color(0xFF007AFF).withOpacity(0.3),
                    width: 2,
                  ),
                ),
              );
            },
          ),
        ),
      );
    }

    return markers;
  }

  List<Polyline> _buildPolylines() {
    if (_routePoints.isEmpty) return [];

    return [
      // Background polyline (wider, lighter)
      Polyline(
        points: _routePoints,
        color: const Color(0xFF007AFF).withOpacity(0.3),
        strokeWidth: 8.0,
        borderStrokeWidth: 2.0,
        borderColor: Colors.white.withOpacity(0.8),
      ),
      // Main polyline (animated)
      Polyline(
        points: _routePoints,
        color: const Color(0xFF007AFF),
        strokeWidth: 4.0,
        pattern: const StrokePattern.solid(),
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.arrow_back, color: Color(0xFF1A1A1A)),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _currentBusStatus.route.routeName,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1A1A1A),
              ),
            ),
            if (_currentBusStatus.busNumber != null)
              Text(
                _currentBusStatus.busNumber!,
                style: const TextStyle(
                  fontSize: 14,
                  color: Color(0xFF6B7280),
                ),
              ),
          ],
        ),
        actions: [
          IconButton(
            onPressed: () {
              setState(() {
                _isFollowingBus = !_isFollowingBus;
              });
              if (_isFollowingBus) {
                _centerMapOnBus();
              }
            },
            icon: Icon(
              _isFollowingBus ? Icons.gps_fixed : Icons.gps_not_fixed,
              color: _isFollowingBus ? const Color(0xFF007AFF) : const Color(0xFF6B7280),
            ),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Stack(
              children: [
                // Main map
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
                    minZoom: 10.0,
                    maxZoom: 18.0,
                    interactionOptions: const InteractionOptions(
                      flags: InteractiveFlag.all,
                    ),
                    onTap: (_, __) {
                      // Disable following when user interacts with map
                      setState(() {
                        _isFollowingBus = false;
                      });
                    },
                  ),
                  children: [
                    TileLayer(
                      urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'com.campusride.app',
                      maxNativeZoom: 19,
                      maxZoom: 22,
                    ),
                    PolylineLayer(polylines: _buildPolylines()),
                    MarkerLayer(markers: _buildMarkers()),
                  ],
                ),
                // Compass widget
                Positioned(
                  top: 20,
                  right: 20,
                  child: _buildCompassWidget(),
                ),
                // Speed and bearing info
                if (_currentBusStatus.currentSpeedKmh != null)
                  Positioned(
                    top: 20,
                    left: 20,
                    child: _buildSpeedWidget(),
                  ),
              ],
            ),
      bottomSheet: Container(
        padding: const EdgeInsets.all(16),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          boxShadow: [
            BoxShadow(
              color: Colors.black12,
              blurRadius: 10,
              offset: Offset(0, -5),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: _getBusStatusColor().withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    _getBusStatusIcon(),
                    color: _getBusStatusColor(),
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _currentBusStatus.statusText,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1A1A1A),
                        ),
                      ),
                      Text(
                        'Last updated: ${_formatLastUpdate()}',
                        style: const TextStyle(
                          fontSize: 14,
                          color: Color(0xFF6B7280),
                        ),
                      ),
                    ],
                  ),
                ),
                if (_currentBusStatus.currentSpeedKmh != null) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF007AFF).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${_currentBusStatus.currentSpeedKmh!.round()} km/h',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF007AFF),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Color _getBusStatusColor() {
    switch (_currentBusStatus.status) {
      case BusCurrentStatus.active:
        return _currentBusStatus.isOnline ? Colors.green : Colors.orange;
      case BusCurrentStatus.inactive:
      case BusCurrentStatus.offline:
        return Colors.grey;
      case BusCurrentStatus.maintenance:
        return Colors.red;
    }
  }

  IconData _getBusStatusIcon() {
    switch (_currentBusStatus.status) {
      case BusCurrentStatus.active:
        return _currentBusStatus.isOnline ? Icons.radio_button_checked : Icons.schedule;
      case BusCurrentStatus.inactive:
      case BusCurrentStatus.offline:
        return Icons.radio_button_unchecked;
      case BusCurrentStatus.maintenance:
        return Icons.build;
    }
  }

  String _formatLastUpdate() {
    if (_currentBusStatus.lastUpdateTime == null) return 'Unknown';
    
    final now = DateTime.now();
    final difference = now.difference(_currentBusStatus.lastUpdateTime!);
    
    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else {
      return '${difference.inHours}h ago';
    }
  }

  @override
  void dispose() {
    // Dispose all animation controllers
    _busMarkerController.dispose();
    _mapMoveController.dispose();
    _compassController.dispose();
    
    // Cancel subscriptions
    _busStatusSubscription?.cancel();
    _routeSubscription?.cancel();
    _refreshTimer?.cancel();
    
    // Stop realtime tracking
    _realtimeService.stopTracking();
    
    super.dispose();
  }
}