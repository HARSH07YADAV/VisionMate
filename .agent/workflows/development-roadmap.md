---
description: VisionMate weekly development roadmap – what's done and what's next to improve performance and usability for blind users
---

# VisionMate Development Roadmap

> **Current Date**: February 2026  
> **Goal**: Make VisionMate fast, reliable, and effortless for blind users

---

## ✅ What Has Been Done (Completed Features)

| # | Feature | Key Files |
|---|---------|-----------|
| 1 | **YOLOv8n Object Detection** – Real-time obstacle recognition (80 COCO classes) via ONNX Runtime | `onnx_service.dart`, `detection.dart` |
| 2 | **Text-to-Speech Guidance** – Natural, calm audio announcements with spatial cues (left/right/ahead) | `tts_service.dart` |
| 3 | **Risk Calculator** – Distance estimation in human terms ("two steps ahead"), danger-level scoring | `risk_calculator.dart` |
| 4 | **Haptic Feedback** – Proximity-based vibration patterns for danger levels | `haptic_service.dart` |
| 5 | **Voice Commands** – "What's ahead", "Find the door", "Read this", "What note is this" | `voice_command_service.dart` |
| 6 | **Navigation Guidance** – Zone-based obstacle analysis → directional advice (move left/right/back) | `navigation_guidance_service.dart` |
| 7 | **Emergency SOS** – GPS location sharing via SMS, emergency calling | `emergency_service.dart` |
| 8 | **OCR Text Reading** – Read signs, labels from camera using Google ML Kit | `ocr_service.dart` |
| 9 | **Currency Identification** – Indian Rupee note recognition | `currency_service.dart` |
| 10 | **On-Device Q-Learning** – Adaptive announcement timing from user feedback | `learning_service.dart`, `feedback_service.dart` |
| 11 | **Accessibility Activation** – Shake, volume-button, double-tap to start hands-free | `accessibility_activation_service.dart` |
| 12 | **High Contrast Mode** – Large fonts, yellow-on-black theme | `main.dart` |
| 13 | **Large Touch Buttons** – 80-100px targets with Semantics labels | `home_screen.dart` |
| 14 | **Detection History** – SQLite logging of past detections | `history_service.dart` |
| 15 | **Settings Persistence** – Shared preferences for user preferences | `settings_service.dart` |
| 16 | **Context Service** – Scene-level understanding of environment | `context_service.dart` |
| 17 | **Background Service** – Continues running when app is minimised | `background_service.dart` |
| 18 | **Object Tracking** – Track previously seen objects to reduce repeat alerts | `tracking_service.dart` |
| 19 | **Always-on Wake Word** – Continuous "Hey Vision" detection via short-burst listening loop | `wake_word_service.dart` |
| 20 | **Expanded Voice Commands** – "How far?", "Describe scene", "Navigate to exit", "Battery status", "Indoors/outdoors?" | `voice_command_service.dart` |
| 21 | **Conversational Flow** – Context-aware follow-ups with yes/no handling (10s conversation window) | `conversation_flow_service.dart` |
| 22 | **Hindi Language Support** – Hindi voice commands + TTS, language toggle in settings | `voice_command_service.dart`, `tts_service.dart`, `settings_service.dart` |
| 23 | **Voice-Based Settings** – High contrast, language switch, vibration toggle — all via voice | `voice_command_service.dart`, `home_screen.dart` |

---

## 🗓️ Weekly Improvement Plan

---

### ✅ Week 1 — Performance & Speed Optimization (COMPLETED)

> **Theme**: Make the app lightning-fast so blind users get instant feedback

| Day | Task | Details | Status |
|-----|------|---------|--------|
| Day 1-2 | **Reduce inference latency** | Throttle reduced 1500ms→200ms, ONNX threads 2→4, compute isolate for preprocessing, stride-based pixel sampling | ✅ Done |
| Day 3 | **Frame pipeline tuning** | Adaptive FPS 2-8 based on accelerometer motion state (stationary/moving/walking) | ✅ Done |
| Day 4 | **Memory optimization** | Preprocessing offloaded to compute isolate (separate memory), NMS capped at 50 candidates with top-10 early exit | ✅ Done |
| Day 5 | **Reduce app startup time** | Two-phase init: critical services (Camera, ONNX, TTS, Haptic) load in parallel via `Future.wait`, non-critical load in background | ✅ Done |
| Day 6-7 | **Battery optimization** | Accelerometer-based pocket detection auto-pauses camera, idle frames → 1 FPS, motion-aware FPS adapts automatically | ✅ Done |

