import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsProvider with ChangeNotifier {
  double _defaultRadius = 500;

  double get defaultRadius => _defaultRadius;

  SettingsProvider() {
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    _defaultRadius = prefs.getDouble('default_radius') ?? 500;
    notifyListeners();
  }

  Future<void> setDefaultRadius(double radius) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('default_radius', radius);
    _defaultRadius = radius;
    notifyListeners();
  }
}