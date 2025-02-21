import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum ThemeSettings { system, light, dark }

List<LocationAccuracy> listOfAccuracy = [
  LocationAccuracy.best,
  LocationAccuracy.medium,
  LocationAccuracy.low,
];

class SettingsProvider with ChangeNotifier {
  SharedPreferences? prefs;

  SettingsProvider(this.prefs);

  double get radius {
    return prefs?.getDouble('default_radius') ?? 500;
  }

  set radius(double radius) {
    prefs?.setDouble('default_radius', radius);
    notifyListeners();
  }

  ThemeSettings get theme {
    return ThemeSettings
        .values[prefs?.getInt('theme') ?? ThemeSettings.system.index];
  }

  set theme(ThemeSettings t) {
    prefs?.setInt('theme', t.index);
    notifyListeners();
  }

  int get trackingAccuracy {
    return prefs?.getInt('tracking_accuracy') ?? 0;
  }

  set trackingAccuracy(int i) {
    prefs?.setInt('tracking_accuracy', i);
    notifyListeners();
  }

  bool get alarmVibration {
    return prefs?.getBool("alarm_vibration") ?? true;
  }

  set alarmVibration(bool enable) {
    prefs?.setBool('alarm_vibration', enable);
    notifyListeners();
  }

  bool get persistentNotification {
    return prefs?.getBool("persistent_notification") ?? true;
  }

  set persistentNotification(bool enable) {
    prefs?.setBool('persistent_notification', enable);
    notifyListeners();
  }

  bool get useOverlayAlarm {
    return prefs?.getBool("use_overlay_alarm") ?? false;
  }

  set useOverlayAlarm(bool enable) {
    prefs?.setBool('use_overlay_alarm', enable);
    notifyListeners();
  }
}
