import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:camera/camera.dart';
import 'package:sensors_plus/sensors_plus.dart';

/// FULLY FEATURED Camera service with:
/// - Frame throttling (adaptive 2-8 FPS for detection)
/// - Configurable resolution (Feature 14)
/// - Non-blocking frame processing
/// - Battery optimization (Feature 16)
/// - Motion-aware adaptive FPS
/// - Pocket detection
class CameraService extends ChangeNotifier {
  CameraController? _controller;
  List<CameraDescription>? _cameras;
  bool _isInitialized = false;
  bool _isStreaming = false;
  String? _error;
  
  // Resolution setting (Feature 14)
  ResolutionPreset _resolution = ResolutionPreset.low;
  bool _isHighResolution = false;
  
  // Frame throttling - adaptive FPS
  DateTime _lastFrameTime = DateTime.now();
  int _targetFps = 5;
  int _baseFps = 5;  // Base FPS before adaptive adjustment
  int get _frameIntervalMs => 1000 ~/ _targetFps;
  
  // Processing lock
  bool _isProcessingFrame = false;
  
  // Battery optimization (Feature 16)
  bool _isPaused = false;
  int _framesSinceLastDetection = 0;
  static const int _maxIdleFrames = 15; // After 15 frames with no detection, slow down

  // Motion-aware adaptive FPS
  StreamSubscription<AccelerometerEvent>? _accelerometerSub;
  double _lastAccelMagnitude = 0;
  MotionState _motionState = MotionState.stationary;
  DateTime _lastMotionChange = DateTime.now();
  
  // Pocket detection
  bool _isInPocket = false;
  StreamSubscription<AccelerometerEvent>? _pocketDetectSub;
  
  // Performance metrics
  int _totalFramesProcessed = 0;
  int _totalFramesDropped = 0;
  DateTime _streamStartTime = DateTime.now();
  double get droppedFrameRate => _totalFramesProcessed > 0 
      ? _totalFramesDropped / (_totalFramesProcessed + _totalFramesDropped) 
      : 0;
  int get effectiveFps => _targetFps;

  CameraController? get controller => _controller;
  bool get isInitialized => _isInitialized;
  bool get isStreaming => _isStreaming;
  String? get error => _error;
  bool get isHighResolution => _isHighResolution;
  bool get isPaused => _isPaused;
  bool get isInPocket => _isInPocket;
  MotionState get motionState => _motionState;

  /// Initialize camera with configurable resolution
  Future<void> initialize({bool highResolution = false}) async {
    try {
      debugPrint('Camera: Initializing...');
      _cameras = await availableCameras();
      
      if (_cameras == null || _cameras!.isEmpty) {
        _error = 'No cameras available';
        notifyListeners();
        return;
      }

      _isHighResolution = highResolution;
      _resolution = highResolution ? ResolutionPreset.medium : ResolutionPreset.low;
      
      await _initController();
      
      // Start motion monitoring for adaptive FPS
      _startMotionMonitoring();
      
    } catch (e) {
      _error = 'Camera initialization failed: $e';
      debugPrint('Camera ERROR: $_error');
      notifyListeners();
    }
  }

  Future<void> _initController() async {
    // Select back camera
    final backCamera = _cameras!.firstWhere(
      (camera) => camera.lensDirection == CameraLensDirection.back,
      orElse: () => _cameras!.first,
    );

    // Dispose old controller if exists
    if (_controller != null) {
      await _controller!.dispose();
    }

    _controller = CameraController(
      backCamera,
      _resolution,
      enableAudio: false,
      imageFormatGroup: ImageFormatGroup.yuv420,
    );

    await _controller!.initialize();
    
    // Lock exposure and focus for consistent performance
    try {
      await _controller!.setExposureMode(ExposureMode.auto);
      await _controller!.setFocusMode(FocusMode.auto);
    } catch (e) {
      debugPrint('Camera: Could not set exposure/focus mode: $e');
    }
    
    _isInitialized = true;
    _error = null;
    debugPrint('Camera: Initialized at ${_controller!.value.previewSize} (${_resolution.name})');
    notifyListeners();
  }

  /// Switch resolution (Feature 14)
  Future<void> setHighResolution(bool enabled) async {
    if (_isHighResolution == enabled) return;
    
    final wasStreaming = _isStreaming;
    if (wasStreaming) {
      await stopImageStream();
    }
    
    _isHighResolution = enabled;
    _resolution = enabled ? ResolutionPreset.medium : ResolutionPreset.low;
    
    // Adjust base FPS based on resolution
    _baseFps = enabled ? 3 : 5;
    _targetFps = _baseFps;
    
    await _initController();
    debugPrint('Camera: Resolution changed to ${_resolution.name}, base FPS: $_baseFps');
  }

