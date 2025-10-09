class College {
  final String id;
  final String name;
  final String address;
  final String city;
  final String state;
  final String country;
  final String? logoUrl;
  final String? websiteUrl;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool isActive;

  const College({
    required this.id,
    required this.name,
    required this.address,
    required this.city,
    required this.state,
    required this.country,
    this.logoUrl,
    this.websiteUrl,
    required this.createdAt,
    required this.updatedAt,
    this.isActive = true,
  });

  factory College.fromJson(Map<String, dynamic> json) {
    return College(
      id: json['id'] as String,
      name: json['name'] as String,
      address: json['address'] as String,
      city: json['city'] as String,
      state: json['state'] as String,
      country: json['country'] as String,
      logoUrl: json['logo_url'] as String?,
      websiteUrl: json['website_url'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
      isActive: json['is_active'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'address': address,
      'city': city,
      'state': state,
      'country': country,
      'logo_url': logoUrl,
      'website_url': websiteUrl,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'is_active': isActive,
    };
  }

  College copyWith({
    String? id,
    String? name,
    String? address,
    String? city,
    String? state,
    String? country,
    String? logoUrl,
    String? websiteUrl,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isActive,
  }) {
    return College(
      id: id ?? this.id,
      name: name ?? this.name,
      address: address ?? this.address,
      city: city ?? this.city,
      state: state ?? this.state,
      country: country ?? this.country,
      logoUrl: logoUrl ?? this.logoUrl,
      websiteUrl: websiteUrl ?? this.websiteUrl,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isActive: isActive ?? this.isActive,
    );
  }

  @override
  String toString() {
    return 'College(id: $id, name: $name, city: $city, state: $state)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is College && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}
