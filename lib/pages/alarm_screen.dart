import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:wakepoint/controller/location_provider.dart';
import 'package:wakepoint/controller/settings_provider.dart';
import 'package:wakepoint/services/alarm_service.dart';

class AlarmScreen extends StatefulWidget {
  const AlarmScreen({super.key});

  @override
  State<AlarmScreen> createState() => _AlarmScreenState();
}

class _AlarmScreenState extends State<AlarmScreen>
    with TickerProviderStateMixin {
  late final AnimationController _iconAnimationController;
  late final AlarmService _alarmService;
  late final SettingsProvider settingsProvider;
  late final LocationProvider locationProvider;

  @override
  void initState() {
    super.initState();

    _iconAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat(reverse: true);

    settingsProvider = context.read<SettingsProvider>();
    locationProvider = context.read<LocationProvider>();
    _alarmService = AlarmService();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _alarmService.startAlarm(
        enableVibration: settingsProvider.enableAlarmVibration,
      );
    });
  }

  void _stopAlarm() {
    locationProvider.stopTracking();
    Navigator.of(context).pop();
  }

  @override
  void dispose() {
    _alarmService.stopAlarm();
    _iconAnimationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final brightness = MediaQuery.of(context).platformBrightness;
    final isDark = brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? Colors.black : Colors.white,
      body: AnnotatedRegion<SystemUiOverlayStyle>(
        value: isDark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ScaleTransition(
                scale: Tween(begin: 1.0, end: 1.2).animate(
                  CurvedAnimation(
                    parent: _iconAnimationController,
                    curve: Curves.easeInOut,
                  ),
                ),
                child: Icon(
                  Icons.alarm,
                  size: 100,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
              const SizedBox(height: 30),
              Text(
                'Wake up! You’re near your stop!',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: _stopAlarm,
                icon: const Icon(Icons.stop),
                label: const Text('Stop Alarm'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
