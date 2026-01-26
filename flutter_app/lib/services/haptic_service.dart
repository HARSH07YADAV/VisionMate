import 'package:flutter/foundation.dart';
import 'package:vibration/vibration.dart';

import '../models/detection.dart';

/// Enhanced Haptic service with:
/// - Different vibration patterns by danger level (Feature 8)
/// - Proximity-based vibration intensity (Feature 9)
class HapticService extends ChangeNotifier {
  bool _hasVibrator = false;
  bool _hasAmplitudeControl = false;
  bool _enabled = true;

  bool get hasVibrator => _hasVibrator;
  bool get enabled => _enabled;

  /// Initialize haptic service
  Future<void> initialize() async {
    try {
      _hasVibrator = await Vibration.hasVibrator() ?? false;
      _hasAmplitudeControl = await Vibration.hasAmplitudeControl() ?? false;
      debugPrint('Haptic: vibrator=$_hasVibrator, amplitude=$_hasAmplitudeControl');
    } catch (e) {
      debugPrint('Haptic: Init error: $e');
    }
  }

  /// Enable or disable vibration
  void setEnabled(bool enabled) {
    _enabled = enabled;
    notifyListeners();
  }

  /// Vibrate based on risk level with different patterns
  Future<void> vibrateForRisk(RiskLevel level) async {
    if (!_hasVibrator || !_enabled) return;

    switch (level) {
      case RiskLevel.critical:
        await vibrateCritical();
        break;
      case RiskLevel.high:
        await vibrateHigh();
        break;
      case RiskLevel.medium:
        await vibrateMedium();
        break;
      case RiskLevel.low:
        await vibrateLow();
        break;
      default:
        break;
    }
  }

  /// FEATURE 8: Critical danger - long continuous vibration
  Future<void> vibrateCritical() async {
    if (!_hasVibrator || !_enabled) return;
    
    if (_hasAmplitudeControl) {
      await Vibration.vibrate(duration: 800, amplitude: 255);
    } else {
      await Vibration.vibrate(duration: 800);
    }
  }

  /// FEATURE 8: High danger - rapid pulses
  Future<void> vibrateHigh() async {
    if (!_hasVibrator || !_enabled) return;

    await Vibration.vibrate(
      pattern: [0, 150, 50, 150, 50, 150],
      intensities: [0, 255, 0, 255, 0, 255],
    );
  }

  /// FEATURE 8: Medium danger - double pulse
  Future<void> vibrateMedium() async {
    if (!_hasVibrator || !_enabled) return;

    await Vibration.vibrate(
      pattern: [0, 100, 80, 100],
      intensities: [0, 180, 0, 180],
    );
  }

  /// FEATURE 8: Low danger - single soft pulse
  Future<void> vibrateLow() async {
    if (!_hasVibrator || !_enabled) return;

    if (_hasAmplitudeControl) {
      await Vibration.vibrate(duration: 80, amplitude: 100);
    } else {
      await Vibration.vibrate(duration: 80);
    }
  }

  /// FEATURE 9: Proximity-based vibration
  /// Intensity increases as distance decreases
  /// distanceMeters: 0.3 = very close (max intensity), 5+ = far (no vibration)
  Future<void> vibrateForDistance(double distanceMeters, {DangerLevel? dangerLevel}) async {
    if (!_hasVibrator || !_enabled) return;
    if (distanceMeters < 0 || distanceMeters > 5) return;

    // Map distance to intensity: closer = stronger
    // 0.3m -> 255, 1m -> 200, 2m -> 150, 3m -> 100, 5m -> 50
    final intensity = _mapDistanceToIntensity(distanceMeters);
    final duration = _mapDistanceToDuration(distanceMeters);

    if (_hasAmplitudeControl) {
      await Vibration.vibrate(duration: duration, amplitude: intensity);
    } else {
      await Vibration.vibrate(duration: duration);
    }
  }

  /// Map distance to vibration intensity (0-255)
  int _mapDistanceToIntensity(double distance) {
    if (distance <= 0.3) return 255;
    if (distance <= 0.5) return 230;
    if (distance <= 1.0) return 200;
    if (distance <= 1.5) return 170;
    if (distance <= 2.0) return 140;
    if (distance <= 3.0) return 100;
    if (distance <= 4.0) return 70;
    return 50;
  }

  /// Map distance to vibration duration (ms)
  int _mapDistanceToDuration(double distance) {
    if (distance <= 0.5) return 300;
    if (distance <= 1.0) return 200;
    if (distance <= 2.0) return 150;
    return 100;
  }

  /// Vibrate for detection with proximity
  Future<void> vibrateForDetection(Detection detection) async {
    if (detection.distanceMeters > 0) {
      await vibrateForDistance(
        detection.distanceMeters, 
        dangerLevel: detection.dangerLevel,
      );
    } else {
      await vibrateForRisk(RiskLevel.fromScore(detection.dangerLevel.weight));
    }
  }

  /// Navigation: Turn left pattern
  Future<void> vibrateTurnLeft() async {
    if (!_hasVibrator || !_enabled) return;

    await Vibration.vibrate(
      pattern: [0, 50, 30, 50, 30, 150],
      intensities: [0, 150, 0, 150, 0, 255],
    );
  }

  /// Navigation: Turn right pattern
  Future<void> vibrateTurnRight() async {
    if (!_hasVibrator || !_enabled) return;

    await Vibration.vibrate(
      pattern: [0, 150, 30, 50, 30, 50],
      intensities: [0, 255, 0, 150, 0, 150],
    );
  }

  /// Arrival confirmation pattern
  Future<void> vibrateArrived() async {
    if (!_hasVibrator || !_enabled) return;

    await Vibration.vibrate(
      pattern: [0, 100, 100, 100, 100, 100, 100, 200],
      intensities: [0, 100, 0, 150, 0, 200, 0, 255],
    );
  }

  /// Emergency SOS pattern
  Future<void> vibrateEmergency() async {
    if (!_hasVibrator) return; // Always vibrate for emergency

    // SOS pattern: ... --- ...
    await Vibration.vibrate(
      pattern: [
        0, 100, 100, 100, 100, 100, 200, // ...
        300, 200, 300, 200, 300, 200,    // ---
        100, 100, 100, 100, 100,         // ...
      ],
      intensities: [
        0, 255, 0, 255, 0, 255, 0,
        255, 0, 255, 0, 255, 0,
        255, 0, 255, 0, 255,
      ],
    );
  }

  /// Quick tick feedback
  Future<void> tick() async {
    if (!_hasVibrator || !_enabled) return;

    if (_hasAmplitudeControl) {
      await Vibration.vibrate(duration: 30, amplitude: 128);
    } else {
      await Vibration.vibrate(duration: 30);
    }
  }

  /// Cancel vibration
  Future<void> cancel() async {
    await Vibration.cancel();
  }
}
