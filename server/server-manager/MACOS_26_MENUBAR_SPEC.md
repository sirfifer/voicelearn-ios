# macOS 26 (Tahoe) Menu Bar App Specification

**Version:** 1.0
**Created:** 2026-01-04
**Purpose:** Definitive specification for building working menu bar apps on macOS 26 Tahoe

---

## Executive Summary

macOS 26 Tahoe introduces significant changes to menu bar app behavior:

1. **New Permission System**: Apps must be explicitly allowed in System Settings > Menu Bar
2. **Apps May Be Disabled by Default**: Some apps appear disabled in the "Allow in Menu Bar" list
3. **SystemUIServer Corruption**: Preference file corruption can prevent icons from appearing
4. **Gray Box Icon Issue**: Non-squircle app icons are placed in a gray box in System Settings

---

## Critical Issue: Your App is Probably Working

Based on research, the most likely cause of your menu bar icon not appearing is:

**The app is disabled in System Settings > Menu Bar > "Allow in Menu Bar"**

### Immediate Fix to Try

1. Open **System Settings** (Apple menu > System Settings)
2. Navigate to **Menu Bar** (may also be under Privacy & Security)
3. Scroll to **"Allow in Menu Bar"** section
4. Find your app (USM / UnaMentis Server Manager)
5. **Toggle it ON**

If the app appears with a gray box icon, this is the macOS 26 squircle enforcement issue (cosmetic, not functional).

---

## Root Causes Analysis

### Issue 1: Menu Bar Permission System (macOS 26+)

macOS Tahoe introduces granular control over which apps can display menu bar icons:

- Location: **System Settings > Menu Bar > Allow in Menu Bar**
- Each app has an individual toggle
- Apps may appear disabled by default for newly installed apps
- There is NO API for apps to detect if they are hidden

