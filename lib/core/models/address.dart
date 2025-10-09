/// Model representing a geographic address with detailed breakdown
/// 
/// This model is compatible with LocationIQ API responses and provides
/// a structured way to handle address information throughout the app.
class Address {
  final String? placeId;
  final double latitude;
  final double longitude;
  final String displayName;
  final String? licence;
  
  // Address components
  final String? houseNumber;
  final String? road;
  final String? suburb;
  final String? neighbourhood;
  final String? village;
  final String? town;
  final String? city;
  final String? county;
  final String? state;
  final String? stateCode;
  final String? postcode;
  final String? country;
  final String? countryCode;
  
  // Additional place information
  final String? amenity;
  final String? attraction;
  final String? building;
  final String? shop;
  final String? tourism;
  final String? leisure;
  
  // Bounding box for the location
  final List<double>? boundingBox;
  
  // OpenStreetMap identifiers
  final String? osmType;
  final String? osmId;

  const Address({
    this.placeId,
    required this.latitude,
    required this.longitude,
    required this.displayName,
    this.licence,
    this.houseNumber,
    this.road,
    this.suburb,
    this.neighbourhood,
    this.village,
    this.town,
    this.city,
    this.county,
    this.state,
    this.stateCode,
    this.postcode,
    this.country,
    this.countryCode,
    this.amenity,
    this.attraction,
    this.building,
    this.shop,
    this.tourism,
    this.leisure,
    this.boundingBox,
    this.osmType,
    this.osmId,
  });

  /// Create an Address from LocationIQ API response
  factory Address.fromLocationIQ(Map<String, dynamic> json) {
    final addressData = json['address'] as Map<String, dynamic>? ?? {};
    
    // Parse bounding box if available
    List<double>? boundingBox;
    if (json['boundingbox'] != null) {
      final bbox = json['boundingbox'] as List<dynamic>;
      if (bbox.length >= 4) {
        boundingBox = [
          double.tryParse(bbox[0].toString()) ?? 0.0, // min_lat
          double.tryParse(bbox[1].toString()) ?? 0.0, // max_lat
          double.tryParse(bbox[2].toString()) ?? 0.0, // min_lon
          double.tryParse(bbox[3].toString()) ?? 0.0, // max_lon
        ];
      }
    }

    return Address(
      placeId: json['place_id']?.toString(),
      latitude: double.tryParse(json['lat']?.toString() ?? '0') ?? 0.0,
      longitude: double.tryParse(json['lon']?.toString() ?? '0') ?? 0.0,
      displayName: json['display_name']?.toString() ?? '',
      licence: json['licence']?.toString(),
      
      // Address components
      houseNumber: addressData['house_number']?.toString(),
      road: addressData['road']?.toString(),
      suburb: addressData['suburb']?.toString(),
      neighbourhood: addressData['neighbourhood']?.toString(),
      village: addressData['village']?.toString(),
      town: addressData['town']?.toString(),
      city: addressData['city']?.toString(),
      county: addressData['county']?.toString(),
      state: addressData['state']?.toString(),
      stateCode: addressData['state_code']?.toString(),
      postcode: addressData['postcode']?.toString(),
      country: addressData['country']?.toString(),
      countryCode: addressData['country_code']?.toString(),
      
      // Additional place information
      amenity: addressData['amenity']?.toString(),
      attraction: addressData['attraction']?.toString(),
      building: addressData['building']?.toString(),
      shop: addressData['shop']?.toString(),
      tourism: addressData['tourism']?.toString(),
      leisure: addressData['leisure']?.toString(),
      
      boundingBox: boundingBox,
      osmType: json['osm_type']?.toString(),
      osmId: json['osm_id']?.toString(),
    );
  }

  /// Create an Address from a simple coordinate
  factory Address.fromCoordinate({
    required double latitude,
    required double longitude,
    String? name,
  }) {
    return Address(
      latitude: latitude,
      longitude: longitude,
      displayName: name ?? 'Location: ${latitude.toStringAsFixed(4)}, ${longitude.toStringAsFixed(4)}',
    );
  }

