# Chatterbox TTS Server Setup

This guide covers deploying and configuring the Chatterbox TTS server for use with UnaMentis.

## Overview

Chatterbox-Turbo is a 350M parameter open-source TTS model from Resemble AI offering:
- 75ms latency, 6x faster than real-time
- Emotion control via exaggeration and CFG weight parameters
- Paralinguistic tags ([laugh], [cough], [sigh], etc.)
- Zero-shot voice cloning (future feature)
- Multilingual support (23 languages with 500M model)
- OpenAI-compatible API

## Prerequisites

- Python 3.11 or higher
- GPU recommended (NVIDIA CUDA, AMD ROCm, or Apple Metal)
- 4GB+ VRAM for Turbo model, 8GB+ for Multilingual model
- Docker (optional, for containerized deployment)

## Quick Start with Docker

### NVIDIA GPU

```bash
docker run -d \
  --name chatterbox \
  --gpus all \
  -p 8004:8004 \
  -e CHATTERBOX_MODEL=turbo \
  ghcr.io/devnen/chatterbox-tts-server:latest
```

### AMD GPU (ROCm)

```bash
docker run -d \
  --name chatterbox \
  --device=/dev/kfd \
  --device=/dev/dri \
  --group-add video \
  -p 8004:8004 \
  -e CHATTERBOX_MODEL=turbo \
  ghcr.io/devnen/chatterbox-tts-server:rocm
```

### CPU Only

```bash
docker run -d \
  --name chatterbox \
  -p 8004:8004 \
  -e CHATTERBOX_MODEL=turbo \
  -e CHATTERBOX_DEVICE=cpu \
  ghcr.io/devnen/chatterbox-tts-server:cpu
```

### Apple Silicon (Native)

Docker is not recommended for Apple Silicon. Use the native installation below.

## Manual Installation

### 1. Clone the Server Repository

```bash
git clone https://github.com/devnen/Chatterbox-TTS-Server.git
cd Chatterbox-TTS-Server
```

### 2. Create Virtual Environment

```bash
python3.11 -m venv venv
source venv/bin/activate
```

### 3. Install Dependencies

```bash
# For NVIDIA GPU
pip install torch torchaudio --index-url https://download.pytorch.org/whl/cu121
pip install -r requirements.txt

# For Apple Silicon
pip install torch torchaudio
pip install -r requirements.txt

# For CPU only
pip install torch torchaudio --index-url https://download.pytorch.org/whl/cpu
pip install -r requirements.txt
```

### 4. Download Models

Models are downloaded automatically on first run, or manually:

```bash
# Turbo model (350M, English, faster)
python -c "from chatterbox import ChatterboxTTS; ChatterboxTTS.from_pretrained('turbo')"

# Multilingual model (500M, 23 languages)
python -c "from chatterbox import ChatterboxTTS; ChatterboxTTS.from_pretrained('multilingual')"
```

### 5. Start the Server

```bash
python server.py --host 0.0.0.0 --port 8004
```

## Configuration Options

### Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `CHATTERBOX_HOST` | `0.0.0.0` | Server bind address |
| `CHATTERBOX_PORT` | `8004` | Server port |
| `CHATTERBOX_MODEL` | `turbo` | Model variant (turbo/multilingual) |
| `CHATTERBOX_DEVICE` | `auto` | Device (cuda/mps/cpu/auto) |
| `CHATTERBOX_WORKERS` | `1` | Number of worker processes |

### Command Line Arguments

```bash
python server.py \
  --host 0.0.0.0 \
  --port 8004 \
  --model turbo \
  --device auto \
  --workers 1
```

## API Endpoints

### Health Check

```bash
curl http://localhost:8004/health
# Returns: {"status": "healthy", "model": "turbo", "device": "cuda"}
```

### Models List

```bash
curl http://localhost:8004/v1/models
# Returns: {"models": ["turbo"], "multilingual_available": false}
```

### OpenAI-Compatible Speech (Non-Streaming)

```bash
curl -X POST http://localhost:8004/v1/audio/speech \
  -H "Content-Type: application/json" \
  -d '{
    "input": "Hello, this is a test.",
    "model": "turbo",
    "voice": "default",
    "response_format": "wav",
    "speed": 1.0,
    "exaggeration": 0.5,
    "cfg_weight": 0.5
  }' \
  --output speech.wav
```

### Streaming TTS

```bash
curl -X POST http://localhost:8004/tts \
  -H "Content-Type: application/json" \
  -d '{
    "text": "Hello, this is a streaming test.",
    "exaggeration": 0.5,
    "cfg_weight": 0.5,
    "speed": 1.0,
    "language": "en"
  }' \
  --output speech_stream.wav
```

## Parameter Reference

| Parameter | Range | Default | Description |
|-----------|-------|---------|-------------|
| `exaggeration` | 0.0-1.5 | 0.5 | Emotion intensity (0=monotone, 1.5=dramatic) |
| `cfg_weight` | 0.0-1.0 | 0.5 | Generation fidelity (lower for fast/dramatic speech) |
| `speed` | 0.5-2.0 | 1.0 | Speaking rate multiplier |
| `seed` | 0-999999 | random | Seed for reproducible output |
| `language` | ISO code | "en" | Language (multilingual model only) |

