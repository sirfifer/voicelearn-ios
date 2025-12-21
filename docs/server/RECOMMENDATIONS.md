# Server Deployment Recommendations

This document provides concrete recommendations for deploying UnaMentis's self-hosted server infrastructure.

## Executive Summary

| Target | Feasibility | Best Use Case |
|--------|-------------|---------------|
| **Proxmox (CPU)** | Good for 3-7B models | Always-on availability, external access |
| **MacBook M4 Max** | Excellent for all sizes | Primary development, high-quality inference |

**Recommended Strategy:** Develop on MacBook M4 Max, deploy to Proxmox for 24/7 availability.

---

## Proxmox CPU Server: Verdict

### Is CPU-Only Viable?

**Yes, with appropriate expectations.**

The Proxmox server is a viable deployment target for UnaMentis, but model selection must be constrained to what CPUs can handle efficiently.

### Recommended Models for CPU

| Service | Model | Performance | Quality |
|---------|-------|-------------|---------|
| **LLM** | Qwen 2.5 3B | ~25-35 tok/s | Good |
| **LLM** | Phi-3 Mini (3.8B) | ~20-30 tok/s | Good |
| **STT** | Whisper Small | ~1.5x realtime | Good |
| **TTS** | Piper Amy Medium | ~0.05x realtime | Excellent |

### What Won't Work on CPU

- LLMs larger than 13B (too slow for interactive use)
- Whisper Large (not real-time)
- Voice cloning TTS (Coqui XTTS, etc.)
- Concurrent users beyond 1-2

### CPU Server Value Proposition

1. **Always available** - No laptop dependency
2. **Easy external access** - Direct port forwarding or Tailscale
3. **Low latency for network** - Dedicated server
4. **Free operation** - No API costs, already running

---

## MacBook M4 Max: Verdict

### Exceptional Capability

The M4 Max is genuinely impressive for AI inference:

- **128GB unified memory** - Can run 70B models
- **400GB/s bandwidth** - Fast token generation
- **MLX optimization** - Native Apple Silicon acceleration

### Recommended Models for M4 Max

| Service | Model | Performance | Quality |
|---------|-------|-------------|---------|
| **LLM** | Qwen 2.5 7B | ~60-80 tok/s | Excellent |
| **LLM** | Qwen 2.5 14B | ~35-50 tok/s | Superior |
| **LLM** | Llama 3.1 70B | ~10-15 tok/s | Best |
| **STT** | Whisper Large-v3 | ~0.1x realtime | Best |
| **TTS** | Piper/StyleTTS2 | Real-time+ | Excellent |

### M4 Max Limitations

1. **Availability** - It's a laptop
2. **External access** - Requires tunneling
3. **Single point of failure** - No redundancy
4. **Power management** - Sleep/wake issues

---

## Hybrid Architecture (Recommended)

Given both targets, the optimal approach is a **hybrid architecture**:

```
┌─────────────────────────────────────────────────────────────────┐
│                    UnaMentis iOS App                           │
│                                                                 │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │                    Patch Panel Router                     │  │
│  │                                                          │  │
│  │  Priority 1: MacBook M4 Max (when available)             │  │
│  │  Priority 2: Proxmox CPU Server (always available)       │  │
│  │  Priority 3: On-device models (offline fallback)         │  │
│  │  Priority 4: Cloud APIs (last resort)                    │  │
│  └──────────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────┘
```

### How It Works

1. **App checks M4 Max health** - If available, use for best quality
2. **Falls back to Proxmox** - Always-on, good enough quality
3. **Graceful degradation** - On-device for scripted content
4. **Cloud backup** - For complex tasks if needed

---

## On-Device First Philosophy

### Scripted Curriculum: No Server Required

For pre-authored curriculum content:

```
Scripted Lesson Flow:
1. Display text prompt (no AI needed)
2. Record student response (on-device VAD)
3. Transcribe response (on-device Whisper or send to server)
4. Compare to expected answer (simple pattern matching)
5. Play feedback (on-device TTS via AVSpeechSynthesizer)
```

This flow requires **zero server dependency** for:
- Vocabulary drills
- Pronunciation practice
- Grammar exercises
- Scripted dialogues

### When Server is Required

Server becomes necessary for:
- Dynamic conversation (unscripted tutoring)
- Content generation (adaptive examples)
- Complex comprehension assessment
- Voice cloning (custom tutor voice)

---

## Implementation Priority

### Phase 1: Local Development (MacBook)

```
Week focus: Get full stack running locally

1. Install Ollama + Qwen 2.5 7B
2. Install whisper.cpp with Metal
3. Install Piper TTS
4. Test all three services
5. Update UnaMentis app to point to localhost
6. Verify end-to-end flow
```

### Phase 2: Proxmox Deployment

```
Week focus: 24/7 availability

1. Create LXC container on Proxmox
2. Install Ollama + Qwen 2.5 3B (CPU-friendly)
3. Install whisper.cpp (small model)
4. Install Piper TTS
5. Configure Tailscale for access
6. Test from iPhone over Tailscale
```

### Phase 3: Routing Integration

```
Week focus: Intelligent failover

1. Implement health checks for both servers
2. Configure Patch Panel for multi-endpoint routing
3. Add automatic failover logic
4. Test failover scenarios
5. Tune latency thresholds
```

