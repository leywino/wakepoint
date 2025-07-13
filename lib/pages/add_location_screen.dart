import 'dart:developer';
import 'package:flutter/material.dart';
import 'package:google_places_flutter/google_places_flutter.dart';
import 'package:open_location_code/open_location_code.dart';
import 'package:provider/provider.dart';
import 'package:wakepoint/controller/location_provider.dart';
import 'package:wakepoint/models/location_model.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';

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
  bool _isManualEntry = false;
  bool _isFetchingLocation = false;

  /// **🌍 Get Current Location & Reverse Geocode**
  Future<void> _useCurrentLocation() async {
    setState(() => _isFetchingLocation = true);

    try {
      Position position = await Geolocator.getCurrentPosition();
      List<Placemark> placemarks =
          await placemarkFromCoordinates(position.latitude, position.longitude);

      String locationName = placemarks.isNotEmpty
          ? placemarks.first.locality ?? "Current Location"
          : "Current Location";

      setState(() {
        _selectedLocation = locationName;
        _selectedLat = position.latitude;
        _selectedLng = position.longitude;
        _isFetchingLocation = false;
      });
    } catch (e) {
      log("⚠️ Error fetching location: $e");
      setState(() => _isFetchingLocation = false);
    }
  }

  /// **📝 Process Manual Coordinates Input**
  void _processManualInput(String input) async {
    try {
      double? lat;
      double? lng;

      final parts = input.split(",");
      final isLatLng =
          parts.length == 2 && double.tryParse(parts[0].trim()) != null;

      if (isLatLng) {
        lat = double.tryParse(parts[0].trim());
        lng = double.tryParse(parts[1].trim());
      } else {
        final plusCode = PlusCode.unverified(input);
        if (plusCode.isValid) {
          final codeArea = plusCode.decode();
          lat = codeArea.center.latitude;
          lng = codeArea.center.longitude;
        }
      }

      if (lat != null && lng != null) {
        final placemarks = await placemarkFromCoordinates(lat, lng);
        final name = placemarks.isNotEmpty
            ? placemarks.first.locality ?? "Unknown Location"
            : "Unknown Location";

        setState(() {
          _selectedLocation = name;
          _selectedLat = lat;
          _selectedLng = lng;
        });
      }
    } catch (e) {
      debugPrint("⚠️ Error processing manual input: $e");
    }
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
        appBar: AppBar(
          title: const Text("Add Location",
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 20,
              )),
          centerTitle: true,
          elevation: 0,
          backgroundColor: theme.canvasColor,
          iconTheme: theme.iconTheme,
        ),
        body: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ChoiceChip(
                    label: const Text("Search",
                        style: TextStyle(fontFamily: 'Poppins')),
                    selected: !_isManualEntry,
                    onSelected: (selected) =>
                        setState(() => _isManualEntry = !selected),
                  ),
                  const SizedBox(width: 10),
                  ChoiceChip(
                    label: const Text("Manual Entry",
                        style: TextStyle(fontFamily: 'Poppins')),
                    selected: _isManualEntry,
                    onSelected: (selected) =>
                        setState(() => _isManualEntry = selected),
                  ),
                ],
              ),
              const SizedBox(height: 15),

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
                        ? "Fetching..."
                        : "Use Current Location",
                    style: const TextStyle(fontFamily: 'Poppins'),
                  ),
                ),
              ),
              const SizedBox(height: 15),

              /// **Search Box (Google Places OR Manual Entry)**
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(),
                ),
                child: _isManualEntry
                    ? TextField(
                        controller: _searchController,
                        onChanged: (value) {
                          if (value.contains(",")) {
                            _processManualInput(value);
                          }
                        },
                        keyboardType: TextInputType.text,
                        decoration: InputDecoration(
                            hintText: "Paste or enter coordinates (lat,lng)",
                            hintStyle: TextStyle(
                                fontFamily: 'Poppins', color: theme.hintColor),
                            border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide: const BorderSide(width: 0.5)),
                            filled: true,
                            fillColor: theme.cardColor,
                            prefixIcon: const Icon(
                              Icons.pin_drop,
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 12),
                            suffixIcon: _searchController.text.isNotEmpty
                                ? IconButton(
                                    onPressed: () {
                                      _searchController.clear();
                                    },
                                    icon: const Icon(Icons.close))
                                : null),
                      )
                    : GooglePlaceAutoCompleteTextField(
                        textEditingController: _searchController,
                        googleAPIKey: "kGoogleMapsApiKey",
                        debounceTime: 800,
                        countries: const ["in"],
                        isLatLngRequired: true,
                        getPlaceDetailWithLatLng: (placeDetail) {
                          Future.delayed(const Duration(milliseconds: 500), () {
                            setState(() {
                              _selectedLocation =
                                  placeDetail.structuredFormatting?.mainText ??
                                      "";
                              _selectedLat = double.parse(placeDetail.lat!);
                              _selectedLng = double.parse(placeDetail.lng!);
                            });
                          });
                        },
                        inputDecoration: InputDecoration(
                          hintText: "Enter a city",
                          hintStyle: TextStyle(
                            fontFamily: 'Poppins',
                            color: theme.hintColor,
                          ),
                          border: InputBorder.none,
                          prefixIcon:
                              Icon(Icons.search, color: theme.iconTheme.color),
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 12),
                        ),
                        itemClick: (postalCodeResponse) {
                          FocusScope.of(context).unfocus();
                          _searchController.clear();
                        },
                      ),
              ),
              const SizedBox(height: 25),

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
                                fontFamily: 'Poppins', fontSize: 18)),
                        Text("Lat: $_selectedLat, Lng: $_selectedLng",
                            style: TextStyle(
                                fontFamily: 'Poppins',
                                fontSize: 16,
                                color: theme.textTheme.bodySmall?.color)),
                      ],
                    ),
                  ),
                ),
              const SizedBox(height: 25),
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
              Navigator.pop(context);
            }
          },
          icon: const Icon(Icons.add_alarm),
          label: const Text("Set Alarm"),
        ),
      ),
    );
  }
}
