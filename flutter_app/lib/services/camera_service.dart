import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:camera/camera.dart';

/// FULLY FEATURED Camera service with:
/// - Frame throttling (3-5 FPS for detection)
/// - Configurable resolution (Feature 14)
/// - Non-blocking frame processing
/// - Battery optimization (Feature 16)
class CameraService extends ChangeNotifier {
  CameraController? _controller;
  List<CameraDescription>? _cameras;
  bool _isInitialized = false;
  bool _isStreaming = false;
  String? _error;
  
  // Resolution setting (Feature 14)
  ResolutionPreset _resolution = ResolutionPreset.low;
  bool _isHighResolution = false;
  
  // Frame throttling
  DateTime _lastFrameTime = DateTime.now();
  int _targetFps = 4;
  int get _frameIntervalMs => 1000 ~/ _targetFps;
  
  // Processing lock
  bool _isProcessingFrame = false;
  
  // Battery optimization (Feature 16)
  bool _isPaused = false;
  int _framesSinceLastDetection = 0;
  static const int _maxIdleFrames = 20; // After 20 frames with no detection, slow down

  CameraController? get controller => _controller;
  bool get isInitialized => _isInitialized;
  bool get isStreaming => _isStreaming;
  String? get error => _error;
  bool get isHighResolution => _isHighResolution;
  bool get isPaused => _isPaused;

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
    
    // Adjust FPS based on resolution
    _targetFps = enabled ? 2 : 4;
    
    await _initController();
    debugPrint('Camera: Resolution changed to ${_resolution.name}');
  }

  /// Start image stream with FRAME THROTTLING
  Future<void> startImageStream(
    Future<void> Function(CameraImage image) onImage,
  ) async {
    if (_controller == null || !_isInitialized) return;
    if (_isStreaming) return;

    try {
      debugPrint('Camera: Starting throttled image stream at $_targetFps FPS');
      _isStreaming = true;
      _isPaused = false;
      _framesSinceLastDetection = 0;
      
      await _controller!.startImageStream((CameraImage image) {
        if (_isPaused) return;
        
        final now = DateTime.now();
        final elapsed = now.difference(_lastFrameTime).inMilliseconds;
        
        // THROTTLE: Skip frame if not enough time has passed
        if (elapsed < _frameIntervalMs) {
          return;
        }
        
        // SKIP: If still processing previous frame
        if (_isProcessingFrame) {
          return;
        }
        
        _lastFrameTime = now;
        _isProcessingFrame = true;
        
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
      // Speed up if we had slowed down
      if (_targetFps < 4) {
        _targetFps = _isHighResolution ? 2 : 4;
      }
    } else {
      _framesSinceLastDetection++;
      // Slow down after many frames with no detections (battery saving)
      if (_framesSinceLastDetection > _maxIdleFrames) {
        _targetFps = 1; // Reduce to 1 FPS
        debugPrint('Camera: Battery saver mode (1 FPS)');
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
    stopImageStream();
    _controller?.dispose();
    super.dispose();
  }
}
