import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:geolocator/geolocator.dart';
import 'package:provider/provider.dart';
import 'package:wakepoint/config/constants.dart';
import 'package:wakepoint/controller/location_provider.dart';
import 'package:wakepoint/controller/settings_provider.dart';
import 'package:wakepoint/models/location_model.dart';
import 'package:wakepoint/pages/add_location_screen.dart';
import 'package:wakepoint/pages/alarm_screen.dart';
import 'package:wakepoint/pages/settings_screen.dart';
import 'package:wakepoint/services/location_service.dart';
import 'package:wakepoint/utils/unit_converter.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _isSelectionMode = false;
  final Set<int> _selectedItems = {};
  Position? _initialPosition;

  @override
  void initState() {
    super.initState();
    _setupAlarmCallback();
    _fetchInitialPosition();
  }

  void _setupAlarmCallback() {
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

  void _navigateToLocationScreen() {
    Navigator.push(
      context,
      MaterialPageRoute(
          builder: (context) => AddLocationScreen(
                initialPosition: _initialPosition!,
              )),
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
      // Delete in reverse order to avoid index issues if multiple are selected
      for (var index in _selectedItems.toList().reversed) {
        provider.removeLocation(index);
      }
      _selectedItems.clear();
      _isSelectionMode = false;
    });
  }

  void _fetchInitialPosition() async {
    try {
      _initialPosition = await LocationService().getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      setState(() {});
    } catch (e) {
      _initialPosition = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer2<LocationProvider, SettingsProvider>(
      builder: (context, locationProvider, settingsProvider, child) {
        return Scaffold(
          appBar: _buildAppBar(locationProvider),
          body: Padding(
            padding: const EdgeInsets.all(s16),
            child: _buildBody(locationProvider, settingsProvider),
          ),
          floatingActionButton: _buildFloatingActionButton(),
        );
      },
    );
  }

  AppBar _buildAppBar(LocationProvider locationProvider) {
    return AppBar(
      title: const Text(appName,
          style: TextStyle(fontFamily: kDefaultFont, fontSize: s20)),
      actions: _isSelectionMode
          ? [_buildDeleteButton(locationProvider)]
          : [_buildTrackingAndSettingsButtons(locationProvider)],
    );
  }

  Widget _buildDeleteButton(LocationProvider locationProvider) {
    return IconButton(
      icon: const Icon(Icons.delete),
      onPressed: () => _deleteSelectedLocations(locationProvider),
    );
  }

  Widget _buildTrackingAndSettingsButtons(LocationProvider locationProvider) {
    return Row(
      children: [
        IconButton(
          icon: Icon(
            locationProvider.isTracking ? Icons.pause : Icons.play_arrow,
            size: s30,
          ),
          onPressed: () {
            locationProvider.toggleTracking();
          },
        ),
        IconButton(
          icon: const Icon(
            Icons.settings,
            size: s30,
          ),
          onPressed: _goToSettings,
        ),
      ],
    );
  }

  Widget _buildBody(
      LocationProvider locationProvider, SettingsProvider settingsProvider) {
    if (locationProvider.locations.isEmpty) {
      return _buildNoAlarmsMessage();
    } else {
      return _buildLocationList(locationProvider, settingsProvider);
    }
  }

  Widget _buildNoAlarmsMessage() {
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: s30),
      child: Center(
        child: Text(
          msgNoAlarms,
          textAlign: TextAlign.center,
          style: TextStyle(
              fontFamily: kDefaultFont, fontSize: s16, color: Colors.grey),
        ),
      ),
    );
  }

  Widget _buildLocationList(
      LocationProvider locationProvider, SettingsProvider settingsProvider) {
    return ListView.builder(
      itemCount: locationProvider.locations.length,
      itemBuilder: (context, index) {
        final location = locationProvider.locations[index];
        final isSelected = _selectedItems.contains(index);
        final isActive = locationProvider.selectedLocationIndex == index;

        return GestureDetector(
          onLongPress: () {
            if (locationProvider.isTracking) {
              Fluttertoast.showToast(msg: msgStopTrackingFirst);
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
            elevation: s2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(s16),
            ),
            color: isSelected
                ? Theme.of(context).colorScheme.primary.withValues(alpha: s05)
                : null,
            child: _buildLocationListItem(
                location, isActive, locationProvider, settingsProvider, index),
          ),
        );
      },
    );
  }

  Widget _buildLocationListItem(
    LocationModel location,
    bool isActive,
    LocationProvider locationProvider,
    SettingsProvider settingsProvider,
    int index,
  ) {
    String distanceText = labelNotTracking;
    if (locationProvider.isTracking &&
        locationProvider.currentPosition != null) {
      double distanceInMeters = LocationService().calculateDistance(
        locationProvider.currentPosition!.latitude,
        locationProvider.currentPosition!.longitude,
        location.latitude,
        location.longitude,
      );

      distanceText = "$labelDistance ${UnitConverter.formatDistanceForDisplay(
        distanceInMeters,
        settingsProvider.preferredUnitSystem,
      )}";
    }

    return ListTile(
      title: Text(
        location.name,
        style: const TextStyle(fontFamily: kDefaultFont, fontSize: s16),
      ),
      subtitle: Text(
        isActive
            ? "Lat: ${location.latitude.toStringAsFixed(4)}, Lng: ${location.longitude.toStringAsFixed(4)}\n$distanceText"
            : "Lat: ${location.latitude.toStringAsFixed(4)}, Lng: ${location.longitude.toStringAsFixed(4)}",
        style: const TextStyle(fontFamily: kDefaultFont, fontSize: s14),
      ),
      trailing: Radio<int>(
        value: index,
        groupValue: locationProvider.selectedLocationIndex,
        onChanged: (value) {
          locationProvider.setSelectedLocation(value!);
        },
      ),
    );
  }

  FloatingActionButton _buildFloatingActionButton() {
    return FloatingActionButton(
      onPressed: _initialPosition != null ? _navigateToLocationScreen : null,
      child: const Icon(Icons.add_location_alt, size: s28),
    );
  }
}
