# 📱 How to Run BlindAssist Flutter App on Your Android Phone

## Complete Step-by-Step Guide (USB Connected)

---

## STEP 1: Install Flutter

### On Windows:
```powershell
# Download Flutter SDK from https://flutter.dev/docs/get-started/install/windows
# Extract to C:\flutter
# Add C:\flutter\bin to PATH

# Or using Chocolatey:
choco install flutter
```

### On Linux:
```bash
# Using snap (easiest)
sudo snap install flutter --classic

# Verify installation
flutter doctor
```

### On macOS:
```bash
# Using Homebrew
brew install flutter

# Verify
flutter doctor
```

---

## STEP 2: Enable USB Debugging on Your Android Phone

1. **Open Settings** → **About Phone**
2. **Tap "Build Number" 7 times** (enables Developer Options)
3. Go back to **Settings** → **Developer Options**
4. **Enable "USB Debugging"**
5. **Enable "Install via USB"** (if available)

---

## STEP 3: Connect Your Phone via USB

1. Connect your Android phone to your computer with a **USB cable**
2. On your phone, when prompted, select **"Allow USB debugging"**
3. Check "Always allow from this computer"
4. Tap **OK**

### Verify Connection:
```bash
flutter devices
```

You should see your phone listed like:
```
ASUS_I006D (mobile) • R9AX10... • android-arm64 • Android 13
```

---

## STEP 4: Navigate to Flutter Project

```bash
cd /home/anchorpoint/.gemini/antigravity/scratch/blind-assist-nav/flutter_app
```

---

## STEP 5: Get Dependencies

```bash
flutter pub get
```

This downloads all required packages (camera, tflite, tts, etc.)

---

## STEP 6: Download TFLite Model

You need a YOLOv8 TFLite model. Options:

### Option A: Download pre-converted (Recommended)
```bash
# Download yolov8n.tflite from Ultralytics releases
# Place it in: flutter_app/assets/models/yolov8n.tflite
```

### Option B: Convert yourself (requires Python)
```bash
pip install ultralytics

python -c "
from ultralytics import YOLO
model = YOLO('yolov8n.pt')
model.export(format='tflite')
"

# Copy the generated yolov8n.tflite to flutter_app/assets/models/
```

---

## STEP 7: Run the App

### Run on connected phone:
```bash
flutter run
```

### Or specify device:
```bash
# List devices
flutter devices

# Run on specific device
flutter run -d <device_id>
```

---

## STEP 8: Grant Permissions

When the app opens on your phone:
1. **Grant Camera permission** when prompted
2. The app will say "BlindAssist ready"
3. Tap the **START DETECTION** button
4. Point your phone's camera forward

---

## 🎉 App Features

| Feature | Description |
|---------|-------------|
| 📷 Real-time Detection | Detects obstacles using camera |
| 🔊 Voice Feedback | Speaks warnings ("Stop! Stairs ahead!") |
| 📳 Haptic Feedback | Vibrates for different risk levels |
| 🔦 Flashlight Toggle | Works in low light |
| 🎯 Risk Levels | Color-coded: Red=Critical, Orange=High |

---

## Troubleshooting

### "No devices found"
```bash
# Check USB connection
adb devices

# If empty, reinstall ADB drivers or try different USB port
```

### "flutter: command not found"
```bash
# Add Flutter to PATH
export PATH="$PATH:/path/to/flutter/bin"
```

### "Gradle build failed"
```bash
# Clean and rebuild
flutter clean
flutter pub get
flutter run
```

### "Permission denied"
- Go to phone Settings → Apps → BlindAssist → Permissions
- Enable Camera permission manually

### App crashes on launch
- Check logcat for errors:
```bash
flutter logs
```

---

## Build APK for Installation

```bash
# Debug APK (for testing)
flutter build apk --debug

# Release APK (optimized, smaller)
flutter build apk --release

# APK location:
# build/app/outputs/flutter-apk/app-release.apk
```

Transfer APK to phone and install manually if needed.

---

## Quick Reference Commands

| Command | Purpose |
|---------|---------|
| `flutter doctor` | Check Flutter setup |
| `flutter devices` | List connected devices |
| `flutter run` | Run app on device |
| `flutter run -d <id>` | Run on specific device |
| `flutter build apk` | Build APK file |
| `flutter logs` | View device logs |
| `flutter clean` | Clean build cache |

---

## Project Location

```
/home/anchorpoint/.gemini/antigravity/scratch/blind-assist-nav/flutter_app/
```

## Files Structure

```
flutter_app/
├── lib/
│   ├── main.dart              # App entry point
│   ├── models/
│   │   └── detection.dart     # Detection models
│   ├── services/
│   │   ├── camera_service.dart
│   │   ├── tflite_service.dart
│   │   ├── tts_service.dart
│   │   └── haptic_service.dart
│   ├── screens/
│   │   └── home_screen.dart   # Main UI
│   ├── core/
│   │   └── risk_calculator.dart
│   └── widgets/
│       └── detection_overlay.dart
├── assets/
│   └── models/
│       ├── yolov8n.tflite     # (you need to add this)
│       └── labels.txt
└── pubspec.yaml
```
