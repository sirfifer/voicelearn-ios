# Voice Pipeline Architecture

Deep dive into UnaMentis voice processing.

## Overview

The voice pipeline enables real-time, bidirectional voice conversations with AI tutors. Target latency is <500ms end-to-end.

```
┌─────────────────────────────────────────────────────────────────┐
│                        Voice Pipeline                           │
│                                                                 │
│  Mic → AudioEngine → VAD → STT → SessionManager → LLM → TTS → Speaker
│                                     │
│                              FOV Context Manager
│                                     │
│                              Patch Panel Router
└─────────────────────────────────────────────────────────────────┘
```

## Components

### 1. Audio Engine

Captures and plays audio with low latency.

**Responsibilities:**
- Microphone input capture (16kHz, mono)
- Speaker output playback
- Buffer management
- Thermal-aware quality adjustment

**Key Classes:**
- `AudioEngine` (actor)
- `AudioBuffer`
- `AudioSessionManager`

### 2. Voice Activity Detection (VAD)

Detects when the user starts/stops speaking.

**Providers:**
| Provider | Type | Notes |
|----------|------|-------|
| Silero VAD | On-device (CoreML) | Primary, Neural Engine optimized |
| RMS-based | On-device | Fallback, energy-based |

**Key Metrics:**
- Speech onset detection: <50ms
- Speech offset detection: <200ms

### 3. Speech-to-Text (STT)

Converts audio to text.

**Providers:**
| Provider | Model | Type | Latency |
|----------|-------|------|---------|
| Apple Speech | Native | On-device | ~150ms |
| GLM-ASR | GLM-ASR-Nano | On-device | ~200ms |
| Deepgram | Nova-3 | Cloud | ~300ms |
| Groq | Whisper-large-v3-turbo | Cloud | ~200ms |

**Features:**
- Streaming transcription
- Automatic provider failover
- Quality-based routing

### 4. Session Manager

Orchestrates the conversation flow.

**State Machine:**
```
Idle → UserSpeaking → Processing → AIThinking → AISpeaking → (loop)
          ↓                                          ↓
       Interrupted ←─────────────────────────────────┘
```

**Responsibilities:**
- Turn-taking management
- Interruption handling (barge-in)
- Context accumulation
- Session persistence

### 5. FOV Context Manager

Builds optimal LLM context using foveated approach.

**Hierarchical Buffers:**
| Buffer | Purpose | Token Budget |
|--------|---------|--------------|
| Immediate | Current turn, recent history | 4,000 |
| Working | Topic content, glossary | 4,000 |
| Episodic | Session history, learner signals | 2,500 |
| Semantic | Curriculum position, prerequisites | 1,500 |

**Adaptive Scaling:**
- Cloud models: 12K total budget
- Mid-range: 8K budget
- On-device: 4K budget
- Tiny: 2K budget

### 6. Patch Panel Router

Routes LLM tasks to appropriate endpoints.

**Routing Priority:**
1. Global override (debugging)
2. Manual task-type override
3. Auto-routing rules (conditions)
4. Default route for task type
5. Fallback chain

**Task Types:**
- Tutoring responses
- Content generation
- Classification
- Navigation
- Simple responses

**Conditions:**
- Thermal state
- Network quality
- Cost budget
- Memory pressure

### 7. Large Language Model (LLM)

Generates tutoring responses.

**Providers:**
| Provider | Model | Type | Use Case |
|----------|-------|------|----------|
| On-device | Ministral-3B | Local | Offline, privacy |
| Ollama | Mistral 7B | Self-hosted | Cost control |
| Anthropic | Claude 3.5 | Cloud | Primary cloud |
| OpenAI | GPT-4o | Cloud | Alternative |

**Features:**
- Streaming responses
- Token counting
- Cost tracking
- Confidence monitoring

### 8. Text-to-Speech (TTS)

Converts text to natural speech.

**Providers:**
| Provider | Model | Type | TTFB |
|----------|-------|------|------|
| Apple TTS | AVSpeech | On-device | ~50ms |
| Chatterbox | Turbo | Self-hosted | ~150ms |
| ElevenLabs | Turbo v2.5 | Cloud | ~200ms |
| Deepgram | Aura-2 | Cloud | ~180ms |

**Features:**
- Streaming playback
- Global caching (cross-user)
- Emotion control (Chatterbox)
- Voice cloning

## Latency Budget

| Stage | Target | Budget |
|-------|--------|--------|
| VAD Detection | <50ms | 50ms |
| STT Processing | <200ms | 200ms |
| Context Building | <20ms | 20ms |
| LLM Routing | <10ms | 10ms |
| LLM TTFT | <150ms | 150ms |
| TTS TTFB | <70ms | 70ms |
| **Total E2E** | **<500ms** | **500ms** |

## Interruption Handling (Barge-In)

When user interrupts AI:

1. VAD detects speech onset
2. TTS playback stops immediately
3. Current LLM response cancelled
4. STT begins on new input
5. Context includes interrupted state

**Key Metrics:**
- Interrupt-to-silence: <100ms
- Interrupt-to-listening: <150ms

## Graceful Degradation

The pipeline degrades gracefully:

```
Full Quality → Reduced Quality → Offline Mode → Error State
```

**Fallback Chain:**
1. Cloud providers (best quality)
2. Self-hosted servers (cost control)
3. On-device inference (offline)
4. Text-only mode (last resort)

## TTS Caching

Global cross-user caching system:

```
User A requests "Welcome" (voice=nova) → Cache MISS → Generate → Store
User B requests "Welcome" (voice=nova) → Cache HIT → 0ms latency
```

**Cache Key:** `hash(text + voice_id + provider + speed)`

**Priority Levels:**
| Priority | Concurrent | Use Case |
|----------|-----------|----------|
| LIVE | 7 | Active user |
| PREFETCH | 3 | Next segments |
| SCHEDULED | 3 | Pre-generation |

## Monitoring

### Key Metrics

- E2E latency (P50, P99)
- STT/LLM/TTS latencies
- Interruption rate
- Error rate per provider
- Cost per session

### Telemetry

```swift
telemetry.recordLatency(.e2e, value: 450)
telemetry.recordEvent(.bargeIn, metadata: ["segment": 5])
telemetry.recordCost(.tts, amount: 0.002)
```

## Related Pages

- [[Architecture]] - System overview
- [[iOS-Development]] - iOS implementation
- [[Testing]] - Latency testing
- [[API-Reference]] - TTS caching API

---

Back to [[Home]]
