import 'dart:async';
import 'package:flutter/services.dart';
import 'package:vibration/vibration.dart';

class AlarmService {
  bool _isVibrating = false;
  Timer? _vibrationTimer;

  Future<void> startAlarm({
    required bool enableVibration,
  }) async {
    if (enableVibration) _startVibrationPattern();

    try {
      await _playDefaultRingtone();
    } catch (_) {
      // Silently fail
    }
  }

  void stopAlarm() {
    _isVibrating = false;
    _vibrationTimer?.cancel();
    Vibration.cancel();
    _stopRingtone();
  }

  void _startVibrationPattern() {
    _isVibrating = true;
    List<int> pattern = [0, 2000, 1000, 2000, 1000, 2000];
    List<int> amplitudes = [255, 255, 0, 255, 0, 255];

    void loop() {
      if (_isVibrating) {
        Vibration.vibrate(pattern: pattern, intensities: amplitudes);
        _vibrationTimer = Timer(const Duration(seconds: 7), loop);
      }
    }

    loop();
  }

  Future<void> _playDefaultRingtone() async {
    const platform = MethodChannel('com.leywin.wakepoint/ringtone');
    await platform.invokeMethod('playRingtone');
  }

  Future<void> _stopRingtone() async {
    const platform = MethodChannel('com.leywin.wakepoint/ringtone');
    await platform.invokeMethod('stopRingtone');
  }
}
