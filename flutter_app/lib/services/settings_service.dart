import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Settings service for persistent user preferences
/// 
/// Features:
/// - Speech rate (0.1-1.0)
/// - Speech volume (0.0-1.0)
/// - Navigation mode (indoor/outdoor)
/// - High contrast mode
/// - Path clear interval
/// - Emergency contact
class SettingsService extends ChangeNotifier {
  static const String _keySpeechRate = 'speech_rate';
  static const String _keySpeechVolume = 'speech_volume';
  static const String _keyNavigationMode = 'navigation_mode';
  static const String _keyHighContrast = 'high_contrast';
  static const String _keyPathClearInterval = 'path_clear_interval';
  static const String _keyEmergencyContact = 'emergency_contact';
  static const String _keyVibrationEnabled = 'vibration_enabled';
  static const String _keyVoiceCommandsEnabled = 'voice_commands_enabled';

  SharedPreferences? _prefs;
  bool _isInitialized = false;

  // Default values
  double _speechRate = 0.5;
  double _speechVolume = 1.0;
  AppNavigationMode _navigationMode = AppNavigationMode.indoor;
  bool _highContrast = false;
  int _pathClearInterval = 5; // seconds
  String _emergencyContact = '';
  bool _vibrationEnabled = true;
  bool _voiceCommandsEnabled = false;

  // Getters
  bool get isInitialized => _isInitialized;
  double get speechRate => _speechRate;
  double get speechVolume => _speechVolume;
  AppNavigationMode get navigationMode => _navigationMode;
  bool get highContrast => _highContrast;
  int get pathClearInterval => _pathClearInterval;
  String get emergencyContact => _emergencyContact;
  bool get vibrationEnabled => _vibrationEnabled;
  bool get voiceCommandsEnabled => _voiceCommandsEnabled;

  /// Initialize and load saved preferences
  Future<void> initialize() async {
    if (_isInitialized) return;
    
    try {
      _prefs = await SharedPreferences.getInstance();
      
      _speechRate = _prefs!.getDouble(_keySpeechRate) ?? 0.5;
      _speechVolume = _prefs!.getDouble(_keySpeechVolume) ?? 1.0;
      _navigationMode = AppNavigationMode.values[_prefs!.getInt(_keyNavigationMode) ?? 0];
      _highContrast = _prefs!.getBool(_keyHighContrast) ?? false;
      _pathClearInterval = _prefs!.getInt(_keyPathClearInterval) ?? 5;
      _emergencyContact = _prefs!.getString(_keyEmergencyContact) ?? '';
      _vibrationEnabled = _prefs!.getBool(_keyVibrationEnabled) ?? true;
      _voiceCommandsEnabled = _prefs!.getBool(_keyVoiceCommandsEnabled) ?? false;
      
      _isInitialized = true;
      debugPrint('Settings: Loaded successfully');
      notifyListeners();
    } catch (e) {
      debugPrint('Settings: Error loading: $e');
    }
  }

  /// Set speech rate (0.1-1.0)
  Future<void> setSpeechRate(double rate) async {
    _speechRate = rate.clamp(0.1, 1.0);
    await _prefs?.setDouble(_keySpeechRate, _speechRate);
    notifyListeners();
  }

  /// Set speech volume (0.0-1.0)
  Future<void> setSpeechVolume(double volume) async {
    _speechVolume = volume.clamp(0.0, 1.0);
    await _prefs?.setDouble(_keySpeechVolume, _speechVolume);
    notifyListeners();
  }

  /// Set navigation mode
  Future<void> setNavigationMode(AppNavigationMode mode) async {
    _navigationMode = mode;
    await _prefs?.setInt(_keyNavigationMode, mode.index);
    notifyListeners();
  }

  /// Set high contrast mode
  Future<void> setHighContrast(bool enabled) async {
    _highContrast = enabled;
    await _prefs?.setBool(_keyHighContrast, enabled);
    notifyListeners();
  }

  /// Set path clear announcement interval (seconds)
  Future<void> setPathClearInterval(int seconds) async {
    _pathClearInterval = seconds.clamp(3, 30);
    await _prefs?.setInt(_keyPathClearInterval, _pathClearInterval);
    notifyListeners();
  }

  /// Set emergency contact number
  Future<void> setEmergencyContact(String contact) async {
    _emergencyContact = contact;
    await _prefs?.setString(_keyEmergencyContact, contact);
    notifyListeners();
  }

  /// Set vibration enabled
  Future<void> setVibrationEnabled(bool enabled) async {
    _vibrationEnabled = enabled;
    await _prefs?.setBool(_keyVibrationEnabled, enabled);
    notifyListeners();
  }

  /// Set voice commands enabled
  Future<void> setVoiceCommandsEnabled(bool enabled) async {
    _voiceCommandsEnabled = enabled;
    await _prefs?.setBool(_keyVoiceCommandsEnabled, enabled);
    notifyListeners();
  }

  /// Reset all settings to defaults
  Future<void> resetToDefaults() async {
    await setSpeechRate(0.5);
    await setSpeechVolume(1.0);
    await setNavigationMode(AppNavigationMode.indoor);
    await setHighContrast(false);
    await setPathClearInterval(5);
    await setVibrationEnabled(true);
    await setVoiceCommandsEnabled(false);
  }
}

/// Navigation mode for filtering detections
enum AppNavigationMode {
  indoor,
  outdoor;

  String get displayName {
    switch (this) {
      case AppNavigationMode.indoor:
        return 'Indoor';
      case AppNavigationMode.outdoor:
        return 'Outdoor';
    }
  }

  /// Get priority classes for this mode
  List<String> get priorityClasses {
    switch (this) {
      case AppNavigationMode.indoor:
        return [
          'person', 'chair', 'couch', 'dining table', 'bed', 
          'door', 'tv', 'laptop', 'potted plant', 'bottle',
          'cup', 'book', 'clock', 'vase'
        ];
      case AppNavigationMode.outdoor:
        return [
          'person', 'car', 'motorcycle', 'bicycle', 'bus', 
          'truck', 'traffic light', 'stop sign', 'fire hydrant',
          'dog', 'cat', 'bench'
        ];
    }
  }

  /// Check if class is relevant for this mode
  bool isRelevant(String className) {
    return priorityClasses.contains(className.toLowerCase());
  }
}
