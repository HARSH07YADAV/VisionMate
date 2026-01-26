# BlindAssist - AI Navigation for Visually Impaired

An AI-powered obstacle detection and navigation assistance app for visually impaired users, built with Flutter and YOLOv8.

![Flutter](https://img.shields.io/badge/Flutter-3.0+-blue.svg)
![Platform](https://img.shields.io/badge/Platform-Android-green.svg)
![License](https://img.shields.io/badge/License-MIT-yellow.svg)

## Features

### 🎯 Object Detection
- Real-time obstacle detection using YOLOv8n ONNX model
- 80 object class recognition (COCO dataset)
- Distance estimation based on object size
- Stairs detection using edge heuristics

### 🔊 Audio Guidance
- Priority-based text-to-speech announcements
- Spatial audio hints (left/right/ahead)
- Customizable speech rate and volume
- Directional navigation guidance ("Move left!", "Go back!")
- Path clear notifications

### 📳 Haptic Feedback
- Proximity-based vibration intensity
- Different patterns for danger levels (critical/high/medium/low)
- Emergency vibration patterns

### 🆘 Safety Features
- Emergency SOS button with GPS location
- Sends SMS to emergency contact
- Detection history logging
- Indoor/Outdoor navigation modes

### ♿ Accessibility
- Large touch buttons (80-100px)
- Screen reader support (Semantics)
- High contrast mode
- Voice commands (stub - requires speech_to_text package fix)

## Screenshots

| Home Screen | Settings | Detection |
|-------------|----------|-----------|
| Large buttons, SOS | Customization | Bounding boxes overlay |

## Installation

### Prerequisites
- Flutter SDK 3.0+
- Android device with camera
- YOLOv8n ONNX model file

### Steps

1. **Clone the repository**
   ```bash
   git clone https://github.com/YOUR_USERNAME/blind-assist-nav.git
   cd blind-assist-nav/flutter_app
   ```

2. **Get dependencies**
   ```bash
   flutter pub get
   ```

3. **Run the app**
   ```bash
   flutter run --release
   ```

## Project Structure

```
flutter_app/
├── lib/
│   ├── main.dart              # App entry point
│   ├── core/
│   │   └── risk_calculator.dart
│   ├── models/
│   │   └── detection.dart
│   ├── screens/
│   │   ├── home_screen.dart   # Main detection screen
│   │   ├── settings_screen.dart
│   │   └── history_screen.dart
│   ├── services/
│   │   ├── camera_service.dart
│   │   ├── onnx_service.dart
│   │   ├── tts_service.dart
│   │   ├── haptic_service.dart
│   │   ├── settings_service.dart
│   │   ├── history_service.dart
│   │   ├── emergency_service.dart
│   │   ├── tracking_service.dart
│   │   └── navigation_guidance_service.dart
│   └── widgets/
│       └── detection_overlay.dart
├── assets/
│   └── models/
│       ├── yolov8n.onnx      # YOLO model (not included)
│       └── labels.txt        # COCO class labels
└── android/
    └── app/src/main/AndroidManifest.xml
```

## Permissions Required

- Camera - for object detection
- Vibrate - for haptic feedback
- Location - for emergency SOS
- SMS - for emergency contact
- Microphone - for voice commands (optional)

## How It Works

1. **Camera Feed** → Captures frames at 4 FPS (low resolution for performance)
2. **YOLOv8 Inference** → Detects objects using ONNX Runtime
3. **Risk Analysis** → Calculates danger level based on distance and object type
4. **Navigation Guidance** → Analyzes left/center/right zones for safest path
5. **TTS + Haptic** → Announces and vibrates based on urgency

## Configuration

| Setting | Description | Default |
|---------|-------------|---------|
| Speech Rate | TTS speed (0.1-1.0) | 0.5 |
| Path Clear Interval | Seconds between "path clear" | 5 |
| Navigation Mode | Indoor/Outdoor filtering | Indoor |
| High Contrast | Yellow on black theme | Off |
| Emergency Contact | Phone number for SOS | Not set |

## Known Issues

- **Voice Commands**: speech_to_text package has compatibility issues with newer AGP
- **Multi-scale Detection**: YOLOv8n requires fixed 640x640 input

## Contributing

1. Fork the repository
2. Create feature branch (`git checkout -b feature/amazing-feature`)
3. Commit changes (`git commit -m 'Add amazing feature'`)
4. Push to branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Acknowledgments

- [YOLOv8](https://github.com/ultralytics/ultralytics) - Object detection model
- [Flutter](https://flutter.dev) - Cross-platform framework
- [ONNX Runtime](https://onnxruntime.ai) - ML inference engine
