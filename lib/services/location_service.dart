import 'dart:async';
import 'package:geolocator/geolocator.dart';

class LocationService {
  StreamSubscription<Position>? _positionStream;
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

  void startListening({
    required LocationAccuracy accuracy,
    int distanceFilter = 20,
    required void Function(Position) onUpdate,
  }) {
    cancelStream();

    final locationSettings = LocationSettings(
      accuracy: accuracy,
      distanceFilter: distanceFilter,
    );

    _positionStream = Geolocator.getPositionStream(
      locationSettings: locationSettings,
    ).listen((position) {
      _currentPosition = position;
      onUpdate(position);
    });
  }

  void stopListening() {
    cancelStream();
  }

  void cancelStream() {
    _positionStream?.cancel();
    _positionStream = null;
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
