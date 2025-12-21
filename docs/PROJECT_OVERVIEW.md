# UnaMentis iOS - Project Overview

## Purpose

UnaMentis is an AI-powered voice tutoring app for iOS that enables extended (60-90+ minute) educational conversations. Built to address limitations in existing voice AI (like ChatGPT's Advanced Voice Mode), it provides low-latency, natural voice interaction with curriculum-driven learning.

**Target:** iPhone 15 Pro+ / 16/17 Pro Max
**Goal:** Sub-500ms end-to-end latency with natural interruption handling

---

## Architecture

### Voice Pipeline

All components are **protocol-based and swappable**:

| Component | On-Device | Cloud | Self-Hosted |
|-----------|-----------|-------|-------------|
| **STT** | Apple Speech, GLM-ASR-Nano | Deepgram Nova-3, AssemblyAI, OpenAI Whisper | GLM-ASR server |
| **TTS** | Apple TTS | ElevenLabs, Deepgram Aura-2 | Piper TTS |
| **LLM** | llama.cpp (experimental) | Anthropic Claude, OpenAI GPT-4o | Ollama, llama.cpp server, vLLM |
| **VAD** | Silero (CoreML on Neural Engine) | - | - |

### LLM Routing (PatchPanel)

Intelligent endpoint routing based on:
- Thermal state, memory pressure, battery level
- Network latency and availability
- Cost budgets and task complexity
- A/B testing configurations

### Session Flow

```
Microphone → AudioEngine → VAD → STT (streaming)
    → SessionManager (turn-taking, context)
    → LLM (streaming) → TTS (streaming)
    → AudioEngine → Speaker
```

**States:** Idle → User Speaking → Processing → AI Thinking → AI Speaking → (loop)

---

## Self-Hosted Server Support

UnaMentis can connect to local/LAN servers for zero-cost inference:

| Server Type | Port | Purpose |
|-------------|------|---------|
| Ollama | 11434 | LLM inference (primary target) |
| llama.cpp | 8080 | LLM inference |
| vLLM | 8000 | High-throughput LLM |
| Whisper server | 11401 | STT |
| Piper TTS | 11402 | TTS |

**Features:**
- Auto-discovery of available models/voices
- Health monitoring with fallback
- OpenAI-compatible API support

---

## Curriculum System (VLCF)

**UnaMentis Curriculum Format** - A JSON-based specification designed for conversational AI tutoring:

### Structure
```
Curriculum
├── Metadata (title, version, language)
├── Topics[] (unlimited nesting depth)
│   ├── Learning objectives
│   ├── Transcript segments with stopping points
│   ├── Alternative explanations (simple/technical/analogy)
│   ├── Misconceptions + remediation
│   ├── Assessments
│   └── Nested children[]
└── Glossary
```

### Content Depth Levels
- **Overview** (2-5 min) - Intuition only
- **Introductory** (5-15 min) - Basic concepts
- **Intermediate** (15-30 min) - Moderate detail
- **Advanced** (30-60 min) - In-depth with derivations
- **Graduate** (60-120 min) - Comprehensive
- **Research** (90-180 min) - Paper-level depth

### Importers
- **CK-12 FlexBooks** - EPUB textbooks → VLCF
- **Fast.ai** - Jupyter notebooks → VLCF
- **AI Enrichment Pipeline** - Plain text → rich VLCF via 7-stage LLM transformation

### Standards Alignment
Maps to IEEE LOM, LRMI, SCORM, xAPI, QTI, and 5+ other educational standards.

---

## Data Persistence

**Core Data entities:**
- `Curriculum` - Course containers
- `Topic` - Hierarchical learning units
- `Session` - Recorded conversations with transcripts
- `TopicProgress` - Time spent, mastery scores
- `TranscriptEntry` - Conversation history

---

## Current Status

### Complete
- All services implemented (STT, TTS, LLM, VAD)
- Full UI (Session, Curriculum, History, Analytics, Settings, Debug)
- VLCF 1.0 specification with JSON Schema
- 103+ unit tests, 16+ integration tests passing
- Telemetry, cost tracking, thermal management
- Self-hosted server discovery and health monitoring

### In Progress
- On-device LLM (llama.cpp API compatibility issues)
- GLM-ASR on-device (requires 2.4GB model download)

### Pending User Setup
- API key configuration
- Physical device testing
- Long-session stability validation
- Curriculum content creation

---

## Key Files

| Path | Purpose |
|------|---------|
| `UnaMentis/Core/Session/SessionManager.swift` | Orchestrates voice sessions |
| `UnaMentis/Core/Curriculum/CurriculumEngine.swift` | Curriculum context generation |
| `UnaMentis/Core/Routing/PatchPanelService.swift` | LLM endpoint routing |
| `UnaMentis/Services/LLM/SelfHostedLLMService.swift` | Ollama/llama.cpp integration |
| `curriculum/spec/vlcf-schema.json` | VLCF JSON Schema (1,847 lines) |

---

## Tech Stack

- **Swift 6.0** with strict concurrency (Actor isolation)
- **SwiftUI** for all UI
- **AVFoundation** for audio (AVAudioEngine)
- **CoreML** for on-device VAD
- **Core Data** for persistence
- **XCTest** with real services (no mocks)

---

## Performance Targets

| Metric | Target |
|--------|--------|
| End-to-end latency | <500ms |
| STT latency | <300ms |
| LLM time-to-first-token | <500ms |
| TTS time-to-first-byte | <200ms |
| Session duration | 60-90+ minutes |
