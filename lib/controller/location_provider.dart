import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_background/flutter_background.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wakepoint/controller/settings_provider.dart';
import 'package:wakepoint/models/location_model.dart';
import 'package:wakepoint/services/location_service.dart';
import 'package:wakepoint/utils/utils.dart';

const String _logTag = "LocationProvider";
void logHere(String message) => log(message, tag: _logTag);

class LocationProvider with ChangeNotifier {
  final SettingsProvider _settingsProvider;
  final LocationService _locationService;

  double _radius;
  List<LocationModel> _locations = [];
  int? _selectedLocationIndex;
  bool _isTracking = false;
  bool _alarmTriggered = false;
  String? currentSelectedLocation;
  VoidCallback? onAlarmTriggered;

  final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  LocationProvider(this._settingsProvider, this._locationService)
      : _radius = _settingsProvider.alarmRadius {
    _settingsProvider.addListener(_updateRadius);
    _initNotifications();
    _loadLocations();
  }

  double get radius => _radius; 
  List<LocationModel> get locations => _locations;
  int? get selectedLocationIndex => _selectedLocationIndex;
  bool get isTracking => _isTracking;
  Position? get currentPosition => _locationService.currentPosition;

  void _updateRadius() {
    _radius = _settingsProvider.alarmRadius;
    notifyListeners();
  }

  void _initNotifications() {
    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const settings = InitializationSettings(android: androidSettings);

    _notificationsPlugin.initialize(
      settings,
      onDidReceiveNotificationResponse: (response) {
        if (response.actionId == 'STOP_TRACKING') stopTracking();
      },
    );
  }

  Future<void> _loadLocations() async {
    logHere('📥 Loading saved locations...');
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString('saved_locations');
    if (saved != null) {
      _locations = (jsonDecode(saved) as List)
          .map((e) => LocationModel.fromJson(e))
          .toList();
      notifyListeners();
    }
  }

  Future<void> _saveLocations() async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = jsonEncode(_locations.map((e) => e.toJson()).toList());
    prefs.setString('saved_locations', encoded);
  }

  void addLocation(LocationModel location) {
    _locations.add(location);
    _saveLocations();
    notifyListeners();
  }

  void removeLocation(int index) {
    _locations.removeAt(index);
    if (_selectedLocationIndex == index) _selectedLocationIndex = null;
    _saveLocations();
    notifyListeners();
  }

  void setSelectedLocation(int index) {
    if (index >= 0 && index < _locations.length) {
      _selectedLocationIndex = index;
      notifyListeners();
    }
  }

  void toggleTracking() {
    _isTracking = !_isTracking;
    if (_isTracking) {
      _startTracking();
      _startForegroundService();
    } else {
      stopTracking();
    }
    notifyListeners();
  }

  Future<void> _startForegroundService() async {
    const config = FlutterBackgroundAndroidConfig(
      notificationTitle: "WakePoint Tracking",
      notificationText: "Tracking location in background...",
      notificationImportance: AndroidNotificationImportance.high,
      enableWifiLock: true,
    );
    if (await FlutterBackground.initialize(androidConfig: config)) {
      FlutterBackground.enableBackgroundExecution();
    }
  }

  void stopTracking() {
    _locationService.stopListening();
    _notificationsPlugin.cancel(1); // Cancel the tracking notification
    _notificationsPlugin.cancel(0); // Cancel the alarm notification
    FlutterBackground.disableBackgroundExecution();
    _alarmTriggered = false;
    _isTracking = false;
    notifyListeners();
  }

  void _startTracking() {
    if (_selectedLocationIndex == null || !_isTracking) return;
    final target = _locations[_selectedLocationIndex!];

    _locationService.startListening(
      accuracy:
          locationAccuracyOptions[_settingsProvider.locationTrackingAccuracy],
      distanceFilter: 20, // Keep this in meters as distance is in meters
      onUpdate: (position) {
        _sendRealtimeUpdate(position, target);
        _checkProximity(position, target);
        notifyListeners();
      },
    );
  }

  void setAlarmCallback(VoidCallback callback) {
    onAlarmTriggered = callback;
  }

  Future<void> _sendRealtimeUpdate(
      Position position, LocationModel target) async {
    final distanceInMeters = _locationService.calculateDistance(
      position.latitude,
      position.longitude,
      target.latitude,
      target.longitude,
    );
    // Threshold is stored in KM, convert to meters for comparison
    final thresholdInMeters = _settingsProvider.notificationDistanceThresholdKm * 1000;

    if (_settingsProvider.isNotificationThresholdEnabled &&
        distanceInMeters > thresholdInMeters) {
      logHere('Distance ($distanceInMeters m) is above notification threshold ($thresholdInMeters m). Not sending update.');
      // Optional: Clear previous notification if it was showing a closer distance
      // to avoid stale info when outside threshold.
      _notificationsPlugin.cancel(1);
      return;
    }

    // Use UnitConverter to format the distance based on the user's preferred unit system
    final formattedDistance = UnitConverter.formatDistanceForDisplay(
      distanceInMeters,
      _settingsProvider.preferredUnitSystem,
    );

    if (!FlutterBackground.isBackgroundExecutionEnabled) return;

    const androidDetails = AndroidNotificationDetails(
      'wakepoint_tracking',
      'WakePoint Tracking',
      importance: Importance.high,
      priority: Priority.high,
      ongoing: true, // Indicates a persistent notification
      autoCancel: false, // Prevents auto-cancellation on tap
      showWhen: false,
      onlyAlertOnce: true, // This is for the notification channel, not the notification itself
      icon: 'ic_stat_notification',
      actions: [
        AndroidNotificationAction(
          'STOP_TRACKING',
          'Stop Tracking',
          showsUserInterface: true,
        ),
      ],
    );

    const details = NotificationDetails(android: androidDetails);

    await _notificationsPlugin.show(
        1, 'Tracking Active', 'Distance: $formattedDistance', details); // Use formattedDistance
  }

  Future<void> _triggerAlarm(LocationModel location) async {
    if (_alarmTriggered) return;
    _alarmTriggered = true;
    currentSelectedLocation = location.name;

    const androidDetails = AndroidNotificationDetails(
      'wakepoint_alarm',
      'WakePoint Alarm',
      importance: Importance.max,
      priority: Priority.high,
      fullScreenIntent: true,
      playSound: true,
      autoCancel: true,
      icon: 'ic_stat_notification',
    );

    const details = NotificationDetails(android: androidDetails);
    await _notificationsPlugin.show(
        0, 'WakePoint Alert!', 'You are near ${location.name}.', details);

    if (_settingsProvider.useOverlayAlarmFeature) {
      const platform = MethodChannel('com.leywin.wakepoint/alarm');
      try {
        await platform.invokeMethod('startAlarm');
      } catch (e) {
        logHere('Overlay alarm failed: $e');
      }
    }

    onAlarmTriggered?.call();
  }

  void _checkProximity(Position position, LocationModel target) {
    final distance = _locationService.calculateDistance(
      position.latitude,
      position.longitude,
      target.latitude,
      target.longitude,
    );
    // _radius is already in meters, so direct comparison is fine here.
    if (distance <= _radius && !_alarmTriggered) {
      _triggerAlarm(target);
    }
  }

  @override
  void dispose() {
    _settingsProvider.removeListener(_updateRadius);
    super.dispose();
  }
}