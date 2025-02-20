import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import 'package:wakepoint/controller/location_provider.dart';
import 'package:wakepoint/pages/alarm_screen.dart';
import 'package:wakepoint/pages/home_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await _requestPermissions();
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (context) => LocationProvider()),
      ],
      child: const MainApp(),
    ),
  );
}

/// **Request ALL Necessary Permissions Before Allowing Access**
Future<bool> _requestPermissions() async {
  bool locationGranted = await _requestLocationPermissions();
  bool notificationsGranted = await _requestNotificationPermissions();
  bool foregroundServiceGranted = await _requestForegroundServicePermissions();
  _requestOverlayPermission();

  return locationGranted && notificationsGranted && foregroundServiceGranted;
}

/// **📍 Request Location Permissions**
Future<bool> _requestLocationPermissions() async {
  bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
  if (!serviceEnabled) {
    print("❌ Location services are disabled.");
    return false;
  }

  LocationPermission permission = await Geolocator.checkPermission();
  if (permission == LocationPermission.denied) {
    permission = await Geolocator.requestPermission();
  }

  if (permission == LocationPermission.whileInUse) {
    await Permission.locationAlways.request();
  }

  if (permission == LocationPermission.deniedForever) {
    print("❌ Location permission is permanently denied.");
    openAppSettings();
    return false;
  }

  return permission == LocationPermission.always ||
      permission == LocationPermission.whileInUse;
}

/// **🔔 Request Notification Permissions**
Future<bool> _requestNotificationPermissions() async {
  PermissionStatus status = await Permission.notification.request();
  if (status.isDenied) {
    print("❌ Notification permission denied.");
    return false;
  }

  if (status.isPermanentlyDenied) {
    print("❌ Notification permission permanently denied.");
    openAppSettings();
    return false;
  }

  return status.isGranted;
}

Future<void> _requestOverlayPermission() async {
  if (!await Permission.systemAlertWindow.isGranted) {
    await Permission.systemAlertWindow.request();
  }
}

/// **🛑 Request Foreground Service Permissions (Required for Background Tracking)**
Future<bool> _requestForegroundServicePermissions() async {
  PermissionStatus status =
      await Permission.ignoreBatteryOptimizations.request();
  if (status.isDenied) {
    print("❌ Foreground service permission denied.");
    return false;
  }

  if (status.isPermanentlyDenied) {
    print("❌ Foreground service permission permanently denied.");
    openAppSettings();
    return false;
  }

  return status.isGranted;
}

class MainApp extends StatefulWidget {
  const MainApp({super.key});

  @override
  State<MainApp> createState() => _MainAppState();
}

class _MainAppState extends State<MainApp> {
  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: _requestPermissions(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const MaterialApp(
            debugShowCheckedModeBanner: false,
            home: Scaffold(
              body: Center(child: CircularProgressIndicator()),
            ),
          );
        }

        if (snapshot.data == false) {
          return MaterialApp(
            debugShowCheckedModeBanner: false,
            home: Scaffold(
              body: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text(
                      "⚠️ Permissions are required to use the app.",
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 16),
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton(
                      onPressed: () async {
                        bool granted = await _requestPermissions();
                        if (granted) {
                          setState(
                              () {}); // Refresh UI after granting permissions
                        }
                      },
                      child: const Text("Retry"),
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        return MaterialApp(
          debugShowCheckedModeBanner: false,
          themeMode: ThemeMode.system,
          darkTheme: ThemeData.dark(),
          theme: ThemeData.light(),
          home: const HomeScreen(),
        );
      },
    );
  }
}
