import 'package:material_ui/material_ui.dart';
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
    final selected = _selectedItems
        .where((index) => index >= 0 && index < provider.locations.length)
        .toList()
      ..sort();
    if (selected.isEmpty) return;
    final names =
        selected.map((index) => provider.locations[index].name).toList();
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          icon: Icon(Icons.delete_sweep_outlined,
              color: Theme.of(context).colorScheme.error, size: 32),
          title: Text(selected.length == 1
              ? 'Delete destination?'
              : 'Delete destinations?'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(selected.length == 1
                  ? '“${names.first}” will be removed from your saved destinations.'
                  : '${selected.length} destinations will be removed from your saved destinations.'),
              if (names.length > 1) ...[
                const SizedBox(height: 12),
                ...names.take(3).map((name) => Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Row(children: [
                        const Icon(Icons.place_outlined, size: 16),
                        const SizedBox(width: 8),
                        Expanded(
                            child: Text(name,
                                maxLines: 1, overflow: TextOverflow.ellipsis)),
                      ]),
                    )),
                if (names.length > 3)
                  Text('and ${names.length - 3} more',
                      style: Theme.of(context).textTheme.bodySmall),
              ],
            ],
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('Keep'),
            ),
            FilledButton.icon(
              style: FilledButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.error,
                  foregroundColor: Theme.of(context).colorScheme.onError),
              onPressed: () {
                Navigator.of(context).pop();
                setState(() {
                  for (var index in selected.reversed) {
                    provider.removeLocation(index);
                  }
                  _selectedItems.clear();
                  _isSelectionMode = false;
                  Fluttertoast.showToast(
                      msg: selected.length == 1
                          ? 'Destination deleted'
                          : '${selected.length} destinations deleted');
                });
              },
              icon: const Icon(Icons.delete_outline, size: 18),
              label: const Text('Delete'),
            )
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
            body: _buildBody(locationProvider, settingsProvider),
            floatingActionButton:
                _isSelectionMode ? null : _buildFloatingActionButton(),
            bottomNavigationBar:
                _isSelectionMode ? _buildSelectionBar(locationProvider) : null,
          ),
        );
      },
    );
  }

  AppBar _buildAppBar(LocationProvider locationProvider) {
    return AppBar(
      automaticallyImplyLeading: false,
      leading: _isSelectionMode
          ? IconButton(
              tooltip: 'Cancel selection',
              onPressed: _clearSelection,
              icon: const Icon(Icons.close_rounded),
            )
          : null,
      title: Text(
        _isSelectionMode ? '${_selectedItems.length} selected' : appName,
        style: const TextStyle(
          fontFamily: kDefaultFont,
          fontSize: s20,
          fontWeight: FontWeight.w600,
        ),
      ),
      actions: _isSelectionMode ? null : [_buildTrackingAndSettingsButtons()],
    );
  }

  Widget _buildSelectionBar(LocationProvider provider) {
    final theme = Theme.of(context);
    final singleSelection = _selectedItems.length == 1;
    final selectedIndex = singleSelection ? _selectedItems.first : null;
    final selectedLocation =
        selectedIndex != null && selectedIndex < provider.locations.length
            ? provider.locations[selectedIndex]
            : null;
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          border:
              Border(top: BorderSide(color: theme.colorScheme.outlineVariant)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: .06),
              blurRadius: 16,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: Row(
          children: [
            _SelectionAction(
              icon: Icons.close_rounded,
              label: 'Cancel',
              onPressed: _clearSelection,
            ),
            if (singleSelection && selectedLocation != null) ...[
              _SelectionAction(
                icon: Icons.edit_location_alt_outlined,
                label: 'Edit',
                onPressed: () {
                  _clearSelection();
                  _navigateToEditLocationScreen(selectedLocation);
                },
              ),
              _SelectionAction(
                icon: Icons.drive_file_rename_outline,
                label: 'Rename',
                onPressed: () => _showRenameDialog(selectedLocation, provider),
              ),
            ],
            _SelectionAction(
              icon: Icons.delete_outline_rounded,
              label: 'Delete',
              color: theme.colorScheme.error,
              onPressed: () => _deleteSelectedLocations(provider),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTrackingAndSettingsButtons() {
    return IconButton(
      tooltip: 'Settings',
      icon: const Icon(Icons.settings_outlined),
      onPressed: _goToSettings,
    );
  }

  Widget _buildBody(
      LocationProvider locationProvider, SettingsProvider settingsProvider) {
    final locations = locationProvider.locations;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      _buildOverview(locationProvider),
      Padding(
        padding: const EdgeInsets.fromLTRB(s20, s24, s20, s12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(
                child: Text(
                    _isSelectionMode
                        ? 'Choose destinations'
                        : 'Your destinations',
                    style: Theme.of(context)
                        .textTheme
                        .titleLarge
                        ?.copyWith(fontWeight: FontWeight.w700))),
            Text('${locations.length}',
                style: Theme.of(context)
                    .textTheme
                    .labelLarge
                    ?.copyWith(color: Theme.of(context).colorScheme.primary)),
          ]),
          if (locations.isNotEmpty && !_isSelectionMode) ...[
            const SizedBox(height: 3),
            Text('Tap to choose a trip · Long press to manage',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant)),
          ],
        ]),
      ),
      if (_isSelectionMode)
        Padding(
          padding: const EdgeInsets.fromLTRB(s20, 0, s20, s12),
          child: Text(
            _selectedItems.length == 1
                ? 'Select more places or use an action below.'
                : 'Select the places you want to remove.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
        ),
      Expanded(
          child: locations.isEmpty
              ? _buildNoAlarmsMessage()
              : _buildLocationList(locationProvider, settingsProvider)),
    ]);
  }

  Widget _buildOverview(LocationProvider provider) {
    final scheme = Theme.of(context).colorScheme;
    final active = provider.selectedLocationIndex != null &&
            provider.selectedLocationIndex! < provider.locations.length
        ? provider.locations[provider.selectedLocationIndex!]
        : null;
    return Container(
      margin: const EdgeInsets.fromLTRB(s20, s12, s20, 0),
      padding: const EdgeInsets.all(s20),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [
          scheme.primary,
          Color.lerp(scheme.primary, scheme.tertiary, .55)!
        ], begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(provider.isTracking ? Icons.my_location : Icons.route,
              color: scheme.onPrimary),
          const SizedBox(width: 10),
          Text(
              provider.isTracking
                  ? 'Tracking your trip'
                  : 'Ready for your next trip',
              style: TextStyle(
                  color: scheme.onPrimary.withValues(alpha: .82),
                  fontSize: 13)),
        ]),
        const SizedBox(height: 14),
        Text(
            provider.isTracking
                ? (active?.name ?? 'Destination')
                : (active?.name ?? 'Choose a destination'),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
                color: scheme.onPrimary,
                fontSize: 22,
                fontWeight: FontWeight.w700)),
        const SizedBox(height: 6),
        Text(
            provider.isTracking
                ? 'WakePoint is watching your location.'
                : active != null
                    ? 'Selected destination · Tap Start when you are ready.'
                    : 'Save a place, then select it to set your alarm.',
            style: TextStyle(
                color: scheme.onPrimary.withValues(alpha: .82), fontSize: 12)),
        if (active != null) ...[
          const SizedBox(height: 18),
          SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                    backgroundColor: scheme.surface,
                    foregroundColor: scheme.primary,
                    padding: const EdgeInsets.symmetric(vertical: 13)),
                onPressed: provider.isInitializingTracking
                    ? null
                    : provider.toggleTracking,
                icon: provider.isInitializingTracking
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : Icon(provider.isTracking
                        ? Icons.stop_rounded
                        : Icons.play_arrow_rounded),
                label: Text(
                    provider.isInitializingTracking
                        ? 'Getting your location…'
                        : provider.isTracking
                            ? 'Stop trip'
                            : 'Start trip',
                    style: const TextStyle(fontWeight: FontWeight.w700)),
              )),
        ],
      ]),
    );
  }

  Widget _buildNoAlarmsMessage() {
    return Center(
        child: Padding(
            padding: const EdgeInsets.all(s32),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.location_on_outlined,
                  size: 52, color: Theme.of(context).colorScheme.primary),
              const SizedBox(height: 14),
              Text('No destinations yet',
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.w700)),
              const SizedBox(height: 6),
              Text('Add your stop to get a wake up alert when you arrive.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context)
                      .textTheme
                      .bodyMedium
                      ?.copyWith(color: Theme.of(context).hintColor)),
              const SizedBox(height: 18),
              FilledButton.icon(
                  onPressed: _initialPosition != null
                      ? _navigateToLocationScreen
                      : null,
                  icon: const Icon(Icons.add_location_alt),
                  label: const Text('Add destination')),
            ])));
  }

  Widget _buildLocationList(
      LocationProvider locationProvider, SettingsProvider settingsProvider) {
    return RefreshIndicator(
      onRefresh: () => _fetchInitialPosition(),
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(s16, 0, s16, 100),
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
              elevation: 0,
              margin: const EdgeInsets.only(bottom: 10),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                  side: BorderSide(
                      color: isActive
                          ? Theme.of(context).colorScheme.primary
                          : Theme.of(context).colorScheme.outlineVariant)),
              color: isSelected || isActive
                  ? Theme.of(context).colorScheme.primary.withValues(alpha: .07)
                  : Theme.of(context).colorScheme.surface,
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
          distanceText.trim().isEmpty
              ? 'Radius · ${location.radius.round()} m'
              : distanceText.trim(),
          style: TextStyle(
              fontFamily: kDefaultFont,
              fontSize: 13,
              color: Theme.of(context).hintColor)),
      leading: CircleAvatar(
          backgroundColor: Theme.of(context).colorScheme.primaryContainer,
          foregroundColor: Theme.of(context).colorScheme.onPrimaryContainer,
          child: Icon(isActive ? Icons.flag_rounded : Icons.place_outlined)),
      trailing: _isSelectionMode
          ? Checkbox(
              value: _selectedItems.contains(index),
              onChanged: locationProvider.isTracking
                  ? null
                  : (_) => _toggleSelectionMode(index),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(6),
              ),
            )
          : RadioGroup<int>(
              onChanged: (value) {
                if (!locationProvider.isTracking && value != null) {
                  locationProvider.setSelectedLocation(value);
                }
              },
              groupValue: locationProvider.selectedLocationIndex,
              child: Radio<int>(value: index),
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

  Future<void> _showRenameDialog(
      LocationModel location, LocationProvider provider) async {
    final TextEditingController controller =
        TextEditingController(text: location.name);

    final name = await showDialog<String>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          icon: const Icon(Icons.drive_file_rename_outline),
          title: const Text('Rename destination'),
          content: TextField(
            controller: controller,
            autofocus: true,
            maxLength: 40,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              labelText: 'Destination name',
              hintText: hintLocationNameExample,
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.place_outlined),
            ),
            onChanged: (_) => setDialogState(() {}),
            onSubmitted: (_) {
              final value = controller.text.trim();
              if (value.isNotEmpty) Navigator.pop(context, value);
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: controller.text.trim().isEmpty
                  ? null
                  : () => Navigator.pop(context, controller.text.trim()),
              child: const Text('Save name'),
            ),
          ],
        ),
      ),
    );
    controller.dispose();
    if (name == null || name == location.name || !mounted) return;
    provider.renameLocation(location, name);
    _clearSelection();
    Fluttertoast.showToast(msg: 'Destination renamed');
  }
}

class _SelectionAction extends StatelessWidget {
  const _SelectionAction({
    required this.icon,
    required this.label,
    required this.onPressed,
    this.color,
  });

  final IconData icon;
  final String label;
  final VoidCallback onPressed;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final foreground = color ?? Theme.of(context).colorScheme.onSurfaceVariant;
    return Expanded(
      child: Semantics(
        button: true,
        label: label,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onPressed,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 5),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, color: foreground),
                const SizedBox(height: 3),
                Text(label,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: foreground,
                          fontWeight: FontWeight.w600,
                        )),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
