import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:sensors_plus/sensors_plus.dart';

/// Accessibility activation and safety monitoring service
/// 
/// Features:
/// 1. Shake to speak - Shake phone to activate voice
/// 2. Volume button - Hardware key for voice activation
/// 3. Double-tap/Long-press - Gesture activation
/// 4. Fall detection - Detect falls and ask "Are you okay?"
/// 5. Auto-SOS - Trigger emergency if no response after fall
enum ActivationMethod {
  shake,
  volumeButton,
  doubleTap,
  alwaysListening,
}

class AccessibilityActivationService extends ChangeNotifier {
  // Accelerometer
  StreamSubscription<AccelerometerEvent>? _accelerometerSubscription;
  DateTime _lastShakeTime = DateTime.now();
  double _lastX = 0, _lastY = 0, _lastZ = 0;
  bool _shakeEnabled = true;
  
  // Fall detection
  bool _fallDetectionEnabled = true;
  DateTime? _lastFallTime;
  Timer? _fallResponseTimer;
  bool _awaitingFallResponse = false;
  static const int _fallResponseTimeoutSec = 30;
  
  // Fall detection algorithm
  final List<double> _accelerationHistory = [];
  static const int _historySize = 10;
  static const double _fallThreshold = 25.0; // Sudden high acceleration
  static const double _impactThreshold = 30.0; // Impact force
  static const double _stillnessThreshold = 2.0; // Post-fall stillness
  
  // Volume button detection
  static const _volumeChannel = MethodChannel('com.example.blind_assist/volume');
  bool _volumeButtonEnabled = true;
  
  // Always listening
  bool _alwaysListeningEnabled = false;
  
  // Callbacks
  Function? onActivate;
  Function(String)? onFeedback;
  Function? onFallDetected;
  Function? onFallConfirmed; // User didn't respond - trigger SOS
  Function? onFallCancelled; // User responded OK
  
  // Settings
  static const double _shakeThreshold = 15.0;
  static const int _shakeCooldownMs = 2000;
  
  bool get shakeEnabled => _shakeEnabled;
  bool get volumeButtonEnabled => _volumeButtonEnabled;
  bool get alwaysListeningEnabled => _alwaysListeningEnabled;
  bool get fallDetectionEnabled => _fallDetectionEnabled;
  bool get awaitingFallResponse => _awaitingFallResponse;
  
  /// Initialize all activation methods
  Future<void> initialize() async {
    _initAccelerometer();
    _initVolumeButton();
    debugPrint('[Activation] Initialized - Shake: $_shakeEnabled, Fall: $_fallDetectionEnabled');
  }
  
  /// Initialize accelerometer for shake and fall detection
  void _initAccelerometer() {
    try {
      _accelerometerSubscription = accelerometerEventStream(
        samplingPeriod: const Duration(milliseconds: 50), // Faster for fall detection
      ).listen(_onAccelerometerEvent);
      debugPrint('[Activation] Accelerometer initialized');
    } catch (e) {
      debugPrint('[Activation] Accelerometer not available: $e');
      _shakeEnabled = false;
      _fallDetectionEnabled = false;
    }
  }
  
  /// Handle accelerometer events
  void _onAccelerometerEvent(AccelerometerEvent event) {
    // Calculate acceleration change for shake
    final deltaX = (event.x - _lastX).abs();
    final deltaY = (event.y - _lastY).abs();
    final deltaZ = (event.z - _lastZ).abs();
    
    _lastX = event.x;
    _lastY = event.y;
    _lastZ = event.z;
    
    final accelerationDelta = math.sqrt(deltaX * deltaX + deltaY * deltaY + deltaZ * deltaZ);
    
    // Total acceleration magnitude (includes gravity ~9.8)
    final totalAcceleration = math.sqrt(event.x * event.x + event.y * event.y + event.z * event.z);
    
    // Check for shake
    if (_shakeEnabled) {
      _checkShake(accelerationDelta);
    }
    
    // Check for fall
    if (_fallDetectionEnabled && !_awaitingFallResponse) {
      _checkFall(totalAcceleration, accelerationDelta);
    }
  }
  
  /// Check for shake gesture
  void _checkShake(double acceleration) {
    final now = DateTime.now();
    final timeDiff = now.difference(_lastShakeTime).inMilliseconds;
    
    if (acceleration > _shakeThreshold && timeDiff > _shakeCooldownMs) {
      _lastShakeTime = now;
      _onShakeDetected();
    }
  }
  
