# MacBook Pro M4 Max Server Deployment

This guide covers deploying UnaMentis's AI services on a MacBook Pro with M4 Max chip, leveraging Apple Silicon's exceptional AI inference capabilities.

## Hardware Profile

**MacBook Pro M4 Max:**
- **CPU:** 14-16 core (10-12 performance + 4 efficiency)
- **GPU:** 40-core GPU (Metal/MLX acceleration)
- **NPU:** 16-core Neural Engine
- **RAM:** 128GB unified memory
- **Memory Bandwidth:** ~400 GB/s
- **Storage:** Fast NVMe SSD

## Why M4 Max is Exceptional for AI

### Unified Memory Advantage

Unlike traditional GPU systems where VRAM limits model size, M4 Max can:
- Load models into unified memory (shared CPU/GPU)
- Run **70B+ parameter models** with full context
- No VRAM limitations - use the full 128GB

### Performance Expectations

| Model Size | Tokens/Second | Notes |
|------------|---------------|-------|
| 1B | 150-200+ tok/s | Near-instant |
| 3B | 80-120 tok/s | Excellent |
| 7-8B | 50-80 tok/s | Very good |
| 13B | 35-50 tok/s | Good |
| 34B | 15-25 tok/s | Usable |
| 70B | 8-15 tok/s | Slow but works |

*Speeds with MLX framework and Q4 quantization*

---

## MLX: Apple's Native Framework

### What is MLX?

MLX is Apple's machine learning framework designed specifically for Apple Silicon. It offers:
- Native Metal GPU acceleration
- Unified memory utilization
- Lazy computation for efficiency
- NumPy-like API

### Installation

```bash
# Install MLX
pip install mlx

# Install MLX-LM for language models
pip install mlx-lm

# Install MLX community tools
pip install mlx-community
```

### Using MLX-LM Directly

```python
from mlx_lm import load, generate

# Load model (downloads if needed)
model, tokenizer = load("mlx-community/Qwen2.5-7B-Instruct-4bit")

# Generate response
response = generate(
    model,
    tokenizer,
    prompt="You are a helpful tutor. Explain photosynthesis briefly.",
    max_tokens=200
)
print(response)
```

### MLX Models Hub

