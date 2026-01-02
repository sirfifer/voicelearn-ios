# UnaMentis Apple Watch App Exploration

## Executive Summary

This document explores adding an Apple Watch companion app to UnaMentis. The Watch app will serve as a **control plane** for active tutoring sessions, allowing users to control their learning experience from their wrist without needing to interact with their iPhone.

### Primary Goals (Phase 1 - Control Plane)
- Automatic installation when iOS app is installed
- Display current session context (curriculum/topic name)
- Session controls: Mute, Pause, Stop
- Progress indicator showing learning progress
- Reliable always-on experience during sessions

### Future Goals (Phase 2 - Voice Communication)
- Direct voice communication through Watch
- Remote STT/TTS via WiFi/Cellular
- Standalone session capability

---

## 1. Technical Platform Requirements

### Target Versions
| Platform | Version | Notes |
|----------|---------|-------|
| iOS | 26.0+ | Unified versioning with watchOS |
| watchOS | 26.0+ | Liquid Glass design, ARM64 required |
| Xcode | 17.0+ | watchOS 26 SDK |
| Swift | 6.0 | Strict concurrency |

### App Store Requirements (April 2026)
- Apps must include 64-bit ARM64 support
- Must be built with watchOS 26 SDK
- Test on: Apple Watch Series 9/10, Ultra 2

### Version Compatibility Pitfall
> **Warning:** iOS/watchOS version mismatches can cause:
> - Watch app failing to install automatically
> - WatchConnectivity communication failures
> - Data sync issues
>
> Recommendation: Require matching major versions (26.x ↔ 26.x)

---

## 2. Xcode Project Configuration

### Bundle Identifier Structure
The Watch app bundle ID **must** be prefixed with the iOS app bundle ID:

```
iOS App:           com.unamentis.UnaMentis
Watch App:         com.unamentis.UnaMentis.watchkitapp
```

### Required Info.plist Keys

**Watch App Target (`UnaMentis Watch App/Info.plist`):**
```xml
<key>WKCompanionAppBundleIdentifier</key>
<string>com.unamentis.UnaMentis</string>

<key>WKRunsIndependentlyOfCompanionApp</key>
<false/>
```

> Note: `WKRunsIndependentlyOfCompanionApp` is `false` for Phase 1 (control plane only). Set to `true` in Phase 2 when enabling standalone voice communication.

### Project Structure

```
UnaMentis.xcodeproj/
├── UnaMentis/                    # iOS app target
├── UnaMentis Watch App/          # watchOS app target (new)
│   ├── UnaMentisWatchApp.swift   # App entry point
│   ├── ContentView.swift         # Main session control view
│   ├── SessionControlView.swift  # Control buttons
│   ├── Assets.xcassets           # Watch-specific assets
│   └── Info.plist
└── Shared/                       # Shared code (new)
    ├── SessionState.swift        # Codable session state
    ├── WatchConnectivityManager.swift
    └── SessionCommands.swift     # Command definitions
```

### Embedding the Watch App

In the iOS target's **Frameworks, Libraries, and Embedded Content**:
1. Click `+`
2. Select the Watch App target
3. This ensures automatic installation when iOS app is installed

### Build Settings
```
WATCHKIT_COMPANION_APP_BUNDLE_IDENTIFIER = com.unamentis.UnaMentis.watchkitapp
```

---

## 3. WatchConnectivity Architecture

### Singleton Manager Pattern

Create a singleton to manage all Watch communication from a single location:

```swift
// Shared/WatchConnectivityManager.swift
import WatchConnectivity

@MainActor
final class WatchConnectivityManager: NSObject, ObservableObject {
    static let shared = WatchConnectivityManager()

    @Published var isReachable = false
    @Published var sessionState: WatchSessionState?

    private var session: WCSession?

    private override init() {
        super.init()
        if WCSession.isSupported() {
            session = WCSession.default
            session?.delegate = self
            session?.activate()
        }
    }
}
```

### Communication Methods

| Method | Use Case | Delivery | Battery Impact |
|--------|----------|----------|----------------|
| `updateApplicationContext` | **State sync** - current session state | Opportunistic, latest wins | Low |
| `sendMessage` | **Real-time** - immediate control commands | Immediate (if reachable) | Medium |
| `transferUserInfo` | **Guaranteed** - important state changes | Queued, guaranteed delivery | Low |

### Recommended Approach

