import 'bus_route.dart';
import 'driver_trip.dart';

enum BusCurrentStatus {
  active,
  inactive,
  offline,
  maintenance,
}

class BusStatus {
  final String id;
  final BusRoute route;
  final BusCurrentStatus status;
  final DriverTrip? currentTrip;
  final String? busNumber;
  final int passengerCount;
  final int maxCapacity;
  final double? currentLatitude;
  final double? currentLongitude;
  final double? currentSpeedKmh;
  final int? bearingDegrees;
  final DateTime? lastUpdateTime;
  final String? driverName;
  final String? driverPhone;
  final String? driverContactId;
  final bool hasAssignedDriver;
  final String? recentlyPassedLocation;
  final DateTime? estimatedArrival;

  const BusStatus({
    required this.id,
    required this.route,
    required this.status,
    this.currentTrip,
    this.busNumber,
    this.passengerCount = 0,
    this.maxCapacity = 50,
    this.currentLatitude,
    this.currentLongitude,
    this.currentSpeedKmh,
    this.bearingDegrees,
    this.lastUpdateTime,
    this.driverName,
    this.driverPhone,
    this.driverContactId,
    this.hasAssignedDriver = false,
    this.recentlyPassedLocation,
    this.estimatedArrival,
  });

  bool get isActive => status == BusCurrentStatus.active && currentTrip != null;
  bool get hasLiveLocation => currentLatitude != null && currentLongitude != null;
  bool get isOnline => lastUpdateTime != null && 
      DateTime.now().difference(lastUpdateTime!).inMinutes < 5;

  String get statusText {
    switch (status) {
      case BusCurrentStatus.active:
        return isOnline ? 'Active' : 'Last seen ${_formatLastSeen()}';
      case BusCurrentStatus.inactive:
        return 'Inactive';
      case BusCurrentStatus.offline:
        return 'Offline';
      case BusCurrentStatus.maintenance:
        return 'Under Maintenance';
    }
  }

  String get occupancyText {
    if (maxCapacity > 0) {
      final percentage = (passengerCount / maxCapacity * 100).round();
      return '$passengerCount/$maxCapacity ($percentage%)';
    }
    return '$passengerCount passengers';
  }

  String _formatLastSeen() {
    if (lastUpdateTime == null) return 'Unknown';
    
    final now = DateTime.now();
    final difference = now.difference(lastUpdateTime!);
    
    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inHours < 1) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inDays < 1) {
      return '${difference.inHours}h ago';
    } else {
      return '${difference.inDays}d ago';
    }
  }

  factory BusStatus.fromJson(Map<String, dynamic> json) {
    return BusStatus(
      id: json['id'] ?? '',
      route: BusRoute.fromJson(json['route'] ?? {}),
      status: BusCurrentStatus.values.firstWhere(
        (e) => e.name == json['status'],
        orElse: () => BusCurrentStatus.inactive,
      ),
      currentTrip: json['current_trip'] != null 
          ? DriverTrip.fromJson(json['current_trip'])
          : null,
      busNumber: json['bus_number'],
      passengerCount: json['passenger_count'] ?? 0,
      maxCapacity: json['max_capacity'] ?? 50,
      currentLatitude: json['current_latitude']?.toDouble(),
      currentLongitude: json['current_longitude']?.toDouble(),
      currentSpeedKmh: json['current_speed_kmh']?.toDouble(),
      bearingDegrees: json['bearing_degrees']?.toInt(),
      lastUpdateTime: json['last_update_time'] != null 
          ? DateTime.parse(json['last_update_time'])
          : null,
      driverName: json['driver_name'],
      driverPhone: json['driver_phone'],
      driverContactId: json['driver_contact_id'],
      hasAssignedDriver: json['has_assigned_driver'] ?? false,
      recentlyPassedLocation: json['recently_passed_location'],
      estimatedArrival: json['estimated_arrival'] != null 
          ? DateTime.parse(json['estimated_arrival'])
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'route': route.toJson(),
      'status': status.name,
      'current_trip': currentTrip?.toJson(),
      'bus_number': busNumber,
      'passenger_count': passengerCount,
      'max_capacity': maxCapacity,
      'current_latitude': currentLatitude,
      'current_longitude': currentLongitude,
      'current_speed_kmh': currentSpeedKmh,
      'bearing_degrees': bearingDegrees,
      'last_update_time': lastUpdateTime?.toIso8601String(),
      'driver_name': driverName,
      'driver_phone': driverPhone,
      'driver_contact_id': driverContactId,
      'has_assigned_driver': hasAssignedDriver,
      'recently_passed_location': recentlyPassedLocation,
      'estimated_arrival': estimatedArrival?.toIso8601String(),
    };
  }

  BusStatus copyWith({
    String? id,
    BusRoute? route,
    BusCurrentStatus? status,
    DriverTrip? currentTrip,
    String? busNumber,
    int? passengerCount,
    int? maxCapacity,
    double? currentLatitude,
    double? currentLongitude,
    double? currentSpeedKmh,
    int? bearingDegrees,
    DateTime? lastUpdateTime,
    String? driverName,
    String? driverPhone,
    String? driverContactId,
    bool? hasAssignedDriver,
    String? recentlyPassedLocation,
    DateTime? estimatedArrival,
  }) {
    return BusStatus(
      id: id ?? this.id,
      route: route ?? this.route,
      status: status ?? this.status,
      currentTrip: currentTrip ?? this.currentTrip,
      busNumber: busNumber ?? this.busNumber,
      passengerCount: passengerCount ?? this.passengerCount,
      maxCapacity: maxCapacity ?? this.maxCapacity,
      currentLatitude: currentLatitude ?? this.currentLatitude,
      currentLongitude: currentLongitude ?? this.currentLongitude,
      currentSpeedKmh: currentSpeedKmh ?? this.currentSpeedKmh,
      bearingDegrees: bearingDegrees ?? this.bearingDegrees,
      lastUpdateTime: lastUpdateTime ?? this.lastUpdateTime,
      driverName: driverName ?? this.driverName,
      driverPhone: driverPhone ?? this.driverPhone,
      driverContactId: driverContactId ?? this.driverContactId,
      hasAssignedDriver: hasAssignedDriver ?? this.hasAssignedDriver,
      recentlyPassedLocation: recentlyPassedLocation ?? this.recentlyPassedLocation,
      estimatedArrival: estimatedArrival ?? this.estimatedArrival,
    );
  }
}