Pre-converted models optimized for MLX:
- [mlx-community on Hugging Face](https://huggingface.co/mlx-community)

**Recommended Models:**
```bash
# View available models
python -c "from huggingface_hub import list_models; [print(m.id) for m in list_models(author='mlx-community', limit=20)]"

# Download specific models
python -c "from mlx_lm import load; load('mlx-community/Qwen2.5-7B-Instruct-4bit')"
python -c "from mlx_lm import load; load('mlx-community/Llama-3.2-3B-Instruct-4bit')"
python -c "from mlx_lm import load; load('mlx-community/Mistral-7B-Instruct-v0.3-4bit')"
```

---

## Option 1: Ollama (Recommended for Simplicity)

Ollama works excellently on Apple Silicon with automatic Metal acceleration.

### Installation

```bash
# Install via Homebrew
brew install ollama

# Or download from ollama.com
```

### Start Server

```bash
# Start Ollama service
ollama serve

# Runs on http://localhost:11434 by default
```

### Pull Models

```bash
# Excellent for tutoring (recommended)
ollama pull qwen2.5:7b          # Great quality, fast
ollama pull llama3.2:3b         # Fast, good for quick tasks

# High capability models (your 128GB RAM enables these!)
ollama pull qwen2.5:32b         # Excellent quality
ollama pull llama3.1:70b        # Top tier (will use ~40GB)
ollama pull mixtral:8x7b        # MoE model, very capable

# For multi-language tutoring
ollama pull qwen2.5:14b         # Excellent multilingual
```

### Configure for Performance

Create optimized models:

```
# ~/voicelearn-tutor.Modelfile
FROM qwen2.5:7b

# Large context for tutoring conversations
PARAMETER num_ctx 8192

# Use all GPU cores
PARAMETER num_gpu 99

# Optimize generation
PARAMETER temperature 0.7
PARAMETER top_p 0.9
PARAMETER repeat_penalty 1.1

SYSTEM """You are an expert language tutor. You help students learn through
natural conversation. Be encouraging, clear, and adapt to the student's level.
Keep responses conversational and concise."""
```

```bash
ollama create voicelearn-tutor -f ~/voicelearn-tutor.Modelfile
```

### Performance on M4 Max

| Model | Ollama Speed | Memory Usage |
|-------|--------------|--------------|
| qwen2.5:3b | ~100 tok/s | ~3GB |
| qwen2.5:7b | ~60-80 tok/s | ~5GB |
| qwen2.5:14b | ~35-50 tok/s | ~10GB |
| qwen2.5:32b | ~20-30 tok/s | ~20GB |
| llama3.1:70b | ~10-15 tok/s | ~40GB |

---

## Option 2: MLX-Server (Maximum Performance)

For the fastest possible inference, use MLX directly with a custom server.

### MLX LM Server

```bash
# Install server
pip install mlx-lm[server]

# Run server
mlx_lm.server --model mlx-community/Qwen2.5-7B-Instruct-4bit --port 8080
```

### Custom High-Performance Server

```python
#!/usr/bin/env python3
# ~/voicelearn/mlx-server.py

from fastapi import FastAPI, HTTPException
from fastapi.responses import StreamingResponse
from pydantic import BaseModel
from mlx_lm import load, generate, stream_generate
import uvicorn
import json

app = FastAPI()

# Load model at startup
print("Loading model...")
model, tokenizer = load("mlx-community/Qwen2.5-7B-Instruct-4bit")
print("Model loaded!")

class ChatMessage(BaseModel):
    role: str
    content: str

class ChatRequest(BaseModel):
    model: str = "qwen2.5-7b"
    messages: list[ChatMessage]
    max_tokens: int = 1024
    temperature: float = 0.7
    stream: bool = False

def format_messages(messages):
    """Format messages for the model."""
    formatted = ""
    for msg in messages:
        if msg.role == "system":
            formatted += f"<|im_start|>system\n{msg.content}<|im_end|>\n"
        elif msg.role == "user":
            formatted += f"<|im_start|>user\n{msg.content}<|im_end|>\n"
        elif msg.role == "assistant":
            formatted += f"<|im_start|>assistant\n{msg.content}<|im_end|>\n"
    formatted += "<|im_start|>assistant\n"
    return formatted

@app.post("/v1/chat/completions")
async def chat_completions(request: ChatRequest):
    prompt = format_messages(request.messages)

    if request.stream:
        async def generate_stream():
            for token in stream_generate(
                model,
                tokenizer,
                prompt=prompt,
                max_tokens=request.max_tokens,
                temp=request.temperature
            ):
                chunk = {
                    "choices": [{
                        "delta": {"content": token},
                        "index": 0
                    }]
                }
                yield f"data: {json.dumps(chunk)}\n\n"
            yield "data: [DONE]\n\n"

        return StreamingResponse(
            generate_stream(),
            media_type="text/event-stream"
        )
    else:
        response = generate(
            model,
            tokenizer,
            prompt=prompt,
            max_tokens=request.max_tokens,
            temp=request.temperature
        )
        return {
            "choices": [{
                "message": {"role": "assistant", "content": response},
                "index": 0
            }]
        }

@app.get("/health")
def health():
    return {"status": "ok", "model": "qwen2.5-7b"}

if __name__ == "__main__":
    uvicorn.run(app, host="0.0.0.0", port=8080)
```

### Run the Server

```bash
pip install fastapi uvicorn
python mlx-server.py
```

---

## Speech-to-Text: Whisper on Apple Silicon

### Option A: whisper.cpp with Metal

```bash
# Clone and build
git clone https://github.com/ggerganov/whisper.cpp
cd whisper.cpp

# Build with Metal support
cmake -B build -DWHISPER_METAL=ON
cmake --build build --config Release

# Download models
cd models
./download-ggml-model.sh medium
./download-ggml-model.sh large-v3
```

### Performance with Metal

| Model | M4 Max Speed | Realtime Factor |
|-------|--------------|-----------------|
| tiny | ~0.01x | 100x faster |
| base | ~0.02x | 50x faster |
| small | ~0.03x | 33x faster |
| medium | ~0.05x | 20x faster |
| large-v3 | ~0.1x | 10x faster |

**You can easily run `large-v3` for maximum quality!**

### Run Whisper Server

```bash
./build/bin/whisper-server \
  --model models/ggml-large-v3.bin \
  --host 0.0.0.0 \
  --port 8081 \
  --threads 8 \
  --gpu
```

### Option B: MLX Whisper

```bash
# Install
pip install mlx-whisper

# Use in Python
import mlx_whisper

result = mlx_whisper.transcribe(
    "audio.wav",
    path_or_hf_repo="mlx-community/whisper-large-v3-mlx"
)
print(result["text"])
```

### MLX Whisper Server

```python
#!/usr/bin/env python3
# ~/voicelearn/whisper-server.py

from fastapi import FastAPI, UploadFile, File
import mlx_whisper
import tempfile
import os

app = FastAPI()

@app.post("/v1/audio/transcriptions")
async def transcribe(file: UploadFile = File(...)):
    # Save uploaded file
    with tempfile.NamedTemporaryFile(suffix='.wav', delete=False) as tmp:
        content = await file.read()
        tmp.write(content)
        tmp_path = tmp.name

    try:
        # Transcribe with MLX Whisper
        result = mlx_whisper.transcribe(
            tmp_path,
            path_or_hf_repo="mlx-community/whisper-large-v3-mlx"
        )
        return {"text": result["text"]}
    finally:
        os.unlink(tmp_path)

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8081)
```

---

## Text-to-Speech Options

### Option A: Piper (Fast, CPU)

Same as Proxmox setup - Piper runs excellently on M4's CPU cores.

```bash
# Install via Homebrew
brew install piper

# Or download binary
wget https://github.com/rhasspy/piper/releases/download/v1.2.0/piper_macos_aarch64.tar.gz
tar -xzf piper_macos_aarch64.tar.gz
```

### Option B: MLX Audio TTS (Experimental)

```bash
pip install mlx-audio

# Download TTS model
# (MLX TTS models are still emerging)
```

### Option C: Bark TTS (High Quality)

```python
from bark import SAMPLE_RATE, generate_audio, preload_models
import scipy.io.wavfile as wav

# Preload (slow first time)
preload_models()

# Generate
audio = generate_audio("Hello, how are you today?")
wav.write("output.wav", SAMPLE_RATE, audio)
```

**Note:** Bark is slower but produces very natural speech.

### Option D: StyleTTS2 (Premium Quality)

```bash
git clone https://github.com/yl4579/StyleTTS2
cd StyleTTS2

# Install dependencies
pip install -r requirements.txt

# Download models
# (Follow StyleTTS2 setup instructions)
```

**Recommendation:** Start with Piper for speed, experiment with Bark/StyleTTS2 for quality.

---

## Complete Server Stack

### Directory Structure

```
~/voicelearn-server/
├── start-all.sh           # Start all services
├── stop-all.sh            # Stop all services
├── llm/
│   ├── mlx-server.py      # MLX LLM server
│   └── config.yaml
├── stt/
│   ├── whisper-server.py  # MLX Whisper server
│   └── models/
├── tts/
│   ├── piper-server.py    # Piper TTS server
│   └── voices/
└── gateway/
    └── nginx.conf         # API gateway
```

### Master Start Script

```bash
#!/bin/bash
# ~/voicelearn-server/start-all.sh

echo "Starting UnaMentis AI Server Stack..."

# Start Ollama (or MLX server)
echo "Starting LLM server..."
ollama serve &
sleep 2

# Start Whisper server
echo "Starting STT server..."
cd ~/voicelearn-server/stt
python whisper-server.py &
sleep 2

# Start TTS server
echo "Starting TTS server..."
cd ~/voicelearn-server/tts
python piper-server.py &
sleep 2

echo "All services started!"
echo "LLM: http://localhost:11434"
echo "STT: http://localhost:8081"
echo "TTS: http://localhost:8082"
```

### Launchd Service (Auto-start on Boot)

Create `~/Library/LaunchAgents/com.unamentis.server.plist`:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.unamentis.server</string>
    <key>ProgramArguments</key>
    <array>
        <string>/bin/bash</string>
        <string>-c</string>
        <string>~/voicelearn-server/start-all.sh</string>
    </array>
    <key>RunAtLoad</key>
    <true/>
    <key>KeepAlive</key>
    <true/>
    <key>StandardOutPath</key>
    <string>/tmp/voicelearn-server.log</string>
    <key>StandardErrorPath</key>
    <string>/tmp/voicelearn-server.err</string>
</dict>
</plist>
```

Load with:
```bash
launchctl load ~/Library/LaunchAgents/com.unamentis.server.plist
```

---

## Managing Laptop Availability

The main challenge with using a MacBook as a server is availability.

### Option 1: Clamshell Mode (Lid Closed)

Run the MacBook with the lid closed, connected to power.

```bash
# Prevent sleep when lid closed (with power connected)
sudo pmset -c disablesleep 1

# Re-enable later
sudo pmset -c disablesleep 0
```

**Requirements:**
- External monitor/display (or dummy HDMI plug)
- Connected to power
- External keyboard/mouse if needed

### Option 2: Caffeine/Amphetamine

Keep the Mac awake automatically:

```bash
# Install Amphetamine from App Store
# Or use built-in caffeinate
caffeinate -d -i -s &
```

### Option 3: Wake-on-LAN

Enable Wake on LAN for remote wake:

```bash
# System Preferences > Battery > Options
# Enable "Wake for network access"
```

### Option 4: Schedule Wake

```bash
# Wake at 8am, sleep at midnight
sudo pmset repeat wake MTWRFSU 08:00:00 sleep MTWRFSU 00:00:00
```

---

## External Access

### Option 1: Tailscale (Recommended)

```bash
# Install Tailscale
brew install tailscale

# Start and authenticate
tailscale up

# Your Mac is now accessible at 100.x.x.x from anywhere
```

### Option 2: Cloudflare Tunnel

```bash
# Install cloudflared
brew install cloudflared

# Create tunnel
cloudflared tunnel create voicelearn

# Configure in ~/.cloudflared/config.yml
# Map voicelearn.yourdomain.com -> localhost:8080
```

### Option 3: ngrok (Quick Testing)

```bash
# Install ngrok
brew install ngrok

# Expose port
ngrok http 8080

# Get public URL (changes each time)
```

---

## Resource Management

### Monitor Performance

```bash
# Watch GPU utilization
sudo powermetrics --samplers gpu_power -i 1000

# Watch memory pressure
vm_stat 1

# Activity Monitor with Metal stats
# Activity Monitor > Window > GPU History
```

### Thermal Management

Heavy inference will generate heat. Monitor temps:

```bash
# Install temperature monitoring
brew install osx-cpu-temp

# Or use smctemp
sudo smctemp
```

**Tips:**
- Use a laptop stand for airflow
- Consider a cooling pad for sustained loads
- Keep ambient temperature cool

### Battery Considerations

For server use, keep plugged in:

```bash
# Optimize for plugged-in operation
sudo pmset -c lowpowermode 0
sudo pmset -c sleep 0
```

---

## Testing the Setup

### Test LLM

```bash
# Ollama
curl http://localhost:11434/api/generate -d '{
  "model": "qwen2.5:7b",
  "prompt": "Explain photosynthesis in one sentence.",
  "stream": false
}'