**iOS → Watch (Session State):**
```swift
// Send session state changes via Application Context
func syncSessionState(_ state: WatchSessionState) {
    guard let session, session.isReachable else { return }

    do {
        let data = try JSONEncoder().encode(state)
        let context = ["sessionState": data]
        try session.updateApplicationContext(context)
    } catch {
        Logger.watch.error("Failed to sync state: \(error)")
    }
}
```

**Watch → iOS (Commands):**
```swift
// Send commands via sendMessage for immediate response
func sendCommand(_ command: SessionCommand) {
    guard let session, session.isReachable else { return }

    session.sendMessage(
        ["command": command.rawValue],
        replyHandler: { response in
            // Handle acknowledgment
        },
        errorHandler: { error in
            Logger.watch.error("Command failed: \(error)")
        }
    )
}
```

### Session State Data Model

```swift
// Shared/SessionState.swift
import Foundation

/// State synced from iOS to Watch
struct WatchSessionState: Codable, Sendable {
    let isActive: Bool
    let isPaused: Bool
    let isMuted: Bool

    // Context display
    let curriculumTitle: String?
    let topicTitle: String?
    let sessionMode: SessionMode

    // Progress
    let currentSegment: Int
    let totalSegments: Int
    let progressPercentage: Double  // 0.0 - 1.0

    // Timing
    let elapsedTime: TimeInterval
    let estimatedRemaining: TimeInterval?

    enum SessionMode: String, Codable {
        case freeform
        case curriculum
        case directStreaming
    }
}

/// Commands from Watch to iOS
enum SessionCommand: String, Codable {
    case pause
    case resume
    case mute
    case unmute
    case stop
}
```

---

## 4. Watch App UI Design

### Liquid Glass Design System (watchOS 26)

The new Liquid Glass design provides:
- Translucent, refractive materials
- Adaptive contrast based on content
- Unified cross-platform appearance

**Key Principle:** Liquid Glass is for the **navigation layer** (controls, bars), NOT content.

### SwiftUI Implementation

```swift
// UnaMentis Watch App/ContentView.swift
import SwiftUI

struct SessionControlView: View {
    @ObservedObject var connectivity = WatchConnectivityManager.shared

    var body: some View {
        if let state = connectivity.sessionState, state.isActive {
            ActiveSessionView(state: state)
        } else {
            IdleView()
        }
    }
}

struct ActiveSessionView: View {
    let state: WatchSessionState

    var body: some View {
        VStack(spacing: 12) {
            // Header: Current context
            SessionHeaderView(
                curriculum: state.curriculumTitle,
                topic: state.topicTitle
            )

            // Progress ring
            ProgressRingView(progress: state.progressPercentage)

            // Control buttons
            ControlButtonsView(
                isPaused: state.isPaused,
                isMuted: state.isMuted
            )
        }
        .containerBackground(for: .navigation) {
            // Liquid Glass background
            Color.clear.glassEffect()
        }
    }
}
```

### Screen Layout (44mm/45mm Watch)

```
┌─────────────────────────────┐
│  📚 Calculus 101            │  ← Curriculum (truncated if needed)
│  Derivatives                │  ← Current topic
├─────────────────────────────┤
│                             │
│       ╭─────────────╮       │
│       │   ██████    │       │  ← Circular progress
│       │   42%       │       │     (Gauge or custom)
│       ╰─────────────╯       │
│                             │
├─────────────────────────────┤
│  [🎤] [⏸️ Pause] [🛑 Stop]  │  ← Controls (Liquid Glass)
└─────────────────────────────┘
```

### Progress Ring with Gauge

```swift
struct ProgressRingView: View {
    let progress: Double

    var body: some View {
        Gauge(value: progress, in: 0...1) {
            Text("Progress")
        } currentValueLabel: {
            Text("\(Int(progress * 100))%")
                .font(.system(.title2, design: .rounded))
                .fontWeight(.bold)
        }
        .gaugeStyle(.accessoryCircular)
        .tint(progressGradient)
    }

    private var progressGradient: Gradient {
        Gradient(colors: [.blue, .cyan, .green])
    }
}
```

### Control Buttons

