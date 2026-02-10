import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

import '../models/detection.dart';

/// Detection history service (Feature 20)
/// Logs detections for caregiver review
class HistoryService extends ChangeNotifier {
  Database? _db;
  bool _isInitialized = false;
  
  static const String _tableName = 'detection_history';

  bool get isInitialized => _isInitialized;

  /// Initialize database
  Future<void> initialize() async {
    if (_isInitialized) return;
    
    try {
      final databasesPath = await getDatabasesPath();
      final path = join(databasesPath, 'vision_mate.db');
      
      _db = await openDatabase(
        path,
        version: 1,
        onCreate: (Database db, int version) async {
          await db.execute('''
            CREATE TABLE $_tableName (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              timestamp TEXT NOT NULL,
              class_name TEXT NOT NULL,
              class_id INTEGER NOT NULL,
              confidence REAL NOT NULL,
              distance_meters REAL,
              position TEXT,
              danger_level TEXT
            )
          ''');
        },
      );
      
      _isInitialized = true;
      debugPrint('History: DB initialized');
    } catch (e) {
      debugPrint('History: Init error: $e');
    }
  }

  /// Log a detection
  Future<void> logDetection(Detection detection) async {
    if (!_isInitialized || _db == null) return;
    
    try {
      await _db!.insert(_tableName, {
        'timestamp': detection.timestamp.toIso8601String(),
        'class_name': detection.className,
        'class_id': detection.classId,
        'confidence': detection.confidence,
        'distance_meters': detection.distanceMeters,
        'position': detection.relativePosition.name,
        'danger_level': detection.dangerLevel.name,
      });
    } catch (e) {
      debugPrint('History: Log error: $e');
    }
  }

  /// Log multiple detections
  Future<void> logDetections(List<Detection> detections) async {
    for (final d in detections) {
      await logDetection(d);
    }
  }

  /// Get recent history
  Future<List<HistoryEntry>> getRecentHistory({int limit = 100}) async {
    if (!_isInitialized || _db == null) return [];
    
    try {
      final rows = await _db!.query(
        _tableName,
        orderBy: 'timestamp DESC',
        limit: limit,
      );
      
      return rows.map((row) => HistoryEntry.fromMap(row)).toList();
    } catch (e) {
      debugPrint('History: Query error: $e');
      return [];
    }
  }

  /// Get history for a specific date
  Future<List<HistoryEntry>> getHistoryForDate(DateTime date) async {
    if (!_isInitialized || _db == null) return [];
    
    final startOfDay = DateTime(date.year, date.month, date.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));
    
    try {
      final rows = await _db!.query(
        _tableName,
        where: 'timestamp >= ? AND timestamp < ?',
        whereArgs: [startOfDay.toIso8601String(), endOfDay.toIso8601String()],
        orderBy: 'timestamp DESC',
      );
      
      return rows.map((row) => HistoryEntry.fromMap(row)).toList();
    } catch (e) {
      debugPrint('History: Query error: $e');
      return [];
    }
  }

  /// Get summary statistics
  Future<Map<String, int>> getClassCounts({int days = 7}) async {
    if (!_isInitialized || _db == null) return {};
    
    final since = DateTime.now().subtract(Duration(days: days));
    
    try {
      final rows = await _db!.rawQuery('''
        SELECT class_name, COUNT(*) as count
        FROM $_tableName
        WHERE timestamp >= ?
        GROUP BY class_name
        ORDER BY count DESC
      ''', [since.toIso8601String()]);
      
      final counts = <String, int>{};
      for (final row in rows) {
        counts[row['class_name'] as String] = row['count'] as int;
      }
      return counts;
    } catch (e) {
      debugPrint('History: Stats error: $e');
      return {};
    }
  }

  /// Clear old history (keep last 7 days)
  Future<void> clearOldHistory() async {
    if (!_isInitialized || _db == null) return;
    
    final cutoff = DateTime.now().subtract(const Duration(days: 7));
    
    try {
      await _db!.delete(
        _tableName,
        where: 'timestamp < ?',
        whereArgs: [cutoff.toIso8601String()],
      );
    } catch (e) {
      debugPrint('History: Clear error: $e');
    }
  }

  /// Clear all history
  Future<void> clearAllHistory() async {
    if (!_isInitialized || _db == null) return;
    
    try {
      await _db!.delete(_tableName);
    } catch (e) {
      debugPrint('History: Clear all error: $e');
    }
  }

  @override
  void dispose() {
    _db?.close();
    super.dispose();
  }
}

/// History entry model
class HistoryEntry {
  final int id;
  final DateTime timestamp;
  final String className;
  final int classId;
  final double confidence;
  final double? distanceMeters;
  final String? position;
  final String? dangerLevel;

  HistoryEntry({
    required this.id,
    required this.timestamp,
    required this.className,
    required this.classId,
    required this.confidence,
    this.distanceMeters,
    this.position,
    this.dangerLevel,
  });

  factory HistoryEntry.fromMap(Map<String, dynamic> map) {
    return HistoryEntry(
      id: map['id'] as int,
      timestamp: DateTime.parse(map['timestamp'] as String),
      className: map['class_name'] as String,
      classId: map['class_id'] as int,
      confidence: map['confidence'] as double,
      distanceMeters: map['distance_meters'] as double?,
      position: map['position'] as String?,
      dangerLevel: map['danger_level'] as String?,
    );
  }
}
