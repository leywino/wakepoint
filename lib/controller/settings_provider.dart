import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum AppTheme { system, light, dark }

List<LocationAccuracy> locationAccuracyOptions = [
  LocationAccuracy.best,
  LocationAccuracy.medium,
  LocationAccuracy.low,
];

class SettingsProvider with ChangeNotifier {
  final SharedPreferences? _prefs;

  SettingsProvider(this._prefs);

  double get alarmRadius {
    return _prefs?.getDouble('alarm_radius') ?? 1000;
  }

  set alarmRadius(double radius) {
    _prefs?.setDouble('alarm_radius', radius);
    notifyListeners();
  }

  AppTheme get theme {
    return AppTheme
        .values[_prefs?.getInt('app_theme') ?? AppTheme.system.index];
  }

  set theme(AppTheme t) {
    _prefs?.setInt('app_theme', t.index);
    notifyListeners();
  }

  int get locationTrackingAccuracy {
    return _prefs?.getInt('location_tracking_accuracy') ?? 0;
  }

  set locationTrackingAccuracy(int i) {
    _prefs?.setInt('location_tracking_accuracy', i);
    notifyListeners();
  }

  bool get enableAlarmVibration {
    return _prefs?.getBool("enable_alarm_vibration") ?? true;
  }

  set enableAlarmVibration(bool enable) {
    _prefs?.setBool('enable_alarm_vibration', enable);
    notifyListeners();
  }

  bool get enablePersistentNotification {
    return _prefs?.getBool("enable_persistent_notification") ?? true;
  }

  set enablePersistentNotification(bool enable) {
    _prefs?.setBool('enable_persistent_notification', enable);
    notifyListeners();
  }

  bool get useOverlayAlarmFeature {
    return _prefs?.getBool("use_overlay_alarm_feature") ?? false;
  }

  set useOverlayAlarmFeature(bool enable) {
    _prefs?.setBool('use_overlay_alarm_feature', enable);
    notifyListeners();
  }

  double get notificationDistanceThresholdKm {
    return _prefs?.getDouble('notification_distance_threshold_km') ?? 5.0;
  }

  set notificationDistanceThresholdKm(double threshold) {
    _prefs?.setDouble('notification_distance_threshold_km', threshold);
    notifyListeners();
  }

  bool get isNotificationThresholdEnabled {
    return _prefs?.getBool('is_notification_threshold_enabled') ?? false;
  }

  set isNotificationThresholdEnabled(bool enable) {
    _prefs?.setBool('is_notification_threshold_enabled', enable);
    notifyListeners();
  }
}
