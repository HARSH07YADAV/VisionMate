import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:sensors_plus/sensors_plus.dart';

/// Context Awareness Service
/// 
/// Features:
/// - Detect indoor vs outdoor environment
/// - Time-of-day awareness (morning, afternoon, evening, night)
/// - User movement detection (walking, standing, sitting)
class ContextService extends ChangeNotifier {
  // Environment context
  EnvironmentType _environment = EnvironmentType.unknown;
  DayPeriod _dayPeriod = DayPeriod.afternoon;
  MovementState _movement = MovementState.stationary;
  
  // Location tracking
  Position? _lastPosition;
  double _movementSpeed = 0;
  
  // Accelerometer
  StreamSubscription<AccelerometerEvent>? _accelerometerSub;
  final List<double> _accelerationHistory = [];
  
  // Getters
  EnvironmentType get environment => _environment;
  DayPeriod get dayPeriod => _dayPeriod;
  MovementState get movement => _movement;
  double get movementSpeed => _movementSpeed;
  
  /// Initialize context detection
  Future<void> initialize() async {
    _updateDayPeriod();
    _startMovementDetection();
    await _detectEnvironment();
    
    // Update time periodically
    Timer.periodic(const Duration(minutes: 30), (_) => _updateDayPeriod());
    
    debugPrint('[Context] Initialized: $_environment, $_dayPeriod, $_movement');
    notifyListeners();
  }
  
  /// Update time of day
  void _updateDayPeriod() {
    final hour = DateTime.now().hour;
    
    if (hour >= 5 && hour < 12) {
      _dayPeriod = DayPeriod.morning;
    } else if (hour >= 12 && hour < 17) {
      _dayPeriod = DayPeriod.afternoon;
    } else if (hour >= 17 && hour < 21) {
      _dayPeriod = DayPeriod.evening;
    } else {
      _dayPeriod = DayPeriod.night;
    }
    
    notifyListeners();
  }
  
  /// Detect indoor/outdoor based on GPS accuracy
  Future<void> _detectEnvironment() async {
    try {
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      
      _lastPosition = position;
      _movementSpeed = position.speed;
      
      // GPS accuracy heuristic
      if (position.accuracy > 50) {
        _environment = EnvironmentType.indoor;
      } else if (position.accuracy < 20) {
        _environment = EnvironmentType.outdoor;
      } else {
        _environment = EnvironmentType.unknown;
      }
      
      if (position.speed > 1.5) {
        _movement = MovementState.walking;
      }
      
      notifyListeners();
    } catch (e) {
      debugPrint('[Context] GPS error: $e');
      _environment = EnvironmentType.unknown;
    }
  }
  
  /// Start accelerometer-based movement detection
  void _startMovementDetection() {
    try {
      _accelerometerSub = accelerometerEventStream(
        samplingPeriod: const Duration(milliseconds: 200),
      ).listen(_onAccelerometerEvent);
    } catch (e) {
      debugPrint('[Context] Accelerometer error: $e');
    }
  }
  
  void _onAccelerometerEvent(AccelerometerEvent event) {
    final magnitude = (event.x * event.x + event.y * event.y + event.z * event.z);
    _accelerationHistory.add(magnitude);
    
    if (_accelerationHistory.length > 20) {
      _accelerationHistory.removeAt(0);
    }
    
    if (_accelerationHistory.length >= 10) {
      final avg = _accelerationHistory.reduce((a, b) => a + b) / _accelerationHistory.length;
      final variance = _accelerationHistory.map((v) => (v - avg) * (v - avg)).reduce((a, b) => a + b) / _accelerationHistory.length;
      
      if (variance < 5) {
        _movement = MovementState.stationary;
      } else if (variance < 50) {
        _movement = MovementState.standing;
      } else {
        _movement = MovementState.walking;
      }
    }
  }
  
  /// Get greeting based on time of day
  String getGreeting() {
    return switch (_dayPeriod) {
      DayPeriod.morning => 'Good morning',
      DayPeriod.afternoon => 'Good afternoon',
      DayPeriod.evening => 'Good evening',
      DayPeriod.night => 'Hello',
    };
  }
  
  /// Should reduce speech (e.g., user is stationary)
  bool get shouldReduceSpeech => _movement == MovementState.stationary;
  
  /// Get announcement frequency adjustment
  double get announcementFrequencyMultiplier {
    if (_movement == MovementState.stationary) return 0.5;
    if (_movement == MovementState.walking) return 1.0;
    return 0.8;
  }
  
  /// Check if it's dark (night time)
  bool get isDark => _dayPeriod == DayPeriod.night;
  
  /// Check if user is moving
  bool get isMoving => _movement == MovementState.walking;
  
  @override
  void dispose() {
    _accelerometerSub?.cancel();
    super.dispose();
  }
}

/// Environment type
enum EnvironmentType {
  indoor,
  outdoor,
  unknown,
}

/// Day period (renamed from TimeOfDay to avoid Flutter conflict)
enum DayPeriod {
  morning,   // 5am - 12pm
  afternoon, // 12pm - 5pm
  evening,   // 5pm - 9pm
  night,     // 9pm - 5am
}

/// Movement state
enum MovementState {
  stationary,
  standing,
  walking,
}
