import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
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

const String _logTag = 'LocationProvider';
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
      settings: settings,
      onDidReceiveNotificationResponse: (response) {
        if (response.actionId == 'STOP_TRACKING') stopTracking();
      },
    );
  }

  Future<void> _decideTrackingMode() async {
    if (_selectedLocationIndex == null || !_isTracking) return;

    try {
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

      logHere(
        '📍 Check: ${(distance / 1000).toStringAsFixed(1)}km away. '
        'Speed: ${(position.speed).toStringAsFixed(1)} m/s',
      );

      if (distance <= kAdaptiveThreshold) {
        logHere(
            '🎯 Within ${(kAdaptiveThreshold / 1000).toStringAsFixed(0)}km. '
            'Switching to continuous GPS.');

        _adaptiveTimer?.cancel();
        _adaptiveTimer = null;

        if (!_isGpsActive) {
          _startGpsStream();
        }

        return;
      }

      if (_isGpsActive) {
        _stopGpsStream();
      }

      final int nextCheckSeconds;

      if (distance > 50000) {
        nextCheckSeconds = 300; // 5 minutes
      } else if (distance > 25000) {
        nextCheckSeconds = 180; // 3 minutes
      } else {
        nextCheckSeconds = 60; // 1 minute
      }

      logHere(
        '⏳ Target far. Next check in '
        '${(nextCheckSeconds / 60).toStringAsFixed(0)} min.',
      );

      _adaptiveTimer?.cancel();

      _adaptiveTimer = Timer(
        Duration(seconds: nextCheckSeconds),
        _decideTrackingMode,
      );
    } catch (e) {
      logHere('⚠️ Adaptive tracking check failed: $e');

      _adaptiveTimer?.cancel();
      _adaptiveTimer = Timer(
        const Duration(seconds: 60),
        _decideTrackingMode,
      );
    }
  }

  Future<void> _initActivityRecognition() async {
    await _activitySubscription?.cancel();
    _activitySubscription = null;

    bool isGranted = await Permission.activityRecognition.isGranted;
    if (!isGranted) {
      isGranted = await Permission.activityRecognition.request().isGranted;
    }

    if (isGranted) {
      logHere('🏃 Activity Permission Granted. Listening for movement...');
      _activitySubscription = FlutterActivityRecognition.instance.activityStream
          .listen(_handleActivityChange);
    } else {
      logHere('⚠️ Activity Permission Denied. Defaulting to Always-On GPS.');
      _startGpsStream();
    }
  }

  void _handleActivityChange(Activity activity) {
    logHere('Detected Activity: ${activity.type}');

    if (activity.type == ActivityType.STILL) {
      logHere('💤 Still. Pausing all location checks.');
      _stopGpsStream();
      _adaptiveTimer?.cancel();
    } else {
      if (!_isGpsActive &&
          (_adaptiveTimer == null || !_adaptiveTimer!.isActive)) {
        logHere('🚗 Moving. Calculating best tracking mode...');
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

  void renameLocation(LocationModel location, String name) {
    final index = _locations.indexWhere((item) => identical(item, location));
    if (index == -1) return;
    _locations[index] = location.copyWith(name: name);
    _saveLocations();
    notifyListeners();
  }

  void removeLocation(int index) {
    if (index < 0 || index >= _locations.length) return;
    if (_isTracking && _selectedLocationIndex == index) stopTracking();
    _locations.removeAt(index);
    if (_selectedLocationIndex == index) {
      _selectedLocationIndex = null;
    } else if (_selectedLocationIndex != null &&
        _selectedLocationIndex! > index) {
      _selectedLocationIndex = _selectedLocationIndex! - 1;
    }
    _saveLocations();
    notifyListeners();
  }

  void setSelectedLocation(int index) {
    if (index >= 0 && index < _locations.length) {
      _selectedLocationIndex = index;
      notifyListeners();
    }
  }

  Future<void> toggleTracking() async {
    if (_isTracking || _isInitializingTracking) {
      stopTracking();
      return;
    }
    if (_selectedLocationIndex == null) return;
    _isInitializingTracking = true;
    notifyListeners();
    final started = await _startTracking();
    if (!started) {
      _isInitializingTracking = false;
      _isTracking = false;
      notifyListeners();
      return;
    }
    _isTracking = true;
    _isInitializingTracking = false;
    await _startForegroundService();
    notifyListeners();
  }

  Future<void> _startForegroundService() async {
    const config = FlutterBackgroundAndroidConfig(
        notificationTitle: appName,
        notificationText: kNotificationTrackingText,
        notificationImportance: AndroidNotificationImportance.normal,
        enableWifiLock: true,
        notificationIcon:
            AndroidResource(name: 'ic_stat_notification', defType: 'drawable'));
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

    _notificationsPlugin.cancel(id: 1);
    _notificationsPlugin.cancel(id: 0);
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
      final position = await _locationService.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      final target = _locations[_selectedLocationIndex!];

      final distance = _locationService.calculateDistance(
        position.latitude,
        position.longitude,
        target.latitude,
        target.longitude,
      );

      if (distance <= target.radius) {
        logHere(
            '🚫 Already inside radius (${distance.toStringAsFixed(0)}m <= ${target.radius}m). Blocking start.');
        Fluttertoast.showToast(msg: msgAlreadyWithinRadius);
        return false;
      }

      await _initActivityRecognition();
      _isTracking = true;
      await _decideTrackingMode();
      // _startGpsStream();

      return true;
    } catch (e) {
      logHere('$kLogInitialPositionFailed $e');
      Fluttertoast.showToast(msg: msgLocationNotVerified);
      return false;
    }
  }

  void setAlarmCallback(VoidCallback callback) {
    onAlarmTriggered = callback;
  }

  Future<void> _sendRealtimeUpdate(
      Position position, LocationModel target) async {
    final rawDistanceToCenter = _locationService.calculateDistance(
      position.latitude,
      position.longitude,
      target.latitude,
      target.longitude,
    );

    final thresholdInMeters =
        _settingsProvider.notificationDistanceThresholdKm * 1000 +
            target.radius;

    if (_settingsProvider.isNotificationThresholdEnabled &&
        rawDistanceToCenter > thresholdInMeters) {
      logHere(kLogDistanceAboveThreshold
          .replaceAll('%s', rawDistanceToCenter.toStringAsFixed(0))
          .replaceAll('%r', thresholdInMeters.toStringAsFixed(0)));

      _notificationsPlugin.cancel(id: 1);
      return;
    }

    double distanceToEdge = rawDistanceToCenter - target.radius;
    if (distanceToEdge < 0) distanceToEdge = 0;

    final formattedDistance = UnitConverter.formatDistanceForDisplay(
      distanceToEdge,
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
        id: 1,
        title: target.name,
        body: '$labelDistance $formattedDistance',
        notificationDetails: details);
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
        id: 0,
        title: titleWakePointAlert,
        body: '$msgYouAreNear${location.name}.',
        notificationDetails: details);

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
