import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_recognition_error.dart';

/// Week 3: Always-on wake word detection service
/// 
/// Continuously listens for "Hey Vision" wake word using low-power
/// short-burst speech recognition. When detected, triggers full
/// voice command listening.
/// 
/// Features:
/// - Continuous background listening in short intervals
/// - Wake word detection: "hey vision", "hey visionmate"
/// - Auto-restart after timeout
/// - Battery-aware: pauses when disabled or app backgrounded
/// - Integrates with VoiceCommandService via callback
class WakeWordService extends ChangeNotifier {
  final stt.SpeechToText _speech = stt.SpeechToText();
  
  bool _isInitialized = false;
  bool _isWakeListening = false;
  bool _enabled = false;
  bool _isPaused = false;
  Timer? _restartTimer;
  
  // Callback when wake word is detected
  VoidCallback? onWakeWordDetected;
  Function(String)? onFeedback;
  
  // Wake word phrases to match
  static const List<String> _wakeWords = [
    'hey vision',
    'hey visionmate',
    'hey vision mate',
    'a vision',       // Common misrecognition
    'hey visual',     // Common misrecognition
  ];
  
  // Listening configuration
  static const Duration _listenDuration = Duration(seconds: 3);
  static const Duration _restartDelay = Duration(milliseconds: 500);
  
  bool get isInitialized => _isInitialized;
  bool get isWakeListening => _isWakeListening;
  bool get enabled => _enabled;
  
  /// Initialize the wake word service
  Future<bool> initialize() async {
    try {
      _isInitialized = await _speech.initialize(
        onStatus: _onStatus,
        onError: _onError,
        debugLogging: false, // Keep quiet for background listening
      );
      
      if (_isInitialized) {
        debugPrint('[WakeWord] Initialized successfully');
      } else {
        debugPrint('[WakeWord] Speech recognition not available');
      }
      
      notifyListeners();
      return _isInitialized;
    } catch (e) {
      debugPrint('[WakeWord] Initialization error: $e');
      _isInitialized = false;
      notifyListeners();
      return false;
    }
  }
  
  /// Enable/disable wake word detection
  void setEnabled(bool enabled) {
    _enabled = enabled;
    if (enabled && _isInitialized) {
      _startWakeListening();
    } else {
      _stopWakeListening();
    }
    notifyListeners();
  }
  
  /// Pause wake listening (e.g., during active voice command)
  void pause() {
    _isPaused = true;
    _stopWakeListening();
  }
  
  /// Resume wake listening after pause
  void resume() {
    _isPaused = false;
    if (_enabled && _isInitialized) {
      // Small delay to let voice command service release the mic
      _restartTimer?.cancel();
      _restartTimer = Timer(const Duration(seconds: 1), () {
        _startWakeListening();
      });
    }
  }
  
  /// Start continuous wake word listening
  Future<void> _startWakeListening() async {
    if (!_isInitialized || !_enabled || _isPaused || _isWakeListening) return;
    
    try {
      await _speech.listen(
        onResult: _onWakeResult,
        listenFor: _listenDuration,
        pauseFor: const Duration(seconds: 2),
        partialResults: true,
        cancelOnError: false,
        listenMode: stt.ListenMode.search, // Low-power mode
      );
      _isWakeListening = true;
      notifyListeners();
    } catch (e) {
      debugPrint('[WakeWord] Error starting: $e');
      _isWakeListening = false;
      // Try again after delay
      _scheduleRestart();
    }
  }
  
  /// Stop wake word listening
  Future<void> _stopWakeListening() async {
    _restartTimer?.cancel();
    try {
      await _speech.stop();
      _isWakeListening = false;
      notifyListeners();
    } catch (e) {
      debugPrint('[WakeWord] Error stopping: $e');
    }
  }
  
  /// Schedule a restart of wake listening
  void _scheduleRestart() {
    _restartTimer?.cancel();
    if (!_enabled || _isPaused) return;
    
    _restartTimer = Timer(_restartDelay, () {
      if (_enabled && !_isPaused && _isInitialized) {
        _startWakeListening();
      }
    });
  }
  
  /// Handle speech status changes
  void _onStatus(String status) {
    if (status == 'listening') {
      _isWakeListening = true;
    } else if (status == 'notListening' || status == 'done') {
      _isWakeListening = false;
      // Auto-restart listening loop
      _scheduleRestart();
    }
    notifyListeners();
  }
  
  /// Handle speech errors
  void _onError(SpeechRecognitionError error) {
    debugPrint('[WakeWord] Error: ${error.errorMsg}');
    _isWakeListening = false;
    
    // Don't restart on permanent errors
    if (error.permanent) {
      debugPrint('[WakeWord] Permanent error, disabling');
      _enabled = false;
    } else {
      // Retry after delay for transient errors
      _scheduleRestart();
    }
    notifyListeners();
  }
  
  /// Handle speech recognition results - check for wake word
  void _onWakeResult(SpeechRecognitionResult result) {
    final words = result.recognizedWords.toLowerCase().trim();
    
    if (words.isEmpty) return;
    
    // Check if any wake word was detected
    for (final wakeWord in _wakeWords) {
      if (words.contains(wakeWord)) {
        debugPrint('[WakeWord] Wake word detected: "$words"');
        _onWakeWordDetected();
        return;
      }
    }
  }
  
  /// Called when wake word is successfully detected
  void _onWakeWordDetected() {
    // Stop wake listening first (release mic for voice commands)
    _stopWakeListening();
    
    // Provide audio feedback
    onFeedback?.call("I'm listening");
    
    // Trigger voice command listening
    onWakeWordDetected?.call();
    
    // Resume wake listening after a delay (voice command will finish)
    _restartTimer?.cancel();
    _restartTimer = Timer(const Duration(seconds: 20), () {
      if (_enabled && !_isPaused) {
        _startWakeListening();
      }
    });
  }
  
  @override
  void dispose() {
    _restartTimer?.cancel();
    _speech.stop();
    _speech.cancel();
    super.dispose();
  }
}
