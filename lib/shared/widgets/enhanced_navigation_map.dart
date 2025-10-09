import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

/// Enhanced FlutterMap widget with road-snapped routes and turn-by-turn navigation
class EnhancedNavigationMap extends StatefulWidget {
  final List<LatLng> routePoints;
  final List<Map<String, dynamic>> turnByTurnInstructions;
  final LatLng? startLocation;
  final LatLng? endLocation;
  final List<LatLng> waypoints;
  final double? distance;
  final double? duration;
  final String? routeSource;
  final VoidCallback? onRouteInfoTap;
  final bool showInstructions;
  final bool showRouteInfo;
  final double initialZoom;
  final EdgeInsets padding;
  final bool enableInteraction;

  const EnhancedNavigationMap({
    super.key,
    required this.routePoints,
    this.turnByTurnInstructions = const [],
    this.startLocation,
    this.endLocation,
    this.waypoints = const [],
    this.distance,
    this.duration,
    this.routeSource,
    this.onRouteInfoTap,
    this.showInstructions = true,
    this.showRouteInfo = true,
    this.initialZoom = 14.0,
    this.padding = EdgeInsets.zero,
    this.enableInteraction = true,
  });

  @override
  State<EnhancedNavigationMap> createState() => _EnhancedNavigationMapState();
}

