import 'bus_route.dart';

enum TripStatus { active, paused, completed }

enum TripDirection { outbound, inbound }

class DriverTrip {
  final String id;
  final String driverId;
  final String routeId;
  final String? busId;
  final TripStatus status;
  final TripDirection direction;
  final DateTime startedAt;
  final DateTime? endedAt;
  final double? totalDistanceM;
  final int? totalDurationS;
  final String? notes;
  final BusRoute? route;

  const DriverTrip({
    required this.id,
    required this.driverId,
    required this.routeId,
    this.busId,
    required this.status,
    required this.direction,
    required this.startedAt,
    this.endedAt,
    this.totalDistanceM,
    this.totalDurationS,
    this.notes,
    this.route,
  });

  factory DriverTrip.fromJson(Map<String, dynamic> json) {
    return DriverTrip(
      id: json['id'] as String,
      driverId: json['driver_id'] as String,
      routeId: json['route_id'] as String,
      busId: json['bus_id'] as String?,
      status: TripStatus.values.firstWhere(
        (s) => s.name == json['status'],
        orElse: () => TripStatus.active,
      ),
      direction: TripDirection.values.firstWhere(
        (d) => d.name == json['trip_type'],
        orElse: () => TripDirection.outbound,
      ),
      startedAt: DateTime.parse(json['started_at'] as String),
      endedAt: json['ended_at'] != null
          ? DateTime.parse(json['ended_at'] as String)
          : null,
      totalDistanceM: json['total_distance_m'] != null
          ? (json['total_distance_m'] as num).toDouble()
          : null,
      totalDurationS: json['total_duration_s'] as int?,
      notes: json['notes'] as String?,
      route: json['route'] != null
          ? BusRoute.fromJson(json['route'] as Map<String, dynamic>)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'driver_id': driverId,
      'route_id': routeId,
      'bus_id': busId,
      'status': status.name,
      'direction': direction.name,
      'started_at': startedAt.toIso8601String(),
      'ended_at': endedAt?.toIso8601String(),
      'total_distance_m': totalDistanceM,
      'total_duration_s': totalDurationS,
      'notes': notes,
    };
  }

  DriverTrip copyWith({
    String? id,
    String? driverId,
    String? routeId,
    String? busId,
    TripStatus? status,
    TripDirection? direction,
    DateTime? startedAt,
    DateTime? endedAt,
    double? totalDistanceM,
    int? totalDurationS,
    String? notes,
    BusRoute? route,
  }) {
    return DriverTrip(
      id: id ?? this.id,
      driverId: driverId ?? this.driverId,
      routeId: routeId ?? this.routeId,
      busId: busId ?? this.busId,
      status: status ?? this.status,
      direction: direction ?? this.direction,
      startedAt: startedAt ?? this.startedAt,
      endedAt: endedAt ?? this.endedAt,
      totalDistanceM: totalDistanceM ?? this.totalDistanceM,
      totalDurationS: totalDurationS ?? this.totalDurationS,
      notes: notes ?? this.notes,
      route: route ?? this.route,
    );
  }
}

class DriverLocation {
  final String id;
  final String tripId;
  final DateTime timestamp;
  final LatLng location;
  final double? heading;
  final double? speedMps;

  const DriverLocation({
    required this.id,
    required this.tripId,
    required this.timestamp,
    required this.location,
    this.heading,
    this.speedMps,
  });

  factory DriverLocation.fromJson(Map<String, dynamic> json) {
    return DriverLocation(
      id: json['id'].toString(),
      tripId: json['trip_id'] as String,
      timestamp: DateTime.parse(json['ts'] as String),
      location: LatLng(
        json['lat'] as double,
        json['lng'] as double,
      ),
      heading: json['heading'] != null ? (json['heading'] as num).toDouble() : null,
      speedMps: json['speed_mps'] != null ? (json['speed_mps'] as num).toDouble() : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'trip_id': tripId,
      'ts': timestamp.toIso8601String(),
      'lat': location.latitude,
      'lng': location.longitude,
      'heading': heading,
      'speed_mps': speedMps,
    };
  }
}
