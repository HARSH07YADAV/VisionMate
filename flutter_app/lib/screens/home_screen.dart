import 'dart:async';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:provider/provider.dart';

import '../models/detection.dart';
import '../services/camera_service.dart';
import '../services/onnx_service.dart';
import '../services/tts_service.dart';
import '../services/haptic_service.dart';
import '../services/settings_service.dart';
import '../services/history_service.dart';
import '../services/emergency_service.dart';
import '../services/voice_command_service.dart';
import '../services/tracking_service.dart';
import '../services/navigation_guidance_service.dart';
import '../core/risk_calculator.dart';
import '../widgets/detection_overlay.dart';

/// Enhanced home screen with all 20 improvements:
/// - Large touch buttons (Feature 10)
/// - Screen reader support (Feature 12)
/// - Path clear guidance (Feature 7)
/// - Emergency SOS (Feature 17)
/// - Voice commands integration (Feature 11)
/// - Navigation mode filtering (Feature 18)
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  bool _isDetecting = false;
  bool _isLoading = true;
  List<Detection> _detections = [];
  List<RiskAssessment> _risks = [];
  String _statusMessage = 'Initializing...';
  int _fps = 0;
  DateTime _lastFrameTime = DateTime.now();

  // Path clear timer (Feature 7)
  Timer? _pathClearTimer;
  DateTime _lastDetectionTime = DateTime.now();

  final RiskCalculator _riskCalculator = RiskCalculator();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeServices();
  }

  Future<void> _initializeServices() async {
    final cameraService = context.read<CameraService>();
    final onnxService = context.read<OnnxService>();
    final ttsService = context.read<TTSService>();
    final hapticService = context.read<HapticService>();
    final settingsService = context.read<SettingsService>();
    final historyService = context.read<HistoryService>();
    final emergencyService = context.read<EmergencyService>();
    final voiceService = context.read<VoiceCommandService>();

    // Initialize all services
    await settingsService.initialize();
    await cameraService.initialize();
    await onnxService.initialize();
    await ttsService.initialize(settings: settingsService);
    await hapticService.initialize();
    await historyService.initialize();
    await emergencyService.initialize();
    await voiceService.initialize();

    // Set up voice commands
    _setupVoiceCommands(voiceService);

    // Set emergency contact from settings
    emergencyService.setEmergencyContact(settingsService.emergencyContact);

    // Apply haptic setting
    hapticService.setEnabled(settingsService.vibrationEnabled);

    setState(() {
      _isLoading = false;
      if (onnxService.error != null) {
        _statusMessage = 'Model error: ${onnxService.error}';
      } else {
        _statusMessage = 'Ready. Tap Start to begin.';
      }
    });

    // Announce ready
    if (onnxService.isInitialized) {
      ttsService.speak('BlindAssist ready. Tap the large button to start.');
    } else {
      ttsService.speak('Warning: Detection model failed to load.');
    }
  }

  void _setupVoiceCommands(VoiceCommandService voiceService) {
    voiceService.onWhatsAhead = _announceCurrentDetections;
    voiceService.onStart = _startDetection;
    voiceService.onStop = _stopDetection;
    voiceService.onEmergency = _triggerEmergency;
    voiceService.onRepeat = _repeatLastAnnouncement;
    
    // Enable if setting is on
    final settings = context.read<SettingsService>();
    if (settings.voiceCommandsEnabled) {
      voiceService.setEnabled(true);
      voiceService.startListening();
    }
  }

  void _announceCurrentDetections() {
    final tts = context.read<TTSService>();
    if (_detections.isEmpty) {
      tts.speakImmediately('No obstacles detected ahead.');
    } else {
      final desc = _detections.take(3).map((d) => 
        '${d.className} ${d.distanceDescription}'
      ).join(', ');
      tts.speakImmediately('Detected: $desc');
    }
  }

  void _repeatLastAnnouncement() {
    if (_risks.isNotEmpty) {
      context.read<TTSService>().speakRisk(_risks.first);
    }
  }

  Future<void> _triggerEmergency() async {
    final emergency = context.read<EmergencyService>();
    final tts = context.read<TTSService>();
    final haptic = context.read<HapticService>();

    await haptic.vibrateEmergency();
    tts.speakEmergency('Sending SOS to emergency contact.');
    
    final success = await emergency.triggerSOS();
    if (!success) {
      tts.speakEmergency('Could not send emergency message. Please set a contact in settings.');
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      _stopDetection();
    }
  }

  void _toggleDetection() {
    if (_isDetecting) {
      _stopDetection();
    } else {
      _startDetection();
    }
  }

  Future<void> _startDetection() async {
    final cameraService = context.read<CameraService>();
    final onnxService = context.read<OnnxService>();
    final ttsService = context.read<TTSService>();
    final trackingService = context.read<TrackingService>();
    final settings = context.read<SettingsService>();

    if (!cameraService.isInitialized) {
      ttsService.speak('Camera not available');
      return;
    }

    if (!onnxService.isInitialized) {
      ttsService.speak('Detection model not available');
      return;
    }

    // Clear tracking
    trackingService.clearTracks();

    setState(() {
      _isDetecting = true;
      _statusMessage = 'Detection active';
    });

    ttsService.speak('Detection started. Point camera forward.');

    // Start path clear timer (Feature 7)
    _startPathClearTimer(settings.pathClearInterval);

    // Start processing frames
    await cameraService.startImageStream(_processFrame);
  }

  void _startPathClearTimer(int intervalSeconds) {
    _pathClearTimer?.cancel();
    _pathClearTimer = Timer.periodic(Duration(seconds: intervalSeconds), (_) {
      final timeSinceDetection = DateTime.now().difference(_lastDetectionTime);
      if (timeSinceDetection.inSeconds > 3 && _isDetecting) {
        context.read<TTSService>().speakPathClear();
      }
    });
  }

  void _stopDetection() {
    final cameraService = context.read<CameraService>();
    final ttsService = context.read<TTSService>();
    final trackingService = context.read<TrackingService>();

    cameraService.stopImageStream();
    _pathClearTimer?.cancel();
    trackingService.clearTracks();

    setState(() {
      _isDetecting = false;
      _detections = [];
      _risks = [];
      _statusMessage = 'Detection stopped';
    });

    ttsService.speak('Detection stopped.');
  }

  /// Process a camera frame
  Future<void> _processFrame(CameraImage image) async {
    if (!_isDetecting) return;

    final onnxService = context.read<OnnxService>();
    final ttsService = context.read<TTSService>();
    final hapticService = context.read<HapticService>();
    final historyService = context.read<HistoryService>();
    final trackingService = context.read<TrackingService>();
    final settings = context.read<SettingsService>();

    try {
      // Calculate FPS
      final now = DateTime.now();
      final frameDuration = now.difference(_lastFrameTime);
      _lastFrameTime = now;
      if (frameDuration.inMilliseconds > 0) {
        _fps = (1000 / frameDuration.inMilliseconds).round();
      }

      // Run detection
      var detections = await onnxService.detectObjects(image);

      // Filter by navigation mode (Feature 18)
      detections = detections.where((d) => 
        settings.navigationMode.isRelevant(d.className)
      ).toList();

      // Calculate risks
      final risks = _riskCalculator.calculateForAll(
        detections,
        frameWidth: image.width,
      );

      setState(() {
        _detections = detections;
        _risks = risks;
        _statusMessage = 'Detecting: ${detections.length} objects';
      });

      if (detections.isNotEmpty) {
        _lastDetectionTime = now;
        
        // Log to history (Feature 20)
        await historyService.logDetections(detections);

        // Use tracking to find NEW detections (Feature 3)
        final newDetections = trackingService.updateTrackers(detections);

        // Announce and vibrate for new detections
        for (final detection in newDetections.take(2)) {
          // Haptic with proximity (Feature 9)
          if (settings.vibrationEnabled) {
            await hapticService.vibrateForDetection(detection);
          }

          // TTS with priority (Feature 4)
          await ttsService.speakDetection(detection);
        }
        
        // Provide directional guidance (move left/right/back)
        final navGuidance = context.read<NavigationGuidanceService>();
        final guidance = navGuidance.analyzeAndGuide(
          detections,
          frameWidth: image.width,
          frameHeight: image.height,
        );
        
        // Announce guidance if urgent or medium+ and cooldown passed
        if (guidance.urgency != GuidanceUrgency.low && navGuidance.shouldAnnounce()) {
          final priority = guidance.urgency == GuidanceUrgency.urgent 
              ? SpeechPriority.interrupt 
              : SpeechPriority.high;
          await ttsService.speak(guidance.message, priority: priority);
        }
      }
    } catch (e) {
      debugPrint('Detection error: $e');
    }
  }

  Future<void> _toggleFlash() async {
    final cameraService = context.read<CameraService>();
    final ttsService = context.read<TTSService>();

    await cameraService.toggleFlash();
    ttsService.speak(cameraService.isFlashOn ? 'Flashlight on' : 'Flashlight off');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            // Status bar
            _buildStatusBar(),

            // Camera preview with overlay
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _buildCameraPreview(),
            ),

            // Control panel with large buttons
            _buildControlPanel(),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusBar() {
    final highestRisk = _risks.isNotEmpty ? _risks.first : null;
    
    return Semantics(
      liveRegion: true,
      label: _statusMessage,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        color: _getRiskColor(highestRisk?.level),
        child: Column(
          children: [
            Text(
              _statusMessage,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            if (highestRisk != null) ...[
              const SizedBox(height: 8),
              Text(
                '${highestRisk.level.name.toUpperCase()}: ${highestRisk.detection.className}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Color _getRiskColor(RiskLevel? level) {
    return switch (level) {
      RiskLevel.critical => Colors.red.shade800,
      RiskLevel.high => Colors.orange.shade800,
      RiskLevel.medium => Colors.amber.shade800,
      RiskLevel.low => Colors.green.shade800,
      _ => Colors.grey.shade800,
    };
  }

  Widget _buildCameraPreview() {
    final cameraService = context.watch<CameraService>();

    if (!cameraService.isInitialized || cameraService.controller == null) {
      return Semantics(
        label: 'Camera not available',
        child: const Center(
          child: Text(
            'Camera not available',
            style: TextStyle(color: Colors.white, fontSize: 20),
          ),
        ),
      );
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        // Camera preview
        ClipRect(
          child: OverflowBox(
            alignment: Alignment.center,
            child: CameraPreview(cameraService.controller!),
          ),
        ),

        // Detection overlay with bounding boxes
        if (_detections.isNotEmpty)
          DetectionOverlay(
            detections: _detections,
            risks: _risks,
            previewSize: cameraService.controller!.value.previewSize!,
          ),
      ],
    );
  }

  Widget _buildControlPanel() {
    return Container(
      padding: const EdgeInsets.all(16),
      color: Colors.black87,
      child: Column(
        children: [
          // Row 1: Main detection button (Feature 10 - Large)
          Row(
            children: [
              // Start/Stop button - takes 3/4 width
              Expanded(
                flex: 3,
                child: Semantics(
                  button: true,
                  label: _isDetecting ? 'Stop detection' : 'Start detection',
                  child: SizedBox(
                    height: 100,
                    child: ElevatedButton(
                      onPressed: _toggleDetection,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _isDetecting ? Colors.red : Colors.blue,
                        foregroundColor: Colors.white,
                        textStyle: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      child: Text(_isDetecting ? 'STOP' : 'START'),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              // Emergency SOS button (Feature 17)
              Expanded(
                flex: 1,
                child: Semantics(
                  button: true,
                  label: 'Emergency SOS',
                  child: SizedBox(
                    height: 100,
                    child: ElevatedButton(
                      onPressed: _triggerEmergency,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red.shade900,
                        foregroundColor: Colors.white,
                      ),
                      child: const Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.emergency, size: 32),
                          Text('SOS', style: TextStyle(fontSize: 14)),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Row 2: Secondary controls (Feature 10 - 80px height minimum)
          Row(
            children: [
              // Flashlight
              Expanded(
                child: Semantics(
                  button: true,
                  label: 'Toggle flashlight',
                  child: SizedBox(
                    height: 80,
                    child: ElevatedButton(
                      onPressed: _toggleFlash,
                      child: const Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.flashlight_on, size: 28),
                          SizedBox(height: 4),
                          Text('Torch'),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              // What's ahead
              Expanded(
                child: Semantics(
                  button: true,
                  label: 'What is ahead',
                  child: SizedBox(
                    height: 80,
                    child: ElevatedButton(
                      onPressed: _announceCurrentDetections,
                      child: const Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.visibility, size: 28),
                          SizedBox(height: 4),
                          Text('Ahead?'),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              // Settings
              Expanded(
                child: Semantics(
                  button: true,
                  label: 'Open settings',
                  child: SizedBox(
                    height: 80,
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pushNamed(context, '/settings');
                      },
                      child: const Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.settings, size: 28),
                          SizedBox(height: 4),
                          Text('Settings'),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _pathClearTimer?.cancel();
    super.dispose();
  }
}
