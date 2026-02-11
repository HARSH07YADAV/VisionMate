import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';

import '../models/detection.dart';
import 'settings_service.dart';

/// Enhanced TTS service with:
/// - Calm, human-like speech
/// - Short, actionable phrases
/// - Emotional support
/// - Distance in human terms (steps)
/// - Confidence-aware announcements
/// - Week 2: Priority queue with max size, stale pruning, dedup
/// - Week 2: Verbosity-aware announcements
class TTSService extends ChangeNotifier {
  final FlutterTts _flutterTts = FlutterTts();
  SettingsService? _settings;
  
  bool _isInitialized = false;
  bool _isSpeaking = false;
  final List<_SpeechRequest> _queue = [];
  final Map<String, DateTime> _cooldowns = {};
  String _lastAnnouncement = '';
  
  static const Duration cooldownDuration = Duration(seconds: 3);
  
  // Week 2: Queue limits
  static const int _maxQueueSize = 5;
  static const Duration _staleThreshold = Duration(seconds: 3);

  // Emotional support phrases
  static const List<String> _reassuringPhrases = [
    "You're safe.",
    "Take your time.",
    "I'm here with you.",
    "All clear for now.",
    "You're doing great.",
  ];

  bool get isInitialized => _isInitialized;
  bool get isSpeaking => _isSpeaking;
  String get lastAnnouncement => _lastAnnouncement;

  /// Initialize TTS engine with settings
  Future<void> initialize({SettingsService? settings}) async {
    _settings = settings;
    
    try {
      await _flutterTts.setLanguage('en-US');
      await _flutterTts.setSpeechRate(_settings?.speechRate ?? 0.45);
      await _flutterTts.setVolume(_settings?.speechVolume ?? 1.0);
      await _flutterTts.setPitch(0.9); // Slightly lower for calmer voice

      _flutterTts.setStartHandler(() {
        _isSpeaking = true;
        notifyListeners();
      });

      _flutterTts.setCompletionHandler(() {
        _isSpeaking = false;
        notifyListeners();
        _processQueue();
      });

      _flutterTts.setErrorHandler((error) {
        debugPrint('TTS Error: $error');
        _isSpeaking = false;
        notifyListeners();
        _processQueue();
      });

      _isInitialized = true;
      notifyListeners();
      debugPrint('TTS: Initialized with calm settings');
    } catch (e) {
      debugPrint('TTS: Init failed: $e');
    }
  }

  /// Update speech settings
  Future<void> updateSettings() async {
    if (_settings != null && _isInitialized) {
      await _flutterTts.setSpeechRate(_settings!.speechRate);
      await _flutterTts.setVolume(_settings!.speechVolume);
    }
  }

  /// Convert meters to human-friendly steps
  /// Average step is ~0.75 meters
  String _metersToSteps(double meters) {
    if (meters < 0.5) return 'very close';
    if (meters < 1.0) return 'one step away';
    if (meters < 1.5) return 'two steps away';
    if (meters < 2.0) return 'three steps away';
    if (meters < 3.0) return 'a few steps ahead';
    if (meters < 5.0) return 'several steps ahead';
    return 'in the distance';
  }

  /// Convert position to simple direction
  String _positionToDirection(RelativePosition? pos) {
    if (pos == null) return '';
    return switch (pos) {
      RelativePosition.left => 'to your left',
      RelativePosition.center => 'straight ahead',
      RelativePosition.right => 'to your right',
    };
  }

  /// Build calm, short announcement for detection (normal verbosity)
  String _buildCalmAnnouncement(Detection detection) {
    final name = detection.className;
    final distance = _metersToSteps(detection.distanceMeters);
    final direction = _positionToDirection(detection.relativePosition);
    
    // Build short phrase: "[Object], [distance], [direction]"
    if (direction.isNotEmpty && direction != 'straight ahead') {
      return '$name, $distance, $direction';
    }
    return '$name, $distance';
  }

  /// Week 2: Build detailed announcement (detailed verbosity)
  String _buildDetailedAnnouncement(Detection detection) {
    final name = detection.className;
    final distance = _metersToSteps(detection.distanceMeters);
    final direction = _positionToDirection(detection.relativePosition);
    final confidence = (detection.confidence * 100).toInt();
    final danger = detection.dangerLevel.name;
    
    String msg = 'I see a $name, $distance';
    if (direction.isNotEmpty) {
      msg += ', $direction';
    }
    msg += '. Confidence $confidence percent, $danger risk.';
    return msg;
  }

