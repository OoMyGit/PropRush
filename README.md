# Prop Call

A multiplayer AR party game for iOS that blends object detection and voice input: find a real-world prop that starts with a given letter, say it out loud, and score points. Built with Swift, SwiftUI, RealityKit, CoreML/Vision and MultipeerConnectivity.

---

## Project Overview

Prop Call is an AR-based, turn-based multiplayer game. Each round, players look for an object in the real world that starts with a target letter. The app uses a CoreML object detector (YOLOv8n) to identify objects and speech recognition to capture players' guesses. Multiplayer sync and simple lobby/host logic are handled via MultipeerConnectivity.

Key entry points:
- App entry: [`Prop_CallApp`](Prop Call/Prop Call/Prop_CallApp.swift)  
- Main UI: [`ARVoiceIntentView`](Prop Call/Prop Call/ContentView.swift)  
- Multiplayer: [`MultipeerManager`](Prop Call/Prop Call/MultipeerManager.swift)  
- Round & timer logic: [`GameRoundManager`](Prop Call/Prop Call/GameRoundManager.swift)  
- Speech: [`SpeechRecognizer`](Prop Call/Prop Call/SpeechRecognizer.swift)  
- Object detection: [`VisionObjectDetector`](Prop Call/Prop Call/VisionObjectDetector.swift)  
- AR capture & rendering: [`ARCoordinator`](Prop Call/Prop Call/ARCoordinator.swift) & [`ARViewContainer`](Prop Call/Prop Call/ARViewContainer.swift)

---

## Features

- AR camera feed with periodic frame capture for object detection.  
- Real-time object classification using a local CoreML model (YOLOv8n). See [`YOLOv8n.mlpackage`](Prop Call/Prop Call/YOLOv8n.mlpackage).  
- On-device speech recognition for player answers: [`SpeechRecognizer`](Prop Call/Prop Call/SpeechRecognizer.swift).  
- Turn-based rounds, timers, and scoring: [`GameRoundManager`](Prop Call/Prop Call/GameRoundManager.swift).  
- Local peer-to-peer multiplayer lobby, score sync, host/guest roles, and game events over MultipeerConnectivity: [`MultipeerManager`](Prop Call/Prop Call/MultipeerManager.swift).  
- Simple UI with SwiftUI and RealityKit integration: [`ARVoiceIntentView`](Prop Call/Prop Call/ContentView.swift), [`ARViewContainer`](Prop Call/Prop Call/ARViewContainer.swift).  
- Asset catalog included: [Assets.xcassets](Prop Call/Prop Call/Assets.xcassets).

---

## Tech Stack

- Language: Swift (SwiftUI)  
- AR: ARKit, RealityKit (`ARCoordinator`, `ARViewContainer`)  
- Machine Learning: CoreML, Vision (`VisionObjectDetector`)  
- Speech: Speech framework + AVAudioSession (`SpeechRecognizer`)  
- Networking: MultipeerConnectivity (`MultipeerManager`)  
- Reactive/async: Combine (Publishers in `MultipeerManager`)  
- Minimum UI: SwiftUI (`ContentView` / `ARVoiceIntentView`)

---

## Requirements

- macOS with Xcode 15+ (recommended)  
- iOS 16.0+ (device with ARKit support required for AR features)  
- A real iOS device for AR, camera and speech (simulator lacks full AR + microphone capabilities)  
- Microphone & Camera permissions granted (see Configuration below)  
- CoreML model included: [`YOLOv8n.mlpackage`](Prop Call/Prop Call/YOLOv8n.mlpackage)

---

## Installation

1. Clone the repo:
   ```sh
   git clone <repo-url>
   ```
2. Open the project in Xcode:
   - Open the project file: `Prop Call/Prop Call.xcodeproj` or workspace if present.
3. Select a connected iOS device (required) and update Team / Signing in the project settings.
4. Ensure the `YOLOv8n.mlpackage` is included in the target (it is already in `Prop Call/Prop Call/`).  
5. Build & run.

Quick run:
- Open `[Prop_CallApp](Prop Call/Prop Call/Prop_CallApp.swift)` and run the app on your device.

---

## Project Structure

Top-level:
- Prop Call/Prop-Call-Info.plist
- Prop Call/Prop Call/ (main app sources)
  - [`Prop_CallApp.swift`](Prop Call/Prop Call/Prop_CallApp.swift)
  - [`ContentView.swift` (ARVoiceIntentView)](Prop Call/Prop Call/ContentView.swift)
  - [`MultipeerManager.swift`](Prop Call/Prop Call/MultipeerManager.swift)
  - [`GameRoundManager.swift`](Prop Call/Prop Call/GameRoundManager.swift)
  - [`SpeechRecognizer.swift`](Prop Call/Prop Call/SpeechRecognizer.swift)
  - [`VisionObjectDetector.swift`](Prop Call/Prop Call/VisionObjectDetector.swift)
  - [`ARCoordinator.swift`](Prop Call/Prop Call/ARCoordinator.swift)
  - [`ARViewContainer.swift`](Prop Call/Prop Call/ARViewContainer.swift)
  - [`YOLOv8n.mlpackage`](Prop Call/Prop Call/YOLOv8n.mlpackage)
  - [`Assets.xcassets`](Prop Call/Prop Call/Assets.xcassets)
  - Extensions/ (utility extensions)

Notes:
- Multiplayer and state sync live in [`MultipeerManager`](Prop Call/Prop Call/MultipeerManager.swift). Look at published values and publishers for UI bindings.
- Round lifecycle & timer logic: [`GameRoundManager`](Prop Call/Prop Call/GameRoundManager.swift).
- Object detection pipeline: [`VisionObjectDetector`](Prop Call/Prop Call/VisionObjectDetector.swift) with Vision/CoreML model.

---

## Configuration

Update Info.plist (located at `Prop Call/Prop-Call-Info.plist`) to provide privacy usage descriptions:

- NSCameraUsageDescription — camera required for AR and detection.  
- NSMicrophoneUsageDescription — speech recognition / audio capture.  
- NSSpeechRecognitionUsageDescription — speech recognition permission.  

Example keys to verify:
- "Privacy - Camera Usage Description"
- "Privacy - Microphone Usage Description"
- "Privacy - Speech Recognition Usage Description"

Signing & team:
- In Xcode, set your Team under the project target -> Signing & Capabilities.

Core ML model:
- The model is already included at [`YOLOv8n.mlpackage`](Prop Call/Prop Call/YOLOv8n.mlpackage). If you replace it, ensure the code in [`VisionObjectDetector`](Prop Call/Prop Call/VisionObjectDetector.swift) matches the model class name.

Multipeer:
- Service type defined in [`MultipeerManager`](Prop Call/Prop Call/MultipeerManager.swift) as `"propcallgame"`. No additional server-side config needed; uses local peer-to-peer.

---

## Roadmap

Planned improvements:
- Improve object label vocabulary & confidence handling in [`VisionObjectDetector`](Prop Call/Prop Call/VisionObjectDetector.swift).  
- Add replay / round history + persistence.  
- Enhance UI/UX for lobby and host controls in [`ContentView`](Prop Call/Prop Call/ContentView.swift).  
- Add audio/visual feedback and accessibility options.  
- Add unit tests and automated CI (Xcode Cloud / GitHub Actions).

---
