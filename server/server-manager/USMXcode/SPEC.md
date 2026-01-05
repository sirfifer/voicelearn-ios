# USM (UnaMentis Server Manager) - Technical Specification

## Overview
Menu bar app for macOS 26 to manage UnaMentis server components.

---

## CONFIRMED REQUIREMENTS (DO NOT CHANGE)

### Info.plist - LOCKED
- `LSUIElement` = `true` - Required for menu bar-only apps (no dock icon)
- `CFBundleIconFile` = `AppIcon` - References the .icns file
- `CFBundleIconName` = `AppIcon` - References asset catalog icon

### Menu Bar Icon - LOCKED
- **Type**: Template image (monochrome)
- **Rendering**: System handles tinting (white on dark, black on light)
- **SF Symbol**: `server.rack` - Known working, use this
- **Code**: `Image(systemName: "server.rack")` - No .renderingMode needed for SF Symbols

### App Icon (System Settings/Finder) - LOCKED
- **Format**: .icns file created with `iconutil`
- **Location**: `Contents/Resources/AppIcon.icns`
- **Sizes required** (iconset folder naming):
  - icon_16x16.png (16x16)
  - icon_16x16@2x.png (32x32)
  - icon_32x32.png (32x32)
  - icon_32x32@2x.png (64x64)
  - icon_128x128.png (128x128)
  - icon_128x128@2x.png (256x256)
  - icon_256x256.png (256x256)
  - icon_256x256@2x.png (512x512)
  - icon_512x512.png (512x512)
  - icon_512x512@2x.png (1024x1024)
- **Creation**: `iconutil -c icns /path/to/App.iconset -o AppIcon.icns`

### Build Settings (xcconfig) - LOCKED
```
GENERATE_INFOPLIST_FILE = YES
INFOPLIST_KEY_LSUIElement = YES
INFOPLIST_KEY_LSApplicationCategoryType = public.app-category.utilities
ASSETCATALOG_COMPILER_APPICON_NAME = AppIcon
ASSETCATALOG_COMPILER_INCLUDE_ALL_APPICON_ASSETS = YES
```

### Code Signing - LOCKED
- Must use Apple Developer certificate (not ad-hoc)
- Command: `codesign --force --deep --sign "Apple Development: <email> (<ID>)" <app>`
- Clear quarantine: `xattr -cr <app>`
- Register: `lsregister -f <app>`

---

## CURRENT STATUS

### Working
- [ ] App builds successfully
- [ ] App runs (process visible)
- [ ] LSUIElement=true in Info.plist

### NOT Working (needs debugging)
- [ ] Menu bar icon not visible
- [ ] App icon shows as gray box in System Settings

---

## DEBUGGING NEEDED

### Issue 1: Menu bar icon not showing
- App process runs but no icon in menu bar
- SF Symbol should work - need to verify MenuBarExtra is functioning

### Issue 2: App icon gray box in Settings
- .icns file exists (47KB)
- May be caching issue or file corruption
- Need to verify .icns is valid

---

## Services to Manage
1. Log Server (port 8765) - `python3 scripts/log_server.py`
2. Management API (port 8766) - `python3 management/server.py`
3. Web Server (port 3000) - `npm run serve`
4. Ollama (port 11434) - `ollama serve`
