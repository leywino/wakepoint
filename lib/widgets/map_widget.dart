import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:provider/provider.dart';
import 'package:wakepoint/config/constants.dart';
import 'package:wakepoint/controller/settings_provider.dart';
import 'package:wakepoint/utils/utils.dart';

class MapWidget extends StatefulWidget {
  const MapWidget({
    super.key,
    this.selectedLatLng,
    required this.initialPosition,
    required this.onMapCreated,
    this.isDark = false,
    this.onTap,
  });

  final LatLng? selectedLatLng;
  final LatLng initialPosition;
  final Function(GoogleMapController) onMapCreated;
  final bool isDark;
  final Function(LatLng)? onTap;

  @override
  State<MapWidget> createState() => _MapWidgetState();
}

class _MapWidgetState extends State<MapWidget> {
  late GoogleMapController _mapController;
  double _radius = 150;
  double _currentZoom = 15;
  String? _mapStyle;

  @override
  void initState() {
    super.initState();
    _loadMapStyle();
  }

  Future<void> _loadMapStyle() async {
    if (widget.isDark) {
      final style = await rootBundle.loadString(kaDarkModeJson);
      if (mounted) {
        setState(() => _mapStyle = style);
      }
    }
  }

  double _calculateZoomLevel(double radius) {
    if (radius <= 50) return 18.5;
    if (radius <= 100) return 18.0;
    if (radius <= 150) return 17.5;
    if (radius <= 200) return 17.0;
    if (radius <= 250) return 16.5;
    if (radius <= 300) return 16.0;
    if (radius <= 400) return 15.5;
    if (radius <= 500) return 15.0;
    if (radius <= 750) return 14.5;
    if (radius <= 1000) return 14.0;
    if (radius <= 1500) return 13.5;
    if (radius <= 2000) return 13.0;
    if (radius <= 2500) return 12.5;
    if (radius <= 3000) return 12.4;
    if (radius <= 3500) return 12.3;
    if (radius <= 4000) return 12.2;
    if (radius <= 4500) return 12.1;
    if (radius <= 5000) return 12.0;
    return 9.0;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(child: _buildMap()),
        if (widget.selectedLatLng != null) _buildRadiusSlider(),
      ],
    );
  }

  Widget _buildMap() {
    return GoogleMap(
      initialCameraPosition: CameraPosition(
        target: widget.initialPosition,
        zoom: _currentZoom,
      ),
      myLocationEnabled: true,
      myLocationButtonEnabled: true,
      markers: _buildMarkers(),
      circles: _buildCircles(),
      onMapCreated: (controller) {
        _mapController = controller;
        widget.onMapCreated(controller);
      },
      onTap: (latLng) {
        widget.onTap?.call(latLng);
        if (widget.selectedLatLng != null) {
          _mapController.animateCamera(
            CameraUpdate.newLatLngZoom(latLng, _currentZoom),
          );
        }
      },
      style: _mapStyle,
    );
  }

  Set<Marker> _buildMarkers() {
    if (widget.selectedLatLng == null) return {};
    return {
      Marker(
        markerId: const MarkerId('selected'),
        position: widget.selectedLatLng!,
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
      ),
    };
  }

  Set<Circle> _buildCircles() {
    if (widget.selectedLatLng == null) return {};
    return {
      Circle(
        circleId: const CircleId('selected'),
        center: widget.selectedLatLng!,
        radius: _radius,
        strokeWidth: 2,
        strokeColor: Colors.red,
        fillColor: Colors.red.withValues(alpha: 0.2),
      ),
    };
  }

  Widget _buildRadiusSlider() {
    final theme = Theme.of(context);
    final settingsProvider =
        Provider.of<SettingsProvider>(context, listen: false);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: s15, vertical: s12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Radius: ${UnitConverter.formatDistanceForDisplay(_radius, settingsProvider.preferredUnitSystem)}',
            style: TextStyle(
              fontSize: s14,
              fontWeight: FontWeight.bold,
              fontFamily: kDefaultFont,
              color: theme.colorScheme.onSurface,
            ),
          ),
          Slider(
            padding: EdgeInsets.zero,
            value: _radius,
            min: ksRadiusOptions.first.toDouble(),
            max: ksRadiusOptions.last.toDouble(),
            divisions: ksRadiusOptions.length - 1,
            onChanged: (newVal) {
              final snapped = ksRadiusOptions.reduce(
                  (a, b) => (a - newVal).abs() < (b - newVal).abs() ? a : b);

              setState(() {
                _radius = snapped.toDouble();
                _currentZoom = _calculateZoomLevel(_radius);
              });

              if (widget.selectedLatLng != null) {
                _mapController.animateCamera(
                  CameraUpdate.newLatLngZoom(
                      widget.selectedLatLng!, _currentZoom),
                );
              }
            },
            label: _radius.round().toString(),
            activeColor: theme.colorScheme.primary,
            inactiveColor: theme.colorScheme.primary.withValues(alpha: 0.3),
          ),
        ],
      ),
    );
  }
}
