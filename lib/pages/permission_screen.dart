import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wakepoint/config/constants.dart';
import 'package:wakepoint/controller/settings_provider.dart';
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
  bool _activityGranted = false;

  @override
  void initState() {
    super.initState();
    _checkPermissions();
  }

  /// Check all permissions on screen load
  Future<void> _checkPermissions() async {
    _locationGranted =
        await Geolocator.checkPermission() == LocationPermission.always;
    _notificationGranted = await Permission.notification.isGranted;
    _batteryGranted = await Permission.ignoreBatteryOptimizations.isGranted;
    _overlayGranted = await Permission.systemAlertWindow.isGranted;
    _activityGranted = await Permission.activityRecognition.isGranted;
    setState(() {});
  }

  /// Request Location Permission using Geolocator
  Future<void> _requestLocationPermission() async {
    final permission = await Geolocator.checkPermission();

    if (permission == LocationPermission.denied) {
      final newPermission = await Geolocator.requestPermission();

      if (newPermission == LocationPermission.always ||
          newPermission == LocationPermission.whileInUse) {
        setState(() => _locationGranted = true);
      }

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

  /// Request Notification Permission
  Future<void> _requestNotificationPermission() async {
    final status = await Permission.notification.request();
    if (status.isGranted) {
      setState(() => _notificationGranted = true);
    } else if (status.isPermanentlyDenied) {
      _openAppSettingsDialog(permNotification);
    }
  }

  /// Request Battery Optimization Permission
  Future<void> _requestBatteryPermission() async {
    final status = await Permission.ignoreBatteryOptimizations.request();
    if (status.isGranted) {
      setState(() => _batteryGranted = true);
    } else if (status.isPermanentlyDenied) {
      _openAppSettingsDialog(permBattery);
    }
  }

  /// Request Overlay Permission
  Future<void> _requestOverlayPermission() async {
    final settingsProvider =
        Provider.of<SettingsProvider>(context, listen: false);
    final status = await Permission.systemAlertWindow.request();
    if (status.isGranted) {
      setState(() {
        _overlayGranted = true;
        settingsProvider.useOverlayAlarmFeature = true;
      });
    } else if (status.isPermanentlyDenied) {
      _openAppSettingsDialog(permOverlay);
    }
  }

  Future<void> _requestActivityPermission() async {
    final status = await Permission.activityRecognition.request();
    if (status.isGranted) {
      setState(() => _activityGranted = true);
    } else if (status.isPermanentlyDenied) {
      _openAppSettingsDialog("Activity Recognition");
    }
  }

  /// Dialog for opening App Settings when permission is permanently denied
  void _openAppSettingsDialog(String permissionName) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          "$permissionName Required",
          style: Theme.of(context).textTheme.titleLarge,
        ),
        content: Text(
          msgPermissionExplanation(permissionName),
          style: Theme.of(context).textTheme.bodyMedium,
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

  /// Save first launch & navigate to home screen
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
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding:
                    const EdgeInsets.symmetric(horizontal: s20, vertical: s24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildHeader(),
                    verticalSpaceSmall,
                    _buildDescription(context),
                    const SizedBox(height: 24),
                    _buildPermissionSection(
                      context,
                      title: labelRequired,
                      permissions: [
                        _buildFlatPermissionTile(
                          permLocation,
                          msgLocationRequired,
                          _locationGranted,
                          _requestLocationPermission,
                        ),
                        _buildFlatPermissionTile(
                          permNotification,
                          msgNotificationRequired,
                          _notificationGranted,
                          _requestNotificationPermission,
                        ),
                        _buildFlatPermissionTile(
                          permActivity,
                          msgActivityRequired,
                          _activityGranted,
                          _requestActivityPermission,
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _buildPermissionSection(
                      context,
                      title: labelOptional,
                      permissions: [
                        _buildFlatPermissionTile(
                          permBattery,
                          msgBatteryRecommended,
                          _batteryGranted,
                          _requestBatteryPermission,
                        ),
                        _buildFlatPermissionTile(
                          permOverlay,
                          msgOverlayRecommended,
                          _overlayGranted,
                          _requestOverlayPermission,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: _buildGetStartedButton(isMandatoryGranted),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFlatPermissionTile(String title, String description,
      bool isGranted, VoidCallback onPressed) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          fontFamily: kDefaultFont,
                          fontWeight: FontWeight.w500,
                        )),
                const SizedBox(height: 4),
                Text(description,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          fontFamily: kDefaultFont,
                          color: Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.color
                              ?.withValues(alpha: 0.7),
                        )),
              ],
            ),
          ),
          const SizedBox(width: 12),
          ElevatedButton(
            onPressed: isGranted ? null : onPressed,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.transparent,
              surfaceTintColor: Colors.transparent,
              shadowColor: Colors.transparent,
              minimumSize: const Size(s75, s40),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(s16),
                side: BorderSide(
                  color: Theme.of(context)
                      .colorScheme
                      .primary
                      .withValues(alpha: 0.5),
                ),
              ),
            ),
            child: isGranted
                ? Icon(Icons.check,
                    color: Theme.of(context).colorScheme.primary)
                : const Text(
                    btnGrant,
                    style: TextStyle(fontSize: s14, fontFamily: kDefaultFont),
                  ),
          ),
        ],
      ),
    );
  }

  /// Helper to build the header with icon and title
  Widget _buildHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          Icons.rocket_launch_rounded,
          size: s50,
          color: Theme.of(context).colorScheme.primary,
        ),
        verticalSpaceMedium,
        Text(
          titleWelcome,
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
                fontFamily: kDefaultFont,
              ),
        ),
      ],
    );
  }

  /// Helper to build the descriptive text
  Widget _buildDescription(BuildContext context) {
    return Text(
      msgGrantPermissions,
      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            fontFamily: kDefaultFont,
          ),
    );
  }

  /// Helper to build a section of permissions (e.g., Required or Optional)
  Widget _buildPermissionSection(BuildContext context,
      {required String title, required List<Widget> permissions}) {
    return Card(
      elevation: s2,
      clipBehavior: Clip.hardEdge,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(s12)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: s10, vertical: s12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontFamily: kDefaultFont,
                  ),
            ),
            verticalSpaceSmall,
            ...permissions,
          ],
        ),
      ),
    );
  }

  /// Helper to build the "Get Started" button
  Widget _buildGetStartedButton(bool isMandatoryGranted) {
    return ElevatedButton(
      onPressed: isMandatoryGranted ? _completeSetup : null,
      style: ElevatedButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: s10),
        minimumSize: const Size(double.infinity, s30),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(s16)),
      ),
      child: const Text(
        btnGetStarted,
        style: TextStyle(
          fontSize: s16,
          fontWeight: FontWeight.bold,
          fontFamily: kDefaultFont,
        ),
      ),
    );
  }
}
