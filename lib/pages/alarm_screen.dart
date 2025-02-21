import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
// import 'package:flutter_ringtone_player/flutter_ringtone_player.dart';
import 'dart:async';
import 'package:provider/provider.dart';
import 'package:wakepoint/controller/location_provider.dart';
import 'package:wakepoint/controller/settings_provider.dart';

class AlarmScreen extends StatefulWidget {
  const AlarmScreen({super.key});

  @override
  State<AlarmScreen> createState() => _AlarmScreenState();
}

class _AlarmScreenState extends State<AlarmScreen>
    with SingleTickerProviderStateMixin {
  bool _isVibrating = false;
  Timer? _vibrateTimer;
  late AnimationController _iconAnimationController;
  late SettingsProvider settingsProvider;

  @override
  void initState() {
    super.initState();
    _startAlarm();
    // Animation for Blinking Alert Icon
    _iconAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat(reverse: true);
  }

  @override
  void didChangeDependencies() {
    settingsProvider = Provider.of<SettingsProvider>(context);
    super.didChangeDependencies();
  }

  void _startAlarm() async {
    if (settingsProvider.alarmVibration) {
      _isVibrating = true;
      _vibrateTimer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (_isVibrating) {
          HapticFeedback.vibrate();
        }
      });
    }
    // FlutterRingtonePlayer().playAlarm();
  }

  void _stopAlarm() {
    setState(() {
      _isVibrating = false;
      _vibrateTimer?.cancel();
    });
    // FlutterRingtonePlayer().stop();
    _iconAnimationController.dispose();
    Provider.of<LocationProvider>(context, listen: false)
        .stopTracking();
    Navigator.of(context).pop();
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
            const SizedBox(height: 20),

            // Alarm Title
            Text(
              "WakePoint Alert!",
              style: theme.textTheme.headlineLarge?.copyWith(
                fontWeight: FontWeight.bold,
                color: textColor,
              ),
            ),
            const SizedBox(height: 10),

            // Subtext
            Text(
              "You are near your destination.",
              style: theme.textTheme.bodyLarge?.copyWith(color: textColor),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 30),

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
                "Dismiss Alarm",
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
