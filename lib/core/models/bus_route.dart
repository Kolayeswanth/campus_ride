class LatLng {
  final double latitude;
  final double longitude;

  const LatLng(this.latitude, this.longitude);

  factory LatLng.fromJson(Map<String, dynamic> json) {
    return LatLng(
      json['lat'] as double,
      json['lng'] as double,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'lat': latitude,
      'lng': longitude,
    };
  }

  @override
  String toString() => 'LatLng($latitude, $longitude)';

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is LatLng &&
        other.latitude == latitude &&
        other.longitude == longitude;
  }

  @override
  int get hashCode => latitude.hashCode ^ longitude.hashCode;
}

class BusRoute {
  final String id;
  final String collegeId;
  final String routeName;
  final String? routeCode;
  final String? busNumberHint;
  final String startName;
  final LatLng startLocation;
  final String endName;
  final LatLng endLocation;
  final String? polylineData;
  final List<LatLng>? waypoints;
  final double? distanceKm;
  final int? estimatedDurationMinutes;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;

  const BusRoute({
    required this.id,
    required this.collegeId,
    required this.routeName,
    this.routeCode,
    this.busNumberHint,
    required this.startName,
    required this.startLocation,
    required this.endName,
    required this.endLocation,
    this.polylineData,
    this.waypoints,
    this.distanceKm,
    this.estimatedDurationMinutes,
    required this.isActive,
    required this.createdAt,
    required this.updatedAt,
  });

  factory BusRoute.fromJson(Map<String, dynamic> json) {
    return BusRoute(
      id: json['id'] as String,
      collegeId: json['college_id'] as String,
      routeName: json['route_name'] as String,
      routeCode: json['route_code'] as String?,
      busNumberHint: json['bus_number_hint'] as String?,
      startName: json['start_name'] as String,
      startLocation: LatLng(
        json['start_latitude'] as double,
        json['start_longitude'] as double,
      ),
      endName: json['end_name'] as String,
      endLocation: LatLng(
        json['end_latitude'] as double,
        json['end_longitude'] as double,
      ),
      polylineData: json['polyline_data'] as String?,
      waypoints: json['waypoints'] != null
          ? (json['waypoints'] as List)
              .map((w) => LatLng.fromJson(w as Map<String, dynamic>))
              .toList()
          : null,
      distanceKm: json['distance_km'] != null
          ? (json['distance_km'] as num).toDouble()
          : null,
      estimatedDurationMinutes: json['estimated_duration_minutes'] as int?,
      isActive: json['is_active'] as bool? ?? true,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'college_id': collegeId,
      'route_name': routeName,
      'route_code': routeCode,
      'bus_number_hint': busNumberHint,
      'start_name': startName,
      'start_latitude': startLocation.latitude,
      'start_longitude': startLocation.longitude,
      'end_name': endName,
      'end_latitude': endLocation.latitude,
      'end_longitude': endLocation.longitude,
      'polyline_data': polylineData,
      'waypoints': waypoints?.map((w) => w.toJson()).toList(),
      'distance_km': distanceKm,
      'estimated_duration_minutes': estimatedDurationMinutes,
      'is_active': isActive,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }
}