### Phase 4: On-Device Fallback

```
Week focus: Offline capability

1. Integrate on-device Whisper (already in app)
2. Configure AVSpeechSynthesizer for fallback TTS
3. Create scripted curriculum renderer
4. Test completely offline flow
5. Optimize for battery/thermal
```

---

## Cost Comparison

### Self-Hosted vs Cloud APIs

**Assumptions:**
- 1 hour of tutoring per day
- 30 days per month
- ~3000 tokens LLM per session
- ~30 minutes audio transcription
- ~10 minutes synthesized speech

### Cloud API Costs (Monthly)

| Service | Provider | Cost |
|---------|----------|------|
| STT | Deepgram Nova | ~$4.50 |
| LLM | GPT-4o | ~$2.25 |
| TTS | Deepgram Aura | ~$1.35 |
| **Total** | | **~$8/month** |

### Self-Hosted Costs (Monthly)

| Item | Cost |
|------|------|
| Electricity (Proxmox) | ~$5-10 already running |
| Internet | Already paying |
| **Total** | **~$0 incremental** |

**Payback:** Immediate (Proxmox already running)

### Where Self-Hosted Wins

1. **Privacy** - Data never leaves your network
2. **Latency** - No cloud round-trip
3. **Availability** - No API quotas or rate limits
4. **Experimentation** - Unlimited usage during development

### Where Cloud Wins

1. **Quality** - GPT-4o/Claude still superior for complex reasoning
2. **Simplicity** - No infrastructure to maintain
3. **Scalability** - Handles any load
4. **Reliability** - Enterprise SLAs

---

## Recommended Starting Configuration

### Minimum Viable Self-Hosted Stack

| Component | Proxmox | MacBook | Notes |
|-----------|---------|---------|-------|
| **LLM** | Qwen 2.5:3b | Qwen 2.5:7b | Ollama |
| **STT** | Whisper small | Whisper large-v3 | whisper.cpp |
| **TTS** | Piper amy-medium | Piper amy-medium | Same quality |

### Expected End-to-End Latency

| Server | User Speaks | STT | LLM | TTS | Total |
|--------|-------------|-----|-----|-----|-------|
| Proxmox | 1-2s | ~600ms | ~200ms | ~50ms | ~850ms |
| MacBook | 1-2s | ~150ms | ~50ms | ~50ms | ~250ms |
| Target | | | | | <500ms |

The MacBook easily hits the target; Proxmox is acceptable.

---

## Technical Recommendations

### API Compatibility

Use **OpenAI-compatible APIs** everywhere for consistency:

```
LLM:  POST /v1/chat/completions
STT:  POST /v1/audio/transcriptions
TTS:  POST /v1/audio/speech
```

Both Ollama and whisper.cpp support these endpoints.

### Health Checking

Implement lightweight health checks:

```swift
// Check every 30 seconds
let healthEndpoints = [
    "http://macbook.local:11434/api/version",
    "http://proxmox.local:11434/api/version"
]
```

### Fallback Strategy

```swift
enum ServerPriority: Int {
    case macbook = 0       // Highest priority when available
    case proxmox = 1       // Always available
    case onDevice = 2      // Offline fallback
    case cloud = 3         // Last resort
}
```

---

## What You Can Build Today

Without any server setup, UnaMentis can still:

1. **Run completely on-device** (with limitations)
2. **Use scripted curriculum** with AVSpeechSynthesizer
3. **Record and playback** user responses
4. **Track progress** with Core Data

With self-hosted servers:

1. **Dynamic tutoring conversations**
2. **High-quality voice synthesis**
3. **Adaptive content generation**
4. **Longer context windows**

---

## Decision Matrix

### When to Use Each Target

| Scenario | Use |
|----------|-----|
| Development & testing | MacBook M4 Max |
| Always-on availability | Proxmox |
| Best possible quality | MacBook M4 Max |
| Testing on the go | Proxmox (via Tailscale) |
| Offline practice | On-device |
| Complex reasoning | Cloud API fallback |

---

## Next Steps

### Immediate (This Week)

1. **On MacBook:**
   ```bash
   brew install ollama
   ollama serve
   ollama pull qwen2.5:7b
   ```

2. **Test basic inference:**
   ```bash
   curl http://localhost:11434/api/generate -d '{"model":"qwen2.5:7b","prompt":"Hello"}'
   ```

3. **Update UnaMentis** to point to `http://localhost:11434`

### Short-term (Next Few Weeks)

1. Set up Proxmox LXC container
2. Install CPU-optimized stack
3. Configure Tailscale on both
4. Implement health checking in app

### Medium-term (Month+)

1. Add automatic failover in Patch Panel
2. Benchmark and tune models
3. Create scripted curriculum system
4. Optimize on-device fallback

---

## Conclusion

**Both deployment targets are viable and complementary:**

- **Proxmox** provides reliability and external access
- **MacBook M4 Max** provides performance and quality
- **Combined** they provide a robust self-hosted solution

The 128GB M4 Max is genuinely impressive - it can run models that would require a $10,000+ GPU server. The Proxmox server, while limited to smaller models, provides the always-on availability that a laptop cannot.

Start with the MacBook for development, deploy to Proxmox for availability, and let the app intelligently route between them.
