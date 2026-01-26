/// Detection model representing a detected object
class Detection {
  final String className;
  final int classId;
  final double confidence;
  final BoundingBox boundingBox;
  final DangerLevel dangerLevel;
  final double distanceMeters;
  final DateTime timestamp;

  Detection({
    required this.className,
    required this.classId,
    required this.confidence,
    required this.boundingBox,
    required this.dangerLevel,
    this.distanceMeters = -1,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  /// Get relative position in frame
  RelativePosition get relativePosition {
    final normalizedCenterX = boundingBox.centerX / 640; // Assuming 640px width
    if (normalizedCenterX < 0.33) return RelativePosition.left;
    if (normalizedCenterX > 0.67) return RelativePosition.right;
    return RelativePosition.center;
  }

  /// Human-readable distance description
  String get distanceDescription {
    if (distanceMeters < 0) return 'unknown distance';
    if (distanceMeters < 1) return 'very close';
    if (distanceMeters < 2) return 'nearby';
    if (distanceMeters < 5) return 'ahead';
    return 'in the distance';
  }
}

/// Bounding box coordinates
class BoundingBox {
  final double left;
  final double top;
  final double right;
  final double bottom;

  BoundingBox({
    required this.left,
    required this.top,
    required this.right,
    required this.bottom,
  });

  double get width => right - left;
  double get height => bottom - top;
  double get centerX => (left + right) / 2;
  double get centerY => (top + bottom) / 2;
  double get area => width * height;
}

/// Danger level classification
enum DangerLevel {
  critical(1.0, 0),
  high(0.8, 1),
  medium(0.5, 2),
  low(0.3, 3),
  info(0.1, 4),
  unknown(0.4, 5);

  final double weight;
  final int alertPriority;

  const DangerLevel(this.weight, this.alertPriority);

  static DangerLevel fromClassName(String className) {
    switch (className.toLowerCase()) {
      case 'stairs':
      case 'stairs_down':
      case 'staircase':
        return DangerLevel.critical;
      case 'person':
        return DangerLevel.high;
      case 'chair':
      case 'couch':
      case 'table':
      case 'dining table':
        return DangerLevel.medium;
      case 'book':
      case 'potted plant':
        return DangerLevel.low;
      case 'door':
        return DangerLevel.info;
      default:
        return DangerLevel.unknown;
    }
  }
}

/// Relative position in camera frame
enum RelativePosition {
  left('on your left'),
  center('ahead'),
  right('on your right');

  final String description;
  const RelativePosition(this.description);
}

/// Risk assessment result
class RiskAssessment {
  final Detection detection;
  final double score;
  final RiskLevel level;
  final String recommendation;
  final bool shouldAlert;

  RiskAssessment({
    required this.detection,
    required this.score,
    required this.level,
    required this.recommendation,
    required this.shouldAlert,
  });

  String get alertKey =>
      '${detection.className}_${detection.relativePosition}_$level';
}

/// Risk level classification
enum RiskLevel {
  critical(0.85, 1.0),
  high(0.65, 0.85),
  medium(0.40, 0.65),
  low(0.20, 0.40),
  safe(0.0, 0.20);

  final double minScore;
  final double maxScore;

  const RiskLevel(this.minScore, this.maxScore);

  static RiskLevel fromScore(double score) {
    for (final level in RiskLevel.values) {
      if (score >= level.minScore && score < level.maxScore) {
        return level;
      }
    }
    return RiskLevel.safe;
  }
}
