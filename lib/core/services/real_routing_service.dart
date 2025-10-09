import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../models/bus_route.dart';

/// Service for getting real road routing using OpenRouteService API
class RealRoutingService {
  static const String _baseUrl = 'https://api.openrouteservice.org/v2';
  static String? _apiKey;
  
  static final Dio _dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 30),
    receiveTimeout: const Duration(seconds: 60), // Increased timeout for longer routes
    sendTimeout: const Duration(seconds: 30),
    headers: {
      'Accept': 'application/json',
      'Content-Type': 'application/json',
    },
  ));

  static String get apiKey {
    _apiKey ??= dotenv.env['OPENROUTESERVICE_API_KEY'];
    return _apiKey!;
  }

  /// Get real driving directions using OpenRouteService
  static Future<Map<String, dynamic>> getDirections(List<LatLng> waypoints, {
    String profile = 'driving-car',
  }) async {
    if (waypoints.length < 2) {
      throw ArgumentError('At least 2 waypoints are required');
    }

    if (kDebugMode) {
      print('Getting real road directions for ${waypoints.length} waypoints');
    }

    try {
      // Convert waypoints to OpenRouteService format [lng, lat]
      final coordinates = waypoints.map((point) => [point.longitude, point.latitude]).toList();

      final requestBody = {
        'coordinates': coordinates,
        'format': 'json',
        'profile': profile,
        'geometry': true,
        'instructions': true,
        'elevation': false,
        'extra_info': ['waytype', 'surface'],
        'options': {
          'avoid_features': [],
        }
      };

      if (kDebugMode) {
        print('OpenRouteService request: ${coordinates.length} coordinates');
        print('API Key: ${apiKey.substring(0, 20)}...');
        print('Request URL: $_baseUrl/directions/$profile/json');
      }

      final response = await _dio.post(
        '$_baseUrl/directions/$profile/json',
        data: requestBody,
        options: Options(
          headers: {
            'Authorization': apiKey,
            'Content-Type': 'application/json',
          },
        ),
      );

      if (kDebugMode) {
        print('OpenRouteService response status: ${response.statusCode}');
      }

      if (response.statusCode == 200) {
        final data = response.data;
        
        if (data['routes'] != null && (data['routes'] as List).isNotEmpty) {
          final route = data['routes'][0];
          final summary = route['summary'];
          
          // Decode the geometry (encoded polyline)
          final geometry = route['geometry'];
          List<LatLng> routePoints = [];
          
          if (kDebugMode) {
            print('Geometry type: ${geometry.runtimeType}');
            if (geometry is String) {
              print('Geometry string length: ${geometry.length}');
              print('Geometry string preview: ${geometry.substring(0, math.min(50, geometry.length))}');
            } else if (geometry is List) {
              print('Geometry list length: ${geometry.length}');
              if (geometry.isNotEmpty) {
                print('First geometry item: ${geometry[0]}');
              }
            }
          }
          
          if (geometry is String) {
            // Decode polyline string
            routePoints = _decodePolyline(geometry);
          } else if (geometry is List && geometry.isNotEmpty) {
            // Direct coordinate array
            routePoints = (geometry as List).map((coord) => 
                LatLng(coord[1].toDouble(), coord[0].toDouble())).toList();
          }

          final distance = (summary['distance'] ?? 0) / 1000.0; // Convert to km
          final duration = (summary['duration'] ?? 0) / 60.0; // Convert to minutes

          if (kDebugMode) {
            print('Real road route: ${distance.toStringAsFixed(2)} km, ${duration.toStringAsFixed(0)} min, ${routePoints.length} points');
          }

          // Extract turn-by-turn instructions
          final instructions = _extractInstructions(route['segments'] ?? []);

          return {
            'route_points': routePoints,
            'distance': distance,
            'duration': duration,
            'polyline': routePoints,
            'polyline_data': geometry,
            'instructions': instructions,
            'fallback': false,
            'source': 'openrouteservice_real_roads',
          };
        }
      }

      throw Exception('No routes found in response');
      
    } catch (e) {
      if (kDebugMode) {
        print('Error with OpenRouteService: $e');
        if (e is DioException) {
          print('Response data: ${e.response?.data}');
          print('Status code: ${e.response?.statusCode}');
        }
      }
      
      // Fall back to enhanced route generation as last resort
      return _generateEnhancedRoadFollowingRoute(waypoints);
    }
  }

  /// Decode polyline string to coordinate points
  static List<LatLng> _decodePolyline(String encoded) {
    List<LatLng> points = [];
    int index = 0, len = encoded.length;
    int lat = 0, lng = 0;

    while (index < len) {
      int b, shift = 0, result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      int dlat = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      lat += dlat;

      shift = 0;
      result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      int dlng = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      lng += dlng;

      points.add(LatLng(lat / 1E6, lng / 1E6));
    }

    return points;
  }

  /// Extract turn-by-turn instructions from OpenRouteService response
  static List<Map<String, dynamic>> _extractInstructions(List<dynamic> segments) {
    final instructions = <Map<String, dynamic>>[];
    
    for (final segment in segments) {
      final steps = segment['steps'] as List<dynamic>? ?? [];
      
      for (final step in steps) {
        final instruction = step['instruction'] ?? 'Continue straight';
        final distance = ((step['distance'] ?? 0) / 1000.0).toStringAsFixed(1);
        final duration = ((step['duration'] ?? 0) / 60.0).toStringAsFixed(0);
        
        instructions.add({
          'instruction': instruction,
          'distance': '${distance} km',
          'duration': '${duration} min',
          'type': step['type'] ?? 'straight',
        });
      }
    }
    
    return instructions;
  }

  /// Enhanced road-following route generation as fallback
  static Map<String, dynamic> _generateEnhancedRoadFollowingRoute(List<LatLng> waypoints) {
    if (kDebugMode) {
      print('Generating enhanced road-following fallback route');
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
      print('Enhanced fallback route: ${totalDistance.toStringAsFixed(2)} km, ${totalDuration.toStringAsFixed(0)} min, ${routePoints.length} points');
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

  /// Calculate road network influence for more realistic paths
  static LatLng _calculateRoadNetworkInfluence(double ratio, double distance) {
    // Simulate following street grid and major roads
    final streetGridSize = 0.001; // ~100m grid
    final majorRoadSpacing = 0.005; // ~500m major roads
    
    // Street grid influence
    final gridInfluenceLat = math.sin(ratio * math.pi * 20) * streetGridSize * 0.3;
    final gridInfluenceLng = math.cos(ratio * math.pi * 15) * streetGridSize * 0.3;
    
    // Major road influence
    final majorInfluenceLat = math.sin(ratio * math.pi * 4) * majorRoadSpacing * 0.5;
    final majorInfluenceLng = math.cos(ratio * math.pi * 3) * majorRoadSpacing * 0.5;
    
    // Scale based on distance (highway vs city roads)
    final scaleFactor = distance > 30 ? 0.5 : 1.0;
    
    return LatLng(
      (gridInfluenceLat + majorInfluenceLat) * scaleFactor,
      (gridInfluenceLng + majorInfluenceLng) * scaleFactor,
    );
  }

  /// Bezier curve interpolation for smooth road curves
  static double _bezierInterpolate(double start, double end, double t) {
    // Cubic bezier with control points for road-like curves
    final controlPoint1 = start + (end - start) * 0.33;
    final controlPoint2 = start + (end - start) * 0.67;
    
    final oneMinusT = 1 - t;
    return oneMinusT * oneMinusT * oneMinusT * start +
           3 * oneMinusT * oneMinusT * t * controlPoint1 +
           3 * oneMinusT * t * t * controlPoint2 +
           t * t * t * end;
  }

  /// Calculate distance using Haversine formula
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

  /// Generate basic turn-by-turn instructions
  static List<Map<String, dynamic>> _generateBasicInstructions(List<LatLng> waypoints) {
    final instructions = <Map<String, dynamic>>[];
    
    for (int i = 0; i < waypoints.length - 1; i++) {
      final start = waypoints[i];
      final end = waypoints[i + 1];
      final distance = _calculateDistance(start, end);
      
      String instruction;
      if (i == 0) {
        instruction = 'Start your journey and head towards destination';
      } else if (i == waypoints.length - 2) {
        instruction = 'Arrive at your destination';
      } else {
        instruction = 'Continue through waypoint ${i}';
      }
      
      instructions.add({
        'instruction': instruction,
        'distance': '${distance.toStringAsFixed(1)} km',
        'duration': '${(distance / 40 * 60).toStringAsFixed(0)} min',
        'type': 'straight',
      });
    }
    
    return instructions;
  }

  /// Encode coordinates to polyline string
  static String _encodePolyline(List<LatLng> points) {
    if (points.isEmpty) return '';
    
    String result = '';
    int prevLat = 0;
    int prevLng = 0;
    
    for (final point in points) {
      final lat = (point.latitude * 1e5).round();
      final lng = (point.longitude * 1e5).round();
      
      result += _encodeNumber(lat - prevLat);
      result += _encodeNumber(lng - prevLng);
      
      prevLat = lat;
      prevLng = lng;
    }
    
    return result;
  }

  /// Encode a number for polyline
  static String _encodeNumber(int num) {
    int sgn = num < 0 ? 1 : 0;
    num = num.abs();
    num = (num << 1) | sgn;
    
    String result = '';
    while (num >= 0x20) {
      result += String.fromCharCode((0x20 | (num & 0x1f)) + 63);
      num >>= 5;
    }
    result += String.fromCharCode(num + 63);
    
    return result;
  }
}
