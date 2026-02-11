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
import '../services/accessibility_activation_service.dart';
import '../services/ocr_service.dart';
import '../services/context_service.dart';
import '../services/currency_service.dart';
import '../services/learning_service.dart';
import '../services/feedback_service.dart';
import '../services/earcon_service.dart';
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

    // === PHASE 1: Critical services (camera + detection ready ASAP) ===
    await settingsService.initialize();
    
    // Initialize camera and ONNX model in parallel for faster startup
    await Future.wait([
      cameraService.initialize(),
      onnxService.initialize(),
      ttsService.initialize(settings: settingsService),
      hapticService.initialize(),
      context.read<EarconService>().initialize(),
    ]);

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

    // Calm, reassuring startup message
    if (onnxService.isInitialized) {
      ttsService.speak('VisionMate ready. Shake phone, press volume up, or double tap to speak. I\'m here with you.');
    } else {
      ttsService.speak('Warning: Detection model failed to load.');
    }

    // === PHASE 2: Non-critical services (load in background, don't block UI) ===
    _initializeNonCriticalServices();
  }

  /// Initialize non-critical services without blocking the main UI
  Future<void> _initializeNonCriticalServices() async {
    final historyService = context.read<HistoryService>();
    final emergencyService = context.read<EmergencyService>();
    final voiceService = context.read<VoiceCommandService>();
    final settingsService = context.read<SettingsService>();

    // Initialize all non-critical services in parallel
    await Future.wait([
      historyService.initialize(),
      emergencyService.initialize(),
      voiceService.initialize(),
    ]);

    // Set up voice commands
    _setupVoiceCommands(voiceService);
    
    // Set up hands-free activation (shake, volume button, etc.)
    _setupAccessibilityActivation();

    // Set emergency contact from settings
    emergencyService.setEmergencyContact(settingsService.emergencyContact);
    
    debugPrint('[Startup] Non-critical services initialized');
  }

  /// Set up hands-free voice activation for blind users
  void _setupAccessibilityActivation() {
    final activationService = context.read<AccessibilityActivationService>();
    final voiceService = context.read<VoiceCommandService>();
    final ttsService = context.read<TTSService>();
    final hapticService = context.read<HapticService>();
    
    // Initialize activation service
    activationService.initialize();
    
    // When activated, start voice recognition
    activationService.onActivate = () async {
      await hapticService.vibrateTap();
      await voiceService.startListening();
    };
    
    // Provide TTS feedback for activation
    activationService.onFeedback = (String message) {
      ttsService.speakImmediately(message);
    };
    
    // Fall detection: Ask "Are you okay?"
    activationService.onFallDetected = () {
      hapticService.vibrateEmergency();
      ttsService.askAreYouOkay();
    };
    
    // Fall confirmed (no response) - Trigger SOS
    activationService.onFallConfirmed = () async {
      ttsService.speakEmergency('No response detected. Sending emergency alert.');
      await _triggerEmergency();
    };
    
    // Fall cancelled (user is okay)
    activationService.onFallCancelled = () {
      ttsService.confirmSafe();
    };
  }

  void _setupVoiceCommands(VoiceCommandService voiceService) {
    final tts = context.read<TTSService>();
    final activationService = context.read<AccessibilityActivationService>();
    
    voiceService.onWhatsAhead = _announceCurrentDetections;
    voiceService.onStart = _startDetection;
    voiceService.onStop = _stopDetection;
    voiceService.onEmergency = _triggerEmergency;
    voiceService.onRepeat = () => tts.repeatLast();
    voiceService.onFaster = () => tts.increaseSpeed();
    voiceService.onSlower = () => tts.decreaseSpeed();
    voiceService.onLouder = () => tts.increaseVolume();
    voiceService.onQuieter = () => tts.decreaseVolume();
    voiceService.onSettings = () => Navigator.pushNamed(context, '/settings');
    
    // New: Find object command
    voiceService.onFindObject = (String objectName) => _findObject(objectName);
    
    // New: Path clear check
    voiceService.onPathClear = _announcePathStatus;
    
    // New: I'm okay response (for fall detection)
    voiceService.onImOkay = () => activationService.confirmUserOkay();
    
    // New: Read text command
    voiceService.onReadText = _readTextFromCamera;
    
    // New: Identify currency command
    voiceService.onIdentifyCurrency = _identifyCurrency;
    
    // New: Feedback for learning
    voiceService.onFeedbackPositive = () => _provideFeedback(true);
    voiceService.onFeedbackNegative = () => _provideFeedback(false);
    
    // New: Unknown command feedback
    voiceService.onUnknownCommand = (String words) {
      tts.speak("I didn't understand. Try 'what's ahead' or 'help'.");
    };
    
    // Week 2: Verbosity voice commands
    voiceService.onSetVerbosity = (String level) {
      final settings = context.read<SettingsService>();
      final VerbosityLevel verbosity;
      switch (level) {
        case 'minimal':
          verbosity = VerbosityLevel.minimal;
          break;
        case 'detailed':
          verbosity = VerbosityLevel.detailed;
          break;
        default:
          verbosity = VerbosityLevel.normal;
      }
      settings.setVerbosityLevel(verbosity);
      tts.speakImmediately('Switched to ${verbosity.displayName} mode.');
    };
    
    // Initialize learning services
    final learningService = context.read<LearningService>();
    final feedbackService = context.read<FeedbackService>();
    learningService.initialize();
    feedbackService.initialize();
    learningService.startSession();
    feedbackService.startSession();
    
    // Enable if setting is on
    final settings = context.read<SettingsService>();
    if (settings.voiceCommandsEnabled) {
      voiceService.setEnabled(true);
    }
  }
  
  /// Find a specific object in detections
  void _findObject(String objectName) {
    final tts = context.read<TTSService>();
    final lower = objectName.toLowerCase();
    
    final found = _detections.where(
      (d) => d.className.toLowerCase().contains(lower)
    ).toList();
    
    if (found.isEmpty) {
      tts.speakImmediately('$objectName not found. Try scanning around.');
    } else {
      final obj = found.first;
      tts.speakImmediately('Found $objectName, ${obj.distanceDescription}, ${obj.relativePosition?.description ?? 'ahead'}.');
    }
  }
  
  /// Announce if path is clear or blocked
  void _announcePathStatus() {
    final tts = context.read<TTSService>();
    if (_detections.isEmpty) {
      tts.speakImmediately('Path ahead is clear. You can go.');
    } else {
      final nearest = _detections.first;
      tts.speakImmediately('Path has obstacles. ${nearest.className} ${nearest.distanceDescription}.');
    }
  }
  
  /// Read text from camera using OCR
  Future<void> _readTextFromCamera() async {
    final tts = context.read<TTSService>();
    final ocrService = context.read<OcrService>();
    final cameraService = context.read<CameraService>();
    
    if (!ocrService.isInitialized) {
      await ocrService.initialize();
    }
    
    tts.speakImmediately('Scanning for text. Hold the phone steady.');
    
    // Capture current frame
    if (cameraService.controller == null) {
      tts.speakImmediately('Camera not available.');
      return;
    }
    
    try {
      // Take a picture and read text
      final image = await cameraService.controller!.takePicture();
      final text = await ocrService.recognizeFromFile(image.path);
      
      if (text.isEmpty) {
        tts.speakImmediately('No text found. Try moving the camera closer.');
      } else {
        // Format and read the text
        final formatted = ocrService.summarizeText(text);
        
        if (ocrService.isMedicineLabel(text)) {
          tts.speakImmediately('Medicine label detected. $formatted');
        } else {
          tts.speakImmediately(formatted);
        }
      }
    } catch (e) {
      debugPrint('[OCR] Error: $e');
      tts.speakImmediately('Could not read text. Please try again.');
    }
  }
  
  /// Identify Indian currency note
  Future<void> _identifyCurrency() async {
    final tts = context.read<TTSService>();
    final currencyService = context.read<CurrencyService>();
    final cameraService = context.read<CameraService>();
    
    if (!currencyService.isInitialized) {
      await currencyService.initialize();
    }
    
    tts.speakImmediately('Scanning currency note. Hold it steady.');
    
    if (cameraService.controller == null) {
      tts.speakImmediately('Camera not available.');
      return;
    }
    
    try {
      final image = await cameraService.controller!.takePicture();
      final result = await currencyService.identifyFromFile(image.path);
      
      final announcement = currencyService.getAnnouncement(result);
      tts.speakImmediately(announcement);
    } catch (e) {
      debugPrint('[Currency] Error: $e');
      tts.speakImmediately('Could not identify note. Please try again.');
    }
  }
  
  /// Provide feedback to learning system
  void _provideFeedback(bool isPositive) {
    final tts = context.read<TTSService>();
    final learningService = context.read<LearningService>();
    final feedbackService = context.read<FeedbackService>();
    
    // Get last announced object type if any
    String? lastObjectType;
    if (_detections.isNotEmpty) {
      lastObjectType = _detections.first.className;
    }
    
    // Update learning service
    learningService.provideFeedback(
      isPositive ? FeedbackType.positive : FeedbackType.negative,
      objectType: lastObjectType,
    );
    
    // Update feedback service
    feedbackService.recordImplicitFeedback(
      isPositive ? ImplicitFeedback.positive : ImplicitFeedback.tooMuch,
      context: lastObjectType,
    );
    
    // Acknowledge
    if (isPositive) {
      tts.speak('Thank you for the feedback. I\'ll remember that.');
    } else {
      tts.speak('Got it. I\'ll announce less often.');
    }
    
    debugPrint('[Learning] Feedback: positive=$isPositive, object=$lastObjectType');
  }

  void _announceCurrentDetections() {
    final tts = context.read<TTSService>();
    if (_detections.isEmpty) {
      tts.speakImmediately('Path ahead is clear.');
    } else {
      // Announce only top 2, in calm format
      final desc = _detections.take(2).map((d) => 
        '${d.className}, ${d.distanceDescription}'
      ).join('. ');
      tts.speakImmediately(desc);
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
        // Week 2: Play earcon for path clear
        context.read<EarconService>().playPathClear();
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
    final cameraService = context.read<CameraService>();
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

      // Notify camera service for battery optimization
      cameraService.notifyDetectionResult(detections.length);

      // Sort by navigation mode priority (Feature 18)
      // Priority objects come first, but ALL objects are kept
      detections.sort((a, b) {
        final aPriority = settings.navigationMode.isRelevant(a.className) ? 0 : 1;
        final bPriority = settings.navigationMode.isRelevant(b.className) ? 0 : 1;
        return aPriority.compareTo(bPriority);
      });

      // Calculate risks
      final risks = _riskCalculator.calculateForAll(
        detections,
        frameWidth: image.width,
      );

      setState(() {
        _detections = detections;
        _risks = risks;
        _statusMessage = 'Detecting: ${detections.length} objects | ${onnxService.lastInferenceMs}ms | FPS: $_fps';
      });

      if (detections.isNotEmpty) {
        _lastDetectionTime = now;
        
        // Log to history (Feature 20)
        await historyService.logDetections(detections);

        // Use tracking to find NEW detections (Feature 3)
        final newDetections = trackingService.updateTrackers(detections);

        // Announce and vibrate for new detections (Week 2: with verbosity)
        final verbosity = settings.verbosityLevel;
        
        // Week 2: Group detections to reduce noise
        final grouped = trackingService.groupDetections(newDetections);

        for (final detection in grouped.take(2)) {
          // Haptic with proximity (Feature 9)
          if (settings.vibrationEnabled) {
            await hapticService.vibrateForDetection(detection);
          }

          // Week 2: Earcon for spatial audio cue
          final earconService = context.read<EarconService>();
          await earconService.playForDetection(detection);

          // TTS with priority and verbosity (Feature 4 + Week 2)
          await ttsService.speakDetectionWithVerbosity(detection, verbosity);
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
    final activationService = context.watch<AccessibilityActivationService>();
    
    return GestureDetector(
      // Feature: Double-tap anywhere to ask "what's ahead"
      onDoubleTap: () {
        activationService.onDoubleTap();
        _announceCurrentDetections();
      },
      // Feature: Long-press anywhere to start voice commands
      onLongPress: () {
        activationService.onLongPress();
      },
      child: Scaffold(
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
              const SizedBox(width: 12),
              // Voice command microphone button
              Expanded(
                child: Semantics(
                  button: true,
                  label: 'Voice commands',
                  child: Consumer<VoiceCommandService>(
                    builder: (context, voiceService, _) => SizedBox(
                      height: 80,
                      child: ElevatedButton(
                        onPressed: voiceService.isInitialized 
                            ? () => voiceService.toggleListening()
                            : null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: voiceService.isListening 
                              ? Colors.green 
                              : null,
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              voiceService.isListening 
                                  ? Icons.mic 
                                  : Icons.mic_none,
                              size: 28,
                            ),
                            const SizedBox(height: 4),
                            Text(voiceService.isListening ? 'Listening' : 'Voice'),
                          ],
                        ),
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
