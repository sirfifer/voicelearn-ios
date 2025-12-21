# UnaMentis Server Deployment Guide

This documentation explores self-hosted server options for UnaMentis, enabling zero-cost or low-cost AI inference without relying on cloud API providers.

## Overview

UnaMentis requires three core AI services:

| Service | Purpose | Latency Target |
|---------|---------|----------------|
| **STT** (Speech-to-Text) | Transcribe user speech | < 200ms P50 |
| **LLM** (Language Model) | Generate tutor responses | < 500ms TTFT |
| **TTS** (Text-to-Speech) | Synthesize tutor voice | < 150ms first audio |

## Deployment Targets

We're exploring two self-hosted deployment options:

### 1. Proxmox Server (CPU-Only)

**Hardware Profile:**
- High core count (many CPU cores)
- Large RAM (hundreds of GB)
- **No GPU acceleration**
- Always-on, 24/7 availability
- Easy to expose externally

**Best For:** Serving smaller models, handling concurrent requests with CPU parallelism

**Documentation:** [PROXMOX_CPU_DEPLOYMENT.md](./PROXMOX_CPU_DEPLOYMENT.md)

---

### 2. MacBook Pro M4 Max

**Hardware Profile:**
- Apple M4 Max chip
- 128GB unified memory
- 40-core GPU (Metal/MLX acceleration)
- High memory bandwidth (~400 GB/s)
- Intermittent availability (laptop)

**Best For:** Running larger models efficiently, rapid experimentation

**Documentation:** [MACBOOK_M4_DEPLOYMENT.md](./MACBOOK_M4_DEPLOYMENT.md)

---

## Quick Comparison

| Aspect | Proxmox (CPU) | MacBook M4 Max |
|--------|---------------|----------------|
| **Availability** | 24/7 | Intermittent |
| **LLM Performance** | ~10-30 tok/s (7B) | ~50-100+ tok/s (7B) |
| **Max Practical Model** | 7-13B parameters | 70B+ parameters |
| **STT Latency** | ~500-1000ms | ~100-300ms |
| **TTS Quality** | Good (CPU models) | Excellent (MLX) |
| **External Access** | Easy | Requires tunnel |
| **Power Cost** | Always running | On-demand |

---

## Service Stack Options

### Speech-to-Text (STT)

| Solution | CPU Performance | M4 Max Performance | Notes |
|----------|-----------------|-------------------|-------|
| **whisper.cpp** | Good (small/base) | Excellent | Best CPU option |
| **faster-whisper** | Very Good | Excellent | CTranslate2 optimized |
| **Silero STT** | Excellent | Excellent | Lightweight, fast |
| **Vosk** | Good | Good | Offline-first design |

### Language Models (LLM)

| Solution | CPU Performance | M4 Max Performance | Notes |
|----------|-----------------|-------------------|-------|
| **llama.cpp** | Fair-Good | Excellent | Best compatibility |
| **Ollama** | Fair-Good | Excellent | Easy deployment |
| **vLLM (CPU)** | Fair | N/A | Production-grade |
| **MLX** | N/A | Best | Apple Silicon native |

### Text-to-Speech (TTS)

| Solution | CPU Performance | M4 Max Performance | Notes |
|----------|-----------------|-------------------|-------|
| **Piper TTS** | Excellent | Excellent | Fast, many voices |
| **Coqui XTTS** | Slow | Good | Voice cloning |
| **StyleTTS2** | Slow | Good | High quality |
| **OpenedAI Speech** | Good | Good | OpenAI-compatible API |

---

## Architecture Philosophy

### On-Device First
The iOS app is designed to work with scripted curriculum rendered via on-device TTS (AVSpeechSynthesizer) when server is unavailable. This ensures:
- Offline functionality for pre-authored content
- No server dependency for basic usage
- Graceful degradation

### Server Enhancement
Self-hosted servers enable:
- Dynamic AI-generated responses
- Higher quality voice synthesis
- Larger context windows
- More sophisticated tutoring interactions

### Hybrid Approach
The Patch Panel routing system supports intelligent fallback:
```
Server Available → Use self-hosted inference
Server Unavailable → Fall back to on-device or cloud
```

---

## Network Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                     Home Network                             │
│                                                             │
│  ┌──────────────┐     ┌──────────────┐     ┌─────────────┐ │
│  │   Proxmox    │     │  MacBook Pro │     │   Router    │ │
│  │   Server     │     │   M4 Max     │     │             │ │
│  │              │     │              │     │  ┌───────┐  │ │
│  │ ┌──────────┐ │     │ ┌──────────┐ │     │  │ Port  │  │ │
│  │ │ LXC/VM   │ │     │ │ Ollama   │ │     │  │Forward│  │ │
│  │ │ Ollama   │ │     │ │ MLX      │ │     │  └───────┘  │ │
│  │ │ Whisper  │ │     │ │ Whisper  │ │     │      │      │ │
│  │ │ Piper    │ │     │ │ Piper    │ │     │      │      │ │
│  │ └──────────┘ │     │ └──────────┘ │     │      │      │ │
│  │      │       │     │      │       │     │      │      │ │
│  └──────┼───────┘     └──────┼───────┘     └──────┼──────┘ │
│         │                    │                    │        │
│         └────────────────────┴────────────────────┘        │
│                              │                              │
└──────────────────────────────┼──────────────────────────────┘
                               │
                    ┌──────────┴──────────┐
                    │     Internet        │
                    │  (Tailscale/VPN/    │
                    │   Port Forward)     │
                    └──────────┬──────────┘
                               │
                    ┌──────────┴──────────┐
                    │   iPhone Testing    │
                    │   (On the go)       │
                    └─────────────────────┘
```

---

## Recommended Reading Order

1. **This README** - Overview and comparison
2. **[PROXMOX_CPU_DEPLOYMENT.md](./PROXMOX_CPU_DEPLOYMENT.md)** - CPU-only server setup
3. **[MACBOOK_M4_DEPLOYMENT.md](./MACBOOK_M4_DEPLOYMENT.md)** - Apple Silicon setup
4. **[RECOMMENDATIONS.md](./RECOMMENDATIONS.md)** - Final recommendations and next steps

---

## Related Documentation

- [GLM_ASR_SERVER_TRD.md](../GLM_ASR_SERVER_TRD.md) - GPU-based STT server (requires CUDA)
- [PATCH_PANEL_ARCHITECTURE.md](../PATCH_PANEL_ARCHITECTURE.md) - LLM routing system
- [UnaMentis_TDD.md](../UnaMentis_TDD.md) - Complete technical design

---

## Quick Start

**For immediate experimentation:**

1. Install Ollama on your MacBook: `brew install ollama`
2. Start Ollama: `ollama serve`
3. Pull a model: `ollama pull llama3.2:3b`
4. Update UnaMentis to point to `http://localhost:11434`

See the detailed guides for production-ready setups.
