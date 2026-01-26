import 'dart:async';
import 'package:flutter/foundation.dart';

/// Voice command service (Feature 11) - STUB IMPLEMENTATION
/// 
/// Note: speech_to_text package removed due to build issues.
/// Voice commands will be available when user speaks to device microphone
/// using system-level voice recognition (Google Assistant, etc.)
/// 
/// This stub service maintains the interface for future implementation.
class VoiceCommandService extends ChangeNotifier {
  bool _isInitialized = false;
  bool _isListening = false;
  bool _enabled = false;
  String _lastCommand = '';
  
  // Callbacks for commands
  Function? onWhatsAhead;
  Function? onStart;
  Function? onStop;
  Function? onEmergency;
  Function? onRepeat;

  bool get isInitialized => _isInitialized;
  bool get isListening => _isListening;
  bool get enabled => _enabled;
  String get lastCommand => _lastCommand;

  /// Initialize (stub - always fails gracefully)
  Future<void> initialize() async {
    debugPrint('[Voice] Stub service - speech_to_text not available');
    _isInitialized = false;
  }

  /// Enable voice commands (no-op in stub)
  void setEnabled(bool enabled) {
    _enabled = enabled;
    notifyListeners();
  }

  /// Start listening (no-op in stub)
  Future<void> startListening() async {
    debugPrint('[Voice] Speech recognition not available');
  }

  /// Stop listening (no-op in stub)
  Future<void> stopListening() async {
    _isListening = false;
    notifyListeners();
  }

  /// Toggle listening (no-op in stub)
  Future<void> toggleListening() async {
    debugPrint('[Voice] Speech recognition not available');
  }

  @override
  void dispose() {
    super.dispose();
  }
}
