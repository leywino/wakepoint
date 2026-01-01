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
    final overlayStatus = await Permission.systemAlertWindow.isGranted;
    final batteryStatus = await Permission.ignoreBatteryOptimizations.isGranted;

    if (!mounted) return;

    setState(() {
      _overlayGranted = overlayStatus;
      _batteryGranted = batteryStatus;
    });
  }

  Future<void> _requestOverlayPermission(VoidCallback onGranted) async {
    final status = await Permission.systemAlertWindow.request();

    if (!mounted) return;
    setState(() => _overlayGranted = status.isGranted);

    if (status.isGranted) onGranted.call();
  }

  Future<void> _requestBatteryPermission() async {
    final status = await Permission.ignoreBatteryOptimizations.request();
    if (!mounted) return;
    setState(() => _batteryGranted = status.isGranted);
  }

  @override
  Widget build(BuildContext context) {
    final settingsProvider = Provider.of<SettingsProvider>(context);

    return Scaffold(
      appBar: AppBar(),
      body: ListView(
        physics: BouncingScrollPhysics(),
        padding: const EdgeInsets.all(s16),
        children: [
          _SettingsHeader(title: sectionSettings),
          verticalSpaceMedium,
          SettingsSectionTitle(title: sectionGeneral),
          _buildThemeSelection(settingsProvider),
          _buildUnitSystemSelection(settingsProvider),
          verticalSpaceMedium,
          SettingsSectionTitle(title: sectionTracking),
          _buildTrackingSettings(settingsProvider),
          verticalSpaceMedium,
          SettingsSectionTitle(title: sectionAlarm),
          _AlarmSettingsSection(
            settingsProvider: settingsProvider,
            overlayGranted: _overlayGranted,
          ),
          verticalSpaceMedium,
          SettingsSectionTitle(title: sectionNotifications),
          _buildNotificationSettings(settingsProvider),
          verticalSpaceMedium,
          if (!_overlayGranted || !_batteryGranted) ...[
            SettingsSectionTitle(title: sectionPermissions),
            _buildPermissionSettings(settingsProvider),
            verticalSpaceMedium,
          ],
        ],
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
              child: Text(titleSelectTheme, style: TextStyle(fontSize: s18)),
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
    return RadioGroup<AppTheme>(
      groupValue: settingsProvider.theme,
      onChanged: (newTheme) {
        if (newTheme != null) {
          settingsProvider.theme = newTheme;
          Navigator.pop(context);
        }
      },
      child: RadioListTile<AppTheme>(
        title: Text(label),
        value: value,
      ),
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

  Widget _buildTrackingSettings(SettingsProvider settingsProvider) {
    return Column(
      children: [
        SettingsDropdownTile(
          title: labelTrackingAccuracy,
          value: _getTrackingAccuracyLabel(
              settingsProvider.locationTrackingAccuracy),
          options: [valHighAccuracy, valBalanced, valBatterySaving],
          onChanged: (value) => settingsProvider.locationTrackingAccuracy =
              _getTrackingAccuracyFromString(value!),
          icon: Icons.location_searching,
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          secondary: const Icon(Icons.notifications_active),
          title: const Text(labelNotifyWhenNearby),
          subtitle: const Text(descNotifyWhenNearby),
          value: settingsProvider.isNotificationThresholdEnabled,
          onChanged: (value) {
            settingsProvider.isNotificationThresholdEnabled = value;
          },
        ),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.social_distance),
          title: const Text(labelTrackingRadius),
          subtitle: const Text(descNotificationRadius),
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
        SettingsSwitchTile(
          title: labelPersistentNotification,
          value: settingsProvider.enablePersistentNotification,
          onChanged: (value) =>
              settingsProvider.enablePersistentNotification = value,
          icon: Icons.push_pin,
          subtitle: descEnablePersistent,
        ),
      ],
    );
  }

  Widget _buildPermissionSettings(SettingsProvider settingsProvider) {
    return Column(
      children: [
        if (!_overlayGranted)
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.window),
            title: const Text(permOverlay),
            subtitle: const Text(msgOverlayNeededForAlerts),
            trailing: ElevatedButton(
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
        if (!_overlayGranted && !_batteryGranted) sizedBoxH10,
        if (!_batteryGranted)
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.battery_alert),
            title: const Text(permBattery),
            subtitle: const Text(msgBatteryNeededForPersistence),
            trailing: ElevatedButton(
              onPressed: _requestBatteryPermission,
              child: const Text(btnGrant),
            ),
          ),
      ],
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

class SettingsSectionTitle extends StatelessWidget {
  const SettingsSectionTitle({
    super.key,
    required this.title,
  });

  final String title;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
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
}

class _SettingsHeader extends StatelessWidget {
  const _SettingsHeader({
    required this.title,
  });

  final String title;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Text(
      title,
      style: TextStyle(
        fontSize: s32,
        fontWeight: FontWeight.bold,
        color: theme.colorScheme.onSurface,
      ),
    );
  }
}

class _AlarmSettingsSection extends StatelessWidget {
  final SettingsProvider settingsProvider;
  final bool overlayGranted;

  const _AlarmSettingsSection({
    required this.settingsProvider,
    required this.overlayGranted,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SettingsSwitchTile(
          title: labelVibration,
          icon: Icons.vibration,
          value: settingsProvider.enableAlarmVibration,
          onChanged: (value) => settingsProvider.enableAlarmVibration = value,
        ),
        SettingsSwitchTile(
          title: labelUseOverlayAlarm,
          subtitle: msgOverlayRequired,
          icon: Icons.layers,
          disabled: !overlayGranted,
          value: settingsProvider.useOverlayAlarmFeature,
          onChanged: overlayGranted
              ? (value) => settingsProvider.useOverlayAlarmFeature = value
              : null,
        ),
        SettingsDropdownTile(
          title: labelAlarmSound,
          icon: Icons.music_note,
          value: _getAlarmSoundLabel(settingsProvider.alarmSoundType),
          options: [
            _getAlarmSoundLabel(AlarmSoundType.ringtone),
            _getAlarmSoundLabel(AlarmSoundType.alarm),
          ],
          onChanged: (value) {
            if (value != null) {
              settingsProvider.alarmSoundType =
                  _getAlarmSoundTypeFromString(value);
            }
          },
        ),
        _buildAlarmDurationDropdownRow(),
      ],
    );
  }

  Widget _buildAlarmDurationDropdownRow() {
    final isDisabled = !settingsProvider.useOverlayAlarmFeature;

    return Row(
      children: [
        const Icon(Icons.timer),
        const SizedBox(width: s12),
        Expanded(
          child: DropdownButtonFormField<int>(
            decoration: const InputDecoration(
              labelText: labelAlarmDuration,
              isDense: true,
              contentPadding:
                  EdgeInsets.symmetric(vertical: 10, horizontal: 12),
              border: UnderlineInputBorder(),
            ),
            initialValue: settingsProvider.alarmPlaybackDurationSeconds,
            items: const [
              DropdownMenuItem(
                  value: alarmDurationDismissed,
                  child: Text(alarmDurationLabelDismissed)),
              DropdownMenuItem(
                  value: alarmDuration15s, child: Text(alarmDurationLabel15s)),
              DropdownMenuItem(
                  value: alarmDuration30s, child: Text(alarmDurationLabel30s)),
              DropdownMenuItem(
                  value: alarmDuration60s, child: Text(alarmDurationLabel60s)),
              DropdownMenuItem(
                  value: alarmDuration90s, child: Text(alarmDurationLabel90s)),
            ],
            onChanged: isDisabled
                ? null
                : (value) {
                    if (value != null) {
                      settingsProvider.alarmPlaybackDurationSeconds = value;
                    }
                  },
          ),
        ),
      ],
    );
  }

  String _getAlarmSoundLabel(AlarmSoundType type) {
    switch (type) {
      case AlarmSoundType.ringtone:
        return valRingtone;
      case AlarmSoundType.alarm:
        return valAlarm;
    }
  }

  AlarmSoundType _getAlarmSoundTypeFromString(String value) {
    switch (value) {
      case valRingtone:
        return AlarmSoundType.ringtone;
      case valAlarm:
        return AlarmSoundType.alarm;
      default:
        return AlarmSoundType.ringtone;
    }
  }
}

class SettingsSwitchTile extends StatelessWidget {
  final String title;
  final String? subtitle;
  final IconData icon;
  final bool value;
  final ValueChanged<bool>? onChanged;
  final bool disabled;

  const SettingsSwitchTile({
    super.key,
    required this.title,
    required this.icon,
    required this.value,
    required this.onChanged,
    this.subtitle,
    this.disabled = false,
  });

  @override
  Widget build(BuildContext context) {
    return SwitchListTile.adaptive(
      contentPadding: EdgeInsets.zero,
      secondary: Icon(icon),
      title: Text(title),
      subtitle: subtitle != null ? Text(subtitle!) : null,
      value: value,
      onChanged: disabled ? null : onChanged,
    );
  }
}

class SettingsDropdownTile extends StatelessWidget {
  final String title;
  final String value;
  final List<String> options;
  final ValueChanged<String?>? onChanged;
  final IconData icon;

  const SettingsDropdownTile({
    super.key,
    required this.title,
    required this.value,
    required this.options,
    required this.onChanged,
    this.icon = Icons.arrow_drop_down,
  });

  @override
  Widget build(BuildContext context) {
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
}
