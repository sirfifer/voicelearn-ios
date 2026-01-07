# Apple Watch App Testing Guide

This document describes how to test the UnaMentis Apple Watch companion app using simulators and real devices.

## Simulator Testing (Recommended for Development)

### Prerequisites

- Xcode with watchOS 26+ simulator support
- iOS 26+ and watchOS 26+ simulators installed

### Step 1: Pair iPhone and Watch Simulators

The iOS and Watch simulators can be paired to enable WatchConnectivity communication.

```bash
# List available simulators
xcrun simctl list devices

# Pair Watch simulator with iPhone simulator
# Format: xcrun simctl pair <watch-udid> <iphone-udid>
xcrun simctl pair 7559430D-2C14-4286-8883-3D5B5AAB5A9A F5BC44F3-65B1-4822-84F0-62D8D5449297

# Verify pairing
xcrun simctl list pairs
```

Expected output:
```
== Device Pairs ==
D20A094C-6FFC-4E48-89D2-35FC9D164E2D (active, connected)
    Watch: Apple Watch Series 11 (46mm) (7559430D-...) (Booted)
    Phone: iPhone 17 Pro (F5BC44F3-...) (Booted)
```

### Step 2: Boot Both Simulators

```bash
# Boot iPhone simulator
xcrun simctl boot F5BC44F3-65B1-4822-84F0-62D8D5449297

# Boot Watch simulator
xcrun simctl boot 7559430D-2C14-4286-8883-3D5B5AAB5A9A

# Open Simulator app to see both
open -a Simulator
```

### Step 3: Build and Install Apps

**Option A: Using Xcode**
1. Open `UnaMentis.xcodeproj`
2. Select "UnaMentis" scheme, target iPhone simulator
3. Build and Run (Cmd+R)
4. Switch to "UnaMentis Watch App" scheme, target Watch simulator
5. Build and Run (Cmd+R)

**Option B: Using Command Line**
```bash
# Build and run iOS app
xcodebuild -project UnaMentis.xcodeproj -scheme UnaMentis \
  -destination 'platform=iOS Simulator,id=F5BC44F3-65B1-4822-84F0-62D8D5449297' \
  build

# Install iOS app
xcrun simctl install F5BC44F3-65B1-4822-84F0-62D8D5449297 \
  ~/Library/Developer/Xcode/DerivedData/UnaMentis-*/Build/Products/Debug-iphonesimulator/UnaMentis.app

# Build Watch app
xcodebuild -project UnaMentis.xcodeproj -scheme "UnaMentis Watch App" \
  -destination 'platform=watchOS Simulator,id=7559430D-2C14-4286-8883-3D5B5AAB5A9A' \
  build

# Install Watch app
xcrun simctl install 7559430D-2C14-4286-8883-3D5B5AAB5A9A \
  ~/Library/Developer/Xcode/DerivedData/UnaMentis-*/Build/Products/Debug-watchsimulator/UnaMentis\ Watch\ App.app
```

### Step 4: Test WatchConnectivity

1. **Launch both apps**
   - On iPhone: Launch UnaMentis
   - On Watch: Launch UnaMentis Watch App

2. **Verify idle state**
   - Watch should show "No Active Session" (without "iPhone Not Reachable" message)
   - This confirms WatchConnectivity is established

3. **Start a session on iPhone**
   - Tap the microphone button to start a voice session
   - Grant Speech Recognition permission when prompted

4. **Verify Watch receives state**
   - Watch should update to show:
     - Session mode (e.g., "Voice Chat")
     - Progress ring (0%)
     - Control buttons (Mute, Pause, Stop)

### Step 5: Test Control Buttons

**Note:** Button taps at the bottom edge of the Watch simulator may trigger system gestures. For reliable button testing, use real hardware.

Testing approach in simulator:
1. Start a session on iPhone
2. Verify Watch shows active session state
3. Tap control buttons on Watch
4. Verify iPhone responds to commands

## Real Device Testing

### Prerequisites

1. iPhone with Developer Mode enabled
2. Apple Watch paired with the iPhone
3. Apple Watch with Developer Mode enabled

### Enabling Developer Mode on Apple Watch

Developer Mode only appears after Xcode has "prepared" the Watch:

1. Connect iPhone to Mac via cable
2. Open Xcode > Window > Devices and Simulators
3. Select your iPhone - the paired Watch should appear below it
4. Wait for Xcode to "prepare" the Watch (may take several minutes)
5. On Watch: Settings > Privacy & Security > Developer Mode > Enable
6. Restart Watch when prompted

### Deploying to Devices

1. In Xcode, select your physical iPhone as the run destination
2. Build and Run the "UnaMentis" scheme
3. The Watch app automatically installs on the paired Watch

### Testing Checklist

- [ ] Watch app auto-installs with iOS app
- [ ] Watch shows "No Active Session" when iPhone app is idle
- [ ] Starting a session on iPhone updates Watch to show:
  - [ ] Session mode (Voice Chat/Lesson/Lecture)
  - [ ] Progress ring with percentage
  - [ ] Control buttons
- [ ] Mute button toggles microphone on iPhone
- [ ] Pause button pauses session on iPhone
- [ ] Resume button resumes paused session
- [ ] Stop button ends session on iPhone
- [ ] Watch returns to idle state when session ends
- [ ] Connection status updates when iPhone becomes unreachable

## Screenshots

Screenshots from simulator testing are stored in this directory:

| Screenshot | Description |
|------------|-------------|
| `04-watch-app-idle.png` | Watch idle state (no active session) |
| `10-watch-sync-check.png` | Watch showing active session from iOS |
| `13-watch-relaunched.png` | Watch with session controls visible |

## Troubleshooting

### Watch shows "iPhone Not Reachable"

- Verify simulators are paired: `xcrun simctl list pairs`
- Re-pair if needed: `xcrun simctl pair <watch-udid> <iphone-udid>`
- Restart both simulators

### WatchConnectivity not working

- Ensure both apps have WCSession activated
- Check that bundle IDs match:
  - iOS: `com.unamentis.app`
  - Watch: `com.unamentis.app.watchkitapp`
- Verify `WKCompanionAppBundleIdentifier` in Watch Info.plist

### Watch app not receiving state updates

- Verify `updateApplicationContext` is being called on iOS
- Check iOS console for WatchConnectivity errors
- Ensure Watch app has activated its WCSession

## Demo Mode (Simulator Only)

For screenshots and demos without a real session, use the debug mode:

1. Build with DEBUG configuration
2. Triple-tap on the Watch idle screen
3. Watch shows mock active session state
4. Triple-tap again to return to idle

This is only available in DEBUG builds and won't appear on production devices.