### Paralinguistic Tags

When enabled, these tags in text trigger natural vocal reactions:

| Tag | Effect |
|-----|--------|
| `[laugh]` | Natural laughter |
| `[chuckle]` | Soft chuckle |
| `[sigh]` | Audible sigh |
| `[gasp]` | Sharp intake of breath |
| `[cough]` | Clearing throat |
| `[yawn]` | Tired yawn |

Example: `"That's hilarious! [laugh] I can't believe it."`

## Supported Languages (Multilingual Model)

| Code | Language | Code | Language |
|------|----------|------|----------|
| ar | Arabic | ko | Korean |
| zh | Chinese | ms | Malay |
| da | Danish | no | Norwegian |
| nl | Dutch | pl | Polish |
| en | English | pt | Portuguese |
| fi | Finnish | ru | Russian |
| fr | French | es | Spanish |
| de | German | sw | Swahili |
| el | Greek | sv | Swedish |
| he | Hebrew | tr | Turkish |
| hi | Hindi | | |
| it | Italian | | |
| ja | Japanese | | |

## UnaMentis Integration

### 1. Configure Server IP

In the UnaMentis app:
1. Go to Settings > TTS
2. Enable "Self-Hosted Servers"
3. Enter your server IP address
4. Select "Chatterbox (24kHz)" as the TTS provider

### 2. Verify Connection

The app will show a green checkmark if the server is reachable. You can also tap "Refresh Status" in Chatterbox Settings.

### 3. Configure Parameters

Use the Chatterbox Settings screen to adjust:
- Preset (Default, Natural, Expressive, Low Latency)
- Exaggeration and CFG Weight sliders
- Speed control
- Paralinguistic tags toggle
- Language selection (if multilingual model available)
- Streaming mode toggle
- Reproducibility seed

### 4. Test Voice

Use the "Test Voice" button in Chatterbox Settings to verify synthesis is working.

## Running as a Service

### systemd (Linux)

Create `/etc/systemd/system/chatterbox.service`:

```ini
[Unit]
Description=Chatterbox TTS Server
After=network.target

[Service]
Type=simple
User=chatterbox
WorkingDirectory=/opt/chatterbox
ExecStart=/opt/chatterbox/venv/bin/python server.py --host 0.0.0.0 --port 8004
Restart=always
RestartSec=10
Environment=CHATTERBOX_MODEL=turbo
Environment=CHATTERBOX_DEVICE=auto

[Install]
WantedBy=multi-user.target
```

Enable and start:

```bash
sudo systemctl daemon-reload
sudo systemctl enable chatterbox
sudo systemctl start chatterbox
```

### launchd (macOS)

Create `~/Library/LaunchAgents/com.unamentis.chatterbox.plist`:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.unamentis.chatterbox</string>
    <key>ProgramArguments</key>
    <array>
        <string>/opt/chatterbox/venv/bin/python</string>
        <string>/opt/chatterbox/server.py</string>
        <string>--host</string>
        <string>0.0.0.0</string>
        <string>--port</string>
        <string>8004</string>
    </array>
    <key>RunAtLoad</key>
    <true/>
    <key>KeepAlive</key>
    <true/>
    <key>WorkingDirectory</key>
    <string>/opt/chatterbox</string>
</dict>
</plist>
```

Load the service:

```bash
launchctl load ~/Library/LaunchAgents/com.unamentis.chatterbox.plist
```

## Troubleshooting

### Server Not Starting

1. Check Python version: `python3 --version` (must be 3.11+)
2. Verify dependencies: `pip list | grep torch`
3. Check port availability: `lsof -i :8004`
4. Review logs: `journalctl -u chatterbox -f` (Linux)

### Connection Refused

1. Verify server is running: `curl http://localhost:8004/health`
2. Check firewall rules allow port 8004
3. Ensure server binds to `0.0.0.0` not `127.0.0.1`
4. Verify iOS device is on same network as server

### Slow Performance

1. Ensure GPU is being used: check health endpoint for device type
2. Use Turbo model instead of Multilingual for lower latency
3. Enable streaming mode for lower perceived latency
4. Reduce exaggeration for faster generation

### Audio Quality Issues

1. Adjust CFG weight (lower for dramatic speech)
2. Try different exaggeration levels
3. Use reproducible seed to compare outputs
4. Ensure sample rate matches (24000 Hz)

### Out of Memory

1. Use Turbo model (350M) instead of Multilingual (500M)
2. Reduce batch size if processing multiple requests
3. Restart server to clear memory
4. Consider CPU fallback for limited VRAM systems

## Performance Benchmarks

Measured on NVIDIA RTX 4090:

| Model | Latency | RTF | VRAM |
|-------|---------|-----|------|
| Turbo | 75ms | 0.16x | 2.5GB |
| Multilingual | 120ms | 0.25x | 4.2GB |

RTF = Real-Time Factor (lower is faster)

## References

- [Chatterbox TTS GitHub](https://github.com/resemble-ai/chatterbox)
- [Chatterbox TTS Server](https://github.com/devnen/Chatterbox-TTS-Server)
- [Resemble AI Blog Post](https://www.resemble.ai/introducing-chatterbox/)
