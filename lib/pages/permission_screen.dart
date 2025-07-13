import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wakepoint/config/constants.dart';
import 'package:wakepoint/pages/home_screen.dart';

class PermissionScreen extends StatefulWidget {
  const PermissionScreen({super.key});

  @override
  State<PermissionScreen> createState() => _PermissionScreenState();
}

class _PermissionScreenState extends State<PermissionScreen> {
  bool _locationGranted = false;
  bool _notificationGranted = false;
  bool _batteryGranted = false;
  bool _overlayGranted = false;

  @override
  void initState() {
    super.initState();
    _checkPermissions();
  }

  /// **Check all permissions on screen load**
  Future<void> _checkPermissions() async {
    _locationGranted =
        await Geolocator.checkPermission() == LocationPermission.always;
    _notificationGranted = await Permission.notification.isGranted;
    _batteryGranted = await Permission.ignoreBatteryOptimizations.isGranted;
    _overlayGranted = await Permission.systemAlertWindow.isGranted;

    setState(() {});
  }

  /// **Request Location Permission using Geolocator**
  Future<void> _requestLocationPermission() async {
    final permission = await Geolocator.checkPermission();

    if (permission == LocationPermission.denied) {
      final newPermission = await Geolocator.requestPermission();

      if (newPermission == LocationPermission.always ||
          newPermission == LocationPermission.whileInUse) {
        setState(() => _locationGranted = true);
      }

      // If only whileInUse is granted, request locationAlways
      if (newPermission == LocationPermission.whileInUse) {
        final alwaysStatus = await Permission.locationAlways.request();
        if (alwaysStatus.isGranted) {
          setState(() => _locationGranted = true);
        }
      }
    } else if (permission == LocationPermission.whileInUse) {
      final alwaysStatus = await Permission.locationAlways.request();
      if (alwaysStatus.isGranted) {
        setState(() => _locationGranted = true);
      }
    } else if (permission == LocationPermission.deniedForever) {
      _openAppSettingsDialog(permLocation);
    } else if (permission == LocationPermission.always) {
      setState(() => _locationGranted = true);
    }
  }

  /// **Request Notification Permission**
  Future<void> _requestNotificationPermission() async {
    final status = await Permission.notification.request();
    if (status.isGranted) {
      setState(() => _notificationGranted = true);
    } else if (status.isPermanentlyDenied) {
      _openAppSettingsDialog(permNotification);
    }
  }

  /// **Request Battery Optimization Permission**
  Future<void> _requestBatteryPermission() async {
    final status = await Permission.ignoreBatteryOptimizations.request();
    if (status.isGranted) {
      setState(() => _batteryGranted = true);
    } else if (status.isPermanentlyDenied) {
      _openAppSettingsDialog(permBattery);
    }
  }

  /// **Request Overlay Permission**
  Future<void> _requestOverlayPermission() async {
    final status = await Permission.systemAlertWindow.request();
    if (status.isGranted) {
      setState(() => _overlayGranted = true);
    } else if (status.isPermanentlyDenied) {
      _openAppSettingsDialog(permOverlay);
    }
  }

  /// **Dialog for opening App Settings when permission is permanently denied**
  void _openAppSettingsDialog(String permissionName) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("$permissionName Required"),
        content: Text(
         msgPermissionExplanation(permissionName),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(btnCancel),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await openAppSettings();
            },
            child: const Text(btnOpenSettings),
          ),
        ],
      ),
    );
  }

  /// **Save first launch & navigate to home screen**
  Future<void> _completeSetup() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool("first_launch_completed", true);
    if (mounted) {
      Navigator.pushReplacement(
          context, MaterialPageRoute(builder: (context) => const HomeScreen()));
    }
  }

  @override
  Widget build(BuildContext context) {
    final isMandatoryGranted = _locationGranted && _notificationGranted;

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 40),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.rocket_launch_rounded,
                size: 50, color: Theme.of(context).colorScheme.primary),
            const SizedBox(height: 16),
            Text(
              titleWelcome,
              style: Theme.of(context)
                  .textTheme
                  .headlineSmall
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              msgPickDefaults,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 30),

            // Required Permissions Section
            _buildPermissionCard(
              title: labelRequired,
              permissions: [
                _buildPermissionTile(
                    permLocation,
                    msgLocationRequired,
                    _locationGranted,
                    _requestLocationPermission),
                _buildPermissionTile(
                    permNotification,
                    msgNotificationRequired,
                    _notificationGranted,
                    _requestNotificationPermission),
              ],
            ),

            // Optional Permissions Section
            _buildPermissionCard(
              title: labelOptional,
              permissions: [
                _buildPermissionTile(
                    permBattery,
                    msgBatteryRecommended,
                    _batteryGranted,
                    _requestBatteryPermission),
                _buildPermissionTile(
                    permOverlay,
                    msgOverlayRecommended,
                    _overlayGranted,
                    _requestOverlayPermission),
              ],
            ),

            const Spacer(),

            // Get Started Button
            ElevatedButton(
              onPressed: isMandatoryGranted ? _completeSetup : null,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 15),
                minimumSize: const Size(double.infinity, 50),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
              ),
              child: const Text(btnGetStarted),
            ),
          ],
        ),
      ),
    );
  }

  /// **Build Permission Card**
  Widget _buildPermissionCard(
      {required String title, required List<Widget> permissions}) {
    return Card(
      elevation: 2,
      clipBehavior: Clip.hardEdge,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 10),
            ...permissions,
          ],
        ),
      ),
    );
  }

  /// **Build Permission Tile**
  Widget _buildPermissionTile(String title, String description, bool isGranted,
      VoidCallback onPressed) {
    return ListTile(
      title: Text(title),
      subtitle: Text(description),
      trailing: ElevatedButton(
        onPressed: isGranted ? null : onPressed,
        style: ElevatedButton.styleFrom(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
        child: Text(isGranted ? labelGranted : btnGrant),
      ),
    );
  }
}