# MLX Server
curl http://localhost:8080/v1/chat/completions -d '{
  "messages": [{"role": "user", "content": "Hello!"}]
}'
```

### Test STT

```bash
# Record audio
say "Hello, this is a test" -o test.aiff
afconvert test.aiff test.wav -d LEI16

# Transcribe
curl -X POST http://localhost:8081/v1/audio/transcriptions \
  -F "file=@test.wav"
```

### Test TTS

```bash
curl -X POST http://localhost:8082/v1/audio/speech \
  -H "Content-Type: application/json" \
  -d '{"input": "Hello, this is a test."}' \
  -o output.wav

afplay output.wav
```

---

## Recommended Configuration

### For Language Tutoring

| Service | Solution | Model | Expected Latency |
|---------|----------|-------|------------------|
| LLM | Ollama | qwen2.5:7b | ~20-50ms TTFT |
| STT | whisper.cpp | large-v3 | ~100-200ms |
| TTS | Piper | amy-medium | ~30-50ms |

**Total latency:** ~150-300ms (excellent)

### For Maximum Quality

| Service | Solution | Model | Expected Latency |
|---------|----------|-------|------------------|
| LLM | Ollama | qwen2.5:32b | ~50-100ms TTFT |
| STT | MLX Whisper | large-v3 | ~100-200ms |
| TTS | StyleTTS2 | - | ~200-400ms |

---

## Summary

### Strengths
- Runs large models (up to 70B) comfortably
- Very fast inference (50-100+ tok/s for 7B)
- Excellent STT with large-v3 Whisper
- Unified memory eliminates VRAM constraints
- Low power for performance delivered

### Limitations
- Laptop form factor (availability concerns)
- No true 24/7 without intervention
- External access requires tunneling
- Single point of failure

### Best Use Cases
- Rapid experimentation with different models
- Development and testing
- High-quality inference when available
- Primary server with Proxmox as fallback

---

## Quick Start Checklist

1. [ ] Install Homebrew: `/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"`
2. [ ] Install Ollama: `brew install ollama`
3. [ ] Start Ollama: `ollama serve`
4. [ ] Pull model: `ollama pull qwen2.5:7b`
5. [ ] Install Python tools: `pip install mlx mlx-lm mlx-whisper`
6. [ ] Install Tailscale: `brew install tailscale && tailscale up`
7. [ ] Configure sleep prevention: `sudo pmset -c disablesleep 1`
8. [ ] Test from iPhone via Tailscale IP
