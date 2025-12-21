# Proxmox CPU-Only Server Deployment

This guide covers deploying UnaMentis's AI services on a high-spec server without GPU acceleration.

## Hardware Assumptions

- **CPU:** High core count (16+ cores recommended)
- **RAM:** 64GB+ (ideally 128GB+)
- **Storage:** SSD preferred for model loading
- **GPU:** None (or very basic, not usable for inference)
- **Network:** Gigabit LAN, external access possible

## Reality Check: CPU-Only Inference

### What Works Well on CPU
- **Small LLMs (1B-7B):** Usable with proper optimization
- **Whisper Small/Base:** Real-time or near-real-time STT
- **Piper TTS:** Excellent, CPU-native design
- **Silero models:** Designed for CPU inference

### What Struggles on CPU
- **Large LLMs (13B+):** Very slow, not recommended
- **Whisper Large:** Too slow for real-time
- **Voice cloning models:** Generally too slow

### Realistic Performance Expectations

| Model Size | Typical CPU Speed | Usability |
|------------|-------------------|-----------|
| 1B params | 30-50 tok/s | Excellent |
| 3B params | 15-30 tok/s | Good |
| 7B params | 8-20 tok/s | Acceptable |
| 13B params | 3-8 tok/s | Poor |
| 70B params | <1 tok/s | Unusable |

*Speeds vary significantly based on CPU generation, RAM speed, and quantization*

---

## Deployment Option 1: LXC Container (Recommended)

LXC containers are lightweight and efficient for Proxmox.

### Create the Container

```bash
# On Proxmox host
pct create 200 local:vztmpl/debian-12-standard_12.2-1_amd64.tar.zst \
  --hostname voicelearn-ai \
  --cores 16 \
  --memory 65536 \
  --swap 8192 \
  --rootfs local-lvm:100 \
  --net0 name=eth0,bridge=vmbr0,ip=dhcp \
  --features nesting=1 \
  --unprivileged 1

# Start container
pct start 200

# Enter container
pct enter 200
```

### Container Configuration

Edit `/etc/pve/lxc/200.conf` to optimize for inference:

```conf
# CPU pinning for dedicated cores (optional)
lxc.cgroup2.cpuset.cpus: 0-15

# Memory limits
lxc.cgroup2.memory.max: 68719476736
lxc.cgroup2.memory.swap.max: 8589934592

# Allow higher priority
lxc.cgroup2.cpu.weight: 200
```

---

## Deployment Option 2: VM with CPU Passthrough

For more isolation or specific CPU feature requirements.

### Create VM

```bash
qm create 201 \
  --name voicelearn-ai-vm \
  --cores 16 \
  --memory 65536 \
  --scsihw virtio-scsi-pci \
  --net0 virtio,bridge=vmbr0 \
  --cpu host \
  --numa 1
```

**Important:** Use `--cpu host` to pass through CPU features (AVX2, AVX-512) crucial for inference performance.

---

## Service Stack Setup

### 1. Base System Setup

```bash
# Update system
apt update && apt upgrade -y

# Install essentials
apt install -y \
  build-essential \
  cmake \
  git \
  curl \
  wget \
  python3 \
  python3-pip \
  python3-venv \
  ffmpeg \
  libsndfile1

# Create service directory
mkdir -p /opt/voicelearn
cd /opt/voicelearn
```

---

## Speech-to-Text: Whisper.cpp (Recommended)

### Why whisper.cpp?
- Native C++ implementation, no Python overhead
- Excellent CPU optimization (AVX2/AVX-512)
- Multiple quantization options
- Streaming support via server mode

### Installation

```bash
cd /opt/voicelearn
git clone https://github.com/ggerganov/whisper.cpp.git
cd whisper.cpp

# Build with optimizations
cmake -B build \
  -DCMAKE_BUILD_TYPE=Release \
  -DWHISPER_BUILD_SERVER=ON \
  -DWHISPER_NO_ACCELERATE=ON

cmake --build build --config Release -j$(nproc)
```

### Download Models

