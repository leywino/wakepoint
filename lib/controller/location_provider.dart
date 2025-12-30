import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_activity_recognition/flutter_activity_recognition.dart';
import 'package:flutter_background/flutter_background.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:geolocator/geolocator.dart' hide AndroidResource, ActivityType;
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wakepoint/config/constants.dart';
import 'package:wakepoint/controller/settings_provider.dart';
import 'package:wakepoint/models/location_model.dart';
import 'package:wakepoint/services/location_service.dart';
import 'package:wakepoint/utils/utils.dart';

const String _logTag = "LocationProvider";
void logHere(String message) => log(message, tag: _logTag);

class LocationProvider with ChangeNotifier {
  final SettingsProvider _settingsProvider;
  final LocationService _locationService;

  List<LocationModel> _locations = [];
  int? _selectedLocationIndex;
  bool _isTracking = false;
  bool _alarmTriggered = false;
  String? currentSelectedLocation;
  VoidCallback? onAlarmTriggered;
  StreamSubscription<Activity>? _activitySubscription;
  bool _isGpsActive = false;
  Timer? _adaptiveTimer;
  static const double kAdaptiveThreshold = 10000;

  final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  LocationProvider(this._settingsProvider, this._locationService) {
    _initNotifications();
    _loadLocations();
  }

  List<LocationModel> get locations => _locations;
  int? get selectedLocationIndex => _selectedLocationIndex;
  bool get isTracking => _isTracking;
  Position? get currentPosition => _locationService.currentPosition;
  bool _isInitializingTracking = false;
  bool get isInitializingTracking => _isInitializingTracking;

  void _initNotifications() {
    const androidSettings =
        AndroidInitializationSettings('ic_stat_notification');
    const settings = InitializationSettings(android: androidSettings);

    _notificationsPlugin.initialize(
      settings,
      onDidReceiveNotificationResponse: (response) {
        if (response.actionId == 'STOP_TRACKING') stopTracking();
      },
    );
  }

  Future<void> _decideTrackingMode() async {
    if (_selectedLocationIndex == null || !_isTracking) return;

    final position = await _locationService.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.medium,
    );

    final target = _locations[_selectedLocationIndex!];
    final distance = _locationService.calculateDistance(
      position.latitude,
      position.longitude,
      target.latitude,
      target.longitude,
    );

    logHere("📍 Check: ${distance.toStringAsFixed(0)}m away.");

