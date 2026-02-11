import 'package:flutter/foundation.dart';
import 'package:audioplayers/audioplayers.dart';

import '../models/detection.dart';

/// Earcon service for short audio cues (Week 2)
/// 
/// Provides distinct sounds for:
/// - Path clear: soft ascending chime
/// - Danger close: sharp beep
/// - Object found: single ping
/// 
/// Supports spatial audio via stereo panning (balance)
class EarconService extends ChangeNotifier {
  final AudioPlayer _playerClear = AudioPlayer();
  final AudioPlayer _playerDanger = AudioPlayer();
  final AudioPlayer _playerPing = AudioPlayer();
  
  bool _isInitialized = false;
  bool _enabled = true;
  
  bool get isInitialized => _isInitialized;
  bool get isEnabled => _enabled;
  
  /// Initialize the earcon service
  Future<void> initialize() async {
    if (_isInitialized) return;
    
    try {
      // Set low latency mode for all players
      await _playerClear.setReleaseMode(ReleaseMode.stop);
      await _playerDanger.setReleaseMode(ReleaseMode.stop);
      await _playerPing.setReleaseMode(ReleaseMode.stop);
      
      _isInitialized = true;
      debugPrint('[Earcon] Initialized');
      notifyListeners();
    } catch (e) {
      debugPrint('[Earcon] Init error: $e');
    }
  }
  
  void setEnabled(bool enabled) {
    _enabled = enabled;
    notifyListeners();
  }
  
  /// Play path clear chime (soft, positive)
  Future<void> playPathClear({RelativePosition? position}) async {
    if (!_enabled || !_isInitialized) return;
    
    try {
      await _playerClear.stop();
      _setBalance(_playerClear, position);
      await _playerClear.setVolume(0.5);
      await _playerClear.play(AssetSource('sounds/path_clear.mp3'));
    } catch (e) {
      debugPrint('[Earcon] Path clear error: $e');
    }
  }
  
  /// Play danger close beep (sharp, urgent)
  Future<void> playDangerClose({RelativePosition? position}) async {
    if (!_enabled || !_isInitialized) return;
    
    try {
      await _playerDanger.stop();
      _setBalance(_playerDanger, position);
      await _playerDanger.setVolume(0.9);
      await _playerDanger.play(AssetSource('sounds/danger_close.mp3'));
    } catch (e) {
      debugPrint('[Earcon] Danger close error: $e');
    }
  }
  
  /// Play object found ping (neutral, informative)
  Future<void> playObjectFound({RelativePosition? position}) async {
    if (!_enabled || !_isInitialized) return;
    
    try {
      await _playerPing.stop();
      _setBalance(_playerPing, position);
      await _playerPing.setVolume(0.6);
      await _playerPing.play(AssetSource('sounds/object_found.mp3'));
    } catch (e) {
      debugPrint('[Earcon] Object found error: $e');
    }
  }
  
  /// Play spatial earcon based on detection danger and position
  Future<void> playForDetection(Detection detection) async {
    final position = detection.relativePosition;
    
    switch (detection.dangerLevel) {
      case DangerLevel.critical:
      case DangerLevel.high:
        await playDangerClose(position: position);
        break;
      case DangerLevel.medium:
        await playObjectFound(position: position);
        break;
      default:
        await playObjectFound(position: position);
        break;
    }
  }
  
  /// Week 2 Spatial Audio: Set stereo balance based on object position
  void _setBalance(AudioPlayer player, RelativePosition? position) {
    if (position == null) {
      player.setBalance(0.0);
      return;
    }
    
    switch (position) {
      case RelativePosition.left:
        player.setBalance(-0.8); // Louder on left ear
        break;
      case RelativePosition.center:
        player.setBalance(0.0); // Centered
        break;
      case RelativePosition.right:
        player.setBalance(0.8); // Louder on right ear
        break;
    }
  }
  
  @override
  void dispose() {
    _playerClear.dispose();
    _playerDanger.dispose();
    _playerPing.dispose();
    super.dispose();
  }
}