```swift
struct ControlButtonsView: View {
    let isPaused: Bool
    let isMuted: Bool

    var body: some View {
        HStack(spacing: 16) {
            // Mute toggle
            Button {
                WatchConnectivityManager.shared.sendCommand(
                    isMuted ? .unmute : .mute
                )
            } label: {
                Image(systemName: isMuted ? "mic.slash.fill" : "mic.fill")
            }
            .buttonStyle(.bordered)
            .tint(isMuted ? .red : .gray)

            // Pause/Resume
            Button {
                WatchConnectivityManager.shared.sendCommand(
                    isPaused ? .resume : .pause
                )
            } label: {
                Image(systemName: isPaused ? "play.fill" : "pause.fill")
            }
            .buttonStyle(.borderedProminent)

            // Stop
            Button(role: .destructive) {
                WatchConnectivityManager.shared.sendCommand(.stop)
            } label: {
                Image(systemName: "stop.fill")
            }
            .buttonStyle(.bordered)
            .tint(.red)
        }
    }
}
```

---

## 5. Session State Integration

### iOS Side: Publishing State Changes

Integrate with existing `SessionViewModel`:

```swift
// UnaMentis/UI/Session/SessionView.swift (additions)

extension SessionViewModel {
    /// Sync session state to Watch
    func syncToWatch() {
        let watchState = WatchSessionState(
            isActive: sessionManager?.isActive ?? false,
            isPaused: isPaused,
            isMuted: isMuted,
            curriculumTitle: currentCurriculum?.title,
            topicTitle: currentTopic?.title,
            sessionMode: isDirectStreamingMode ? .directStreaming :
                         (currentTopic != nil ? .curriculum : .freeform),
            currentSegment: currentSegmentIndex,
            totalSegments: totalSegments,
            progressPercentage: totalSegments > 0 ?
                Double(completedSegmentCount) / Double(totalSegments) : 0,
            elapsedTime: sessionDuration,
            estimatedRemaining: estimatedRemainingTime
        )

        WatchConnectivityManager.shared.syncSessionState(watchState)
    }
}
```

### State Sync Triggers

Sync to Watch when any of these change:
- Session starts/stops
- Pause/resume state changes
- Mute state changes
- Segment completion (progress updates)
- Topic/curriculum changes

```swift
// In SessionViewModel, add observation
private func setupWatchSync() {
    // Sync on state changes
    $isPaused.sink { [weak self] _ in self?.syncToWatch() }.store(in: &cancellables)
    $isMuted.sink { [weak self] _ in self?.syncToWatch() }.store(in: &cancellables)
    $currentSegmentIndex.sink { [weak self] _ in self?.syncToWatch() }.store(in: &cancellables)
}
```

### iOS Side: Handling Commands

```swift
// In WatchConnectivityManager (iOS side)
extension WatchConnectivityManager: WCSessionDelegate {
    func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        guard let commandString = message["command"] as? String,
              let command = SessionCommand(rawValue: commandString) else {
            return
        }

        Task { @MainActor in
            handleCommand(command)
        }
    }

    private func handleCommand(_ command: SessionCommand) {
        guard let viewModel = activeSessionViewModel else { return }

        switch command {
        case .pause:
            viewModel.pauseSession()
        case .resume:
            viewModel.resumeSession()
        case .mute:
            viewModel.isMuted = true
        case .unmute:
            viewModel.isMuted = false
        case .stop:
            viewModel.stopSession()
        }
    }
}
```

---

## 6. Always-On Display Support

### Automatic Support (watchOS 8+)

For apps built with watchOS 8+ SDK, Always-On is **enabled by default**. The Watch will continue displaying your app while:
- App is frontmost, OR
- App has an active background session

### Background Session for Tutoring

Since UnaMentis tutoring sessions are long-form (60-90+ minutes), we need a background session to keep the Watch app alive.

**Option 1: Extended Runtime Session (Recommended for Phase 1)**

```swift
import WatchKit

class SessionBackgroundManager {
    private var extendedSession: WKExtendedRuntimeSession?

    func startBackgroundSession() {
        extendedSession = WKExtendedRuntimeSession()
        extendedSession?.delegate = self
        extendedSession?.start(at: Date())
    }

    func endBackgroundSession() {
        extendedSession?.invalidate()
        extendedSession = nil
    }
}
```

**Session Types:**
| Type | Duration | Use Case |
|------|----------|----------|
| `.smartAlarm` | Until dismissed | Not applicable |
| `.selfCare` | Up to 10 min | Short sessions |
| `.mindfulness` | Up to 10 min | Guided sessions |
| `.physicalTherapy` | Up to 1 hour | Extended sessions |

