import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_background/flutter_background.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:wakepoint/controller/settings_provider.dart';
import 'package:wakepoint/models/location_model.dart';
import 'package:wakepoint/utils/utils.dart';

const String _logTag = "LocationProvider";
void logHere(String message) => log(message, tag: _logTag);

class LocationProvider with ChangeNotifier {
  final SettingsProvider _settingsProvider;
  double _radius;
  List<LocationModel> _locations = [];
  int? _selectedLocationIndex;
  Position? _currentPosition;
  bool _isTracking = false;
  bool _alarmTriggered = false;
  String? currentSelectedLocation;
  StreamSubscription<Position>? _positionStream;
  VoidCallback? onAlarmTriggered;

  final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  LocationProvider(this._settingsProvider)
      : _radius = _settingsProvider.radius {
    _settingsProvider.addListener(_updateRadius);
    _initNotifications();
    _loadLocations();
  }

  double get radius => _radius;
  List<LocationModel> get locations => _locations;
  int? get selectedLocationIndex => _selectedLocationIndex;
  Position? get currentPosition => _currentPosition;
  bool get isTracking => _isTracking;

  void _updateRadius() {
    _radius = _settingsProvider.radius;
    notifyListeners();
  }

  void _initNotifications() {
    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const InitializationSettings settings =
        InitializationSettings(android: androidSettings);

    _notificationsPlugin.initialize(
      settings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        if (response.actionId == 'STOP_TRACKING') {
          stopTracking();
        }
      },
    );
  }

  Future<void> _loadLocations() async {
    logHere('📥 Loading saved locations...');
    final prefs = await SharedPreferences.getInstance();
    final String? locationsString = prefs.getString('saved_locations');
    if (locationsString != null) {
      _locations = (jsonDecode(locationsString) as List)
          .map((e) => LocationModel.fromJson(e))
          .toList();
      logHere('✅ Loaded ${_locations.length} locations.');
      notifyListeners();
    }
  }

  Future<void> _saveLocations() async {
    logHere('💾 Saving ${_locations.length} locations...');
    final prefs = await SharedPreferences.getInstance();
    final String locationsString =
        jsonEncode(_locations.map((e) => e.toJson()).toList());
    prefs.setString('saved_locations', locationsString);
  }

  void addLocation(LocationModel location) {
    logHere('➕ Adding location: ${location.name}');
    _locations.add(location);
    _saveLocations();
    notifyListeners();
  }

  void removeLocation(int index) {
    logHere('❌ Removing location at index: $index');
    _locations.removeAt(index);
    if (_selectedLocationIndex == index) {
      _selectedLocationIndex = null;
    }
    _saveLocations();
    notifyListeners();
  }

  void setSelectedLocation(int index) {
    if (index >= 0 && index < _locations.length) {
      logHere('🎯 Selected location index: $index');
      _selectedLocationIndex = index;
      notifyListeners();
    }
  }

  void toggleTracking() {
    _isTracking = !_isTracking;
    logHere(_isTracking ? '🚀 Enabling tracking...' : '🛑 Disabling tracking...');
    if (_isTracking) {
      _startTracking();
      _startForegroundService();
    } else {
      stopTracking();
    }
    notifyListeners();
  }

  Future<void> _startForegroundService() async {
    logHere('📡 Initializing foreground service...');
    const androidConfig = FlutterBackgroundAndroidConfig(
      notificationTitle: "WakePoint Tracking",
      notificationText: "Tracking location in background...",
      notificationImportance: AndroidNotificationImportance.high,
      enableWifiLock: true,
    );

    bool success =
        await FlutterBackground.initialize(androidConfig: androidConfig);
    if (success) {
      FlutterBackground.enableBackgroundExecution();
      logHere('✅ Foreground service started.');
    } else {
      logHere('❌ Failed to start foreground service.');
    }
  }

  void stopTracking() {
    logHere('🛑 Stopping location tracking and foreground service...');
    _positionStream?.cancel();
    _notificationsPlugin.cancel(1);
    FlutterBackground.disableBackgroundExecution();
    _alarmTriggered = false;
    _isTracking = false;
    notifyListeners();
  }

  void _startTracking() {
    if (_selectedLocationIndex == null || !_isTracking) return;

    logHere('📍 Starting location stream...');

    LocationSettings locationSettings = LocationSettings(
      accuracy: listOfAccuracy[_settingsProvider.trackingAccuracy],
      distanceFilter: 20,
    );

    _positionStream = Geolocator.getPositionStream(
      locationSettings: locationSettings,
    ).listen((Position position) {
      _currentPosition = position;
      _sendRealtimeUpdate(position);
      notifyListeners();
      _checkProximity(position);
    });
  }

  Future<void> _sendRealtimeUpdate(Position position) async {
    logHere('📍 Sending realtime update...');
    if (_selectedLocationIndex == null) return;

    final location = _locations[_selectedLocationIndex!];
    double distance = Geolocator.distanceBetween(
      position.latitude,
      position.longitude,
      location.latitude,
      location.longitude,
    );

    double notificationThreshold =
        _settingsProvider.notificationDistanceThreshold * 1000;

    if (_settingsProvider.isThresholdEnabled && distance > notificationThreshold) {
      logHere('🔕 Skipped update — outside threshold: ${distance.toStringAsFixed(0)} m');
      return;
    }

    String formattedDistance = distance >= 1000
        ? "${(distance / 1000).toStringAsFixed(1)} km"
        : "${distance.toStringAsFixed(0)} m";

    logHere('📏 Distance to destination: $formattedDistance');

    if (FlutterBackground.isBackgroundExecutionEnabled) {
      AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
        'wakepoint_tracking',
        'WakePoint Tracking',
        importance: Importance.high,
        priority: Priority.high,
        ongoing: _settingsProvider.persistentNotification,
        autoCancel: false,
        showWhen: false,
        onlyAlertOnce: true,
        icon: 'ic_stat_notification',
        actions: <AndroidNotificationAction>[
          const AndroidNotificationAction(
            'STOP_TRACKING',
            'Stop Tracking',
            showsUserInterface: true,
          ),
        ],
      );

      NotificationDetails notificationDetails =
          NotificationDetails(android: androidDetails);

      await _notificationsPlugin.show(
        1,
        "Tracking Active",
        "Distance: $formattedDistance",
        notificationDetails,
      );
    }
  }

  void setAlarmCallback(VoidCallback callback) {
    logHere('🔔 Alarm callback set');
    onAlarmTriggered = callback;
  }

  Future<void> _triggerAlarm(LocationModel location) async {
    if (_alarmTriggered) return;

    logHere('🚨 Triggering alarm for: ${location.name}');
    _alarmTriggered = true;
    currentSelectedLocation = location.name;

    const AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
      'wakepoint_alarm',
      'WakePoint Alarm',
      importance: Importance.max,
      priority: Priority.high,
      fullScreenIntent: true,
      playSound: true,
      autoCancel: true,
      icon: 'ic_stat_notification',
    );

    const NotificationDetails notificationDetails = NotificationDetails(
      android: androidDetails,
    );

    await _notificationsPlugin.show(
      0,
      "WakePoint Alert!",
      "You are near ${location.name}.",
      notificationDetails,
    );

    logHere('📢 WakePoint notification shown for: ${location.name}');

    if (!_settingsProvider.useOverlayAlarm) return;

    const platform = MethodChannel('com.leywin.wakepoint/alarm');
    try {
      await platform.invokeMethod('startAlarm');
    } catch (e) {
      logHere('⚠️ Alarm overlay launch failed: $e');
    }

    onAlarmTriggered?.call();
  }

  void _checkProximity(Position position) {
    logHere('🔎 Checking proximity...');
    if (_selectedLocationIndex == null) return;

    final location = _locations[_selectedLocationIndex!];
    double distance = Geolocator.distanceBetween(
      position.latitude,
      position.longitude,
      location.latitude,
      location.longitude,
    );

    logHere('📐 Current distance: ${distance.toStringAsFixed(2)} m');

    if (distance <= _settingsProvider.radius && !_alarmTriggered) {
      logHere('🚨 Within radius, triggering alarm...');
      _triggerAlarm(location);
    }
  }
}