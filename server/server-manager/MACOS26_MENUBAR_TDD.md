# macOS 26 Menu Bar App - Technical Design Document

**Version:** 1.0
**Status:** VERIFIED
**Last Updated:** January 4, 2026
**Reference Implementation:** TahoeMenuDemo (https://github.com/sjhooper/TahoeMenuDemo)
**Working Implementation:** USM (UnaMentis Server Manager)

---

## VERIFICATION STATUS

✅ **THIS DOCUMENT IS VERIFIED**

Verified through:
- TahoeMenuDemo built and tested locally (works)
- USM implementation built, tested, and functioning
- All menu bar functionality confirmed working on macOS 26 Tahoe

**Verification Date:** January 4, 2026
**Current Status:** VERIFIED

---

## 1. Overview

This document defines the proposed specification for building menu bar apps on macOS 26 Tahoe, based on research and the TahoeMenuDemo reference. It requires local verification before being treated as authoritative.

---

## 2. Reference Sources

| Source | URL | Purpose |
|--------|-----|---------|
| TahoeMenuDemo | https://github.com/sjhooper/TahoeMenuDemo | Verified working example |
| Apple MenuBarExtra Docs | https://developer.apple.com/documentation/swiftui/menubarextra | Official API reference |
| Nil Coalescing Tutorial | https://nilcoalescing.com/blog/BuildAMacOSMenuBarUtilityInSwiftUI/ | Implementation guide |
| Sarunw Tutorial | https://sarunw.com/posts/swiftui-menu-bar-app/ | SwiftUI patterns |
| macOS 26 Permissions | https://allthings.how/use-the-enhanced-app-permissions-in-macos-26-tahoe/ | Permission system |

---

## 3. Required Project Structure

```
AppName/
├── AppName.xcodeproj/
├── AppName/
│   ├── AppNameApp.swift      # Main app entry point
│   ├── Info.plist            # CRITICAL: Must have LSUIElement=true
│   └── Assets.xcassets/
│       ├── Contents.json
│       ├── AccentColor.colorset/
│       │   └── Contents.json
│       └── AppIcon.appiconset/
│           └── Contents.json  # Icon files optional but recommended
└── README.md
```

---

## 4. Info.plist - MANDATORY Configuration

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key>
    <string>$(DEVELOPMENT_LANGUAGE)</string>
    <key>CFBundleExecutable</key>
    <string>$(EXECUTABLE_NAME)</string>
    <key>CFBundleIdentifier</key>
    <string>$(PRODUCT_BUNDLE_IDENTIFIER)</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleName</key>
    <string>$(PRODUCT_NAME)</string>
    <key>CFBundlePackageType</key>
    <string>$(PRODUCT_BUNDLE_PACKAGE_TYPE)</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0</string>
    <key>CFBundleVersion</key>
    <string>1</string>

    <!-- CRITICAL: Makes app a menu bar agent (no dock icon) -->
    <key>LSUIElement</key>
    <true/>

    <key>LSMinimumSystemVersion</key>
    <string>14.0</string>
    <key>LSApplicationCategoryType</key>
    <string>public.app-category.utilities</string>
</dict>
</plist>
```

**CRITICAL KEY:** `LSUIElement = true` - Without this, the app will show in the Dock instead of being menu-bar-only.

---

## 5. SwiftUI App Structure - EXACT Pattern

```swift
import SwiftUI

@main
struct MyMenuBarApp: App {
    // Use @State for simple state, @StateObject for ObservableObject
    @State private var someState = false

    var body: some Scene {
        // MenuBarExtra is the ONLY scene for pure menu bar apps
        MenuBarExtra {
            // Menu content goes here
            MenuContent(someState: $someState)
        } label: {
            // CRITICAL: Menu bar icon
            Image(systemName: "circle.fill")
                .renderingMode(.template)  // MANDATORY for proper rendering
        }
        .menuBarExtraStyle(.menu)  // Use .menu for simple dropdown, .window for rich UI
    }
}

struct MenuContent: View {
    @Binding var someState: Bool

    var body: some View {
        Button(someState ? "Stop" : "Start") {
            someState.toggle()
        }

        Divider()

        Button("Quit") {
            NSApp.terminate(nil)
        }
        .keyboardShortcut("q", modifiers: .command)
    }
}
```

---

## 6. Menu Bar Icon Requirements

### 6.1 SF Symbols (Recommended)
```swift
Image(systemName: "server.rack")
    .renderingMode(.template)  // MANDATORY
```

**CRITICAL:** `.renderingMode(.template)` is MANDATORY. Without it, the icon may not render correctly or at all in macOS 26's transparent menu bar.

### 6.2 Custom Images (Alternative)
If using custom images instead of SF Symbols:
- Size: 18x18pt (@1x), 36x36px (@2x)
- Format: PNG with transparency
- Color: Black pixels with alpha channel (template image)
- Asset catalog: Set "Render As" to "Template Image"

---

## 7. App Icon (System Settings Display)

### 7.1 Asset Catalog Structure
```
AppIcon.appiconset/
├── Contents.json
├── icon_16x16.png      (16x16)
├── icon_16x16@2x.png   (32x32)
├── icon_32x32.png      (32x32)
├── icon_32x32@2x.png   (64x64)
├── icon_128x128.png    (128x128)
├── icon_128x128@2x.png (256x256)
├── icon_256x256.png    (256x256)
├── icon_256x256@2x.png (512x512)
├── icon_512x512.png    (512x512)
└── icon_512x512@2x.png (1024x1024)
```

### 7.2 Creating .icns with iconutil
```bash
# Create iconset folder with properly named PNGs
mkdir MyApp.iconset
# Add all size variants...

# Convert to .icns
iconutil -c icns MyApp.iconset -o AppIcon.icns
```

**NOTE:** TahoeMenuDemo works WITHOUT app icon files. The gray box in System Settings is cosmetic and does NOT affect menu bar functionality.

---

## 8. Build Settings (xcconfig)

```
// Platform
MACOSX_DEPLOYMENT_TARGET = 14.0

// Info.plist Generation
GENERATE_INFOPLIST_FILE = YES
INFOPLIST_KEY_LSUIElement = YES
INFOPLIST_KEY_LSApplicationCategoryType = public.app-category.utilities

// Asset Catalog (optional, for app icon)
ASSETCATALOG_COMPILER_APPICON_NAME = AppIcon
ASSETCATALOG_COMPILER_INCLUDE_ALL_APPICON_ASSETS = YES
```

---

## 9. Code Signing

### 9.1 Development
```bash
codesign --force --deep --sign "Apple Development: email@example.com (TEAMID)" /path/to/App.app
```

### 9.2 Clear Quarantine (for local testing)
```bash
xattr -cr /path/to/App.app
```

### 9.3 Register with Launch Services
```bash
/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -f /path/to/App.app
```

---

## 10. macOS 26 Permission System

macOS 26 Tahoe introduced explicit menu bar permissions:

**Location:** System Settings → Menu Bar → "Allow in Menu Bar"

Apps must be toggled ON in this list to appear in the menu bar. If an app is running but not visible:
1. Check this setting
2. Toggle OFF then ON
3. If app not listed, restart SystemUIServer: `killall SystemUIServer`

---

## 11. Known Issues & Solutions

### Issue: Menu bar icon not appearing
**Causes:**
1. Missing `.renderingMode(.template)` on Image
2. Heavy initialization blocking MenuBarExtra
3. macOS 26 permission not enabled
4. **Bundle ID caching** - macOS caches permission states by bundle ID

**Solutions:**
1. Add `.renderingMode(.template)` to all menu bar icons
2. Defer heavy work (Process calls, network, etc.) to after app appears
3. Check System Settings → Menu Bar
4. If bundle ID has cached "hidden" state, change bundle ID temporarily

### Issue: Menu bar icon hidden behind MacBook notch
**Cause:** MacBook Pro models have a camera notch that can hide menu bar items
**Solution:** Reposition menu bar icon using Command+drag, or use `menuBarExtraStyle(.window)` with `.autosaveName()` to persist position

### Issue: App crashes immediately after launch with sandbox
**Cause:** App uses `Process()` to run shell commands but has sandbox enabled
**Solution:** Disable sandbox by setting `com.apple.security.app-sandbox` to `false` in entitlements:
```xml
<key>com.apple.security.app-sandbox</key>
<false/>
```

### Issue: Bundle ID permission caching
**Cause:** macOS 26 caches the "Show in Menu Bar" toggle state by bundle ID. If a previous version was set to hidden, new builds inherit this state.
**Solution:**
1. Change bundle ID temporarily (e.g., add suffix `2`)
2. Or clear the cache: Reset NSStatusItem states (requires more investigation)

### Issue: Gray box icon in System Settings
**Cause:** Missing or invalid app icon in asset catalog
**Solution:** Either add valid icons OR ignore (cosmetic only, doesn't affect functionality)

### Issue: Window appears behind other apps
**Cause:** Menu bar apps are background processes
**Solution:** Call `NSApp.activate(ignoringOtherApps: true)` before showing windows

### Issue: Process detection false positives
**Cause:** Using `pgrep -f "name"` matches any process containing the substring
**Solution:** Use more specific patterns or combine with port checking for accuracy

---

## 12. Verification Checklist

Before declaring implementation complete:

- [x] App process runs (verify with `pgrep -fl AppName`)
- [x] Menu bar icon visible in status area (top right)
- [x] Icon renders correctly in light mode
- [x] Icon renders correctly in dark mode
- [x] Clicking icon shows dropdown menu/popover
- [x] Menu items respond to clicks
- [x] Quit menu item terminates app
- [x] App listed in System Settings → Menu Bar
- [x] App permission toggle is ON

**USM Verification (January 4, 2026):** All items verified working

---

## 13. Rich Window Style Example

For apps requiring complex UI with inline buttons, metrics, and custom layouts, use `.menuBarExtraStyle(.window)`:

```swift
@main
struct RichMenuBarApp: App {
    @StateObject private var manager = ServiceManager()

    var body: some Scene {
        MenuBarExtra {
            PopoverContent(manager: manager)
        } label: {
            Image(systemName: "server.rack")
                .renderingMode(.template)
        }
        .menuBarExtraStyle(.window)  // Enables rich SwiftUI content

        Settings {
            Text("Settings")
        }
    }
}

struct PopoverContent: View {
    @ObservedObject var manager: ServiceManager

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack {
                Text("Services")
                    .font(.headline)
                Spacer()
                Button(action: { manager.refresh() }) {
                    Image(systemName: "arrow.clockwise")
                }
                .buttonStyle(.borderless)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)

            Divider()

            // Service rows with inline buttons
            ForEach(manager.services) { service in
                HStack(spacing: 8) {
                    Circle()
                        .fill(service.isRunning ? .green : .red)
                        .frame(width: 8, height: 8)
                    Text(service.name)
                    Spacer()
                    Button(action: { manager.start(service.id) }) {
                        Image(systemName: "play.fill")
                    }
                    .buttonStyle(.borderless)
                    .disabled(service.isRunning)
                    .opacity(service.isRunning ? 0.3 : 1.0)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
            }

            Divider()

            // Footer with quit
            HStack {
                Spacer()
                Button("Quit") { NSApp.terminate(nil) }
                    .buttonStyle(.borderless)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
        }
        .frame(width: 400)
    }
}
```

**Key differences from `.menu` style:**
- Full SwiftUI view support (not limited to Menu items)
- Custom button styles and layouts
- Inline metrics and status indicators
- Fixed width for consistent appearance

---

## 14. Minimal Working Example (`.menu` style)

This is the absolute minimum code for a working macOS 26 menu bar app:

**AppNameApp.swift:**
```swift
import SwiftUI

@main
struct MinimalMenuBarApp: App {
    var body: some Scene {
        MenuBarExtra {
            Button("Quit") {
                NSApp.terminate(nil)
            }
        } label: {
            Image(systemName: "circle.fill")
                .renderingMode(.template)
        }
        .menuBarExtraStyle(.menu)
    }
}
```

**Info.plist:**
```xml
<key>LSUIElement</key>
<true/>
```

That's it. No other configuration required for basic functionality.

---

## 15. References

1. Apple Developer Documentation: MenuBarExtra
   https://developer.apple.com/documentation/swiftui/menubarextra

2. TahoeMenuDemo GitHub Repository
   https://github.com/sjhooper/TahoeMenuDemo

3. macOS Tahoe Menu Bar Permissions
   https://badgeify.app/how-to-add-remove-icons-from-menu-bar-macos-tahoe/

4. Maccy Issue #1224 (macOS 26 menu bar issues)
   https://github.com/p0deje/Maccy/issues/1224

5. Peter Steinberger: Showing Settings from Menu Bar Items
   https://steipete.me/posts/2025/showing-settings-from-macos-menu-bar-items
