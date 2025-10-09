import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' as latlong;
import 'animated_polyline_widget.dart';

import '../../core/services/nominatim_location_service.dart';

/// Widget that displays OpenStreetMap tiles with route overlay
class OlaMapWidget extends StatefulWidget {
  final List<latlong.LatLng> routePoints;
  final LocationSuggestion? startPoint;
  final LocationSuggestion? endPoint;
  final List<LocationSuggestion> viaPoints;
  final double? distance;
  final double? duration;
  final VoidCallback? onMapReady;

  const OlaMapWidget({
    super.key,
    this.routePoints = const [],
    this.startPoint,
    this.endPoint,
    this.viaPoints = const [],
    this.distance,
    this.duration,
    this.onMapReady,
  });

  @override
  State<OlaMapWidget> createState() => _OlaMapWidgetState();
}

class _OlaMapWidgetState extends State<OlaMapWidget> {
  final MapController _mapController = MapController();
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _initializeMap();
  }

  void _initializeMap() {
    // Simulate map loading
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        
        // Debug route points and auto-fit bounds
        if (widget.routePoints.isNotEmpty) {
          _debugRoutePoints();
          _fitBoundsToRoute();
        }
        
        widget.onMapReady?.call();
      }
    });
  }

  void _debugRoutePoints() {
    if (!kDebugMode || widget.routePoints.isEmpty) return;
    
    print('🛣️ Route points debugging:');
    print('📊 Total route points: ${widget.routePoints.length}');
    print('🚀 Start point: ${widget.routePoints.first}');
    print('🏁 End point: ${widget.routePoints.last}');
    
    // Check coordinate range to detect potential issues
    double minLat = widget.routePoints.first.latitude;
    double maxLat = widget.routePoints.first.latitude;
    double minLng = widget.routePoints.first.longitude;
    double maxLng = widget.routePoints.first.longitude;
    
    for (final point in widget.routePoints) {
      minLat = math.min(minLat, point.latitude);
      maxLat = math.max(maxLat, point.latitude);
      minLng = math.min(minLng, point.longitude);
      maxLng = math.max(maxLng, point.longitude);
    }
    
    print('📏 Coordinate bounds:');
    print('   Lat: ${minLat.toStringAsFixed(6)} to ${maxLat.toStringAsFixed(6)} (span: ${(maxLat - minLat).toStringAsFixed(6)})');
    print('   Lng: ${minLng.toStringAsFixed(6)} to ${maxLng.toStringAsFixed(6)} (span: ${(maxLng - minLng).toStringAsFixed(6)})');
    
    // Sample some middle points to check for road-following
    if (widget.routePoints.length > 10) {
      print('🔍 Sample points (every ${widget.routePoints.length ~/ 5}):');
      for (int i = 0; i < widget.routePoints.length; i += widget.routePoints.length ~/ 5) {
        final point = widget.routePoints[i];
        print('   Point $i: Lat ${point.latitude.toStringAsFixed(6)}, Lng ${point.longitude.toStringAsFixed(6)}');
      }
    }
    
    // Check if points form a reasonable path (not all the same or too linear)
    bool hasVariation = false;
    final firstPoint = widget.routePoints.first;
    for (final point in widget.routePoints) {
      if ((point.latitude - firstPoint.latitude).abs() > 0.001 ||
          (point.longitude - firstPoint.longitude).abs() > 0.001) {
        hasVariation = true;
        break;
      }
    }
    
    if (hasVariation) {
      print('✅ Route has proper geographic variation');
      
      // Additional check: see if the route makes geographic sense
      final latSpan = maxLat - minLat;
      final lngSpan = maxLng - minLng;
      if (latSpan < 0.001 && lngSpan < 0.001) {
        print('⚠️ WARNING: Route span is very small - might be all at same location');
      } else if (latSpan > 10 || lngSpan > 10) {
        print('⚠️ WARNING: Route span is very large - might be incorrect coordinates');
      } else {
        print('✅ Route geographic span looks reasonable');
      }
    } else {
      print('⚠️ WARNING: All route points seem to be at the same location!');
    }
  }

  void _fitBoundsToRoute() {
    if (widget.routePoints.isEmpty) return;
    
    if (kDebugMode) {
      print('🗺️ Fitting map bounds to ${widget.routePoints.length} route points');
      print('📍 Start: ${widget.startPoint?.displayName ?? 'Unknown'}');
      print('📍 End: ${widget.endPoint?.displayName ?? 'Unknown'}');
    }
    
    // Calculate bounds from all route points to ensure complete coverage
    double minLat = widget.routePoints.first.latitude;
    double maxLat = widget.routePoints.first.latitude;
    double minLng = widget.routePoints.first.longitude;
    double maxLng = widget.routePoints.first.longitude;

    // Include all route points in bounds calculation
    for (final point in widget.routePoints) {
      minLat = math.min(minLat, point.latitude);
      maxLat = math.max(maxLat, point.latitude);
      minLng = math.min(minLng, point.longitude);
      maxLng = math.max(maxLng, point.longitude);
    }

    // Also ensure start and end markers are included
    if (widget.startPoint != null) {
      minLat = math.min(minLat, widget.startPoint!.latitude);
      maxLat = math.max(maxLat, widget.startPoint!.latitude);
      minLng = math.min(minLng, widget.startPoint!.longitude);
      maxLng = math.max(maxLng, widget.startPoint!.longitude);
    }
    
    if (widget.endPoint != null) {
      minLat = math.min(minLat, widget.endPoint!.latitude);
      maxLat = math.max(maxLat, widget.endPoint!.latitude);
      minLng = math.min(minLng, widget.endPoint!.longitude);
      maxLng = math.max(maxLng, widget.endPoint!.longitude);
    }

    // Add optimal padding to ensure start/end points are clearly visible
    final latSpan = maxLat - minLat;
    final lngSpan = maxLng - minLng;
    
    // Use adaptive padding based on route span for better visibility
    double paddingPercent;
    if (latSpan < 0.01 || lngSpan < 0.01) {
      paddingPercent = 0.50; // 50% padding for very short routes
    } else if (latSpan < 0.1 || lngSpan < 0.1) {
      paddingPercent = 0.25; // 25% padding for short routes
    } else {
      paddingPercent = 0.12; // 12% padding for longer routes
    }
    
    final minPadding = 0.004; // Minimum ~400m padding
    final latPadding = math.max(latSpan * paddingPercent, minPadding);
    final lngPadding = math.max(lngSpan * paddingPercent, minPadding);
    
    minLat -= latPadding;
    maxLat += latPadding;
    minLng -= lngPadding;
    maxLng += lngPadding;

    // Calculate center point
    final center = latlong.LatLng(
      (minLat + maxLat) / 2,
      (minLng + maxLng) / 2,
    );
    
    // Calculate zoom level based on padded bounds
    final paddedLatSpan = maxLat - minLat;
    final paddedLngSpan = maxLng - minLng;
    final maxSpan = math.max(paddedLatSpan, paddedLngSpan);
    
    // Adaptive zoom levels based on route bounds for optimal visibility
    double zoom;
    if (maxSpan > 15) zoom = 5.0;         // Country/state level
    else if (maxSpan > 8) zoom = 6.5;     // Multi-city routes  
    else if (maxSpan > 4) zoom = 8.0;     // Inter-city routes
    else if (maxSpan > 2) zoom = 9.5;     // City-wide routes
    else if (maxSpan > 1) zoom = 11.0;    // District routes
    else if (maxSpan > 0.5) zoom = 12.5;  // Local routes
    else if (maxSpan > 0.25) zoom = 13.5; // Neighborhood routes
    else if (maxSpan > 0.12) zoom = 14.5; // Short routes
    else if (maxSpan > 0.06) zoom = 15.0; // Very short routes  
    else if (maxSpan > 0.03) zoom = 15.5; // Campus routes
    else zoom = 16.5;                     // Very local routes
    
    // Fine-tune zoom to ensure start/end points are clearly visible
    // Reduce zoom slightly if we have very small routes for better visibility
    if (maxSpan < 0.02) {
      zoom = math.min(zoom, 15.8); // Don't zoom too far in for tiny routes
    }

    if (kDebugMode) {
      print('🎯 Route bounds: lat(${minLat.toStringAsFixed(4)} to ${maxLat.toStringAsFixed(4)}), lng(${minLng.toStringAsFixed(4)} to ${maxLng.toStringAsFixed(4)})');
      print('📐 Span: ${maxSpan.toStringAsFixed(4)}°, zoom: $zoom');
      print('📍 Map center: ${center.latitude.toStringAsFixed(4)}, ${center.longitude.toStringAsFixed(4)}');
    }

    // Apply map positioning with delay for proper initialization
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _mapController.move(center, zoom);
        
        if (kDebugMode) {
          print('✅ Map positioned to show complete route with start/end points');
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Main map widget
        FlutterMap(
          mapController: _mapController,
          options: MapOptions(
            minZoom: 3.0,
            maxZoom: 18.0,
            keepAlive: true,
          ),
          children: [
            // OpenStreetMap tile layer (fallback from Ola Maps due to API limitations)
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'com.campusride.app',
              maxZoom: 18,
              additionalOptions: const {
                'attribution': '© OpenStreetMap contributors',
              },
              errorTileCallback: (tile, error, stackTrace) {
                if (kDebugMode) {
                  print('🗺️ Tile loading error: $error');
                }
              },
            ),
            
            // Route polyline overlay with Apple Maps-style animation
            if (widget.routePoints.isNotEmpty)
              EnhancedAnimatedPolyline(
                routePoints: widget.routePoints.map((point) => 
                    latlong.LatLng(point.latitude, point.longitude)
                ).toList(),
                routeColor: const Color(0xFF007AFF), // Apple Maps blue
                strokeWidth: 5.0,
                animationDuration: const Duration(milliseconds: 2000),
                showPulsingMarkers: true,
              ),
            
            // Markers layer
            MarkerLayer(
              markers: _buildMarkers(),
            ),
            
            // Route info overlay
            if (widget.distance != null && widget.duration != null)
              _buildRouteInfoOverlay(),
          ],
        ),
        
        // Loading indicator
        if (_isLoading)
          Container(
            color: Colors.grey.shade100,
            child: const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text(
                    'Loading Map...',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  /// Calculate map center based on route points or start/end locations
  latlong.LatLng _calculateCenter() {
    // Prefer using actual start and end points for better centering
    if (widget.startPoint != null && widget.endPoint != null) {
      final centerLat = (widget.startPoint!.latitude + widget.endPoint!.latitude) / 2;
      final centerLng = (widget.startPoint!.longitude + widget.endPoint!.longitude) / 2;
      
      if (kDebugMode) {
        print('🎯 Map center from start/end points: $centerLat, $centerLng');
      }
      
      return latlong.LatLng(centerLat, centerLng);
    }

    if (widget.routePoints.isNotEmpty) {
      if (widget.routePoints.length == 1) {
        final point = widget.routePoints.first;
        return latlong.LatLng(point.latitude, point.longitude);
      }

      // Calculate center of route bounds for better positioning
      double minLat = widget.routePoints.first.latitude;
      double maxLat = widget.routePoints.first.latitude;
      double minLng = widget.routePoints.first.longitude;
      double maxLng = widget.routePoints.first.longitude;

      for (final point in widget.routePoints) {
        minLat = math.min(minLat, point.latitude);
        maxLat = math.max(maxLat, point.latitude);
        minLng = math.min(minLng, point.longitude);
        maxLng = math.max(maxLng, point.longitude);
      }

      return latlong.LatLng(
        (minLat + maxLat) / 2,
        (minLng + maxLng) / 2,
      );
    }

    // Default center (India) when no route data available
    return latlong.LatLng(20.5937, 78.9629);
  }

  /// Calculate appropriate zoom level based on route distance and bounds
  double _calculateZoom() {
    // Use start/end points for initial zoom calculation if available
    if (widget.startPoint != null && widget.endPoint != null) {
      final latDiff = (widget.startPoint!.latitude - widget.endPoint!.latitude).abs();
      final lngDiff = (widget.startPoint!.longitude - widget.endPoint!.longitude).abs();
      final maxDiff = math.max(latDiff, lngDiff);
      
      // More precise zoom for start/end point distance
      if (maxDiff > 5) return 7.0;       // Very long routes
      if (maxDiff > 2) return 9.0;       // Long routes  
      if (maxDiff > 1) return 11.0;      // Medium routes
      if (maxDiff > 0.5) return 12.5;    // Short routes
      if (maxDiff > 0.2) return 14.0;    // Local routes
      if (maxDiff > 0.1) return 15.0;    // Nearby routes
      return 16.0;                       // Very close routes
    }

    if (widget.routePoints.isEmpty) {
      return 6.0; // Default zoom for India view
    }

    if (widget.routePoints.length == 1) {
      return 15.0; // Close zoom for single point
    }

    // Calculate bounds from route points
    double minLat = widget.routePoints.first.latitude;
    double maxLat = widget.routePoints.first.latitude;
    double minLng = widget.routePoints.first.longitude;
    double maxLng = widget.routePoints.first.longitude;

    for (final point in widget.routePoints) {
      minLat = math.min(minLat, point.latitude);
      maxLat = math.max(maxLat, point.latitude);
      minLng = math.min(minLng, point.longitude);
      maxLng = math.max(maxLng, point.longitude);
    }

    // Calculate zoom based on actual route bounds
    final latDiff = maxLat - minLat;
    final lngDiff = maxLng - minLng;
    final maxDiff = math.max(latDiff, lngDiff);

    if (kDebugMode) {
      print('📏 Route bounds difference: ${maxDiff.toStringAsFixed(4)} degrees');
    }

    // Optimized zoom levels for route visibility
    if (maxDiff > 10) return 6.0;        // Interstate routes
    if (maxDiff > 5) return 8.0;         // Long distance routes
    if (maxDiff > 2) return 10.0;        // Inter-city routes
    if (maxDiff > 1) return 11.5;        // City routes
    if (maxDiff > 0.5) return 13.0;      // Local routes
    if (maxDiff > 0.2) return 14.5;      // Neighborhood routes
    if (maxDiff > 0.1) return 15.5;      // Short routes
    return 16.5;                         // Campus/nearby routes
  }

  /// Build markers for start, end, and via points
  List<Marker> _buildMarkers() {
    final markers = <Marker>[];

    // Start marker
    if (widget.startPoint != null) {
      markers.add(
        Marker(
          point: latlong.LatLng(
            widget.startPoint!.latitude,
            widget.startPoint!.longitude,
          ),
          child: _buildMarkerIcon(
            icon: Icons.trip_origin,
            color: Colors.green,
            label: 'S',
          ),
          width: 40,
          height: 40,
        ),
      );
    }

    // Via markers
    for (int i = 0; i < widget.viaPoints.length; i++) {
      final viaPoint = widget.viaPoints[i];
      markers.add(
        Marker(
          point: latlong.LatLng(
            viaPoint.latitude,
            viaPoint.longitude,
          ),
          child: _buildMarkerIcon(
            icon: Icons.radio_button_unchecked,
            color: Colors.orange,
            label: '${i + 1}',
          ),
          width: 36,
          height: 36,
        ),
      );
    }

    // End marker
    if (widget.endPoint != null) {
      markers.add(
        Marker(
          point: latlong.LatLng(
            widget.endPoint!.latitude,
            widget.endPoint!.longitude,
          ),
          child: _buildMarkerIcon(
            icon: Icons.location_on,
            color: Colors.red,
            label: 'E',
          ),
          width: 40,
          height: 40,
        ),
      );
    }

    return markers;
  }

  /// Build individual marker icon
  Widget _buildMarkerIcon({
    required IconData icon,
    required Color color,
    required String label,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white, width: 2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Icon(
        icon,
        color: Colors.white,
        size: 20,
      ),
    );
  }

  /// Build route info overlay widget
  Widget _buildRouteInfoOverlay() {
    return Positioned(
      top: 10,
      right: 10,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.route, size: 16, color: Colors.blue.shade600),
                const SizedBox(width: 6),
                Text(
                  'Route Info',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey.shade800,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (widget.distance != null)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.straighten, size: 12, color: Colors.grey.shade600),
                  const SizedBox(width: 4),
                  Text(
                    '${widget.distance!.toStringAsFixed(1)} km',
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey.shade800,
                    ),
                  ),
                ],
              ),
            if (widget.duration != null)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.access_time, size: 12, color: Colors.grey.shade600),
                  const SizedBox(width: 4),
                  Text(
                    '${widget.duration!.toStringAsFixed(0)} min',
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey.shade800,
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}