# Demo Video Generator - Claude Code Instructions

This document provides Claude Code with complete guidance for using and maintaining the iOS demo video automation system.

## Overview

The demo video generator creates professional iOS app demo videos autonomously. It captures screenshots/video from the iOS Simulator, generates voice narration using UnaMentis's own TTS, and assembles everything into a polished video via Shotstack.

**Key Principle**: This system is designed for full autonomy. Once the user approves a script, Claude Code executes the entire pipeline without intervention.

## Architecture

```
┌─────────────────────────────────────────────────────────────────────────┐
│                           USER PROVIDES                                  │
│  Direction: "Create a 60-second overview of the voice session feature"  │
└─────────────────────────────────────────────────────────────────────────┘
                                    │
                                    ▼
┌─────────────────────────────────────────────────────────────────────────┐
│                         CLAUDE CODE DRAFTS                               │
│  Script: demo/scripts/<name>.md (narration text)                        │
│  Config: demo/configs/<name>.json (scenes, timing, effects)             │
└─────────────────────────────────────────────────────────────────────────┘
                                    │
                                    ▼
┌─────────────────────────────────────────────────────────────────────────┐
│                          USER REVIEWS                                    │
│  Edit script if needed, approve when ready                              │
└─────────────────────────────────────────────────────────────────────────┘
                                    │
                                    ▼
┌─────────────────────────────────────────────────────────────────────────┐
│                    CLAUDE CODE EXECUTES PIPELINE                         │
│                                                                          │
│  1. PRE-FLIGHT ──► Verify TTS, Shotstack, Simulator, ffmpeg             │
│  2. CAPTURE ─────► Boot sim, launch app, navigate, capture              │
│  3. TTS ─────────► Generate audio via UnaMentis API (cached)            │
│  4. UPLOAD ──────► Push assets to Shotstack CDN                         │
│  5. ASSEMBLE ────► Build timeline, submit render job                    │
│  6. DOWNLOAD ────► Retrieve final MP4                                   │
└─────────────────────────────────────────────────────────────────────────┘
                                    │
                                    ▼
┌─────────────────────────────────────────────────────────────────────────┐
│                            OUTPUT                                        │
│  demo/output/<name>/<Demo_Name>.mp4                                     │
└─────────────────────────────────────────────────────────────────────────┘
```

## Directory Structure

```
demo/
├── CLAUDE.md                       # This file - Claude Code instructions
├── README.md                       # Quick start for humans
├── IOS_DEMO_VIDEO_AUTOMATION.md    # Deep technical documentation
├── ios_demo_video_generator.py     # Main generator script (700+ lines)
│
├── configs/                        # Demo configurations (JSON)
│   └── app_overview.json           # Full app walkthrough config
│
├── scripts/                        # Narration scripts (Markdown)
│   └── app_overview.md             # Narration for app overview
│
├── output/                         # Generated files (gitignored)
│   └── <config_name>/              # Output per config
│       ├── *.png                   # Screenshots
│       ├── *.mp4                   # Video clips
│       ├── *_audio.mp3             # Audio narration
│       ├── scenes.json             # Scene metadata (for resume)
│       ├── timeline.json           # Shotstack timeline
│       └── <Demo_Name>.mp4         # Final video
│
└── tests/                          # Test coverage
    ├── __init__.py
    └── test_generator.py           # Unit and integration tests
```

## Prerequisites

Before running the generator, verify:

### 1. UnaMentis Services
```bash
/service status
# management-api must be running for TTS
```

If not running:
```bash
/service start management-api
```

### 2. Shotstack API Key
```bash
# Set in environment
export SHOTSTACK_API_KEY="your-key-here"
export SHOTSTACK_ENV="stage"  # "stage" = free with watermark, "v1" = production
```

Get a key at https://shotstack.io (free tier available, ~$0.40/min for production).

### 3. ffmpeg
```bash
# Install if needed
brew install ffmpeg
```

### 4. iOS Simulator
The config specifies `iPhone 16 Pro` by default. Verify it exists:
```bash
xcrun simctl list devices | grep "iPhone 16 Pro"
```

## Using the Generator

### Command Line Interface