```bash
# Download models (choose based on performance needs)
cd models

# Small model - good balance (recommended for CPU)
./download-ggml-model.sh small

# Base model - faster, less accurate
./download-ggml-model.sh base

# Tiny model - fastest, lower quality
./download-ggml-model.sh tiny
```

### Model Performance on CPU

| Model | Size | CPU Realtime Factor | Quality |
|-------|------|---------------------|---------|
| tiny | 75MB | 0.1-0.2x | Basic |
| base | 142MB | 0.2-0.4x | Good |
| small | 466MB | 0.5-1.0x | Very Good |
| medium | 1.5GB | 1.5-3.0x | Excellent |
| large | 3GB | 3.0-6.0x | Best |

*Realtime factor: 1.0x = processes audio in real-time*

### Run Whisper Server

```bash
# Start server (small model)
./build/bin/whisper-server \
  --model models/ggml-small.bin \
  --host 0.0.0.0 \
  --port 8081 \
  --threads 8
```

### Systemd Service

```bash
cat > /etc/systemd/system/whisper-server.service << 'EOF'
[Unit]
Description=Whisper.cpp STT Server
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=/opt/voicelearn/whisper.cpp
ExecStart=/opt/voicelearn/whisper.cpp/build/bin/whisper-server \
  --model /opt/voicelearn/whisper.cpp/models/ggml-small.bin \
  --host 0.0.0.0 \
  --port 8081 \
  --threads 8
Restart=always
RestartSec=3

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable whisper-server
systemctl start whisper-server
```

### API Usage

```bash
# Test transcription
curl -X POST http://localhost:8081/inference \
  -H "Content-Type: multipart/form-data" \
  -F "file=@audio.wav" \
  -F "response_format=json"
```

---

## Alternative STT: Faster-Whisper

Faster-Whisper uses CTranslate2 for better CPU performance.

### Installation

```bash
python3 -m venv /opt/voicelearn/faster-whisper-env
source /opt/voicelearn/faster-whisper-env/bin/activate

pip install faster-whisper
```

### Simple Server

```python
#!/usr/bin/env python3
# /opt/voicelearn/faster-whisper-server.py

from faster_whisper import WhisperModel
from flask import Flask, request, jsonify
import tempfile
import os

app = Flask(__name__)

# Use int8 quantization for CPU
model = WhisperModel("small", device="cpu", compute_type="int8")

@app.route('/v1/audio/transcriptions', methods=['POST'])
def transcribe():
    if 'file' not in request.files:
        return jsonify({"error": "No file provided"}), 400

    audio_file = request.files['file']

    with tempfile.NamedTemporaryFile(suffix='.wav', delete=False) as tmp:
        audio_file.save(tmp.name)

        segments, info = model.transcribe(tmp.name, beam_size=5)

        text = " ".join([segment.text for segment in segments])

        os.unlink(tmp.name)

        return jsonify({
            "text": text.strip(),
            "language": info.language,
            "duration": info.duration
        })

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=8081, threaded=True)
```

---

## Alternative STT: Vosk (Lightweight)

Vosk is designed for CPU inference and has very low latency.

### Installation

```bash
pip install vosk

# Download model
mkdir -p /opt/voicelearn/vosk-models
cd /opt/voicelearn/vosk-models

# Small English model (~50MB)
wget https://alphacephei.com/vosk/models/vosk-model-small-en-us-0.15.zip
unzip vosk-model-small-en-us-0.15.zip

# Larger model for better accuracy
wget https://alphacephei.com/vosk/models/vosk-model-en-us-0.22.zip
unzip vosk-model-en-us-0.22.zip
```

### Vosk Characteristics
- Very fast on CPU
- Lower quality than Whisper
- WebSocket streaming support built-in
- Good for real-time applications

---

## Language Model: Ollama (Recommended)

### Installation

```bash
curl -fsSL https://ollama.com/install.sh | sh
```

### Configure for CPU

Edit `/etc/systemd/system/ollama.service`:

