import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Feedback Service for collecting user preferences
/// 
/// Collects both implicit and explicit feedback:
/// - Implicit: voice commands like "stop", "louder", "too much"
/// - Explicit: "Was that helpful?" prompts (occasional)
/// 
/// Uses this feedback to improve the learning model and
/// personalize the user experience.
class FeedbackService extends ChangeNotifier {
  static const String _keyFeedbackHistory = 'feedback_history';
  static const String _keyPromptCount = 'prompt_count';
  static const String _keyLastPromptTime = 'last_prompt_time';
  static const String _keyPreferenceScores = 'preference_scores';
  
  SharedPreferences? _prefs;
  bool _isInitialized = false;
  
  // Feedback history (recent 100 entries)
  List<FeedbackEntry> _feedbackHistory = [];
  
  // Preference scores (0-1 scale)
  Map<String, double> _preferenceScores = {
    'announcement_frequency': 0.5,  // 0=few, 1=many
    'speech_speed': 0.5,            // 0=slow, 1=fast
    'urgency_level': 0.5,           // 0=calm, 1=urgent
    'detail_level': 0.5,            // 0=brief, 1=detailed
  };
  
  // Prompt tracking
  int _promptCount = 0;
  DateTime? _lastPromptTime;
  int _sessionFeedbackCount = 0;
  
  // Callbacks
  Function(bool)? onFeedbackReceived;
  
  bool get isInitialized => _isInitialized;
  Map<String, double> get preferenceScores => Map.unmodifiable(_preferenceScores);
  int get totalFeedbackCount => _feedbackHistory.length;
  
  /// Initialize and load persisted data
  Future<void> initialize() async {
    if (_isInitialized) return;
    
    try {
      _prefs = await SharedPreferences.getInstance();
      
      // Load feedback history
      final historyJson = _prefs!.getString(_keyFeedbackHistory);
      if (historyJson != null) {
        final List<dynamic> decoded = jsonDecode(historyJson);
        _feedbackHistory = decoded.map((e) => FeedbackEntry.fromJson(e)).toList();
      }
      
      // Load preference scores
      final scoresJson = _prefs!.getString(_keyPreferenceScores);
      if (scoresJson != null) {
        _preferenceScores = Map<String, double>.from(jsonDecode(scoresJson));
      }
      
      // Load prompt tracking
      _promptCount = _prefs!.getInt(_keyPromptCount) ?? 0;
      final lastStr = _prefs!.getString(_keyLastPromptTime);
      if (lastStr != null) {
        _lastPromptTime = DateTime.tryParse(lastStr);
      }
      
      _isInitialized = true;
      debugPrint('[Feedback] Initialized - ${_feedbackHistory.length} entries');
      notifyListeners();
    } catch (e) {
      debugPrint('[Feedback] Init error: $e');
    }
  }
  
  /// Record implicit feedback from voice commands
  void recordImplicitFeedback(ImplicitFeedback type, {String? context}) {
    final entry = FeedbackEntry(
      timestamp: DateTime.now(),
      type: type.name,
      isExplicit: false,
      context: context,
    );
    
    _addFeedbackEntry(entry);
    _updatePreferencesFromImplicit(type);
    _sessionFeedbackCount++;
    
    onFeedbackReceived?.call(type == ImplicitFeedback.positive);
    
    debugPrint('[Feedback] Implicit: ${type.name}');
  }
  
  /// Record explicit feedback from user prompt
  void recordExplicitFeedback(bool wasHelpful, {String? context}) {
    final entry = FeedbackEntry(
      timestamp: DateTime.now(),
      type: wasHelpful ? 'helpful' : 'not_helpful',
      isExplicit: true,
      context: context,
    );
    
    _addFeedbackEntry(entry);
    _updatePreferencesFromExplicit(wasHelpful);
    _promptCount++;
    _lastPromptTime = DateTime.now();
    _sessionFeedbackCount++;
    
    _saveState();
    onFeedbackReceived?.call(wasHelpful);
    
    debugPrint('[Feedback] Explicit: helpful=$wasHelpful');
  }
  
  /// Check if we should ask for explicit feedback
  bool shouldPromptForFeedback() {
    // Don't prompt too often
    if (_lastPromptTime != null) {
      final timeSince = DateTime.now().difference(_lastPromptTime!);
      if (timeSince.inMinutes < 5) return false;
    }
    
    // Don't prompt more than 3 times per session
    if (_sessionFeedbackCount >= 3) return false;
    
    // Prompt roughly every 10 announcements
    return _sessionFeedbackCount % 10 == 9;
  }
  
  /// Get feedback prompt text
  String getFeedbackPrompt() {
    return "Was that announcement helpful?";
  }
  
  /// Update preferences based on implicit feedback
  void _updatePreferencesFromImplicit(ImplicitFeedback type) {
    switch (type) {
      case ImplicitFeedback.tooMuch:
        _adjustPreference('announcement_frequency', -0.1);
        break;
      case ImplicitFeedback.tooLoud:
        _adjustPreference('urgency_level', -0.1);
        break;
      case ImplicitFeedback.tooQuiet:
        _adjustPreference('urgency_level', 0.1);
        break;
      case ImplicitFeedback.tooFast:
        _adjustPreference('speech_speed', -0.1);
        break;
      case ImplicitFeedback.tooSlow:
        _adjustPreference('speech_speed', 0.1);
        break;
      case ImplicitFeedback.positive:
        // Reinforce current settings
        break;
      case ImplicitFeedback.stop:
        _adjustPreference('announcement_frequency', -0.2);
        break;
    }
  }
  