  /// Start motion monitoring using accelerometer
  void _startMotionMonitoring() {
    _accelerometerSub?.cancel();
    
    try {
      _accelerometerSub = accelerometerEventStream(
        samplingPeriod: const Duration(milliseconds: 200),
      ).listen((AccelerometerEvent event) {
        final magnitude = math.sqrt(
          event.x * event.x + event.y * event.y + event.z * event.z
        );
        
        // Detect motion state from acceleration changes
        final delta = (magnitude - _lastAccelMagnitude).abs();
        _lastAccelMagnitude = magnitude;
        
        final prevState = _motionState;
        
        if (delta > 2.0) {
          _motionState = MotionState.walking;
        } else if (delta > 0.5) {
          _motionState = MotionState.moving;
        } else {
          _motionState = MotionState.stationary;
        }
        
        // Pocket detection: phone face-down or gravity primarily on Z-axis
        // with screen facing down (z acceleration > 8)
        final isLikelyPocketed = event.z.abs() > 8.5 && 
            event.x.abs() < 2.0 && event.y.abs() < 3.0;
        
        if (isLikelyPocketed != _isInPocket) {
          _isInPocket = isLikelyPocketed;
          if (_isInPocket) {
            debugPrint('Camera: Pocket detected – pausing');
            setPaused(true);
          } else {
            debugPrint('Camera: Phone removed from pocket – resuming');
            setPaused(false);
          }
        }
        
        // Adapt FPS based on motion state
        if (prevState != _motionState) {
          _lastMotionChange = DateTime.now();
          _adaptFps();
        }
      });
    } catch (e) {
      debugPrint('Camera: Accelerometer not available: $e');
    }
  }
  
  /// Adapt FPS based on current motion state
  void _adaptFps() {
    if (_isPaused) return;
    
    final prevFps = _targetFps;
    switch (_motionState) {
      case MotionState.walking:
        // Walking: need fast detection
        _targetFps = _isHighResolution ? 4 : 8;
        break;
      case MotionState.moving:
        // Slight movement: moderate FPS
        _targetFps = _baseFps;
        break;
      case MotionState.stationary:
        // Not moving: save battery
        _targetFps = math.max(2, _baseFps ~/ 2);
        break;
    }
    
    if (prevFps != _targetFps) {
      debugPrint('Camera: Adaptive FPS: $prevFps → $_targetFps (${_motionState.name})');
    }
  }

  /// Start image stream with ADAPTIVE FRAME THROTTLING
  Future<void> startImageStream(
    Future<void> Function(CameraImage image) onImage,
  ) async {
    if (_controller == null || !_isInitialized) return;
    if (_isStreaming) return;

    try {
      debugPrint('Camera: Starting adaptive image stream at $_targetFps FPS');
      _isStreaming = true;
      _isPaused = false;
      _framesSinceLastDetection = 0;
      _totalFramesProcessed = 0;
      _totalFramesDropped = 0;
      _streamStartTime = DateTime.now();
      
      await _controller!.startImageStream((CameraImage image) {
        if (_isPaused || _isInPocket) return;
        
        final now = DateTime.now();
        final elapsed = now.difference(_lastFrameTime).inMilliseconds;
        
        // THROTTLE: Skip frame if not enough time has passed
        if (elapsed < _frameIntervalMs) {
          return;
        }
        
        // SKIP: If still processing previous frame
        if (_isProcessingFrame) {
          _totalFramesDropped++;
          return;
        }
        
        _lastFrameTime = now;
        _isProcessingFrame = true;
        _totalFramesProcessed++;
        
        // Process frame asynchronously (non-blocking)
        onImage(image).whenComplete(() {
          _isProcessingFrame = false;
        });
      });
      
      notifyListeners();
    } catch (e) {
      _error = 'Failed to start image stream: $e';
      _isStreaming = false;
      debugPrint('Camera ERROR: $_error');
      notifyListeners();
    }
  }

  /// Notify detection result for battery optimization (Feature 16)
  void notifyDetectionResult(int detectionCount) {
    if (detectionCount > 0) {
      _framesSinceLastDetection = 0;
      // Speed up if we had slowed down due to idle
      if (_targetFps < _baseFps) {
        _adaptFps(); // Restore motion-appropriate FPS
      }
    } else {
      _framesSinceLastDetection++;
      // Slow down after many frames with no detections (battery saving)
      if (_framesSinceLastDetection > _maxIdleFrames) {
        _targetFps = 1; // Reduce to 1 FPS
        debugPrint('Camera: Battery saver mode (1 FPS) – no detections for $_framesSinceLastDetection frames');
      }
    }
  }

  /// Pause/resume streaming (Feature 16 - pocket mode)
  void setPaused(bool paused) {
    _isPaused = paused;
    notifyListeners();
  }

  /// Stop image stream
  Future<void> stopImageStream() async {
    if (_controller == null || !_isInitialized) return;
    if (!_isStreaming) return;

    try {
      await _controller!.stopImageStream();
      _isStreaming = false;
      _isProcessingFrame = false;
      notifyListeners();
      debugPrint('Camera: Image stream stopped');
    } catch (e) {
      debugPrint('Camera: Error stopping stream: $e');
    }
  }

  /// Toggle flashlight
  Future<void> toggleFlash() async {
    if (_controller == null || !_isInitialized) return;

    try {
      final currentMode = _controller!.value.flashMode;
      final newMode = currentMode == FlashMode.off ? FlashMode.torch : FlashMode.off;
      await _controller!.setFlashMode(newMode);
      notifyListeners();
    } catch (e) {
      debugPrint('Camera: Error toggling flash: $e');
    }
  }

  bool get isFlashOn => _controller?.value.flashMode == FlashMode.torch;

  @override
  void dispose() {
    _accelerometerSub?.cancel();
    _pocketDetectSub?.cancel();
    stopImageStream();
    _controller?.dispose();
    super.dispose();
  }
}

/// Motion states for adaptive FPS
enum MotionState {
  stationary,  // Phone not moving – low FPS
  moving,      // Slight movement – normal FPS
  walking,     // Walking – high FPS for safety
}
