class LocationModel {
  String name;
  double latitude;
  double longitude;
  bool isEnabled;
  double radius;
  DateTime? createdAt;

  LocationModel({
    required this.name,
    required this.latitude,
    required this.longitude,
    required this.isEnabled,
    required this.radius,
    this.createdAt,
  });

  Map<String, dynamic> toJson() => {
        'name': name,
        'latitude': latitude,
        'longitude': longitude,
        'isEnabled': isEnabled,
        'radius': radius,
        'createdAt': DateTime.now().toIso8601String(),
      };

  factory LocationModel.fromJson(Map<String, dynamic> json) => LocationModel(
        name: json['name'],
        latitude: json['latitude'],
        longitude: json['longitude'],
        isEnabled: json['isEnabled'],
        radius: (json['radius'] as num?)?.toDouble() ?? 150.0,
        createdAt: DateTime.tryParse(json['createdAt'] ?? ''),
      );

  LocationModel copyWith({
    String? name,
    double? latitude,
    double? longitude,
    bool? isEnabled,
    double? radius,
    DateTime? createdAt,
  }) {
    return LocationModel(
      name: name ?? this.name,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      isEnabled: isEnabled ?? this.isEnabled,
      radius: radius ?? this.radius,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
