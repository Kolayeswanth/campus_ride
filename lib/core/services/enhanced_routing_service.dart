import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
import 'package:google_polyline_algorithm/google_polyline_algorithm.dart';
import 'package:latlong2/latlong.dart';

/// Enhanced routing service using OSRM (Open Source Routing Machine)
/// Provides road-snapped routes with turn-by-turn navigation instructions
class EnhancedRoutingService {
  static final Dio _dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 30),
    receiveTimeout: const Duration(seconds: 60),
    sendTimeout: const Duration(seconds: 30),
    headers: {
      'Accept': 'application/json',
      'Content-Type': 'application/json',
      'User-Agent': 'CampusRide/1.0',
    },
  ));

  /// Get enhanced routing using OSRM
  static Future<Map<String, dynamic>> getEnhancedRoute(
    List<LatLng> waypoints, {
    String profile = 'driving-car',
    bool alternatives = false,
    bool steps = true,
    String geometries = 'geojson',
  }) async {
    if (waypoints.length < 2) {
      throw ArgumentError('At least 2 waypoints are required');
    }

    if (kDebugMode) {
      print('🚗 Calculating route for ${waypoints.length} waypoints');
    }

    // Use OSRM as primary service (proven to work perfectly)
    try {
      final result = await _getOSRMRoute(waypoints, profile, alternatives, steps, geometries);
      if (result.isNotEmpty && result['route_points'] != null) {
        if (kDebugMode) {
          final points = result['route_points'] as List<LatLng>;
          print('✅ Route generated: ${points.length} points, ${result['distance_km']?.toStringAsFixed(2)} km');
        }
        return result;
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Routing failed: $e');
      }
    }

    throw Exception('Routing service failed');
  }

  /// OSRM (Open Source Routing Machine) - Free public server
  static Future<Map<String, dynamic>> _getOSRMRoute(
    List<LatLng> waypoints,
    String profile,
    bool alternatives,
    bool steps,
    String geometries,
  ) async {
    // Format coordinates for OSRM (longitude,latitude)
    final coordinates = waypoints
        .map((point) => '${point.longitude},${point.latitude}')
        .join(';');

    final queryParams = <String, dynamic>{
      'geometries': 'geojson',
      'overview': 'full',
      'steps': steps ? 'true' : 'false',
    };

    if (alternatives) {
      queryParams['alternatives'] = 'true';
    }

    // Use public OSRM server
    final response = await _dio.get(
      'https://router.project-osrm.org/route/v1/driving/$coordinates',
      queryParameters: queryParams,
    );

    if (response.statusCode != 200) {
      throw Exception('OSRM HTTP ${response.statusCode}: ${response.data}');
    }

    final data = response.data;
    
    if (data['routes'] == null || (data['routes'] as List).isEmpty) {
      throw Exception('No routes found in OSRM response');
    }

    final route = data['routes'][0];
    final geometry = route['geometry'];
    
    List<LatLng> routePoints = [];
    
    if (geometry['type'] == 'LineString') {
      final coordinates = geometry['coordinates'] as List;
      routePoints = coordinates
          .map((coord) => LatLng(coord[1].toDouble(), coord[0].toDouble()))
          .toList();
    }

    final distance = (route['distance'] as num).toDouble() / 1000.0; // Convert to km
    final duration = (route['duration'] as num).toDouble() / 60.0; // Convert to minutes

    // Extract turn-by-turn instructions
    final instructions = <Map<String, dynamic>>[];
    if (steps && route['legs'] != null) {
      final legs = route['legs'] as List;
      for (final leg in legs) {
        final legSteps = leg['steps'] as List? ?? [];
        for (final step in legSteps) {
          final maneuver = step['maneuver'] ?? {};
          instructions.add({
            'instruction': maneuver['instruction'] ?? 'Continue',
            'distance': ((step['distance'] as num?)?.toDouble() ?? 0) / 1000.0,
            'duration': ((step['duration'] as num?)?.toDouble() ?? 0) / 60.0,
            'type': maneuver['type']?.toString() ?? 'straight',
            'name': step['name'] ?? '',
            'modifier': maneuver['modifier']?.toString() ?? '',
            'readable_distance': '${(((step['distance'] as num?)?.toDouble() ?? 0) / 1000.0).toStringAsFixed(1)} km',
            'readable_duration': '${(((step['duration'] as num?)?.toDouble() ?? 0) / 60.0).toStringAsFixed(0)} min',
          });
        }
      }
    }

    return {
      'route_points': routePoints,
      'distance_km': distance,
      'duration_minutes': duration,
      'polyline_encoded': encodePolyline(routePoints.map((p) => [p.latitude, p.longitude]).toList()),
      'instructions': instructions,
      'raw_response': data,
      'source': 'osrm',
      'fallback': false,
    };
  }

  /// Calculate distance between two points in kilometers
  static double calculateDistance(LatLng point1, LatLng point2) {
    const double earthRadius = 6371.0; // Earth's radius in kilometers
    
    final double lat1Rad = point1.latitude * (math.pi / 180.0);
    final double lat2Rad = point2.latitude * (math.pi / 180.0);
    final double deltaLatRad = (point2.latitude - point1.latitude) * (math.pi / 180.0);
    final double deltaLngRad = (point2.longitude - point1.longitude) * (math.pi / 180.0);

    final double a = math.sin(deltaLatRad / 2) * math.sin(deltaLatRad / 2) +
        math.cos(lat1Rad) * math.cos(lat2Rad) *
        math.sin(deltaLngRad / 2) * math.sin(deltaLngRad / 2);
    final double c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));

    return earthRadius * c;
  }
}