```bash
# Generate template config
python demo/ios_demo_video_generator.py --template > demo/configs/new_demo.json

# Full pipeline (capture + TTS + assemble)
python demo/ios_demo_video_generator.py \
  --config demo/configs/app_overview.json \
  --script demo/scripts/app_overview.md

# Capture only (test navigation and screenshots)
python demo/ios_demo_video_generator.py \
  --config demo/configs/app_overview.json \
  --capture-only

# Assemble only (use existing captures, regenerate video)
python demo/ios_demo_video_generator.py \
  --config demo/configs/app_overview.json \
  --script demo/scripts/app_overview.md \
  --skip-capture

# Skip pre-flight checks (for debugging)
python demo/ios_demo_video_generator.py \
  --config demo/configs/app_overview.json \
  --skip-preflight
```

### Using the /demo-video Skill

```
/demo-video                         # Show status and available configs
/demo-video generate app_overview   # Full pipeline
/demo-video capture app_overview    # Capture only
/demo-video assemble app_overview   # Assemble only
/demo-video script app_overview     # View narration script
```

## Configuration Reference

### Config File (JSON)

```json
{
    "name": "Demo Name",              // Used in output filename
    "version": "1.0.0",               // For cache invalidation

    "simulator_device": "iPhone 16 Pro",
    "app_bundle_id": "com.unamentis.app",
    "app_scheme": "UnaMentis",        // Optional: Xcode scheme
    "project_path": "/path/to/UnaMentis.xcodeproj",  // Optional

    "tts_method": "unamentis",        // unamentis, macos, custom, prerecorded, none
    "tts_voice": "nova",              // Voice ID (nova, sarah, john, emma, alex)
    "tts_rate": 175,                  // Words per minute (175 = 1.0x)
    "tts_provider": "vibevoice",      // TTS provider
    "tts_server_url": "http://localhost:8766",

    "shotstack_resolution": "1080",   // preview, sd, hd, 1080, 4k
    "shotstack_format": "mp4",        // mp4, gif, webm
    "default_effect": "zoomIn",       // zoomIn, zoomOut, slideLeft, slideRight
    "default_transition": "fade",     // fade, slideLeft, slideRight, carouselLeft
    "background_color": "#0a0a0f",    // Video background

    "scenes": [...],                  // Array of scene objects

    "output_dir": "./demo/output/demo_name"
}
```

### Scene Object

```json
{
    "id": "unique_scene_id",          // Required: matches script header
    "narration": "",                  // Loaded from script file
    "duration": null,                 // Auto-calculated from audio if null
    "capture": "screenshot",          // screenshot, video, none
    "video_length": 5.0,              // Seconds (for video captures)
    "wait_before": 2.0,               // Seconds before capture
    "deep_link": "unamentis://chat",  // Navigate via URL scheme
    "effect": "zoomIn",               // Override default effect
    "transition": "fade",             // Override default transition
    "text_overlay": "Feature Name"    // Optional text on screen
}
```

### Script File (Markdown)

```markdown
# Demo Title (ignored)

## scene_id_1
Narration text for scene 1.

## scene_id_2
Narration text for scene 2.
Can span multiple lines.
```

The `## header` must match the scene `id` in the config.

## TTS Integration

The generator uses UnaMentis's own TTS server, not external services.

### API Endpoint
```
POST http://localhost:8766/api/tts
Content-Type: application/json

{
    "text": "Narration text",
    "voice_id": "nova",
    "tts_provider": "vibevoice",
    "speed": 1.0
}

Response: WAV audio file
```

### Available Voices
- `nova` (default) - Female, natural
- `sarah` - Female, warm
- `john` - Male, professional
- `emma` - Female, friendly
- `alex` - Male, casual

### Caching
The TTS server caches audio by text hash. Regenerating with the same narration is instant.

## Deep Links

The iOS app supports these deep links for demo navigation:

| Deep Link | Action |
|-----------|--------|
| `unamentis://chat` | Open freeform chat |
| `unamentis://chat?prompt=Hello` | Chat with initial prompt |
| `unamentis://lesson?id=UUID` | Start specific lesson |
| `unamentis://analytics` | Open analytics tab |
| `unamentis://settings` | Open settings tab |
| `unamentis://history` | Open history tab |
| `unamentis://learning` | Open learning tab |
| `unamentis://onboarding` | Show onboarding (for demos) |

## Workflow for Creating a New Demo

### Step 1: Create Config
```bash
# Start from template
python demo/ios_demo_video_generator.py --template > demo/configs/new_feature.json
```

Edit the config:
- Set `name` and `version`
- Define scenes with `id`, `capture` type, `deep_link`, and timing

