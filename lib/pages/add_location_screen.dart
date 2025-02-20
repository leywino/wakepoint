import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_places_flutter/google_places_flutter.dart';
import 'package:google_places_flutter/model/place_type.dart';
import 'package:provider/provider.dart';
import 'package:wakepoint/controller/location_provider.dart';
import 'package:wakepoint/core/api_key.dart';
import 'package:wakepoint/models/location_model.dart';

class AddLocationScreen extends StatefulWidget {
  const AddLocationScreen({super.key});

  @override
  State<AddLocationScreen> createState() => _AddLocationScreenState();
}

class _AddLocationScreenState extends State<AddLocationScreen> {
  final TextEditingController _searchController = TextEditingController();
  double _radius = 500;
  String? _selectedLocation;
  double? _selectedLat;
  double? _selectedLng;

  @override
  Widget build(BuildContext context) {
    final locationProvider = Provider.of<LocationProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: Text("Add Location", style: GoogleFonts.poppins(fontSize: 20)),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Search Location:",
                style: GoogleFonts.poppins(
                    fontSize: 18, fontWeight: FontWeight.w600)),
            const SizedBox(height: 10),
            GooglePlaceAutoCompleteTextField(
              placeType: PlaceType.cities,
              textEditingController: _searchController,
              googleAPIKey: kGoogleMapsApiKey,
              debounceTime: 800,
              countries: const ["in"],
              isLatLngRequired: true,
              getPlaceDetailWithLatLng: (placeDetail) {
                setState(() {
                  _selectedLocation =
                      placeDetail.structuredFormatting?.mainText ?? "";
                  _selectedLat = double.parse(placeDetail.lat!);
                  _selectedLng = double.parse(placeDetail.lng!);
                });
              },
            ),
            const SizedBox(height: 20),
            if (_selectedLocation != null)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("Selected Location:",
                      style: GoogleFonts.poppins(
                          fontSize: 18, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 5),
                  Text(_selectedLocation!,
                      style: GoogleFonts.poppins(fontSize: 16)),
                  Text("Lat: $_selectedLat, Lng: $_selectedLng",
                      style: GoogleFonts.poppins(
                          fontSize: 16, color: Colors.grey)),
                ],
              ),
            const SizedBox(height: 20),
            Text("Set Alarm Radius (m):",
                style: GoogleFonts.poppins(
                    fontSize: 18, fontWeight: FontWeight.w600)),
            Slider(
              value: _radius,
              min: 100,
              max: 5000,
              divisions: 50,
              label: "${_radius.toInt()} m",
              onChanged: (value) {
                setState(() {
                  _radius = value;
                });
              },
            ),
            const SizedBox(height: 30),
            Center(
              child: ElevatedButton.icon(
                onPressed: () {
                  if (_selectedLocation != null &&
                      _selectedLat != null &&
                      _selectedLng != null) {
                    locationProvider.addLocation(LocationModel(
                      name: _selectedLocation!,
                      latitude: _selectedLat!,
                      longitude: _selectedLng!,
                    ));
                    Navigator.pop(context);
                  }
                },
                style: ElevatedButton.styleFrom(
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 50, vertical: 15),
                ),
                icon: const Icon(Icons.alarm_add),
                label: Text(
                  "Set Alarm",
                  style: GoogleFonts.poppins(
                      fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
