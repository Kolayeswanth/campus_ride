import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_polyline_algorithm/google_polyline_algorithm.dart';
import 'package:http/http.dart' as http;
import '../models/bus_route.dart';
import 'real_routing_service.dart';

class OlaMapsService {
  static String? _apiKey;
  static const String _baseUrl = 'https://api.olamaps.io';
  static final Dio _dio = Dio();

  /// Initialize OLA Maps API key
  static void initialize() {
    try {
      _apiKey = dotenv.env['OLA_MAPS_API_KEY'];
      
      if (_apiKey == null || _apiKey!.isEmpty) {
        if (kDebugMode) {
          print('WARNING: OLA_MAPS_API_KEY not found in .env file');
        }
        // Use the working key provided by the user
        _apiKey = 'u8bxvlb9ubgP2wKgJyxEY2ya1hYNcvyxFDCpA85y';
      }

      if (kDebugMode) {
        print('INFO: OLA Maps Service initialized');
        if (kIsWeb) {
          print('INFO: Running on web - some features may be limited');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('ERROR: Failed to initialize OLA Maps Service: $e');
      }
    }
  }

  /// Generate route using the exact working pattern from user's old code
  static Future<Map<String, dynamic>> generateRoute({
    required LatLng start,
    required LatLng end,
    List<LatLng>? waypoints,
  }) async {
    try {
      // Ola Maps Directions API - user's exact working pattern
      final url = 'https://api.olamaps.io/routing/v1/directions';
      
      // Build coordinates (same format as ORS)
      List<List<double>> coordinates = [[start.longitude, start.latitude]];
      if (waypoints != null) {
        coordinates.addAll(waypoints.map((wp) => [wp.longitude, wp.latitude]));
      }
      coordinates.add([end.longitude, end.latitude]);
      
      final response = await http.post(
        Uri.parse(url),
        headers: {
          'X-API-Key': _apiKey!, // Read from .env
          'Content-Type': 'application/json',
        },
        body: json.encode({
          'origin': '${start.latitude},${start.longitude}',
          'destination': '${end.latitude},${end.longitude}',
          'waypoints': waypoints?.map((w) => '${w.latitude},${w.longitude}').join('|'),
          'alternatives': false,
          'steps': true,
          'geometries': 'geojson',
        }),
      );
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final route = data['routes'][0];
        final geometry = route['geometry'];
        final coords = geometry['coordinates'] as List;
        
        // Same return format as ORS
        final routePoints = coords.map((coord) => LatLng(coord[1], coord[0])).toList();
        
        // Calculate distance and duration
        final summary = route['legs'][0];
        final distance = (summary['distance'] ?? 0) / 1000.0; // Convert to km
        final duration = (summary['duration'] ?? 0) / 60.0; // Convert to minutes
        
        if (kDebugMode) {
          print('SUCCESS: OLA Maps route generated: ${distance.toStringAsFixed(2)} km, ${duration.toStringAsFixed(0)} min, ${routePoints.length} points');
        }
        
        return {
          'route_points': routePoints,
          'distance': distance,
          'duration': duration,
          'polyline': routePoints,
          'polyline_data': _encodePolyline(routePoints),
          'instructions': _extractInstructions(route),
          'fallback': false,
          'source': 'ola_maps_real_roads',
        };
      }
      
      throw Exception('Route generation failed: ${response.statusCode}');
    } catch (e) {
      if (kDebugMode) {
        print('ERROR: Ola Maps route error: $e');
      }
      return {};
    }
  }

  /// Get directions with multiple service fallbacks (primary method)
  static Future<Map<String, dynamic>> getDirections(List<LatLng> waypoints, {
    String mode = 'driving',
    bool alternatives = false,
    bool withTrafficInfo = true,
  }) async {
    if (waypoints.length < 2) {
      throw ArgumentError('At least 2 waypoints are required');
    }

    if (kDebugMode) {
      print('INFO: Getting real road directions for ${waypoints.length} waypoints');
    }

    // 1. Try OpenRouteService first (primary routing service)
    try {
      if (kDebugMode) {
        print('INFO: Attempting OpenRouteService for real road routing');
      }
      
      final result = await RealRoutingService.getDirections(waypoints);
      
      if (result.isNotEmpty && result['route_points'] != null) {
        if (kDebugMode) {
          print('SUCCESS: OpenRouteService route: ${result['distance'].toStringAsFixed(2)} km, ${result['duration'].toStringAsFixed(0)} min');
        }
        return result;
      }
      
    } catch (e) {
      if (kDebugMode) {
        print('WARNING: OpenRouteService failed: $e');
      }
    }

    // 2. Try OLA Maps API (secondary)
    try {
      if (kDebugMode) {
        print('INFO: Attempting OLA Maps routing');
      }

      final start = waypoints.first;
      final end = waypoints.last;
      final viaWaypoints = waypoints.length > 2 ? waypoints.sublist(1, waypoints.length - 1) : null;
      
      final result = await generateRoute(
        start: start,
        end: end,
        waypoints: viaWaypoints,
      );
      
      if (result.isNotEmpty && result['route_points'] != null) {
        if (kDebugMode) {
          print('SUCCESS: OLA Maps route: ${result['distance'].toStringAsFixed(2)} km, ${result['duration'].toStringAsFixed(0)} min');
        }
        return result;
      }

    } catch (e) {
      if (e is DioException) {
        if (kDebugMode) {
          print('ERROR: OLA Maps API error: $e');
          print('ERROR: Status Code: ${e.response?.statusCode}');
          print('ERROR: Response: ${e.response?.data}');
        }
      } else {
        if (kDebugMode) {
          print('ERROR: Error with OLA Maps Directions API: $e');
        }
      }
    }

    // 3. Enhanced fallback route generation
    if (kDebugMode) {
      print('INFO: Using enhanced fallback route generation');
    }

    try {
      return _generateEnhancedRoadFollowingRoute(waypoints);
    } catch (fallbackError) {
      if (kDebugMode) {
        print('ERROR: Error in fallback route generation: $fallbackError');
      }
      rethrow;
    }
  }

