import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import 'package:wakepoint/controller/settings_provider.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _overlayGranted = false;
  bool _batteryGranted = false;

  @override
  void initState() {
    super.initState();
    _checkPermissions();
  }

  /// **Check current permission status**
  Future<void> _checkPermissions() async {
    _overlayGranted = await Permission.systemAlertWindow.isGranted;
    _batteryGranted = await Permission.ignoreBatteryOptimizations.isGranted;
    setState(() {});
  }

  /// **Request Overlay Permission**
  Future<void> _requestOverlayPermission() async {
    final status = await Permission.systemAlertWindow.request();
    setState(() => _overlayGranted = status.isGranted);
  }

  /// **Request Battery Optimization Permission**
  Future<void> _requestBatteryPermission() async {
    final status = await Permission.ignoreBatteryOptimizations.request();
    setState(() => _batteryGranted = status.isGranted);
  }

  @override
  Widget build(BuildContext context) {
    final settingsProvider = Provider.of<SettingsProvider>(context);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text("Settings")),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          _buildTitle(),
          const SizedBox(height: 12),
          _buildSectionTitle("Appearance", theme),
          _buildThemeSelection(settingsProvider),
          const SizedBox(height: 20),
          _buildSectionTitle("Tracking", theme),
          _buildRadiusSlider(settingsProvider),
          _buildTrackingSettings(settingsProvider),
          const SizedBox(height: 20),
          _buildSectionTitle("Alarm Settings", theme),
          _buildAlarmSettings(settingsProvider),
          const SizedBox(height: 20),
          _buildSectionTitle("Notifications", theme),
          _buildNotificationSettings(settingsProvider),
          const SizedBox(height: 20),
          _buildSectionTitle("Permissions", theme),
          _buildPermissionSettings(),
        ],
      ),
    );
  }

  Widget _buildTitle() {
    return const Text(
      "Settings",
      style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
    );
  }

  /// **Section Title**
  Widget _buildSectionTitle(String title, ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Text(
        title.toUpperCase(),
        style: theme.textTheme.labelLarge?.copyWith(
          color: theme.colorScheme.primary,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  /// **Dropdown-style Theme Selection**
  Widget _buildThemeSelection(SettingsProvider settingsProvider) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: const Text("App Theme"),
      subtitle: Text(
        _getThemeName(settingsProvider.theme),
        style: TextStyle(
          color: Theme.of(context).colorScheme.primary,
          fontWeight: FontWeight.bold,
        ),
      ),
      onTap: () => _showThemeDialog(settingsProvider),
    );
  }

  /// **Theme Selection Dialog**
  void _showThemeDialog(SettingsProvider settingsProvider) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.all(8),
              child: Text("Select App Theme", style: TextStyle(fontSize: 18)),
            ),
            _buildThemeOption(
                settingsProvider, ThemeSettings.system, "System Default"),
            _buildThemeOption(
                settingsProvider, ThemeSettings.light, "Light Mode"),
            _buildThemeOption(
                settingsProvider, ThemeSettings.dark, "Dark Mode"),
            const SizedBox(height: 10),
          ],
        );
      },
    );
  }

  Widget _buildThemeOption(
      SettingsProvider settingsProvider, ThemeSettings value, String label) {
    return RadioListTile<ThemeSettings>(
      title: Text(label),
      value: value,
      groupValue: settingsProvider.theme,
      onChanged: (newTheme) {
        if (newTheme != null) {
          settingsProvider.theme = newTheme;
          Navigator.pop(context);
        }
      },
    );
  }

  String _getThemeName(ThemeSettings theme) {
    switch (theme) {
      case ThemeSettings.light:
        return "Light Mode";
      case ThemeSettings.dark:
        return "Dark Mode";
      default:
        return "System Default";
    }
  }

  /// **Tracking Radius Slider**
  Widget _buildRadiusSlider(SettingsProvider settingsProvider) {
    return Column(
      children: [
        ListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text("Tracking Radius"),
          subtitle: Text("${settingsProvider.radius.toInt()} meters"),
        ),
        Slider(
          value: settingsProvider.radius,
          min: 10,
          max: 1000,
          divisions: 20,
          label: "${settingsProvider.radius.toInt()} m",
          onChanged: (newValue) {
            settingsProvider.radius = newValue;
          },
        ),
      ],
    );
  }

  /// **Alarm Settings**
  Widget _buildAlarmSettings(SettingsProvider settingsProvider) {
    return Column(
      children: [
        _buildSwitchTile(
          "Vibration",
          settingsProvider.alarmVibration,
          (value) => settingsProvider.alarmVibration = value,
        ),
        _buildSwitchTile(
          "Use Overlay Alarm",
          settingsProvider.useOverlayAlarm,
          _overlayGranted
              ? (value) => settingsProvider.useOverlayAlarm = value
              : null,
          disabled: !_overlayGranted,
        ),
      ],
    );
  }

  /// **Tracking Settings**
  Widget _buildTrackingSettings(SettingsProvider settingsProvider) {
    return Column(
      children: [
        _buildDropdownTile(
          "Tracking Accuracy",
          _getTrackingAccuracyLabel(settingsProvider.trackingAccuracy),
          ["High Accuracy", "Balanced", "Battery Saving"],
          (value) => settingsProvider.trackingAccuracy =
              _getTrackingAccuracyFromString(value!),
        ),
      ],
    );
  }

  /// **Notification Settings**
  Widget _buildNotificationSettings(SettingsProvider settingsProvider) {
    return Column(
      children: [
        _buildSwitchTile(
          "Persistent Notification",
          settingsProvider.persistentNotification,
          (value) => settingsProvider.persistentNotification = value,
        ),
      ],
    );
  }

  /// **Permission Settings**
  Widget _buildPermissionSettings() {
    return Column(
      children: [
        // Overlay Permission
        ListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text("Overlay Permission"),
          subtitle:
              const Text("Required for displaying alarm over other apps."),
          trailing: _overlayGranted
              ? const Icon(Icons.check_circle, color: Colors.green)
              : ElevatedButton(
                  onPressed: _requestOverlayPermission,
                  child: const Text("Grant"),
                ),
        ),

        const SizedBox(height: 10),

        // Battery Optimization Permission
        ListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text("Battery Optimization"),
          subtitle: const Text("Required to prevent app from being stopped."),
          trailing: _batteryGranted
              ? const Icon(Icons.check_circle, color: Colors.green)
              : ElevatedButton(
                  onPressed: _requestBatteryPermission,
                  child: const Text("Grant"),
                ),
        ),
      ],
    );
  }

  /// **Reusable Dropdown Tile**
  Widget _buildDropdownTile(String title, String value, List<String> options,
      ValueChanged<String?>? onChanged) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(title),
      trailing: DropdownButton<String>(
        value: value,
        items: options
            .map((e) => DropdownMenuItem(value: e, child: Text(e)))
            .toList(),
        onChanged: onChanged,
      ),
    );
  }

  /// **Reusable Switch Tile**
  Widget _buildSwitchTile(
      String title, bool value, ValueChanged<bool>? onChanged,
      {bool disabled = false}) {
    return SwitchListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(title),
      value: value,
      onChanged: disabled ? null : onChanged,
    );
  }

  String _getTrackingAccuracyLabel(int trackingAccuracy) {
    switch (trackingAccuracy) {
      case 0:
        return "High Accuracy";
      case 1:
        return "Balanced";
      case 2:
        return "Battery Saving";
      default:
        throw ArgumentError("Invalid accuracy value: $trackingAccuracy");
    }
  }

  int _getTrackingAccuracyFromString(String accuracy) {
    switch (accuracy) {
      case "High Accuracy":
        return 0;
      case "Balanced":
        return 1;
      case "Battery Saving":
        return 2;
      default:
        throw ArgumentError("Invalid accuracy value: $accuracy");
    }
  }
}
