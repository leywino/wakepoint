import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:geolocator/geolocator.dart';
import 'package:provider/provider.dart';
import 'package:wakepoint/controller/location_provider.dart';
import 'package:wakepoint/pages/add_location_screen.dart';
import 'package:wakepoint/pages/alarm_screen.dart';
import 'package:wakepoint/pages/settings_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _isSelectionMode = false;
  final Set<int> _selectedItems = {};

  @override
  void initState() {
    super.initState();
    Provider.of<LocationProvider>(context, listen: false).setAlarmCallback(
      () {
        if (mounted) {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const AlarmScreen()),
          );
        }
      },
    );
  }

  void _addLocation() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const AddLocationScreen()),
    );
  }

  void _goToSettings() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const SettingsScreen()),
    );
  }

  void _toggleSelectionMode(int index) {
    setState(() {
      if (_isSelectionMode) {
        if (_selectedItems.contains(index)) {
          _selectedItems.remove(index);
        } else {
          _selectedItems.add(index);
        }
        if (_selectedItems.isEmpty) {
          _isSelectionMode = false;
        }
      } else {
        _isSelectionMode = true;
        _selectedItems.add(index);
      }
    });
  }

  void _deleteSelectedLocations(LocationProvider provider) {
    setState(() {
      for (var index in _selectedItems.toList().reversed) {
        provider.removeLocation(index);
      }
      _selectedItems.clear();
      _isSelectionMode = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<LocationProvider>(
      builder: (context, locationProvider, child) {
        return Scaffold(
          appBar: AppBar(
            title: const Text("WakePoint",
                style: TextStyle(fontFamily: 'Poppins', fontSize: 20)),
            actions: _isSelectionMode
                ? [
                    IconButton(
                      icon: const Icon(Icons.delete),
                      onPressed: () =>
                          _deleteSelectedLocations(locationProvider),
                    ),
                  ]
                : [
                    Row(
                      children: [
                        IconButton(
                          icon: Icon(
                            locationProvider.isTracking
                                ? Icons.pause
                                : Icons.play_arrow,
                            size: 30,
                          ),
                          onPressed: () {
                            locationProvider.toggleTracking();
                          },
                        ),
                        IconButton(
                          icon: const Icon(
                            Icons.settings,
                            size: 30,
                          ),
                          onPressed: _goToSettings,
                        ),
                      ],
                    ),
                  ],
          ),
          body: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: locationProvider.locations.isEmpty
                      ? const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 30),
                          child: Center(
                            child: Text(
                              "There are no alarms, please add a location using the button below.",
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                  fontFamily: 'Poppins',
                                  fontSize: 16,
                                  color: Colors.grey),
                            ),
                          ),
                        )
                      : ListView.builder(
                          itemCount: locationProvider.locations.length,
                          itemBuilder: (context, index) {
                            final location = locationProvider.locations[index];
                            final isSelected = _selectedItems.contains(index);
                            final isActive =
                                locationProvider.selectedLocationIndex == index;

                            // Calculate distance if tracking is active
                            String distanceText = "Not Tracking";
                            if (locationProvider.isTracking &&
                                locationProvider.currentPosition != null) {
                              double distance = Geolocator.distanceBetween(
                                locationProvider.currentPosition!.latitude,
                                locationProvider.currentPosition!.longitude,
                                location.latitude,
                                location.longitude,
                              );
                              if (distance >= 1000) {
                                distanceText =
                                    "Distance: ${(distance / 1000).toStringAsFixed(1)} km";
                              } else {
                                distanceText =
                                    "Distance: ${distance.toStringAsFixed(0)} m";
                              }
                            }

                            return GestureDetector(
                              onLongPress: () {
                                if (locationProvider.isTracking) {
                                  Fluttertoast.showToast(
                                      msg:
                                          "Please stop tracking before selecting");
                                  return;
                                }
                                _toggleSelectionMode(index);
                              },
                              onTap: () {
                                if (_isSelectionMode) {
                                  _toggleSelectionMode(index);
                                } else {
                                  locationProvider.setSelectedLocation(index);
                                }
                              },
                              child: Card(
                                elevation: 2,
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16)),
                                color: isSelected
                                    ? Theme.of(context)
                                        .colorScheme
                                        .primary
                                        .withValues(alpha: 0.3)
                                    : null,
                                child: ListTile(
                                  title: Text(location.name,
                                      style: const TextStyle(
                                          fontFamily: 'Poppins', fontSize: 16)),
                                  subtitle: Text(
                                    isActive
                                        ? "Lat: ${location.latitude}, Lng: ${location.longitude}\n$distanceText"
                                        : "Lat: ${location.latitude}, Lng: ${location.longitude}",
                                    style: const TextStyle(
                                        fontFamily: "Poppins", fontSize: 14),
                                  ),
                                  trailing: Radio<int>(
                                    value: index,
                                    groupValue:
                                        locationProvider.selectedLocationIndex,
                                    onChanged: (value) {
                                      locationProvider
                                          .setSelectedLocation(value!);
                                    },
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
          floatingActionButton: FloatingActionButton(
            onPressed: _addLocation,
            child: const Icon(Icons.add_location_alt, size: 28),
          ),
        );
      },
    );
  }
}
