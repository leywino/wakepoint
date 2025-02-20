class LocationModel {
  String name;
  double latitude;
  double longitude;
  
  LocationModel({required this.name, required this.latitude, required this.longitude});
  
  Map<String, dynamic> toJson() => {
        'name': name,
        'latitude': latitude,
        'longitude': longitude,
      };

  factory LocationModel.fromJson(Map<String, dynamic> json) => LocationModel(
        name: json['name'],
        latitude: json['latitude'],
        longitude: json['longitude'],
      );
}