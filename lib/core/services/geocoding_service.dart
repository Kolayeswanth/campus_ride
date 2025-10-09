import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:dio/dio.dart';
import '../models/address.dart';

/// Service for geocoding and reverse geocoding using LocationIQ API
/// 
/// This service provides:
/// - Reverse geocoding: Convert coordinates to addresses
/// - Forward geocoding: Convert addresses to coordinates
/// - Place search with detailed address breakdown
class GeocodingService {
  static const String _baseUrl = 'https://us1.locationiq.com/v1';
  static final String _apiKey = dotenv.env['LOCATIONIQ_API_KEY'] ?? '';
  
  static final Dio _dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 10),
    headers: {
      'Accept': 'application/json',
      'Content-Type': 'application/json',
    },
  ));

  /// Convert coordinates to human-readable address
  /// 
  /// [latitude] and [longitude] are the coordinates to reverse geocode
  /// [includeAddressDetails] whether to include detailed address breakdown
  /// [normalizeAddress] makes parsing easier by returning predictable elements
  /// [language] preferred language for the response
  static Future<Address?> reverseGeocode({
    required double latitude,
    required double longitude,
    bool includeAddressDetails = true,
    bool normalizeAddress = true,
    String language = 'en',
  }) async {
    if (_apiKey.isEmpty) {
      if (kDebugMode) {
        print('LocationIQ API key not found in environment');
      }
      return null;
    }

    try {
      final queryParams = {
        'key': _apiKey,
        'lat': latitude.toString(),
        'lon': longitude.toString(),
        'format': 'json',
        'addressdetails': includeAddressDetails ? '1' : '0',
        'normalizeaddress': normalizeAddress ? '1' : '0',
        'accept-language': language,
        'statecode': '1', // Include state codes
      };

      if (kDebugMode) {
        print('Reverse geocoding: $latitude, $longitude');
      }

      final response = await _dio.get(
        '$_baseUrl/reverse',
        queryParameters: queryParams,
      );

      if (response.statusCode == 200 && response.data != null) {
        final data = response.data as Map<String, dynamic>;
        return Address.fromLocationIQ(data);
      } else {
        if (kDebugMode) {
          print('LocationIQ API error: ${response.statusCode} - ${response.data}');
        }
        return null;
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error in reverse geocoding: $e');
      }
      return null;
    }
  }

  /// Convert address string to coordinates
  /// 
  /// [query] the address or place name to search for
  /// [limit] maximum number of results to return
  /// [countryCode] limit search to specific country (e.g., 'IN' for India)
  /// [viewbox] limit search to specific bounding box
  /// [bounded] restrict results to viewbox area
  static Future<List<Address>> forwardGeocode({
    required String query,
    int limit = 5,
    String? countryCode,
    String? viewbox,
    bool bounded = false,
    String language = 'en',
  }) async {
    if (_apiKey.isEmpty || query.trim().isEmpty) {
      return [];
    }

    try {
      final queryParams = {
        'key': _apiKey,
        'q': query.trim(),
        'format': 'json',
        'addressdetails': '1',
        'normalizeaddress': '1',
        'limit': limit.toString(),
        'accept-language': language,
        'statecode': '1',
      };

      if (countryCode != null) {
        queryParams['countrycodes'] = countryCode;
      }

      if (viewbox != null) {
        queryParams['viewbox'] = viewbox;
        queryParams['bounded'] = bounded ? '1' : '0';
      }

      if (kDebugMode) {
        print('Forward geocoding: $query');
      }

      final response = await _dio.get(
        '$_baseUrl/search',
        queryParameters: queryParams,
      );

      if (response.statusCode == 200 && response.data != null) {
        final data = response.data as List<dynamic>;
        return data
            .map((item) => Address.fromLocationIQ(item as Map<String, dynamic>))
            .toList();
      } else {
        if (kDebugMode) {
          print('LocationIQ API error: ${response.statusCode} - ${response.data}');
        }
        return [];
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error in forward geocoding: $e');
      }
      return [];
    }
  }

  /// Search for places near a specific location
  /// 
  /// [query] the place name or type to search for
  /// [latitude] and [longitude] center point for proximity search
  /// [radius] search radius in kilometers
  static Future<List<Address>> searchNearby({
    required String query,
    required double latitude,
    required double longitude,
    double radius = 10.0,
    int limit = 10,
  }) async {
    // Calculate viewbox for the search area
    // Approximate: 1 degree ≈ 111 km
    final radiusDegrees = radius / 111.0;
    final minLat = latitude - radiusDegrees;
    final maxLat = latitude + radiusDegrees;
    final minLon = longitude - radiusDegrees;
    final maxLon = longitude + radiusDegrees;
    
    final viewbox = '$minLon,$minLat,$maxLon,$maxLat';
    
    return forwardGeocode(
      query: query,
      limit: limit,
      viewbox: viewbox,
      bounded: true,
    );
  }

  /// Get detailed address information for a place ID
  /// 
  /// [placeId] the LocationIQ place ID
  static Future<Address?> getPlaceDetails(String placeId) async {
    if (_apiKey.isEmpty || placeId.isEmpty) {
      return null;
    }

    try {
      final queryParams = {
        'key': _apiKey,
        'place_id': placeId,
        'format': 'json',
        'addressdetails': '1',
        'normalizeaddress': '1',
      };

      final response = await _dio.get(
        '$_baseUrl/details',
        queryParameters: queryParams,
      );

      if (response.statusCode == 200 && response.data != null) {
        final data = response.data as Map<String, dynamic>;
        return Address.fromLocationIQ(data);
      } else {
        if (kDebugMode) {
          print('LocationIQ API error: ${response.statusCode} - ${response.data}');
        }
        return null;
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error getting place details: $e');
      }
      return null;
    }
  }

  /// Batch reverse geocoding for multiple coordinates
  /// 
  /// [coordinates] list of [latitude, longitude] pairs
  static Future<List<Address?>> batchReverseGeocode(
    List<List<double>> coordinates,
  ) async {
    final results = <Address?>[];
    
    // LocationIQ doesn't support batch requests in free tier
    // So we'll make individual requests with a small delay
    for (final coord in coordinates) {
      if (coord.length >= 2) {
        final address = await reverseGeocode(
          latitude: coord[0],
          longitude: coord[1],
        );
        results.add(address);
        
        // Small delay to respect rate limits
        await Future.delayed(const Duration(milliseconds: 100));
      } else {
        results.add(null);
      }
    }
    
    return results;
  }

  /// Check if the service is properly configured
  static bool get isConfigured => _apiKey.isNotEmpty;

  /// Get the current API key status
  static String get apiKeyStatus {
    if (_apiKey.isEmpty) return 'Not configured';
    if (_apiKey.startsWith('pk.')) return 'Configured';
    return 'Invalid format';
  }
}
