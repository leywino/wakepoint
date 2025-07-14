import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:geolocator/geolocator.dart';
import 'package:provider/provider.dart';
import 'package:wakepoint/config/constants.dart';
import 'package:wakepoint/controller/location_provider.dart';
import 'package:wakepoint/models/location_model.dart';
import 'package:geocoding/geocoding.dart';
import 'package:wakepoint/services/location_service.dart';
import 'package:wakepoint/widgets/auto_complete_textfield.dart';
import 'package:wakepoint/utils/utils.dart';

const String _logTag = "AddLocationScreen";
void logHere(String message) => log(message, tag: _logTag);

class AddLocationScreen extends StatefulWidget {
  const AddLocationScreen({super.key});

  @override
  State<AddLocationScreen> createState() => _AddLocationScreenState();
}

class _AddLocationScreenState extends State<AddLocationScreen> {
  final TextEditingController _searchController = TextEditingController();
  String? _selectedLocation;
  double? _selectedLat;
  double? _selectedLng;
  bool _isFetchingLocation = false;
  Position? _initialPosition;

  @override
  void initState() {
    _fetchCurrentLocationForAutocomplete();
    super.initState();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _useCurrentLocation() async {
    setState(() => _isFetchingLocation = true);
    try {
      Position position = await LocationService().getCurrentPosition();
      logHere("Current position: ${position.latitude}, ${position.longitude}");

      List<Placemark> placemarks =
          await placemarkFromCoordinates(position.latitude, position.longitude);

      String locationName = placemarks.isNotEmpty
          ? [
              placemarks.first.locality,
              placemarks.first.administrativeArea,
              placemarks.first.postalCode,
              placemarks.first.country
            ].where((e) => e != null && e.isNotEmpty).join(', ')
          : labelCurrentLocation;

      setState(() {
        _selectedLocation = locationName;
        _selectedLat = position.latitude;
        _selectedLng = position.longitude;
        _isFetchingLocation = false;
      });
      logHere("Selected current location: $_selectedLocation");
    } catch (e) {
      logHere("Error fetching location: $e");
      setState(() => _isFetchingLocation = false);
    }
  }

  void _fetchCurrentLocationForAutocomplete() {
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final stopwatch = Stopwatch()..start();
      try {
        final position = await LocationService().getCurrentPosition();
        stopwatch.stop();
        final durationMs = stopwatch.elapsedMilliseconds;
        logHere(
            "Fetched current location in ${durationMs}ms: ${position.latitude}, ${position.longitude}");
        setState(() {
          _initialPosition = position;
        });
      } catch (e) {
        stopwatch.stop();
        logHere(
            "Failed to fetch current location after ${stopwatch.elapsedMilliseconds}ms: $e");
      }
    });
  }

  void _addSelectedLocation() {
    if (_selectedLocation != null && _selectedLat != null && _selectedLng != null) {
      Provider.of<LocationProvider>(context, listen: false).addLocation(LocationModel(
        name: _selectedLocation!,
        latitude: _selectedLat!,
        longitude: _selectedLng!,
        isEnabled: true,
      ));
      logHere("Location added: $_selectedLocation ($_selectedLat, $_selectedLng)");
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        if (FocusScope.of(context).hasFocus) {
          FocusScope.of(context).unfocus();
        }
      },
      child: Scaffold(
        appBar: AppBar(),
        body: Padding(
          padding: const EdgeInsets.all(s20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildUseCurrentLocationButton(),
              verticalSpaceMedium, // Replaced sizedBoxH15
              _buildSearchAutoCompleteField(context),
              verticalSpaceMassive, // Replaced sizedBoxH25
              if (_selectedLocation != null) _buildSelectedLocationPreview(context),
              verticalSpaceMassive, // Replaced sizedBoxH25
            ],
          ),
        ),
        floatingActionButton: _buildAddLocationButton(),
      ),
    );
  }

  Widget _buildUseCurrentLocationButton() {
    return Center(
      child: ElevatedButton.icon(
        onPressed: _isFetchingLocation ? null : _useCurrentLocation,
        style: ElevatedButton.styleFrom(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(s10)),
          padding: const EdgeInsets.symmetric(horizontal: s20, vertical: s12),
        ),
        icon: const Icon(Icons.my_location),
        label: Text(
          _isFetchingLocation ? labelFetching : hintUseCurrentLocation,
          style: const TextStyle(fontFamily: kDefaultFont),
        ),
      ),
    );
  }

  Widget _buildSearchAutoCompleteField(BuildContext context) {
    final theme = Theme.of(context);
    return AutoCompleteTextField(
      controller: _searchController,
      apiKey: dotenv.env['OLA_MAPS_API_KEY']!,
      debounceTime: 800,
      longitude: _initialPosition?.longitude,
      latitude: _initialPosition?.latitude,
      decoration: InputDecoration(
        hintText: hintEnterPlace,
        hintStyle: TextStyle(fontFamily: kDefaultFont, color: theme.hintColor),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(s10),
          borderSide: const BorderSide(width: 0.5),
        ),
        filled: true,
        fillColor: theme.cardColor,
        prefixIcon: const Icon(Icons.search),
        contentPadding: const EdgeInsets.symmetric(horizontal: s16, vertical: s12),
      ),
      onItemTap: (prediction) {
        final location = prediction.geometry!.location!;
        final locationName = prediction.description;
        setState(() {
          _selectedLocation = locationName;
          _selectedLat = location.lat!.toDouble();
          _selectedLng = location.lng!.toDouble();
          logHere("Prediction coordinates set: $_selectedLat, $_selectedLng");
        });
      },
      onManualLatLngDetected: (lat, lng) async {
        final placemarks = await placemarkFromCoordinates(lat, lng);
        String locationName = placemarks.isNotEmpty
            ? [
                placemarks.first.locality,
                placemarks.first.administrativeArea,
                placemarks.first.postalCode,
                placemarks.first.country
              ].where((e) => e != null && e.isNotEmpty).join(', ')
            : labelCurrentLocation;

        setState(() {
          _selectedLat = lat;
          _selectedLng = lng;
          _selectedLocation = locationName;
        });
        logHere("Manual coordinates detected and set: $lat, $lng");
      },
    );
  }

  Widget _buildSelectedLocationPreview(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      elevation: s2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(s10)),
      color: theme.cardColor,
      child: Padding(
        padding: const EdgeInsets.all(s12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _selectedLocation!,
              style: const TextStyle(fontFamily: kDefaultFont, fontSize: s18),
            ),
            Text(
              "Lat: ${_selectedLat!.toStringAsFixed(4)}, Lng: ${_selectedLng!.toStringAsFixed(4)}",
              style: TextStyle(
                fontFamily: kDefaultFont,
                fontSize: s16,
                color: theme.textTheme.bodySmall?.color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAddLocationButton() {
    return ElevatedButton.icon(
      onPressed: (_selectedLocation != null && _selectedLat != null && _selectedLng != null)
          ? _addSelectedLocation
          : null,
      icon: const Icon(Icons.add_location),
      label: const Text(labelAddLocation),
    );
  }
}