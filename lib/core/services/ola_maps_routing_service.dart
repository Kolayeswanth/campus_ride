import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
import '../models/bus_route.dart';
import '../../app_config.dart';

/// Service for getting real road routing using Ola Maps Directions API
class OlaMapsRoutingService {
  static final Dio _dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 30),
    receiveTimeout: const Duration(seconds: 60),
    sendTimeout: const Duration(seconds: 30),
    headers: {
      'Accept': 'application/json',
      'Content-Type': 'application/json',
      'X-Request-Id': DateTime.now().millisecondsSinceEpoch.toString(),
      'Access-Control-Allow-Origin': '*',
      'Access-Control-Allow-Methods': 'GET, POST, OPTIONS',
      'Access-Control-Allow-Headers': 'Content-Type, Authorization',
    },
  ));

  /// Get real driving directions using Ola Maps Directions API
  static Future<Map<String, dynamic>> getDirections(List<LatLng> waypoints, {
    String profile = 'driving',
    String vehicleType = 'car',
    bool alternatives = false,
    bool steps = true,
    String geometries = 'polyline6',
  }) async {
    if (waypoints.length < 2) {
      throw ArgumentError('At least 2 waypoints are required');
    }

    if (kDebugMode) {
      print('🚗 Getting Ola Maps directions for ${waypoints.length} waypoints (vehicle: $vehicleType)');
    }

    try {
      // Ola Maps API uses origin/destination format with waypoints
      final origin = '${waypoints.first.latitude},${waypoints.first.longitude}';
      final destination = '${waypoints.last.latitude},${waypoints.last.longitude}';
      
      // Format waypoints if any (exclude first and last)
      String? waypointsParam;
      if (waypoints.length > 2) {
        waypointsParam = waypoints
            .sublist(1, waypoints.length - 1)
            .map((point) => '${point.latitude},${point.longitude}')
            .join('|');
      }

      if (kDebugMode) {
        print('🗺️ Ola Maps request: ${waypoints.length} coordinates');
        print('🔑 API Key: ${AppConfig.olaMapsApiKey.substring(0, 20)}...');
        print('🚦 Profile: $profile, Vehicle: $vehicleType');
        print('📍 Origin: $origin');
        print('🎯 Destination: $destination');
        if (waypointsParam != null) {
          print('🔄 Waypoints: $waypointsParam');
        }
      }

      // Build parameters for Ola Maps Directions API with geometry
      Map<String, dynamic> queryParams = {
        'origin': origin,
        'destination': destination,
        'api_key': AppConfig.olaMapsApiKey,
        'steps': 'true',         // Get turn-by-turn steps
        'overview': 'full',      // Get full route geometry  
        'language': 'en',
        'mode': 'driving',       // Ensure driving mode for road routes
      };
      
      // Add optional parameters only if needed
      if (waypointsParam != null) {
        queryParams['waypoints'] = waypointsParam;
      }
      
      if (alternatives) {
        queryParams['alternatives'] = 'true';
      }

      // Use full directions API to get geometry 
      final response = await _dio.post(
        '${AppConfig.olaMapsDirectionsUrl}/directions',
        queryParameters: queryParams,
        options: Options(
          headers: {
            'Accept': 'application/json',
            'Content-Type': 'application/json',
            'X-Request-Id': DateTime.now().millisecondsSinceEpoch.toString(),
            'X-Correlation-Id': DateTime.now().millisecondsSinceEpoch.toString(),
          },
        ),
      );

      if (kDebugMode) {
        print('📡 Ola Maps response status: ${response.statusCode}');
      }

      if (response.statusCode == 200) {
        final data = response.data;
        
        if (kDebugMode) {
          print('📋 Ola Maps full response: $data');
        }
        
        if (data['routes'] != null && (data['routes'] as List).isNotEmpty) {
          final route = data['routes'][0];
          
          // Extract distance and duration from legs
          double totalDistance = 0.0;
          double totalDuration = 0.0;
          List<LatLng> routePoints = [];
          
          // First, try to get detailed route geometry (polyline)
          bool foundGeometry = false;
          if (route['geometry'] != null) {
            if (kDebugMode) {
              print('📐 Found geometry field, type: ${route['geometry'].runtimeType}');
              if (route['geometry'] is String) {
                print('📐 Geometry string length: ${(route['geometry'] as String).length}');
              }
            }
            
            if (route['geometry'] is String) {
              if (kDebugMode) {
                print('🗜️ Decoding route geometry polyline for detailed road path...');
              }
              
              try {
                routePoints = decodePolyline(route['geometry']);
                foundGeometry = true;
                if (kDebugMode) {
                  print('✅ Decoded ${routePoints.length} detailed route points from geometry');
                }
              } catch (e) {
                if (kDebugMode) {
                  print('⚠️ Failed to decode geometry, falling back to step coordinates: $e');
                }
              }
            } else if (route['geometry'] is Map) {
              // Handle GeoJSON format
              final geom = route['geometry'] as Map;
              if (geom['type'] == 'LineString' && geom['coordinates'] != null) {
                if (kDebugMode) {
                  print('🗺️ Found GeoJSON LineString geometry');
                }
                final coordinates = geom['coordinates'] as List;
                routePoints = coordinates.map((coord) => 
                  LatLng(coord[1].toDouble(), coord[0].toDouble())
                ).toList();
                foundGeometry = true;
                if (kDebugMode) {
                  print('✅ Extracted ${routePoints.length} points from GeoJSON');
                }
              }
            }
          } else {
            if (kDebugMode) {
              print('⚠️ No geometry field found in route response');
            }
          }
          
          // Extract distance, duration, and coordinates from legs/steps
          if (route['legs'] != null && (route['legs'] as List).isNotEmpty) {
            final legs = route['legs'] as List;
            
            for (final leg in legs) {
              if (leg['steps'] != null) {
                final steps = leg['steps'] as List;
                
                for (final step in steps) {
                  // Add distance (in meters)
                  if (step['distance'] != null) {
                    totalDistance += (step['distance'] as num).toDouble();
                  }
                  
                  // Add duration (in seconds) 
                  if (step['duration'] != null) {
                    totalDuration += (step['duration'] as num).toDouble();
                  }
                  
                  // Collect step coordinates if we don't have geometry
                  if (!foundGeometry) {
                    LatLng? stepStart;
                    LatLng? stepEnd;
                    
                    // Get step start and end coordinates
                    if (step['start_location'] != null) {
                      final startLoc = step['start_location'];
                      if (startLoc['lat'] != null && startLoc['lng'] != null) {
                        stepStart = LatLng(
                          (startLoc['lat'] as num).toDouble(),
                          (startLoc['lng'] as num).toDouble(),
                        );
                      }
                    }
                    
                    if (step['end_location'] != null) {
                      final endLoc = step['end_location'];
                      if (endLoc['lat'] != null && endLoc['lng'] != null) {
                        stepEnd = LatLng(
                          (endLoc['lat'] as num).toDouble(),
                          (endLoc['lng'] as num).toDouble(),
                        );
                      }
                    }
                    
                    // Generate intermediate points for better road following
                    if (stepStart != null && stepEnd != null) {
                      final stepDistance = (step['distance'] as num?)?.toDouble() ?? 0.0; // meters
                      final intermediatePoints = _generateIntermediatePoints(stepStart, stepEnd, stepDistance);
                      routePoints.addAll(intermediatePoints);
                    } else if (stepStart != null) {
                      routePoints.add(stepStart);
                    } else if (stepEnd != null) {
                      routePoints.add(stepEnd);
                    }
                  }
                }
              }
            }
          }

          final distanceKm = totalDistance / 1000.0;
          final durationMin = totalDuration / 60.0;

          if (kDebugMode) {
            print('✅ Ola Maps route: ${distanceKm.toStringAsFixed(2)} km, ${durationMin.toStringAsFixed(0)} min, ${routePoints.length} points');
            if (routePoints.isNotEmpty) {
              print('🗺️ First route point: ${routePoints.first}');
              print('🏁 Last route point: ${routePoints.last}');
              
              // Check if we have enough detail for road following
              if (routePoints.length > 50) {
                print('🛣️ Route has detailed geometry (${routePoints.length} points) - good for road following');
              } else {
                print('⚠️ Route has limited points (${routePoints.length}) - may show straight lines between waypoints');
              }
            }
          }

          // Extract turn-by-turn instructions if available
          List<Map<String, dynamic>> instructions = [];
          try {
            if (route['legs'] != null) {
              instructions = _extractInstructions(route['legs']);
            }
          } catch (e) {
            if (kDebugMode) {
              print('⚠️ Error extracting instructions, skipping: $e');
            }
            // Continue without instructions
          }

          return {
            'success': true,
            'source': 'ola_maps_directions',
            'route_points': routePoints,
            'distance_km': distanceKm,
            'duration_minutes': durationMin,
            'instructions': instructions,
            'raw_response': data,
          };
        } else {
          throw Exception('No routes found in Ola Maps response');
        }
      } else {
        throw Exception('Ola Maps API error: ${response.statusCode} - ${response.statusMessage}');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error with Ola Maps: $e');
        if (e is DioException) {
          print('📋 Status Code: ${e.response?.statusCode}');
          print('📋 Response Data: ${e.response?.data}');
          print('📋 Request URL: ${e.requestOptions.uri}');
          print('📋 Request Params: ${e.requestOptions.queryParameters}');
        }
      }
      
      // Fallback to enhanced road-following algorithm if Ola Maps fails
      if (kDebugMode) {
        print('🔄 Falling back to enhanced road-following route');
      }
      return await _generateEnhancedRoadFollowingRoute(waypoints);
    }
  }

  /// Decode Ola Maps polyline (precision 6) to coordinate points
  static List<LatLng> decodePolyline(String encoded) {
    List<LatLng> points = [];
    
    try {
      if (encoded.isEmpty) return points;
      
      int index = 0, len = encoded.length;
      int lat = 0, lng = 0;

      while (index < len) {
        int b, shift = 0, result = 0;
        do {
          if (index >= len) break;
          b = encoded.codeUnitAt(index++) - 63;
          result |= (b & 0x1f) << shift;
          shift += 5;
        } while (b >= 0x20 && index < len);
        int dlat = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
        lat += dlat;

        shift = 0;
        result = 0;
        do {
          if (index >= len) break;
          b = encoded.codeUnitAt(index++) - 63;
          result |= (b & 0x1f) << shift;
          shift += 5;
        } while (b >= 0x20 && index < len);
        int dlng = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
        lng += dlng;

        points.add(LatLng(lat / 1E6, lng / 1E6)); // Ola Maps uses precision 6
      }
    } catch (e) {
      if (kDebugMode) {
        print('⚠️ Error decoding polyline: $e');
      }
    }

    return points;
  }

  /// Decode OpenRouteService geometry coordinates to LatLng points
  static List<LatLng> _decodeOpenRouteServiceGeometry(List<dynamic> geometry) {
    final List<LatLng> points = [];
    
    for (final coord in geometry) {
      if (coord is List && coord.length >= 2) {
        final lng = coord[0] as double;
        final lat = coord[1] as double;
        points.add(LatLng(lat, lng));
      }
    }
    
    if (kDebugMode) {
      print('🛠️ Decoded ${points.length} points from OpenRouteService geometry');
    }
    
    return points;
  }

  /// Extract turn-by-turn instructions from Ola Maps response
  static List<Map<String, dynamic>> _extractInstructions(List<dynamic> legs) {
    final instructions = <Map<String, dynamic>>[];
    
    try {
      for (final leg in legs) {
        final steps = leg['steps'] as List<dynamic>? ?? [];
        
        for (final step in steps) {
          // Ola Maps response format has instructions directly in step
          final instruction = step['instructions'] ?? 'Continue straight';
          final distance = ((step['distance'] as num? ?? 0) / 1000.0).toStringAsFixed(1);
          final duration = ((step['duration'] as num? ?? 0) / 60.0).toStringAsFixed(0);
          final maneuverType = step['maneuver'] ?? 'straight';
          
          instructions.add({
            'instruction': instruction.toString(),
            'distance': '${distance} km',
            'duration': '${duration} min',
            'type': maneuverType.toString(),
            'readable_distance': step['readable_distance']?.toString(),
            'readable_duration': step['readable_duration']?.toString(),
          });
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('⚠️ Error extracting instructions: $e');
      }
    }
    
    return instructions;
  }

  /// Enhanced road-following route generation as fallback when Ola Maps is unavailable
  static Future<Map<String, dynamic>> _generateEnhancedRoadFollowingRoute(List<LatLng> waypoints) async {
    if (kDebugMode) {
      print('🛠️ Trying OpenRouteService API for real road routing');
    }

    try {
      // Use OpenRouteService as fallback for real road directions
      final coordinates = waypoints.map((point) => [point.longitude, point.latitude]).toList();
      
      final response = await _dio.post(
        'https://api.openrouteservice.org/v2/directions/driving-car',
        data: {
          'coordinates': coordinates,
          'format': 'json',
          'instructions': true,
          'preference': 'fastest',
          'units': 'km',
        },
        options: Options(
          headers: {
            'Authorization': 'Bearer ${AppConfig.openRouteServiceApiKey}', 
            'Content-Type': 'application/json',
          },
        ),
      );

      if (response.statusCode == 200 && response.data['routes'] != null) {
        final route = response.data['routes'][0];
        final geometry = route['geometry'];
        final duration = route['summary']['duration']?.toDouble() ?? 0.0; // seconds
        final distance = route['summary']['distance']?.toDouble() ?? 0.0; // meters
        
        // Decode the geometry to get route points (OpenRouteService uses different format)
        final List<LatLng> routePoints = _decodeOpenRouteServiceGeometry(geometry);
        
        if (kDebugMode) {
          print('🛠️ OpenRouteService route: ${(distance / 1000).toStringAsFixed(1)} km, ${(duration / 60).toStringAsFixed(0)} min, ${routePoints.length} points');
        }

        return {
          'success': true,
          'source': 'openrouteservice_fallback',
          'route_points': routePoints,
          'distance_km': distance / 1000,
          'duration_minutes': duration / 60,
          'instructions': route['segments']?[0]?['steps'] ?? [],
          'raw_response': response.data,
        };
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ OpenRouteService also failed: $e');
        print('🛠️ Generating enhanced road-following approximation');
      }
    }

    final List<LatLng> routePoints = [];
    double totalDistance = 0;
    double totalDuration = 0;

    for (int i = 0; i < waypoints.length - 1; i++) {
      final start = waypoints[i];
      final end = waypoints[i + 1];
      
      // Calculate direct distance
      final directDistance = _calculateDistance(start, end);
      
      // Generate intermediate points simulating road curvature
      final segmentPoints = _generateRoadSegment(start, end, directDistance);
      
      // Add points (avoid duplicating waypoints)
      if (i == 0) {
        routePoints.addAll(segmentPoints);
      } else {
        routePoints.addAll(segmentPoints.skip(1));
      }
      
      // Estimate road distance (typically 1.2-1.5x direct distance)
      final roadDistance = directDistance * 1.3;
      totalDistance += roadDistance;
      
      // Estimate duration (average 60 km/h in urban areas)
      totalDuration += (roadDistance / 60.0) * 60; // minutes
    }

    if (kDebugMode) {
      print('🛠️ Enhanced fallback route: ${totalDistance.toStringAsFixed(2)} km, ${totalDuration.toStringAsFixed(0)} min, ${routePoints.length} points');
    }

    return {
      'success': true,
      'source': 'enhanced_road_following_fallback',
      'route_points': routePoints,
      'distance_km': totalDistance,
      'duration_minutes': totalDuration,
      'instructions': _generateBasicInstructions(waypoints),
    };
  }

  /// Generate intermediate points between two coordinates simulating road curvature
  static List<LatLng> _generateRoadSegment(LatLng start, LatLng end, double distanceKm) {
    final points = <LatLng>[start];
    
    // Number of intermediate points based on distance
    final numPoints = math.max(5, (distanceKm * 2).round());
    
    for (int i = 1; i < numPoints; i++) {
      final progress = i / numPoints;
      
      // Linear interpolation with slight curvature simulation
      final lat = start.latitude + (end.latitude - start.latitude) * progress;
      final lng = start.longitude + (end.longitude - start.longitude) * progress;
      
      // Add slight curvature to simulate roads (not perfectly straight)
      final curvature = math.sin(progress * math.pi) * 0.002; // Small deviation
      final random = math.Random();
      final curvedLat = lat + curvature * (random.nextDouble() - 0.5);
      final curvedLng = lng + curvature * (random.nextDouble() - 0.5);
      
      points.add(LatLng(curvedLat, curvedLng));
    }
    
    points.add(end);
    return points;
  }

  /// Calculate distance between two points using Haversine formula
  static double _calculateDistance(LatLng start, LatLng end) {
    const double earthRadius = 6371; // km
    
    final dLat = _degreesToRadians(end.latitude - start.latitude);
    final dLng = _degreesToRadians(end.longitude - start.longitude);
    
    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_degreesToRadians(start.latitude)) *
        math.cos(_degreesToRadians(end.latitude)) *
        math.sin(dLng / 2) * math.sin(dLng / 2);
    
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    
    return earthRadius * c;
  }

  static double _degreesToRadians(double degrees) {
    return degrees * (math.pi / 180);
  }

  /// Generate basic instructions for fallback routing
  static List<Map<String, dynamic>> _generateBasicInstructions(List<LatLng> waypoints) {
    final instructions = <Map<String, dynamic>>[];
    
    for (int i = 0; i < waypoints.length - 1; i++) {
      final distance = _calculateDistance(waypoints[i], waypoints[i + 1]);
      final duration = (distance / 60.0) * 60; // Assume 60 km/h average speed
      
      String instruction;
      if (i == 0) {
        instruction = 'Head towards destination';
      } else if (i == waypoints.length - 2) {
        instruction = 'Arrive at destination';
      } else {
        instruction = 'Continue towards destination';
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

  /// Generate intermediate points between two coordinates based on step distance
  /// Creates more points for longer segments to improve road-following visualization
  static List<LatLng> _generateIntermediatePoints(LatLng start, LatLng end, double distanceMeters) {
    final points = <LatLng>[start];
    
    // Calculate number of intermediate points based on distance
    // More points for longer segments (every 50 meters for detailed routes)
    final numIntermediatePoints = math.max(0, (distanceMeters / 50.0).round() - 1);
    
    if (numIntermediatePoints > 0 && numIntermediatePoints <= 20) { // Cap at 20 points per step
      final latDiff = end.latitude - start.latitude;
      final lngDiff = end.longitude - start.longitude;
      
      for (int i = 1; i <= numIntermediatePoints; i++) {
        final ratio = i / (numIntermediatePoints + 1);
        
        // Add some curvature variation to simulate road geometry
        final curveFactor = math.sin(ratio * math.pi) * 0.0001; // Small variation
        
        final intermediateLat = start.latitude + (latDiff * ratio) + curveFactor;
        final intermediateLng = start.longitude + (lngDiff * ratio) + curveFactor;
        
        points.add(LatLng(intermediateLat, intermediateLng));
      }
    }
    
    points.add(end);
    return points;
  }
}