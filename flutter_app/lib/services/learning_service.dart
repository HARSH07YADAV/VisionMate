import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Reinforcement Learning Service
/// 
/// Implements on-device Q-Learning for announcement optimization.
/// The agent learns when to announce, how urgently, based on:
/// - Object type, distance, user movement
/// - Recent announcement history
/// - Time of day
/// 
/// Rewards come from user feedback:
/// - Positive: "thanks", "helpful", successful navigation
/// - Negative: "stop", "too much", near-collisions
class LearningService extends ChangeNotifier {
  static const String _keyQTable = 'q_table';
  static const String _keyEpsilon = 'epsilon';
  static const String _keyTotalInteractions = 'total_interactions';
  static const String _keyObjectPreferences = 'object_preferences';
  
  SharedPreferences? _prefs;
  final Random _random = Random();
  
  // Q-Learning parameters
  double _alpha = 0.1;      // Learning rate
  double _gamma = 0.9;      // Discount factor
  double _epsilon = 0.3;    // Exploration rate (decreases over time)
  double _minEpsilon = 0.05;
  
  // Q-Table: state -> action -> value
  // State: encoded as integer, Action: 0=skip, 1=calm, 2=urgent
  Map<int, List<double>> _qTable = {};
  
  // Object preference learning
  Map<String, double> _objectPreferences = {};
  
  // Session tracking
  int _totalInteractions = 0;
  int _sessionAnnouncements = 0;
  DateTime? _lastAnnouncementTime;
  List<int> _recentStates = [];
  
  bool _isInitialized = false;
  
  // Getters
  bool get isInitialized => _isInitialized;
  double get epsilon => _epsilon;
  int get totalInteractions => _totalInteractions;
  Map<String, double> get objectPreferences => Map.unmodifiable(_objectPreferences);
  
  /// Initialize and load persisted Q-table
  Future<void> initialize() async {
    if (_isInitialized) return;
    
    try {
      _prefs = await SharedPreferences.getInstance();
      
      // Load Q-table
      final qTableJson = _prefs!.getString(_keyQTable);
      if (qTableJson != null) {
        final Map<String, dynamic> decoded = jsonDecode(qTableJson);
        _qTable = decoded.map((key, value) => MapEntry(
          int.parse(key),
          (value as List).cast<double>(),
        ));
      }
      
      // Load epsilon (exploration rate decreases over time)
      _epsilon = _prefs!.getDouble(_keyEpsilon) ?? 0.3;
      _totalInteractions = _prefs!.getInt(_keyTotalInteractions) ?? 0;
      
      // Load object preferences
      final prefsJson = _prefs!.getString(_keyObjectPreferences);
      if (prefsJson != null) {
        _objectPreferences = Map<String, double>.from(jsonDecode(prefsJson));
      }
      
      _isInitialized = true;
      debugPrint('[Learning] Initialized - ${_qTable.length} states, ε=$_epsilon');
      notifyListeners();
    } catch (e) {
      debugPrint('[Learning] Init error: $e');
      _isInitialized = false;
    }
  }
  
  /// Encode current situation into a state integer
  int encodeState({
    required String objectType,
    required double distance,
    required bool isWalking,
    required int recentAnnouncementCount,
    required bool isNight,
  }) {
    // Object category (0-9)
    final objCategory = _getObjectCategory(objectType);
    
    // Distance bucket (0=far >3m, 1=medium 1-3m, 2=close <1m)
    final distBucket = distance > 3.0 ? 0 : (distance > 1.0 ? 1 : 2);
    
    // Movement (0=stationary, 1=walking)
    final movement = isWalking ? 1 : 0;
    
    // Recent announcements (0=none, 1=some 1-3, 2=many >3)
    final recentBucket = recentAnnouncementCount == 0 ? 0 : 
                         (recentAnnouncementCount <= 3 ? 1 : 2);
    
    // Time (0=day, 1=night)
    final time = isNight ? 1 : 0;
    
    // Encode: objCategory * 1000 + distBucket * 100 + movement * 10 + recentBucket * 2 + time
    return objCategory * 1000 + distBucket * 100 + movement * 10 + recentBucket * 2 + time;
  }
  
