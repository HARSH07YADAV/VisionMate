import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:sensors_plus/sensors_plus.dart';

/// Accessibility activation methods for blind users
/// 
/// Provides multiple ways to activate voice commands without seeing the screen:
/// 1. Shake to speak - Shake the phone
/// 2. Volume button - Hardware key press
/// 3. Double-tap anywhere - Gesture anywhere on screen
/// 4. Always listening - Continuous mode with wake word
enum ActivationMethod {
  shake,
  volumeButton,
  doubleTap,
  alwaysListening,
}

class AccessibilityActivationService extends ChangeNotifier {
  // Shake detection
  StreamSubscription<AccelerometerEvent>? _accelerometerSubscription;
  DateTime _lastShakeTime = DateTime.now();
  double _lastX = 0, _lastY = 0, _lastZ = 0;
  bool _shakeEnabled = true;
  
  // Volume button detection
  static const _volumeChannel = MethodChannel('com.example.blind_assist/volume');
  bool _volumeButtonEnabled = true;
  
  // Always listening
  bool _alwaysListeningEnabled = false;
  
  // Callbacks
  Function? onActivate;
  Function(String)? onFeedback;
  
  // Settings
  static const double _shakeThreshold = 15.0; // Acceleration threshold
  static const int _shakeCooldownMs = 2000; // Prevent multiple triggers
  
  bool get shakeEnabled => _shakeEnabled;
  bool get volumeButtonEnabled => _volumeButtonEnabled;
  bool get alwaysListeningEnabled => _alwaysListeningEnabled;
  
  /// Initialize all activation methods
  Future<void> initialize() async {
    _initShakeDetection();
    _initVolumeButton();
    debugPrint('[Activation] Initialized - Shake: $_shakeEnabled');
  }
  
  /// Initialize accelerometer for shake detection
  void _initShakeDetection() {
    try {
      _accelerometerSubscription = accelerometerEventStream(
        samplingPeriod: const Duration(milliseconds: 100),
      ).listen(_onAccelerometerEvent);
      debugPrint('[Activation] Shake detection enabled');
    } catch (e) {
      debugPrint('[Activation] Accelerometer not available: $e');
      _shakeEnabled = false;
    }
  }
  
  /// Handle accelerometer events for shake detection
  void _onAccelerometerEvent(AccelerometerEvent event) {
    if (!_shakeEnabled) return;
    
    final now = DateTime.now();
    final timeDiff = now.difference(_lastShakeTime).inMilliseconds;
    
    // Calculate acceleration change
    final deltaX = (event.x - _lastX).abs();
    final deltaY = (event.y - _lastY).abs();
    final deltaZ = (event.z - _lastZ).abs();
    
    _lastX = event.x;
    _lastY = event.y;
    _lastZ = event.z;
    
    // Calculate total acceleration magnitude
    final acceleration = math.sqrt(deltaX * deltaX + deltaY * deltaY + deltaZ * deltaZ);
    
    // Check if it's a shake
    if (acceleration > _shakeThreshold && timeDiff > _shakeCooldownMs) {
      _lastShakeTime = now;
      _onShakeDetected();
    }
  }
  
  /// Called when shake is detected
  void _onShakeDetected() {
    debugPrint('[Activation] Shake detected!');
    onFeedback?.call('Shake detected. Listening...');
    onActivate?.call();
    notifyListeners();
  }
  
  /// Initialize volume button listener (platform-specific)
  void _initVolumeButton() {
    _volumeChannel.setMethodCallHandler((call) async {
      if (call.method == 'onVolumeUp' && _volumeButtonEnabled) {
        debugPrint('[Activation] Volume up pressed');
        onFeedback?.call('Volume button pressed. Listening...');
        onActivate?.call();
        notifyListeners();
      }
      return null;
    });
  }
  
  /// Enable/disable shake activation
  void setShakeEnabled(bool enabled) {
    _shakeEnabled = enabled;
    notifyListeners();
  }
  
  /// Enable/disable volume button activation
  void setVolumeButtonEnabled(bool enabled) {
    _volumeButtonEnabled = enabled;
    notifyListeners();
  }
  
  /// Enable/disable always listening mode
  void setAlwaysListeningEnabled(bool enabled) {
    _alwaysListeningEnabled = enabled;
    notifyListeners();
  }
  
  /// Handle double-tap gesture (call this from UI)
  void onDoubleTap() {
    debugPrint('[Activation] Double-tap detected');
    onFeedback?.call('Double tap detected. Listening...');
    onActivate?.call();
    notifyListeners();
  }
  
  /// Handle long-press gesture (call this from UI)  
  void onLongPress() {
    debugPrint('[Activation] Long-press detected');
    onFeedback?.call('Long press detected. Listening...');
    onActivate?.call();
    notifyListeners();
  }
  
  @override
  void dispose() {
    _accelerometerSubscription?.cancel();
    super.dispose();
  }
}
