import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wakepoint/models/location_model.dart';

class LocationProvider with ChangeNotifier {
  List<LocationModel> _locations = [];
  bool _isEnabled = true;

  List<LocationModel> get locations => _locations;
  bool get isEnabled => _isEnabled;

  void toggleEnabled() {
    _isEnabled = !_isEnabled;
    notifyListeners();
  }

  Future<void> loadLocations() async {
    final prefs = await SharedPreferences.getInstance();
    final String? locationsString = prefs.getString('saved_locations');
    if (locationsString != null) {
      final List<dynamic> locationsJson = jsonDecode(locationsString);
      _locations = locationsJson.map((e) => LocationModel.fromJson(e)).toList();
      notifyListeners();
    }
  }

  Future<void> saveLocations() async {
    final prefs = await SharedPreferences.getInstance();
    final String locationsString = jsonEncode(_locations.map((e) => e.toJson()).toList());
    prefs.setString('saved_locations', locationsString);
  }

  void addLocation(LocationModel location) {
    _locations.add(location);
    saveLocations();
    notifyListeners();
  }

  void removeLocation(int index) {
    _locations.removeAt(index);
    saveLocations();
    notifyListeners();
  }
}