  /// Speak with confidence indicator
  Future<void> speakWithConfidence(String message, double confidence) async {
    String prefix = '';
    if (confidence < 0.3) {
      prefix = 'I think I see ';
    } else if (confidence < 0.5) {
      prefix = 'Possibly ';
    }
    await speak('$prefix$message');
  }

  // ==================== Speed/Volume Controls ====================

  Future<void> increaseSpeed() async {
    if (_settings != null) {
      final newRate = (_settings!.speechRate + 0.1).clamp(0.1, 1.0);
      await _settings!.setSpeechRate(newRate);
      await _flutterTts.setSpeechRate(newRate);
      await speak('Faster', priority: SpeechPriority.high);
    }
  }

  Future<void> decreaseSpeed() async {
    if (_settings != null) {
      final newRate = (_settings!.speechRate - 0.1).clamp(0.1, 1.0);
      await _settings!.setSpeechRate(newRate);
      await _flutterTts.setSpeechRate(newRate);
      await speak('Slower', priority: SpeechPriority.high);
    }
  }

  Future<void> increaseVolume() async {
    if (_settings != null) {
      final newVol = (_settings!.speechVolume + 0.2).clamp(0.2, 1.0);
      await _settings!.setSpeechVolume(newVol);
      await _flutterTts.setVolume(newVol);
      await speak('Louder', priority: SpeechPriority.high);
    }
  }

  Future<void> decreaseVolume() async {
    if (_settings != null) {
      final newVol = (_settings!.speechVolume - 0.2).clamp(0.2, 1.0);
      await _settings!.setSpeechVolume(newVol);
      await _flutterTts.setVolume(newVol);
      await speak('Quieter', priority: SpeechPriority.high);
    }
  }

  // ==================== Core Speech Methods ====================

  /// Speak with priority and spatial audio hint
  Future<void> speak(
    String message, {
    SpeechPriority priority = SpeechPriority.normal,
    String? cooldownKey,
    RelativePosition? position,
  }) async {
    if (!_isInitialized) await initialize();

    // Check cooldown
    if (cooldownKey != null) {
      final lastSpoken = _cooldowns[cooldownKey];
      if (lastSpoken != null &&
          DateTime.now().difference(lastSpoken) < cooldownDuration) {
        return;
      }
      _cooldowns[cooldownKey] = DateTime.now();
    }

    _lastAnnouncement = message;

    final request = _SpeechRequest(
      message: message,
      priority: priority,
      timestamp: DateTime.now(),
    );

    if (priority == SpeechPriority.interrupt) {
      await _speakImmediately(request);
    } else if (priority == SpeechPriority.high && _isSpeaking) {
      // Week 2: Check for duplicate in queue before adding
      if (!_isDuplicateInQueue(message)) {
        _queue.insert(0, request);
        _pruneQueue();
      }
    } else {
      // Week 2: Check for duplicate in queue before adding
      if (!_isDuplicateInQueue(message)) {
        _queue.add(request);
        _queue.sort((a, b) => a.priority.index.compareTo(b.priority.index));
        _pruneQueue();
      }
      if (!_isSpeaking) {
        _processQueue();
      }
    }
  }

  Future<void> speakImmediately(String message) async {
    await speak(message, priority: SpeechPriority.interrupt);
  }

  Future<void> _speakImmediately(_SpeechRequest request) async {
    await stop();
    _queue.clear();
    _lastAnnouncement = request.message;
    await _flutterTts.speak(request.message);
  }

  void _processQueue() {
    if (_queue.isEmpty || _isSpeaking) return;
    
    // Week 2: Remove stale messages before processing
    _removeStaleMessages();
    
    if (_queue.isEmpty) return;
    
    final next = _queue.removeAt(0);
    _lastAnnouncement = next.message;
    _flutterTts.speak(next.message);
  }

  /// Week 2: Check if identical message already exists in queue
  bool _isDuplicateInQueue(String message) {
    return _queue.any((r) => r.message == message);
  }

  /// Week 2: Remove messages older than stale threshold
  void _removeStaleMessages() {
    final now = DateTime.now();
    _queue.removeWhere((r) => now.difference(r.timestamp) > _staleThreshold);
  }

  /// Week 2: Enforce max queue size, drop lowest priority
  void _pruneQueue() {
    // Remove stale first
    _removeStaleMessages();
    
    // If still over limit, drop lowest priority (end of sorted list)
    while (_queue.length > _maxQueueSize) {
      _queue.removeLast();
    }
  }

  // ==================== Detection Announcements ====================

