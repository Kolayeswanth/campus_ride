import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../models/bus_route.dart';

/// Enhanced location autocomplete service using multiple geocoding providers
/// Provides accurate location suggestions without fallback data
class LocationAutocompleteService {
  static String? _locationiqKey;
  static const String _locationiqUrl = 'https://us1.locationiq.com/v1';
  static const String _nominatimUrl = 'https://nominatim.openstreetmap.org';
  
  // Dedicated Dio client for location services
  static final Dio _dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 10),
    headers: {
      'Accept': 'application/json',
      'User-Agent': 'CampusRide/1.0.0 (Campus Bus Tracking)',
    },
    followRedirects: true,
  ));
  
  static String get locationiqKey {
    _locationiqKey ??= dotenv.env['LOCATIONIQ_API_KEY'];
    if (_locationiqKey == null || _locationiqKey!.isEmpty) {
      throw Exception('LOCATIONIQ_API_KEY not found in environment variables');
    }
    return _locationiqKey!;
  }

  /// Search for locations using multiple geocoding services
  /// Returns accurate results only, no fallback data
  static Future<List<LocationSuggestion>> searchLocations(
    String query, {
    LatLng? biasLocation,
    String? countryCode = 'IN',
    String? state = 'Andhra Pradesh',
    int maxResults = 8,
  }) async {
    if (query.trim().length < 3) {
      return [];
    }

    final List<LocationSuggestion> allResults = [];

    try {
      // Use only Nominatim for now (LocationIQ has API issues)
      if (kDebugMode) {
        print('Using Nominatim for location search (LocationIQ disabled due to API issues)');
      }
      
      final nominatimResults = await _searchNominatim(
        query,
        biasLocation: biasLocation,
        countryCode: countryCode,
        state: state,
        maxResults: maxResults,
      );
      allResults.addAll(nominatimResults);

      // Remove duplicates based on coordinates (within 100m radius)
      final uniqueResults = _removeDuplicates(allResults);
      
      // Sort by relevance and distance from bias location
      _sortResultsByRelevance(uniqueResults, query, biasLocation);
      
      return uniqueResults.take(maxResults).toList();
    } catch (e) {
      if (kDebugMode) {
        print('Error in location search: $e');
      }
      return [];
    }
  }

  /// Search using LocationIQ API
  static Future<List<LocationSuggestion>> _searchLocationIQ(
    String query, {
    LatLng? biasLocation,
    String? countryCode,
    String? state,
    int maxResults = 8,
  }) async {
    try {
      String enhancedQuery = query.trim();
      if (state != null && !enhancedQuery.toLowerCase().contains(state.toLowerCase())) {
        enhancedQuery = '$enhancedQuery, $state';
      }
      if (countryCode == 'IN') {
        enhancedQuery = '$enhancedQuery, India';
      }

      final queryParams = {
        'key': locationiqKey,
        'q': enhancedQuery,
        'format': 'json',
        'addressdetails': '1',
        'limit': maxResults.toString(),
        'countrycodes': countryCode?.toLowerCase(),
        'accept-language': 'en',
        'extratags': '1',
        'namedetails': '1',
      };

      // Add location bias if provided
      if (biasLocation != null) {
        final viewbox = _calculateViewbox(biasLocation, 50.0); // 50km radius
        queryParams['viewbox'] = viewbox;
        queryParams['bounded'] = '1';
      }

      final response = await _dio.get(
        '$_locationiqUrl/search',
        queryParameters: queryParams,
      );

      if (response.statusCode == 200 && response.data != null) {
        final data = response.data as List<dynamic>;
        final List<LocationSuggestion> results = [];

        for (final item in data) {
          final itemMap = item as Map<String, dynamic>;
          final suggestion = _parseLocationIQResult(itemMap, state);
          if (suggestion != null) {
            results.add(suggestion);
          }
        }

        return results;
      }
    } catch (e) {
      if (kDebugMode) {
        print('LocationIQ search error: $e');
      }
    }
    return [];
  }

  /// Search using Nominatim API (OpenStreetMap)
  static Future<List<LocationSuggestion>> _searchNominatim(
    String query, {
    LatLng? biasLocation,
    String? countryCode,
    String? state,
    int maxResults = 8,
  }) async {
    try {
      String enhancedQuery = query.trim();
      if (state != null && !enhancedQuery.toLowerCase().contains(state.toLowerCase())) {
        enhancedQuery = '$enhancedQuery, $state';
      }
      if (countryCode == 'IN') {
        enhancedQuery = '$enhancedQuery, India';
      }

      final queryParams = {
        'q': enhancedQuery,
        'format': 'json',
        'addressdetails': '1',
        'limit': maxResults.toString(),
        'countrycodes': countryCode?.toLowerCase(),
        'accept-language': 'en',
        'extratags': '1',
        'namedetails': '1',
      };

      // Add location bias if provided
      if (biasLocation != null) {
        final viewbox = _calculateViewbox(biasLocation, 50.0);
        queryParams['viewbox'] = viewbox;
        queryParams['bounded'] = '1';
      }

      final response = await _dio.get(
        _nominatimUrl + '/search',
        queryParameters: queryParams,
      );

      if (response.statusCode == 200 && response.data != null) {
        final data = response.data as List<dynamic>;
        final List<LocationSuggestion> results = [];

        for (final item in data) {
          final itemMap = item as Map<String, dynamic>;
          final suggestion = _parseNominatimResult(itemMap, state);
          if (suggestion != null) {
            results.add(suggestion);
          }
        }

        return results;
      }
    } catch (e) {
      if (kDebugMode) {
        print('Nominatim search error: $e');
      }
    }
    return [];
  }

  /// Parse LocationIQ search result
  static LocationSuggestion? _parseLocationIQResult(
    Map<String, dynamic> item,
    String? expectedState,
  ) {
    try {
      final lat = double.tryParse(item['lat']?.toString() ?? '');
      final lng = double.tryParse(item['lon']?.toString() ?? '');
      
      if (lat == null || lng == null) return null;

      final address = item['address'] as Map<String, dynamic>? ?? {};
      final state = address['state'] as String?;
      
      // Filter by state if specified
      if (expectedState != null && state != null) {
        if (!state.toLowerCase().contains(expectedState.toLowerCase())) {
          return null;
        }
      }

      final displayName = item['display_name']?.toString() ?? '';
      final name = _extractPrimaryName(item);
      final category = _determineLocationType(item);

      return LocationSuggestion(
        name: name,
        displayName: displayName,
        coordinates: LatLng(lat, lng),
        category: category,
        address: _buildAddressString(address),
        source: 'LocationIQ',
      );
    } catch (e) {
      if (kDebugMode) {
        print('Error parsing LocationIQ result: $e');
      }
      return null;
    }
  }

  /// Parse Nominatim search result
  static LocationSuggestion? _parseNominatimResult(
    Map<String, dynamic> item,
    String? expectedState,
  ) {
    try {
      final lat = double.tryParse(item['lat']?.toString() ?? '');
      final lng = double.tryParse(item['lon']?.toString() ?? '');
      
      if (lat == null || lng == null) return null;

      final address = item['address'] as Map<String, dynamic>? ?? {};
      final state = address['state'] as String?;
      
      // Filter by state if specified
      if (expectedState != null && state != null) {
        if (!state.toLowerCase().contains(expectedState.toLowerCase())) {
          return null;
        }
      }

      final displayName = item['display_name']?.toString() ?? '';
      final name = _extractPrimaryName(item);
      final category = _determineLocationType(item);

      return LocationSuggestion(
        name: name,
        displayName: displayName,
        coordinates: LatLng(lat, lng),
        category: category,
        address: _buildAddressString(address),
        source: 'Nominatim',
      );
    } catch (e) {
      if (kDebugMode) {
        print('Error parsing Nominatim result: $e');
      }
      return null;
    }
  }

  /// Extract primary name from search result
  static String _extractPrimaryName(Map<String, dynamic> item) {
    final nameDetails = item['namedetails'] as Map<String, dynamic>?;
    if (nameDetails != null) {
      final name = nameDetails['name:en'] ?? nameDetails['name'];
      if (name != null && name.toString().isNotEmpty) {
        return name.toString();
      }
    }

    final address = item['address'] as Map<String, dynamic>? ?? {};
    
    // Try different address components in order of preference
    final components = [
      'amenity', 'shop', 'building', 'tourism', 'leisure',
      'university', 'college', 'school', 'hospital',
      'village', 'town', 'city', 'suburb', 'neighbourhood',
      'road', 'house_number'
    ];

    for (final component in components) {
      final value = address[component]?.toString();
      if (value != null && value.isNotEmpty) {
        return value;
      }
    }

    // Fallback to display name first part
    final displayName = item['display_name']?.toString() ?? '';
    final firstPart = displayName.split(',').first.trim();
    return firstPart.isNotEmpty ? firstPart : 'Unknown location';
  }

  /// Determine location type/category
  static LocationCategory _determineLocationType(Map<String, dynamic> item) {
    final cls = item['class']?.toString().toLowerCase() ?? '';
    final type = item['type']?.toString().toLowerCase() ?? '';
    final address = item['address'] as Map<String, dynamic>? ?? {};

    if (address.containsKey('university') || address.containsKey('college') || 
        cls == 'amenity' && (type == 'university' || type == 'college')) {
      return LocationCategory.educational;
    }

    if (cls == 'railway' || type.contains('station') || 
        address.containsKey('railway') || 
        item['display_name']?.toString().toLowerCase().contains('station') == true) {
      return LocationCategory.transport;
    }

    if (cls == 'amenity' && (type == 'hospital' || type == 'clinic')) {
      return LocationCategory.medical;
    }

    if (cls == 'shop' || cls == 'amenity' && (type == 'restaurant' || type == 'cafe')) {
      return LocationCategory.commercial;
    }

    if (cls == 'place' || address.containsKey('city') || address.containsKey('town') || 
        address.containsKey('village')) {
      return LocationCategory.place;
    }

    return LocationCategory.general;
  }

  /// Build address string from components
  static String _buildAddressString(Map<String, dynamic> address) {
    final parts = <String>[];
    
    // Add relevant address components in logical order
    final components = [
      'house_number', 'road', 'neighbourhood', 'suburb', 
      'village', 'town', 'city', 'state', 'postcode'
    ];

    for (final component in components) {
      final value = address[component]?.toString();
      if (value != null && value.isNotEmpty && !parts.contains(value)) {
        parts.add(value);
      }
    }

    return parts.join(', ');
  }

  /// Calculate viewbox for location bias
  static String _calculateViewbox(LatLng center, double radiusKm) {
    const double earthRadiusKm = 6371.0;
    final double deltaLat = (radiusKm / earthRadiusKm) * (180.0 / 3.14159);
    final double deltaLng = deltaLat / math.cos(center.latitude * 3.14159 / 180.0);

    final double minLat = center.latitude - deltaLat;
    final double maxLat = center.latitude + deltaLat;
    final double minLng = center.longitude - deltaLng;
    final double maxLng = center.longitude + deltaLng;

    return '$minLng,$minLat,$maxLng,$maxLat';
  }

  /// Remove duplicate results based on coordinates
  static List<LocationSuggestion> _removeDuplicates(List<LocationSuggestion> results) {
    final unique = <LocationSuggestion>[];
    
    for (final result in results) {
      bool isDuplicate = false;
      
      for (final existing in unique) {
        final distance = _calculateDistance(
          result.coordinates, 
          existing.coordinates,
        );
        
        // Consider locations within 100 meters as duplicates
        if (distance < 0.1) {
          isDuplicate = true;
          break;
        }
      }
      
      if (!isDuplicate) {
        unique.add(result);
      }
    }
    
    return unique;
  }

  /// Sort results by relevance and distance
  static void _sortResultsByRelevance(
    List<LocationSuggestion> results, 
    String query, 
    LatLng? biasLocation,
  ) {
    results.sort((a, b) {
      // Calculate relevance score based on name match
      final aScore = _calculateRelevanceScore(a.name, query);
      final bScore = _calculateRelevanceScore(b.name, query);
      
      if (aScore != bScore) {
        return bScore.compareTo(aScore); // Higher score first
      }
      
      // If relevance is equal, sort by distance from bias location
      if (biasLocation != null) {
        final aDistance = _calculateDistance(a.coordinates, biasLocation);
        final bDistance = _calculateDistance(b.coordinates, biasLocation);
        return aDistance.compareTo(bDistance); // Closer first
      }
      
      return 0;
    });
  }

  /// Calculate relevance score for name matching
  static int _calculateRelevanceScore(String name, String query) {
    final nameLower = name.toLowerCase();
    final queryLower = query.toLowerCase();
    
    if (nameLower == queryLower) return 100;
    if (nameLower.startsWith(queryLower)) return 80;
    if (nameLower.contains(queryLower)) return 60;
    if (_fuzzyMatch(nameLower, queryLower)) return 40;
    
    return 0;
  }

  /// Simple fuzzy matching
  static bool _fuzzyMatch(String text, String pattern) {
    final words = pattern.split(' ');
    return words.every((word) => text.contains(word));
  }

  /// Calculate distance between two coordinates in kilometers
  static double _calculateDistance(LatLng point1, LatLng point2) {
    const double earthRadiusKm = 6371.0;
    final double dLat = (point2.latitude - point1.latitude) * (3.14159 / 180.0);
    final double dLng = (point2.longitude - point1.longitude) * (3.14159 / 180.0);
    
    final double a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(point1.latitude * (3.14159 / 180.0)) *
        math.cos(point2.latitude * (3.14159 / 180.0)) *
        math.sin(dLng / 2) * math.sin(dLng / 2);
    
    final double c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return earthRadiusKm * c;
  }
}

