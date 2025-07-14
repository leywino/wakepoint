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

  /// **🌍 Get Current Location & Reverse Geocode**
  Future<void> _useCurrentLocation() async {
    setState(() => _isFetchingLocation = true);

    try {
      Position position = await LocationService().getCurrentPosition();
      logHere(
          "📍 Current position: ${position.latitude}, ${position.longitude}");

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

      logHere("✅ Selected current location: $_selectedLocation");
    } catch (e) {
      logHere("⚠️ Error fetching location: $e");
      setState(() => _isFetchingLocation = false);
    }
  }

  void _fetchCurrentLocation() {
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final stopwatch = Stopwatch()..start();

      try {
        final position = await LocationService().getCurrentPosition();
        stopwatch.stop();

        final durationMs = stopwatch.elapsedMilliseconds;
        logHere("✅ Fetched current location in ${durationMs}ms: "
            "${position.latitude}, ${position.longitude}");

        setState(() {
          _initialPosition = position;
        });
      } catch (e) {
        stopwatch.stop();
        logHere("❌ Failed to fetch current location after "
            "${stopwatch.elapsedMilliseconds}ms: $e");
      }
    });
  }

  @override
  void initState() {
    _fetchCurrentLocation();
    super.initState();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final locationProvider = Provider.of<LocationProvider>(context);
    final theme = Theme.of(context);

    return GestureDetector(
      onTap: () {
        if (FocusScope.of(context).hasFocus) {
          FocusScope.of(context).unfocus();
        }
      },
      child: Scaffold(
        appBar: AppBar(),
        body: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              /// **🌍 "Use Current Location" Button**
              Center(
                child: ElevatedButton.icon(
                  onPressed: _isFetchingLocation ? null : _useCurrentLocation,
                  style: ElevatedButton.styleFrom(
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 12),
                  ),
                  icon: const Icon(
                    Icons.my_location,
                  ),
                  label: Text(
                    _isFetchingLocation
                        ? labelFetching
                        : hintUseCurrentLocation,
                    style: const TextStyle(fontFamily: kDefaultFont),
                  ),
                ),
              ),
              sizedBoxH15,

              /// **Search Box (Autocomplete Places OR Manual Entry)**
              AutoCompleteTextField(
                controller: _searchController,
                apiKey: dotenv.env['OLA_MAPS_API_KEY']!,
                debounceTime: 800,
                longitude: _initialPosition?.longitude,
                latitude: _initialPosition?.latitude,
                decoration: InputDecoration(
                  hintText: hintEnterPlace,
                  hintStyle: TextStyle(
                      fontFamily: kDefaultFont, color: theme.hintColor),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(width: 0.5)),
                  filled: true,
                  fillColor: theme.cardColor,
                  prefixIcon: const Icon(
                    Icons.search,
                  ),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
                onItemTap: (prediction) {
                  final location = prediction.geometry!.location!;
                  final locationName = prediction.description;

                  setState(() {
                    _selectedLocation = locationName;
                    _selectedLat = location.lat!.toDouble();
                    _selectedLng = location.lng!.toDouble();
                    logHere(
                        "📍 Prediction coordinates set: $_selectedLat, $_selectedLng");
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

                  logHere("✅ Manual coordinates detected and set: $lat, $lng");
                },
              ),
              sizedBoxH25,

              /// **📌 Selected Location Preview**
              if (_selectedLocation != null)
                Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                  color: theme.cardColor,
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(_selectedLocation!,
                            style: const TextStyle(
                                fontFamily: kDefaultFont, fontSize: 18)),
                        Text("Lat: $_selectedLat, Lng: $_selectedLng",
                            style: TextStyle(
                                fontFamily: kDefaultFont,
                                fontSize: 16,
                                color: theme.textTheme.bodySmall?.color)),
                      ],
                    ),
                  ),
                ),
              sizedBoxH25,
            ],
          ),
        ),
        floatingActionButton: ElevatedButton.icon(
          onPressed: () {
            if (_selectedLocation != null &&
                _selectedLat != null &&
                _selectedLng != null) {
              locationProvider.addLocation(LocationModel(
                name: _selectedLocation!,
                latitude: _selectedLat!,
                longitude: _selectedLng!,
                isEnabled: true,
              ));
              logHere(
                  "📌 Location added: $_selectedLocation ($_selectedLat, $_selectedLng)");
              Navigator.pop(context);
            }
          },
          icon: const Icon(Icons.add_location),
          label: const Text(labelAddLocation),
        ),
      ),
    );
  }
}
