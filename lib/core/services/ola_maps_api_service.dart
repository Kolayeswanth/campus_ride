import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:dio/dio.dart';
import '../models/bus_route.dart';

/// Service for Ola Maps API integration
/// 
/// This service provides:
/// - Places API: Search for places, autocomplete
/// - Directions API: Get routes between points
/// - Geocoding API: Convert addresses to coordinates
/// - Static Maps API: Generate static map images
/// - Distance Matrix API: Calculate distances and durations
class OlaMapsApiService {
  static const String _baseUrl = 'https://api.olamaps.io';
  static final String _apiKey = dotenv.env['OLA_MAPS_API_KEY'] ?? '';
  
  static final Dio _dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 15),
    receiveTimeout: const Duration(seconds: 15),
    headers: {
      'Accept': 'application/json',
      'Content-Type': 'application/json',
    },
  ));

  // API Endpoints
  static const String _placesEndpoint = '/places/v1';
  static const String _directionsEndpoint = '/routing/v1';
  static const String _geocodingEndpoint = '/places/v1';
  static const String _distanceMatrixEndpoint = '/distancematrix/v1';
  static const String _staticMapEndpoint = '/staticmap/v1';

  /// Check if the service is properly configured
  static bool get isConfigured => _apiKey.isNotEmpty && (_apiKey.startsWith('u8') || _apiKey.startsWith('U7'));

  /// Get the current API key status
  static String get apiKeyStatus {
    if (_apiKey.isEmpty) return 'Not configured';
    if (_apiKey.startsWith('u8') || _apiKey.startsWith('U7')) return 'Configured';
    return 'Invalid format';
  }

  /// Test API connectivity
  static Future<bool> testConnection() async {
    if (!isConfigured) return false;
    
    try {
      // Test with a simple places search
      final response = await _dio.get(
        '$_baseUrl$_placesEndpoint/search',
        queryParameters: {
          'api_key': _apiKey,
          'input': 'India',
          'location': '28.6139,77.2090', // Delhi coordinates
          'radius': '50000',
        },
      );
      
      return response.statusCode == 200;
    } catch (e) {
      if (kDebugMode) {
        print('Ola Maps API test failed: $e');
      }
      return false;
    }
  }

  /// Places API - Search for places
  /// 
  /// [input] The search query
  /// [location] Bias location as "lat,lng"
  /// [radius] Search radius in meters
  /// [types] Place types to filter (e.g., 'establishment', 'geocode')
  static Future<List<Map<String, dynamic>>> searchPlaces({
    required String input,
    String? location,
    int radius = 50000,
    String? types,
    String language = 'en',
  }) async {
    if (!isConfigured || input.trim().isEmpty) {
      return [];
    }

    try {
      final queryParams = {
        'api_key': _apiKey,
        'input': input.trim(),
        'language': language,
      };

      if (location != null) {
        queryParams['location'] = location;
        queryParams['radius'] = radius.toString();
      }

      if (types != null) {
        queryParams['types'] = types;
      }

      if (kDebugMode) {
        print('Ola Maps Places search: $input');
      }

      final response = await _dio.get(
        '$_baseUrl$_placesEndpoint/search',
        queryParameters: queryParams,
      );

      if (response.statusCode == 200 && response.data != null) {
        final data = response.data;
        if (data['predictions'] != null) {
          return List<Map<String, dynamic>>.from(data['predictions']);
        }
      }

      return [];
    } catch (e) {
      if (kDebugMode) {
        print('Error in Ola Maps places search: $e');
      }
      return [];
    }
  }

  /// Places API - Get place details
  /// 
  /// [placeId] The place ID from search results
  static Future<Map<String, dynamic>?> getPlaceDetails(String placeId) async {
    if (!isConfigured || placeId.isEmpty) {
      return null;
    }

    try {
      final response = await _dio.get(
        '$_baseUrl$_placesEndpoint/details',
        queryParameters: {
          'api_key': _apiKey,
          'place_id': placeId,
        },
      );

      if (response.statusCode == 200 && response.data != null) {
        return response.data['result'] as Map<String, dynamic>?;
      }

      return null;
    } catch (e) {
      if (kDebugMode) {
        print('Error getting Ola Maps place details: $e');
      }
      return null;
    }
  }

  /// Directions API - Get route between points
  /// 
  /// [origin] Starting point as "lat,lng"
  /// [destination] End point as "lat,lng"
  /// [waypoints] Optional waypoints as list of "lat,lng"
  /// [mode] Travel mode: driving, walking, transit
  static Future<Map<String, dynamic>?> getDirections({
    required String origin,
    required String destination,
    List<String>? waypoints,
    String mode = 'driving',
    bool alternatives = false,
    String language = 'en',
  }) async {
    if (!isConfigured) {
      return null;
    }

    try {
      final queryParams = {
        'api_key': _apiKey,
        'origin': origin,
        'destination': destination,
        'mode': mode,
        'alternatives': alternatives.toString(),
        'language': language,
      };

      if (waypoints != null && waypoints.isNotEmpty) {
        queryParams['waypoints'] = waypoints.join('|');
      }

      if (kDebugMode) {
        print('Ola Maps Directions: $origin to $destination');
      }

      final response = await _dio.get(
        '$_baseUrl$_directionsEndpoint/directions',
        queryParameters: queryParams,
      );

      if (response.statusCode == 200 && response.data != null) {
        return response.data as Map<String, dynamic>;
      }

      return null;
    } catch (e) {
      if (kDebugMode) {
        print('Error getting Ola Maps directions: $e');
      }
      return null;
    }
  }

  /// Geocoding API - Convert address to coordinates
  /// 
  /// [address] The address to geocode
  /// [region] Region code for better results (e.g., 'IN')
  static Future<List<Map<String, dynamic>>> geocode({
    required String address,
    String? region,
    String language = 'en',
  }) async {
    if (!isConfigured || address.trim().isEmpty) {
      return [];
    }

    try {
      final queryParams = {
        'api_key': _apiKey,
        'address': address.trim(),
        'language': language,
      };

      if (region != null) {
        queryParams['region'] = region;
      }

      final response = await _dio.get(
        '$_baseUrl$_geocodingEndpoint/geocode',
        queryParameters: queryParams,
      );

      if (response.statusCode == 200 && response.data != null) {
        final results = response.data['results'];
        if (results != null) {
          return List<Map<String, dynamic>>.from(results);
        }
      }

      return [];
    } catch (e) {
      if (kDebugMode) {
        print('Error in Ola Maps geocoding: $e');
      }
      return [];
    }
  }

  /// Reverse Geocoding API - Convert coordinates to address
  /// 
  /// [location] Coordinates as "lat,lng"
  /// [result_type] Type of result ('street_address', 'route', 'intersection', etc.)
  static Future<List<Map<String, dynamic>>> reverseGeocode({
    required String location,
    String? resultType,
    String language = 'en',
  }) async {
    if (!isConfigured) {
      return [];
    }

    try {
      final queryParams = {
        'api_key': _apiKey,
        'latlng': location,
        'language': language,
      };

      if (resultType != null) {
        queryParams['result_type'] = resultType;
      }

      final response = await _dio.get(
        '$_baseUrl$_geocodingEndpoint/reverse_geocode',
        queryParameters: queryParams,
      );

      if (response.statusCode == 200 && response.data != null) {
        final results = response.data['results'];
        if (results != null) {
          return List<Map<String, dynamic>>.from(results);
        }
      }

      return [];
    } catch (e) {
      if (kDebugMode) {
        print('Error in Ola Maps reverse geocoding: $e');
      }
      return [];
    }
  }

  /// Distance Matrix API - Calculate distances and durations
  /// 
  /// [origins] List of origin points as "lat,lng"
  /// [destinations] List of destination points as "lat,lng"
  /// [mode] Travel mode: driving, walking, transit
  static Future<Map<String, dynamic>?> getDistanceMatrix({
    required List<String> origins,
    required List<String> destinations,
    String mode = 'driving',
    String units = 'metric',
    String language = 'en',
  }) async {
    if (!isConfigured || origins.isEmpty || destinations.isEmpty) {
      return null;
    }

    try {
      final queryParams = {
        'api_key': _apiKey,
        'origins': origins.join('|'),
        'destinations': destinations.join('|'),
        'mode': mode,
        'units': units,
        'language': language,
      };

      final response = await _dio.get(
        '$_baseUrl$_distanceMatrixEndpoint/distance_matrix',
        queryParameters: queryParams,
      );

      if (response.statusCode == 200 && response.data != null) {
        return response.data as Map<String, dynamic>;
      }

      return null;
    } catch (e) {
      if (kDebugMode) {
        print('Error getting Ola Maps distance matrix: $e');
      }
      return null;
    }
  }

  /// Static Maps API - Generate static map image URL
  /// 
  /// [center] Center point as "lat,lng"
  /// [zoom] Zoom level (1-20)
  /// [size] Image size as "widthxheight" (max 640x640)
  /// [maptype] Map type: roadmap, satellite, terrain, hybrid
  static String getStaticMapUrl({
    required String center,
    int zoom = 15,
    String size = '400x400',
    String maptype = 'roadmap',
    List<String>? markers,
    String? path,
  }) {
    if (!isConfigured) {
      return '';
    }

    final queryParams = {
      'api_key': _apiKey,
      'center': center,
      'zoom': zoom.toString(),
      'size': size,
      'maptype': maptype,
    };

    if (markers != null && markers.isNotEmpty) {
      queryParams['markers'] = markers.join('|');
    }

    if (path != null) {
      queryParams['path'] = path;
    }

    final uri = Uri.parse('$_baseUrl$_staticMapEndpoint/map').replace(
      queryParameters: queryParams,
    );

    return uri.toString();
  }

  /// Helper method to convert LatLng to string format
  static String latLngToString(LatLng latLng) {
    return '${latLng.latitude},${latLng.longitude}';
  }

  /// Helper method to parse LatLng from Ola Maps response
  static LatLng? parseLatLngFromResponse(Map<String, dynamic> location) {
    try {
      final lat = location['lat'] ?? location['latitude'];
      final lng = location['lng'] ?? location['longitude'];
      
      if (lat != null && lng != null) {
        return LatLng(
          double.parse(lat.toString()),
          double.parse(lng.toString()),
        );
      }
      
      return null;
    } catch (e) {
      if (kDebugMode) {
        print('Error parsing LatLng: $e');
      }
      return null;
    }
  }

  /// Helper method to format duration from seconds
  static String formatDuration(int seconds) {
    final hours = seconds ~/ 3600;
    final minutes = (seconds % 3600) ~/ 60;
    
    if (hours > 0) {
      return '${hours}h ${minutes}m';
    } else {
      return '${minutes}m';
    }
  }

  /// Helper method to format distance from meters
  static String formatDistance(int meters) {
    if (meters >= 1000) {
      final km = meters / 1000;
      return '${km.toStringAsFixed(1)} km';
    } else {
      return '${meters} m';
    }
  }
}
