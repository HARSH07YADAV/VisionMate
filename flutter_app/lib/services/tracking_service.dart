import 'package:flutter/foundation.dart';
import '../models/detection.dart';

/// Object tracking service (Feature 3)
/// Tracks objects across frames to avoid repeated announcements
class TrackingService extends ChangeNotifier {
  final Map<int, TrackedObject> _trackedObjects = {};
  int _nextTrackId = 0;
  
  static const double _iouThreshold = 0.5;
  static const int _maxMissedFrames = 3;
  static const Duration _minReAnnounceDuration = Duration(seconds: 3);

  List<TrackedObject> get trackedObjects => _trackedObjects.values.toList();

  /// Update trackers with new detections
  /// Returns list of NEW detections that should be announced
  List<Detection> updateTrackers(List<Detection> detections) {
    final announceList = <Detection>[];
    final matched = <int>{};
    
    // Try to match new detections with existing tracks
    for (final detection in detections) {
      int? bestTrackId;
      double bestIou = 0;
      
      for (final entry in _trackedObjects.entries) {
        if (entry.value.className != detection.className) continue;
        
        final iou = _calculateIoU(entry.value.lastBox, detection.boundingBox);
        if (iou > _iouThreshold && iou > bestIou) {
          bestIou = iou;
          bestTrackId = entry.key;
        }
      }
      
      if (bestTrackId != null) {
        // Update existing track
        matched.add(bestTrackId);
        final track = _trackedObjects[bestTrackId]!;
        track.update(detection);
        
        // Check if should re-announce (object moved significantly or time passed)
        if (track.shouldReAnnounce) {
          announceList.add(detection);
          track.markAnnounced();
        }
      } else {
        // New object - create track and announce
        final trackId = _nextTrackId++;
        _trackedObjects[trackId] = TrackedObject(
          id: trackId,
          className: detection.className,
          lastBox: detection.boundingBox,
          detection: detection,
        );
        announceList.add(detection);
      }
    }
    
    // Update missed counts and remove stale tracks
    final toRemove = <int>[];
    for (final entry in _trackedObjects.entries) {
      if (!matched.contains(entry.key)) {
        entry.value.missedFrames++;
        if (entry.value.missedFrames > _maxMissedFrames) {
          toRemove.add(entry.key);
        }
      }
    }
    
    for (final id in toRemove) {
      _trackedObjects.remove(id);
    }
    
    return announceList;
  }

  /// Calculate IoU between two boxes
  double _calculateIoU(BoundingBox a, BoundingBox b) {
    final x1 = a.left > b.left ? a.left : b.left;
    final y1 = a.top > b.top ? a.top : b.top;
    final x2 = a.right < b.right ? a.right : b.right;
    final y2 = a.bottom < b.bottom ? a.bottom : b.bottom;
    
    if (x2 <= x1 || y2 <= y1) return 0;
    
    final intersection = (x2 - x1) * (y2 - y1);
    final union = a.area + b.area - intersection;
    
    return intersection / union;
  }

  /// Clear all tracks
  void clearTracks() {
    _trackedObjects.clear();
    _nextTrackId = 0;
  }
}

/// Tracked object state
class TrackedObject {
  final int id;
  final String className;
  BoundingBox lastBox;
  Detection detection;
  int missedFrames = 0;
  DateTime lastAnnounced;
  DateTime firstSeen;

  TrackedObject({
    required this.id,
    required this.className,
    required this.lastBox,
    required this.detection,
  }) : lastAnnounced = DateTime.now(),
       firstSeen = DateTime.now();

  /// Update with new detection
  void update(Detection newDetection) {
    lastBox = newDetection.boundingBox;
    detection = newDetection;
    missedFrames = 0;
  }

  /// Mark as announced
  void markAnnounced() {
    lastAnnounced = DateTime.now();
  }

  /// Check if enough time passed for re-announcement
  bool get shouldReAnnounce {
    final timeSince = DateTime.now().difference(lastAnnounced);
    return timeSince > const Duration(seconds: 3);
  }

  /// Age of this track
  Duration get age => DateTime.now().difference(firstSeen);
}
