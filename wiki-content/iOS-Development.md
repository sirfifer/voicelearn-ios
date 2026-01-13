# iOS Development Guide

Guide for developing the UnaMentis iOS app (Swift 6.0 / SwiftUI).

## Overview

The iOS app is the primary client for UnaMentis, enabling 60-90+ minute voice tutoring sessions with sub-500ms latency.

**Target**: iPhone 16/17 Pro Max | **Minimum**: iOS 18.0 | **Language**: Swift 6.0

## Project Structure

```
UnaMentis/
├── Core/
│   ├── Audio/           # AudioEngine, VAD
│   ├── Config/          # APIKeyManager, ServerConfig
│   ├── Curriculum/      # CurriculumEngine, ProgressTracker
│   ├── Routing/         # PatchPanelService (LLM routing)
│   ├── Session/         # SessionManager (state machine)
│   └── Telemetry/       # TelemetryEngine
├── Services/
│   ├── STT/             # Speech-to-Text providers
│   ├── TTS/             # Text-to-Speech providers
│   ├── LLM/             # Language model providers
│   └── VAD/             # Voice activity detection
├── Intents/             # Siri & App Intents
└── UI/
    ├── Session/         # Voice session views
    ├── Curriculum/      # Curriculum browser
    ├── Settings/        # Configuration views
    └── Debug/           # Debug tools
```

## Coding Standards

### Swift 6.0 Concurrency

**Use actors for shared state:**
```swift
actor SessionManager {
    private var state: SessionState = .idle

    func transition(to newState: SessionState) {
        state = newState
    }
}
```

**Mark UI code with @MainActor:**
```swift
@MainActor
class SessionViewModel: ObservableObject {
    @Published var isRecording = false
}
```

### Documentation

Document all public APIs:
```swift
/// Manages voice conversation sessions
///
/// SessionManager orchestrates the complete conversation flow including
/// turn-taking, interruption handling, and state management.
///
/// - Important: Always call `startSession()` before processing audio
actor SessionManager {
    // ...
}
```

### Naming Conventions

- **Types**: PascalCase (`SessionManager`, `AudioEngine`)
- **Methods/Properties**: camelCase (`startSession()`, `isRecording`)
- **Constants**: camelCase (`defaultTimeout`)
- **Protocols**: Suffix with `Protocol` or describe capability (`STTProviding`)

### Error Handling

Use typed errors:
```swift
enum AudioEngineError: LocalizedError {
    case microphonePermissionDenied
    case audioSessionFailed(underlying: Error)

    var errorDescription: String? {
        switch self {
        case .microphonePermissionDenied:
            return "Microphone permission is required"
        case .audioSessionFailed(let error):
            return "Audio session failed: \(error.localizedDescription)"
        }
    }
}
```

## Key Components

### SessionManager

The central orchestrator for voice sessions:

```swift
// State machine states
enum SessionState {
    case idle
    case userSpeaking
    case aiThinking
    case aiSpeaking
    case paused
    case error
}

// Usage
let session = SessionManager(...)
await session.startSession()
```

### PatchPanelService

Routes LLM tasks to appropriate endpoints:

```swift
let decision = await patchPanel.resolveRouting(
    taskType: .tutoringResponse,
    context: currentContext
)
// decision.endpointChain = ["gpt-4o", "claude-3.5", ...]
```

### Provider Services

All providers conform to protocols:

```swift
protocol STTProviding: Sendable {
    func transcribe(audio: Data) async throws -> String
}

protocol TTSProviding: Sendable {
    func synthesize(text: String) async throws -> Data
}

protocol LLMProviding: Sendable {
    func complete(prompt: String) async throws -> AsyncStream<String>
}
```

## Building and Running

### Xcode

```bash
# Open project
open UnaMentis.xcodeproj

# Select iPhone 16 Pro simulator
# Press Cmd+R to build and run
```

### Command Line

```bash
# Build for simulator
xcodebuild -project UnaMentis.xcodeproj \
  -scheme UnaMentis \
  -destination 'platform=iOS Simulator,name=iPhone 16 Pro' \
  build

# Run tests
./scripts/test-quick.sh
```

### MCP (AI-Assisted)

```bash
# Set session defaults
mcp__XcodeBuildMCP__session-set-defaults({
  projectPath: "/path/to/UnaMentis.xcodeproj",
  scheme: "UnaMentis",
  simulatorName: "iPhone 16 Pro"
})

# Build and run
mcp__XcodeBuildMCP__build_run_sim
```

## Testing

### Test Categories

- **Unit Tests**: Test individual components in isolation
- **Integration Tests**: Test component interactions
- **UI Tests**: Test user interface flows

### Running Tests

```bash
# Quick tests (unit only)
./scripts/test-quick.sh

# All tests with coverage
./scripts/test-all.sh

# Specific test file
xcodebuild test -project UnaMentis.xcodeproj \
  -scheme UnaMentis \
  -destination 'platform=iOS Simulator,name=iPhone 16 Pro' \
  -only-testing:UnaMentisTests/SessionManagerTests
```

### Testing Philosophy

**Real Over Mock**: Use real implementations when possible. Only mock:
- Paid external APIs (LLM, STT, TTS)
- Network requests to external services

See [[Testing]] for detailed testing guide.

## Common Patterns

### Async/Await with Actors

```swift
actor DataStore {
    private var items: [Item] = []

    func add(_ item: Item) {
        items.append(item)
    }

    func getAll() -> [Item] {
        items
    }
}

// Usage
let store = DataStore()
await store.add(newItem)
let allItems = await store.getAll()
```

### Publisher/Subscriber

```swift
class ViewModel: ObservableObject {
    @Published var state: State = .initial
    private var cancellables = Set<AnyCancellable>()

    init(service: SomeService) {
        service.statePublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] newState in
                self?.state = newState
            }
            .store(in: &cancellables)
    }
}
```

## Debugging

### Log Server

Always run the log server for debugging:

```bash
# Start log server
python3 scripts/log_server.py &

# View logs
open http://localhost:8765
```

### Debug UI

Access via Settings > Debug in the app:
- Subsystem toggles
- Network request inspector
- Audio visualizer
- Session state viewer

## Related Pages

- [[Dev-Environment]] - Setup guide
- [[Voice-Pipeline]] - Voice processing
- [[Testing]] - Testing guide
- [[Architecture]] - System design

---

Back to [[Home]]
