import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// Location suggestion model
class LocationSuggestion {
  final String displayName;
  final double latitude;
  final double longitude;
  final String? placeId;
  final String? addressType;
  final Map<String, dynamic>? rawData;

  const LocationSuggestion({
    required this.displayName,
    required this.latitude,
    required this.longitude,
    this.placeId,
    this.addressType,
    this.rawData,
  });

  factory LocationSuggestion.fromNominatim(Map<String, dynamic> json) {
    return LocationSuggestion(
      displayName: json['display_name'] ?? '',
      latitude: double.tryParse(json['lat']?.toString() ?? '0') ?? 0,
      longitude: double.tryParse(json['lon']?.toString() ?? '0') ?? 0,
      placeId: json['place_id']?.toString(),
      addressType: json['type'],
      rawData: json,
    );
  }

  @override
  String toString() => displayName;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LocationSuggestion &&
          runtimeType == other.runtimeType &&
          latitude == other.latitude &&
          longitude == other.longitude;

  @override
  int get hashCode => latitude.hashCode ^ longitude.hashCode;
}

/// Nominatim-only location autocomplete service
class NominatimLocationService {
  static const String _nominatimBaseUrl = 'https://nominatim.openstreetmap.org';
  static const Duration _timeout = Duration(seconds: 8);
  
  /// Search for location suggestions using only Nominatim
  static Future<List<LocationSuggestion>> searchLocations(String query) async {
    if (query.trim().isEmpty) {
      return [];
    }

    if (kDebugMode) {
      print('Using Nominatim for location search: "${query}"');
    }

    try {
      return await _searchNominatim(query);
    } catch (e) {
      if (kDebugMode) {
        print('Nominatim search failed: $e');
      }
      return [];
    }
  }

  /// Search using Nominatim API
  static Future<List<LocationSuggestion>> _searchNominatim(String query) async {
    final uri = Uri.parse('$_nominatimBaseUrl/search').replace(queryParameters: {
      'q': query,
      'format': 'json',
      'limit': '8',
      'addressdetails': '1',
      'bounded': '0',
      'countrycodes': 'in', // Focus on India for campus ride
      'accept-language': 'en',
    });

    if (kDebugMode) {
      print('Nominatim request: $uri');
    }

    final response = await http.get(
      uri,
      headers: {
        'User-Agent': 'CampusRide/1.0 (Flutter App)',
        'Accept': 'application/json',
      },
    ).timeout(_timeout);

    if (response.statusCode == 200) {
      final List<dynamic> data = json.decode(response.body);
      final suggestions = data
          .map((item) => LocationSuggestion.fromNominatim(item))
          .where((suggestion) => 
              suggestion.displayName.isNotEmpty && 
              suggestion.latitude != 0 && 
              suggestion.longitude != 0)
          .toList();

      if (kDebugMode) {
        print('Nominatim found ${suggestions.length} suggestions');
        for (int i = 0; i < suggestions.length && i < 3; i++) {
          print('  ${i + 1}. ${suggestions[i].displayName}');
        }
      }

      return suggestions;
    } else {
      throw Exception('Nominatim search failed: ${response.statusCode}');
    }
  }

  /// Get location details by coordinates (reverse geocoding)
  static Future<LocationSuggestion?> getLocationByCoordinates(
      double latitude, double longitude) async {
    try {
      final uri = Uri.parse('$_nominatimBaseUrl/reverse').replace(queryParameters: {
        'lat': latitude.toString(),
        'lon': longitude.toString(),
        'format': 'json',
        'addressdetails': '1',
        'accept-language': 'en',
      });

      final response = await http.get(
        uri,
        headers: {
          'User-Agent': 'CampusRide/1.0 (Flutter App)',
          'Accept': 'application/json',
        },
      ).timeout(_timeout);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return LocationSuggestion.fromNominatim(data);
      }
    } catch (e) {
      if (kDebugMode) {
        print('Reverse geocoding failed: $e');
      }
    }
    return null;
  }

  /// Validate if coordinates are within reasonable bounds
  static bool isValidCoordinates(double latitude, double longitude) {
    return latitude >= -90 && latitude <= 90 && longitude >= -180 && longitude <= 180;
  }

  /// Get formatted address from location suggestion
  static String getFormattedAddress(LocationSuggestion suggestion) {
    if (suggestion.rawData == null) return suggestion.displayName;
    
    final address = suggestion.rawData!['address'] as Map<String, dynamic>?;
    if (address == null) return suggestion.displayName;

    final parts = <String>[];
    
    // Building/house number and road
    if (address['house_number'] != null && address['road'] != null) {
      parts.add('${address['house_number']} ${address['road']}');
    } else if (address['road'] != null) {
      parts.add(address['road']);
    }
    
    // Locality
    if (address['suburb'] != null) {
      parts.add(address['suburb']);
    } else if (address['village'] != null) {
      parts.add(address['village']);
    }
    
    // City
    if (address['city'] != null) {
      parts.add(address['city']);
    } else if (address['town'] != null) {
      parts.add(address['town']);
    }
    
    // State
    if (address['state'] != null) {
      parts.add(address['state']);
    }
    
    return parts.isEmpty ? suggestion.displayName : parts.join(', ');
  }
}