```ini
[Unit]
Description=Ollama Service
After=network.target

[Service]
Type=simple
User=ollama
Group=ollama
ExecStart=/usr/local/bin/ollama serve
Restart=always
RestartSec=3
Environment="OLLAMA_HOST=0.0.0.0:11434"
Environment="OLLAMA_NUM_PARALLEL=2"
Environment="OLLAMA_MAX_LOADED_MODELS=1"

[Install]
WantedBy=multi-user.target
```

### Pull CPU-Optimized Models

```bash
# Recommended models for CPU inference

# Qwen 2.5 - Excellent quality for size
ollama pull qwen2.5:3b        # Fast, good quality
ollama pull qwen2.5:7b        # Better quality, slower

# Llama 3.2 - Great instruction following
ollama pull llama3.2:1b       # Fastest
ollama pull llama3.2:3b       # Good balance

# Phi-3 - Microsoft's efficient model
ollama pull phi3:mini         # 3.8B, very efficient

# Gemma 2 - Google's efficient model
ollama pull gemma2:2b         # Very fast
```

### CPU Performance Tuning

Create a Modelfile for CPU optimization:

```
# /opt/voicelearn/Modelfile.cpu-optimized
FROM qwen2.5:3b

# Reduce context for faster inference
PARAMETER num_ctx 2048

# Optimize for CPU
PARAMETER num_thread 16
PARAMETER num_batch 512

# Reduce temperature for more deterministic output
PARAMETER temperature 0.7
PARAMETER top_p 0.9

SYSTEM """You are a friendly language tutor helping students learn through conversation.
Keep responses concise and conversational."""
```

```bash
ollama create voicelearn-tutor -f /opt/voicelearn/Modelfile.cpu-optimized
```

### Expected Performance

On a modern multi-core CPU (e.g., Xeon, EPYC):

| Model | Q4_K_M Speed | Q8_0 Speed | Memory |
|-------|--------------|------------|---------|
| 1B | 40-60 tok/s | 30-45 tok/s | ~1GB |
| 3B | 20-35 tok/s | 15-25 tok/s | ~2-3GB |
| 7B | 10-20 tok/s | 7-15 tok/s | ~5-6GB |

---

## Alternative LLM: llama.cpp Direct

For more control over inference parameters.

### Installation

```bash
cd /opt/voicelearn
git clone https://github.com/ggerganov/llama.cpp.git
cd llama.cpp

# Build with CPU optimizations
cmake -B build \
  -DCMAKE_BUILD_TYPE=Release \
  -DLLAMA_NATIVE=ON \
  -DLLAMA_BUILD_SERVER=ON

cmake --build build --config Release -j$(nproc)
```

### Download Models

```bash
# From Hugging Face (example: Qwen 2.5 3B)
cd /opt/voicelearn/models

# Install huggingface-cli
pip install huggingface_hub

# Download GGUF model
huggingface-cli download \
  Qwen/Qwen2.5-3B-Instruct-GGUF \
  qwen2.5-3b-instruct-q4_k_m.gguf \
  --local-dir .
```

### Run Server

```bash
./build/bin/llama-server \
  --model /opt/voicelearn/models/qwen2.5-3b-instruct-q4_k_m.gguf \
  --host 0.0.0.0 \
  --port 8080 \
  --threads 16 \
  --ctx-size 2048 \
  --batch-size 512 \
  --parallel 2
```

---

## Text-to-Speech: Piper (Recommended)

Piper is specifically designed for fast CPU inference.

### Installation

```bash
cd /opt/voicelearn

# Download Piper release
wget https://github.com/rhasspy/piper/releases/download/v1.2.0/piper_linux_x86_64.tar.gz
tar -xzf piper_linux_x86_64.tar.gz
mv piper /opt/voicelearn/piper

# Download voices
mkdir -p /opt/voicelearn/piper-voices
cd /opt/voicelearn/piper-voices

# Amy - Natural US English female voice
wget https://huggingface.co/rhasspy/piper-voices/resolve/v1.0.0/en/en_US/amy/medium/en_US-amy-medium.onnx
wget https://huggingface.co/rhasspy/piper-voices/resolve/v1.0.0/en/en_US/amy/medium/en_US-amy-medium.onnx.json

# Danny - US English male voice
wget https://huggingface.co/rhasspy/piper-voices/resolve/v1.0.0/en/en_US/danny/low/en_US-danny-low.onnx
wget https://huggingface.co/rhasspy/piper-voices/resolve/v1.0.0/en/en_US/danny/low/en_US-danny-low.onnx.json
```