**Evidence**: [Maccy issue #1224](https://github.com/p0deje/Maccy/issues/1224) confirms this exact behavior.

### Issue 2: SystemUIServer Corruption

During macOS updates, the SystemUIServer preference file can become corrupted:

**Fix:**
```bash
# Backup and reset SystemUIServer preferences
mv ~/Library/Preferences/com.apple.systemuiserver.plist ~/Library/Preferences/com.apple.systemuiserver.plist.backup
killall SystemUIServer

# If that doesn't work, also reset Control Center
killall ControlStrip SystemUIServer
mv ~/Library/Preferences/com.apple.controlcenter.plist ~/Library/Preferences/com.apple.controlcenter.plist.backup
killall ControlCenter SystemUIServer
```

**Source**: [Tongfamily fix guide](https://tongfamily.com/2025/10/29/mac-fix-tahoe-menubar-missing-3rd-party-apps/)

### Issue 3: Gray Box App Icon

macOS 26 enforces squircle icons. Non-compliant icons appear in a gray rounded rectangle.

**This is cosmetic only** and does not prevent the menu bar icon from appearing.

---

## Implementation Requirements

### Minimum Requirements (All Must Be Met)

#### 1. Info.plist Configuration

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <!-- REQUIRED: Hide from Dock -->
    <key>LSUIElement</key>
    <true/>

    <!-- REQUIRED: Bundle identifier -->
    <key>CFBundleIdentifier</key>
    <string>com.yourcompany.yourapp</string>

    <!-- REQUIRED: App name -->
    <key>CFBundleName</key>
    <string>YourApp</string>

    <!-- RECOMMENDED: Category -->
    <key>LSApplicationCategoryType</key>
    <string>public.app-category.utilities</string>

    <!-- RECOMMENDED: High resolution -->
    <key>NSHighResolutionCapable</key>
    <true/>
</dict>
</plist>
```

If using xcconfig with `GENERATE_INFOPLIST_FILE = YES`:
```
INFOPLIST_KEY_LSUIElement = YES
INFOPLIST_KEY_LSApplicationCategoryType = public.app-category.utilities
```

#### 2. App Structure (SwiftUI)

**CRITICAL**: The MenuBarExtra scene structure matters.

**Working Pattern:**
```swift
import SwiftUI

@main
struct MyMenuBarApp: App {
    var body: some Scene {
        MenuBarExtra {
            MenuContent()
        } label: {
            // Option A: SF Symbol (RECOMMENDED for reliability)
            Image(systemName: "server.rack")
                .renderingMode(.template)

            // Option B: Custom image from Assets
            // Image("MenuBarIcon")
            //     .renderingMode(.template)
        }
        .menuBarExtraStyle(.menu)  // or .window for popover
    }
}
```

**Key Points:**
- Use `.renderingMode(.template)` for automatic light/dark mode adaptation
- SF Symbols are more reliable than custom images
- The label is what appears in the menu bar

#### 3. Menu Bar Icon Requirements (if using custom image)

**Asset Catalog Configuration** (Assets.xcassets/MenuBarIcon.imageset/Contents.json):
```json
{
  "images": [
    { "filename": "menubar.png", "idiom": "mac", "scale": "1x" },
    { "filename": "menubar@2x.png", "idiom": "mac", "scale": "2x" }
  ],
  "info": { "author": "xcode", "version": 1 },
  "properties": {
    "template-rendering-intent": "template"
  }
}
```

**Image Requirements:**
- 1x: 18x18 pixels (or 16x16 to 22x22 range)
- 2x: 36x36 pixels
- Format: PNG with transparency
- Colors: Black and clear ONLY for template images
- DPI: 72 (standard, not 144)

#### 4. Entitlements (Minimal for Menu Bar Apps)

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>com.apple.security.app-sandbox</key>
    <true/>
</dict>
</plist>
```

**Note**: For menu bar apps that need to run shell commands (like your service manager), you may need to disable sandboxing or add specific entitlements.

---

## Verification Checklist

### Pre-Build Verification

- [ ] Info.plist has `LSUIElement = YES` (or xcconfig equivalent)
- [ ] MenuBarExtra is the primary/only scene (no WindowGroup)
- [ ] Icon uses `.renderingMode(.template)`
- [ ] If using custom icon: Asset catalog has `template-rendering-intent: template`
- [ ] No file extension in image name references

### Post-Build Verification

1. **Build and run the app**
2. **Check Activity Monitor** - app should appear in process list
3. **Check System Settings > Menu Bar > Allow in Menu Bar**
   - App should appear in the list
   - Toggle should be ON
   - If toggle is OFF, turn it ON
4. **If icon still not visible**, run:
   ```bash
   killall SystemUIServer
   ```
5. **Relaunch the app**

### Debug Commands

```bash
# Check if app is running
pgrep -fl "USM"

# Check lsregister for the app
/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -dump | grep -i "com.unamentis.server-manager"

# Reset SystemUIServer
killall SystemUIServer

# Nuclear option: reset all menu bar preferences
mv ~/Library/Preferences/com.apple.systemuiserver.plist ~/Library/Preferences/com.apple.systemuiserver.plist.backup
mv ~/Library/Preferences/com.apple.controlcenter.plist ~/Library/Preferences/com.apple.controlcenter.plist.backup
killall ControlCenter SystemUIServer Dock
```

---

## Common Failure Modes

### 1. App Running But No Icon

**Symptoms:** App visible in Activity Monitor, no menu bar icon

**Causes & Solutions:**
| Cause | Solution |
|-------|----------|
| Disabled in System Settings | Enable in System Settings > Menu Bar |
| SystemUIServer corruption | Run `killall SystemUIServer` |
| MenuBarExtra not rendering | Check scene structure, ensure no WindowGroup |
| Image loading failure | Use SF Symbol instead of custom image |

### 2. Gray Box Icon in System Settings

**Cause:** App icon not in squircle format

**Solution:** This is cosmetic. The menu bar functionality is unaffected. To fix the appearance:
- Create a 1024x1024 squircle-compliant icon
- Use Icon Composer or similar tool for macOS 26

### 3. Icon Appears Then Disappears

**Symptoms:** Icon briefly shows then vanishes

**Causes & Solutions:**
| Cause | Solution |
|-------|----------|
| App crash on launch | Check Console.app for crash logs |
| Memory issue | Ensure MenuBarExtra retained (not local variable) |
| macOS Sequoia bug | Move cursor away from icon when it closes |

### 4. Menu Opens Behind Other Windows

**Cause:** Menu bar apps lack proper activation context

**Solution:** Add activation before showing windows:
```swift
NSApp.activate(ignoringOtherApps: true)
```

---

## Known Working Code Pattern (macOS 26)

```swift
import SwiftUI

@main
struct WorkingMenuBarApp: App {
    var body: some Scene {
        MenuBarExtra {
            VStack {
                Text("My Menu Bar App")
                    .font(.headline)

                Divider()

                Button("Action 1") {
                    print("Action 1")
                }

                Button("Action 2") {
                    print("Action 2")
                }

                Divider()

                Button("Quit") {
                    NSApp.terminate(nil)
                }
                .keyboardShortcut("q")
            }
        } label: {
            Image(systemName: "star.fill")
                .renderingMode(.template)
        }
        .menuBarExtraStyle(.menu)
    }
}
```

**This pattern is confirmed working on macOS 26 when:**
1. LSUIElement is set
2. The app is enabled in System Settings > Menu Bar
3. SystemUIServer is not corrupted

---

## Your Current Implementation Analysis

### USMApp.swift Review

Your current implementation looks correct:

```swift
MenuBarExtra {
    MenuContent(serviceManager: serviceManager)
} label: {
    Image(systemName: "server.rack")
        .renderingMode(.template)
}
.menuBarExtraStyle(.menu)
```

**This should work.** The issue is likely:

1. **Most Probable**: App disabled in System Settings > Menu Bar
2. **Second Most Probable**: SystemUIServer preferences corrupted
3. **Less Likely**: Build configuration issue

### Recommended Actions

1. **First**: Check System Settings > Menu Bar > Allow in Menu Bar
2. **If app not listed**: Run `killall SystemUIServer` and relaunch app
3. **If still not working**: Reset SystemUIServer preferences (see commands above)
4. **If still not working**: Verify the built app bundle has correct Info.plist:
   ```bash
   plutil -p /path/to/USM.app/Contents/Info.plist | grep -i uielement
   ```

---

## References

- [Maccy Issue #1224: Menu bar icon missing in macOS 26.0.1](https://github.com/p0deje/Maccy/issues/1224)
- [Fix Tahoe menubar missing 3rd party apps](https://tongfamily.com/2025/10/29/mac-fix-tahoe-menubar-missing-3rd-party-apps/)
- [Showing Settings from macOS Menu Bar Items](https://steipete.me/posts/2025/showing-settings-from-macos-menu-bar-items)
- [How to Add/Remove Icons from Menu Bar on macOS Tahoe](https://badgeify.app/how-to-add-remove-icons-from-menu-bar-macos-tahoe/)
- [Enhanced App Permissions in macOS 26 Tahoe](https://allthings.how/use-the-enhanced-app-permissions-in-macos-26-tahoe/)
- [Build a macOS menu bar utility in SwiftUI](https://nilcoalescing.com/blog/BuildAMacOSMenuBarUtilityInSwiftUI/)
- [Create a mac menu bar app in SwiftUI with MenuBarExtra](https://sarunw.com/posts/swiftui-menu-bar-app/)
- [Apple Developer: MenuBarExtra Documentation](https://developer.apple.com/documentation/swiftui/menubarextra)