> **Limitation:** Extended runtime sessions have maximum durations. For 90+ minute tutoring sessions, we may need to restart the session or use HKWorkoutSession.

**Option 2: HKWorkoutSession (Alternative)**

While unconventional for a tutoring app, an HKWorkoutSession provides:
- Unlimited background runtime
- Always-on display
- High-priority execution

```swift
// Only if Extended Runtime proves insufficient
import HealthKit

func startWorkoutSession() {
    let config = HKWorkoutConfiguration()
    config.activityType = .mindAndBody  // Closest match for learning

    do {
        let session = try HKWorkoutSession(
            healthStore: HKHealthStore(),
            configuration: config
        )
        session.startActivity(with: Date())
    } catch {
        Logger.watch.error("Failed to start workout session: \(error)")
    }
}
```

### UI Update Frequency

| State | Max Update Rate |
|-------|-----------------|
| Foreground | Unlimited |
| Background (with session) | 1 Hz (once/second) |
| Background (no session) | 1/minute |
| Always-On (dimmed) | 1/minute |

**Recommendation:** Update progress ring once per second during active session for smooth animation.

---

## 7. Reliability & Edge Cases

### Connection States

```swift
enum WatchConnectionState {
    case notSupported          // No Watch paired
    case inactive              // Session not activated
    case activating            // Activation in progress
    case activated             // Ready to communicate
    case notReachable          // Watch not reachable (out of range, etc.)
    case reachable             // Can send immediate messages
}
```

### Handling Disconnection

```swift
// Graceful degradation when Watch loses connection
func handleConnectionLoss() {
    // 1. Show "Reconnecting..." on Watch
    // 2. Cache last known state
    // 3. Disable control buttons (or show offline state)
    // 4. Auto-retry connection
}
```

### State Recovery

When Watch reconnects after disconnection:
1. iOS immediately sends current `ApplicationContext`
2. Watch receives state in `session(_:didReceiveApplicationContext:)`
3. UI updates to reflect current session state

### Pending Messages

```swift
// Check for pending messages after activation
func sessionDidBecomeActive(_ session: WCSession) {
    // Process any queued transferUserInfo
    if !session.outstandingUserInfoTransfers.isEmpty {
        Logger.watch.info("Processing \(session.outstandingUserInfoTransfers.count) pending transfers")
    }
}
```

---

## 8. Implementation Roadmap

### Phase 1: Control Plane (MVP)

| Week | Milestone |
|------|-----------|
| 1 | Project setup: Add Watch target, configure bundle IDs |
| 1 | WatchConnectivityManager singleton (both platforms) |
| 2 | Session state model and sync infrastructure |
| 2 | Basic Watch UI: idle view, session detection |
| 3 | Control buttons: pause, mute, stop |
| 3 | Progress ring integration |
| 4 | Always-on display and background session |
| 4 | Testing on real devices, edge case handling |

### Phase 1 Deliverables
- [x] Watch app auto-installs with iOS app
- [x] Session context displayed (curriculum/topic)
- [x] Mute/Pause/Stop controls working
- [x] Progress indicator updates in real-time
- [x] Always-on display during sessions
- [x] Graceful handling of disconnection

### Phase 2: Voice Communication (Future)

| Feature | Requirements |
|---------|--------------|
| Watch microphone input | Audio capture APIs |
| Remote STT | WebSocket to server, not iOS |
| Remote TTS | Audio streaming to Watch |
| Standalone mode | `WKRunsIndependentlyOfCompanionApp = true` |
| Cellular/WiFi | Network APIs on Watch |

**Key Consideration:** Phase 2 requires server-side STT/TTS (e.g., Deepgram, ElevenLabs) since on-device processing on Watch is limited.

---

## 9. Testing Strategy

### Simulator Limitations

> **Warning:** WatchConnectivity rarely works reliably between simulators. Use real devices for connectivity testing.

### Test Matrix

| Scenario | Test Method |
|----------|-------------|
| Session state sync | Real iPhone + Watch |
| Control commands | Real devices |
| Disconnection recovery | Airplane mode toggle |
| Always-on display | Real Watch Series 5+ |
| Version mismatch | Different OS versions |

### Automated Testing

