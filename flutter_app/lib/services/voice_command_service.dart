import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_recognition_error.dart';

/// Voice command types - extended for natural language
enum VoiceCommand {
  whatsAhead,       // "What's ahead", "What do you see"
  start,            // "Start", "Begin", "Go", "Guide me"
  stop,             // "Stop", "Pause", "Wait"
  emergency,        // "Help", "Help me", "Emergency", "SOS"
  repeat,           // "Repeat", "Again"
  faster,           // "Faster", "Speed up"
  slower,           // "Slower", "Slow down"
  louder,           // "Louder", "Volume up"
  quieter,          // "Quieter", "Volume down"
  settings,         // "Settings", "Options"
  findObject,       // "Find the door", "Where is the chair"
  readText,         // "Read this", "What does it say"
  identifyCurrency, // "What note is this", "Identify currency"
  pathClear,        // "Is the path clear"
  imOkay,           // "I'm okay", "I'm fine" (for fall)
  unknown,          // Unrecognized
}

/// Voice command service with natural language understanding
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
  Function(String)? onFindObject;  // Pass the object name
  Function? onReadText;
  Function? onIdentifyCurrency;
  Function? onPathClear;
  Function? onImOkay;
  Function(VoiceCommand, String)? onAnyCommand;
  Function(String)? onUnknownCommand;  // For feedback on unrecognized

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
        debugPrint('[Voice] Speech recognition initialized');
      } else {
        debugPrint('[Voice] Speech recognition not available');
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

  void _onStatus(String status) {
    if (status == 'listening') {
      _isListening = true;
    } else if (status == 'notListening' || status == 'done') {
      _isListening = false;
    }
    notifyListeners();
  }

  void _onError(SpeechRecognitionError error) {
    debugPrint('[Voice] Error: ${error.errorMsg}');
    _isListening = false;
    notifyListeners();
  }

  void setEnabled(bool enabled) {
    _enabled = enabled;
    if (!enabled) stopListening();
    notifyListeners();
  }

  Future<void> startListening() async {
    if (!_isInitialized || !_enabled || _isListening) return;

    try {
      await _speech.listen(
        onResult: _onResult,
        listenFor: const Duration(seconds: 15), // Shorter for responsiveness
        pauseFor: const Duration(seconds: 2),
        partialResults: true,
        cancelOnError: false,
        listenMode: stt.ListenMode.confirmation,
      );
      _isListening = true;
      notifyListeners();
    } catch (e) {
      debugPrint('[Voice] Error starting: $e');
      _isListening = false;
      notifyListeners();
    }
  }

  Future<void> stopListening() async {
    try {
      await _speech.stop();
      _isListening = false;
      notifyListeners();
    } catch (e) {
      debugPrint('[Voice] Error stopping: $e');
    }
  }

  Future<void> toggleListening() async {
    if (_isListening) {
      await stopListening();
    } else {
      await startListening();
    }
  }

  void _onResult(SpeechRecognitionResult result) {
    _lastWords = result.recognizedWords;
    _confidence = result.confidence;
    
    if (result.finalResult && _lastWords.isNotEmpty) {
      final parsed = _parseCommand(_lastWords);
      _executeCommand(parsed.command, parsed.objectName, _lastWords);
    }
    
    notifyListeners();
  }

  /// Parse natural language command
  _ParsedCommand _parseCommand(String words) {
    final lower = words.toLowerCase().trim();
    
    // === EMERGENCY (highest priority) ===
    if (lower.contains("help me") || 
        lower == "help" ||
        lower.contains("emergency") ||
        lower.contains("sos") ||
        lower.contains("call for help") ||
        lower.contains("i need help")) {
      return _ParsedCommand(VoiceCommand.emergency);
    }
    
    // === I'M OKAY (for fall detection response) ===
    if (lower.contains("i'm okay") || 
        lower.contains("i am okay") ||
        lower.contains("i'm fine") ||
        lower.contains("i am fine") ||
        lower.contains("i'm alright") ||
        lower.contains("yes") ||
        lower.contains("no help")) {
      return _ParsedCommand(VoiceCommand.imOkay);
    }
    
    // === FIND OBJECT ===
    // "Find the door", "Where is the chair", "Locate the table"
    final findPatterns = [
      RegExp(r'find (?:the |a )?(\w+)', caseSensitive: false),
      RegExp(r'where is (?:the |a )?(\w+)', caseSensitive: false),
      RegExp(r'locate (?:the |a )?(\w+)', caseSensitive: false),
      RegExp(r'look for (?:the |a )?(\w+)', caseSensitive: false),
    ];
    for (final pattern in findPatterns) {
      final match = pattern.firstMatch(lower);
      if (match != null && match.group(1) != null) {
        return _ParsedCommand(VoiceCommand.findObject, match.group(1));
      }
    }
    
    // === WHAT'S AHEAD ===
    if (lower.contains("what's ahead") || 
        lower.contains("what is ahead") ||
        lower.contains("what do you see") ||
        lower.contains("what's in front") ||
        lower.contains("what is in front") ||
        lower.contains("describe") ||
        lower.contains("scan") ||
        lower.contains("look ahead")) {
      return _ParsedCommand(VoiceCommand.whatsAhead);
    }
    
    // === PATH CLEAR ===
    if (lower.contains("is the path clear") ||
        lower.contains("path clear") ||
        lower.contains("is it safe") ||
        lower.contains("can i go")) {
      return _ParsedCommand(VoiceCommand.pathClear);
    }
    
    // === READ TEXT ===
    if (lower.contains("read this") ||
        lower.contains("read that") ||
        lower.contains("what does it say") ||
        lower.contains("read the text") ||
        lower.contains("read the sign")) {
      return _ParsedCommand(VoiceCommand.readText);
    }
    
    // === IDENTIFY CURRENCY ===
    if (lower.contains("what note") ||
        lower.contains("identify money") ||
        lower.contains("identify currency") ||
        lower.contains("what rupee") ||
        lower.contains("currency") ||
        lower.contains("how much money") ||
        lower.contains("what denomination")) {
      return _ParsedCommand(VoiceCommand.identifyCurrency);
    }
    
    // === STOP ===
    if (lower.contains("stop") || 
        lower.contains("pause") ||
        lower.contains("wait") ||
        lower.contains("be quiet") ||
        lower.contains("silence") ||
        lower.contains("shut up")) { // Common expression
      return _ParsedCommand(VoiceCommand.stop);
    }
    
    // === START ===
    if (lower.contains("start") || 
        lower.contains("begin") ||
        lower.contains("go") ||
        lower.contains("resume") ||
        lower.contains("continue") ||
        lower.contains("guide me") ||
        lower.contains("lead the way")) {
      return _ParsedCommand(VoiceCommand.start);
    }
    
    // === REPEAT ===
    if (lower.contains("repeat") || 
        lower.contains("again") ||
        lower.contains("say that again") ||
        lower.contains("what was that") ||
        lower.contains("pardon") ||
        lower.contains("come again")) {
      return _ParsedCommand(VoiceCommand.repeat);
    }
    
    // === SPEED ===
    if (lower.contains("faster") || lower.contains("speed up") || lower.contains("quicker")) {
      return _ParsedCommand(VoiceCommand.faster);
    }
    if (lower.contains("slower") || lower.contains("slow down")) {
      return _ParsedCommand(VoiceCommand.slower);
    }
    
    // === VOLUME ===
    if (lower.contains("louder") || lower.contains("volume up") || lower.contains("speak up")) {
      return _ParsedCommand(VoiceCommand.louder);
    }
    if (lower.contains("quieter") || lower.contains("volume down") || lower.contains("softer")) {
      return _ParsedCommand(VoiceCommand.quieter);
    }
    
    // === SETTINGS ===
    if (lower.contains("settings") || lower.contains("options") || lower.contains("preferences")) {
      return _ParsedCommand(VoiceCommand.settings);
    }
    
    return _ParsedCommand(VoiceCommand.unknown);
  }

  void _executeCommand(VoiceCommand command, String? objectName, String rawWords) {
    _lastCommand = command.name;
    debugPrint('[Voice] Command: $command, Object: $objectName');
    
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
      case VoiceCommand.findObject:
        if (objectName != null) {
          onFindObject?.call(objectName);
        }
        break;
      case VoiceCommand.readText:
        onReadText?.call();
        break;
      case VoiceCommand.identifyCurrency:
        onIdentifyCurrency?.call();
        break;
      case VoiceCommand.pathClear:
        onPathClear?.call();
        break;
      case VoiceCommand.imOkay:
        onImOkay?.call();
        break;
      case VoiceCommand.unknown:
        onUnknownCommand?.call(rawWords);
        break;
    }
    
    onAnyCommand?.call(command, rawWords);
    notifyListeners();
  }

  Future<bool> checkAvailability() async {
    if (!_isInitialized) {
      return await initialize();
    }
    return _isInitialized;
  }

  @override
  void dispose() {
    _speech.stop();
    _speech.cancel();
    super.dispose();
  }
}

/// Parsed command with optional object name
class _ParsedCommand {
  final VoiceCommand command;
  final String? objectName;
  
  _ParsedCommand(this.command, [this.objectName]);
}
