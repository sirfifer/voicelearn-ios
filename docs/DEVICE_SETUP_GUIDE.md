# UnaMentis Device Setup Guide

**Complete guide for running UnaMentis on your iPhone with local on-device speech recognition.**

---

## Table of Contents

1. [Prerequisites](#1-prerequisites)
2. [Building for Device](#2-building-for-device)
3. [Installing on iPhone](#3-installing-on-iphone)
4. [Local Model Setup (On-Device GLM-ASR)](#4-local-model-setup-on-device-glm-asr)
5. [Using the App](#5-using-the-app)
6. [Troubleshooting](#6-troubleshooting)

---

## 1. Prerequisites

### Hardware Requirements

| Requirement | Minimum | Recommended |
|-------------|---------|-------------|
| **iPhone Model** | iPhone 15 Pro | iPhone 16 Pro Max / 17 Pro Max |
| **RAM** | 8GB | 12GB |
| **Storage** | 5GB free | 10GB free |
| **iOS Version** | iOS 18.0 | iOS 18.0+ |

**Important**: On-device GLM-ASR requires an A17 Pro chip or later (8GB+ RAM). Older devices will use server-based STT.

### Software Requirements

- **macOS**: 14.0+ (Sonoma or later)
- **Xcode**: 15.4+
- **Apple Developer Account**: Free or paid (for device deployment)
- **iPhone configured as developer device**

### Developer Device Setup

If your iPhone isn't already set up as a developer device:

1. **On iPhone**: Settings → Privacy & Security → Developer Mode → Enable
2. **In Xcode**: Window → Devices and Simulators → Add your iPhone
3. **Trust Computer**: When prompted on iPhone, tap "Trust"

---

## 2. Building for Device

### Option A: Using Xcode (Recommended)

```bash
# Open the project in Xcode
open /Users/ramerman/dev/voicelearn-ios/Package.swift
```

1. Select your iPhone from the device dropdown (top of Xcode window)
2. Click **Product → Build** (⌘+B)
3. Wait for build to complete

### Option B: Using Command Line

```bash
# List available devices
xcrun xctrace list devices

# Build for your device (replace with your device name)
xcodebuild build \
    -scheme UnaMentis \
    -destination 'platform=iOS,name=Your iPhone Name' \
    -configuration Release
```

### Signing Configuration

For device deployment, you need code signing:

1. **In Xcode**: Select UnaMentis target → Signing & Capabilities
2. **Team**: Select your Apple ID / Developer Team
3. **Bundle Identifier**: Change to unique ID (e.g., `com.yourname.voicelearn`)
4. **Automatically manage signing**: Enable

---

## 3. Installing on iPhone

### Method 1: Xcode Direct Install (Easiest)

1. Connect iPhone via USB
2. In Xcode, select your iPhone from device dropdown
3. Click **Run** (⌘+R)
4. App installs and launches on device

### Method 2: Export and Install

1. **Archive**: Product → Archive
2. **Distribute**: Organize → Distribute App → Ad Hoc
3. **Install**: Use Apple Configurator or Finder to install the .ipa

### First Launch

On first launch, you may need to:

1. **Trust Developer**: Settings → General → VPN & Device Management → Trust "Developer App"
2. **Grant Microphone Access**: The app will prompt for microphone permission

---

## 4. Local Model Setup (On-Device GLM-ASR)

### Model Files Required

For fully on-device speech recognition, you need these model files:

| Model | Size | Purpose |
|-------|------|---------|
| GLMASRWhisperEncoder.mlpackage | 1.2 GB | Audio encoding (CoreML) |
| GLMASRAudioAdapter.mlpackage | 56 MB | Audio adaptation (CoreML) |
| GLMASREmbedHead.mlpackage | 232 MB | Embedding head (CoreML) |
| glm-asr-nano-q4km.gguf | 935 MB | Text decoder (llama.cpp) |

**Total: ~2.4 GB**

### Step 1: Download Models

```bash
# Create models directory
mkdir -p /Users/ramerman/dev/voicelearn-ios/models/glm-asr-nano

# Download from Hugging Face (example)
# Visit: https://huggingface.co/zai-org/GLM-ASR-Nano-2512
# Download all model files to the models directory
```

### Step 2: Add Models to Xcode Project

1. **In Xcode**: Right-click on UnaMentis folder
2. **Add Files to UnaMentis...**
3. **Select** all model files from `models/glm-asr-nano/`
4. **Options**:
   - ✅ Copy items if needed
   - ✅ Add to targets: UnaMentis
5. **Click Add**

### Step 3: Configure Build Phase

1. Select UnaMentis target
2. Go to **Build Phases**
3. Expand **Copy Bundle Resources**
4. Verify all .mlpackage and .gguf files are listed

### Step 4: Enable llama.cpp

The on-device decoder requires llama.cpp with the `LLAMA_AVAILABLE` flag:

In Package.swift or Xcode build settings:
```swift
// Swift settings
swiftSettings: [
    .define("LLAMA_AVAILABLE")
]
```

### Without Local Models

If you don't add the models, the app will:
- Fall back to **server-based GLM-ASR** (requires server URL)
- Or fall back to **Deepgram** (requires API key)

---

## 5. Using the App

### First-Time Setup

1. **Launch the app** on your iPhone
2. **Grant microphone permission** when prompted
3. **Navigate to Settings tab**

### Loading Sample Curriculum

1. Go to **Settings** tab
2. Scroll to **Debug & Testing** section
3. Tap **Load Sample Curriculum**
4. Go to **Curriculum** tab to see PyTorch Fundamentals curriculum

### Starting a Voice Session

1. Select a topic from the **Curriculum** tab
2. Tap the topic to start studying
3. Navigate to **Session** tab
4. The voice session interface shows:
   - Transcript area
   - Recording indicator
   - Session controls

### Configuring Providers

In **Settings** tab:

**For Local Mode (No Internet)**:
- On-device models must be installed
- No API keys needed

**For Server Mode**:
- Configure `GLM_ASR_SERVER_URL` (environment or settings)
- Or add Deepgram API key for fallback

**For Cloud Mode**:
- Add API keys for Deepgram, ElevenLabs, Anthropic/OpenAI

### Monitoring Performance

Check **Analytics** tab for:
- STT latency (target: <300ms)
- LLM latency (target: <200ms TTFT)
- TTS latency (target: <200ms TTFB)
- End-to-end latency (target: <500ms)
- Cost tracking

---

## 6. Troubleshooting

### Build Issues

**"Signing certificate not found"**
- Ensure you're signed into Xcode with Apple ID
- Try: Xcode → Preferences → Accounts → Download Manual Profiles

**"Device not found"**
- Ensure iPhone is unlocked
- Trust the computer on iPhone
- Try unplugging and reconnecting

**"Core Data model assertion"**
- This is a warning, not an error
- Build should still succeed

### Runtime Issues

**App crashes on launch**
- Check device meets minimum requirements (A17 Pro chip)
- Ensure iOS 18.0+
- Check Console.app for crash logs

**Microphone not working**
- Settings → UnaMentis → Microphone → Enable
- Restart the app

**Models not loading**
- Verify models are in app bundle (not just project)
- Check device has sufficient storage
- Check Console.app for loading errors

**High latency**
- Ensure device isn't thermally throttling
- Close other apps
- Check network if using server mode

### Performance Optimization

**For best on-device performance**:
1. Keep device cool (avoid direct sunlight, remove case)
2. Ensure 50%+ battery
3. Close background apps
4. Use airplane mode to prevent network interference

**Thermal throttling handling**:
- The app automatically switches to server mode if device overheats
- Performance recovers when device cools down

---

## Quick Reference

### Key File Locations

| Item | Path |
|------|------|
| Project | `/Users/ramerman/dev/voicelearn-ios/` |
| Package.swift | `/Users/ramerman/dev/voicelearn-ios/Package.swift` |
| Models directory | `/Users/ramerman/dev/voicelearn-ios/models/glm-asr-nano/` |
| Core Data model | `UnaMentis/UnaMentis.xcdatamodeld` |
| On-device service | `UnaMentis/Services/STT/GLMASROnDeviceSTTService.swift` |

### Build Commands

```bash
# SPM build (macOS)
swift build

# Xcode build for device
xcodebuild -scheme UnaMentis -destination 'platform=iOS,name=YOUR_IPHONE'

# List simulators
xcrun simctl list devices

# List physical devices
xcrun xctrace list devices
```

### Environment Variables

| Variable | Purpose |
|----------|---------|
| `GLM_ASR_SERVER_URL` | WebSocket URL for server-based GLM-ASR |
| `GLM_ASR_AUTH_TOKEN` | Optional auth token for server |
| `DEEPGRAM_API_KEY` | Deepgram API key (fallback STT) |
| `ELEVENLABS_API_KEY` | ElevenLabs API key (TTS) |
| `ANTHROPIC_API_KEY` | Anthropic API key (LLM) |
| `OPENAI_API_KEY` | OpenAI API key (LLM) |

---

## Related Documentation

- [GLM_ASR_ON_DEVICE_GUIDE.md](GLM_ASR_ON_DEVICE_GUIDE.md) - Detailed on-device implementation
- [QUICKSTART.md](QUICKSTART.md) - Quick start guide
- [SETUP.md](SETUP.md) - Development environment setup
- [AI_SIMULATOR_TESTING.md](AI_SIMULATOR_TESTING.md) - AI-driven testing

---

**Last Updated**: December 2025