  /// Get object category (0-9)
  int _getObjectCategory(String objectType) {
    final obj = objectType.toLowerCase();
    
    // Danger: vehicles
    if (['car', 'motorcycle', 'bicycle', 'bus', 'truck'].contains(obj)) return 0;
    
    // Danger: stairs/hazards
    if (['stairs', 'curb', 'hole', 'step'].contains(obj)) return 1;
    
    // People
    if (obj == 'person') return 2;
    
    // Large obstacles
    if (['chair', 'couch', 'bed', 'dining table'].contains(obj)) return 3;
    
    // Doors/navigation
    if (['door', 'gate', 'entrance'].contains(obj)) return 4;
    
    // Small objects
    if (['bottle', 'cup', 'book', 'laptop', 'phone'].contains(obj)) return 5;
    
    // Animals
    if (['dog', 'cat', 'bird'].contains(obj)) return 6;
    
    // Traffic
    if (['traffic light', 'stop sign', 'fire hydrant'].contains(obj)) return 7;
    
    // Plants
    if (['potted plant', 'tree'].contains(obj)) return 8;
    
    // Other
    return 9;
  }
  
  /// Select action using epsilon-greedy policy
  /// Returns: 0=skip, 1=announce calm, 2=announce urgent
  int selectAction(int state) {
    // Initialize state if not exists
    if (!_qTable.containsKey(state)) {
      // Default Q-values: slightly prefer announcing for safety
      _qTable[state] = [0.0, 0.5, 0.3]; // [skip, calm, urgent]
    }
    
    // Epsilon-greedy: explore with probability epsilon
    if (_random.nextDouble() < _epsilon) {
      // Exploration: random action
      return _random.nextInt(3);
    }
    
    // Exploitation: choose best action
    final qValues = _qTable[state]!;
    return _argmax(qValues);
  }
  
  /// Get recommended action with object preference adjustment
  LearningDecision getDecision({
    required String objectType,
    required double distance,
    required bool isWalking,
    required bool isNight,
  }) {
    // Count recent announcements
    final recentCount = _sessionAnnouncements;
    
    // Encode state
    final state = encodeState(
      objectType: objectType,
      distance: distance,
      isWalking: isWalking,
      recentAnnouncementCount: recentCount,
      isNight: isNight,
    );
    
    // Store state for learning
    _recentStates.add(state);
    if (_recentStates.length > 10) _recentStates.removeAt(0);
    
    // Get action from Q-learning
    final action = selectAction(state);
    
    // Adjust based on learned object preferences
    final objPref = _objectPreferences[objectType.toLowerCase()] ?? 0.5;
    
    // If user dislikes this object type, prefer skipping
    int adjustedAction = action;
    if (objPref < 0.3 && action == 1) {
      adjustedAction = 0; // Skip
    } else if (objPref > 0.7 && action == 0 && distance < 2.0) {
      adjustedAction = 1; // Force announce for important objects
    }
    
    return LearningDecision(
      action: adjustedAction,
      state: state,
      confidence: _getConfidence(state, adjustedAction),
    );
  }
  
  /// Get confidence level (0-1) for a decision
  double _getConfidence(int state, int action) {
    if (!_qTable.containsKey(state)) return 0.5;
    
    final qValues = _qTable[state]!;
    final maxQ = qValues.reduce(max);
    final actionQ = qValues[action];
    
    // Higher confidence if this action has much higher Q than others
    if (maxQ == 0) return 0.5;
    return (actionQ / maxQ).clamp(0.0, 1.0);
  }
  
  /// Record that an announcement was made
  void recordAnnouncement() {
    _sessionAnnouncements++;
    _lastAnnouncementTime = DateTime.now();
  }
  
