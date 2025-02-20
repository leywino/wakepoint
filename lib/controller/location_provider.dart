import 'dart:async';
import 'dart:convert';
import 'dart:developer';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:background_fetch/background_fetch.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_vibrate/flutter_vibrate.dart';
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
    _initBackgroundFetch();
    loadLocations();
  }

  /// Initialize Notifications
  void _initNotifications() {
    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const InitializationSettings settings =
        InitializationSettings(android: androidSettings);
    _notificationsPlugin.initialize(settings);
  }

  /// Initialize Background Fetch for 15-min Updates
  void _initBackgroundFetch() {
    BackgroundFetch.configure(
      BackgroundFetchConfig(
        minimumFetchInterval: 15,
        stopOnTerminate: false,
        enableHeadless: true,
      ),
      (String taskId) async {
        await _fetchBackgroundLocation();
        BackgroundFetch.finish(taskId);
      },
    );
  }

  /// Fetch Background Location (For 15-min updates)
  Future<void> _fetchBackgroundLocation() async {
    if (!_isTracking) return;

    Position position = await Geolocator.getCurrentPosition(
        locationSettings: AndroidSettings(accuracy: LocationAccuracy.best));

    _currentPosition = position;
    _checkProximity(position);
    _sendRealtimeUpdate(position);

    notifyListeners();
  }

  /// Load Locations from SharedPreferences
  Future<void> loadLocations() async {
    final prefs = await SharedPreferences.getInstance();
    final String? locationsString = prefs.getString('saved_locations');
    if (locationsString != null) {
      final List<dynamic> locationsJson = jsonDecode(locationsString);
      _locations = locationsJson.map((e) => LocationModel.fromJson(e)).toList();
      notifyListeners();
    }
  }

  /// Save Locations to SharedPreferences
  Future<void> saveLocations() async {
    final prefs = await SharedPreferences.getInstance();
    final String locationsString =
        jsonEncode(_locations.map((e) => e.toJson()).toList());
    prefs.setString('saved_locations', locationsString);
  }

  /// Add Location
  void addLocation(LocationModel location) {
    _locations.add(location);
    saveLocations();
    notifyListeners();
  }

  /// Remove Location
  void removeLocation(int index) {
    _locations.removeAt(index);
    if (_selectedLocationIndex == index) {
      _selectedLocationIndex = null;
    }
    saveLocations();
    notifyListeners();
  }

  /// Select a Location for Tracking
  void setSelectedLocation(int index) {
    if (index >= 0 && index < _locations.length) {
      _selectedLocationIndex = index;
      notifyListeners();
    }
  }

  /// Toggle Tracking (Start/Pause)
  void toggleTracking() {
    _isTracking = !_isTracking;
    if (_isTracking) {
      _startTracking();
    } else {
      _stopTracking();
    }
    notifyListeners();
  }

  /// Start Tracking Every 20 Meters (Even in Background)
  void _startTracking() {
    if (_selectedLocationIndex != null && _isTracking) {
      log('Started tracking');
      const LocationSettings locationSettings = LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 20, // ✅ Update every 20 meters
      );
      _positionStream = Geolocator.getPositionStream(
        locationSettings: locationSettings,
      ).listen((Position position) {
        _currentPosition = position;
        _checkProximity(position);
        _sendRealtimeUpdate(position);
        notifyListeners();
      });
    }
  }

  /// Stop Tracking and Remove Notification
  void _stopTracking() {
    _positionStream?.cancel();
    _notificationsPlugin.cancel(1); // Remove ongoing tracking notification
    log('Stopped tracking');
  }

  /// Check if User is Near Selected Location
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

  /// Send Persistent Notification for Real-Time Tracking
  Future<void> _sendRealtimeUpdate(Position position) async {
    if (_selectedLocationIndex != null) {
      final location = _locations[_selectedLocationIndex!];
      double distance = Geolocator.distanceBetween(
        position.latitude,
        position.longitude,
        location.latitude,
        location.longitude,
      );

      log("Tracking: ${position.latitude}, ${position.longitude}");

      const AndroidNotificationDetails androidDetails =
          AndroidNotificationDetails(
        'wakepoint_tracking',
        'WakePoint Tracking',
        importance: Importance.high,
        priority: Priority.high,
        ongoing: true, // ✅ Persistent notification
        autoCancel: false,
        showWhen: false,
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

  /// Trigger Alarm (Notification + Vibration)
  Future<void> _triggerAlarm(LocationModel location) async {
    if (await Vibrate.canVibrate) {
      Vibrate.vibrate();
    }

    const AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
      'wakepoint_alarm',
      'WakePoint Alarm',
      importance: Importance.max,
      priority: Priority.high,
      playSound: true,
      autoCancel: true,
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
}
