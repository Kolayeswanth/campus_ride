class UserProfile {
  final String id;
  final String email;
  final String role;
  final String displayName;
  final String? phone;
  final String? photoUrl;
  final String? collegeId;
  final DateTime createdAt;
  final DateTime updatedAt;

  const UserProfile({
    required this.id,
    required this.email,
    required this.role,
    required this.displayName,
    this.phone,
    this.photoUrl,
    this.collegeId,
    required this.createdAt,
    required this.updatedAt,
  });

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      id: json['id'] as String,
      email: json['email'] as String,
      role: json['role'] as String,
      displayName: json['display_name'] as String,
      phone: json['phone_number'] as String?,
      photoUrl: json['avatar_url'] as String?,
      collegeId: json['college_id'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
      'role': role,
      'display_name': displayName,
      'phone_number': phone,
      'avatar_url': photoUrl,
      'college_id': collegeId,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  UserProfile copyWith({
    String? id,
    String? email,
    String? role,
    String? displayName,
    String? phone,
    String? photoUrl,
    String? collegeId,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return UserProfile(
      id: id ?? this.id,
      email: email ?? this.email,
      role: role ?? this.role,
      displayName: displayName ?? this.displayName,
      phone: phone ?? this.phone,
      photoUrl: photoUrl ?? this.photoUrl,
      collegeId: collegeId ?? this.collegeId,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

enum UserRole {
  passenger,
  driver,
  admin,
  superAdmin;

  String get value {
    switch (this) {
      case UserRole.passenger:
        return 'passenger';
      case UserRole.driver:
        return 'driver';
      case UserRole.admin:
        return 'admin';
      case UserRole.superAdmin:
        return 'super_admin';
    }
  }

  static UserRole fromString(String role) {
    switch (role) {
      case 'passenger':
        return UserRole.passenger;
      case 'driver':
        return UserRole.driver;
      case 'admin':
        return UserRole.admin;
      case 'super_admin':
        return UserRole.superAdmin;
      default:
        return UserRole.passenger;
    }
  }
}
