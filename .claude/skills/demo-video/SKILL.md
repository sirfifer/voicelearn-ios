# Demo Video Skill

Generate iOS app demo videos autonomously using UnaMentis TTS and Shotstack.

## User-Invocable

This skill can be invoked directly by users with `/demo-video`.

## Commands

```
/demo-video                         # Show status and available configs
/demo-video generate <config>       # Full pipeline: capture → TTS → assemble
/demo-video capture <config>        # Capture only (test navigation)
/demo-video assemble <config>       # Use existing captures, regenerate video
/demo-video script <config>         # Show narration script for editing
```

## Prerequisites

### 1. UnaMentis Services
```bash
/service status
# management-api must be running for TTS
```

### 2. Shotstack API Key
```bash
export SHOTSTACK_API_KEY="your-key"    # Get at shotstack.io
export SHOTSTACK_ENV="stage"            # "stage" = watermark, "v1" = production
```

### 3. Simulator
```bash
xcrun simctl list devices | grep "iPhone 16 Pro"
```

## Available Configs

| Config | Description | Script |
|--------|-------------|--------|
| `app_overview` | Full app walkthrough | `scripts/app_overview.md` |

## Workflow

### Creating a New Demo

1. **User provides direction:**
   > "Create a 60-second overview of the voice session feature"

2. **Claude drafts script and config:**
   - Creates `demo/configs/<name>.json` with scenes
   - Creates `demo/scripts/<name>.md` with narration
   - Presents for review

3. **User reviews and edits:**
   - Edit markdown script directly
   - Or provide feedback for Claude to update

4. **Claude runs pipeline:**
   ```
   /demo-video generate <name>
   ```

5. **Video delivered:**
   ```
   demo/output/<name>/<Demo_Name>.mp4
   ```

### Editing an Existing Demo

1. **Edit script:** Update `demo/scripts/<config>.md`
2. **Regenerate:** `/demo-video assemble <config>` (uses cached captures)

## Implementation

### For `generate` command:
```bash
cd /Users/ramerman/dev/unamentis
python demo/ios_demo_video_generator.py \
  --config demo/configs/<config>.json \
  --script demo/scripts/<config>.md
```

### For `capture` command:
```bash
python demo/ios_demo_video_generator.py \
  --config demo/configs/<config>.json \
  --capture-only
```

### For `assemble` command:
```bash
python demo/ios_demo_video_generator.py \
  --config demo/configs/<config>.json \
  --script demo/scripts/<config>.md \
  --skip-capture
```

### For `script` command:
Read and display `demo/scripts/<config>.md`

## Pipeline Stages

```
PRE-FLIGHT
    │ Verify: TTS server, Shotstack API, simulator, ffmpeg
    ▼
CAPTURE
    │ Boot simulator → Launch app → Navigate → Screenshot/Video
    ▼
TTS
    │ Generate audio via UnaMentis API (http://localhost:8766/api/tts)
    ▼
UPLOAD
    │ Push assets to Shotstack CDN
    ▼
ASSEMBLE
    │ Build timeline → Submit render → Poll for completion
    ▼
DOWNLOAD
    │ Retrieve final MP4
    ▼
OUTPUT: demo/output/<config>/<Demo_Name>.mp4
```

## TTS Integration

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
```

### Available Voices
| Voice | Description |
|-------|-------------|
| `nova` | Female, natural (default) |
| `sarah` | Female, warm |
| `john` | Male, professional |
| `emma` | Female, friendly |
| `alex` | Male, casual |

### Caching
TTS is cached by text hash. Same narration = instant on regeneration.

## Deep Links

| Deep Link | Action |
|-----------|--------|
| `unamentis://chat` | Freeform chat |
| `unamentis://chat?prompt=Hello` | Chat with prompt |
| `unamentis://learning` | Learning tab |
| `unamentis://analytics` | Analytics tab |
| `unamentis://settings` | Settings tab |
| `unamentis://history` | History tab |
| `unamentis://lesson?id=UUID` | Specific lesson |

## Config Reference

### Scene Object
```json
{
    "id": "scene_id",           // Must match script ## header
    "narration": "",            // Loaded from script
    "capture": "screenshot",    // screenshot, video, none
    "video_length": 5.0,        // For video captures
    "wait_before": 2.0,         // Seconds before capture
    "deep_link": "unamentis://...",
    "effect": "zoomIn",         // zoomIn, zoomOut, slideLeft, slideRight
    "transition": "fade"        // fade, slideLeft, slideRight, carouselLeft
}
```

### Script Format
```markdown
# Title (ignored)

## scene_id
Narration text for this scene.
Can span multiple lines.
```

## Cost

| Environment | Cost | Output |
|-------------|------|--------|
| `stage` | Free | Watermarked |
| `v1` | ~$0.40/min | Production |

## Troubleshooting

### "TTS server not available"
```bash
/service start management-api
```

### "Simulator not found"
```bash
xcrun simctl list devices
xcrun simctl create "iPhone 16 Pro" "com.apple.CoreSimulator.SimDeviceType.iPhone-16-Pro"
```

### "Shotstack API key invalid"
- Verify at https://dashboard.shotstack.io
- Check: `echo $SHOTSTACK_API_KEY`

### "Video has watermark"
Using stage environment. For production:
```bash
export SHOTSTACK_ENV=v1
```

## Related Documentation

- [demo/CLAUDE.md](../../../demo/CLAUDE.md) - Comprehensive Claude Code guide
- [demo/README.md](../../../demo/README.md) - Quick start
- [demo/IOS_DEMO_VIDEO_AUTOMATION.md](../../../demo/IOS_DEMO_VIDEO_AUTOMATION.md) - Deep technical docs
