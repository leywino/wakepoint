import 'package:flutter/services.dart';

/// Bridges the Flutter trip controls to Android's Play Services geofencing API.
class GeofenceService {
  static const MethodChannel _channel =
      MethodChannel('com.leywin.wakepoint/geofencing');

  void setEventHandler(Future<void> Function(Map<String, dynamic>) handler) {
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'geofenceEvent' && call.arguments is Map) {
        await handler(Map<String, dynamic>.from(call.arguments as Map));
      }
    });
  }

  Future<void> register({
    required String tripId,
    required String name,
    required double latitude,
    required double longitude,
    required double arrivalRadiusMeters,
    required double approachRadiusMeters,
  }) async {
    await _channel.invokeMethod<void>('register', {
      'name': name,
      'tripId': tripId,
      'latitude': latitude,
      'longitude': longitude,
      'arrivalRadius': arrivalRadiusMeters,
      'approachRadius': approachRadiusMeters,
    });
  }

  Future<void> remove() async {
    await _channel.invokeMethod<void>('remove');
  }

  Future<Map<String, dynamic>?> consumePendingEvent() async {
    final event = await _channel.invokeMapMethod<String, dynamic>(
      'consumePendingEvent',
    );
    return event;
  }
}
