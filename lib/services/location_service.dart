import 'package:geolocator/geolocator.dart';

class LocationService {
  Position? _currentPosition;

  Position? get currentPosition => _currentPosition;

  Future<Position> getCurrentPosition({
    LocationSettings? locationSettings,
    LocationAccuracy desiredAccuracy = LocationAccuracy.best,
    bool forceAndroidLocationManager = false,
    Duration? timeLimit,
  }) async {
    _currentPosition = await Geolocator.getCurrentPosition();
    return _currentPosition!;
  }

  Future<bool> checkPermissions() async {
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    return permission == LocationPermission.always ||
        permission == LocationPermission.whileInUse;
  }

  double calculateDistance(
    double startLat,
    double startLng,
    double endLat,
    double endLng,
  ) {
    return Geolocator.distanceBetween(startLat, startLng, endLat, endLng);
  }

  Future<String> formatDistance({
    required double distance,
  }) async {
    if (distance >= 1000) {
      return '${(distance / 1000).toStringAsFixed(1)} km';
    } else {
      return '${distance.toStringAsFixed(0)} m';
    }
  }
}
