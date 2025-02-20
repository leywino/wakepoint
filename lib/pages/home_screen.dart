import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:wakepoint/controller/location_provider.dart';
import 'package:wakepoint/pages/add_location_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  void initState() {
    super.initState();
    Provider.of<LocationProvider>(context, listen: false).loadLocations();
  }

  void _addLocation() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const AddLocationScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final locationProvider = Provider.of<LocationProvider>(context);
    return Scaffold(
      appBar: AppBar(
        title: Text("WakePoint", style: GoogleFonts.poppins(fontSize: 20)),
        actions: [
          Switch(
            value: locationProvider.isEnabled,
            onChanged: (value) => locationProvider.toggleEnabled(),
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
                  ? Center(
                      child: Text(
                        "There are no alarms, please add a location using the button below.",
                        textAlign: TextAlign.center,
                        style: GoogleFonts.poppins(
                            fontSize: 16, color: Colors.grey),
                      ),
                    )
                  : ListView.builder(
                      itemCount: locationProvider.locations.length,
                      itemBuilder: (context, index) {
                        final location = locationProvider.locations[index];
                        return Card(
                          elevation: 2,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16)),
                          child: ListTile(
                            title: Text(location.name,
                                style: GoogleFonts.poppins(fontSize: 16)),
                            subtitle: Text(
                                "Lat: ${location.latitude}, Lng: ${location.longitude}"),
                            trailing: IconButton(
                              icon: const Icon(Icons.delete, color: Colors.red),
                              onPressed: () =>
                                  locationProvider.removeLocation(index),
                            ),
                          ),
                        );
                      },
                    ),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: _addLocation,
              style: ElevatedButton.styleFrom(
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
                padding:
                    const EdgeInsets.symmetric(horizontal: 50, vertical: 15),
              ),
              icon: const Icon(Icons.add_location_alt),
              label: Text(
                "Add Location",
                style: GoogleFonts.poppins(
                    fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
