# USM Menu Bar App - Diagnostic Report

**Date:** January 4, 2026
**Reference Implementation:** TahoeMenuDemo (https://github.com/sjhooper/TahoeMenuDemo)
**Problem:** Menu bar icon not appearing; App icon shows as gray box in System Settings

---

## Executive Summary

After comparing USM against the verified working TahoeMenuDemo example, I identified **one code difference** and **one system configuration issue** that are the likely causes.

---

## Comparison Analysis

### 1. Menu Bar Icon Code

| Aspect | TahoeMenuDemo (Working) | USM (Not Working) |
|--------|------------------------|-------------------|
| SF Symbol | `circle.fill` | `server.rack` |
| Rendering Mode | `.renderingMode(.template)` | **MISSING** |

**FINDING:** USM is missing `.renderingMode(.template)` on the menu bar icon.

**TahoeMenuDemo code (lines 43-44):**
```swift
Image(systemName: "circle.fill")
    .renderingMode(.template)
```

**USM code (lines 236-237):**
```swift
Image(systemName: "server.rack")
// No .renderingMode(.template)
```

**Impact:** Without `.renderingMode(.template)`, SF Symbols may not render correctly as menu bar icons in macOS 26's transparent menu bar system.

---

### 2. Info.plist Configuration

| Key | TahoeMenuDemo | USM | Match? |
|-----|---------------|-----|--------|
| LSUIElement | true | true | ✅ |
| LSMinimumSystemVersion | 14.0 | 15.4 | ⚠️ Different |
| LSApplicationCategoryType | public.app-category.utilities | public.app-category.utilities | ✅ |
| CFBundleIconFile | Not present | AppIcon | ⚠️ Different |
| CFBundleIconName | Not present | AppIcon | ⚠️ Different |

**FINDING:** Info.plist configurations are similar. The icon file keys are present in USM but not in TahoeMenuDemo, which shouldn't cause issues.

---

### 3. App Icon (.icns) Analysis

| Aspect | TahoeMenuDemo | USM |
|--------|---------------|-----|
| Has .icns file | No (empty AppIcon.appiconset) | Yes (47,588 bytes) |
| .icns validity | N/A | Valid (verified with iconutil) |
| Assets.car present | Unknown | Yes (47,608 bytes) |

**FINDING:** USM has a valid .icns file. TahoeMenuDemo has NO app icon files at all (empty asset catalog slots).

**Critical Insight:** TahoeMenuDemo works WITHOUT any app icon files. The gray box in System Settings may be cosmetic only and NOT the cause of the menu bar icon not appearing.

---

### 4. Code Complexity Comparison

| Aspect | TahoeMenuDemo | USM |
|--------|---------------|-----|
| Lines of code | ~107 | ~325 |
| Uses @StateObject | No (uses @State) | Yes |
| Uses ObservableObject | No | Yes |
| Process() calls | No | Yes (multiple) |
| Timer usage | No | Yes |

**FINDING:** USM has significantly more complexity including:
- `@MainActor class ServiceManager` with `@Published` properties
- `Timer.scheduledTimer` running every 5 seconds
- Multiple `Process()` calls to pgrep, ps, kill
- `DispatchQueue.main.asyncAfter` calls

**Potential Issue:** The ServiceManager's `init()` runs `setupServices()` and `startMonitoring()` which creates a Timer and runs Process commands. If any of these operations block or fail during app launch, it could prevent the MenuBarExtra from initializing properly.

---

### 5. macOS 26 Permission System

According to research, macOS 26 Tahoe introduced a new permission system where menu bar apps must be enabled in:

**System Settings → Menu Bar → "Allow in Menu Bar"**

**User's Status:** USM appears in this list with toggle ON, but icon still doesn't appear.

**FINDING:** This rules out the permission toggle as the cause.

---

## Root Cause Analysis

### Primary Cause (HIGH CONFIDENCE)

**Missing `.renderingMode(.template)` on menu bar icon.**

The working example explicitly uses:
```swift
Image(systemName: "circle.fill")
    .renderingMode(.template)
```

Our code does NOT have `.renderingMode(.template)`:
```swift
Image(systemName: "server.rack")
```

### Secondary Cause (MEDIUM CONFIDENCE)

**ServiceManager initialization may be blocking or failing.**

The `ServiceManager.init()` immediately:
1. Calls `setupServices()` - creates service array
2. Calls `startMonitoring()` - runs `updateStatuses()` which calls `Process()` multiple times, then creates a Timer

If `Process()` calls block or fail during app startup, this could prevent the MenuBarExtra from rendering.

### Tertiary Cause (LOW CONFIDENCE)

**App icon gray box is a cosmetic issue.**

TahoeMenuDemo has NO app icon files and still works. The gray box may be a macOS 26 cosmetic enforcement issue and NOT related to menu bar functionality.

---

## Definitive Fixes Required

### Fix 1: Add .renderingMode(.template)

Change line 237 in USMApp.swift from:
```swift
Image(systemName: "server.rack")
```

To:
```swift
Image(systemName: "server.rack")
    .renderingMode(.template)
```

### Fix 2: Defer ServiceManager initialization

Move heavy initialization out of `init()` to prevent blocking MenuBarExtra:

```swift
@main
struct USMApp: App {
    @StateObject private var serviceManager = ServiceManager()

    var body: some Scene {
        MenuBarExtra {
            MenuContent(serviceManager: serviceManager)
        } label: {
            Image(systemName: "server.rack")
                .renderingMode(.template)
        }
        .menuBarExtraStyle(.menu)
    }
}

// In ServiceManager:
init() {
    setupServices()
    // DON'T call startMonitoring() here
}

// Call startMonitoring() from MenuContent.onAppear instead
```

### Fix 3: Test with minimal implementation first

Before applying fixes, test with the exact TahoeMenuDemo code to confirm the base pattern works on this system.

---

## Verification Checklist

Before any fix is considered complete:

- [ ] Menu bar icon appears in status menu bar (top right)
- [ ] Icon renders correctly in both light and dark modes
- [ ] Clicking icon shows dropdown menu
- [ ] Menu items are functional
- [ ] App appears in System Settings → Menu Bar list
- [ ] App icon in System Settings is not a gray box (cosmetic, not blocking)

---

## What I Still Don't Know

1. **Why SF Symbol without .renderingMode(.template) would cause complete invisibility** - Normally it would just render incorrectly, not disappear entirely.

2. **Whether the ServiceManager's Process() calls are actually blocking** - Would need to add logging or test with a minimal app.

3. **Whether there's a macOS 26-specific issue with our development environment** - The fact that MenuDemo (from TahoeMenuDemo) also didn't work when tested earlier suggests a system-level issue.

---

## Recommended Next Steps

1. **Clone and build TahoeMenuDemo** exactly as-is from the GitHub repo
2. **Run the unmodified TahoeMenuDemo** to verify it works on this system
3. If TahoeMenuDemo works: Apply Fix 1 and Fix 2 to USM
4. If TahoeMenuDemo doesn't work: The issue is system-level, not code-level

---

## Files Analyzed

- `/Users/ramerman/dev/unamentis/server/server-manager/USMXcode/USM/USMApp.swift` (325 lines)
- `/Users/ramerman/Applications/USM.app/Contents/Info.plist`
- `/Users/ramerman/Applications/USM.app/Contents/Resources/AppIcon.icns` (47,588 bytes, valid)
- `/Users/ramerman/Applications/USM.app/Contents/Resources/Assets.car` (47,608 bytes)
- TahoeMenuDemo reference implementation from GitHub

---

## Appendix: Working TahoeMenuDemo Pattern

```swift
import SwiftUI

@main
struct MenuDemoApp: App {
    @State private var isRunning = false

    var body: some Scene {
        MenuBarExtra {
            MenuContent(isRunning: $isRunning)
        } label: {
            Image(systemName: "circle.fill")
                .renderingMode(.template)  // CRITICAL
        }
        .menuBarExtraStyle(.menu)
    }
}

struct MenuContent: View {
    @Binding var isRunning: Bool

    var body: some View {
        Button(isRunning ? "Stop" : "Start") {
            isRunning.toggle()
        }

        Divider()

        Button("Quit") {
            NSApp.terminate(nil)
        }
        .keyboardShortcut("q", modifiers: .command)
    }
}
```

**Info.plist minimum requirements:**
```xml
<key>LSUIElement</key>
<true/>
```
