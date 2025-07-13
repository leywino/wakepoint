import 'dart:developer' as dev;

final Map<String, bool> kFeatureLogs = {
  'AutoCompleteTextField': true,
  'AddLocationScreen': true,
  'LocationProvider': false,
  'PlacesService': true,
};

void log(String message, {String tag = 'General'}) {
  if (kFeatureLogs[tag] == true) {
    dev.log('[$tag] $message');
  }
}
