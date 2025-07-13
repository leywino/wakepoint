import 'dart:developer' as dev;

final Map<String, bool> kFeatureLogs = {
  'OlaAutocomplete': true,
  'LocationPicker': false,
  'WakeAlarm': false,
};

void log(String message, {String tag = 'General'}) {
  if (kFeatureLogs[tag] == true) {
    dev.log('[$tag] $message');
  }
}