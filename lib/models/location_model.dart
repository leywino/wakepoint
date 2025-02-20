class LocationModel {
  String name;
  double latitude;
  double longitude;
  bool isEnabled;

  LocationModel({
    required this.name,
    required this.latitude,
    required this.longitude,
    required this.isEnabled,
  });

  Map<String, dynamic> toJson() => {
        'name': name,
        'latitude': latitude,
        'longitude': longitude,
        'isEnabled': isEnabled,
      };

  factory LocationModel.fromJson(Map<String, dynamic> json) => LocationModel(
        name: json['name'],
        latitude: json['latitude'],
        longitude: json['longitude'],
        isEnabled: json['isEnabled'],
      );

  LocationModel copyWith({
    String? name,
    double? latitude,
    double? longitude,
    bool? isEnabled,
  }) {
    return LocationModel(
      name: name ?? this.name,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      isEnabled: isEnabled ?? this.isEnabled,
    );
  }
}
