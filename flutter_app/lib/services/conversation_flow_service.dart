import 'dart:async';
import 'package:flutter/foundation.dart';

/// Week 3: Conversational flow service
/// 
/// Provides context-aware follow-up after voice commands.
/// Example: After "Find the door" → "Door found on your right,
/// about 5 steps away. Should I guide you?"
/// 
/// Features:
/// - Tracks last command + result as conversation context
/// - Auto-follow-up questions after relevant commands
/// - 10-second conversation window (context expires)
/// - Yes/No response handling during active conversation
/// - States: idle → awaitingFollowUp → guiding
class ConversationFlowService extends ChangeNotifier {
  ConversationState _state = ConversationState.idle;
  ConversationType? _activeType;
  String? _contextData;  // e.g., object name, direction
  Timer? _expirationTimer;
  
  // Callbacks
  VoidCallback? onStartGuiding;         // Start navigation guidance
  Function(String)? onFollowUpSpeak;    // Speak follow-up message
  VoidCallback? onConversationExpired;  // Conversation timed out
  
  // Conversation timeout
  static const Duration _conversationTimeout = Duration(seconds: 10);
  
  ConversationState get state => _state;
  ConversationType? get activeType => _activeType;
  bool get isActive => _state != ConversationState.idle;
  
  /// Start a conversational follow-up after a command result
  void startFollowUp({
    required ConversationType type,
    required String message,
    String? contextData,
  }) {
    _state = ConversationState.awaitingFollowUp;
    _activeType = type;
    _contextData = contextData;
    
    // Speak the follow-up message
    onFollowUpSpeak?.call(message);
    
    // Start expiration timer
    _resetExpirationTimer();
    
    debugPrint('[Conversation] Follow-up started: $type, context: $contextData');
    notifyListeners();
  }
  
  /// Handle yes/no response during active conversation
  /// Returns true if the response was consumed by the conversation
  bool handleResponse(bool isPositive) {
    if (_state != ConversationState.awaitingFollowUp) return false;
    
    _expirationTimer?.cancel();
    
    if (isPositive) {
      _handlePositiveResponse();
    } else {
      _handleNegativeResponse();
    }
    
    return true;
  }
  
  void _handlePositiveResponse() {
    switch (_activeType) {
      case ConversationType.findObject:
        // User wants guidance to the found object
        _state = ConversationState.guiding;
        onFollowUpSpeak?.call('Guiding you to $_contextData now. Walk forward slowly.');
        onStartGuiding?.call();
        // End conversation after guidance starts
        _resetExpirationTimer();
        break;
        
      case ConversationType.describeScene:
        // User wants to find something specific
        onFollowUpSpeak?.call('What would you like me to find?');
        // Keep conversation active for the next command
        _resetExpirationTimer();
        break;
        
      case ConversationType.navigateExit:
        // User wants to start navigation
        _state = ConversationState.guiding;
        onFollowUpSpeak?.call('Starting navigation. I\'ll guide you step by step.');
        onStartGuiding?.call();
        _resetExpirationTimer();
        break;
        
      default:
        _endConversation();
    }
    
    notifyListeners();
  }
  
  void _handleNegativeResponse() {
    onFollowUpSpeak?.call('Okay, let me know if you need anything.');
    _endConversation();
  }
  
  /// Generate follow-up for "find object" command results
  String buildFindObjectFollowUp({
    required String objectName,
    required String distance,
    required String direction,
  }) {
    return '$objectName found $direction, $distance. Should I guide you there?';
  }
  
  /// Generate follow-up for "describe scene" command results
  String buildDescribeSceneFollowUp(int objectCount) {
    if (objectCount == 0) {
      return 'The area appears clear. Want me to scan again?';
    }
    return 'I see $objectCount objects around you. Want me to find something specific?';
  }
  
  /// Generate follow-up for "navigate to exit"
  String buildNavigateExitFollowUp({
    required bool exitFound,
    String? direction,
    String? distance,
  }) {
    if (exitFound) {
      return 'Exit found $direction, $distance. Want me to guide you?';
    }
    return 'No exit visible right now. Should I keep looking?';
  }
  
  /// Check if current input matches yes/no during conversation
  /// Returns: 'yes', 'no', or null if not a yes/no
  String? parseYesNo(String words) {
    final lower = words.toLowerCase().trim();
    
    // Positive responses
    if (lower.contains('yes') ||
        lower.contains('yeah') ||
        lower.contains('sure') ||
        lower.contains('okay') ||
        lower.contains('please') ||
        lower.contains('guide me') ||
        lower.contains('go ahead') ||
        lower == 'ok' ||
        // Hindi positive
        lower.contains('हाँ') ||
        lower.contains('हां') ||
        lower.contains('ठीक')) {
      return 'yes';
    }
    
    // Negative responses
    if (lower.contains('no') ||
        lower.contains('nah') ||
        lower.contains('cancel') ||
        lower.contains('never mind') ||
        lower.contains('forget it') ||
        lower.contains('stop') ||
        // Hindi negative
        lower.contains('नहीं') ||
        lower.contains('रहने दो')) {
      return 'no';
    }
    
    return null;
  }
  
  void _resetExpirationTimer() {
    _expirationTimer?.cancel();
    _expirationTimer = Timer(_conversationTimeout, () {
      debugPrint('[Conversation] Conversation expired');
      onConversationExpired?.call();
      _endConversation();
    });
  }
  
  void _endConversation() {
    _state = ConversationState.idle;
    _activeType = null;
    _contextData = null;
    _expirationTimer?.cancel();
    notifyListeners();
  }
  
  /// Force end the conversation
  void cancel() {
    _endConversation();
  }
  
  @override
  void dispose() {
    _expirationTimer?.cancel();
    super.dispose();
  }
}

/// Conversation state
enum ConversationState {
  idle,              // No active conversation
  awaitingFollowUp,  // Waiting for yes/no response
  guiding,           // Actively guiding user
}

/// Type of conversation
enum ConversationType {
  findObject,       // Found object, offer guidance
  describeScene,    // Scene described, offer to find specific
  navigateExit,     // Exit found, offer navigation
}