    if (distance > kAdaptiveThreshold) {
      if (_isGpsActive) _stopGpsStream();

      int intervalMinutes = (distance / 2000).floor().clamp(2, 30);

      logHere("🌍 Far away (>10km). Sleeping for $intervalMinutes mins.");

      _adaptiveTimer?.cancel();
      _adaptiveTimer = Timer(Duration(minutes: intervalMinutes), () {
        _decideTrackingMode();
      });
    } else {
      logHere("🎯 Close (<10km)! Switching to High Precision Stream.");
      _adaptiveTimer?.cancel();

      if (!_isGpsActive) {
        _startGpsStream();
      }
    }
  }

  Future<void> _initActivityRecognition() async {
    // 1. Check or Request Permission
    bool isGranted = await Permission.activityRecognition.isGranted;
    if (!isGranted) {
      isGranted = await Permission.activityRecognition.request().isGranted;
    }

    if (isGranted) {
      logHere("🏃 Activity Permission Granted. Listening for movement...");
      _activitySubscription = FlutterActivityRecognition.instance.activityStream
          .listen(_handleActivityChange);
    } else {
      logHere("⚠️ Activity Permission Denied. Defaulting to Always-On GPS.");
      _startGpsStream(); // Fallback: Run GPS continuously
    }
  }

  void _handleActivityChange(Activity activity) {
    logHere("Detected Activity: ${activity.type}");

    if (activity.type == ActivityType.STILL) {
      // STOP EVERYTHING when still
      logHere("💤 Still. Pausing all location checks.");
      _stopGpsStream();
      _adaptiveTimer?.cancel();
    } else {
      // MOVING? Let the brain decide strategy (Stream vs Timer)
      // Only trigger if we aren't already streaming or waiting on a timer
      if (!_isGpsActive &&
          (_adaptiveTimer == null || !_adaptiveTimer!.isActive)) {
        logHere("🚗 Moving. Calculating best tracking mode...");
        _decideTrackingMode();
      }
    }
  }

  void _startGpsStream() {
    if (_selectedLocationIndex == null || _isGpsActive) return;

    final target = _locations[_selectedLocationIndex!];
    _isGpsActive = true;

    _locationService.startListening(
      accuracy:
          locationAccuracyOptions[_settingsProvider.locationTrackingAccuracy],
      distanceFilter: 20,
      onUpdate: (position) {
        _sendRealtimeUpdate(position, target);
        _checkProximity(position, target, target.radius);
        notifyListeners();
      },
    );
  }

  void _stopGpsStream() {
    _locationService.stopListening();
    _isGpsActive = false;
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

  void editLocation(DateTime createdAt, LocationModel updatedLocation) {
    final index = _locations.indexWhere((loc) => loc.createdAt == createdAt);
    if (index != -1) {
      _locations[index] = updatedLocation;
      _saveLocations();
      notifyListeners();
    } else {
      logHere(
          '❌ Attempted to edit location with unknown createdAt: $createdAt');
      Fluttertoast.showToast(msg: msgLocationNotFound);
    }
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

  void toggleTracking() async {
    _isTracking = !_isTracking;
    if (_isTracking) {
      bool started = await _startTracking();
      if (started) {
        _startForegroundService();
      }
    } else {
      stopTracking();
    }
    notifyListeners();
  }

  Future<void> _startForegroundService() async {
    const config = FlutterBackgroundAndroidConfig(
        notificationTitle: appName,
        notificationText: kNotificationTrackingText,
        notificationImportance: AndroidNotificationImportance.normal,
        enableWifiLock: true,
        notificationIcon:
            AndroidResource(name: "ic_stat_notification", defType: 'drawable'));
    if (await FlutterBackground.initialize(androidConfig: config)) {
      FlutterBackground.enableBackgroundExecution();
    }
  }

  void stopTracking() {
    _activitySubscription?.cancel();
    _activitySubscription = null;

    _stopGpsStream();
    _adaptiveTimer?.cancel(); // NEW: Kill the timer
    _adaptiveTimer = null;

    _notificationsPlugin.cancel(1);
    _notificationsPlugin.cancel(0);
    if (FlutterBackground.isBackgroundExecutionEnabled) {
      FlutterBackground.disableBackgroundExecution();
    }

    _alarmTriggered = false;
    _isTracking = false;
    _isInitializingTracking = false;

    notifyListeners();
  }

  Future<bool> _startTracking() async {
    if (_selectedLocationIndex == null) return false;

    try {
      // 1. Start Activity Recognition
      await _initActivityRecognition();

      // 2. Trigger immediate check to decide strategy
      await _decideTrackingMode();

      return true;
    } catch (e) {
      logHere('$kLogInitialPositionFailed $e');
      return false;
    }
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

    final thresholdInMeters =
        _settingsProvider.notificationDistanceThresholdKm * 1000 +
            target.radius;

    if (_settingsProvider.isNotificationThresholdEnabled &&
        distanceInMeters > thresholdInMeters) {
      logHere(kLogDistanceAboveThreshold
          .replaceAll('%s', distanceInMeters.toStringAsFixed(0))
          .replaceAll('%r', thresholdInMeters.toStringAsFixed(0)));

      _notificationsPlugin.cancel(1);
      return;
    }

    final formattedDistance = UnitConverter.formatDistanceForDisplay(
      distanceInMeters,
      _settingsProvider.preferredUnitSystem,
    );

    if (!FlutterBackground.isBackgroundExecutionEnabled) return;

    final androidDetails = AndroidNotificationDetails(
      kNotificationTrackingChannelId,
      target.name,
      importance: Importance.high,
      priority: Priority.high,
      ongoing: true,
      autoCancel: false,
      showWhen: false,
      icon: 'ic_stat_notification',
      onlyAlertOnce: true,
      actions: [
        const AndroidNotificationAction(
          'STOP_TRACKING',
          btnDismissAlarm,
          showsUserInterface: true,
        ),
      ],
    );

    final details = NotificationDetails(android: androidDetails);

    await _notificationsPlugin.show(
        1, target.name, '$labelDistance $formattedDistance', details);
  }

  Future<void> _triggerAlarm(LocationModel location) async {
    if (_alarmTriggered) return;
    _alarmTriggered = true;
    currentSelectedLocation = location.name;

    final androidDetails = AndroidNotificationDetails(
        kNotificationAlarmChannelId, '$kReachedLocationPrefix${location.name}',
        importance: Importance.max,
        priority: Priority.high,
        fullScreenIntent: true,
        playSound: true,
        autoCancel: true,
        icon: 'ic_stat_notification');

    final details = NotificationDetails(android: androidDetails);
    await _notificationsPlugin.show(
        0, titleWakePointAlert, '$msgYouAreNear${location.name}.', details);

    if (_settingsProvider.useOverlayAlarmFeature) {
      const platform = MethodChannel(kMethodChannelAlarm);
      try {
        await platform.invokeMethod('startAlarm');
      } catch (e) {
        logHere('$kLogOverlayAlarmFailed $e');
      }
    }

    onAlarmTriggered?.call();
  }

  void _checkProximity(Position position, LocationModel target, double radius) {
    final distance = _locationService.calculateDistance(
      position.latitude,
      position.longitude,
      target.latitude,
      target.longitude,
    );
    if (distance <= radius && !_alarmTriggered) {
      _triggerAlarm(target);
    }
  }
}
