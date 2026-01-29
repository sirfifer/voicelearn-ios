# UnaMentis iOS Style Guide and Standards

**Version:** 1.0
**Last Updated:** December 2025
**Status:** Mandatory

This document defines the coding standards, accessibility requirements, internationalization patterns, and UI/UX guidelines for the UnaMentis iOS application. **All contributors (human and AI) must comply with these standards.**

---

## Table of Contents

1. [Accessibility Requirements](#1-accessibility-requirements)
2. [Internationalization (i18n)](#2-internationalization-i18n)
3. [iPad and Adaptive Layout](#3-ipad-and-adaptive-layout)
4. [SwiftUI Best Practices](#4-swiftui-best-practices)
5. [Performance Standards](#5-performance-standards)
6. [Code Style](#6-code-style)
7. [Testing Requirements](#7-testing-requirements)

---

## 1. Accessibility Requirements

### 1.1 Non-Negotiable Standards

Accessibility is **mandatory**, not optional. UnaMentis must be usable by people with disabilities.

#### VoiceOver Support

Every interactive element MUST have accessibility labels:

```swift
// REQUIRED for all interactive elements
Button("Start") { ... }
    .accessibilityLabel("Start voice session")
    .accessibilityHint("Double-tap to begin a conversation with your AI tutor")

// REQUIRED for dynamic content
Text(transcriptText)
    .accessibilityLabel(isUserMessage ? "You said" : "AI said")
    .accessibilityValue(transcriptText)

// REQUIRED for visual indicators
Circle()
    .fill(statusColor)
    .accessibilityLabel("Session status")
    .accessibilityValue(sessionState.accessibilityDescription)
```

#### Dynamic Type Support

All text MUST scale with user's text size preferences:

```swift
// At the app root level (UnaMentisApp.swift)
ContentView()
    .dynamicTypeSize(.medium ... .accessibility3)

// Use scalable fonts, not fixed sizes
Text("Title")
    .font(.headline)  // CORRECT: Uses Dynamic Type

Text("Title")
    .font(.system(size: 18))  // INCORRECT: Fixed size, won't scale
```

#### Minimum Touch Targets

Interactive elements must meet Apple's 44x44pt minimum:

```swift
Button { ... } label: {
    Image(systemName: "gear")
}
.frame(minWidth: 44, minHeight: 44)  // Ensure minimum touch target
```

### 1.2 Audio-First Considerations

UnaMentis is primarily an audio application. For users who cannot hear:

1. **Visual Feedback Required**: All audio events must have visual representation
   - Speaking indicators (waveforms, animations)
   - Transcript display of all speech
   - Status indicators for audio states

2. **Haptic Feedback**: Use haptics for state changes
   ```swift
   .sensoryFeedback(.impact(weight: .medium), trigger: sessionState)
   ```

3. **Transcript Always Available**: The transcript view provides text representation of all audio content, enabling deaf users to read what is being spoken.

### 1.3 Reduce Motion

Respect the user's Reduce Motion preference:

```swift
@Environment(\.accessibilityReduceMotion) var reduceMotion

var body: some View {
    waveformView
        .animation(reduceMotion ? nil : .easeInOut, value: amplitude)
}
```

### 1.4 Hands-Free First Design

UnaMentis implements a **two-tier voice interaction model** to support hands-free operation:

**Tier 1: Activity-Mode Voice-First**
- Automatic when entering voice-centric activities (oral practice, learning sessions)
- Complete activities entirely hands-free (e.g., while driving)
- No toggle needed; entering the activity activates voice-first mode

**Tier 2: App-Wide Voice Navigation**
- Accessibility feature for vision-impaired users
- Opt-in via Accessibility settings
- Extends voice control to all app navigation

**Key Requirement:** All voice-first work MUST follow accessibility standards:
- Commands consistent across both tiers ("next" means "next" everywhere)
- VoiceOver compatibility required
- Audio feedback has visual equivalents

See [HANDS_FREE_FIRST_DESIGN.md](../design/HANDS_FREE_FIRST_DESIGN.md) for complete specification.

---

## 2. Internationalization (i18n)

### 2.1 String Localization

**All user-facing strings MUST be localizable.** Use `LocalizedStringKey` or `String(localized:)`:

```swift
// CORRECT: Localizable
Text("Start Session")  // Automatically uses LocalizedStringKey
Text(String(localized: "curriculum.topics.count \(count)"))

// INCORRECT: Hardcoded, not localizable
Text(verbatim: "Start Session")  // Only use for non-localizable content like identifiers
```

#### Localizable.strings Structure

```
// Localizable.strings (English)

// MARK: - Session
"session.start" = "Start Session";
"session.stop" = "End Session";
"session.status.idle" = "Ready to start";
"session.status.listening" = "Listening...";
"session.status.processing" = "Thinking...";
"session.status.speaking" = "Speaking...";

// MARK: - Curriculum
"curriculum.title" = "Curriculum";
"curriculum.topics.count %lld" = "%lld topics";
"curriculum.empty.title" = "No Curriculum Loaded";
"curriculum.empty.description" = "Import a curriculum to get started.";

// MARK: - Accessibility
"accessibility.session.start.hint" = "Double-tap to begin a voice conversation";
"accessibility.transcript.user" = "You said";
"accessibility.transcript.ai" = "AI said";
```

### 2.2 Date and Number Formatting

Always use formatters that respect locale:

```swift
// CORRECT: Locale-aware
Text(date, style: .date)
Text(duration.formatted(.units(allowed: [.hours, .minutes])))
Text(cost, format: .currency(code: "USD"))

// INCORRECT: Hardcoded format
Text("\(hours)h \(minutes)m")  // Doesn't localize
```

### 2.3 Right-to-Left (RTL) Support

Use leading/trailing instead of left/right:

```swift
// CORRECT: RTL-aware
.padding(.leading, 16)
HStack { ... }  // Automatically flips for RTL

// INCORRECT: Forces LTR
.padding(.left, 16)
```

### 2.4 Future Language Support

The app is designed to support multiple languages. When adding UI:

1. Extract all strings to Localizable.strings
2. Use string interpolation for dynamic content: `"topics.count %lld"`
3. Avoid string concatenation: build complete sentences for translation context
4. Consider text expansion (German is ~30% longer than English)

---

## 3. iPad and Adaptive Layout

### 3.1 Mandatory iPad Support

UnaMentis MUST work as a first-class iPad app, not just an enlarged iPhone app.

#### Size Class Detection

Use horizontal size class to adapt layouts:

```swift
@Environment(\.horizontalSizeClass) var horizontalSizeClass

var body: some View {
    if horizontalSizeClass == .regular {
        // iPad: Use NavigationSplitView or wider layouts
        iPadLayout
    } else {
        // iPhone: Use NavigationStack or compact layouts
        iPhoneLayout
    }
}
```

#### NavigationSplitView for iPad

Multi-column navigation for list-detail views:

```swift
var body: some View {
    if horizontalSizeClass == .regular {
        NavigationSplitView {
            // Sidebar
            CurriculumListView(selection: $selectedCurriculum)
        } detail: {
            // Detail
            if let curriculum = selectedCurriculum {
                CurriculumDetailView(curriculum: curriculum)
            } else {
                ContentUnavailableView("Select a Curriculum", systemImage: "book.closed")
            }
        }
    } else {
        NavigationStack {
            CurriculumListView(selection: $selectedCurriculum)
        }
    }
}
```

### 3.2 Orientation Support

iPad must support all orientations. In Info.plist:

```xml
<key>UISupportedInterfaceOrientations~ipad</key>
<array>
    <string>UIInterfaceOrientationPortrait</string>
    <string>UIInterfaceOrientationPortraitUpsideDown</string>
    <string>UIInterfaceOrientationLandscapeLeft</string>
    <string>UIInterfaceOrientationLandscapeRight</string>
</array>
```

### 3.3 Keyboard Support

For iPad with Magic Keyboard, add keyboard shortcuts:

```swift
.keyboardShortcut("n", modifiers: .command)  // Cmd+N for new session
.keyboardShortcut(.space, modifiers: [])     // Space for pause/resume
.keyboardShortcut("s", modifiers: .command)  // Cmd+S for settings
```

### 3.4 Focus Management

Support keyboard navigation with focus states:

```swift
@FocusState private var focusedElement: FocusableElement?

enum FocusableElement: Hashable {
    case searchField
    case curriculumList
    case transcriptView
}

TextField("Search", text: $searchText)
    .focused($focusedElement, equals: .searchField)
```

### 3.5 Multitasking

Support Split View and Slide Over on iPad:

- Views must adapt to varying widths
- Don't assume full-screen
- Test at 1/3, 1/2, and 2/3 widths

---

## 4. SwiftUI Best Practices

### 4.1 Property Wrappers

Use the correct property wrapper for each situation:

| Wrapper | Use Case |
|---------|----------|
| `@State` | Simple local view state (primitives, structs) |
| `@StateObject` | View-owned reference type (create once per view lifecycle) |
| `@ObservedObject` | Reference type passed from parent |
| `@EnvironmentObject` | Shared app-wide state |
| `@Environment` | System values (colorScheme, sizeClass, etc.) |
| `@Binding` | Two-way connection to parent's state |

**Anti-pattern to avoid:**
```swift
// WRONG: Creating StateObject in init
init(topic: Topic) {
    _viewModel = StateObject(wrappedValue: ViewModel(topic: topic))
}

// CORRECT: Use onAppear/task to configure
@StateObject private var viewModel = ViewModel()

var body: some View {
    content
        .task { await viewModel.configure(topic: topic) }
}
```

### 4.2 View Performance

#### Equatable Conformance

For frequently-updated views, add Equatable to prevent unnecessary redraws:

```swift
struct TranscriptBubble: View, Equatable {
    let text: String
    let isUser: Bool
    let timestamp: Date

    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.text == rhs.text && lhs.isUser == rhs.isUser
    }

    var body: some View { ... }
}

// Usage
TranscriptBubble(text: message.text, isUser: message.isUser, timestamp: message.time)
    .equatable()
```

#### Consolidate onChange

Multiple onChange modifiers create separate observation chains:

```swift
// AVOID: Multiple onChange
.onChange(of: value1) { ... }
.onChange(of: value2) { ... }
.onChange(of: value3) { ... }

// PREFER: Single observation with tuple or combined state
.onChange(of: (value1, value2, value3)) { oldValue, newValue in
    // Handle changes
}
```

### 4.3 Navigation

Use NavigationStack (iOS 16+) instead of deprecated NavigationView:

```swift
NavigationStack {
    List { ... }
        .navigationDestination(for: Topic.self) { topic in
            TopicDetailView(topic: topic)
        }
}
```

### 4.4 Modern APIs

Use current iOS 17+ APIs:

| Deprecated | Current |
|------------|---------|
| `NavigationView` | `NavigationStack` / `NavigationSplitView` |
| `.onAppear { Task { } }` | `.task { }` |
| `EmptyView()` for empty states | `ContentUnavailableView` |
| `@State` for animation | `.animation(_:value:)` |

---

## 5. Performance Standards

### 5.1 Targets

| Metric | Target |
|--------|--------|
| App launch to interactive | < 2 seconds |
| View transition | < 300ms |
| List scroll | 60 FPS |
| Memory growth per hour | < 50MB |

### 5.2 Lazy Loading

Use lazy containers for large collections:

```swift
LazyVStack {  // Not VStack
    ForEach(items) { item in
        ItemRow(item: item)
    }
}
```

### 5.3 Image Optimization

```swift
AsyncImage(url: imageURL) { phase in
    switch phase {
    case .success(let image):
        image.resizable().aspectRatio(contentMode: .fit)
    case .failure:
        Image(systemName: "photo")
    case .empty:
        ProgressView()
    @unknown default:
        EmptyView()
    }
}
```

---

## 6. Code Style

### 6.1 Swift 6 Concurrency

All services MUST be actors or properly isolated:

```swift
// Services are actors
actor MyService {
    func fetchData() async throws -> Data { ... }
}

// ViewModels are @MainActor
@MainActor
class MyViewModel: ObservableObject { ... }

// Sendable conformance for cross-boundary types
struct Message: Sendable { ... }
```

### 6.2 Documentation

Public APIs require documentation:

```swift
/// Manages voice session lifecycle and state
///
/// SessionManager coordinates between audio input, speech recognition,
/// LLM processing, and text-to-speech output.
///
/// - Important: Must be created via `AppState.createSessionManager()`
public actor SessionManager {
    /// Starts a new voice session
    /// - Parameter topic: Optional topic for curriculum-based sessions
    /// - Throws: `SessionError` if services unavailable
    public func startSession(topic: Topic? = nil) async throws { ... }
}
```

### 6.3 File Organization

```swift
// 1. Imports
import SwiftUI
import Combine

// 2. Main type
struct MyView: View {
    // Properties (grouped)
    @Environment(\.horizontalSizeClass) var sizeClass
    @EnvironmentObject var appState: AppState
    @StateObject private var viewModel = MyViewModel()
    @State private var isLoading = false

    // Body
    var body: some View { ... }
}

// 3. Extensions
extension MyView {
    // Private helpers
}

// 4. Subviews (if small, otherwise separate file)
private struct MySubview: View { ... }

// 5. Previews
#Preview {
    MyView()
}
```

---

## 7. Testing Requirements

### 7.1 Accessibility Testing Checklist

Before any PR:

- [ ] Navigate all screens with VoiceOver enabled
- [ ] Test with Dynamic Type at largest sizes
- [ ] Test with Reduce Motion enabled
- [ ] Test with Increase Contrast enabled
- [ ] Run Xcode Accessibility Inspector
- [ ] Verify all interactive elements have labels

### 7.2 iPad Testing Checklist

- [ ] Test on iPad Pro 12.9" in portrait
- [ ] Test on iPad Pro 12.9" in landscape
- [ ] Test on iPad mini
- [ ] Test Split View at 1/3, 1/2, 2/3 widths
- [ ] Test with Magic Keyboard attached
- [ ] Verify keyboard shortcuts work

### 7.3 Internationalization Testing

- [ ] Verify all strings use localization
- [ ] Test with pseudolocalization (longer strings)
- [ ] Test with RTL language (Arabic/Hebrew)
- [ ] Verify dates/numbers format correctly

---

## Compliance

### Enforcement

1. All PRs must pass accessibility audit
2. New views must include iPad layout support
3. All user-facing strings must be localizable
4. Code review must verify compliance with this guide

### Exceptions

Exceptions require explicit approval and documentation explaining why the standard cannot be met and the plan to address it in the future.

---

## Related Documents

- [iOS Best Practices Review](IOS_BEST_PRACTICES_REVIEW.md) - Original audit findings
- [AGENTS.md](../AGENTS.md) - AI development guidelines
- [Apple Human Interface Guidelines](https://developer.apple.com/design/human-interface-guidelines/)
- [Apple Accessibility Guidelines](https://developer.apple.com/accessibility/)