**Deliverable**: App responds within 200ms of detecting an obstacle ✅

---

### ✅ Week 2 — Audio & Speech Improvements (COMPLETED)

> **Theme**: Make announcements feel like a trusted friend, not a robot

| Day | Task | Details | Status |
|-----|------|---------|--------|
| Day 1 | **Smart announcement deduplication** | Priority-based cooldowns (2s critical → 8s low), object grouping (3+ objects → "N objects ahead") in `tracking_service.dart` | ✅ Done |
| Day 2-3 | **Priority-based speech queue** | Max 5 entries, stale message pruning (>3s), duplicate dedup, verbosity-aware announcements in `tts_service.dart` | ✅ Done |
| Day 4 | **Earcon / sound effects** | New `earcon_service.dart` with path clear chime, danger beep, object ping via `audioplayers` | ✅ Done |
| Day 5 | **Spatial audio** | Stereo panning via `setBalance()` – left objects → -0.8, right → +0.8 in `earcon_service.dart` | ✅ Done |
| Day 6-7 | **Customizable verbosity levels** | `VerbosityLevel` enum (Minimal/Normal/Detailed) in `settings_service.dart`, 3-button selector in `settings_screen.dart`, voice commands "less talk"/"more detail" | ✅ Done |

**Deliverable**: User hears only what matters, in the right priority, at the right volume ✅

---

### ✅ Week 3 — Voice Command & Hands-Free Upgrades (COMPLETED)

> **Theme**: Blind users should never need to touch the screen

| Day | Task | Details | Status |
|-----|------|---------|--------|
| Day 1-2 | **Always-on voice activation** | New `wake_word_service.dart` with continuous "Hey Vision" detection via short-burst `speech_to_text` listening loop. Auto-restart, battery-aware, pauses during active commands | ✅ Done |
| Day 3 | **Expand command vocabulary** | 5 new commands: "How far is [object]?", "Am I indoors or outdoors?", "Describe the scene", "Navigate to exit", "Battery status". Added `battery_plus` package | ✅ Done |
| Day 4 | **Conversational flow** | New `conversation_flow_service.dart` with context-aware follow-ups. 10s conversation window, yes/no handling, auto-offers guidance after find/describe/navigate commands | ✅ Done |
| Day 5 | **Multi-language support** | Hindi voice commands + TTS via `AppLanguage` enum in settings. Language toggle in settings screen, `setLanguage()` in TTS, locale-aware speech recognition | ✅ Done |
| Day 6-7 | **Voice-based settings** | "High contrast on/off", "Switch to Hindi/English", "Vibration on/off" — all controllable by voice. TTS confirmations for all setting changes | ✅ Done |

**Deliverable**: Full app control via voice, zero screen touches required ✅

---

### Week 4 — Smarter Detection & Navigation

> **Theme**: Understand the environment like a sighted companion

| Day | Task | Details |
|-----|------|---------|
| Day 1-2 | **Depth estimation** | Add monocular depth estimation (MiDaS ONNX model) for accurate distance measurement instead of bounding-box heuristics. "Person is exactly 3 meters ahead" |
| Day 3 | **Scene classification** | Classify environments: indoor (home, office, mall), outdoor (road, park, crossing). Adjust announcement style per scene |
| Day 4 | **Crosswalk & traffic light detection** | Add pedestrian signal detection – "Red light, wait" / "Green signal, safe to cross". Critical for road safety |
| Day 5-6 | **Landmark recognition** | Recognize doors, stairs (improved), elevators, signboards. "You're approaching an elevator on your right" |
| Day 7 | **Path memory** | Remember frequently walked paths. "You're on your usual route to the kitchen. Chair is still on the left" |

**Deliverable**: Context-aware detection that understands indoor/outdoor, traffic, and familiar places  

---

### Week 5 — Safety & Emergency Enhancements

> **Theme**: Never let the user feel unsafe or alone

| Day | Task | Details |
|-----|------|---------|
| Day 1-2 | **Improved fall detection** | Use accelerometer + gyroscope fusion for accurate fall detection. Reduce false positives. 30-second auto-SOS countdown with voice cancel |
| Day 3 | **Multiple emergency contacts** | Support up to 5 contacts in `emergency_service.dart`. Send SOS to all simultaneously. Add emergency contact management by voice |
| Day 4 | **Live location sharing** | Continuous location sharing with caregiver during walks. Caregiver gets a web link with live map. Auto-start when leaving home |
| Day 5 | **Collision warning system** | Predict object trajectory using tracking data. "Moving object approaching from the left!" – warn 2-3 seconds before collision |
| Day 6-7 | **Offline mode** | Ensure core detection + TTS + haptic works 100% offline. No data connection required for basic safety features. Cache ML models on first run |

