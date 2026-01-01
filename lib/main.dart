import 'package:flutter/material.dart';
import 'package:flutter_displaymode/flutter_displaymode.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:geolocator/geolocator.dart'; // Import this
import 'package:permission_handler/permission_handler.dart'; // Import this
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wakepoint/config/constants.dart';
import 'package:wakepoint/controller/location_provider.dart';
import 'package:wakepoint/controller/settings_provider.dart';
import 'package:wakepoint/pages/home_screen.dart';
import 'package:wakepoint/pages/permission_screen.dart';
import 'package:wakepoint/services/location_service.dart';

void main() async {
  await dotenv.load(fileName: '.env');
  WidgetsFlutterBinding.ensureInitialized();
  await FlutterDisplayMode
      .setHighRefreshRate(); // Await this for smoother start
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  /// Loads Prefs AND Checks Permissions
  Future<Map<String, dynamic>> _initApp() async {
    // 1. Load Preferences
    final prefs = await SharedPreferences.getInstance();

    // 2. Check Permissions Directly
    // Location
    final locStatus = await Geolocator.checkPermission();
    final hasLocation = locStatus == LocationPermission.always ||
        locStatus == LocationPermission.whileInUse;

    // Notification
    final hasNotification = await Permission.notification.isGranted;

    // Activity (Since you added it as mandatory)
    final hasActivity = await Permission.activityRecognition.isGranted;

    final allGranted = hasLocation && hasNotification && hasActivity;

    return {
      'prefs': prefs,
      'isAuthorized': allGranted,
    };
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>>(
      future: _initApp(),
      builder: (context, snapshot) {
        // Show splash/loading while checking
        if (!snapshot.hasData) {
          return const MaterialApp(
            home: Scaffold(
              body: Center(child: CircularProgressIndicator()),
            ),
          );
        }

        final prefs = snapshot.data!['prefs'] as SharedPreferences;
        final isAuthorized = snapshot.data!['isAuthorized'] as bool;

        return MultiProvider(
          providers: [
            ChangeNotifierProvider(
                create: (context) => SettingsProvider(prefs)),
            // Note: LocationProvider depends on SettingsProvider,
            // so often it's better to use ProxyProvider, but if your
            // current setup works, keep it.
            ChangeNotifierProxyProvider<SettingsProvider, LocationProvider>(
              create: (ctx) => LocationProvider(
                  Provider.of<SettingsProvider>(ctx, listen: false),
                  LocationService()),
              update: (ctx, settings, prev) =>
                  LocationProvider(settings, LocationService()),
            ),
          ],
          child: MainApp(isAuthorized: isAuthorized),
        );
      },
    );
  }
}

class MainApp extends StatelessWidget {
  const MainApp({super.key, required this.isAuthorized});

  final bool isAuthorized;

  @override
  Widget build(BuildContext context) {
    return Consumer<SettingsProvider>(
      builder: (context, settingsProvider, child) {
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          themeMode: ThemeMode.values[settingsProvider.theme.index],
          theme: ThemeData(
            useMaterial3: true,
            colorScheme: ColorScheme.fromSeed(
              seedColor: Colors.purple,
              brightness: Brightness.light,
            ),
            fontFamily: kDefaultFont,
          ),
          darkTheme: ThemeData(
            useMaterial3: true,
            fontFamily: kDefaultFont,
            colorScheme: ColorScheme.fromSeed(
              seedColor: Colors.purple,
              brightness: Brightness.dark,
            ),
          ),
          home: isAuthorized ? const HomeScreen() : const PermissionScreen(),
        );
      },
    );
  }
}