### Voice Quality Tiers

| Quality | Speed (RTF) | Notes |
|---------|-------------|-------|
| low | ~0.02x | Very fast, robotic |
| medium | ~0.05x | Good quality, fast |
| high | ~0.1x | Great quality |

*RTF (Real-Time Factor): 0.05x means 1 second of audio generates in 50ms*

### Simple HTTP Server

```python
#!/usr/bin/env python3
# /opt/voicelearn/piper-server.py

from flask import Flask, request, Response
import subprocess
import tempfile
import os

app = Flask(__name__)

PIPER_PATH = "/opt/voicelearn/piper/piper"
VOICE_PATH = "/opt/voicelearn/piper-voices/en_US-amy-medium.onnx"

@app.route('/v1/audio/speech', methods=['POST'])
def synthesize():
    data = request.json
    text = data.get('input', '')

    if not text:
        return {"error": "No text provided"}, 400

    with tempfile.NamedTemporaryFile(suffix='.wav', delete=False) as tmp:
        # Run Piper
        process = subprocess.run(
            [PIPER_PATH, '--model', VOICE_PATH, '--output_file', tmp.name],
            input=text,
            capture_output=True,
            text=True
        )

        if process.returncode != 0:
            return {"error": process.stderr}, 500

        # Read and return audio
        with open(tmp.name, 'rb') as f:
            audio_data = f.read()

        os.unlink(tmp.name)

        return Response(audio_data, mimetype='audio/wav')

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=8082, threaded=True)
```

### Piper HTTP Server (Built-in)

Piper also has a built-in HTTP server:

```bash
# Using piper-http-server
pip install piper-tts

# Run server
piper_http_server \
  --model /opt/voicelearn/piper-voices/en_US-amy-medium.onnx \
  --host 0.0.0.0 \
  --port 8082
```

---

## Alternative TTS: OpenedAI Speech

OpenAI-compatible TTS API using Piper voices.

### Installation

```bash
cd /opt/voicelearn
git clone https://github.com/matatonic/openedai-speech.git
cd openedai-speech

python3 -m venv venv
source venv/bin/activate

pip install -r requirements.txt

# Download default voices
python download_voices.py
```

### Run Server

```bash
python speech.py --host 0.0.0.0 --port 8082
```

### OpenAI-Compatible API

```bash
curl http://localhost:8082/v1/audio/speech \
  -H "Content-Type: application/json" \
  -d '{
    "model": "tts-1",
    "input": "Hello, how are you today?",
    "voice": "nova"
  }' \
  --output speech.mp3
```

---

## Unified API Gateway

Create a unified gateway that combines all services.

### Using Nginx

```nginx
# /etc/nginx/sites-available/voicelearn-api

upstream llm_backend {
    server 127.0.0.1:11434;
}

upstream stt_backend {
    server 127.0.0.1:8081;
}

upstream tts_backend {
    server 127.0.0.1:8082;
}

server {
    listen 8000;
    server_name _;

    # LLM endpoints (Ollama)
    location /v1/chat/completions {
        proxy_pass http://llm_backend/v1/chat/completions;
        proxy_http_version 1.1;
        proxy_set_header Connection "";
        proxy_buffering off;
    }

    # STT endpoint
    location /v1/audio/transcriptions {
        proxy_pass http://stt_backend/v1/audio/transcriptions;
        client_max_body_size 25M;
    }

    # TTS endpoint
    location /v1/audio/speech {
        proxy_pass http://tts_backend/v1/audio/speech;
    }

    # Health check
    location /health {
        return 200 '{"status": "ok"}';
        add_header Content-Type application/json;
    }
}
```

---

## Performance Optimization Tips

### 1. CPU Affinity

Pin services to specific CPU cores:

```bash
# Pin Ollama to cores 0-7
taskset -c 0-7 ollama serve

# Pin Whisper to cores 8-11
taskset -c 8-11 whisper-server ...
```