  /// Speak detection in calm, short format
  Future<void> speakDetection(Detection detection) async {
    final priority = switch (detection.dangerLevel) {
      DangerLevel.critical => SpeechPriority.interrupt,
      DangerLevel.high => SpeechPriority.high,
      DangerLevel.medium => SpeechPriority.normal,
      _ => SpeechPriority.low,
    };

    // Use the new calm announcement format
    final message = _buildCalmAnnouncement(detection);

    await speak(
      message,
      priority: priority,
      cooldownKey: '${detection.className}_${detection.relativePosition}',
    );
  }

  /// Week 2: Speak detection with verbosity awareness
  Future<void> speakDetectionWithVerbosity(
    Detection detection,
    VerbosityLevel verbosity,
  ) async {
    // In minimal mode, TTS is skipped (earcons handle it)
    if (verbosity == VerbosityLevel.minimal) return;

    final priority = switch (detection.dangerLevel) {
      DangerLevel.critical => SpeechPriority.interrupt,
      DangerLevel.high => SpeechPriority.high,
      DangerLevel.medium => SpeechPriority.normal,
      _ => SpeechPriority.low,
    };

    final message = verbosity == VerbosityLevel.detailed
        ? _buildDetailedAnnouncement(detection)
        : _buildCalmAnnouncement(detection);

    await speak(
      message,
      priority: priority,
      cooldownKey: '${detection.className}_${detection.relativePosition}',
    );
  }

  /// Speak risk assessment
  Future<void> speakRisk(RiskAssessment risk) async {
    if (!risk.shouldAlert) return;

    final priority = switch (risk.level) {
      RiskLevel.critical => SpeechPriority.interrupt,
      RiskLevel.high => SpeechPriority.high,
      RiskLevel.medium => SpeechPriority.normal,
      _ => SpeechPriority.low,
    };

    await speak(
      risk.recommendation,
      priority: priority,
      cooldownKey: risk.alertKey,
    );
  }

  // ==================== Guidance Announcements ====================

  /// Path is clear - calm confirmation
  Future<void> speakPathClear() async {
    await speak(
      'Path ahead is clear',
      priority: SpeechPriority.low,
      cooldownKey: 'path_clear',
    );
  }

  /// Announce obstacle with distance and direction
  Future<void> speakObstacle(String objectName, double meters, RelativePosition? pos) async {
    final distance = _metersToSteps(meters);
    final direction = _positionToDirection(pos);
    
    String message;
    if (direction.isNotEmpty) {
      message = 'Obstacle ahead, $distance, $direction';
    } else {
      message = 'Obstacle ahead, $distance';
    }
    
    await speak(message, priority: SpeechPriority.high);
  }

  /// Warn about hazard
  Future<void> speakHazardWarning(String hazard, double meters) async {
    final distance = _metersToSteps(meters);
    await speakImmediately('Caution, $hazard, $distance');
  }

  // ==================== Emotional Support ====================

  /// Speak a reassuring phrase
  Future<void> speakReassurance() async {
    final phrase = _reassuringPhrases[Random().nextInt(_reassuringPhrases.length)];
    await speak(phrase, priority: SpeechPriority.low, cooldownKey: 'reassure');
  }

  /// Ask if user is okay (for fall detection)
  Future<void> askAreYouOkay() async {
    await speakImmediately('Are you okay? Say help if you need assistance.');
  }

  /// Confirm user is safe
  Future<void> confirmSafe() async {
    await speak("You're safe.", priority: SpeechPriority.normal);
  }

  /// Encourage user to take their time
  Future<void> encouragePatience() async {
    await speak('Take your time.', priority: SpeechPriority.low);
  }

  // ==================== Emergency ====================

  Future<void> speakEmergency(String message) async {
    await speakImmediately(message);
  }

  // ==================== Control Methods ====================

  Future<void> stop() async {
    await _flutterTts.stop();
    _isSpeaking = false;
    _queue.clear();
    notifyListeners();
  }

  void clearCooldowns() {
    _cooldowns.clear();
  }

  /// Repeat last announcement
  Future<void> repeatLast() async {
    if (_lastAnnouncement.isNotEmpty) {
      await speakImmediately(_lastAnnouncement);
    }
  }

  @override
  void dispose() {
    _flutterTts.stop();
    super.dispose();
  }
}

/// Speech request in queue
class _SpeechRequest {
  final String message;
  final SpeechPriority priority;
  final DateTime timestamp;

  _SpeechRequest({
    required this.message,
    required this.priority,
    required this.timestamp,
  });
}

/// Speech priority levels
enum SpeechPriority {
  interrupt, // Stop current speech immediately
  high,      // Next in queue
  normal,    // Standard priority
  low,       // Only if queue empty
}