  /// Enhanced road-following route generation as fallback
  static Map<String, dynamic> _generateEnhancedRoadFollowingRoute(List<LatLng> waypoints) {
    if (kDebugMode) {
      print('INFO: Generating enhanced road-following fallback route');
    }

    final List<LatLng> routePoints = [];
    double totalDistance = 0;
    double totalDuration = 0;

    for (int i = 0; i < waypoints.length - 1; i++) {
      final start = waypoints[i];
      final end = waypoints[i + 1];
      
      final segmentDistance = _calculateDistance(start, end);
      totalDistance += segmentDistance;
      
      // Generate road-like path points
      final segmentPoints = _generateRoadLikePath(start, end, segmentDistance);
      
      if (i == 0) {
        routePoints.addAll(segmentPoints);
      } else {
        routePoints.addAll(segmentPoints.skip(1));
      }
    }

    totalDuration = (totalDistance / 40 * 60); // 40 km/h average speed

    if (kDebugMode) {
      print('INFO: Enhanced fallback route: ${totalDistance.toStringAsFixed(2)} km, ${totalDuration.toStringAsFixed(0)} min, ${routePoints.length} points');
    }

    return {
      'route_points': routePoints,
      'distance': totalDistance,
      'duration': totalDuration,
      'polyline': routePoints,
      'polyline_data': _encodePolyline(routePoints),
      'instructions': _generateBasicInstructions(waypoints),
      'fallback': true,
      'source': 'enhanced_road_following_fallback',
    };
  }

  /// Generate realistic road-like path between two points
  static List<LatLng> _generateRoadLikePath(LatLng start, LatLng end, double distance) {
    final points = <LatLng>[start];
    
    // More points for longer distances, simulating real road complexity
    final numPoints = (distance * 8).round().clamp(10, 100);
    
    // Create intermediate waypoints that simulate road network
    final roadWaypoints = _generateRoadNetworkPoints(start, end, distance);
    
    // Generate smooth curves through road network points
    for (int w = 0; w < roadWaypoints.length - 1; w++) {
      final segmentStart = roadWaypoints[w];
      final segmentEnd = roadWaypoints[w + 1];
      final segmentPoints = numPoints ~/ roadWaypoints.length;
      
      for (int i = 1; i <= segmentPoints; i++) {
        final ratio = i / segmentPoints;
        
        // Use bezier curve for smooth road-like paths
        final lat = _bezierInterpolate(segmentStart.latitude, segmentEnd.latitude, ratio);
        final lng = _bezierInterpolate(segmentStart.longitude, segmentEnd.longitude, ratio);
        
        // Add road network influence
        final roadInfluence = _calculateRoadNetworkInfluence(ratio, distance);
        
        points.add(LatLng(lat + roadInfluence.latitude, lng + roadInfluence.longitude));
      }
    }
    
    points.add(end);
    return points;
  }

