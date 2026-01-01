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
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _fetchInitialPosition();
    });
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
        ),
      ),
    );
  }

  void _navigateToEditLocationScreen(LocationModel locationToEdit) {
    if (_initialPosition == null) {
      Fluttertoast.showToast(
          msg: 'Please wait, fetching current location first.');
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AddLocationScreen(
          initialPosition: _initialPosition!,
          locationToEdit: locationToEdit,
        ),
      ),
    ).then((_) {
      _clearSelection();
    });
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
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text(titleConfirmDeletion),
          content: Text(msgConfirmDeleteSelected(_selectedItems.length)),
          actions: <Widget>[
            TextButton(
              child: const Text(btnCancel),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: const Text(btnSave),
              onPressed: () {
                Navigator.of(context).pop();
                setState(() {
                  for (var index in _selectedItems.toList().reversed) {
                    provider.removeLocation(index);
                  }
                  _selectedItems.clear();
                  _isSelectionMode = false;
                  Fluttertoast.showToast(msg: 'Location(s) deleted');
                });
              },
            ),
          ],
        );
      },
    );
  }

  Future<void> _fetchInitialPosition() async {
    Fluttertoast.showToast(
      msg: msgFetchingLocation,
      toastLength: Toast.LENGTH_SHORT,
    );

    try {
      _initialPosition = await LocationService().getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      if (mounted) {
        setState(() {});
      }
    } catch (e) {
      _initialPosition = null;
    }
  }

  void _clearSelection() {
    if (_isSelectionMode) {
      setState(() {
        _selectedItems.clear();
        _isSelectionMode = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer2<LocationProvider, SettingsProvider>(
      builder: (context, locationProvider, settingsProvider, child) {
        return GestureDetector(
          onTap: _clearSelection,
          behavior: HitTestBehavior.translucent,
          child: Scaffold(
            appBar: _buildAppBar(locationProvider),
            body: Padding(
              padding: const EdgeInsets.all(s16),
              child: _buildBody(locationProvider, settingsProvider),
            ),
            floatingActionButton: _buildFloatingActionButton(),
          ),
        );
      },
    );
  }

  AppBar _buildAppBar(LocationProvider locationProvider) {
    return AppBar(
      title: const Text(appName,
          style: TextStyle(fontFamily: kDefaultFont, fontSize: s20)),
      actions: _isSelectionMode
          ? _buildSelectionModeActions(locationProvider)
          : [_buildTrackingAndSettingsButtons(locationProvider)],
    );
  }

  List<Widget> _buildSelectionModeActions(LocationProvider locationProvider) {
    List<Widget> actions = [];
    if (_selectedItems.length == 1) {
      final int selectedIndex = _selectedItems.first;
      final LocationModel locationToEdit =
          locationProvider.locations[selectedIndex];
      actions.add(
        IconButton(
          icon: const Icon(Icons.edit),
          onPressed: () {
            _clearSelection();
            _navigateToEditLocationScreen(locationToEdit);
          },
        ),
      );
    }

    actions.add(_buildRenameButton(locationProvider));
    actions.add(_buildDeleteButton(locationProvider));
    return actions;
  }

  Widget _buildRenameButton(LocationProvider provider) {
    if (_selectedItems.length != 1) return const SizedBox.shrink();

    return IconButton(
      icon: const Icon(Icons.drive_file_rename_outline),
      tooltip: btnRename,
      onPressed: () {
        final index = _selectedItems.first;
        _showRenameDialog(provider.locations[index], provider);
      },
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
        if (locationProvider.selectedLocationIndex != null)
          IconButton(
            icon: Icon(
              locationProvider.isTracking ? Icons.stop : Icons.play_arrow,
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
    return RefreshIndicator(
      onRefresh: () => _fetchInitialPosition(),
      child: ListView.builder(
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
              if (locationProvider.isTracking) return;
              if (_isSelectionMode) {
                _toggleSelectionMode(index);
              } else {
                locationProvider.setSelectedLocation(index);
              }
            },
            child: Card(
              elevation: s2,
              color: isSelected
                  ? Theme.of(context).colorScheme.primary.withValues(alpha: s05)
                  : null,
              child: _buildLocationListItem(location, isActive,
                  locationProvider, settingsProvider, index),
            ),
          );
        },
      ),
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

    final currentPos = locationProvider.isTracking
        ? locationProvider.currentPosition
        : _initialPosition;

    if (currentPos != null) {
      double rawDistance = LocationService().calculateDistance(
        currentPos.latitude,
        currentPos.longitude,
        location.latitude,
        location.longitude,
      );

      double distanceToEdge = rawDistance - location.radius;
      if (distanceToEdge < 0) distanceToEdge = 0;

      distanceText = '\n$labelDistance ${UnitConverter.formatDistanceForDisplay(
        distanceToEdge, // <--- Use the adjusted distance
        settingsProvider.preferredUnitSystem,
      )}';
    } else {
      distanceText = '';
    }

    return ListTile(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(s16),
      ),
      tileColor: isActive
          ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.1)
          : null,
      title: Text(
        location.name,
        style: TextStyle(
          fontFamily: kDefaultFont,
          fontSize: s16,
          fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
        ),
      ),
      subtitle: Text(
        'Lat: ${location.latitude.toStringAsFixed(4)}, Lng: ${location.longitude.toStringAsFixed(4)}$distanceText',
        style: const TextStyle(fontFamily: kDefaultFont, fontSize: s14),
      ),
      trailing: RadioGroup<int>(
        onChanged: (value) {
          if (!locationProvider.isTracking) {
            locationProvider.setSelectedLocation(value!);
          }
        },
        groupValue: locationProvider.selectedLocationIndex,
        child: Radio<int>(
          value: index,
        ),
      ),
    );
  }

  FloatingActionButton _buildFloatingActionButton() {
    return FloatingActionButton(
      onPressed: _initialPosition != null ? _navigateToLocationScreen : null,
      child: _initialPosition != null
          ? const Icon(Icons.add_location_alt, size: s28)
          : const CircularProgressIndicator(),
    );
  }

  void _showRenameDialog(LocationModel location, LocationProvider provider) {
    final TextEditingController controller =
        TextEditingController(text: location.name);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text(titleRenameLocation),
        content: TextField(
          controller: controller,
          autofocus: true,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(
            labelText: labelLocationName,
            hintText: hintLocationNameExample,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(btnCancel),
          ),
          TextButton(
            onPressed: () {
              if (controller.text.trim().isNotEmpty) {
                // Create copy with new name
                final updated = location.copyWith(name: controller.text.trim());
                // Update via provider
                provider.editLocation(location.createdAt!, updated);
                Navigator.pop(context);
                _clearSelection(); // Exit selection mode
                Fluttertoast.showToast(msg: 'Renamed to ${controller.text}');
              }
            },
            child: const Text(btnSave),
          ),
        ],
      ),
    );
  }
}
