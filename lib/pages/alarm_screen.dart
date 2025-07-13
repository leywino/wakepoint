import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import 'package:provider/provider.dart';
import 'package:vibration/vibration.dart';
import 'package:wakepoint/config/constants.dart';
import 'package:wakepoint/controller/location_provider.dart';
import 'package:wakepoint/controller/settings_provider.dart';

class AlarmScreen extends StatefulWidget {
  const AlarmScreen({super.key});

  @override
  State<AlarmScreen> createState() => _AlarmScreenState();
}

class _AlarmScreenState extends State<AlarmScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _iconAnimationController;
  SettingsProvider get settingsProvider =>
      Provider.of<SettingsProvider>(context, listen: false);

  LocationProvider get locationProvider =>
      Provider.of<LocationProvider>(context, listen: false);

  bool _isVibrating = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _startAlarm();
    });

    // Animation for Blinking Alert Icon
    _iconAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat(reverse: true);
  }

  /// **Start Alarm with Default Ringtone & Vibration**
  void _startAlarm() async {
    if (settingsProvider.alarmVibration) {
      _startVibrationPattern();
    }

    try {
      await _playDefaultRingtone();
    } catch (e) {
      debugPrint("Error playing default ringtone: $e");
    }
  }

  void _startVibrationPattern() {
    _isVibrating = true;

    List<int> pattern = [
      0,
      2000,
      1000,
      2000,
      1000,
      2000
    ]; // Start delay, Vibrate, Pause, Vibrate, Pause, Vibrate
    List<int> amplitudes = [
      255,
      255,
      0,
      255,
      0,
      255
    ]; // Maximum amplitude for vibration

    void loopVibration() {
      if (_isVibrating) {
        Vibration.vibrate(pattern: pattern, intensities: amplitudes);
        Future.delayed(const Duration(seconds: 7),
            loopVibration); // Restart after 7 seconds (full pattern length)
      }
    }

    loopVibration(); // Start looping
  }

  /// **Stop Alarm & Cleanup**
  void _stopAlarm() {
    setState(() {
      _isVibrating = false;
    });
    Vibration.cancel();
    _stopRingtone();
    _iconAnimationController.dispose();
    Provider.of<LocationProvider>(context, listen: false).stopTracking();
    Navigator.of(context).pop();
  }

  Future<void> _playDefaultRingtone() async {
    const platform = MethodChannel('com.leywin.wakepoint/ringtone');
    try {
      await platform.invokeMethod('playRingtone');
    } on PlatformException catch (e) {
      debugPrint("Failed to play ringtone: ${e.message}");
    }
  }

  Future<void> _stopRingtone() async {
    const platform = MethodChannel('com.leywin.wakepoint/ringtone');
    try {
      await platform.invokeMethod('stopRingtone');
    } on PlatformException catch (e) {
      debugPrint("Failed to stop ringtone: ${e.message}");
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final backgroundColor =
        theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.9);
    final textColor = theme.colorScheme.onSurface;

    return Scaffold(
      backgroundColor: backgroundColor,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Blinking Alert Icon
            ScaleTransition(
              scale:
                  Tween(begin: 1.0, end: 1.2).animate(_iconAnimationController),
              child: Icon(
                Icons.warning_amber_rounded,
                size: 100,
                color: theme.colorScheme.error,
              ),
            ),
            sizedBoxH20,

            // Alarm Title
            Text(
              titleWakePointAlert,
              style: theme.textTheme.headlineLarge?.copyWith(
                fontWeight: FontWeight.bold,
                color: textColor,
              ),
            ),
            sizedBoxH10,

            // Subtext
            RichText(
              textAlign: TextAlign.center,
              text: TextSpan(
                style: theme.textTheme.bodyLarge?.copyWith(color: textColor),
                children: [
                  const TextSpan(text: msgYouAreNear),
                  TextSpan(
                    text: locationProvider.currentSelectedLocation ??
                        labelUnknownLocation,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ],
              ),
            ),

            sizedBoxH30,

            // Dismiss Button
            ElevatedButton(
              onPressed: _stopAlarm,
              style: ElevatedButton.styleFrom(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                padding:
                    const EdgeInsets.symmetric(horizontal: 50, vertical: 15),
                elevation: 8,
                shadowColor: Colors.black26,
              ),
              child: Text(
                btnDismissAlarm,
                style: theme.textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
