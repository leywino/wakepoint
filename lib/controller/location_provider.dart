import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wakepoint/config/constants.dart';
import 'package:wakepoint/controller/settings_provider.dart';
import 'package:wakepoint/models/location_model.dart';
import 'package:wakepoint/services/geofence_service.dart';
import 'package:wakepoint/services/location_service.dart';
import 'package:wakepoint/utils/utils.dart';

const String _logTag = 'LocationProvider';
void logHere(String message) => log(message, tag: _logTag);

class LocationProvider with ChangeNotifier {
  final SettingsProvider _settingsProvider;
  final LocationService _locationService;
  final GeofenceService _geofenceService = GeofenceService();

  List<LocationModel> _locations = [];
  int? _selectedLocationIndex;
  bool _isTracking = false;
  bool _alarmTriggered = false;
  String? currentSelectedLocation;
  VoidCallback? onAlarmTriggered;
  LocationModel? _pendingArrivalLocation;
  late bool _lastThresholdEnabled;
  late double _lastThresholdKm;
  late bool _lastPersistentNotification;

  final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();
  late final Future<void> _notificationsReady;

  LocationProvider(this._settingsProvider, this._locationService) {
    _lastThresholdEnabled = _settingsProvider.isNotificationThresholdEnabled;
    _lastThresholdKm = _settingsProvider.notificationDistanceThresholdKm;
    _lastPersistentNotification =
        _settingsProvider.enablePersistentNotification;
    _settingsProvider.addListener(_onSettingsChanged);
    _notificationsReady = _initNotifications();
    _geofenceService.setEventHandler(_handleGeofenceEvent);
    _loadLocations();
  }

  List<LocationModel> get locations => _locations;
  int? get selectedLocationIndex => _selectedLocationIndex;
  bool get isTracking => _isTracking;
  // Geofencing deliberately avoids continuous fixes, so don't show a stale
  // distance from the point where the trip was started.
  Position? get currentPosition =>
      _isTracking ? null : _locationService.currentPosition;
  bool _isInitializingTracking = false;
  bool get isInitializingTracking => _isInitializingTracking;

  Future<void> _registerGeofence(LocationModel target) {
    final radius = target.radius < 100 ? 100.0 : target.radius;
    final approachRadius = _settingsProvider.isNotificationThresholdEnabled
        ? _settingsProvider.notificationDistanceThresholdKm * 1000 + radius
        : 0.0;
    return _geofenceService.register(
      tripId: target.createdAt!.toIso8601String(),
      name: target.name,
      latitude: target.latitude,
      longitude: target.longitude,
      arrivalRadiusMeters: radius,
      approachRadiusMeters: approachRadius,
    );
  }

  void _onSettingsChanged() {
    final enabled = _settingsProvider.isNotificationThresholdEnabled;
    final thresholdKm = _settingsProvider.notificationDistanceThresholdKm;
    final persistentNotification =
        _settingsProvider.enablePersistentNotification;
    final thresholdChanged =
        enabled != _lastThresholdEnabled || thresholdKm != _lastThresholdKm;
    final persistentChanged =
        persistentNotification != _lastPersistentNotification;
    _lastThresholdEnabled = enabled;
    _lastThresholdKm = thresholdKm;
    _lastPersistentNotification = persistentNotification;
    final index = _selectedLocationIndex;
    if (!_isTracking || index == null || index >= _locations.length) return;
    if (thresholdChanged) {
      _registerGeofence(_locations[index]).catchError((error) {
        logHere('Unable to update the approach geofence: $error');
      });
    }
    if (persistentChanged) {
      if (persistentNotification) {
        _showTrackingNotification(_locations[index]);
      } else {
        _notificationsPlugin.cancel(id: 1);
      }
    }
  }

  Future<void> _initNotifications() async {
    const androidSettings =
        AndroidInitializationSettings('ic_stat_notification');
    const settings = InitializationSettings(android: androidSettings);

    await _notificationsPlugin.initialize(
      settings: settings,
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
    final activeTripId = prefs.getString('active_trip_created_at');
    if (activeTripId != null) {
      final activeIndex = _locations.indexWhere(
        (location) => location.createdAt?.toIso8601String() == activeTripId,
      );
      if (activeIndex >= 0) {
        _selectedLocationIndex = activeIndex;
        _isTracking = true;
        final target = _locations[activeIndex];
        try {
          await _registerGeofence(target);
          await _showTrackingNotification(target);
        } catch (error) {
          logHere('Unable to restore destination geofence: $error');
          try {
            await _geofenceService.remove();
          } catch (removeError) {
            logHere('Unable to clear restored geofence: $removeError');
          }
          _isTracking = false;
          _selectedLocationIndex = null;
          await prefs.remove('active_trip_created_at');
        }
        notifyListeners();
      } else {
        await prefs.remove('active_trip_created_at');
      }
    }
    final pendingEvent = await _geofenceService.consumePendingEvent();
    if (pendingEvent != null) await _handleGeofenceEvent(pendingEvent);
  }

  Future<void> _saveLocations() async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = jsonEncode(_locations.map((e) => e.toJson()).toList());
    await prefs.setString('saved_locations', encoded);
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
    if (_isTracking) {
      await stopTracking();
      return;
    }
    if (_isInitializingTracking) return;
    if (_selectedLocationIndex == null) return;
    _isInitializingTracking = true;
    notifyListeners();
    final started = await _startTracking();
    if (!started || !_isInitializingTracking) {
      _isInitializingTracking = false;
      _isTracking = false;
      notifyListeners();
      return;
    }
    _isTracking = true;
    _isInitializingTracking = false;
    final prefs = await SharedPreferences.getInstance();
    final target = _locations[_selectedLocationIndex!];
    target.createdAt ??= DateTime.now();
    await _saveLocations();
    await prefs.setString(
      'active_trip_created_at',
      target.createdAt!.toIso8601String(),
    );
    await _showTrackingNotification(target);
    notifyListeners();
  }

