import 'dart:developer';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_places_flutter/google_places_flutter.dart';
import 'package:provider/provider.dart';
import 'package:wakepoint/controller/location_provider.dart';
import 'package:wakepoint/core/api_key.dart';
import 'package:wakepoint/models/location_model.dart';
import 'package:geocoding/geocoding.dart';

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

  void _processManualInput(String input) async {
    List<String> parts = input.split(",");
    if (parts.length == 2) {
      double? lat = double.tryParse(parts[0].trim());
      double? lng = double.tryParse(parts[1].trim());
      if (lat != null && lng != null) {
        try {
          List<Placemark> placemarks = await placemarkFromCoordinates(lat, lng);
          String name = placemarks.isNotEmpty
              ? placemarks.first.locality ?? "Unknown Location"
              : "Unknown Location";
          setState(() {
            _selectedLocation = name;
            _selectedLat = lat;
            _selectedLng = lng;
          });
        } catch (e) {
          log("Error retrieving location name: $e");
        }
      }
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
          title: Text("Add Location", style: GoogleFonts.poppins(fontSize: 20)),
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
                    label: Text("Search", style: GoogleFonts.poppins()),
                    selected: !_isManualEntry,
                    onSelected: (selected) =>
                        setState(() => _isManualEntry = !selected),
                  ),
                  const SizedBox(width: 10),
                  ChoiceChip(
                    label: Text("Manual Entry", style: GoogleFonts.poppins()),
                    selected: _isManualEntry,
                    onSelected: (selected) =>
                        setState(() => _isManualEntry = selected),
                  ),
                ],
              ),
              const SizedBox(height: 15),
              Container(
                // Container for consistent styling
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
                            hintStyle:
                                GoogleFonts.poppins(color: theme.hintColor),
                            border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide: const BorderSide(width: 0.5)),
                            filled: true,
                            fillColor: theme.cardColor,
                            prefixIcon: Icon(Icons.pin_drop,
                                color: theme.iconTheme.color),
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
                        googleAPIKey: kGoogleMapsApiKey,
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
                          hintStyle:
                              GoogleFonts.poppins(color: theme.hintColor),
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
              if (_selectedLocation != null)
                Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                  color: theme.cardColor,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(_selectedLocation!,
                          style: GoogleFonts.poppins(fontSize: 18)),
                      Text("Lat: $_selectedLat, Lng: $_selectedLng",
                          style: GoogleFonts.poppins(
                              fontSize: 16,
                              color: theme.textTheme.bodySmall?.color)),
                    ],
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
                longitude: _selectedLng!,isEnabled: true,
              ));
              Navigator.pop(context);
            }
          },
          style: ElevatedButton.styleFrom(
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 15),
            backgroundColor: theme.colorScheme.primary,
          ),
          icon: Icon(Icons.add_alarm, color: theme.colorScheme.onPrimary),
          label: Text("Set Alarm",
              style: TextStyle(color: theme.colorScheme.onPrimary)),
        ),
      ),
    );
  }
}
