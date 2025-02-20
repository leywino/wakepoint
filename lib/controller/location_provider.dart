import 'dart:async';
import 'dart:convert';
import 'dart:developer';
import 'package:flutter/material.dart';
import 'package:flutter_background/flutter_background.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:wakepoint/models/location_model.dart';

class LocationProvider with ChangeNotifier {
  List<LocationModel> _locations = [];
  int? _selectedLocationIndex;
  Position? _currentPosition;
  bool _isTracking = false;
  StreamSubscription<Position>? _positionStream;
  final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  List<LocationModel> get locations => _locations;
  int? get selectedLocationIndex => _selectedLocationIndex;
  Position? get currentPosition => _currentPosition;
  bool get isTracking => _isTracking;

  LocationProvider() {
    _initNotifications();
    _requestPermissions();
    loadLocations();
  }

  /// 🔔 Initialize Local Notifications
  void _initNotifications() {
    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const InitializationSettings settings =
        InitializationSettings(android: androidSettings);
    _notificationsPlugin.initialize(
      settings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        if (response.actionId == 'STOP_TRACKING') {
          stopForegroundService();
        }
      },
    );
  }

  /// 📍 Request Permissions (Location, Notifications, Foreground)
  Future<void> _requestPermissions() async {
    await [
      Permission.locationAlways,
      Permission.locationWhenInUse,
      Permission.notification,
      Permission.ignoreBatteryOptimizations,
    ].request();
  }

  /// 📥 Load Locations from Storage
  Future<void> loadLocations() async {
    final prefs = await SharedPreferences.getInstance();
    final String? locationsString = prefs.getString('saved_locations');
    if (locationsString != null) {
      final List<dynamic> locationsJson = jsonDecode(locationsString);
      _locations = locationsJson.map((e) => LocationModel.fromJson(e)).toList();
      notifyListeners();
    }
  }

  /// 💾 Save Locations to Storage
  Future<void> saveLocations() async {
    final prefs = await SharedPreferences.getInstance();
    final String locationsString =
        jsonEncode(_locations.map((e) => e.toJson()).toList());
    prefs.setString('saved_locations', locationsString);
  }

  /// ➕ Add a New Location
  void addLocation(LocationModel location) {
    _locations.add(location);
    saveLocations();
    notifyListeners();
  }

  /// ❌ Remove Location
  void removeLocation(int index) {
    _locations.removeAt(index);
    if (_selectedLocationIndex == index) {
      _selectedLocationIndex = null;
    }
    saveLocations();
    notifyListeners();
  }

  /// 🎯 Select Location for Tracking
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
      startForegroundService();
    } else {
      stopForegroundService();
    }
    notifyListeners();
  }

  /// 🚀 **Start Foreground Location Tracking**
  Future<void> startForegroundService() async {
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
  void stopForegroundService() {
    _positionStream?.cancel();
    _notificationsPlugin.cancel(1);
    FlutterBackground.disableBackgroundExecution();
    log('🛑 Foreground Service Stopped');
    notifyListeners(); // Ensure UI updates properly
  }

  /// 📍 **Start Location Tracking**
  void _startTracking() {
    if (_selectedLocationIndex != null && _isTracking) {
      log('✅ Started tracking');
      const LocationSettings locationSettings = LocationSettings(
        accuracy: LocationAccuracy.bestForNavigation,
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
  }

  /// 🔔 **Send Persistent Notification for Tracking**
  Future<void> _sendRealtimeUpdate(Position position) async {
    if (_selectedLocationIndex != null) {
      final location = _locations[_selectedLocationIndex!];
      double distance = Geolocator.distanceBetween(
        position.latitude,
        position.longitude,
        location.latitude,
        location.longitude,
      );

      log("📍 Tracking: ${position.latitude}, ${position.longitude} | Distance: ${distance.toStringAsFixed(2)} meters");

      if (FlutterBackground.isBackgroundExecutionEnabled) {
        const AndroidNotificationDetails androidDetails =
            AndroidNotificationDetails(
          'wakepoint_tracking',
          'WakePoint Tracking',
          importance: Importance.high,
          priority: Priority.high,
          ongoing: true, // ✅ Persistent Notification
          autoCancel: false,
          showWhen: false,
          onlyAlertOnce: true,
          actions: <AndroidNotificationAction>[
            AndroidNotificationAction(
              'STOP_TRACKING',
              'Stop Tracking',
              showsUserInterface: true,
            ),
          ],
        );

        const NotificationDetails notificationDetails =
            NotificationDetails(android: androidDetails);

        await _notificationsPlugin.show(
          1,
          "Tracking Active",
          "Distance: ${distance.toStringAsFixed(2)} meters",
          notificationDetails,
        );
      }
    }
  }

  /// 🚨 **Trigger Alarm When Near a Location (With Stop Button)**
  Future<void> _triggerAlarm(LocationModel location) async {
    const AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
      'wakepoint_alarm',
      'WakePoint Alarm',
      importance: Importance.max,
      priority: Priority.high,
      playSound: true,
      autoCancel:
          false, // 🔴 Don't auto-dismiss so user can interact with the button
      actions: <AndroidNotificationAction>[
        AndroidNotificationAction(
          'STOP_TRACKING', // Unique action ID
          'Stop Tracking', // Button text
          showsUserInterface: true,
        ),
      ],
    );

    const NotificationDetails notificationDetails =
        NotificationDetails(android: androidDetails);

    await _notificationsPlugin.show(
      0,
      "WakePoint Alert!",
      "You are near ${location.name}.",
      notificationDetails,
    );
  }

  /// 🛑 **Check Proximity & Trigger Alarm if Needed**
  void _checkProximity(Position position) {
    if (_selectedLocationIndex != null) {
      final location = _locations[_selectedLocationIndex!];
      double distance = Geolocator.distanceBetween(
        position.latitude,
        position.longitude,
        location.latitude,
        location.longitude,
      );

      if (distance <= 500) {
        _triggerAlarm(location);
      }
    }
  }
}
