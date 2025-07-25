import 'package:flutter/material.dart';
import 'package:flutter_displaymode/flutter_displaymode.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wakepoint/controller/location_provider.dart';
import 'package:wakepoint/controller/settings_provider.dart';
import 'package:wakepoint/pages/home_screen.dart';
import 'package:wakepoint/pages/permission_screen.dart';
import 'package:wakepoint/services/location_service.dart';

void main() async {
  await dotenv.load(fileName: ".env");
  WidgetsFlutterBinding.ensureInitialized();
  FlutterDisplayMode.setHighRefreshRate();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  /// Loads SharedPreferences asynchronously
  Future<Map<String, dynamic>> _loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    final firstLaunchCompleted =
        prefs.getBool("first_launch_completed") ?? false;
    return {
      "prefs": prefs,
      "firstLaunchCompleted": firstLaunchCompleted,
    };
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>>(
      future: _loadPreferences(), // Load SharedPreferences in the background
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const MaterialApp(
            home: Scaffold(
              body: Center(
                  child:
                      CircularProgressIndicator()),
            ),
          );
        }

        final prefs = snapshot.data!["prefs"] as SharedPreferences;
        final firstLaunchCompleted =
            snapshot.data!["firstLaunchCompleted"] as bool;

        return MultiProvider(
          providers: [
            ChangeNotifierProvider(
                create: (context) => LocationProvider(
                    SettingsProvider(prefs), LocationService())),
            ChangeNotifierProvider(
                create: (context) => SettingsProvider(prefs)),
          ],
          child: MainApp(firstLaunchCompleted: firstLaunchCompleted),
        );
      },
    );
  }
}

class MainApp extends StatelessWidget {
  const MainApp({super.key, required this.firstLaunchCompleted});

  final bool firstLaunchCompleted;

  @override
  Widget build(BuildContext context) {
    return Consumer<SettingsProvider>(
      builder: (context, settingsProvider, child) {
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          themeMode: ThemeMode.values[settingsProvider.theme.index],
          darkTheme: ThemeData.dark(useMaterial3: true),
          theme: ThemeData.light(useMaterial3: true),
          home: firstLaunchCompleted
              ? const HomeScreen()
              : const PermissionScreen(),
        );
      },
    );
  }
}
