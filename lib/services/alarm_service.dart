import 'dart:async';
import 'package:flutter/services.dart';
import 'package:vibration/vibration.dart';
import 'package:wakepoint/config/constants.dart';
import 'package:wakepoint/controller/settings_provider.dart';

class AlarmService {
  bool _isVibrating = false;
  Timer? _vibrationTimer;

  Future<void> startAlarm({
    required bool enableVibration,
    required int durationSeconds,
    required AlarmSoundType alarmSoundType,
    Function? onAlarmEnd,
  }) async {
    if (enableVibration) _startVibrationPattern();

    if (durationSeconds > 0) {
      Future.delayed(Duration(seconds: durationSeconds), () {
        stopAlarm();
        onAlarmEnd?.call();
      });
    }

    try {
      await _playTone(alarmSoundType);
    } catch (_) {
      // Silently fail
    }
  }

  void stopAlarm() {
    _isVibrating = false;
    _vibrationTimer?.cancel();
    Vibration.cancel();
    _stopTone();
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

  Future<void> _playTone(AlarmSoundType alarmSoundType) async {
    const platform = MethodChannel(kMethodChannelTone);
    await platform
        .invokeMethod('playTone', {"type": alarmSoundType.name.toLowerCase()});
  }

  Future<void> _stopTone() async {
    const platform = MethodChannel(kMethodChannelTone);
    await platform.invokeMethod('stopTone');
  }
}
