# VisionMate – Smart Navigation for the Blind

An AI-powered obstacle detection and navigation assistance app for visually impaired users, built with Flutter, YOLOv8 and on-device Reinforcement Learning.

![Flutter](https://img.shields.io/badge/Flutter-3.0+-blue.svg)
![Platform](https://img.shields.io/badge/Platform-Android-green.svg)
![License](https://img.shields.io/badge/License-MIT-yellow.svg)

## Features

### 🎯 Object Detection
- Real-time obstacle detection using YOLOv8n ONNX model
- 80 object class recognition (COCO dataset)
- Distance estimation in human terms ("two steps ahead")
- Stairs detection using edge heuristics

### 🔊 Audio Guidance
- Calm, natural TTS announcements with emotional support
- Confidence-aware speech ("I think I see...")
- Spatial audio hints (left/right/ahead)
- Customizable speech rate and volume
- Path clear notifications

### 🧠 Reinforcement Learning
- On-device Q-Learning agent
- Learns optimal announcement timing from feedback
- Object preference learning (which obstacles matter to you)
- Epsilon-greedy exploration → exploitation over time
- Persistent Q-table across sessions

### 🗣️ Voice Commands
- Natural language understanding
- "What's ahead", "Find the door", "Help me"
- "Read this" – OCR text reading
- "What note is this" – Currency identification (₹)
- "Thanks" / "Too much" – Feedback for learning

### 📳 Haptic Feedback
- Proximity-based vibration intensity
- Different patterns for danger levels (critical/high/medium/low)
- Emergency vibration patterns

### 🆘 Safety Features
- Emergency SOS with GPS location
- Fall detection with auto-SOS (30s countdown)
- "I'm okay" voice cancellation
- Sends SMS to emergency contact
- Detection history logging

### ♿ Accessibility
- Large touch buttons (80-100px)
- Screen reader support (Semantics)
- High contrast mode
- Hands-free activation (shake, volume button, double-tap)
- Beginner / Advanced personalization modes

## Installation

### Prerequisites
- Flutter SDK 3.0+
- Android device with camera
- YOLOv8n ONNX model file

### Steps

1. **Clone the repository**
   ```bash
   git clone https://github.com/HARSH07YADAV/Blind-Assist-Nav.git
   cd Blind-Assist-Nav/flutter_app
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
│   ├── main.dart
│   ├── core/
│   │   └── risk_calculator.dart
│   ├── models/
│   │   └── detection.dart
│   ├── screens/
│   │   ├── home_screen.dart
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
│   │   ├── voice_command_service.dart
│   │   ├── tracking_service.dart
│   │   ├── navigation_guidance_service.dart
│   │   ├── accessibility_activation_service.dart
│   │   ├── ocr_service.dart
│   │   ├── context_service.dart
│   │   ├── currency_service.dart
│   │   ├── learning_service.dart       # Q-Learning agent
│   │   └── feedback_service.dart       # Preference learning
│   └── widgets/
│       └── detection_overlay.dart
├── assets/
│   └── models/
│       ├── yolov8n.onnx
│       └── labels.txt
└── android/
    └── app/src/main/AndroidManifest.xml
```

## How It Works

1. **Camera Feed** → Captures frames at 4 FPS
2. **YOLOv8 Inference** → Detects objects using ONNX Runtime
3. **Risk Analysis** → Calculates danger based on distance and type
4. **Q-Learning Decision** → Should I announce? Calm or urgent?
5. **TTS + Haptic** → Announces and vibrates based on urgency
6. **User Feedback** → "Thanks" or "Too much" updates Q-table

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Acknowledgments

- [YOLOv8](https://github.com/ultralytics/ultralytics) - Object detection model
- [Flutter](https://flutter.dev) - Cross-platform framework
- [ONNX Runtime](https://onnxruntime.ai) - ML inference engine