```swift
// Unit tests for state encoding/decoding
func testSessionStateEncoding() throws {
    let state = WatchSessionState(
        isActive: true,
        isPaused: false,
        isMuted: true,
        curriculumTitle: "Calculus",
        topicTitle: "Derivatives",
        sessionMode: .curriculum,
        currentSegment: 5,
        totalSegments: 20,
        progressPercentage: 0.25,
        elapsedTime: 300,
        estimatedRemaining: 900
    )

    let data = try JSONEncoder().encode(state)
    let decoded = try JSONDecoder().decode(WatchSessionState.self, from: data)

    XCTAssertEqual(decoded.isActive, true)
    XCTAssertEqual(decoded.curriculumTitle, "Calculus")
    XCTAssertEqual(decoded.progressPercentage, 0.25)
}
```

---

## 10. Risks and Mitigations

| Risk | Impact | Mitigation |
|------|--------|------------|
| WatchConnectivity unreliable | High | Use ApplicationContext (guaranteed), retry logic |
| Extended runtime session limits | Medium | Evaluate HKWorkoutSession if needed |
| Battery drain on Watch | Medium | Minimize update frequency, use efficient layouts |
| Version mismatch issues | Medium | Require matching major versions, graceful degradation |
| Simulator testing limitations | Low | Test on real devices early and often |
| Liquid Glass adoption complexity | Low | Use standard SwiftUI components, test early |

---

## 11. References

### Apple Documentation
- [Setting up a watchOS project](https://developer.apple.com/documentation/watchkit/setting-up-a-watchos-project)
- [Watch Connectivity](https://developer.apple.com/documentation/watchconnectivity)
- [Transferring data with Watch Connectivity](https://developer.apple.com/documentation/WatchConnectivity/transferring-data-with-watch-connectivity)
- [Using extended runtime sessions](https://developer.apple.com/documentation/watchkit/using-extended-runtime-sessions)
- [Designing for watchOS](https://developer.apple.com/design/human-interface-guidelines/designing-for-watchos)

### WWDC Sessions
- "Build a SwiftUI app with the new design" (WWDC25)
- "Meet Liquid Glass" (WWDC25)
- "What's new in watchOS" (WWDC25)
- "Streaming Audio on watchOS" (WWDC19)

### Community Resources
- [watchOS Development Pitfalls and Practical Tips](https://fatbobman.com/en/posts/watchos-development-pitfalls-and-practical-tips)
- [Kodeco: watchOS with SwiftUI - Watch Connectivity](https://www.kodeco.com/books/watchos-with-swiftui-by-tutorials/v1.0/chapters/4-watch-connectivity)
- [Hacking with Swift: WCSession](https://www.hackingwithswift.com/read/37/8/communicating-between-ios-and-watchos-wcsession)

---

## Appendix A: File Structure

```
UnaMentis/
├── UnaMentis.xcodeproj
├── UnaMentis/                          # iOS App
│   ├── Core/
│   │   ├── Session/
│   │   │   └── SessionManager.swift
│   │   └── Watch/                      # NEW
│   │       └── WatchConnectivityManager.swift
│   └── UI/
│       └── Session/
│           └── SessionView.swift       # Add Watch sync
│
├── UnaMentis Watch App/                # NEW - Watch App
│   ├── UnaMentisWatchApp.swift
│   ├── Views/
│   │   ├── ContentView.swift
│   │   ├── ActiveSessionView.swift
│   │   ├── IdleView.swift
│   │   ├── ProgressRingView.swift
│   │   └── ControlButtonsView.swift
│   ├── Managers/
│   │   ├── WatchConnectivityManager.swift
│   │   └── SessionBackgroundManager.swift
│   ├── Assets.xcassets
│   └── Info.plist
│
└── Shared/                             # NEW - Shared Code
    ├── Models/
    │   ├── WatchSessionState.swift
    │   └── SessionCommand.swift
    └── Extensions/
        └── Codable+Watch.swift
```

---

## Appendix B: Capability Entitlements

### iOS App (UnaMentis.entitlements)
```xml
<!-- Add if not present -->
<key>com.apple.developer.watchos.host-app</key>
<true/>
```

### Watch App (UnaMentis Watch App.entitlements)
```xml
<key>com.apple.developer.healthkit</key>
<true/>  <!-- Only if using HKWorkoutSession -->

<key>com.apple.developer.watchos.background-mode</key>
<array>
    <string>extended-runtime-session</string>
</array>
```

---

*Document Version: 1.0*
*Last Updated: January 2026*
*Author: Claude Code*