  /// Provide reward feedback for learning
  /// Called when user gives feedback (thanks, stop, etc.)
  Future<void> provideFeedback(FeedbackType feedback, {String? objectType}) async {
    if (_recentStates.isEmpty) return;
    
    // Determine reward
    final reward = switch (feedback) {
      FeedbackType.positive => 1.0,      // "thanks", "helpful"
      FeedbackType.negative => -1.0,     // "stop", "too much"
      FeedbackType.neutral => 0.1,       // No complaint
      FeedbackType.collision => -2.0,    // Near collision
    };
    
    // Update Q-values for recent states
    for (int i = 0; i < _recentStates.length; i++) {
      final state = _recentStates[i];
      final decay = 1.0 - (i * 0.1); // More recent = more credit
      _updateQValue(state, reward * decay);
    }
    
    // Update object preferences
    if (objectType != null) {
      _updateObjectPreference(objectType, feedback);
    }
    
    // Decay epsilon (explore less over time)
    _totalInteractions++;
    if (_totalInteractions % 10 == 0) {
      _epsilon = max(_minEpsilon, _epsilon * 0.95);
    }
    
    // Persist
    await _saveState();
    
    debugPrint('[Learning] Feedback: $feedback, reward=$reward, ε=$_epsilon');
    notifyListeners();
  }
  
  /// Update Q-value for a state
  void _updateQValue(int state, double reward) {
    if (!_qTable.containsKey(state)) return;
    
    final qValues = _qTable[state]!;
    final bestAction = _argmax(qValues);
    
    // Q-learning update: Q(s,a) = Q(s,a) + α * (reward - Q(s,a))
    // Simplified since we don't have next state
    qValues[bestAction] = qValues[bestAction] + _alpha * (reward - qValues[bestAction]);
  }
  
  /// Update learned preference for an object type
  void _updateObjectPreference(String objectType, FeedbackType feedback) {
    final obj = objectType.toLowerCase();
    final current = _objectPreferences[obj] ?? 0.5;
    
    final adjustment = switch (feedback) {
      FeedbackType.positive => 0.1,   // User wants more announcements
      FeedbackType.negative => -0.1,  // User wants fewer
      FeedbackType.neutral => 0.0,
      FeedbackType.collision => 0.2,  // Definitely want warnings for this
    };
    
    _objectPreferences[obj] = (current + adjustment).clamp(0.0, 1.0);
  }
  
  /// Get argmax of a list
  int _argmax(List<double> values) {
    double maxVal = values[0];
    int maxIdx = 0;
    for (int i = 1; i < values.length; i++) {
      if (values[i] > maxVal) {
        maxVal = values[i];
        maxIdx = i;
      }
    }
    return maxIdx;
  }
  
  /// Save Q-table and preferences to storage
  Future<void> _saveState() async {
    if (_prefs == null) return;
    
    try {
      // Save Q-table
      final qTableJson = jsonEncode(
        _qTable.map((key, value) => MapEntry(key.toString(), value)),
      );
      await _prefs!.setString(_keyQTable, qTableJson);
      
      // Save epsilon and interactions
      await _prefs!.setDouble(_keyEpsilon, _epsilon);
      await _prefs!.setInt(_keyTotalInteractions, _totalInteractions);
      
      // Save object preferences
      await _prefs!.setString(_keyObjectPreferences, jsonEncode(_objectPreferences));
    } catch (e) {
      debugPrint('[Learning] Save error: $e');
    }
  }
  
  /// Reset learning (for testing)
  Future<void> resetLearning() async {
    _qTable.clear();
    _objectPreferences.clear();
    _epsilon = 0.3;
    _totalInteractions = 0;
    _sessionAnnouncements = 0;
    _recentStates.clear();
    await _saveState();
    notifyListeners();
  }
  
  /// Get learning statistics
  Map<String, dynamic> getStats() {
    return {
      'totalInteractions': _totalInteractions,
      'statesLearned': _qTable.length,
      'explorationRate': _epsilon,
      'objectPreferences': _objectPreferences,
    };
  }
  
  /// Reset session counters (call at app start)
  void startSession() {
    _sessionAnnouncements = 0;
    _recentStates.clear();
    _lastAnnouncementTime = null;
  }
}

/// Decision from the learning agent
class LearningDecision {
  final int action;       // 0=skip, 1=calm, 2=urgent
  final int state;        // Encoded state
  final double confidence; // 0-1 confidence level
  
  LearningDecision({
    required this.action,
    required this.state,
    required this.confidence,
  });
  
  bool get shouldAnnounce => action > 0;
  bool get isUrgent => action == 2;
}

/// Types of user feedback
enum FeedbackType {
  positive,   // "thanks", "helpful", "good"
  negative,   // "stop", "too much", "quiet"
  neutral,    // No explicit feedback
  collision,  // Near collision detected
}