  Future<void> _showTrackingNotification(LocationModel target) async {
    if (!_settingsProvider.enablePersistentNotification) return;
    await _notificationsReady;
    final androidDetails = AndroidNotificationDetails(
      kNotificationTrackingChannelId,
      'Trip monitoring',
      importance: Importance.low,
      priority: Priority.low,
      ongoing: true,
      autoCancel: false,
      showWhen: false,
      icon: 'ic_stat_notification',
      onlyAlertOnce: true,
      actions: [
        const AndroidNotificationAction(
          'STOP_TRACKING',
          'Stop trip',
          showsUserInterface: true,
        ),
      ],
    );
    await _notificationsPlugin.show(
      id: 1,
      title: 'Monitoring ${target.name}',
      body: 'WakePoint will alert you as you approach your destination.',
      notificationDetails: NotificationDetails(android: androidDetails),
    );
  }

  Future<void> stopTracking() async {
    _alarmTriggered = false;
    _isTracking = false;
    _isInitializingTracking = false;
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('active_trip_created_at');
    try {
      await _geofenceService.remove();
    } catch (error) {
      logHere('Unable to remove destination geofence: $error');
    }
    await _notificationsReady;
    await _notificationsPlugin.cancel(id: 1);
    await _notificationsPlugin.cancel(id: 0);
  }

  Future<bool> _startTracking() async {
    if (_selectedLocationIndex == null) return false;

    try {
      if (!await _geofenceService.canUseFullScreenIntent()) {
        await _geofenceService.openAlarmPresentationSettings();
        Fluttertoast.showToast(
          msg:
              'Allow WakePoint alarm notifications and full-screen access, then start again.',
        );
        return false;
      }

      final position = await _locationService.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      final target = _locations[_selectedLocationIndex!];
      target.createdAt ??= DateTime.now();

      final distance = _locationService.calculateDistance(
        position.latitude,
        position.longitude,
        target.latitude,
        target.longitude,
      );

      final effectiveRadius = target.radius < 100 ? 100.0 : target.radius;
      if (distance <= effectiveRadius) {
        logHere(
            'Already inside geofence radius (${distance.toStringAsFixed(0)}m <= ${effectiveRadius.toStringAsFixed(0)}m). Blocking start.');
        Fluttertoast.showToast(msg: msgAlreadyWithinRadius);
        return false;
      }

      final permission = await Geolocator.checkPermission();
      if (permission != LocationPermission.always) {
        final backgroundPermission = await Permission.locationAlways.request();
        if (!backgroundPermission.isGranted) {
          Fluttertoast.showToast(
            msg: 'Allow background location to monitor your trip.',
          );
          return false;
        }
      }

      await _registerGeofence(target);

      return true;
    } catch (e) {
      logHere('$kLogInitialPositionFailed $e');
      Fluttertoast.showToast(msg: 'Could not start destination monitoring.');
      return false;
    }
  }

  void setAlarmCallback(VoidCallback callback) {
    onAlarmTriggered = callback;
    final pending = _pendingArrivalLocation;
    if (pending != null) {
      _pendingArrivalLocation = null;
      _triggerAlarm(pending);
    }
  }

  @override
  void dispose() {
    _settingsProvider.removeListener(_onSettingsChanged);
    super.dispose();
  }

  Future<void> _handleGeofenceEvent(Map<String, dynamic> event) async {
    if (event['type'] != 'arrival') return;
    final tripId = event['tripId']?.toString();
    final name = event['name']?.toString();
    LocationModel? target;
    for (final location in _locations) {
      if ((tripId != null && location.createdAt?.toIso8601String() == tripId) ||
          (tripId == null && location.name == name)) {
        target = location;
        break;
      }
    }
    if (target == null &&
        _selectedLocationIndex != null &&
        _selectedLocationIndex! < _locations.length) {
      target = _locations[_selectedLocationIndex!];
    }
    if (target == null) {
      logHere('Received destination arrival without a saved destination.');
      return;
    }
    if (onAlarmTriggered == null) {
      _pendingArrivalLocation = target;
      return;
    }
    _triggerAlarm(target);
  }

  void _triggerAlarm(LocationModel location) {
    if (_alarmTriggered) return;
    _alarmTriggered = true;
    currentSelectedLocation = location.name;
    onAlarmTriggered?.call();
  }
}
