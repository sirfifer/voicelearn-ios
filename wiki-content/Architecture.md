# Architecture Overview

UnaMentis is a multi-component system for voice-based AI tutoring.

## System Overview

```
┌─────────────────┐     ┌─────────────────┐     ┌─────────────────┐
│    iOS App      │────▶│  Management API │────▶│   AI Services   │
│  (Swift/SwiftUI)│     │   (Python)      │     │  (STT/TTS/LLM)  │
└─────────────────┘     └─────────────────┘     └─────────────────┘
                              │
                              ▼
                        ┌─────────────────┐
                        │  Web Interface  │
                        │   (Next.js)     │
                        └─────────────────┘
```

## Components

### iOS App (UnaMentis/)

The primary user interface for voice tutoring.

**Technology**: Swift 6.0, SwiftUI, Combine

**Key Features**:
- Voice capture and playback
- Real-time conversation UI
- Session management
- Curriculum navigation

**Architecture Pattern**: MVVM with actors for concurrency

### Management API (server/management/)

Backend orchestration and AI service integration.

**Technology**: Python, aiohttp, async/await

**Port**: 8766

**Responsibilities**:
- AI provider orchestration
- Session state management
- Curriculum serving
- Latency monitoring

### Web Interface (server/web/)

Administrative dashboard and monitoring.

**Technology**: Next.js 14, React, TypeScript

**Port**: 3000

**Features**:
- Dashboard and monitoring
- Configuration management
- Curriculum management
- Real-time metrics

## Voice Pipeline

See [[Voice-Pipeline]] for detailed voice processing architecture.

### Latency Targets

| Stage | Target |
|-------|--------|
| Speech-to-Text | <200ms |
| LLM Processing | <300ms |
| Text-to-Speech | <200ms |
| **End-to-End** | **<500ms** |

## AI Providers

### Speech-to-Text (STT)

- Groq Whisper (primary)
- Deepgram Nova-2
- OpenAI Whisper
- Local Whisper

### Large Language Models (LLM)

- Claude (primary)
- GPT-4o
- Llama (local)

### Text-to-Speech (TTS)

- ElevenLabs (primary)
- OpenAI TTS
- Azure Neural TTS

## Data Flow

1. User speaks into iOS app
2. Audio streamed to Management API
3. STT converts speech to text
4. LLM generates response
5. TTS converts response to audio
6. Audio streamed back to iOS app

## Key Design Decisions

### Actor-Based Concurrency

Swift 6.0 actors for thread-safe state management.

### Multi-Provider Architecture

Pluggable AI providers for redundancy and optimization.

### Real-Time Streaming

WebSocket/streaming APIs for low-latency voice interaction.

### Curriculum-Driven Learning

UMCF format for structured learning content.

## Related Documentation

- [[Voice-Pipeline]] - Voice processing details
- [[Development]] - Development guide
- [[Getting-Started]] - Setup guide

---

Back to [[Home]]