  /// Update preferences based on explicit feedback
  void _updatePreferencesFromExplicit(bool wasHelpful) {
    if (wasHelpful) {
      // Slightly reinforce current settings
      // (no change, just record positive)
    } else {
      // User didn't find it helpful - reduce frequency
      _adjustPreference('announcement_frequency', -0.05);
    }
  }
  
  /// Adjust a preference score
  void _adjustPreference(String key, double delta) {
    if (!_preferenceScores.containsKey(key)) return;
    _preferenceScores[key] = (_preferenceScores[key]! + delta).clamp(0.0, 1.0);
    _saveState();
    notifyListeners();
  }
  
  /// Add entry to feedback history
  void _addFeedbackEntry(FeedbackEntry entry) {
    _feedbackHistory.add(entry);
    
    // Keep only last 100 entries
    if (_feedbackHistory.length > 100) {
      _feedbackHistory.removeAt(0);
    }
  }
  
  /// Save state to persistence
  Future<void> _saveState() async {
    if (_prefs == null) return;
    
    try {
      // Save feedback history
      final historyJson = jsonEncode(
        _feedbackHistory.map((e) => e.toJson()).toList(),
      );
      await _prefs!.setString(_keyFeedbackHistory, historyJson);
      
      // Save preference scores
      await _prefs!.setString(_keyPreferenceScores, jsonEncode(_preferenceScores));
      
      // Save prompt tracking
      await _prefs!.setInt(_keyPromptCount, _promptCount);
      if (_lastPromptTime != null) {
        await _prefs!.setString(_keyLastPromptTime, _lastPromptTime!.toIso8601String());
      }
    } catch (e) {
      debugPrint('[Feedback] Save error: $e');
    }
  }
  
  /// Get summary of learned preferences
  Map<String, String> getPreferenceSummary() {
    return {
      'Announcement Frequency': _describePreference(_preferenceScores['announcement_frequency']!, ['Few', 'Normal', 'Many']),
      'Speech Speed': _describePreference(_preferenceScores['speech_speed']!, ['Slow', 'Normal', 'Fast']),
      'Urgency Level': _describePreference(_preferenceScores['urgency_level']!, ['Calm', 'Normal', 'Urgent']),
      'Detail Level': _describePreference(_preferenceScores['detail_level']!, ['Brief', 'Normal', 'Detailed']),
    };
  }
  
  String _describePreference(double value, List<String> labels) {
    if (value < 0.33) return labels[0];
    if (value < 0.67) return labels[1];
    return labels[2];
  }
  
  /// Get recommended settings based on learned preferences
  RecommendedSettings getRecommendedSettings() {
    return RecommendedSettings(
      speechRate: 0.3 + (_preferenceScores['speech_speed']! * 0.4),
      announcementFrequency: _preferenceScores['announcement_frequency']!,
      detailLevel: _preferenceScores['detail_level']!,
    );
  }
  
  /// Reset all feedback data
  Future<void> resetFeedback() async {
    _feedbackHistory.clear();
    _preferenceScores = {
      'announcement_frequency': 0.5,
      'speech_speed': 0.5,
      'urgency_level': 0.5,
      'detail_level': 0.5,
    };
    _promptCount = 0;
    _lastPromptTime = null;
    _sessionFeedbackCount = 0;
    await _saveState();
    notifyListeners();
  }
  
  /// Reset session counters
  void startSession() {
    _sessionFeedbackCount = 0;
  }
}

/// Entry in feedback history
class FeedbackEntry {
  final DateTime timestamp;
  final String type;
  final bool isExplicit;
  final String? context;
  
  FeedbackEntry({
    required this.timestamp,
    required this.type,
    required this.isExplicit,
    this.context,
  });
  
  Map<String, dynamic> toJson() => {
    'timestamp': timestamp.toIso8601String(),
    'type': type,
    'isExplicit': isExplicit,
    'context': context,
  };
  
  factory FeedbackEntry.fromJson(Map<String, dynamic> json) => FeedbackEntry(
    timestamp: DateTime.parse(json['timestamp']),
    type: json['type'],
    isExplicit: json['isExplicit'],
    context: json['context'],
  );
}

/// Types of implicit feedback
enum ImplicitFeedback {
  positive,   // "thanks", "good", "helpful"
  tooMuch,    // "too much", "enough"
  tooLoud,    // "too loud", "quieter"
  tooQuiet,   // "louder", "can't hear"
  tooFast,    // "slower", "too fast"
  tooSlow,    // "faster", "speed up"
  stop,       // "stop", "be quiet"
}

/// Recommended settings based on learned preferences
class RecommendedSettings {
  final double speechRate;           // 0.3-0.7
  final double announcementFrequency; // 0-1
  final double detailLevel;          // 0-1
  
  RecommendedSettings({
    required this.speechRate,
    required this.announcementFrequency,
    required this.detailLevel,
  });
}
