# iOS App Demo Video Automation System

## Executive Summary

This document describes a fully automated pipeline for generating iOS app demo videos. The system captures screenshots or video from the iOS Simulator, generates voice narration, and assembles everything into a professional demo video - all programmatically, with no manual intervention required.

**Key insight**: By combining Apple's native simulator tools (`xcrun simctl`) with cloud-based video assembly APIs (Shotstack), we can create a CI/CD-style pipeline where demo videos are regenerated automatically whenever the app's UI changes.

**Cost**: Approximately $0.40-0.80 per minute of final video. No ongoing subscription required - pay only for what you render.

---

## Table of Contents

1. [Problem Statement](#problem-statement)
2. [Research Findings](#research-findings)
3. [Architecture Overview](#architecture-overview)
4. [Component Deep Dives](#component-deep-dives)
5. [API Reference](#api-reference)
6. [Configuration Patterns](#configuration-patterns)
7. [Extension Points](#extension-points)
8. [Integration Strategies](#integration-strategies)
9. [Troubleshooting](#troubleshooting)
10. [Cost Analysis](#cost-analysis)
11. [Future Considerations](#future-considerations)

---

## Problem Statement

### The Challenge

Creating demo videos for iOS apps is traditionally:
- **Manual**: Screen recording, editing, re-recording when UI changes
- **Time-consuming**: Hours of work for a few minutes of polished video
- **Fragile**: Videos become outdated as the app evolves
- **Inconsistent**: Different people create videos differently

### Requirements

1. **100% Automation**: No manual steps - trigger and walk away
2. **Repeatability**: Same inputs produce same outputs
3. **Flexibility**: Support different narratives, flows, and audiences
4. **Quality**: Professional-looking output suitable for App Store, marketing, stakeholders
5. **Cost-effective**: Not enterprise pricing for indie/small team use
6. **Integratable**: Works with CI/CD, can be triggered by code changes

### Constraints

- Must work with iOS Simulator (not physical devices)
- Should leverage existing tools where possible
- Voice narration needed (but can use local TTS, not cloud services)
- Output: Standard video formats (MP4, etc.)

---

## Research Findings

### Tools Evaluated

We evaluated 25+ tools across several categories. Here are the key findings:

#### Video Editing APIs (Fully Automatable)

| Tool | API Quality | Pricing | Verdict |
|------|-------------|---------|---------|
| **Shotstack** | Excellent REST API, JSON timeline | $0.40/min PAYG | ✅ **SELECTED** |
| JSON2Video | Good REST API | Credit-based | Alternative |
| Creatomate | Good REST API | Credit-based | Alternative |
| Plainly | After Effects-based | $69+/mo | Overkill for this use case |

**Why Shotstack?**
- Pure REST API with JSON-based timeline definition
- No subscription required - pay as you go
- Free sandbox for development (watermarked output)
- Built-in asset hosting via Ingest API
- Supports images, video, audio, text overlays, transitions, effects
- Well-documented with examples

#### Tools That DON'T Work for Full Automation

| Tool | Why Not |
|------|---------|
| **Descript** | API only supports importing files INTO Descript for manual editing - cannot programmatically create/export videos |
| **Synthesia** | API exists but designed for avatar-based videos with templates, not screenshot assemblies |
| **HeyGen** | Similar to Synthesia - avatar-focused |
| **Loom** | No API for video creation |
| **NotebookLM** | No API - web interface only |

#### iOS Capture Tools

| Tool | Type | Automation Level |
|------|------|------------------|
| **xcrun simctl** | CLI | ✅ Fully scriptable |
| **XCUITest** | Framework | ✅ Fully scriptable |
| **Fastlane Snapshot** | Wrapper | ✅ Fully scriptable |
| RocketSim | GUI App | ❌ Manual |

**Key insight**: Apple provides everything needed via `xcrun simctl`:
- `xcrun simctl io booted screenshot` - capture screenshots
- `xcrun simctl io booted recordVideo` - record video
- `xcrun simctl launch` - launch apps
- `xcrun simctl openurl` - deep link navigation

#### Text-to-Speech Options

| Option | Quality | Cost | Latency | Automation |
|--------|---------|------|---------|------------|
| **macOS say** | Good | Free | Instant | ✅ CLI |
| **Your own TTS** | Best (you control it) | Varies | Varies | ✅ API/CLI |
| ElevenLabs | Excellent | $5-22/mo | ~1s | ✅ API |
| OpenAI TTS | Very Good | Per-character | ~1s | ✅ API |
| Google TTS | Good | Per-character | ~1s | ✅ API |

**Decision**: Since VoiceLearn IS a voice AI platform, using external TTS services is unnecessary and potentially counterproductive. The macOS `say` command provides decent quality for testing, with hooks for custom TTS integration.

---

## Architecture Overview

### Pipeline Stages

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                              TRIGGER                                        │
│  • Manual command: "generate demo"                                          │
│  • Git hook: on push to main                                                │
│  • Scheduled: cron job                                                      │
│  • File watcher: UI code changes                                            │
└─────────────────────────────────────────────────────────────────────────────┘
                                      │
                                      ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│  STAGE 1: CAPTURE                                                           │
│  ════════════════                                                           │
│                                                                             │
│  Tools: xcrun simctl, XCUITest (optional)                                   │
│  Location: Local Mac with Xcode                                             │
│                                                                             │
│  Actions:                                                                   │
│  1. Boot iOS Simulator (specific device/iOS version)                        │
│  2. Install app (optional - if building from source)                        │
│  3. Launch app                                                              │
│  4. For each scene:                                                         │
│     a. Wait for UI to settle                                                │
│     b. Navigate (deep links, or XCUITest taps)                              │
│     c. Capture screenshot OR record video segment                           │
│  5. Terminate app                                                           │
│                                                                             │
│  Output: PNG screenshots and/or MP4 video clips in local directory          │
└─────────────────────────────────────────────────────────────────────────────┘
                                      │
                                      ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│  STAGE 2: NARRATION                                                         │
│  ═════════════════                                                          │
│                                                                             │
│  Tools: macOS say, custom TTS CLI, or pre-recorded files                    │
│  Location: Local Mac                                                        │
│                                                                             │
│  Actions:                                                                   │
│  1. For each scene with narration text:                                     │
│     a. Generate audio file from text (or copy pre-recorded)                 │
│     b. Determine audio duration                                             │
│     c. Set scene duration = audio duration + padding                        │
│                                                                             │
│  Output: MP3/M4A audio files, scene timing metadata                         │
└─────────────────────────────────────────────────────────────────────────────┘
                                      │
                                      ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│  STAGE 3: UPLOAD                                                            │
│  ══════════════                                                             │
│                                                                             │
│  Tools: Shotstack Ingest API, or S3/GCS                                     │
│  Location: Cloud                                                            │
│                                                                             │
│  Actions:                                                                   │
│  1. For each asset (screenshots, audio files):                              │
│     a. Request signed upload URL from Shotstack                             │
│     b. Upload file to signed URL                                            │
│     c. Store resulting asset URL                                            │
│                                                                             │
│  Output: Mapping of local filenames to cloud URLs                           │
└─────────────────────────────────────────────────────────────────────────────┘
                                      │
                                      ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│  STAGE 4: ASSEMBLY                                                          │
│  ════════════════                                                           │
│                                                                             │
│  Tools: Shotstack Edit API                                                  │
│  Location: Cloud                                                            │
│                                                                             │
│  Actions:                                                                   │
│  1. Build timeline JSON:                                                    │
│     - Image/video track with clips, timing, effects, transitions            │
│     - Audio track with narration clips                                      │
│     - Optional text overlay track                                           │
│  2. Submit render job to Shotstack                                          │
│  3. Poll for completion                                                     │
│  4. Retrieve rendered video URL                                             │
│                                                                             │
│  Output: URL to rendered MP4 video                                          │
└─────────────────────────────────────────────────────────────────────────────┘
                                      │
                                      ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│  STAGE 5: DELIVERY (Optional)                                               │
│  ════════════════════════════                                               │
│                                                                             │
│  Actions (choose as needed):                                                │
│  • Download video to local filesystem                                       │
│  • Upload to S3/GCS for permanent hosting                                   │
│  • Post to Slack channel                                                    │
│  • Update README with new video link                                        │
│  • Commit to repository                                                     │
│  • Upload to App Store Connect                                              │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

### Data Flow

```
Configuration (JSON)
        │
        ▼
┌───────────────┐     ┌───────────────┐     ┌───────────────┐
│    Scenes     │────▶│   Captures    │────▶│    Assets     │
│  (what to do) │     │ (local files) │     │ (cloud URLs)  │
└───────────────┘     └───────────────┘     └───────────────┘
                              │                     │
                              ▼                     ▼
                      ┌───────────────┐     ┌───────────────┐
                      │    Audio      │────▶│   Timeline    │
                      │  (narration)  │     │    (JSON)     │
                      └───────────────┘     └───────────────┘
                                                    │
                                                    ▼
                                            ┌───────────────┐
                                            │  Final Video  │
                                            │    (MP4)      │
                                            └───────────────┘
```

---

## Component Deep Dives

### Component 1: iOS Simulator Control

The iOS Simulator can be fully controlled via the `xcrun simctl` command-line tool.

#### Key Commands

```bash
# List available simulators
xcrun simctl list devices

# Boot a specific simulator
xcrun simctl boot "iPhone 15 Pro"
# Or by UDID: xcrun simctl boot 12345678-1234-1234-1234-123456789ABC

# Open Simulator app (makes it visible)
open -a Simulator

# Install an app
xcrun simctl install booted /path/to/MyApp.app

# Launch an app
xcrun simctl launch booted com.example.myapp

# Open a URL (deep link)
xcrun simctl openurl booted "myapp://screen/settings"

# Take a screenshot
xcrun simctl io booted screenshot ~/screenshot.png
# Options: --type png|jpeg|tiff|bmp|gif

# Record video
xcrun simctl io booted recordVideo ~/recording.mp4
# Options: --codec h264|hevc, runs until Ctrl+C or SIGTERM

# Terminate app
xcrun simctl terminate booted com.example.myapp

# Shutdown simulator
xcrun simctl shutdown booted
```

#### Device Selection Strategy

For demo videos, consistency matters. Always specify:
1. Device type (iPhone 15 Pro, iPad Pro 12.9, etc.)
2. iOS version (via runtime selection)

```bash
# Find available runtimes
xcrun simctl list runtimes

# Create a specific device if needed
xcrun simctl create "Demo iPhone" "iPhone 15 Pro" "iOS-17-2"
```

#### UI Automation Options

**Option A: Deep Links (Simplest)**
- App supports URL schemes for navigation
- `xcrun simctl openurl booted "myapp://onboarding"`
- Pros: Simple, reliable, no additional code
- Cons: Requires deep link support in app

**Option B: XCUITest (Most Powerful)**
- Write UI test code that navigates through app
- Run via `xcodebuild test`
- Pros: Can do anything - taps, swipes, text input
- Cons: Requires maintaining test code

**Option C: Accessibility Automation**
- Tools like `applesimutils` or AppleScript
- Pros: No app code changes needed
- Cons: More brittle, complex setup

**Recommendation**: Start with deep links. Add XCUITest only if needed for complex flows.

### Component 2: Text-to-Speech

#### macOS Built-in TTS

The `say` command provides free, instant TTS:

```bash
# Basic usage
say "Hello world"

# Save to file (AIFF format)
say -o output.aiff "Hello world"

# Specify voice
say -v Samantha "Hello world"

# Adjust rate (words per minute, default ~175)
say -r 150 "Hello world"

# List available voices
say -v '?'
```

**Quality voices on macOS:**
- `Samantha` - Female, American English (default)
- `Alex` - Male, American English
- `Daniel` - Male, British English
- `Karen` - Female, Australian English
- `Moira` - Female, Irish English

**Audio format conversion:**
Shotstack works best with MP3. Convert AIFF:
```bash
# Using ffmpeg (recommended)
ffmpeg -i input.aiff -acodec libmp3lame -ab 192k output.mp3

# Using afconvert (macOS native, M4A output)
afconvert -f m4af -d aac input.aiff output.m4a
```

#### Custom TTS Integration

For your own TTS system, the pipeline supports a command template:

```json
{
  "tts_method": "custom",
  "tts_custom_cmd": "my-tts-cli --text '{text}' --output '{output}' --voice richard"
}
```

Placeholders:
- `{text}` - The narration text (shell-escaped)
- `{output}` - Output file path
- `{voice}` - Voice identifier (optional)

**Example integrations:**

```bash
# Local Piper TTS
"tts_custom_cmd": "echo '{text}' | piper --model en_US-lessac-medium -f {output}"

# Coqui TTS
"tts_custom_cmd": "tts --text '{text}' --out_path {output}"

# HTTP API call
"tts_custom_cmd": "curl -X POST 'http://localhost:8080/tts' -d 'text={text}' -o {output}"

# VoiceLearn's own TTS (example)
"tts_custom_cmd": "voicelearn-cli synthesize --text '{text}' --output {output}"
```

#### Pre-recorded Audio

For maximum quality or when TTS isn't suitable:

```json
{
  "tts_method": "prerecorded",
  "tts_prerecorded_dir": "./audio_files"
}
```

Directory structure:
```
audio_files/
├── welcome.mp3      # Matches scene id "welcome"
├── onboarding.mp3   # Matches scene id "onboarding"
├── lesson.mp3       # Matches scene id "lesson"
└── ...
```

### Component 3: Shotstack Video Assembly

Shotstack is a cloud API that assembles videos from a JSON timeline specification.

#### Core Concepts

**Timeline**: The complete video structure
**Tracks**: Layers that stack (bottom track renders first, top renders last)
**Clips**: Individual media elements placed on tracks
**Assets**: The actual media content (images, video, audio, text)
**Effects**: Visual modifications (zoom, slide, etc.)
**Transitions**: How clips fade in/out

#### Timeline Structure

```json
{
  "timeline": {
    "background": "#000000",
    "tracks": [
      {
        "clips": [...]  // Track 1 (bottom layer)
      },
      {
        "clips": [...]  // Track 2 (above track 1)
      }
    ]
  },
  "output": {
    "format": "mp4",
    "resolution": "hd"
  }
}
```

#### Clip Structure

```json
{
  "asset": {
    "type": "image",           // image, video, audio, text, html
    "src": "https://..."       // URL to asset
  },
  "start": 0,                  // Start time in seconds
  "length": 5,                 // Duration in seconds
  "fit": "contain",            // contain, cover, crop, none
  "effect": "zoomIn",          // Visual effect
  "transition": {
    "in": "fade",              // Entry transition
    "out": "fade"              // Exit transition
  }
}
```

#### Available Effects

| Effect | Description |
|--------|-------------|
| `zoomIn` | Ken Burns zoom in |
| `zoomOut` | Ken Burns zoom out |
| `slideLeft` | Pan left |
| `slideRight` | Pan right |
| `slideUp` | Pan up |
| `slideDown` | Pan down |

#### Available Transitions

| Transition | Description |
|------------|-------------|
| `fade` | Cross-fade |
| `slideLeft` | Slide in from right |
| `slideRight` | Slide in from left |
| `slideUp` | Slide in from bottom |
| `slideDown` | Slide in from top |
| `carouselLeft` | 3D carousel effect |
| `carouselRight` | 3D carousel effect |

#### Text Overlays

```json
{
  "asset": {
    "type": "text",
    "text": "Welcome to the App",
    "font": {
      "family": "Helvetica",
      "size": 48,
      "color": "#ffffff"
    },
    "background": {
      "color": "#000000",
      "opacity": 0.7,
      "padding": 20
    }
  },
  "start": 0,
  "length": 5,
  "position": "bottom",        // top, bottom, center, etc.
  "offset": {
    "x": 0,                    // -1 to 1 (percentage of width)
    "y": -0.1                  // -1 to 1 (percentage of height)
  }
}
```

#### Render Process

1. **Submit render job**:
   ```
   POST https://api.shotstack.io/edit/v1/render
   Headers: x-api-key: YOUR_KEY
   Body: { timeline, output }
   
   Response: { "response": { "id": "render-uuid" } }
   ```

2. **Poll for status**:
   ```
   GET https://api.shotstack.io/edit/v1/render/{id}
   
   Response: { "response": { "status": "rendering|done|failed", "url": "..." } }
   ```

3. **Download result** from the URL when status is "done"

---

## API Reference

### Shotstack API Endpoints

**Base URLs:**
- Stage (testing, watermarked): `https://api.shotstack.io/edit/stage`
- Production: `https://api.shotstack.io/edit/v1`

**Authentication:**
All requests require header: `x-api-key: YOUR_API_KEY`

#### Edit API

| Endpoint | Method | Purpose |
|----------|--------|---------|
| `/render` | POST | Submit render job |
| `/render/{id}` | GET | Check render status |
| `/templates` | GET | List saved templates |
| `/templates/{id}` | GET | Get template details |
| `/templates/render` | POST | Render from template |

#### Ingest API

For uploading assets to Shotstack's CDN:

| Endpoint | Method | Purpose |
|----------|--------|---------|
| `/upload` | POST | Get signed upload URL |
| `/sources` | GET | List uploaded sources |
| `/sources/{id}` | GET | Get source details |

**Upload flow:**
```python
# 1. Request upload URL
POST /ingest/v1/upload
Body: { "filename": "screenshot.png" }
Response: { "data": { "url": "https://signed-upload-url...", "id": "..." } }

# 2. Upload file to signed URL
PUT {signed_url}
Headers: Content-Type: application/octet-stream
Body: <file bytes>

# 3. Use the base URL (without query params) as asset src in timeline
```

### Output Options

| Resolution | Dimensions | Use Case |
|------------|------------|----------|
| `preview` | 512x288 | Quick previews |
| `mobile` | 640x360 | Mobile-optimized |
| `sd` | 1024x576 | Standard definition |
| `hd` | 1280x720 | HD (recommended default) |
| `1080` | 1920x1080 | Full HD |
| `4k` | 3840x2160 | Ultra HD |

| Format | Notes |
|--------|-------|
| `mp4` | H.264, most compatible |
| `gif` | Animated GIF (large files) |
| `webm` | VP9, smaller files |

---

## Configuration Patterns

### Basic Configuration

```json
{
  "name": "App Demo",
  "simulator_device": "iPhone 15 Pro",
  "app_bundle_id": "com.example.myapp",
  
  "tts_method": "macos",
  "tts_voice": "Samantha",
  
  "scenes": [
    {
      "id": "welcome",
      "narration": "Welcome to the app.",
      "capture": "screenshot"
    }
  ],
  
  "output_dir": "./demo_output"
}
```

### Multi-Device Demos

Create separate configs for different devices:

```json
// demo_iphone.json
{
  "name": "App Demo - iPhone",
  "simulator_device": "iPhone 15 Pro",
  "shotstack_resolution": "hd",
  ...
}

// demo_ipad.json
{
  "name": "App Demo - iPad",
  "simulator_device": "iPad Pro 12.9-inch",
  "shotstack_resolution": "1080",
  ...
}
```

### Localized Demos

For multiple languages:

```json
// demo_en.json
{
  "name": "App Demo - English",
  "tts_voice": "Samantha",
  "scenes": [
    { "id": "welcome", "narration": "Welcome to the app." }
  ]
}

// demo_es.json
{
  "name": "App Demo - Spanish",
  "tts_voice": "Monica",
  "scenes": [
    { "id": "welcome", "narration": "Bienvenido a la aplicación." }
  ]
}
```

### Feature-Focused Demos

Different demos for different features:

```json
// demo_onboarding.json - Just the onboarding flow
// demo_lesson.json - Just the lesson experience
// demo_full.json - Complete walkthrough
```

### Scene Configuration Options

```json
{
  "id": "unique_scene_id",           // Required: unique identifier
  "narration": "Text to speak",       // Optional: TTS input
  "duration": 5.0,                    // Optional: override auto-duration
  "capture": "screenshot",            // screenshot, video, or none
  "video_length": 10.0,               // For video captures
  "wait_before": 2.0,                 // Seconds to wait before capture
  "deep_link": "myapp://screen",      // Navigate via URL scheme
  "effect": "zoomIn",                 // Visual effect
  "transition": "fade",               // Entry/exit transition
  "text_overlay": "Feature Name"      // Optional text on screen
}
```

---

## Extension Points

The system is designed to be extended in several ways:

### 1. Custom Capture Logic

Replace the capture stage with XCUITest:

```swift
// DemoUITests.swift
func testCaptureWelcomeScreen() {
    let app = XCUIApplication()
    app.launch()
    
    // Navigate to welcome screen
    // ...
    
    // Take screenshot with specific name
    let screenshot = app.screenshot()
    let attachment = XCTAttachment(screenshot: screenshot)
    attachment.name = "welcome"
    attachment.lifetime = .keepAlways
    add(attachment)
}
```

### 2. Custom TTS Integration

Create a wrapper script for your TTS:

```bash
#!/bin/bash
# voicelearn_tts.sh
TEXT="$1"
OUTPUT="$2"

# Call your TTS API
curl -X POST "http://localhost:5000/synthesize" \
  -H "Content-Type: application/json" \
  -d "{\"text\": \"$TEXT\"}" \
  -o "$OUTPUT"
```

Config: `"tts_custom_cmd": "./voicelearn_tts.sh '{text}' '{output}'"`

### 3. Custom Asset Hosting

Replace Shotstack Ingest with S3:

```python
def upload_to_s3(files):
    import boto3
    s3 = boto3.client('s3')
    urls = {}
    for path in files:
        key = f"demo-assets/{path.name}"
        s3.upload_file(str(path), "my-bucket", key)
        urls[path.name] = f"https://my-bucket.s3.amazonaws.com/{key}"
    return urls
```

### 4. Post-Processing

Add a delivery stage:

```python
def deliver_video(video_path: Path, config: Config):
    # Upload to CDN
    cdn_url = upload_to_cdn(video_path)
    
    # Post to Slack
    slack_notify(f"New demo video: {cdn_url}")
    
    # Update README
    update_readme(cdn_url)
    
    # Commit to repo
    git_commit(f"Update demo video: {config.name}")
```

### 5. Template System

For complex, reusable layouts:

```python
# Create template in Shotstack dashboard
# Use template ID in render call

def render_from_template(template_id: str, variables: dict):
    payload = {
        "id": template_id,
        "merge": [
            {"find": "TITLE", "replace": variables["title"]},
            {"find": "SCREENSHOT_1", "replace": variables["screenshots"][0]},
            # ...
        ]
    }
    # POST to /templates/render
```

---

## Integration Strategies

### CI/CD Integration

#### GitHub Actions

```yaml
name: Generate Demo Video

on:
  push:
    branches: [main]
    paths:
      - 'Sources/UI/**'  # Only on UI changes

jobs:
  demo:
    runs-on: macos-14
    steps:
      - uses: actions/checkout@v4
      
      - name: Setup Xcode
        uses: maxim-lobanov/setup-xcode@v1
        with:
          xcode-version: latest-stable
      
      - name: Install ffmpeg
        run: brew install ffmpeg
      
      - name: Generate Demo
        env:
          SHOTSTACK_API_KEY: ${{ secrets.SHOTSTACK_API_KEY }}
          SHOTSTACK_ENV: v1
        run: python ios_demo_video_generator.py --config demo_config.json
      
      - name: Upload Video
        uses: actions/upload-artifact@v4
        with:
          name: demo-video
          path: demo_output/*.mp4
```

#### Fastlane Integration

```ruby
# Fastfile
lane :demo_video do
  # Build app
  build_app(scheme: "MyApp", configuration: "Debug")
  
  # Generate demo
  sh("python ../ios_demo_video_generator.py --config ../demo_config.json")
  
  # Upload to S3 or wherever
  sh("aws s3 cp ../demo_output/demo.mp4 s3://my-bucket/demos/")
end
```

### Git Hook Integration

```bash
# .git/hooks/post-commit
#!/bin/bash

# Check if UI files changed
if git diff --name-only HEAD~1 | grep -q "Sources/UI/"; then
  echo "UI changed, regenerating demo video..."
  python ios_demo_video_generator.py --config demo_config.json
fi
```

### Scheduled Generation

```bash
# crontab -e
# Regenerate demo every Monday at 9am
0 9 * * 1 cd /path/to/project && python ios_demo_video_generator.py --config demo_config.json
```

---

## Troubleshooting

### Common Issues

#### Simulator Issues

**"Simulator not found"**
```bash
# List available simulators
xcrun simctl list devices

# Create the device if missing
xcrun simctl create "iPhone 15 Pro" "com.apple.CoreSimulator.SimDeviceType.iPhone-15-Pro"
```

**"App not installed"**
- Ensure the .app bundle path is correct
- Build the app first: `xcodebuild -scheme MyApp -destination 'platform=iOS Simulator'`

**"Screenshots are blank"**
- Wait longer before capture (increase `wait_before`)
- Ensure app has finished loading
- Check that Simulator window is not minimized

#### TTS Issues

**"say command not found"**
- Only available on macOS
- Run from Terminal, not over SSH

**"Audio duration is 0"**
- Install ffprobe: `brew install ffmpeg`
- Or use afinfo (macOS native)

**"Voice not found"**
- List voices: `say -v '?'`
- Download additional voices in System Preferences > Accessibility > Spoken Content

#### Shotstack Issues

**"401 Unauthorized"**
- Check SHOTSTACK_API_KEY is set
- Verify key is valid in Shotstack dashboard

**"Render failed"**
- Check asset URLs are accessible (not file:// URLs)
- Verify timeline JSON structure
- Look for error details in render status response

**"Video has watermark"**
- Using stage environment (expected)
- Switch to v1 for production: `SHOTSTACK_ENV=v1`

### Debug Mode

Save intermediate files for debugging:

```python
# In the generator, save timeline for inspection
with open(output_dir / "debug_timeline.json", "w") as f:
    json.dump(timeline, f, indent=2)

# Save scene data
with open(output_dir / "debug_scenes.json", "w") as f:
    json.dump(scenes_data, f, indent=2)
```

---

## Cost Analysis

### Shotstack Pricing

**Pay-as-you-go (Recommended for starting):**
- $0.40 per rendered minute
- Minimum purchase: $10 (25 credits)
- 1 credit = 1 minute of video

**Subscription:**
- $0.20 per minute (50% discount)
- Monthly plans from $20/month

**Free tier:**
- Stage environment (watermarked)
- Unlimited for development/testing

### Typical Costs

| Demo Length | PAYG Cost | Subscription Cost |
|-------------|-----------|-------------------|
| 30 seconds | $0.20 | $0.10 |
| 1 minute | $0.40 | $0.20 |
| 2 minutes | $0.80 | $0.40 |
| 5 minutes | $2.00 | $1.00 |

### Cost Optimization

1. **Use stage environment for development** - Free, just watermarked
2. **Batch renders** - Generate all variants at once
3. **Cache captures** - Only re-render when UI actually changes
4. **Right-size resolution** - HD is usually sufficient, 4K costs more

### Comparison with Alternatives

| Approach | Monthly Cost | Notes |
|----------|-------------|-------|
| This system | $5-20 variable | Pay only for what you render |
| Synthesia | $29+/month | Avatar-focused, not ideal for app demos |
| Manual editing | $0 (your time) | Hours per video, not repeatable |
| Video editor subscription | $15-50/month | Still manual work |

---

## Future Considerations

### Potential Enhancements

1. **Parallel rendering** - Generate multiple versions simultaneously
2. **A/B testing** - Create variants for different audiences
3. **Analytics integration** - Track video engagement
4. **Auto-narration** - Use LLM to generate narration from screenshots
5. **Change detection** - Automatically detect when UI changes warrant new video
6. **Template library** - Pre-built templates for common app types

### Alternative Technologies to Watch

- **ffmpeg directly** - Skip Shotstack for simple assemblies
- **Remotion** - React-based video generation
- **MoviePy** - Python video editing library
- **Apple's AVFoundation** - Native video composition

### Integration Opportunities

- **App Store Connect API** - Auto-upload preview videos
- **TestFlight** - Include demo in test builds
- **Documentation sites** - Embed in docs automatically
- **Marketing automation** - Trigger new videos for campaigns

---

## Summary

This system provides a complete, automated pipeline for generating iOS app demo videos:

1. **Capture** via `xcrun simctl` - reliable, scriptable, free
2. **Narration** via local TTS - no cloud dependencies, supports custom TTS
3. **Assembly** via Shotstack API - professional quality, pay-as-you-go

The key advantages are:
- **100% automated** - no manual steps
- **Repeatable** - regenerate anytime the app changes
- **Flexible** - different configs for different demos
- **Cost-effective** - ~$0.40-0.80 per minute of final video
- **Extensible** - hooks for custom TTS, capture logic, delivery

The reference implementation (Python script) is a starting point. Claude Code should feel free to modify, extend, or rewrite components as needed for VoiceLearn's specific requirements.