**Deliverable**: User is safe even in worst-case scenarios – falls, moving obstacles, no internet  

---

### Week 6 — Accessibility & Onboarding Polish

> **Theme**: A new blind user should feel confident within 5 minutes

| Day | Task | Details |
|-----|------|---------|
| Day 1-2 | **Guided onboarding tour** | Audio-guided first-time setup: introduce each feature, walk through voice commands, set emergency contacts. No visual UI needed – purely voice-driven |
| Day 3 | **Tutorial mode** | Practice mode where user can explore a room and learn app responses. "Try walking towards a chair." Builds confidence before real use |
| Day 4 | **Accessibility audit** | Full TalkBack/Screen Reader compatibility test. Ensure every button has proper Semantics labels. Fix any focus order issues |
| Day 5 | **Personalization wizard** | Voice-guided setup: preferred speech speed, verbosity level, feedback sensitivity, emergency contacts, beginner/advanced mode |
| Day 6-7 | **Simplified home screen** | For first-time users: just 3 giant buttons – Start (full screen), SOS (red), and Settings (gear). Advanced controls hidden until user asks "More options" |

**Deliverable**: Any blind user can install, set up, and start using the app in under 5 minutes, entirely by voice  

---

### Week 7 — Testing, QA & Real User Feedback

> **Theme**: Validate everything with actual blind users

| Day | Task | Details |
|-----|------|---------|
| Day 1-2 | **Unit & integration tests** | Write tests for all services. Target > 80% coverage. Test edge cases: no camera, no internet, low battery, multiple simultaneous detections |
| Day 3 | **Real-device testing** | Test on 5+ Android devices (budget to flagship). Verify performance across different chipsets. Fix device-specific issues |
| Day 4-5 | **Blind user testing session** | Recruit 3-5 visually impaired testers. Observe them using the app in real-world settings. Document pain points, confusion, and feature requests |
| Day 6 | **Feedback analysis** | Categorize feedback into: critical bugs, UX improvements, feature requests. Prioritize for Week 8 |
| Day 7 | **Bug fix sprint** | Fix all critical bugs found during testing. Polish based on user feedback |

**Deliverable**: Validated, battle-tested app with real user feedback incorporated  

---

### Week 8 — Advanced Features & Launch Prep

> **Theme**: Final polish and standout features

| Day | Task | Details |
|-----|------|---------|
| Day 1-2 | **Face recognition (opt-in)** | Recognize familiar faces: "Your friend Rahul is approaching." User enrolls faces with voice labels. Privacy-first: all on-device |
| Day 3 | **Indoor navigation** | BLE beacon support for indoor navigation in malls/offices. "Turn right in 5 steps to reach the restroom" |
| Day 4 | **Daily summary** | End-of-day voice report: "Today you walked 2 km, detected 47 objects, had 0 near-collisions." Gamification for caregivers |
| Day 5 | **Play Store optimization** | App description, screenshots (for sighted helpers who install for blind users), accessibility badges, privacy policy |
| Day 6 | **Performance final check** | Full benchmark: startup < 3s, detection < 100ms, battery impact < 15%/hr, crash-free rate > 99.5% |
| Day 7 | **Release candidate** | Final build, version tag, release notes. Share with beta testers before public launch |

**Deliverable**: Production-ready app on Google Play Store  

---

## 📊 Success Metrics

| Metric | Target |
|--------|--------|
| Detection latency | < 100ms per frame |
| App startup | < 3 seconds to active detection |
| Battery usage | < 15% per hour of active use |
| Voice command accuracy | > 90% correct recognition |
| Announcement usefulness | > 80% rated helpful by Q-learning |
| False alarm rate | < 5% of announcements |
| User onboarding time | < 5 minutes to first successful use |
| Crash-free rate | > 99.5% |

---

## 🔧 How to Use This Workflow

1. **Start each week** by reviewing the theme and tasks
2. **Update progress** by checking off completed tasks
3. **Adjust timelines** based on actual testing results
4. **Prioritize safety features** (Weeks 4-5) if any week is cut short
5. **Always test with real blind users** – their feedback overrides assumptions
