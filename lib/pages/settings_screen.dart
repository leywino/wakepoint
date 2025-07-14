import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import 'package:wakepoint/controller/settings_provider.dart';
import 'package:wakepoint/config/constants.dart';
import 'package:wakepoint/utils/unit_converter.dart';

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

  Future<void> _checkPermissions() async {
    _overlayGranted = await Permission.systemAlertWindow.isGranted;
    _batteryGranted = await Permission.ignoreBatteryOptimizations.isGranted;
    setState(() {});
  }

  Future<void> _requestOverlayPermission(VoidCallback onGranted) async {
    final status = await Permission.systemAlertWindow.request();
    setState(() {
      _overlayGranted = status.isGranted;
    });
    if (status.isGranted) {
      onGranted.call();
    }
  }

  Future<void> _requestBatteryPermission() async {
    final status = await Permission.ignoreBatteryOptimizations.request();
    setState(() => _batteryGranted = status.isGranted);
  }

  @override
  Widget build(BuildContext context) {
    final settingsProvider = Provider.of<SettingsProvider>(context);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(),
      body: DefaultTextStyle(
        style: const TextStyle(fontFamily: kDefaultFont),
        child: ListView(
          padding: const EdgeInsets.all(s16),
          children: [
            _buildTitle(),
            verticalSpaceMedium,
            _buildSectionTitle(sectionGeneral, theme),
            _buildThemeSelection(settingsProvider),
            _buildUnitSystemSelection(
                settingsProvider),
            verticalSpaceMedium,
            _buildSectionTitle(sectionTracking, theme),
            _buildTrackingSettings(settingsProvider),
            verticalSpaceMedium,
            _buildSectionTitle(sectionAlarm, theme),
            _buildRadiusSetting(settingsProvider, theme),
            _buildAlarmSettings(settingsProvider),
            verticalSpaceMedium,
            _buildSectionTitle(sectionNotifications, theme),
            _buildNotificationSettings(settingsProvider),
            verticalSpaceMedium,
            _buildSectionTitle(sectionPermissions, theme),
            _buildPermissionSettings(settingsProvider),
          ],
        ),
      ),
    );
  }

  Widget _buildTitle() {
    return const Text(
      sectionSettings,
      style: TextStyle(fontSize: s32, fontWeight: FontWeight.bold),
    );
  }

  Widget _buildSectionTitle(String title, ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.only(top: s6),
      child: Text(
        title.toUpperCase(),
        style: theme.textTheme.labelLarge?.copyWith(
          color: theme.colorScheme.primary,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildThemeSelection(SettingsProvider settingsProvider) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: const Icon(Icons.color_lens),
      title: const Text(labelTheme),
      subtitle: Text(
        _getThemeName(settingsProvider.theme),
        style: const TextStyle(fontWeight: FontWeight.bold),
      ),
      onTap: () => _showThemeDialog(settingsProvider),
    );
  }

  void _showThemeDialog(SettingsProvider settingsProvider) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(s16)),
      ),
      builder: (context) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.all(s8),
              child: Text("Select App Theme", style: TextStyle(fontSize: s18)),
            ),
            _buildThemeOption(
                settingsProvider, AppTheme.system, valSystemDefault),
            _buildThemeOption(settingsProvider, AppTheme.light, valLightMode),
            _buildThemeOption(settingsProvider, AppTheme.dark, valDarkMode),
            sizedBoxH10,
          ],
        );
      },
    );
  }

  Widget _buildThemeOption(
      SettingsProvider settingsProvider, AppTheme value, String label) {
    return RadioListTile<AppTheme>(
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

  String _getThemeName(AppTheme theme) {
    switch (theme) {
      case AppTheme.light:
        return valLightMode;
      case AppTheme.dark:
        return valDarkMode;
      default:
        return valSystemDefault;
    }
  }

  Widget _buildUnitSystemSelection(SettingsProvider settingsProvider) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: const Icon(Icons.straighten),
      title: const Text(labelUnitSystem),
      trailing: DropdownButton<UnitSystem>(
        value: settingsProvider.preferredUnitSystem,
        items: UnitSystem.values.map((system) {
          return DropdownMenuItem(
            value: system,
            child: Text(UnitConverter.getUnitSystemLabels()[system.index]),
          );
        }).toList(),
        onChanged: (newSystem) {
          if (newSystem != null) {
            settingsProvider.preferredUnitSystem = newSystem;
          }
        },
      ),
    );
  }

  Widget _buildRadiusSetting(
      SettingsProvider settingsProvider, ThemeData theme) {
    int initialIndex = ksRadiusOptions.indexWhere(
      (r) => r >= settingsProvider.alarmRadius.toInt(),
    );
    if (initialIndex == -1) initialIndex = ksRadiusOptions.length - 1;

    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: const Icon(Icons.share_location),
      title: const Text(labelTrackingRadius),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            UnitConverter.formatDistanceForDisplay(settingsProvider.alarmRadius,
                settingsProvider.preferredUnitSystem),
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.primary,
              fontSize: s16,
            ),
          ),
          sizedBoxW8,
          const Icon(Icons.chevron_right),
        ],
      ),
      onTap: () =>
          _showRadiusSelectionModal(context, settingsProvider, initialIndex),
    );
  }

  Future<void> _showRadiusSelectionModal(BuildContext context,
      SettingsProvider settingsProvider, int initialIndex) async {
    int selectedIndex = initialIndex;

    await showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(s16)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final currentSettingsProvider =
                Provider.of<SettingsProvider>(context);

            return Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: s16, vertical: s12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    labelSelectRadius,
                    style:
                        TextStyle(fontSize: s18, fontWeight: FontWeight.bold),
                  ),
                  Slider(
                    value: selectedIndex.toDouble(),
                    min: s0,
                    max: (ksRadiusOptions.length - 1).toDouble(),
                    divisions: ksRadiusOptions.length - 1,
                    label: UnitConverter.formatDistanceForDisplay(
                        ksRadiusOptions[selectedIndex].toDouble(),
                        currentSettingsProvider.preferredUnitSystem),
                    onChanged: (double newIndex) {
                      setModalState(() {
                        selectedIndex = newIndex.round();
                      });
                    },
                  ),
                  Text(
                    UnitConverter.formatDistanceForDisplay(
                        ksRadiusOptions[selectedIndex].toDouble(),
                        currentSettingsProvider.preferredUnitSystem),
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  sizedBoxH8,
                  ElevatedButton(
                    onPressed: () {
                      currentSettingsProvider.alarmRadius =
                          ksRadiusOptions[selectedIndex].toDouble();
                      Navigator.pop(context);
                    },
                    child: const Text(btnApply),
                  ),
                  sizedBoxH16,
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildAlarmSettings(SettingsProvider settingsProvider) {
    return Column(
      children: [
        _buildSwitchTile(
          labelVibration,
          settingsProvider.enableAlarmVibration,
          (value) => settingsProvider.enableAlarmVibration = value,
          icon: Icons.vibration,
        ),
        _buildSwitchTile(
          labelUseOverlayAlarm,
          settingsProvider.useOverlayAlarmFeature,
          _overlayGranted
              ? (value) => settingsProvider.useOverlayAlarmFeature = value
              : null,
          disabled: !_overlayGranted,
          subtitle: msgOverlayRequired,
          icon: Icons.layers,
        ),
      ],
    );
  }

  Widget _buildTrackingSettings(SettingsProvider settingsProvider) {
    return Column(
      children: [
        _buildDropdownTile(
          labelTrackingAccuracy,
          _getTrackingAccuracyLabel(settingsProvider.locationTrackingAccuracy),
          [valHighAccuracy, valBalanced, valBatterySaving],
          (value) => settingsProvider.locationTrackingAccuracy =
              _getTrackingAccuracyFromString(value!),
          icon: Icons.location_searching,
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          secondary: const Icon(Icons.notifications_active),
          title: const Text(labelDistanceNotification),
          subtitle: const Text(descLimitNotifications),
          value: settingsProvider.isNotificationThresholdEnabled,
          onChanged: (value) {
            settingsProvider.isNotificationThresholdEnabled = value;
          },
        ),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.social_distance),
          title: const Text(labelDistanceThreshold),
          subtitle: const Text(descSendRealTime),
          trailing: DropdownButton<double>(
            value: settingsProvider.notificationDistanceThresholdKm,
            items: kcDistanceNumberList.map((e) {
              return DropdownMenuItem<double>(
                value: e,
                child: Text(UnitConverter.formatThresholdForDisplay(
                    e, settingsProvider.preferredUnitSystem)),
              );
            }).toList(),
            onChanged: settingsProvider.isNotificationThresholdEnabled
                ? (newValue) {
                    if (newValue != null) {
                      settingsProvider.notificationDistanceThresholdKm =
                          newValue;
                    }
                  }
                : null,
          ),
        ),
      ],
    );
  }

  Widget _buildNotificationSettings(SettingsProvider settingsProvider) {
    return Column(
      children: [
        _buildSwitchTile(
          labelPersistentNotification,
          settingsProvider.enablePersistentNotification,
          (value) => settingsProvider.enablePersistentNotification = value,
          icon: Icons.push_pin,
          subtitle: descEnablePersistent,
        ),
      ],
    );
  }

  Widget _buildPermissionSettings(SettingsProvider settingsProvider) {
    return Column(
      children: [
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.window),
          title: const Text(permOverlay),
          subtitle: const Text(msgOverlayNeededForAlerts),
          trailing: _overlayGranted
              ? const Icon(Icons.check_circle, color: Colors.green)
              : ElevatedButton(
                  onPressed: () {
                    _requestOverlayPermission(
                      () {
                        settingsProvider.useOverlayAlarmFeature = true;
                      },
                    );
                  },
                  child: const Text(btnGrant),
                ),
        ),
        sizedBoxH10,
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.battery_alert),
          title: const Text(permBattery),
          subtitle: const Text(msgBatteryNeededForPersistence),
          trailing: _batteryGranted
              ? const Icon(Icons.check_circle, color: Colors.green)
              : ElevatedButton(
                  onPressed: _requestBatteryPermission,
                  child: const Text(btnGrant),
                ),
        ),
      ],
    );
  }

  Widget _buildDropdownTile(String title, String value, List<String> options,
      ValueChanged<String?>? onChanged,
      {IconData icon = Icons.arrow_drop_down}) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon),
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

  Widget _buildSwitchTile(
      String title, bool value, ValueChanged<bool>? onChanged,
      {bool disabled = false,
      String? subtitle,
      IconData icon = Icons.toggle_on}) {
    return SwitchListTile(
      contentPadding: EdgeInsets.zero,
      secondary: Icon(icon),
      title: Text(title),
      subtitle: subtitle != null ? Text(subtitle) : null,
      value: value,
      onChanged: disabled ? null : onChanged,
    );
  }

  String _getTrackingAccuracyLabel(int trackingAccuracy) {
    switch (trackingAccuracy) {
      case 0:
        return valHighAccuracy;
      case 1:
        return valBalanced;
      case 2:
        return valBatterySaving;
      default:
        throw ArgumentError(msgInvalidAccuracy(trackingAccuracy.toString()));
    }
  }

  int _getTrackingAccuracyFromString(String accuracy) {
    switch (accuracy) {
      case valHighAccuracy:
        return 0;
      case valBalanced:
        return 1;
      case valBatterySaving:
        return 2;
      default:
        throw ArgumentError(msgInvalidAccuracy(accuracy));
    }
  }
}
