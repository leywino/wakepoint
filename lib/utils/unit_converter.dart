// lib/utils/unit_converter.dart

import 'package:wakepoint/config/constants.dart';

import '../controller/settings_provider.dart';

class UnitConverter {
  // Conversion constants
  static const double metersPerFoot = 0.3048;
  static const double _metersPerYard = 0.9144;
  static const double _metersPerMile = 1609.34;
  static const double _kmPerMile = 1.60934;

  /// Helper method to format distance (e.g., alarm radius) which is stored in meters
  static String formatDistanceForDisplay(double meters, UnitSystem unitSystem) {
    if (unitSystem == UnitSystem.imperial) {
      // Convert meters to feet, yards, or miles
      // If less than 0.1 miles (approx 160 meters), show in yards
      if (meters < 160.934) { // 0.1 * 1609.34
         double yards = meters / _metersPerYard;
         return '${yards.toStringAsFixed(0)} yd'; // No decimals for yards
      } else {
        double miles = meters / _metersPerMile;
        return '${miles.toStringAsFixed(1)} mi'; // One decimal for miles
      }
    } else {
      // Metric system
      if (meters < 1000) {
        return '${meters.toInt()} m';
      } else {
        return '${(meters / 1000).toStringAsFixed(1)} km';
      }
    }
  }

  /// Helper method to format threshold distance (stored in kilometers)
  static String formatThresholdForDisplay(double kilometers, UnitSystem unitSystem) {
    if (unitSystem == UnitSystem.imperial) {
      double miles = kilometers / _kmPerMile;
      return '${miles.toStringAsFixed(1)} mi';
    } else {
      return '${kilometers.toStringAsFixed(1)} km';
    }
  }

  /// Helper method to get the list of unit system labels for UI dropdowns
  static List<String> getUnitSystemLabels() {
    return UnitSystem.values.map((system) {
      switch (system) {
        case UnitSystem.metric:
          return labelMetric;
        case UnitSystem.imperial:
          return labelImperial;
      }
    }).toList();
  }

  /// Helper method to convert a string label back to UnitSystem enum
  static UnitSystem getUnitSystemFromString(String label) {
    switch (label) {
      case labelMetric:
        return UnitSystem.metric;
      case labelImperial:
        return UnitSystem.imperial;
      default:
        throw ArgumentError('Invalid unit system label: $label');
    }
  }
}