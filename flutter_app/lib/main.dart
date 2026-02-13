import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:permission_handler/permission_handler.dart';

import 'services/camera_service.dart';
import 'services/onnx_service.dart';
import 'services/tts_service.dart';
import 'services/haptic_service.dart';
import 'services/settings_service.dart';
import 'services/history_service.dart';
import 'services/emergency_service.dart';
import 'services/voice_command_service.dart';
import 'services/tracking_service.dart';
import 'services/background_service.dart';
import 'services/navigation_guidance_service.dart';
import 'services/accessibility_activation_service.dart';
import 'services/ocr_service.dart';
import 'services/context_service.dart';
import 'services/currency_service.dart';
import 'services/learning_service.dart';
import 'services/feedback_service.dart';
import 'services/earcon_service.dart';
import 'services/wake_word_service.dart';
import 'services/conversation_flow_service.dart';
import 'screens/home_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/history_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Lock to portrait mode
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
  ]);
  
  runApp(const VisionMateApp());
}

class VisionMateApp extends StatelessWidget {
  const VisionMateApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => SettingsService()),
        ChangeNotifierProvider(create: (_) => CameraService()),
        ChangeNotifierProvider(create: (_) => OnnxService()),
        ChangeNotifierProvider(create: (_) => TTSService()),
        ChangeNotifierProvider(create: (_) => HapticService()),
        ChangeNotifierProvider(create: (_) => HistoryService()),
        ChangeNotifierProvider(create: (_) => EmergencyService()),
        ChangeNotifierProvider(create: (_) => VoiceCommandService()),
        ChangeNotifierProvider(create: (_) => TrackingService()),
        ChangeNotifierProvider(create: (_) => BackgroundService()),
        ChangeNotifierProvider(create: (_) => NavigationGuidanceService()),
        ChangeNotifierProvider(create: (_) => AccessibilityActivationService()),
        ChangeNotifierProvider(create: (_) => OcrService()),
        ChangeNotifierProvider(create: (_) => ContextService()),
        ChangeNotifierProvider(create: (_) => CurrencyService()),
        ChangeNotifierProvider(create: (_) => LearningService()),
        ChangeNotifierProvider(create: (_) => FeedbackService()),
        ChangeNotifierProvider(create: (_) => EarconService()),
        ChangeNotifierProvider(create: (_) => WakeWordService()),
        ChangeNotifierProvider(create: (_) => ConversationFlowService()),
      ],
      child: Consumer<SettingsService>(
        builder: (context, settings, _) {
          return MaterialApp(
            title: 'VisionMate',
            debugShowCheckedModeBanner: false,
            theme: settings.highContrast 
              ? _highContrastTheme()
              : _defaultTheme(),
            home: const PermissionWrapper(),
            routes: {
              '/settings': (context) => const SettingsScreen(),
              '/history': (context) => const HistoryScreen(),
            },
          );
        },
      ),
    );
  }

  ThemeData _defaultTheme() {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: Colors.blue,
        brightness: Brightness.dark,
      ),
    );
  }

  ThemeData _highContrastTheme() {
    return ThemeData(
      useMaterial3: true,
      colorScheme: const ColorScheme.dark(
        primary: Colors.yellow,
        onPrimary: Colors.black,
        secondary: Colors.cyan,
        onSecondary: Colors.black,
        surface: Colors.black,
        onSurface: Colors.white,
        error: Colors.red,
        onError: Colors.white,
      ),
      textTheme: const TextTheme(
        bodyLarge: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        bodyMedium: TextStyle(fontSize: 18),
        titleLarge: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
      ),
    );
  }
}

/// Handles permission requests before showing main screen
class PermissionWrapper extends StatefulWidget {
  const PermissionWrapper({super.key});

  @override
  State<PermissionWrapper> createState() => _PermissionWrapperState();
}

class _PermissionWrapperState extends State<PermissionWrapper> {
  bool _permissionsGranted = false;
  bool _checking = true;

  @override
  void initState() {
    super.initState();
    _checkPermissions();
  }

  Future<void> _checkPermissions() async {
    // Request all needed permissions
    final statuses = await [
      Permission.camera,
      Permission.microphone,
      Permission.location,
    ].request();
    
    final cameraGranted = statuses[Permission.camera]?.isGranted ?? false;
    
    setState(() {
      _permissionsGranted = cameraGranted;
      _checking = false;
    });
    
    if (_permissionsGranted) {
      // Initialize settings
      if (mounted) {
        await context.read<SettingsService>().initialize();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_checking) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 16),
              Text(
                'Initializing...',
                style: Theme.of(context).textTheme.bodyLarge,
              ),
            ],
          ),
        ),
      );
    }

    if (!_permissionsGranted) {
      return Scaffold(
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(32.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.camera_alt, size: 100, color: Colors.grey),
                const SizedBox(height: 32),
                Text(
                  'Camera Permission Required',
                  style: Theme.of(context).textTheme.titleLarge,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                Text(
                  'VisionMate needs camera access to detect obstacles and help you navigate safely.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 48),
                // Large accessible button
                SizedBox(
                  width: double.infinity,
                  height: 80,
                  child: ElevatedButton.icon(
                    onPressed: _checkPermissions,
                    icon: const Icon(Icons.check, size: 32),
                    label: const Text(
                      'Grant Permission',
                      style: TextStyle(fontSize: 20),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return const HomeScreen();
  }
}
