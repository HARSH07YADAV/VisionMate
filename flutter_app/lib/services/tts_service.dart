import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';

import '../models/detection.dart';
import 'settings_service.dart';

/// Enhanced TTS service with:
/// - Priority-based announcements (Feature 4)
/// - Customizable voice speed (Feature 6)
/// - Spatial audio hints (Feature 5)
/// - Path clear notifications (Feature 7)
class TTSService extends ChangeNotifier {
  final FlutterTts _flutterTts = FlutterTts();
  SettingsService? _settings;
  
  bool _isInitialized = false;
  bool _isSpeaking = false;
  final List<_SpeechRequest> _queue = [];
  final Map<String, DateTime> _cooldowns = {};
  
  static const Duration cooldownDuration = Duration(seconds: 3);

  bool get isInitialized => _isInitialized;
  bool get isSpeaking => _isSpeaking;

  /// Initialize TTS engine with settings
  Future<void> initialize({SettingsService? settings}) async {
    _settings = settings;
    
    try {
      await _flutterTts.setLanguage('en-US');
      await _flutterTts.setSpeechRate(_settings?.speechRate ?? 0.5);
      await _flutterTts.setVolume(_settings?.speechVolume ?? 1.0);
      await _flutterTts.setPitch(0.95);

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
      debugPrint('TTS: Initialized');
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

    // Add spatial hint to message
    final spatialMessage = _addSpatialHint(message, position);

    final request = _SpeechRequest(
      message: spatialMessage,
      priority: priority,
      timestamp: DateTime.now(),
    );

    if (priority == SpeechPriority.interrupt) {
      await _speakImmediately(request);
    } else if (priority == SpeechPriority.high && _isSpeaking) {
      // For high priority, add to front of queue
      _queue.insert(0, request);
    } else {
      _queue.add(request);
      _queue.sort((a, b) => a.priority.index.compareTo(b.priority.index));
      if (!_isSpeaking) {
        _processQueue();
      }
    }
  }

  /// Add spatial audio hint to message
  String _addSpatialHint(String message, RelativePosition? position) {
    if (position == null) return message;
    
    final hint = position.description;
    // Check if message already contains position info
    if (message.toLowerCase().contains('left') || 
        message.toLowerCase().contains('right') ||
        message.toLowerCase().contains('ahead')) {
      return message;
    }
    return '$message, $hint';
  }

  /// Speak immediately, interrupting current speech
  Future<void> speakImmediately(String message) async {
    await speak(message, priority: SpeechPriority.interrupt);
  }

  Future<void> _speakImmediately(_SpeechRequest request) async {
    await stop();
    _queue.clear();
    await _flutterTts.speak(request.message);
  }

  void _processQueue() {
    if (_queue.isEmpty || _isSpeaking) return;

    final next = _queue.removeAt(0);
    _flutterTts.speak(next.message);
  }

  /// Speak detection with priority and position
  Future<void> speakDetection(Detection detection) async {
    final priority = switch (detection.dangerLevel) {
      DangerLevel.critical => SpeechPriority.interrupt,
      DangerLevel.high => SpeechPriority.high,
      DangerLevel.medium => SpeechPriority.normal,
      _ => SpeechPriority.low,
    };

    final distance = detection.distanceDescription;
    final message = '${detection.className} $distance';

    await speak(
      message,
      priority: priority,
      cooldownKey: '${detection.className}_${detection.relativePosition}',
      position: detection.relativePosition,
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
      position: risk.detection.relativePosition,
    );
  }

  /// Announce path is clear (Feature 7)
  Future<void> speakPathClear() async {
    await speak(
      'Path is clear',
      priority: SpeechPriority.low,
      cooldownKey: 'path_clear',
    );
  }

  /// Announce emergency
  Future<void> speakEmergency(String message) async {
    await speakImmediately('Emergency: $message');
  }

  /// Stop all speech
  Future<void> stop() async {
    await _flutterTts.stop();
    _isSpeaking = false;
    _queue.clear();
    notifyListeners();
  }

  /// Clear cooldowns
  void clearCooldowns() {
    _cooldowns.clear();
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
  high,      // Next in queue, may interrupt low priority
  normal,    // Standard priority
  low,       // Only if queue empty
}
