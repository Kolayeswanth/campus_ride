import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' as latlong;

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
        
        // Auto-fit bounds to show complete route
        if (widget.routePoints.isNotEmpty) {
          _fitBoundsToRoute();
        }
        
        widget.onMapReady?.call();
      }
    });
  }

  void _fitBoundsToRoute() {
    if (widget.routePoints.isEmpty) return;
    
    // Calculate bounds with padding
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

    // Add padding (10% of the bounds)
    final latPadding = (maxLat - minLat) * 0.1;
    final lngPadding = (maxLng - minLng) * 0.1;
    
    minLat -= latPadding;
    maxLat += latPadding;
    minLng -= lngPadding;
    maxLng += lngPadding;

    // Calculate appropriate center and zoom for the bounds
    final center = latlong.LatLng(
      (minLat + maxLat) / 2,
      (minLng + maxLng) / 2,
    );
    
    // Calculate zoom based on bounds size
    final latDiff = maxLat - minLat;
    final lngDiff = maxLng - minLng;
    final maxDiff = math.max(latDiff, lngDiff);
    
    double zoom = 16.0;
    if (maxDiff > 5) zoom = 7.0;
    else if (maxDiff > 2) zoom = 9.0;
    else if (maxDiff > 1) zoom = 11.0;
    else if (maxDiff > 0.5) zoom = 13.0;
    else if (maxDiff > 0.1) zoom = 15.0;

    // Move map to fit bounds
    _mapController.move(center, zoom);
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Main map widget
        FlutterMap(
          mapController: _mapController,
          options: MapOptions(
            initialCenter: _calculateCenter(),
            initialZoom: _calculateZoom(),
            minZoom: 3.0,
            maxZoom: 18.0,
            keepAlive: true,
          ),
          children: [
            // Map tile layer with better web compatibility
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'com.campusride.app',
              maxZoom: 18,
              errorTileCallback: (tile, error, stackTrace) {
                if (kDebugMode) {
                  print('🗺️ Tile loading error: $error');
                  print('📍 Tile coordinates: z=${tile.coordinates.z}, x=${tile.coordinates.x}, y=${tile.coordinates.y}');
                }
              },
            ),
            
            // Route polyline overlay
            if (widget.routePoints.isNotEmpty)
              PolylineLayer(
                polylines: [
                  Polyline(
                    points: widget.routePoints,
                    color: const Color(0xFF2563EB), // Better blue color
                    strokeWidth: 6.0, // Thicker line for better visibility
                    borderColor: Colors.white,
                    borderStrokeWidth: 2.0,
                  ),
                ],
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

  /// Calculate map center based on route points
  latlong.LatLng _calculateCenter() {
    if (widget.routePoints.isEmpty) {
      // Default center (India)
      return latlong.LatLng(20.5937, 78.9629);
    }

    if (widget.routePoints.length == 1) {
      final point = widget.routePoints.first;
      return latlong.LatLng(point.latitude, point.longitude);
    }

    // Calculate center of all route points
    double sumLat = 0;
    double sumLng = 0;
    for (final point in widget.routePoints) {
      sumLat += point.latitude;
      sumLng += point.longitude;
    }

    return latlong.LatLng(
      sumLat / widget.routePoints.length,
      sumLng / widget.routePoints.length,
    );
  }

  /// Calculate appropriate zoom level based on route bounds
  double _calculateZoom() {
    if (widget.routePoints.isEmpty) {
      return 6.0; // Default zoom for India
    }

    if (widget.routePoints.length == 1) {
      return 15.0; // Close zoom for single point
    }

    // Calculate bounds
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

    // Calculate zoom based on bounds
    final latDiff = maxLat - minLat;
    final lngDiff = maxLng - minLng;
    final maxDiff = math.max(latDiff, lngDiff);

    if (maxDiff > 10) return 5.0;
    if (maxDiff > 5) return 7.0;
    if (maxDiff > 2) return 9.0;
    if (maxDiff > 1) return 11.0;
    if (maxDiff > 0.5) return 13.0;
    if (maxDiff > 0.1) return 15.0;
    return 16.0;
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