import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:provider/provider.dart';
import 'package:wakepoint/config/constants.dart';
import 'package:wakepoint/controller/google_search_provider.dart';
import 'package:wakepoint/controller/location_provider.dart';
import 'package:wakepoint/models/location_model.dart';
import 'package:geocoding/geocoding.dart';
import 'package:wakepoint/models/place.dart';
import 'package:wakepoint/widgets/auto_complete_textfield.dart';
import 'package:wakepoint/utils/utils.dart';
import 'package:wakepoint/widgets/map_widget.dart';

const String _logTag = "AddLocationScreen";
void logHere(String message) => log(message, tag: _logTag);

class AddLocationScreen extends StatefulWidget {
  const AddLocationScreen({
    super.key,
    required this.initialPosition,
    this.locationToEdit,
  });

  final Position initialPosition;
  final LocationModel? locationToEdit;

  @override
  State<AddLocationScreen> createState() => _AddLocationScreenState();
}

class _AddLocationScreenState extends State<AddLocationScreen> {
  final TextEditingController _searchController = TextEditingController();
  GoogleMapController? _mapController;
  LatLng? _selectedLatLng;
  String? _selectedLocationName;
  double _radius = 150;
  DateTime? _originalCreatedAt;

  Future<void> _updateLocation(String name, LatLng latLng) async {
    setState(() {
      _selectedLocationName = name;
      _selectedLatLng = latLng;
    });

    _mapController?.animateCamera(CameraUpdate.newLatLng(latLng));
    logHere(
        "Updated location: $name at ${latLng.latitude}, ${latLng.longitude}");
  }

  Future<String> _reverseGeocode(double lat, double lng) async {
    try {
      final placemarks = await placemarkFromCoordinates(lat, lng);
      final placemark = placemarks.first;
      return [
        placemark.locality,
        placemark.administrativeArea,
        placemark.postalCode,
        placemark.country
      ].where((e) => e != null && e.isNotEmpty).join(', ');
    } catch (e) {
      logHere("Reverse geocoding failed: $e");
      return labelCurrentLocation;
    }
  }

  void _saveLocation() {
    final provider = Provider.of<LocationProvider>(context, listen: false);
    final newLocation = LocationModel(
      name: _selectedLocationName!,
      latitude: _selectedLatLng!.latitude,
      longitude: _selectedLatLng!.longitude,
      isEnabled: widget.locationToEdit?.isEnabled ?? true,
      radius: _radius,
      createdAt: DateTime.now(),
    );

    if (widget.locationToEdit != null) {
      provider.editLocation(_originalCreatedAt!, newLocation);
      logHere("Location updated: $_selectedLocationName at $_selectedLatLng");
      Fluttertoast.showToast(msg: msgLocationUpdated);
    } else {
      provider.addLocation(newLocation);
      logHere("Location added: $_selectedLocationName at $_selectedLatLng");
      Fluttertoast.showToast(msg: msgLocationAdded);
    }

    Navigator.pop(context);
  }

  _init() {
    if (widget.locationToEdit != null) {
      _selectedLocationName = widget.locationToEdit!.name;
      // _searchController.text = _selectedLocationName!;
      _selectedLatLng = LatLng(
          widget.locationToEdit!.latitude, widget.locationToEdit!.longitude);
      _radius = widget.locationToEdit!.radius;
      _originalCreatedAt = widget.locationToEdit!.createdAt;
    } else {
      _selectedLatLng = LatLng(
          widget.initialPosition.latitude, widget.initialPosition.longitude);
      _reverseGeocode(_selectedLatLng!.latitude, _selectedLatLng!.longitude)
          .then((name) {
        setState(() {
          _selectedLocationName = name;
          // _searchController.text = name;
        });
      });
    }
  }

  @override
  void initState() {
    _init();
    super.initState();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        appBar: AppBar(
          title: Text(
              widget.locationToEdit != null
                  ? labelEditLocation
                  : labelAddLocation,
              style: const TextStyle(fontFamily: kDefaultFont)),
          centerTitle: true,
        ),
        body: Column(
          children: [
            _buildSearchField(context),
            Expanded(
              child: MapWidget(
                initialPosition: _selectedLatLng!,
                isDark: isDark,
                onMapCreated: (controller) => _mapController = controller,
                selectedLatLng: _selectedLatLng,
                radius: _radius,
                onTap: (latLng) async {
                  final name =
                      await _reverseGeocode(latLng.latitude, latLng.longitude);
                  await _updateLocation(name, latLng);
                },
                onRadiusChanged: (radius) {
                  setState(() {
                    _radius = radius;
                  });
                },
              ),
            ),
            _buildSaveButton(context),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchField(BuildContext context) {
    final theme = Theme.of(context);
    final borderSide = BorderSide(width: s08, color: theme.dividerColor);

    return Container(
      decoration: BoxDecoration(border: Border(bottom: borderSide)),
      child: AutoCompleteTextField(
        controller: _searchController,
        apiKey: dotenv.env['GOOGLE_PLACES_API_KEY']!,
        searchProvider: GoogleSearchProvider(),
        debounceTime: 800,
        latitude: widget.initialPosition.latitude,
        longitude: widget.initialPosition.longitude,
        decoration: InputDecoration(
          hintText: hintEnterPlace,
          hintStyle:
              TextStyle(fontFamily: kDefaultFont, color: theme.hintColor),
          filled: true,
          fillColor: theme.cardColor,
          prefixIcon: const Icon(Icons.search),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: s16, vertical: s12),
        ),
        onPlaceSelected: (Place place) async {
          final latLng =
              LatLng(place.latitude.toDouble(), place.longitude.toDouble());
          final name = place.name;
          _searchController.text = name;
          await _updateLocation(name, latLng);
        },
        onManualLatLngDetected: (lat, lng) async {
          final name = await _reverseGeocode(lat, lng);
          _searchController.text = name;
          await _updateLocation(name, LatLng(lat, lng));
          // FocusScope.of(context).unfocus();
        },
      ),
    );
  }

  Widget _buildSaveButton(BuildContext context) {
    final isEnabled = _selectedLatLng != null && _selectedLocationName != null;
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(s8),
      alignment: Alignment.bottomRight,
      child: ElevatedButton.icon(
        onPressed: isEnabled ? _saveLocation : null,
        // icon: const Icon(Icons.save, size: s20),
        label: const Text(
          'Save',
          style: TextStyle(
              fontSize: s16,
              fontWeight: FontWeight.bold,
              fontFamily: kDefaultFont),
        ),
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: s20, vertical: s8),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(s0)),
          backgroundColor: theme.colorScheme.primary,
          foregroundColor: theme.colorScheme.onPrimary,
          disabledBackgroundColor:
              theme.colorScheme.primary.withValues(alpha: 0.3),
          disabledForegroundColor:
              theme.colorScheme.onPrimary.withValues(alpha: 0.5),
          elevation: 4,
        ),
      ),
    );
  }
}