### 2. Memory Configuration

```bash
# Increase huge pages for better memory performance
echo 4096 > /proc/sys/vm/nr_hugepages

# Add to /etc/sysctl.conf
vm.nr_hugepages = 4096
```

### 3. Disable CPU Frequency Scaling

```bash
# Set to performance mode
for cpu in /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor; do
    echo performance > $cpu
done
```

### 4. NUMA Optimization

If your server has multiple CPU sockets:

```bash
# Check NUMA topology
numactl --hardware

# Run services on specific NUMA node
numactl --cpunodebind=0 --membind=0 ollama serve
```

---

## Docker Compose Alternative

For easier deployment and management:

```yaml
# /opt/voicelearn/docker-compose.yml
version: '3.8'

services:
  ollama:
    image: ollama/ollama:latest
    ports:
      - "11434:11434"
    volumes:
      - ollama-data:/root/.ollama
    environment:
      - OLLAMA_HOST=0.0.0.0:11434
      - OLLAMA_NUM_PARALLEL=2
    deploy:
      resources:
        limits:
          cpus: '8'
          memory: 32G
    restart: unless-stopped

  whisper:
    build:
      context: ./whisper-server
    ports:
      - "8081:8081"
    volumes:
      - ./whisper-models:/models
    command: >
      whisper-server
      --model /models/ggml-small.bin
      --host 0.0.0.0
      --port 8081
      --threads 4
    deploy:
      resources:
        limits:
          cpus: '4'
          memory: 4G
    restart: unless-stopped

  piper:
    image: rhasspy/piper:latest
    ports:
      - "8082:8082"
    volumes:
      - ./piper-voices:/voices
    command: >
      --model /voices/en_US-amy-medium.onnx
      --host 0.0.0.0
      --port 8082
    restart: unless-stopped

  nginx:
    image: nginx:alpine
    ports:
      - "8000:8000"
    volumes:
      - ./nginx.conf:/etc/nginx/conf.d/default.conf:ro
    depends_on:
      - ollama
      - whisper
      - piper
    restart: unless-stopped

volumes:
  ollama-data:
```

---

## Monitoring and Logging

### Prometheus Metrics

Add metrics endpoint to track:
- Inference latency
- Token generation speed
- Memory usage
- Request queue depth

### Log Aggregation

```bash
# journalctl for all services
journalctl -u ollama -u whisper-server -u piper-server -f
```

---

## External Access

### Option 1: Tailscale (Recommended)

```bash
# Install Tailscale
curl -fsSL https://tailscale.com/install.sh | sh

# Authenticate
tailscale up

# Access from anywhere via Tailscale IP
# e.g., http://100.x.x.x:8000
```

### Option 2: Cloudflare Tunnel

```bash
# Install cloudflared
wget https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64
chmod +x cloudflared-linux-amd64

# Create tunnel
./cloudflared-linux-amd64 tunnel create voicelearn

# Configure tunnel
# Map voicelearn.yourdomain.com -> localhost:8000
```

### Option 3: Port Forwarding

Less secure, but simplest for testing:
- Forward router port 8000 -> server:8000
- Use dynamic DNS for stable hostname

---

## Summary: Recommended CPU Stack

| Service | Solution | Model | Expected Latency |
|---------|----------|-------|------------------|
| STT | whisper.cpp | small | ~500-800ms |
| LLM | Ollama | qwen2.5:3b | ~100-200ms TTFT |
| TTS | Piper | amy-medium | ~50-100ms |

**Total pipeline latency:** ~700-1100ms (acceptable for tutoring)

### Strengths
- 24/7 availability
- No API costs
- Full data privacy
- Easy external access

### Limitations
- Cannot run large models (13B+) effectively
- STT slower than real-time for longer audio
- Limited concurrent users (1-2 recommended)

---

## Next Steps

1. Set up LXC container on Proxmox
2. Install Ollama and pull qwen2.5:3b
3. Install whisper.cpp with small model
4. Install Piper with amy-medium voice
5. Configure unified API gateway
6. Set up Tailscale for external access
7. Update UnaMentis app configuration
