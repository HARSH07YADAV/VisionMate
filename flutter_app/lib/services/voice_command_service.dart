import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_recognition_error.dart';

/// Voice command types
enum VoiceCommand {
  whatsAhead,     // "What's ahead", "What do you see"
  start,          // "Start", "Begin", "Go"
  stop,           // "Stop", "Pause", "Wait"
  emergency,      // "Help", "Emergency", "SOS"
  repeat,         // "Repeat", "Again", "Say that again"
  faster,         // "Faster", "Speed up"
  slower,         // "Slower", "Slow down"
  louder,         // "Louder", "Volume up"
  quieter,        // "Quieter", "Volume down"
  settings,       // "Settings", "Options"
  unknown,        // Unrecognized command
}

/// Voice command service (Feature 11) - Full speech recognition implementation
class VoiceCommandService extends ChangeNotifier {
  final stt.SpeechToText _speech = stt.SpeechToText();
  
  bool _isInitialized = false;
  bool _isListening = false;
  bool _enabled = true;
  String _lastCommand = '';
  String _lastWords = '';
  double _confidence = 0.0;
  
  // Callbacks for commands
  Function? onWhatsAhead;
  Function? onStart;
  Function? onStop;
  Function? onEmergency;
  Function? onRepeat;
  Function? onFaster;
  Function? onSlower;
  Function? onLouder;
  Function? onQuieter;
  Function? onSettings;
  Function(VoiceCommand, String)? onAnyCommand;

  bool get isInitialized => _isInitialized;
  bool get isListening => _isListening;
  bool get enabled => _enabled;
  String get lastCommand => _lastCommand;
  String get lastWords => _lastWords;
  double get confidence => _confidence;

  /// Initialize speech recognition
  Future<bool> initialize() async {
    try {
      _isInitialized = await _speech.initialize(
        onStatus: _onStatus,
        onError: _onError,
        debugLogging: kDebugMode,
      );
      
      if (_isInitialized) {
        debugPrint('[Voice] Speech recognition initialized successfully');
        final locales = await _speech.locales();
        debugPrint('[Voice] Available locales: ${locales.length}');
      } else {
        debugPrint('[Voice] Speech recognition not available on this device');
      }
      
      notifyListeners();
      return _isInitialized;
    } catch (e) {
      debugPrint('[Voice] Initialization error: $e');
      _isInitialized = false;
      notifyListeners();
      return false;
    }
  }

  /// Status callback
  void _onStatus(String status) {
    debugPrint('[Voice] Status: $status');
    if (status == 'listening') {
      _isListening = true;
    } else if (status == 'notListening' || status == 'done') {
      _isListening = false;
    }
    notifyListeners();
  }

  /// Error callback
  void _onError(SpeechRecognitionError error) {
    debugPrint('[Voice] Error: ${error.errorMsg}');
    _isListening = false;
    notifyListeners();
  }

  /// Enable/disable voice commands
  void setEnabled(bool enabled) {
    _enabled = enabled;
    if (!enabled) {
      stopListening();
    }
    notifyListeners();
  }

  /// Start listening for voice commands
  Future<void> startListening() async {
    if (!_isInitialized || !_enabled) {
      debugPrint('[Voice] Cannot start: initialized=$_isInitialized, enabled=$_enabled');
      return;
    }
    
    if (_isListening) {
      debugPrint('[Voice] Already listening');
      return;
    }

    try {
      await _speech.listen(
        onResult: _onResult,
        listenFor: const Duration(seconds: 30),
        pauseFor: const Duration(seconds: 3),
        partialResults: true,
        cancelOnError: false,
        listenMode: stt.ListenMode.confirmation,
      );
      _isListening = true;
      debugPrint('[Voice] Started listening');
      notifyListeners();
    } catch (e) {
      debugPrint('[Voice] Error starting: $e');
      _isListening = false;
      notifyListeners();
    }
  }

  /// Stop listening
  Future<void> stopListening() async {
    try {
      await _speech.stop();
      _isListening = false;
      debugPrint('[Voice] Stopped listening');
      notifyListeners();
    } catch (e) {
      debugPrint('[Voice] Error stopping: $e');
    }
  }

