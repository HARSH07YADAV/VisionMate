import 'package:flutter/foundation.dart';
import '../models/detection.dart';

/// Navigation guidance service
/// Analyzes obstacle positions and recommends which direction to move
class NavigationGuidanceService extends ChangeNotifier {
  String _lastGuidance = '';
  DateTime _lastGuidanceTime = DateTime.now();
  static const Duration _guidanceCooldown = Duration(seconds: 2);

  String get lastGuidance => _lastGuidance;

  /// Analyze detections and return navigation guidance
  /// 
  /// Returns guidance like:
  /// - "Move left" - obstacles on right side
  /// - "Move right" - obstacles on left side  
  /// - "Move back" - obstacles in center/both sides
  /// - "Path clear" - no obstacles ahead
  NavigationGuidance analyzeAndGuide(
    List<Detection> detections, {
    required int frameWidth,
    required int frameHeight,
  }) {
    if (detections.isEmpty) {
      return NavigationGuidance(
        direction: GuidanceDirection.forward,
        message: 'Path is clear, continue forward',
        urgency: GuidanceUrgency.low,
      );
    }

    // Divide frame into 3 vertical zones: left, center, right
    final leftThird = frameWidth / 3;
    final rightThird = frameWidth * 2 / 3;

    // Track which zones have obstacles and their severity
    double leftZoneRisk = 0;
    double centerZoneRisk = 0;
    double rightZoneRisk = 0;

    for (final detection in detections) {
      final box = detection.boundingBox;
      final centerX = box.centerX;
      final riskScore = _calculateRisk(detection, frameHeight);

      // Determine which zone(s) the detection covers
      if (centerX < leftThird) {
        leftZoneRisk += riskScore;
      } else if (centerX > rightThird) {
        rightZoneRisk += riskScore;
      } else {
        centerZoneRisk += riskScore;
      }

      // Large objects may span multiple zones
      if (box.left < leftThird && box.right > leftThird) {
        centerZoneRisk += riskScore * 0.5;
      }
      if (box.left < rightThird && box.right > rightThird) {
        centerZoneRisk += riskScore * 0.5;
      }
    }

    debugPrint('[NavGuide] Left: ${leftZoneRisk.toStringAsFixed(2)}, Center: ${centerZoneRisk.toStringAsFixed(2)}, Right: ${rightZoneRisk.toStringAsFixed(2)}');

    // Determine safest direction
    return _determineGuidance(leftZoneRisk, centerZoneRisk, rightZoneRisk);
  }

  double _calculateRisk(Detection detection, int frameHeight) {
    // Risk based on danger level and proximity (using box height as proxy)
    final dangerFactor = detection.dangerLevel.weight;
    final boxHeight = detection.boundingBox.height;
    final proximityFactor = (boxHeight / frameHeight).clamp(0.0, 1.0);
    
    // Distance factor - closer objects are higher risk
    final distanceFactor = detection.distanceMeters > 0 
        ? (1 - (detection.distanceMeters / 5).clamp(0.0, 1.0)) 
        : proximityFactor;

    return (dangerFactor + proximityFactor + distanceFactor) / 3;
  }

  NavigationGuidance _determineGuidance(double left, double center, double right) {
    final allClear = left < 0.1 && center < 0.1 && right < 0.1;
    if (allClear) {
      return NavigationGuidance(
        direction: GuidanceDirection.forward,
        message: 'Path is clear',
        urgency: GuidanceUrgency.low,
      );
    }

    final highRiskThreshold = 0.5;
    final centerBlocked = center > highRiskThreshold;
    final leftBlocked = left > highRiskThreshold;
    final rightBlocked = right > highRiskThreshold;

    // All paths blocked - go back
    if (centerBlocked && leftBlocked && rightBlocked) {
      _lastGuidance = 'back';
      return NavigationGuidance(
        direction: GuidanceDirection.backward,
        message: 'Obstacles ahead. Go back!',
        urgency: GuidanceUrgency.urgent,
      );
    }

    // Center blocked but sides clear
    if (centerBlocked) {
      // Choose the safer side
      if (left < right) {
        _lastGuidance = 'left';
        return NavigationGuidance(
          direction: GuidanceDirection.left,
          message: 'Obstacle ahead. Move left!',
          urgency: GuidanceUrgency.high,
        );
      } else {
        _lastGuidance = 'right';
        return NavigationGuidance(
          direction: GuidanceDirection.right,
          message: 'Obstacle ahead. Move right!',
          urgency: GuidanceUrgency.high,
        );
      }
    }

    // Only left blocked
    if (leftBlocked && !rightBlocked) {
      _lastGuidance = 'right';
      return NavigationGuidance(
        direction: GuidanceDirection.right,
        message: 'Obstacle on left. Move right',
        urgency: GuidanceUrgency.medium,
      );
    }

    // Only right blocked
    if (rightBlocked && !leftBlocked) {
      _lastGuidance = 'left';
      return NavigationGuidance(
        direction: GuidanceDirection.left,
        message: 'Obstacle on right. Move left',
        urgency: GuidanceUrgency.medium,
      );
    }

    // Both sides blocked but center clear
    if (leftBlocked && rightBlocked && !centerBlocked) {
      _lastGuidance = 'forward';
      return NavigationGuidance(
        direction: GuidanceDirection.forward,
        message: 'Stay center. Obstacles on both sides',
        urgency: GuidanceUrgency.medium,
      );
    }

    // Low-level obstacles - just warn
    if (left > 0.1 || center > 0.1 || right > 0.1) {
      final safestDirection = [left, center, right].indexOf(
        [left, center, right].reduce((a, b) => a < b ? a : b)
      );
      
      final guidance = switch (safestDirection) {
        0 => NavigationGuidance(
            direction: GuidanceDirection.left,
            message: 'Safest path: left',
            urgency: GuidanceUrgency.low,
          ),
        1 => NavigationGuidance(
            direction: GuidanceDirection.forward,
            message: 'Continue forward carefully',
            urgency: GuidanceUrgency.low,
          ),
        _ => NavigationGuidance(
            direction: GuidanceDirection.right,
            message: 'Safest path: right',
            urgency: GuidanceUrgency.low,
          ),
      };
      return guidance;
    }

    return NavigationGuidance(
      direction: GuidanceDirection.forward,
      message: 'Continue forward',
      urgency: GuidanceUrgency.low,
    );
  }

  /// Check if guidance should be spoken (cooldown check)
  bool shouldAnnounce() {
    final now = DateTime.now();
    if (now.difference(_lastGuidanceTime) > _guidanceCooldown) {
      _lastGuidanceTime = now;
      return true;
    }
    return false;
  }
}

/// Navigation guidance result
class NavigationGuidance {
  final GuidanceDirection direction;
  final String message;
  final GuidanceUrgency urgency;

  NavigationGuidance({
    required this.direction,
    required this.message,
    required this.urgency,
  });

  @override
  String toString() => '$direction: $message ($urgency)';
}

/// Direction to move
enum GuidanceDirection {
  forward,
  left,
  right,
  backward,
}

/// How urgent the guidance is
enum GuidanceUrgency {
  low,
  medium,
  high,
  urgent,
}