  /// Check for fall pattern
  void _checkFall(double totalAcceleration, double accelerationDelta) {
    // Add to history
    _accelerationHistory.add(totalAcceleration);
    if (_accelerationHistory.length > _historySize) {
      _accelerationHistory.removeAt(0);
    }
    
    if (_accelerationHistory.length < _historySize) return;
    
    // Fall detection algorithm:
    // 1. Sudden high acceleration change (falling)
    // 2. Followed by high impact
    // 3. Followed by relative stillness
    
    final recentMax = _accelerationHistory.reduce(math.max);
    final recentMin = _accelerationHistory.reduce(math.min);
    final variance = recentMax - recentMin;
    
    // Free fall detection: acceleration drops near 0 briefly
    // Impact detection: sudden spike > 25 m/s²
    // Post-fall: back to normal ~9.8 m/s²
    
    if (accelerationDelta > _fallThreshold || 
        totalAcceleration > _impactThreshold ||
        (variance > 20 && totalAcceleration < 5)) {
      
      // Cooldown check
      final now = DateTime.now();
      if (_lastFallTime != null && 
          now.difference(_lastFallTime!).inSeconds < 60) {
        return; // Don't trigger multiple times within 60 seconds
      }
      
      _lastFallTime = now;
      _onFallDetected();
    }
  }
  
  /// Called when shake is detected
  void _onShakeDetected() {
    debugPrint('[Activation] Shake detected!');
    onFeedback?.call('Listening...');
    onActivate?.call();
    notifyListeners();
  }
  
  /// Called when fall is detected
  void _onFallDetected() {
    debugPrint('[Safety] Fall detected!');
    _awaitingFallResponse = true;
    
    // Notify app to ask "Are you okay?"
    onFallDetected?.call();
    
    // Start timeout timer
    _fallResponseTimer?.cancel();
    _fallResponseTimer = Timer(Duration(seconds: _fallResponseTimeoutSec), () {
      if (_awaitingFallResponse) {
        debugPrint('[Safety] No response to fall - triggering SOS');
        _awaitingFallResponse = false;
        onFallConfirmed?.call(); // Trigger SOS
      }
    });
    
    notifyListeners();
  }
  
  /// User responded they are OK after fall
  void confirmUserOkay() {
    debugPrint('[Safety] User confirmed OK');
    _fallResponseTimer?.cancel();
    _awaitingFallResponse = false;
    onFallCancelled?.call();
    _accelerationHistory.clear();
    notifyListeners();
  }
  
  /// User needs help after fall
  void confirmUserNeedsHelp() {
    debugPrint('[Safety] User needs help');
    _fallResponseTimer?.cancel();
    _awaitingFallResponse = false;
    onFallConfirmed?.call(); // Trigger SOS
    notifyListeners();
  }
  
  /// Initialize volume button listener
  void _initVolumeButton() {
    _volumeChannel.setMethodCallHandler((call) async {
      if (call.method == 'onVolumeUp' && _volumeButtonEnabled) {
        // If awaiting fall response, treat as "I'm okay"
        if (_awaitingFallResponse) {
          confirmUserOkay();
          onFeedback?.call("Okay, glad you're safe.");
        } else {
          debugPrint('[Activation] Volume up pressed');
          onFeedback?.call('Listening...');
          onActivate?.call();
        }
        notifyListeners();
      }
      return null;
    });
  }
  
  // ==================== Settings ====================
  
  void setShakeEnabled(bool enabled) {
    _shakeEnabled = enabled;
    notifyListeners();
  }
  
  void setVolumeButtonEnabled(bool enabled) {
    _volumeButtonEnabled = enabled;
    notifyListeners();
  }
  
  void setAlwaysListeningEnabled(bool enabled) {
    _alwaysListeningEnabled = enabled;
    notifyListeners();
  }
  
  void setFallDetectionEnabled(bool enabled) {
    _fallDetectionEnabled = enabled;
    notifyListeners();
  }
  
  // ==================== Gesture Handlers ====================
  
  void onDoubleTap() {
    if (_awaitingFallResponse) {
      confirmUserOkay();
      onFeedback?.call("Okay, glad you're safe.");
      return;
    }
    debugPrint('[Activation] Double-tap detected');
    onActivate?.call();
    notifyListeners();
  }
  
  void onLongPress() {
    if (_awaitingFallResponse) {
      confirmUserOkay();
      onFeedback?.call("Okay, glad you're safe.");
      return;
    }
    debugPrint('[Activation] Long-press detected');
    onFeedback?.call('Listening...');
    onActivate?.call();
    notifyListeners();
  }
  
  @override
  void dispose() {
    _accelerometerSubscription?.cancel();
    _fallResponseTimer?.cancel();
    super.dispose();
  }
}