### Step 2: Create Script
Create `demo/scripts/new_feature.md`:
```markdown
# New Feature Demo

## intro
Welcome to this feature demonstration.

## feature_overview
Here's how the feature works.

## closing
Try it yourself today.
```

### Step 3: Test Capture
```bash
python demo/ios_demo_video_generator.py \
  --config demo/configs/new_feature.json \
  --capture-only
```

Review screenshots in `demo/output/new_feature/`.

### Step 4: Generate Full Video
```bash
python demo/ios_demo_video_generator.py \
  --config demo/configs/new_feature.json \
  --script demo/scripts/new_feature.md
```

### Step 5: Iterate
Edit the script, then regenerate (TTS is cached):
```bash
python demo/ios_demo_video_generator.py \
  --config demo/configs/new_feature.json \
  --script demo/scripts/new_feature.md \
  --skip-capture
```

## Error Handling

### DemoError
Base exception for all demo generation errors.

### TTSServerError
TTS server not available. Fix:
```bash
/service start management-api
```

### ShotstackError
Shotstack API error. Check:
- `SHOTSTACK_API_KEY` is set
- Key is valid in Shotstack dashboard
- Network connectivity

### SimulatorError
Simulator control failed. Check:
- Simulator device exists
- Xcode is installed
- No other process is using the simulator

## Testing

Run tests:
```bash
# All tests
pytest demo/tests/ -v

# TTS integration (requires management-api)
pytest demo/tests/test_generator.py::TestTTS -v

# Skip integration tests
pytest demo/tests/test_generator.py -v -k "not integration"
```

## Cost

| Environment | Cost | Output |
|-------------|------|--------|
| `stage` | Free | Watermarked |
| `v1` | ~$0.40/min | Production quality |

Typical demo (60 seconds): ~$0.40 production, free for testing.

## Maintenance

### Adding a New TTS Voice
The TTS server supports multiple voices. To use a new voice:
1. Check available voices in management-api
2. Update config: `"tts_voice": "new_voice_id"`

### Adding a New Deep Link
1. Edit `UnaMentis/UnaMentisApp.swift`
2. Add case in `handleDeepLink()`
3. Add notification name
4. Add handler in `ContentView`

### Updating Shotstack Integration
The Shotstack API is wrapped in the `Shotstack` class. Key methods:
- `upload()` - Push files to CDN
- `build_timeline()` - Create timeline JSON
- `render()` - Submit and poll for completion

## Integration with CI/CD

### GitHub Actions Example
```yaml
name: Generate Demo Video

on:
  push:
    paths:
      - 'UnaMentis/UI/**'

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

      - name: Start Services
        run: |
          # Start management-api for TTS
          python -m server.management &
          sleep 5

      - name: Generate Demo
        env:
          SHOTSTACK_API_KEY: ${{ secrets.SHOTSTACK_API_KEY }}
          SHOTSTACK_ENV: v1
        run: |
          python demo/ios_demo_video_generator.py \
            --config demo/configs/app_overview.json \
            --script demo/scripts/app_overview.md

      - name: Upload Video
        uses: actions/upload-artifact@v4
        with:
          name: demo-video
          path: demo/output/app_overview/*.mp4
```

## Troubleshooting

### "TTS server not available"
```bash
/service status
/service start management-api
```

### "Simulator not found"
```bash
# List available simulators
xcrun simctl list devices

# Create if missing
xcrun simctl create "iPhone 16 Pro" "com.apple.CoreSimulator.SimDeviceType.iPhone-16-Pro"
```

### "Shotstack API key invalid"
- Verify key at https://dashboard.shotstack.io
- Check environment: `echo $SHOTSTACK_API_KEY`
- Ensure correct environment: `echo $SHOTSTACK_ENV`

### "ffmpeg not found"
```bash
brew install ffmpeg
```

### "Render failed"
- Check `demo/output/<name>/timeline.json` for issues
- Verify asset URLs are accessible
- Look for error details in Shotstack dashboard

### "Video has watermark"
Using `stage` environment (expected for testing). For production:
```bash
export SHOTSTACK_ENV=v1
```

## Best Practices

1. **Always test capture first** before full pipeline
2. **Use descriptive scene IDs** that match script headers
3. **Keep narration concise** (3-5 seconds per scene)
4. **Add wait_before** for UI animations to settle
5. **Use deep links** for reliable navigation
6. **Version your configs** for cache management
7. **Review in stage** before using production credits