  /// Convert to JSON for storage or transmission
  Map<String, dynamic> toJson() {
    return {
      'place_id': placeId,
      'lat': latitude,
      'lon': longitude,
      'display_name': displayName,
      'licence': licence,
      'address': {
        if (houseNumber != null) 'house_number': houseNumber,
        if (road != null) 'road': road,
        if (suburb != null) 'suburb': suburb,
        if (neighbourhood != null) 'neighbourhood': neighbourhood,
        if (village != null) 'village': village,
        if (town != null) 'town': town,
        if (city != null) 'city': city,
        if (county != null) 'county': county,
        if (state != null) 'state': state,
        if (stateCode != null) 'state_code': stateCode,
        if (postcode != null) 'postcode': postcode,
        if (country != null) 'country': country,
        if (countryCode != null) 'country_code': countryCode,
        if (amenity != null) 'amenity': amenity,
        if (attraction != null) 'attraction': attraction,
        if (building != null) 'building': building,
        if (shop != null) 'shop': shop,
        if (tourism != null) 'tourism': tourism,
        if (leisure != null) 'leisure': leisure,
      },
      if (boundingBox != null) 'boundingbox': boundingBox,
      if (osmType != null) 'osm_type': osmType,
      if (osmId != null) 'osm_id': osmId,
    };
  }

  /// Get a short address suitable for display
  String get shortAddress {
    final parts = <String>[];
    
    if (road != null) parts.add(road!);
    if (suburb != null) parts.add(suburb!);
    if (city != null) parts.add(city!);
    if (state != null) parts.add(state!);
    
    if (parts.isEmpty) {
      // Fallback to village/town if city is not available
      if (village != null) parts.add(village!);
      if (town != null) parts.add(town!);
      if (county != null) parts.add(county!);
    }
    
    return parts.isNotEmpty ? parts.join(', ') : displayName;
  }

  /// Get the primary locality (city, town, or village)
  String? get locality {
    return city ?? town ?? village ?? suburb;
  }

  /// Get the administrative area (state/province)
  String? get administrativeArea {
    return state;
  }

  /// Get the postal code
  String? get postalCode {
    return postcode;
  }

  /// Check if this address has detailed components
  bool get hasDetailedAddress {
    return road != null || suburb != null || city != null;
  }

  /// Get a formatted address for Indian context
  String get indianFormattedAddress {
    final parts = <String>[];
    
    // Building/House number and road
    if (houseNumber != null && road != null) {
      parts.add('$houseNumber, $road');
    } else if (road != null) {
      parts.add(road!);
    }
    
    // Area/Suburb
    if (suburb != null) parts.add(suburb!);
    if (neighbourhood != null && suburb != neighbourhood) {
      parts.add(neighbourhood!);
    }
    
    // City/Town/Village
    final locality = city ?? town ?? village;
    if (locality != null) parts.add(locality);
    
    // District/County
    if (county != null && county != locality) {
      parts.add(county!);
    }
    
    // State and PIN
    if (state != null) {
      if (postcode != null) {
        parts.add('$state $postcode');
      } else {
        parts.add(state!);
      }
    }
    
    return parts.isNotEmpty ? parts.join(', ') : displayName;
  }

  @override
  String toString() {
    return 'Address(${latitude.toStringAsFixed(4)}, ${longitude.toStringAsFixed(4)}) - $displayName';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Address &&
        other.latitude == latitude &&
        other.longitude == longitude &&
        other.displayName == displayName;
  }

  @override
  int get hashCode {
    return Object.hash(latitude, longitude, displayName);
  }

  /// Create a copy with updated fields
  Address copyWith({
    String? placeId,
    double? latitude,
    double? longitude,
    String? displayName,
    String? licence,
    String? houseNumber,
    String? road,
    String? suburb,
    String? neighbourhood,
    String? village,
    String? town,
    String? city,
    String? county,
    String? state,
    String? stateCode,
    String? postcode,
    String? country,
    String? countryCode,
    String? amenity,
    String? attraction,
    String? building,
    String? shop,
    String? tourism,
    String? leisure,
    List<double>? boundingBox,
    String? osmType,
    String? osmId,
  }) {
    return Address(
      placeId: placeId ?? this.placeId,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      displayName: displayName ?? this.displayName,
      licence: licence ?? this.licence,
      houseNumber: houseNumber ?? this.houseNumber,
      road: road ?? this.road,
      suburb: suburb ?? this.suburb,
      neighbourhood: neighbourhood ?? this.neighbourhood,
      village: village ?? this.village,
      town: town ?? this.town,
      city: city ?? this.city,
      county: county ?? this.county,
      state: state ?? this.state,
      stateCode: stateCode ?? this.stateCode,
      postcode: postcode ?? this.postcode,
      country: country ?? this.country,
      countryCode: countryCode ?? this.countryCode,
      amenity: amenity ?? this.amenity,
      attraction: attraction ?? this.attraction,
      building: building ?? this.building,
      shop: shop ?? this.shop,
      tourism: tourism ?? this.tourism,
      leisure: leisure ?? this.leisure,
      boundingBox: boundingBox ?? this.boundingBox,
      osmType: osmType ?? this.osmType,
      osmId: osmId ?? this.osmId,
    );
  }
}
