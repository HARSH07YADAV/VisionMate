import 'dart:math';
import '../models/detection.dart';

/// Risk calculator for determining danger levels
class RiskCalculator {
  final double distanceWeight;
  final double dangerWeight;
  final double positionWeight;
  final double maxSafeDistance;

  RiskCalculator({
    this.distanceWeight = 0.40,
    this.dangerWeight = 0.35,
    this.positionWeight = 0.25,
    this.maxSafeDistance = 5.0,
  });

  /// Calculate risk for a single detection
  RiskAssessment calculate(
    Detection detection, {
    required int frameWidth,
  }) {
    // Distance factor (closer = higher risk)
    final distanceFactor = _calculateDistanceFactor(detection, frameWidth);

    // Danger factor (based on object type)
    final dangerFactor = detection.dangerLevel.weight;

    // Position factor (center = higher risk)
    final positionFactor = _calculatePositionFactor(detection, frameWidth);

    // Weighted score
    final score = (
      distanceWeight * distanceFactor +
      dangerWeight * dangerFactor +
      positionWeight * positionFactor
    ).clamp(0.0, 1.0);

    final level = RiskLevel.fromScore(score);
    final recommendation = _generateRecommendation(detection, level);
    final shouldAlert = level != RiskLevel.safe && level != RiskLevel.low;

    return RiskAssessment(
      detection: detection,
      score: score,
      level: level,
      recommendation: recommendation,
      shouldAlert: shouldAlert,
    );
  }

  /// Calculate risk for multiple detections, sorted by priority
  List<RiskAssessment> calculateForAll(
    List<Detection> detections, {
    required int frameWidth,
  }) {
    return detections
        .map((d) => calculate(d, frameWidth: frameWidth))
        .toList()
      ..sort((a, b) => b.score.compareTo(a.score));
  }

  double _calculateDistanceFactor(Detection detection, int frameWidth) {
    // Estimate distance from bounding box size
    final frameArea = frameWidth * frameWidth * 0.75; // Approximate
    final bboxRatio = detection.boundingBox.area / frameArea;
    
    // Larger box = closer object = higher risk
    return min(1.0, bboxRatio * 5);
  }

  double _calculatePositionFactor(Detection detection, int frameWidth) {
    final normalizedCenterX = detection.boundingBox.centerX / frameWidth;
    final horizontalOffset = (normalizedCenterX - 0.5).abs();

    if (horizontalOffset < 0.17) return 1.0;  // Center third
    if (horizontalOffset < 0.33) return 0.5;  // Middle thirds
    return 0.2;  // Outer thirds
  }

  String _generateRecommendation(Detection detection, RiskLevel level) {
    final position = detection.relativePosition.description;
    final distance = detection.distanceDescription;
    final objectName = detection.className.replaceAll('_', ' ');

    return switch (level) {
      RiskLevel.critical => 'Stop! $objectName $position, $distance!',
      RiskLevel.high => 'Caution! $objectName $position, $distance.',
      RiskLevel.medium => '$objectName detected $position.',
      RiskLevel.low => '$objectName $position.',
      RiskLevel.safe => '',
    };
  }
}