  /// Toggle listening state
  Future<void> toggleListening() async {
    if (_isListening) {
      await stopListening();
    } else {
      await startListening();
    }
  }

  /// Process speech recognition result
  void _onResult(SpeechRecognitionResult result) {
    _lastWords = result.recognizedWords;
    _confidence = result.confidence;
    
    debugPrint('[Voice] Words: $_lastWords (confidence: ${(_confidence * 100).toStringAsFixed(1)}%)');
    
    if (result.finalResult) {
      final command = _parseCommand(_lastWords);
      _executeCommand(command, _lastWords);
    }
    
    notifyListeners();
  }

  /// Parse spoken words into a command
  VoiceCommand _parseCommand(String words) {
    final lower = words.toLowerCase().trim();
    
    // What's ahead / What do you see
    if (lower.contains("what's ahead") || 
        lower.contains("what is ahead") ||
        lower.contains("what do you see") ||
        lower.contains("describe") ||
        lower.contains("scan")) {
      return VoiceCommand.whatsAhead;
    }
    
    // Emergency
    if (lower.contains("help") || 
        lower.contains("emergency") ||
        lower.contains("sos") ||
        lower.contains("danger")) {
      return VoiceCommand.emergency;
    }
    
    // Stop
    if (lower.contains("stop") || 
        lower.contains("pause") ||
        lower.contains("wait") ||
        lower.contains("quiet")) {
      return VoiceCommand.stop;
    }
    
    // Start
    if (lower.contains("start") || 
        lower.contains("begin") ||
        lower.contains("go") ||
        lower.contains("resume") ||
        lower.contains("continue")) {
      return VoiceCommand.start;
    }
    
    // Repeat
    if (lower.contains("repeat") || 
        lower.contains("again") ||
        lower.contains("say that") ||
        lower.contains("what was that")) {
      return VoiceCommand.repeat;
    }
    
    // Speed controls
    if (lower.contains("faster") || lower.contains("speed up")) {
      return VoiceCommand.faster;
    }
    if (lower.contains("slower") || lower.contains("slow down")) {
      return VoiceCommand.slower;
    }
    
    // Volume controls
    if (lower.contains("louder") || lower.contains("volume up")) {
      return VoiceCommand.louder;
    }
    if (lower.contains("quieter") || lower.contains("volume down") || lower.contains("softer")) {
      return VoiceCommand.quieter;
    }
    
    // Settings
    if (lower.contains("settings") || lower.contains("options") || lower.contains("preferences")) {
      return VoiceCommand.settings;
    }
    
    return VoiceCommand.unknown;
  }

  /// Execute the recognized command
  void _executeCommand(VoiceCommand command, String rawWords) {
    _lastCommand = command.name;
    debugPrint('[Voice] Executing command: $command');
    
    // Call specific callback
    switch (command) {
      case VoiceCommand.whatsAhead:
        onWhatsAhead?.call();
        break;
      case VoiceCommand.start:
        onStart?.call();
        break;
      case VoiceCommand.stop:
        onStop?.call();
        break;
      case VoiceCommand.emergency:
        onEmergency?.call();
        break;
      case VoiceCommand.repeat:
        onRepeat?.call();
        break;
      case VoiceCommand.faster:
        onFaster?.call();
        break;
      case VoiceCommand.slower:
        onSlower?.call();
        break;
      case VoiceCommand.louder:
        onLouder?.call();
        break;
      case VoiceCommand.quieter:
        onQuieter?.call();
        break;
      case VoiceCommand.settings:
        onSettings?.call();
        break;
      case VoiceCommand.unknown:
        debugPrint('[Voice] Unknown command: $rawWords');
        break;
    }
    
    // Call generic callback
    onAnyCommand?.call(command, rawWords);
    
    notifyListeners();
  }

  /// Check if speech recognition is available
  Future<bool> checkAvailability() async {
    if (!_isInitialized) {
      return await initialize();
    }
    return _isInitialized;
  }

  /// Get list of available locales
  Future<List<stt.LocaleName>> getLocales() async {
    if (!_isInitialized) return [];
    return await _speech.locales();
  }

  @override
  void dispose() {
    _speech.stop();
    _speech.cancel();
    super.dispose();
  }
}
