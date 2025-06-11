import 'dart:async';
import 'dart:convert';
import 'dart:developer';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_background/flutter_background.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:wakepoint/controller/settings_provider.dart';
import 'package:wakepoint/models/location_model.dart';

class LocationProvider with ChangeNotifier {
  final SettingsProvider _settingsProvider;
  double _radius;
  List<LocationModel> _locations = [];
  int? _selectedLocationIndex;
  Position? _currentPosition;
  bool _isTracking = false;
  bool _alarmTriggered = false;
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

  /// 🔄 **Update radius from settings**
  void _updateRadius() {
    _radius = _settingsProvider.radius;
    notifyListeners();
  }

  /// 🔔 **Initialize Local Notifications**
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

  /// 📥 **Load Locations from Storage**
  Future<void> _loadLocations() async {
    final prefs = await SharedPreferences.getInstance();
    final String? locationsString = prefs.getString('saved_locations');
    if (locationsString != null) {
      _locations = (jsonDecode(locationsString) as List)
          .map((e) => LocationModel.fromJson(e))
          .toList();
      notifyListeners();
    }
  }

  /// 💾 **Save Locations to Storage**
  Future<void> _saveLocations() async {
    final prefs = await SharedPreferences.getInstance();
    final String locationsString =
        jsonEncode(_locations.map((e) => e.toJson()).toList());
    prefs.setString('saved_locations', locationsString);
  }

  /// ➕ **Add a New Location**
  void addLocation(LocationModel location) {
    _locations.add(location);
    _saveLocations();
    notifyListeners();
  }

  /// ❌ **Remove Location**
  void removeLocation(int index) {
    _locations.removeAt(index);
    if (_selectedLocationIndex == index) {
      _selectedLocationIndex = null;
    }
    _saveLocations();
    notifyListeners();
  }

  /// 🎯 **Select Location for Tracking**
  void setSelectedLocation(int index) {
    if (index >= 0 && index < _locations.length) {
      _selectedLocationIndex = index;
      notifyListeners();
    }
  }

  /// 🔄 **Toggle Location Tracking**
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

  /// 🚀 **Start Foreground Location Tracking**
  Future<void> _startForegroundService() async {
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
      log("✅ Foreground Service Started!");
    }
  }

  /// 🛑 **Stop Foreground Location Tracking**
  void stopTracking() {
    _positionStream?.cancel();
    _notificationsPlugin.cancel(1);
    FlutterBackground.disableBackgroundExecution();
    log('🛑 Foreground Service Stopped');
    _alarmTriggered = false;
    _isTracking = false;
    notifyListeners();
  }

  /// 📍 **Start Location Tracking**
  void _startTracking() {
    if (_selectedLocationIndex == null || !_isTracking) return;

    log('✅ Started tracking');

    LocationSettings locationSettings = LocationSettings(
      accuracy: listOfAccuracy[_settingsProvider.trackingAccuracy],
      distanceFilter: 20, // 🔄 Updates every 20 meters
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

  /// 🔔 **Send Persistent Notification for Tracking**
  Future<void> _sendRealtimeUpdate(Position position) async {
    if (_selectedLocationIndex == null) return;

    final location = _locations[_selectedLocationIndex!];
    double distance = Geolocator.distanceBetween(
      position.latitude,
      position.longitude,
      location.latitude,
      location.longitude,
    );

    // Convert km to meters
    double notificationThreshold =
        _settingsProvider.notificationDistanceThreshold * 1000;

    // If distance-based notifications are enabled and user is beyond threshold, skip notification
    if (_settingsProvider.isThresholdEnabled &&
        distance > notificationThreshold) {
      return;
    }

    // Format distance: show in km if >= 1000m
    String formattedDistance = distance >= 1000
        ? "${(distance / 1000).toStringAsFixed(1)} km"
        : "${distance.toStringAsFixed(0)} m";

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
    onAlarmTriggered = callback;
  }

  /// 🚨 **Trigger Alarm When Near a Location**
  Future<void> _triggerAlarm(LocationModel location) async {
    if (_alarmTriggered) return; // Prevent multiple triggers

    _alarmTriggered = true;

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

    if (!_settingsProvider.useOverlayAlarm) return;

    const platform = MethodChannel('com.leywin.wakepoint/alarm');
    try {
      await platform.invokeMethod('startAlarm');
    } catch (e) {
      log("Error launching alarm: $e");
    }

    onAlarmTriggered?.call();
  }

  /// 🛑 **Check Proximity & Trigger Alarm if Needed**
  void _checkProximity(Position position) {
    if (_selectedLocationIndex == null) return;

    final location = _locations[_selectedLocationIndex!];
    double distance = Geolocator.distanceBetween(
      position.latitude,
      position.longitude,
      location.latitude,
      location.longitude,
    );

    if (distance <= _settingsProvider.radius && !_alarmTriggered) {
      _triggerAlarm(location);
    }
  }
}