/// Location suggestion model
class LocationSuggestion {
  final String name;
  final String displayName;
  final LatLng coordinates;
  final LocationCategory category;
  final String address;
  final String source;

  const LocationSuggestion({
    required this.name,
    required this.displayName,
    required this.coordinates,
    required this.category,
    required this.address,
    required this.source,
  });

  /// Convert to map for easy integration with existing code
  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'display_name': displayName,
      'lat': coordinates.latitude.toString(),
      'lng': coordinates.longitude.toString(),
      'address': address,
      'category': category.name,
      'source': source,
    };
  }

  @override
  String toString() => 'LocationSuggestion(name: $name, coordinates: $coordinates)';
}

/// Location categories for better organization
enum LocationCategory {
  educational,
  transport,
  medical,
  commercial,
  place,
  general,
}

extension LocationCategoryExtension on LocationCategory {
  String get displayName {
    switch (this) {
      case LocationCategory.educational:
        return 'Educational';
      case LocationCategory.transport:
        return 'Transport';
      case LocationCategory.medical:
        return 'Medical';
      case LocationCategory.commercial:
        return 'Commercial';
      case LocationCategory.place:
        return 'Place';
      case LocationCategory.general:
        return 'General';
    }
  }

  /// Get appropriate icon for the category
  String get iconName {
    switch (this) {
      case LocationCategory.educational:
        return 'school';
      case LocationCategory.transport:
        return 'train';
      case LocationCategory.medical:
        return 'local_hospital';
      case LocationCategory.commercial:
        return 'store';
      case LocationCategory.place:
        return 'place';
      case LocationCategory.general:
        return 'location_on';
    }
  }
}