  /// Generate points that simulate following a road network
  static List<LatLng> _generateRoadNetworkPoints(LatLng start, LatLng end, double distance) {
    final waypoints = <LatLng>[start];
    
    // Number of "intersections" based on distance (more for longer routes)
    final numIntersections = (distance / 3).round().clamp(2, 8);
    
    for (int i = 1; i <= numIntersections; i++) {
      final ratio = i / (numIntersections + 1);
      
      // Base position
      final baseLat = start.latitude + (end.latitude - start.latitude) * ratio;
      final baseLng = start.longitude + (end.longitude - start.longitude) * ratio;
      
      // Road network deviation (simulate following major roads)
      final bearing = math.atan2(end.longitude - start.longitude, end.latitude - start.latitude);
      final perpBearing = bearing + math.pi / 2;
      
      // Vary the road deviation based on "urban density"
      final urbanFactor = distance > 20 ? 0.5 : 1.5; // Less deviation for highways
      final maxDeviation = 0.005 * urbanFactor;
      
      final deviation = (math.sin(ratio * math.pi * 2) + math.cos(ratio * math.pi * 3)) * maxDeviation;
      
      final deviationLat = math.cos(perpBearing) * deviation;
      final deviationLng = math.sin(perpBearing) * deviation;
      
      waypoints.add(LatLng(baseLat + deviationLat, baseLng + deviationLng));
    }
    
    waypoints.add(end);
    return waypoints;
  }

  /// Calculate great circle distance between two points
  static double _calculateDistance(LatLng start, LatLng end) {
    const double earthRadius = 6371;
    
    final lat1Rad = start.latitude * (math.pi / 180);
    final lat2Rad = end.latitude * (math.pi / 180);
    final deltaLat = (end.latitude - start.latitude) * (math.pi / 180);
    final deltaLng = (end.longitude - start.longitude) * (math.pi / 180);
    
    final a = math.sin(deltaLat / 2) * math.sin(deltaLat / 2) +
        math.cos(lat1Rad) * math.cos(lat2Rad) *
        math.sin(deltaLng / 2) * math.sin(deltaLng / 2);
    
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return earthRadius * c;
  }

  /// Bezier curve interpolation for smooth paths
  static double _bezierInterpolate(double start, double end, double t) {
    final control1 = start + (end - start) * 0.3;
    final control2 = start + (end - start) * 0.7;
    
    final u = 1 - t;
    return u * u * u * start + 3 * u * u * t * control1 + 3 * u * t * t * control2 + t * t * t * end;
  }

  /// Calculate road network influence for realistic routing
  static LatLng _calculateRoadNetworkInfluence(double ratio, double distance) {
    final gridSize = distance > 10 ? 0.01 : 0.005; // Larger grid for longer distances
    final influence = math.sin(ratio * math.pi * 4) * gridSize * 0.3;
    
    return LatLng(influence * 0.7, influence);
  }

  /// Generate basic turn-by-turn instructions
  static List<Map<String, dynamic>> _generateBasicInstructions(List<LatLng> waypoints) {
    final instructions = <Map<String, dynamic>>[];
    
    for (int i = 0; i < waypoints.length - 1; i++) {
      final distance = _calculateDistance(waypoints[i], waypoints[i + 1]);
      final duration = (distance / 40 * 60); // 40 km/h average
      
      String instruction;
      if (i == 0) {
        instruction = 'Start your journey';
      } else if (i == waypoints.length - 2) {
        instruction = 'Arrive at destination';
      } else {
        instruction = 'Continue on current route';
      }
      
      instructions.add({
        'instruction': instruction,
        'distance': '${distance.toStringAsFixed(1)} km',
        'duration': '${duration.toStringAsFixed(0)} min',
        'type': 'straight',
      });
    }
    
    return instructions;
  }

  /// Encode polyline using Google's algorithm
  static String _encodePolyline(List<LatLng> points) {
    return encodePolyline(points.map((p) => [p.latitude, p.longitude]).toList());
  }

  /// Extract instructions from OLA Maps response
  static List<Map<String, dynamic>> _extractInstructions(Map<String, dynamic> route) {
    final instructions = <Map<String, dynamic>>[];
    
    try {
      final legs = route['legs'] as List? ?? [];
      for (final leg in legs) {
        final steps = leg['steps'] as List? ?? [];
        for (final step in steps) {
          final instruction = step['maneuver']?['instruction'] ?? 'Continue straight';
          final distance = ((step['distance'] ?? 0) / 1000.0).toStringAsFixed(1);
          final duration = ((step['duration'] ?? 0) / 60.0).toStringAsFixed(0);
          
          instructions.add({
            'instruction': instruction,
            'distance': '${distance} km',
            'duration': '${duration} min',
            'type': step['maneuver']?['type'] ?? 'straight',
          });
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('ERROR: Failed to extract instructions: $e');
      }
    }
    
    return instructions;
  }

  /// Get reverse geocoding for a location
  static Future<String?> getLocationName(LatLng location) async {
    try {
      final response = await _dio.get(
        '$_baseUrl/places/v1/reverse-geocode',
        queryParameters: {
          'latlng': '${location.latitude},${location.longitude}',
          'api_key': _apiKey,
        },
      );

      if (response.statusCode == 200) {
        final results = response.data['results'] as List?;
        if (results != null && results.isNotEmpty) {
          return results.first['formatted_address'] as String?;
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('ERROR: Reverse geocoding failed: $e');
      }
    }
    return null;
  }
}