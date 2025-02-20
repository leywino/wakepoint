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
  bool _isSelectionMode = false;
  final Set<int> _selectedItems = {};

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
      for (var index in _selectedItems.toList().reversed) {
        provider.removeLocation(index);
      }
      _selectedItems.clear();
      _isSelectionMode = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final locationProvider = Provider.of<LocationProvider>(context);
    return Scaffold(
      appBar: AppBar(
        title: Text("WakePoint", style: GoogleFonts.poppins(fontSize: 20)),
        actions: _isSelectionMode
            ? [
                IconButton(
                  icon: const Icon(Icons.delete, color: Colors.red),
                  onPressed: () => _deleteSelectedLocations(locationProvider),
                ),
              ]
            : [
                IconButton(
                  icon: Icon(locationProvider.isTracking
                      ? Icons.pause
                      : Icons.play_arrow),
                  onPressed: () {
                    locationProvider.toggleTracking();
                  },
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
                        final isSelected = _selectedItems.contains(index);
                        return GestureDetector(
                          onLongPress: () => _toggleSelectionMode(index),
                          onTap: () {
                            if (_isSelectionMode) {
                              _toggleSelectionMode(index);
                            } else {
                              locationProvider.setSelectedLocation(index);
                            }
                          },
                          child: Card(
                            elevation: 2,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16)),
                            color: isSelected
                                ? Colors.blue.withOpacity(0.3)
                                : null,
                            child: ListTile(
                              title: Text(location.name,
                                  style: GoogleFonts.poppins(fontSize: 16)),
                              subtitle: Text(
                                  "Lat: ${location.latitude}, Lng: ${location.longitude}"),
                              trailing: Radio<int>(
                                value: index,
                                groupValue:
                                    locationProvider.selectedLocationIndex,
                                onChanged: (value) {
                                  locationProvider.setSelectedLocation(value!);
                                },
                              ),
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