class _EnhancedNavigationMapState extends State<EnhancedNavigationMap>
    with TickerProviderStateMixin {
  final MapController _mapController = MapController();
  late AnimationController _routeAnimationController;
  late Animation<double> _routeAnimation;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _setupAnimations();
    
    // Debug: Basic route info
    if (kDebugMode && widget.routePoints.isNotEmpty) {
      print('🗺️ Map initialized with ${widget.routePoints.length} route points');
    }
    
    // Trigger route animation and map fitting after the first frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _fitMapToRoute();
      _animateRoute();
    });
  }

  void _setupAnimations() {
    _routeAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    );
    
    _routeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _routeAnimationController,
      curve: Curves.easeInOut,
    ));
  }

  @override
  void didUpdateWidget(EnhancedNavigationMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.routePoints != oldWidget.routePoints) {
      _fitMapToRoute();
      _animateRoute();
    }
  }

  void _fitMapToRoute() {
    if (widget.routePoints.isEmpty) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      try {
        final bounds = _calculateBounds(widget.routePoints);
        if (bounds != null) {
          _mapController.fitCamera(
            CameraFit.bounds(
              bounds: bounds,
              padding: widget.padding.copyWith(
                top: widget.padding.top + 50,
                bottom: widget.padding.bottom + 50,
                left: widget.padding.left + 50,
                right: widget.padding.right + 50,
              ),
            ),
          );
        }
      } catch (e) {
        if (kDebugMode) {
          print('🗺️ Error fitting map to route: $e');
        }
      }
    });
  }

  void _animateRoute() {
    if (widget.routePoints.isNotEmpty) {
      _routeAnimationController.reset();
      _routeAnimationController.forward();
    }
  }

  LatLngBounds? _calculateBounds(List<LatLng> points) {
    if (points.isEmpty) return null;

    double minLat = points.first.latitude;
    double maxLat = points.first.latitude;
    double minLng = points.first.longitude;
    double maxLng = points.first.longitude;

    for (final point in points) {
      minLat = math.min(minLat, point.latitude);
      maxLat = math.max(maxLat, point.latitude);
      minLng = math.min(minLng, point.longitude);
      maxLng = math.max(maxLng, point.longitude);
    }

    // Add padding
    const padding = 0.001;
    return LatLngBounds(
      LatLng(minLat - padding, minLng - padding),
      LatLng(maxLat + padding, maxLng + padding),
    );
  }

  List<Marker> _buildMarkers() {
    final List<Marker> markers = [];

    // Start marker - Apple Maps style
    if (widget.startLocation != null) {
      markers.add(
        Marker(
          point: widget.startLocation!,
          width: 24,
          height: 24,
          child: Container(
            decoration: BoxDecoration(
              color: const Color(0xFF34C759), // Apple Maps green
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
    }

    // End marker - Apple Maps style
    if (widget.endLocation != null) {
      markers.add(
        Marker(
          point: widget.endLocation!,
          width: 24,
          height: 24,
          child: Container(
            decoration: BoxDecoration(
              color: const Color(0xFFFF3B30), // Apple Maps red
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
    }

    // Waypoint markers
    for (int i = 0; i < widget.waypoints.length; i++) {
      markers.add(
        Marker(
          point: widget.waypoints[i],
          width: 32,
          height: 32,
          child: Container(
            decoration: BoxDecoration(
              color: Colors.orange,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.3),
                  blurRadius: 3,
                  offset: const Offset(0, 1),
                ),
              ],
            ),
            child: Center(
              child: Text(
                '${i + 1}',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ),
          ),
        ),
      );
    }

    // Turn-by-turn instruction markers (only show major turns)
    if (widget.showInstructions && widget.turnByTurnInstructions.isNotEmpty) {
      for (int i = 0; i < widget.turnByTurnInstructions.length; i++) {
        final instruction = widget.turnByTurnInstructions[i];
        final wayPoints = instruction['way_points'] as List?;
        
        // Only show markers for significant turns
        final type = instruction['type']?.toString() ?? '';
        if (!_isMajorTurn(type)) continue;
        
        // Try to get coordinates from way_points or estimate position
        LatLng? instructionPoint;
        if (wayPoints != null && wayPoints.length >= 2 && 
            wayPoints[0] < widget.routePoints.length) {
          instructionPoint = widget.routePoints[wayPoints[0] as int];
        } else if (i < widget.routePoints.length ~/ widget.turnByTurnInstructions.length) {
          // Estimate position based on instruction index
          final index = (i / widget.turnByTurnInstructions.length * widget.routePoints.length).round();
          if (index < widget.routePoints.length) {
            instructionPoint = widget.routePoints[index];
          }
        }
        
        if (instructionPoint != null) {
          markers.add(
            Marker(
              point: instructionPoint,
              width: 24,
              height: 24,
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.blue,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 1),
                ),
                child: Icon(
                  _getInstructionIcon(type),
                  color: Colors.white,
                  size: 12,
                ),
              ),
            ),
          );
        }
      }
    }

    return markers;
  }

  bool _isMajorTurn(String type) {
    const majorTurns = {
      'turn-left',
      'turn-right', 
      'turn-sharp-left',
      'turn-sharp-right',
      'roundabout-enter',
      'roundabout-exit',
      'fork',
      'merge',
    };
    return majorTurns.contains(type);
  }

  IconData _getInstructionIcon(String type) {
    switch (type) {
      case 'turn-left':
        return Icons.turn_left;
      case 'turn-right':
        return Icons.turn_right;
      case 'turn-slight-left':
        return Icons.turn_slight_left;
      case 'turn-slight-right':
        return Icons.turn_slight_right;
      case 'turn-sharp-left':
        return Icons.turn_sharp_left;
      case 'turn-sharp-right':
        return Icons.turn_sharp_right;
      case 'roundabout-enter':
      case 'roundabout-exit':
        return Icons.roundabout_left;
      case 'fork':
        return Icons.call_split;
      case 'merge':
        return Icons.merge;
      case 'uturn':
        return Icons.u_turn_left;
      default:
        return Icons.straight;
    }
  }

  Widget _buildRouteInfoOverlay() {
    if (!widget.showRouteInfo || 
        (widget.distance == null && widget.duration == null)) {
      return const SizedBox.shrink();
    }

    return Positioned(
      top: 16,
      left: 16,
      right: 16,
      child: GestureDetector(
        onTap: widget.onRouteInfoTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.blue.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.route,
                  color: Colors.blue.shade700,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        if (widget.distance != null) ...[
                          Icon(Icons.straighten, size: 16, color: Colors.grey.shade600),
                          const SizedBox(width: 4),
                          Text(
                            '${widget.distance!.toStringAsFixed(1)} km',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: Colors.grey.shade800,
                            ),
                          ),
                        ],
                        if (widget.distance != null && widget.duration != null)
                          Text(' • ', style: TextStyle(color: Colors.grey.shade500)),
                        if (widget.duration != null) ...[
                          Icon(Icons.schedule, size: 16, color: Colors.grey.shade600),
                          const SizedBox(width: 4),
                          Text(
                            '${widget.duration!.toStringAsFixed(0)} min',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: Colors.grey.shade800,
                            ),
                          ),
                        ],
                      ],
                    ),
                    if (widget.routeSource != null) ...[
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: _getSourceColor(widget.routeSource!),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              _getSourceDisplayName(widget.routeSource!),
                              style: const TextStyle(
                                fontSize: 10,
                                color: Colors.white,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '${widget.routePoints.length} points',
                            style: TextStyle(
                              fontSize: 10,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              if (widget.onRouteInfoTap != null)
                Icon(Icons.info_outline, color: Colors.grey.shade600, size: 20),
            ],
          ),
        ),
      ),
    );
  }

  Color _getSourceColor(String source) {
    switch (source.toLowerCase()) {
      case 'openrouteservice':
        return Colors.green;
      case 'locationiq':
        return Colors.orange;
      case 'osrm':
        return Colors.blue;
      case 'mapbox':
        return Colors.purple;
      default:
        return Colors.grey;
    }
  }

  String _getSourceDisplayName(String source) {
    switch (source.toLowerCase()) {
      case 'openrouteservice':
        return 'OpenRoute';
      case 'locationiq':
        return 'LocationIQ';
      case 'osrm':
        return 'OSRM';
      case 'mapbox':
        return 'MapBox';
      default:
        return source.toUpperCase();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        FlutterMap(
          mapController: _mapController,
          options: MapOptions(
            initialZoom: widget.initialZoom,
            minZoom: 3.0,
            maxZoom: 20.0,
            interactionOptions: InteractionOptions(
              flags: widget.enableInteraction 
                  ? InteractiveFlag.all 
                  : InteractiveFlag.none,
            ),
          ),
          children: [
            // Base tile layer
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'com.campusride.app',
              maxZoom: 20,
              additionalOptions: const {
                'attribution': '© OpenStreetMap contributors',
              },
              errorTileCallback: (tile, error, stackTrace) {
                if (kDebugMode) {
                  print('🗺️ Tile loading error: $error');
                }
              },
            ),
            
            // Route polyline (with fallback for animation issues)
            if (widget.routePoints.isNotEmpty)
              AnimatedBuilder(
                animation: _routeAnimation,
                builder: (context, child) {
                  final animatedLength = (_routeAnimation.value * widget.routePoints.length).round();
                  final animatedPoints = widget.routePoints.take(animatedLength).toList();
                  
                  // Fallback: If animation hasn't started or is broken, show full route
                  final pointsToShow = animatedPoints.isEmpty ? widget.routePoints : animatedPoints;
                  
                  // Reduced logging - only show when animation starts
                  if (kDebugMode && _routeAnimation.value == 0.0 && pointsToShow.isNotEmpty) {
                    print('🎨 Route animation started for ${widget.routePoints.length} points');
                  }
                  
                  return PolylineLayer(
                    polylines: [
                      // Shadow/Border polyline
                      if (pointsToShow.length > 1)
                        Polyline(
                          points: pointsToShow,
                          color: Colors.black.withOpacity(0.3),
                          strokeWidth: 8.0,
                        ),
                      // Main route polyline
                      if (pointsToShow.length > 1)
                        Polyline(
                          points: pointsToShow,
                          color: const Color(0xFF007AFF), // Apple Maps blue
                          strokeWidth: 5.0,
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
        
        // Route info overlay
        _buildRouteInfoOverlay(),
        
        // Loading indicator
        if (_isLoading)
          Container(
            color: Colors.black.withOpacity(0.3),
            child: const Center(
              child: CircularProgressIndicator(),
            ),
          ),
      ],
    );
  }

  @override
  void dispose() {
    _routeAnimationController.dispose();
    super.dispose();
  }
}

/// Route instruction item widget for displaying turn-by-turn directions
class RouteInstructionItem extends StatelessWidget {
  final Map<String, dynamic> instruction;
  final int index;
  final bool isCurrentStep;

  const RouteInstructionItem({
    super.key,
    required this.instruction,
    required this.index,
    this.isCurrentStep = false,
  });

  @override
  Widget build(BuildContext context) {
    final type = instruction['type']?.toString() ?? 'straight';
    final instructionText = instruction['instruction']?.toString() ?? 'Continue';
    final distance = instruction['readable_distance']?.toString() ?? '';
    final roadName = instruction['name']?.toString() ?? '';

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isCurrentStep 
            ? Colors.blue.shade50 
            : Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isCurrentStep 
              ? Colors.blue.shade200 
              : Colors.grey.shade200,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: isCurrentStep 
                  ? Colors.blue.shade100 
                  : Colors.grey.shade200,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              _getInstructionIcon(type),
              color: isCurrentStep 
                  ? Colors.blue.shade700 
                  : Colors.grey.shade600,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  instructionText,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: isCurrentStep 
                        ? Colors.blue.shade800 
                        : Colors.grey.shade800,
                  ),
                ),
                if (roadName.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    'on $roadName',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (distance.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                distance,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: Colors.grey.shade700,
                ),
              ),
            ),
        ],
      ),
    );
  }

  IconData _getInstructionIcon(String type) {
    switch (type) {
      case 'turn-left':
        return Icons.turn_left;
      case 'turn-right':
        return Icons.turn_right;
      case 'turn-slight-left':
        return Icons.turn_slight_left;
      case 'turn-slight-right':
        return Icons.turn_slight_right;
      case 'turn-sharp-left':
        return Icons.turn_sharp_left;
      case 'turn-sharp-right':
        return Icons.turn_sharp_right;
      case 'roundabout-enter':
      case 'roundabout-exit':
        return Icons.roundabout_left;
      case 'fork':
        return Icons.call_split;
      case 'merge':
        return Icons.merge;
      case 'uturn':
        return Icons.u_turn_left;
      case 'depart':
        return Icons.start;
      case 'arrive':
        return Icons.place;
      default:
        return Icons.straight;
    }
  }
}