# iOS Demo Video Generator

Fully automated pipeline for creating professional iOS app demo videos. Captures from the iOS Simulator, generates voice narration using UnaMentis TTS, and assembles polished videos via Shotstack.

## Features

- **100% Automated**: No manual video editing required
- **UnaMentis TTS**: Uses your own voice AI, not external services
- **Repeatable**: Edit script, regenerate instantly (TTS is cached)
- **Professional Output**: Effects, transitions, 1080p video
- **Cost-Effective**: ~$0.40/minute, free testing with watermark

## Quick Start

### 1. Prerequisites

```bash
# Verify UnaMentis services
/service status
# management-api must be running

# Set Shotstack credentials
export SHOTSTACK_API_KEY="your-key"    # Get at shotstack.io
export SHOTSTACK_ENV="stage"            # Free testing with watermark

# Verify ffmpeg
ffmpeg -version || brew install ffmpeg
```

### 2. Generate Your First Video

```bash
# Run with existing config and script
python demo/ios_demo_video_generator.py \
  --config demo/configs/app_overview.json \
  --script demo/scripts/app_overview.md
```

Output: `demo/output/app_overview/UnaMentis_App_Overview.mp4`

## How It Works

```
┌──────────────┐    ┌──────────────┐    ┌──────────────┐    ┌──────────────┐
│   CAPTURE    │───▶│     TTS      │───▶│    UPLOAD    │───▶│   ASSEMBLE   │
│  Simulator   │    │  UnaMentis   │    │   Shotstack  │    │    Video     │
└──────────────┘    └──────────────┘    └──────────────┘    └──────────────┘
```

1. **Capture**: Boot simulator, launch app, navigate via deep links, take screenshots/video
2. **TTS**: Generate voice narration using UnaMentis's own TTS server
3. **Upload**: Push assets to Shotstack's CDN
4. **Assemble**: Build timeline, render video, download result

## Commands

| Command | Description |
|---------|-------------|
| `--config <file>` | Config JSON file (required) |
| `--script <file>` | Markdown script for narration |
| `--template` | Print template config |
| `--capture-only` | Only capture, skip video assembly |
| `--skip-capture` | Use existing captures, regenerate video |
| `--skip-preflight` | Skip pre-flight checks |

### Examples

```bash
# Generate template config
python demo/ios_demo_video_generator.py --template > demo/configs/my_demo.json

# Test capture (no video assembly)
python demo/ios_demo_video_generator.py --config demo/configs/my_demo.json --capture-only

# Regenerate video with updated script (uses cached captures)
python demo/ios_demo_video_generator.py \
  --config demo/configs/my_demo.json \
  --script demo/scripts/my_demo.md \
  --skip-capture
```

## Configuration

### Config File (JSON)

```json
{
    "name": "My Demo",
    "version": "1.0.0",

    "simulator_device": "iPhone 16 Pro",
    "app_bundle_id": "com.unamentis.app",

    "tts_method": "unamentis",
    "tts_voice": "nova",
    "tts_rate": 175,

    "shotstack_resolution": "1080",
    "background_color": "#0a0a0f",

    "scenes": [
        {
            "id": "welcome",
            "narration": "",
            "capture": "screenshot",
            "wait_before": 2.0,
            "deep_link": null,
            "effect": "zoomIn",
            "transition": "fade"
        }
    ],

    "output_dir": "./demo/output/my_demo"
}
```

### Script File (Markdown)

```markdown
# My Demo Script

## welcome
Welcome to the app. This is the narration for the welcome scene.

## feature_one
Here's the first feature. Narration can span multiple lines.

## closing
Thanks for watching.
```

The `## header` must match the scene `id` in the config.

## TTS Options

| Method | Description | Requirements |
|--------|-------------|--------------|
| `unamentis` | UnaMentis TTS server (default) | management-api running |
| `macos` | macOS built-in voices | None |
| `custom` | Your own TTS command | `tts_custom_cmd` in config |
| `prerecorded` | Pre-recorded audio files | `tts_prerecorded_dir` |
| `none` | Video only, no narration | None |

### Available Voices (UnaMentis)
- `nova` (default) - Female, natural
- `sarah` - Female, warm
- `john` - Male, professional
- `emma` - Female, friendly
- `alex` - Male, casual

## Deep Links

Navigate within the app using URL schemes:

| Deep Link | Action |
|-----------|--------|
| `unamentis://chat` | Freeform chat |
| `unamentis://learning` | Learning tab |
| `unamentis://analytics` | Analytics tab |
| `unamentis://settings` | Settings tab |
| `unamentis://history` | History tab |

## Directory Structure

```
demo/
├── configs/           # Demo configurations (JSON)
│   └── app_overview.json
├── scripts/           # Narration scripts (Markdown)
│   └── app_overview.md
├── output/            # Generated files (gitignored)
│   └── app_overview/
│       ├── *.png      # Screenshots
│       ├── *_audio.mp3 # Audio narration
│       └── *.mp4      # Final video
├── tests/             # Test coverage
└── ios_demo_video_generator.py  # Main script
```

## Workflow

### Creating a New Demo

1. **Create config**: Copy template or existing config
2. **Create script**: Write narration in markdown
3. **Test capture**: Run with `--capture-only`, review screenshots
4. **Generate video**: Run full pipeline
5. **Iterate**: Edit script, regenerate with `--skip-capture`

### Editing an Existing Demo

1. **Edit script**: Update `demo/scripts/<name>.md`
2. **Regenerate**: Run with `--skip-capture` (uses cached captures and TTS)

## Cost

| Environment | Cost | Output |
|-------------|------|--------|
| `stage` | Free | Watermarked |
| `v1` | ~$0.40/min | Production quality |

Set environment: `export SHOTSTACK_ENV=v1`

## Troubleshooting

### "TTS server not available"
```bash
/service start management-api
```

### "Simulator not found"
```bash
xcrun simctl list devices | grep "iPhone 16 Pro"
```

### "Shotstack API key invalid"
Verify at https://dashboard.shotstack.io

### "ffmpeg not found"
```bash
brew install ffmpeg
```

## Documentation

- [CLAUDE.md](CLAUDE.md) - Detailed Claude Code instructions
- [IOS_DEMO_VIDEO_AUTOMATION.md](IOS_DEMO_VIDEO_AUTOMATION.md) - Deep technical documentation
- [.claude/skills/demo-video/SKILL.md](../.claude/skills/demo-video/SKILL.md) - Skill reference

## Integration

### Claude Code Skill
```
/demo-video generate app_overview   # Full pipeline
/demo-video capture app_overview    # Capture only
/demo-video script app_overview     # View script
```

### CI/CD
See [CLAUDE.md](CLAUDE.md) for GitHub Actions example.
