# UnaMentis Web Client - Technical Design Document

**Version**: 1.0.0
**Date**: January 2026
**Status**: Draft

---

## Table of Contents

1. [Executive Summary](#1-executive-summary)
2. [Goals and Requirements](#2-goals-and-requirements)
3. [Architecture Overview](#3-architecture-overview)
4. [Voice Pipeline](#4-voice-pipeline)
5. [Provider Abstraction Layer](#5-provider-abstraction-layer)
6. [Session State Machine](#6-session-state-machine)
7. [Desktop Layout](#7-desktop-layout)
8. [Mobile Layout](#8-mobile-layout)
9. [Component Architecture](#9-component-architecture)
10. [Real-time Streaming](#10-real-time-streaming)
11. [Curriculum Integration](#11-curriculum-integration)
12. [Visual Asset Rendering](#12-visual-asset-rendering)
13. [Authentication](#13-authentication)
14. [Error Handling](#14-error-handling)
15. [Performance Optimization](#15-performance-optimization)
16. [Telemetry and Cost Tracking](#16-telemetry-and-cost-tracking)
17. [Security](#17-security)
18. [Browser Compatibility](#18-browser-compatibility)

---

## 1. Executive Summary

### 1.1 Purpose

The UnaMentis Web Client provides voice AI tutoring through web browsers, matching the iOS app's capabilities while leveraging the flexibility of web technologies. The client enables 60-90+ minute learning sessions with sub-500ms voice latency.

### 1.2 Key Differentiators from iOS

| Aspect | iOS App | Web Client |
|--------|---------|------------|
| On-device AI | Available (MLX, Apple Speech) | Not available |
| Audio Processing | Native AVAudioEngine | Web Audio API |
| Primary Voice | Multiple options | OpenAI Realtime (WebRTC) |
| Layout | Adaptive (iPhone/iPad) | Responsive (any screen) |
| Distribution | App Store | URL (instant access) |

### 1.3 Technology Stack

```
Frontend
├── Next.js 15+ (App Router)
├── React 19
├── TypeScript 5 (strict)
└── Tailwind CSS 4

Voice
├── OpenAI Realtime API (WebRTC)
├── Web Audio API
└── WebSocket (fallback)

Rendering
├── KaTeX (LaTeX formulas)
├── Leaflet/Mapbox (maps)
├── Mermaid.js (diagrams)
└── Chart.js (charts)
```

---

## 2. Goals and Requirements

### 2.1 Functional Requirements

| ID | Requirement | Priority |
|----|-------------|----------|
| F1 | Voice-to-voice conversation with AI tutor | Must |
| F2 | Real-time transcript display | Must |
| F3 | Visual asset display (formulas, maps, diagrams) | Must |
| F4 | Curriculum browsing and selection | Must |
| F5 | Session history and analytics | Should |
| F6 | User authentication | Must |
| F7 | Progress tracking | Should |
| F8 | Todo/task management | Could |

### 2.2 Performance Requirements

| Metric | Target | Measurement |
|--------|--------|-------------|
| Voice Latency (E2E) | <500ms median | User speech end to TTS start |
| LLM Time-to-First-Token | <300ms | Request to first token |
| TTS Time-to-First-Byte | <200ms | Text sent to audio received |
| Session Stability | 90+ minutes | No crashes or memory leaks |
| Memory Growth | <100MB/90min | Browser memory delta |

### 2.3 Provider Flexibility

The architecture must support runtime provider switching:

- **STT**: OpenAI Realtime, Deepgram, AssemblyAI, Groq, self-hosted
- **LLM**: OpenAI GPT-4o, Anthropic Claude, self-hosted Ollama
- **TTS**: OpenAI Realtime, ElevenLabs, Deepgram Aura-2, self-hosted Piper

---

## 3. Architecture Overview

### 3.1 High-Level Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                        Browser Client                            │
├─────────────────────────────────────────────────────────────────┤
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────────────────┐  │
│  │   React UI  │  │   Session   │  │    Provider Manager     │  │
│  │  Components │  │   Manager   │  │  ┌─────┬─────┬─────┐   │  │
│  │             │◄─┤             │◄─┤  │ STT │ LLM │ TTS │   │  │
│  └─────────────┘  └─────────────┘  │  └──┬──┴──┬──┴──┬──┘   │  │
│                                     │     │     │     │      │  │
│  ┌─────────────┐  ┌─────────────┐  │     ▼     ▼     ▼      │  │
│  │ Web Audio   │  │   WebRTC    │  │  Provider Implementations│  │
│  │    API      │  │  Manager    │  │                         │  │
│  └──────┬──────┘  └──────┬──────┘  └─────────────────────────┘  │
│         │                │                                       │
└─────────┼────────────────┼───────────────────────────────────────┘
          │                │
          ▼                ▼
    ┌──────────┐    ┌──────────────┐    ┌───────────────────────┐
    │ Mic/Spkr │    │ OpenAI       │    │ Management API        │
    │          │    │ Realtime API │    │ (localhost:8766)      │
    └──────────┘    └──────────────┘    └───────────────────────┘
```

### 3.2 Data Flow

```
User speaks
    │
    ▼
┌──────────────────┐
│ Web Audio API    │ Capture microphone audio
│ (getUserMedia)   │ 24kHz, 16-bit PCM
└────────┬─────────┘
         │
         ▼
┌──────────────────┐
│ Audio Processor  │ VAD, level detection
│ (AudioWorklet)   │
└────────┬─────────┘
         │
    ┌────┴────┐
    ▼         ▼
┌────────┐ ┌────────┐
│WebRTC  │ │WebSocket│ (fallback)
│OpenAI  │ │to Server│
└───┬────┘ └────┬───┘
    │           │
    ▼           ▼
┌──────────────────┐
│ STT Provider     │ Transcribe speech
└────────┬─────────┘
         │
         ▼
┌──────────────────┐
│ LLM Provider     │ Generate response
│ (streaming)      │
└────────┬─────────┘
         │
         ▼
┌──────────────────┐
│ TTS Provider     │ Synthesize audio
│ (streaming)      │
└────────┬─────────┘
         │
         ▼
┌──────────────────┐
│ Audio Playback   │ Play through speakers
│ (AudioContext)   │
└──────────────────┘
```

---

## 4. Voice Pipeline

### 4.1 OpenAI Realtime (WebRTC) - Primary Path

The OpenAI Realtime API provides the lowest latency path through WebRTC:

```typescript
// Ephemeral token generation (server-side)
async function getEphemeralToken(): Promise<string> {
  const response = await fetch('/api/realtime/token', {
    method: 'POST',
    headers: { 'Authorization': `Bearer ${accessToken}` }
  });
  const { token } = await response.json();
  return token;
}

// WebRTC connection setup
async function connectRealtime() {
  const token = await getEphemeralToken();

  const pc = new RTCPeerConnection();

  // Add audio track from microphone
  const stream = await navigator.mediaDevices.getUserMedia({
    audio: {
      sampleRate: 24000,
      channelCount: 1,
      echoCancellation: true,
      noiseSuppression: true,
      autoGainControl: true
    }
  });
  const audioTrack = stream.getAudioTracks()[0];
  pc.addTrack(audioTrack);

  // Handle remote audio (AI response)
  pc.ontrack = (event) => {
    const audioElement = new Audio();
    audioElement.srcObject = event.streams[0];
    audioElement.play();
  };

  // Data channel for events
  const dc = pc.createDataChannel('oai-events');
  dc.onmessage = handleRealtimeEvent;

  // Connect to OpenAI
  const offer = await pc.createOffer();
  await pc.setLocalDescription(offer);

  const response = await fetch('https://api.openai.com/v1/realtime', {
    method: 'POST',
    headers: {
      'Authorization': `Bearer ${token}`,
      'Content-Type': 'application/sdp'
    },
    body: offer.sdp
  });

  const answer = await response.text();
  await pc.setRemoteDescription({ type: 'answer', sdp: answer });
}
```

### 4.2 WebRTC Benefits

- **Low Latency**: Peer-to-peer, no server hop for audio
- **Echo Cancellation**: Built-in browser AEC
- **Noise Suppression**: Hardware-accelerated
- **Auto Gain Control**: Consistent audio levels
- **Opus Codec**: Efficient compression, FEC for packet loss
- **Interruption Handling**: Server-side audio buffer management

### 4.3 Fallback: WebSocket to Server

When WebRTC is unavailable or for non-OpenAI providers:

```typescript
// WebSocket audio streaming
class AudioStreamer {
  private ws: WebSocket;
  private audioContext: AudioContext;
  private processor: AudioWorkletNode;

  async connect(provider: 'deepgram' | 'assemblyai' | 'self-hosted') {
    this.ws = new WebSocket(`wss://server/api/stream/${provider}`);

    this.audioContext = new AudioContext({ sampleRate: 16000 });
    await this.audioContext.audioWorklet.addModule('/audio-processor.js');

    const stream = await navigator.mediaDevices.getUserMedia({ audio: true });
    const source = this.audioContext.createMediaStreamSource(stream);

    this.processor = new AudioWorkletNode(this.audioContext, 'audio-processor');
    this.processor.port.onmessage = (e) => {
      if (this.ws.readyState === WebSocket.OPEN) {
        this.ws.send(e.data.buffer);
      }
    };

    source.connect(this.processor);
    this.processor.connect(this.audioContext.destination);
  }
}
```

### 4.4 Audio Format Requirements

| Provider | Sample Rate | Bit Depth | Codec | Notes |
|----------|-------------|-----------|-------|-------|
| OpenAI Realtime | 24000 Hz | 16-bit | Opus | WebRTC native |
| Deepgram | 16000 Hz | 16-bit | PCM | Raw audio |
| AssemblyAI | 16000 Hz | 16-bit | PCM | Raw audio |
| ElevenLabs | 24000 Hz | 16-bit | MP3/PCM | Streaming |
| Self-hosted | 16000/22050 Hz | 16-bit | PCM/WAV | Depends on model |

---

## 5. Provider Abstraction Layer

### 5.1 TypeScript Interfaces

```typescript
// ===== STT Provider =====

interface STTResult {
  text: string;
  isFinal: boolean;
  confidence?: number;
  words?: WordTiming[];
  language?: string;
}

interface WordTiming {
  word: string;
  start: number;
  end: number;
  confidence: number;
}

interface STTProvider {
  readonly name: string;
  readonly costPerHour: number;
  readonly isStreaming: boolean;

  connect(config: STTConfig): Promise<void>;
  startStreaming(): AsyncIterable<STTResult>;
  sendAudio(buffer: ArrayBuffer): void;
  stopStreaming(): Promise<STTResult | null>;
  disconnect(): void;
}

interface STTConfig {
  sampleRate: number;
  channels: number;
  language?: string;
  model?: string;
  interimResults?: boolean;
  endpointing?: {
    silenceThreshold: number;  // ms
    utteranceEndTimeout: number;  // ms
  };
}

// ===== LLM Provider =====

interface LLMToken {
  content: string;
  finishReason?: 'stop' | 'length' | 'tool_calls';
  toolCalls?: ToolCall[];
}

interface Message {
  role: 'system' | 'user' | 'assistant' | 'tool';
  content: string;
  toolCallId?: string;
  name?: string;
}

interface LLMProvider {
  readonly name: string;
  readonly costPerInputToken: number;
  readonly costPerOutputToken: number;

  streamCompletion(
    messages: Message[],
    config: LLMConfig
  ): AsyncIterable<LLMToken>;

  cancelCompletion(): void;
}

interface LLMConfig {
  model: string;
  maxTokens: number;
  temperature: number;
  topP?: number;
  stopSequences?: string[];
  tools?: ToolDefinition[];
}

// ===== TTS Provider =====

interface AudioChunk {
  audio: ArrayBuffer;
  format: 'pcm' | 'mp3' | 'opus';
  sampleRate: number;
  isFinal: boolean;
}

interface TTSProvider {
  readonly name: string;
  readonly costPerCharacter: number;

  configure(config: TTSConfig): void;
  synthesize(text: string): AsyncIterable<AudioChunk>;
  flush(): Promise<void>;
  cancel(): void;
}

interface TTSConfig {
  voice: string;
  speed?: number;  // 0.5 - 2.0
  pitch?: number;  // -20 to 20 semitones
  stability?: number;  // 0 - 1 (ElevenLabs)
  similarityBoost?: number;  // 0 - 1 (ElevenLabs)
}
```

### 5.2 Provider Registry

```typescript
// Provider registry with factory functions
const providerRegistry = {
  stt: {
    'openai-realtime': () => new OpenAIRealtimeSTT(),
    'deepgram': () => new DeepgramSTT(),
    'assemblyai': () => new AssemblyAISTT(),
    'groq': () => new GroqWhisperSTT(),
    'self-hosted': (config) => new SelfHostedSTT(config),
  },
  llm: {
    'openai': () => new OpenAILLM(),
    'anthropic': () => new AnthropicLLM(),
    'self-hosted': (config) => new OllamaLLM(config),
  },
  tts: {
    'openai-realtime': () => new OpenAIRealtimeTTS(),
    'elevenlabs': () => new ElevenLabsTTS(),
    'deepgram': () => new DeepgramAuraTTS(),
    'self-hosted': (config) => new SelfHostedTTS(config),
  }
};

// Provider manager
class ProviderManager {
  private sttProvider: STTProvider;
  private llmProvider: LLMProvider;
  private ttsProvider: TTSProvider;

  async configure(config: ProviderConfig) {
    this.sttProvider = providerRegistry.stt[config.stt.provider](config.stt);
    this.llmProvider = providerRegistry.llm[config.llm.provider](config.llm);
    this.ttsProvider = providerRegistry.tts[config.tts.provider](config.tts);
  }

  // Allow runtime switching
  async switchSTT(provider: string, config?: any) {
    await this.sttProvider?.disconnect();
    this.sttProvider = providerRegistry.stt[provider](config);
  }
}
```

### 5.3 Provider Configurations

```typescript
// Default provider configurations
const defaultConfigs = {
  stt: {
    'openai-realtime': {
      model: 'gpt-4o-realtime-preview',
      language: 'en',
    },
    'deepgram': {
      model: 'nova-3',
      language: 'en-US',
      punctuate: true,
      interimResults: true,
    },
    'assemblyai': {
      model: 'universal',
      language: 'en',
    },
  },
  llm: {
    'openai': {
      model: 'gpt-4o',
      maxTokens: 1024,
      temperature: 0.7,
    },
    'anthropic': {
      model: 'claude-3-5-sonnet-20241022',
      maxTokens: 1024,
      temperature: 0.7,
    },
  },
  tts: {
    'openai-realtime': {
      voice: 'coral',
    },
    'elevenlabs': {
      voice: 'EXAVITQu4vr4xnSDxMaL',  // Bella
      model: 'eleven_turbo_v2_5',
      stability: 0.5,
      similarityBoost: 0.75,
    },
    'deepgram': {
      voice: 'aura-asteria-en',
    },
  },
};
```

---

## 6. Session State Machine

### 6.1 State Definitions

Match iOS session states exactly for consistency:

```typescript
type SessionState =
  | 'idle'                    // Not active
  | 'userSpeaking'            // Listening to user
  | 'processingUserUtterance' // STT result received
  | 'aiThinking'              // LLM generating response
  | 'aiSpeaking'              // TTS playback in progress
  | 'interrupted'             // Tentative barge-in
  | 'paused'                  // Frozen state (can resume)
  | 'error';                  // Error occurred

interface SessionContext {
  state: SessionState;
  conversationHistory: Message[];
  currentTopic?: Topic;
  visualAssets: VisualAsset[];
  currentVisualIndex: number;
  metrics: SessionMetrics;
  error?: Error;
}
```

### 6.2 State Transitions

```
                    ┌──────────────┐
                    │     idle     │
                    └──────┬───────┘
                           │ startSession()
                           ▼
                    ┌──────────────┐
          ┌────────│ userSpeaking │◄────────────┐
          │        └──────┬───────┘             │
          │               │ STT final result    │
          │               ▼                     │
          │    ┌─────────────────────┐          │
          │    │processingUserUtterance│         │
          │    └──────────┬──────────┘          │
          │               │                     │
          │               ▼                     │
          │        ┌──────────────┐             │
          │        │  aiThinking  │             │
          │        └──────┬───────┘             │
          │               │ first LLM token     │
          │               ▼                     │
          │        ┌──────────────┐             │
          │        │  aiSpeaking  │─────────────┤
          │        └──────┬───────┘             │
          │               │ user interrupts     │
          │               ▼                     │
          │        ┌──────────────┐             │
          │        │ interrupted  │─────────────┘
          │        └──────────────┘  confirmed
          │               │ 600ms timeout (false positive)
          │               └────────► resume aiSpeaking
          │
pause()──►│
          │
          ▼
    ┌──────────────┐
    │    paused    │
    └──────┬───────┘
           │ resume()
           └────────► previous state
```

### 6.3 State Machine Implementation

```typescript
import { createMachine, assign } from 'xstate';

const sessionMachine = createMachine({
  id: 'session',
  initial: 'idle',
  context: {
    conversationHistory: [],
    currentUtterance: '',
    aiResponse: '',
    visualAssets: [],
    metrics: createInitialMetrics(),
  },
  states: {
    idle: {
      on: {
        START_SESSION: {
          target: 'userSpeaking',
          actions: ['initializeSession', 'startAudioCapture'],
        },
      },
    },
    userSpeaking: {
      on: {
        STT_INTERIM: {
          actions: 'updateInterimTranscript',
        },
        STT_FINAL: {
          target: 'processingUserUtterance',
          actions: 'setFinalTranscript',
        },
        PAUSE: 'paused',
      },
    },
    processingUserUtterance: {
      entry: ['addUserMessage', 'startLLMRequest'],
      on: {
        LLM_FIRST_TOKEN: 'aiThinking',
        ERROR: 'error',
      },
    },
    aiThinking: {
      on: {
        LLM_TOKEN: {
          actions: 'appendAIResponse',
        },
        LLM_SENTENCE_COMPLETE: {
          actions: 'queueTTSSentence',
        },
        TTS_PLAYBACK_START: 'aiSpeaking',
        LLM_COMPLETE: {
          actions: 'finalizeLLMResponse',
        },
        PAUSE: 'paused',
      },
    },
    aiSpeaking: {
      on: {
        USER_SPEECH_DETECTED: 'interrupted',
        TTS_COMPLETE: 'userSpeaking',
        PAUSE: 'paused',
      },
    },
    interrupted: {
      after: {
        600: [
          { target: 'userSpeaking', cond: 'userStillSpeaking' },
          { target: 'aiSpeaking', actions: 'resumeTTS' },
        ],
      },
      on: {
        USER_SPEECH_CONFIRMED: {
          target: 'userSpeaking',
          actions: ['cancelTTS', 'truncateAIResponse'],
        },
      },
    },
    paused: {
      on: {
        RESUME: {
          target: 'userSpeaking', // or restore previous state
          actions: 'resumeSession',
        },
        STOP: {
          target: 'idle',
          actions: 'cleanupSession',
        },
      },
    },
    error: {
      on: {
        RETRY: 'idle',
        DISMISS: 'idle',
      },
    },
  },
});
```

### 6.4 Interruption Handling

The iOS app uses a "tentative pause" approach for barge-in detection:

```typescript
// Interruption detection and handling
class InterruptionHandler {
  private interruptionTimer: NodeJS.Timeout | null = null;
  private readonly CONFIRMATION_WINDOW = 600; // ms

  onUserSpeechDetected(sessionManager: SessionManager) {
    // Immediately pause TTS playback
    sessionManager.pauseTTS();
    sessionManager.setState('interrupted');

    // Wait for confirmation
    this.interruptionTimer = setTimeout(() => {
      if (sessionManager.isUserStillSpeaking()) {
        // Confirmed interruption
        sessionManager.cancelTTS();
        sessionManager.truncateAIResponse();
        sessionManager.setState('userSpeaking');
      } else {
        // False positive - resume playback
        sessionManager.resumeTTS();
        sessionManager.setState('aiSpeaking');
      }
    }, this.CONFIRMATION_WINDOW);
  }

  onUserSpeechEnded() {
    if (this.interruptionTimer) {
      clearTimeout(this.interruptionTimer);
      this.interruptionTimer = null;
    }
  }
}
```

---

## 7. Desktop Layout

### 7.1 Layout Structure

```
┌─────────────────────────────────────────────────────────────────────────┐
│  HEADER                                                          72px   │
│  ┌─────────────────────────────────────────────────────────────────┐   │
│  │ Logo  │  Topic Title  │  Timer  │  Status  │  Controls  │ User │   │
│  └─────────────────────────────────────────────────────────────────┘   │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                         │
│  ┌────────────────────────────┐  ┌─────────────────────────────────┐   │
│  │                            │  │                                 │   │
│  │     TRANSCRIPT PANEL       │  │       VISUAL PANEL              │   │
│  │        (60% width)         │  │        (40% width)              │   │
│  │                            │  │                                 │   │
│  │  ┌──────────────────────┐  │  │  ┌─────────────────────────┐   │   │
│  │  │ User: "What is..."   │  │  │  │                         │   │   │
│  │  └──────────────────────┘  │  │  │   Current Visual Asset  │   │   │
│  │                            │  │  │                         │   │   │
│  │  ┌──────────────────────┐  │  │  │   - Formula (KaTeX)     │   │   │
│  │  │ AI: "Let me explain" │  │  │  │   - Map (Leaflet)       │   │   │
│  │  │ ...                  │  │  │  │   - Diagram (Mermaid)   │   │   │
│  │  └──────────────────────┘  │  │  │   - Image               │   │   │
│  │                            │  │  │   - Chart               │   │   │
│  │  ┌──────────────────────┐  │  │  │                         │   │   │
│  │  │ [Waveform / Levels]  │  │  │  └─────────────────────────┘   │   │
│  │  └──────────────────────┘  │  │                                 │   │
│  │                            │  │  ┌─────────────────────────┐   │   │
│  └────────────────────────────┘  │  │  Asset Thumbnails       │   │   │
│                                  │  └─────────────────────────┘   │   │
│                                  └─────────────────────────────────┘   │
│                                                                         │
├─────────────────────────────────────────────────────────────────────────┤
│  TAB BAR                                                         64px   │
│  ┌─────────────────────────────────────────────────────────────────┐   │
│  │  Session  │  Curriculum  │  To-Do  │  History  │  Settings      │   │
│  └─────────────────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────────────────┘
```

### 7.2 Responsive Breakpoints

```typescript
const breakpoints = {
  sm: 640,    // Mobile
  md: 768,    // Tablet portrait
  lg: 1024,   // Tablet landscape / small desktop
  xl: 1280,   // Desktop
  '2xl': 1536 // Large desktop
};

// Layout behavior
// < 768px: Mobile layout (full-width transcript, bottom sheet visuals)
// >= 768px: Split layout (60/40 or configurable)
// >= 1280px: Enhanced split with larger visual panel
```

### 7.3 CSS Implementation (Tailwind)

```tsx
// Layout component
function SessionLayout({ children }: { children: React.ReactNode }) {
  return (
    <div className="flex flex-col h-screen bg-gray-50 dark:bg-gray-900">
      {/* Header */}
      <header className="h-18 border-b bg-white dark:bg-gray-800 flex items-center px-4">
        <SessionHeader />
      </header>

      {/* Main content */}
      <main className="flex-1 flex overflow-hidden">
        {/* Mobile: Stack, Desktop: Side-by-side */}
        <div className="flex-1 flex flex-col md:flex-row">
          {/* Transcript Panel */}
          <div className="flex-1 md:w-[60%] overflow-y-auto">
            <TranscriptPanel />
          </div>

          {/* Visual Panel - Hidden on mobile, shown as bottom sheet */}
          <div className="hidden md:block md:w-[40%] border-l overflow-y-auto">
            <VisualPanel />
          </div>
        </div>
      </main>

      {/* Mobile: Bottom sheet for visuals */}
      <div className="md:hidden">
        <VisualBottomSheet />
      </div>

      {/* Tab bar */}
      <nav className="h-16 border-t bg-white dark:bg-gray-800">
        <TabBar />
      </nav>
    </div>
  );
}
```

---

## 8. Mobile Layout

### 8.1 Layout Structure

```
┌─────────────────────────┐
│  HEADER (Compact)  56px │
│  ┌─────────────────────┐│
│  │ ← │ Title │ ⋮ │ 🎤  ││
│  └─────────────────────┘│
├─────────────────────────┤
│                         │
│   TRANSCRIPT PANEL      │
│   (Full width)          │
│                         │
│  ┌─────────────────────┐│
│  │ User: "What is..."  ││
│  └─────────────────────┘│
│                         │
│  ┌─────────────────────┐│
│  │ AI: "Let me explain"││
│  │ ...                 ││
│  └─────────────────────┘│
│                         │
│  ┌─────────────────────┐│
│  │ [Voice Indicator]   ││
│  └─────────────────────┘│
│                         │
├─────────────────────────┤
│  VISUAL OVERLAY         │
│  (Expandable)      120px│
│  ┌─────────────────────┐│
│  │ ═══ (drag handle)   ││
│  │ [Current Asset]     ││
│  └─────────────────────┘│
├─────────────────────────┤
│  TAB BAR           56px │
│  ┌─────────────────────┐│
│  │ 🎙️ │ 📚 │ ✓ │ 🕐 │ ⚙️ ││
│  └─────────────────────┘│
└─────────────────────────┘
```

### 8.2 Bottom Sheet States

```typescript
type BottomSheetState = 'collapsed' | 'peek' | 'expanded' | 'fullscreen';

// Collapsed: Hidden (0px visible)
// Peek: Small preview (120px visible)
// Expanded: Half screen (~50% visible)
// Fullscreen: Full screen minus header

const bottomSheetHeights = {
  collapsed: 0,
  peek: 120,
  expanded: '50vh',
  fullscreen: 'calc(100vh - 56px)',
};
```

### 8.3 Touch Interactions

```typescript
// Bottom sheet drag handling
function useBottomSheetGesture() {
  const [state, setState] = useState<BottomSheetState>('peek');
  const [dragY, setDragY] = useState(0);

  const handlers = {
    onTouchStart: (e: TouchEvent) => {
      // Record start position
    },
    onTouchMove: (e: TouchEvent) => {
      // Update drag position
      const delta = e.touches[0].clientY - startY;
      setDragY(delta);
    },
    onTouchEnd: () => {
      // Snap to nearest state based on velocity and position
      const velocity = calculateVelocity();
      const newState = determineTargetState(dragY, velocity);
      setState(newState);
      setDragY(0);
    },
  };

  return { state, dragY, handlers };
}
```

---

## 9. Component Architecture

### 9.1 Component Hierarchy

```
App
├── Providers
│   ├── AuthProvider
│   ├── SessionProvider
│   ├── ProviderManagerProvider
│   └── ThemeProvider
│
├── Layout
│   ├── Header
│   │   ├── Logo
│   │   ├── TopicTitle
│   │   ├── SessionTimer
│   │   ├── SessionStatus
│   │   ├── SessionControls
│   │   └── UserMenu
│   │
│   ├── MainContent
│   │   ├── TranscriptPanel
│   │   │   ├── ConversationHistory
│   │   │   │   ├── UserMessage
│   │   │   │   └── AIMessage
│   │   │   ├── CurrentUtterance
│   │   │   └── VoiceIndicator
│   │   │
│   │   └── VisualPanel (desktop) / VisualBottomSheet (mobile)
│   │       ├── VisualAssetViewer
│   │       │   ├── FormulaRenderer (KaTeX)
│   │       │   ├── MapViewer (Leaflet)
│   │       │   ├── DiagramViewer (Mermaid)
│   │       │   ├── ChartViewer (Chart.js)
│   │       │   └── ImageViewer
│   │       └── AssetThumbnails
│   │
│   └── TabBar
│       ├── SessionTab
│       ├── CurriculumTab
│       ├── TodoTab
│       ├── HistoryTab
│       └── SettingsTab
│
└── Pages
    ├── SessionPage
    ├── CurriculumPage
    │   ├── CurriculumList
    │   └── TopicList
    ├── TodoPage
    ├── HistoryPage
    └── SettingsPage
        ├── ProviderSettings
        ├── VoiceSettings
        └── AccountSettings
```

### 9.2 Key Component Implementations

```tsx
// TranscriptPanel.tsx
function TranscriptPanel() {
  const { conversationHistory, currentUtterance, state } = useSession();
  const scrollRef = useRef<HTMLDivElement>(null);

  // Auto-scroll to bottom on new messages
  useEffect(() => {
    scrollRef.current?.scrollTo({
      top: scrollRef.current.scrollHeight,
      behavior: 'smooth',
    });
  }, [conversationHistory, currentUtterance]);

  return (
    <div ref={scrollRef} className="flex-1 overflow-y-auto p-4 space-y-4">
      {conversationHistory.map((message, i) => (
        <Message key={i} message={message} />
      ))}

      {currentUtterance && (
        <CurrentUtterance text={currentUtterance} state={state} />
      )}

      <VoiceIndicator state={state} />
    </div>
  );
}

// VisualAssetViewer.tsx
function VisualAssetViewer({ asset }: { asset: VisualAsset }) {
  switch (asset.type) {
    case 'formula':
      return <FormulaRenderer latex={asset.latex} displayMode={asset.displayMode} />;
    case 'map':
      return <MapViewer config={asset.mapConfig} />;
    case 'diagram':
      return <DiagramViewer source={asset.source} format={asset.format} />;
    case 'chart':
      return <ChartViewer data={asset.chartData} type={asset.chartType} />;
    case 'image':
      return <ImageViewer src={asset.url} alt={asset.alt} />;
    default:
      return <div>Unsupported asset type</div>;
  }
}
```

---

## 10. Real-time Streaming

### 10.1 Streaming Patterns

```typescript
// Async iterator pattern for all streaming APIs
async function* streamLLMResponse(messages: Message[]): AsyncIterable<LLMToken> {
  const response = await fetch('/api/llm/stream', {
    method: 'POST',
    body: JSON.stringify({ messages }),
  });

  const reader = response.body!.getReader();
  const decoder = new TextDecoder();

  while (true) {
    const { done, value } = await reader.read();
    if (done) break;

    const chunk = decoder.decode(value);
    const lines = chunk.split('\n').filter(Boolean);

    for (const line of lines) {
      if (line.startsWith('data: ')) {
        const data = JSON.parse(line.slice(6));
        yield data as LLMToken;
      }
    }
  }
}
```

### 10.2 Sentence Extraction for TTS

```typescript
// Extract complete sentences for TTS as they arrive
class SentenceExtractor {
  private buffer = '';
  private readonly sentenceEnders = /[.!?]\s*$/;

  addText(text: string): string[] {
    this.buffer += text;
    const sentences: string[] = [];

    // Look for sentence boundaries
    let match;
    while ((match = this.buffer.match(/[^.!?]*[.!?]\s*/))) {
      sentences.push(match[0].trim());
      this.buffer = this.buffer.slice(match[0].length);
    }

    return sentences;
  }

  flush(): string | null {
    const remaining = this.buffer.trim();
    this.buffer = '';
    return remaining || null;
  }
}
```

### 10.3 TTS Prefetching

```typescript
// Queue and prefetch TTS for smooth playback
class TTSQueue {
  private queue: Array<{ text: string; audio?: ArrayBuffer }> = [];
  private prefetchDepth = 2;
  private currentIndex = 0;

  async addSentence(text: string) {
    const entry = { text };
    this.queue.push(entry);

    // Prefetch if within lookahead window
    if (this.queue.length - this.currentIndex <= this.prefetchDepth) {
      this.prefetch(this.queue.length - 1);
    }
  }

  private async prefetch(index: number) {
    const entry = this.queue[index];
    if (entry.audio) return;  // Already fetched

    const chunks: ArrayBuffer[] = [];
    for await (const chunk of this.ttsProvider.synthesize(entry.text)) {
      chunks.push(chunk.audio);
    }
    entry.audio = concatenateAudio(chunks);
  }

  async getNextAudio(): Promise<ArrayBuffer | null> {
    const entry = this.queue[this.currentIndex];
    if (!entry) return null;

    // Wait for prefetch if needed
    if (!entry.audio) {
      await this.prefetch(this.currentIndex);
    }

    this.currentIndex++;

    // Start prefetching next
    if (this.currentIndex + this.prefetchDepth < this.queue.length) {
      this.prefetch(this.currentIndex + this.prefetchDepth);
    }

    return entry.audio!;
  }
}
```

---

## 11. Curriculum Integration

### 11.1 UMCF Loading

```typescript
// Load curriculum from Management API
async function loadCurriculum(curriculumId: string): Promise<Curriculum> {
  const response = await apiClient.get<CurriculumResponse>(
    `/api/curricula/${curriculumId}/full-with-assets`
  );

  return {
    ...response.curriculum,
    topics: response.topics.map(topic => ({
      ...topic,
      visualAssets: topic.assets.map(parseVisualAsset),
      transcript: parseTranscript(topic.transcript),
    })),
  };
}

// Parse visual asset from UMCF
function parseVisualAsset(asset: UMCFMediaAsset): VisualAsset {
  const base = {
    id: asset.id,
    type: asset.type,
    title: asset.title,
    alt: asset.alt,
    caption: asset.caption,
    segmentTiming: asset.segmentTiming,
  };

  switch (asset.type) {
    case 'formula':
      return {
        ...base,
        latex: asset.latex,
        displayMode: asset.displayMode || 'block',
        semanticMeaning: asset.semanticMeaning,
      };
    case 'map':
      return {
        ...base,
        mapConfig: {
          center: asset.geography.center,
          zoom: asset.geography.zoom,
          style: asset.mapStyle,
          markers: asset.markers,
          routes: asset.routes,
          regions: asset.regions,
        },
      };
    case 'diagram':
      return {
        ...base,
        source: asset.sourceCode?.code,
        format: asset.sourceCode?.format || 'mermaid',
        imageUrl: asset.url,
      };
    default:
      return { ...base, url: asset.url };
  }
}
```

### 11.2 Segment Synchronization

```typescript
// Synchronize visual assets with transcript playback
class VisualAssetSynchronizer {
  private assets: VisualAsset[];
  private currentSegment = 0;

  constructor(assets: VisualAsset[]) {
    this.assets = assets.sort((a, b) =>
      (a.segmentTiming?.startSegment || 0) - (b.segmentTiming?.startSegment || 0)
    );
  }

  onSegmentChange(segmentIndex: number): VisualAsset | null {
    this.currentSegment = segmentIndex;

    // Find asset that should be displayed for this segment
    const asset = this.assets.find(a => {
      const start = a.segmentTiming?.startSegment || 0;
      const end = a.segmentTiming?.endSegment || start;
      return segmentIndex >= start && segmentIndex <= end;
    });

    return asset || null;
  }
}
```

---

## 12. Visual Asset Rendering

### 12.1 Formula Rendering (KaTeX)

```tsx
import katex from 'katex';
import 'katex/dist/katex.min.css';

interface FormulaRendererProps {
  latex: string;
  displayMode?: boolean;
  semanticMeaning?: SemanticMeaning;
}

function FormulaRenderer({ latex, displayMode = true, semanticMeaning }: FormulaRendererProps) {
  const containerRef = useRef<HTMLDivElement>(null);

  useEffect(() => {
    if (containerRef.current) {
      katex.render(latex, containerRef.current, {
        displayMode,
        throwOnError: false,
        errorColor: '#cc0000',
        trust: true,
        macros: {
          '\\R': '\\mathbb{R}',
          '\\N': '\\mathbb{N}',
          '\\Z': '\\mathbb{Z}',
        },
      });
    }
  }, [latex, displayMode]);

  return (
    <div className="formula-container">
      <div ref={containerRef} className="text-center py-4" />
      {semanticMeaning && (
        <div className="text-sm text-gray-600 mt-2">
          <strong>{semanticMeaning.commonName}</strong>: {semanticMeaning.purpose}
          {semanticMeaning.variables && (
            <ul className="mt-1">
              {semanticMeaning.variables.map((v, i) => (
                <li key={i}><em>{v.symbol}</em>: {v.meaning}</li>
              ))}
            </ul>
          )}
        </div>
      )}
    </div>
  );
}
```

### 12.2 Map Rendering (Leaflet)

```tsx
import { MapContainer, TileLayer, Marker, Polyline, Polygon, Popup } from 'react-leaflet';
import 'leaflet/dist/leaflet.css';

interface MapViewerProps {
  config: MapConfig;
}

function MapViewer({ config }: MapViewerProps) {
  const { center, zoom, style, markers, routes, regions } = config;

  const tileUrl = getTileUrl(style);

  return (
    <MapContainer
      center={[center.latitude, center.longitude]}
      zoom={zoom}
      className="h-full w-full rounded-lg"
    >
      <TileLayer url={tileUrl} attribution="&copy; OpenStreetMap" />

      {markers?.map((marker, i) => (
        <Marker
          key={i}
          position={[marker.latitude, marker.longitude]}
          icon={createIcon(marker.color)}
        >
          <Popup>
            <strong>{marker.label}</strong>
            {marker.description && <p>{marker.description}</p>}
          </Popup>
        </Marker>
      ))}

      {routes?.map((route, i) => (
        <Polyline
          key={i}
          positions={route.points.map(p => [p.latitude, p.longitude])}
          color={route.color}
          dashArray={route.style === 'dashed' ? '10, 10' : undefined}
        />
      ))}

      {regions?.map((region, i) => (
        <Polygon
          key={i}
          positions={region.points.map(p => [p.latitude, p.longitude])}
          fillColor={region.fillColor}
          fillOpacity={region.opacity}
        />
      ))}
    </MapContainer>
  );
}

function getTileUrl(style: string): string {
  switch (style) {
    case 'satellite':
      return 'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}';
    case 'terrain':
      return 'https://stamen-tiles.a.ssl.fastly.net/terrain/{z}/{x}/{y}.png';
    case 'historical':
      return 'https://tiles.stadiamaps.com/tiles/stamen_watercolor/{z}/{x}/{y}.jpg';
    default:
      return 'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png';
  }
}
```

### 12.3 Diagram Rendering (Mermaid)

```tsx
import mermaid from 'mermaid';

interface DiagramViewerProps {
  source: string;
  format: 'mermaid' | 'graphviz' | 'plantuml';
  fallbackUrl?: string;
}

function DiagramViewer({ source, format, fallbackUrl }: DiagramViewerProps) {
  const containerRef = useRef<HTMLDivElement>(null);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    if (format !== 'mermaid') {
      // For non-mermaid, use fallback image or server-side rendering
      return;
    }

    mermaid.initialize({
      startOnLoad: false,
      theme: 'neutral',
      securityLevel: 'strict',
    });

    const render = async () => {
      try {
        const id = `mermaid-${Date.now()}`;
        const { svg } = await mermaid.render(id, source);
        if (containerRef.current) {
          containerRef.current.innerHTML = svg;
        }
      } catch (e) {
        setError(e.message);
      }
    };

    render();
  }, [source, format]);

  if (format !== 'mermaid' || error) {
    return fallbackUrl ? (
      <img src={fallbackUrl} alt="Diagram" className="max-w-full" />
    ) : (
      <div className="text-red-500">Failed to render diagram</div>
    );
  }

  return <div ref={containerRef} className="flex justify-center" />;
}
```

---

## 13. Authentication

### 13.1 Token Management

```typescript
// Secure token storage
class TokenManager {
  private accessToken: string | null = null;
  private refreshToken: string | null = null;
  private expiresAt: number = 0;

  constructor() {
    // Load from secure storage on init
    this.loadFromStorage();
  }

  private loadFromStorage() {
    // Refresh token in httpOnly cookie (most secure)
    // Access token in memory only
    this.refreshToken = document.cookie
      .split('; ')
      .find(row => row.startsWith('refresh_token='))
      ?.split('=')[1] || null;
  }

  setTokens(access: string, refresh: string, expiresIn: number) {
    this.accessToken = access;
    this.refreshToken = refresh;
    this.expiresAt = Date.now() + expiresIn * 1000;

    // Store refresh in httpOnly cookie via server
    // Access token stays in memory
  }

  async getValidAccessToken(): Promise<string> {
    // Refresh if expiring soon (1 minute buffer)
    if (Date.now() > this.expiresAt - 60000) {
      await this.refreshAccessToken();
    }
    return this.accessToken!;
  }

  private async refreshAccessToken() {
    const response = await fetch('/api/auth/refresh', {
      method: 'POST',
      credentials: 'include', // Send cookies
    });

    if (!response.ok) {
      this.clear();
      throw new AuthError('Session expired');
    }

    const { tokens } = await response.json();
    this.setTokens(tokens.access_token, tokens.refresh_token, tokens.expires_in);
  }

  clear() {
    this.accessToken = null;
    this.refreshToken = null;
    this.expiresAt = 0;
  }
}
```

### 13.2 Device Registration

```typescript
interface DeviceInfo {
  fingerprint: string;
  name: string;
  type: 'web';
  model: string;  // Browser name
  osVersion: string;  // Browser version
  appVersion: string;
}

async function getDeviceInfo(): Promise<DeviceInfo> {
  const ua = navigator.userAgent;
  const browserInfo = parseBrowserInfo(ua);

  return {
    fingerprint: await generateDeviceFingerprint(),
    name: `${browserInfo.name} on ${browserInfo.os}`,
    type: 'web',
    model: browserInfo.name,
    osVersion: browserInfo.version,
    appVersion: APP_VERSION,
  };
}

async function generateDeviceFingerprint(): Promise<string> {
  // Use subtle crypto for fingerprint generation
  const components = [
    navigator.userAgent,
    navigator.language,
    screen.width,
    screen.height,
    new Date().getTimezoneOffset(),
    navigator.hardwareConcurrency,
  ];

  const data = components.join('|');
  const encoder = new TextEncoder();
  const hash = await crypto.subtle.digest('SHA-256', encoder.encode(data));
  return Array.from(new Uint8Array(hash))
    .map(b => b.toString(16).padStart(2, '0'))
    .join('');
}
```

---

## 14. Error Handling

### 14.1 Error Types

```typescript
// Application-specific errors
class AppError extends Error {
  constructor(
    message: string,
    public code: string,
    public isRecoverable: boolean = true,
    public retryable: boolean = false
  ) {
    super(message);
    this.name = 'AppError';
  }
}

class AuthError extends AppError {
  constructor(message: string) {
    super(message, 'AUTH_ERROR', true, false);
  }
}

class NetworkError extends AppError {
  constructor(message: string = 'Network connection lost') {
    super(message, 'NETWORK_ERROR', true, true);
  }
}

class ProviderError extends AppError {
  constructor(
    message: string,
    public provider: string,
    public originalError?: Error
  ) {
    super(message, 'PROVIDER_ERROR', true, true);
  }
}

class AudioError extends AppError {
  constructor(message: string) {
    super(message, 'AUDIO_ERROR', true, false);
  }
}
```

### 14.2 Error Recovery

```typescript
// Retry with exponential backoff
async function withRetry<T>(
  fn: () => Promise<T>,
  options: {
    maxRetries?: number;
    baseDelay?: number;
    maxDelay?: number;
    shouldRetry?: (error: Error) => boolean;
  } = {}
): Promise<T> {
  const {
    maxRetries = 3,
    baseDelay = 1000,
    maxDelay = 30000,
    shouldRetry = (e) => e instanceof NetworkError || (e as AppError).retryable,
  } = options;

  let lastError: Error;

  for (let attempt = 0; attempt <= maxRetries; attempt++) {
    try {
      return await fn();
    } catch (error) {
      lastError = error as Error;

      if (attempt === maxRetries || !shouldRetry(lastError)) {
        throw lastError;
      }

      const delay = Math.min(baseDelay * Math.pow(2, attempt), maxDelay);
      await sleep(delay);
    }
  }

  throw lastError!;
}
```

### 14.3 Error Boundaries

```tsx
// React error boundary for graceful degradation
class SessionErrorBoundary extends React.Component<
  { children: React.ReactNode },
  { hasError: boolean; error: Error | null }
> {
  state = { hasError: false, error: null };

  static getDerivedStateFromError(error: Error) {
    return { hasError: true, error };
  }

  componentDidCatch(error: Error, info: React.ErrorInfo) {
    // Log to telemetry
    telemetry.captureException(error, { componentStack: info.componentStack });
  }

  handleRetry = () => {
    this.setState({ hasError: false, error: null });
  };

  render() {
    if (this.state.hasError) {
      return (
        <ErrorFallback
          error={this.state.error!}
          onRetry={this.handleRetry}
        />
      );
    }
    return this.props.children;
  }
}
```

---

## 15. Performance Optimization

### 15.1 Latency Optimization Strategies

| Strategy | Target | Implementation |
|----------|--------|----------------|
| WebRTC for primary voice | <50ms audio transport | OpenAI Realtime API |
| Sentence-level TTS | <200ms first audio | Extract sentences as they complete |
| TTS prefetching | Zero gap between sentences | Queue next 2 sentences |
| LLM streaming | Progressive display | Token-by-token rendering |
| Audio worklet | Consistent audio processing | Dedicated audio thread |
| Connection keepalive | No reconnection delay | Persistent WebSocket/WebRTC |

### 15.2 Memory Management

```typescript
// Audio buffer management to prevent memory leaks
class AudioBufferPool {
  private pool: AudioBuffer[] = [];
  private maxSize = 50;

  acquire(context: AudioContext, length: number, sampleRate: number): AudioBuffer {
    // Reuse existing buffer if compatible
    const existing = this.pool.find(
      b => b.length >= length && b.sampleRate === sampleRate
    );

    if (existing) {
      this.pool = this.pool.filter(b => b !== existing);
      return existing;
    }

    return context.createBuffer(1, length, sampleRate);
  }

  release(buffer: AudioBuffer) {
    if (this.pool.length < this.maxSize) {
      this.pool.push(buffer);
    }
    // Otherwise let it be garbage collected
  }

  clear() {
    this.pool = [];
  }
}

// Cleanup on session end
function cleanupSession() {
  audioBufferPool.clear();
  transcriptHistory.truncate(100);  // Keep last 100 messages
  visualAssetCache.clear();
}
```

### 15.3 Code Splitting

```typescript
// Lazy load heavy components
const MapViewer = dynamic(() => import('./MapViewer'), {
  loading: () => <Skeleton className="h-64" />,
  ssr: false,  // Maps don't work in SSR
});

const DiagramViewer = dynamic(() => import('./DiagramViewer'), {
  loading: () => <Skeleton className="h-64" />,
});

const ChartViewer = dynamic(() => import('./ChartViewer'), {
  loading: () => <Skeleton className="h-64" />,
});

// Route-based code splitting handled by Next.js App Router
```

---

## 16. Telemetry and Cost Tracking

### 16.1 Metrics Collection

```typescript
interface SessionMetrics {
  sessionId: string;
  startTime: Date;
  duration: number;  // seconds

  // Latency metrics
  sttLatencies: number[];  // ms
  llmTTFTs: number[];  // ms (time to first token)
  ttsTTFBs: number[];  // ms (time to first byte)
  e2eLatencies: number[];  // ms (full turn)

  // Cost metrics
  sttCost: number;  // dollars
  llmInputTokens: number;
  llmOutputTokens: number;
  llmCost: number;  // dollars
  ttsCost: number;  // dollars
  totalCost: number;  // dollars

  // Usage metrics
  turnCount: number;
  userSpeechDuration: number;  // seconds
  aiSpeechDuration: number;  // seconds
  interruptionCount: number;
  errorCount: number;
}

// Collect metrics during session
class MetricsCollector {
  private metrics: SessionMetrics;
  private turnStartTime: number = 0;

  startTurn() {
    this.turnStartTime = performance.now();
  }

  recordSTTLatency(latency: number) {
    this.metrics.sttLatencies.push(latency);
  }

  recordLLMFirstToken(elapsed: number) {
    this.metrics.llmTTFTs.push(elapsed);
  }

  recordTTSFirstByte(elapsed: number) {
    this.metrics.ttsTTFBs.push(elapsed);
  }

  recordTurnComplete() {
    const e2e = performance.now() - this.turnStartTime;
    this.metrics.e2eLatencies.push(e2e);
    this.metrics.turnCount++;
  }

  recordCost(type: 'stt' | 'llm' | 'tts', amount: number, tokens?: { input?: number; output?: number }) {
    switch (type) {
      case 'stt':
        this.metrics.sttCost += amount;
        break;
      case 'llm':
        this.metrics.llmCost += amount;
        if (tokens) {
          this.metrics.llmInputTokens += tokens.input || 0;
          this.metrics.llmOutputTokens += tokens.output || 0;
        }
        break;
      case 'tts':
        this.metrics.ttsCost += amount;
        break;
    }
    this.metrics.totalCost = this.metrics.sttCost + this.metrics.llmCost + this.metrics.ttsCost;
  }

  getSnapshot(): SessionMetrics {
    return { ...this.metrics, duration: (Date.now() - this.metrics.startTime.getTime()) / 1000 };
  }
}
```

### 16.2 Metrics Upload

```typescript
// Upload metrics to server periodically
class MetricsUploadService {
  private uploadInterval = 5 * 60 * 1000;  // 5 minutes
  private timer: NodeJS.Timeout | null = null;

  start(collector: MetricsCollector) {
    this.timer = setInterval(() => {
      this.upload(collector.getSnapshot());
    }, this.uploadInterval);
  }

  stop() {
    if (this.timer) {
      clearInterval(this.timer);
      this.timer = null;
    }
  }

  private async upload(metrics: SessionMetrics) {
    try {
      await apiClient.post('/api/metrics', {
        client_id: deviceId,
        client_name: deviceName,
        timestamp: new Date().toISOString(),
        metrics,
      });
    } catch (error) {
      console.error('Failed to upload metrics:', error);
      // Queue for retry
    }
  }
}
```

---

## 17. Security

### 17.1 Security Measures

| Threat | Mitigation |
|--------|------------|
| XSS | React's built-in escaping, CSP headers |
| CSRF | SameSite cookies, CSRF tokens |
| Token theft | httpOnly cookies for refresh, memory for access |
| API key exposure | Server-side only, ephemeral tokens |
| Audio interception | HTTPS/WSS only, WebRTC encryption |
| Injection | Input validation, parameterized queries |

### 17.2 Content Security Policy

```typescript
// next.config.js
const securityHeaders = [
  {
    key: 'Content-Security-Policy',
    value: [
      "default-src 'self'",
      "script-src 'self' 'unsafe-eval'",  // For Mermaid
      "style-src 'self' 'unsafe-inline'",  // For KaTeX
      "img-src 'self' data: https:",
      "connect-src 'self' https://api.openai.com wss://api.openai.com",
      "media-src 'self' blob:",
      "worker-src 'self' blob:",
    ].join('; '),
  },
  {
    key: 'X-Frame-Options',
    value: 'DENY',
  },
  {
    key: 'X-Content-Type-Options',
    value: 'nosniff',
  },
];
```

### 17.3 Input Validation

```typescript
// Validate all user inputs
import { z } from 'zod';

const loginSchema = z.object({
  email: z.string().email(),
  password: z.string().min(8),
});

const messageSchema = z.object({
  content: z.string().max(10000),
});

// Use in API routes
export async function POST(request: Request) {
  const body = await request.json();
  const result = loginSchema.safeParse(body);

  if (!result.success) {
    return Response.json({ error: 'Invalid input' }, { status: 400 });
  }

  // Proceed with validated data
}
```

---

## 18. Browser Compatibility

### 18.1 Support Matrix

| Browser | Version | WebRTC | Web Audio | Notes |
|---------|---------|--------|-----------|-------|
| Chrome | 90+ | Full | Full | Recommended |
| Safari | 15+ | Full | Full | iOS included |
| Firefox | 100+ | Partial | Full | Echo cancellation issues |
| Edge | 90+ | Full | Full | Chromium-based |

### 18.2 Feature Detection

```typescript
// Check browser capabilities
async function checkBrowserCapabilities(): Promise<BrowserCapabilities> {
  const capabilities: BrowserCapabilities = {
    webrtc: false,
    webAudio: false,
    mediaDevices: false,
    audioWorklet: false,
  };

  // WebRTC
  capabilities.webrtc = typeof RTCPeerConnection !== 'undefined';

  // Web Audio
  capabilities.webAudio = typeof AudioContext !== 'undefined' ||
    typeof (window as any).webkitAudioContext !== 'undefined';

  // Media Devices
  capabilities.mediaDevices = typeof navigator.mediaDevices?.getUserMedia === 'function';

  // Audio Worklet
  if (capabilities.webAudio) {
    const ctx = new AudioContext();
    capabilities.audioWorklet = typeof ctx.audioWorklet?.addModule === 'function';
    ctx.close();
  }

  return capabilities;
}

// Show warning if unsupported
function BrowserCheck({ children }: { children: React.ReactNode }) {
  const [compatible, setCompatible] = useState<boolean | null>(null);

  useEffect(() => {
    checkBrowserCapabilities().then(caps => {
      setCompatible(caps.webrtc && caps.webAudio && caps.mediaDevices);
    });
  }, []);

  if (compatible === null) return <LoadingSpinner />;
  if (!compatible) return <BrowserWarning />;
  return children;
}
```

---

## Appendix A: Environment Variables

```bash
# Server connection
NEXT_PUBLIC_API_URL=http://localhost:8766
NEXT_PUBLIC_WS_URL=ws://localhost:8766

# OpenAI (server-side only)
OPENAI_API_KEY=sk-...

# Anthropic (server-side only)
ANTHROPIC_API_KEY=sk-ant-...

# Deepgram (server-side only)
DEEPGRAM_API_KEY=...

# ElevenLabs (server-side only)
ELEVENLABS_API_KEY=...

# Self-hosted endpoints
SELF_HOSTED_LLM_URL=http://localhost:11434
SELF_HOSTED_TTS_URL=http://localhost:8880
SELF_HOSTED_STT_URL=http://localhost:8765

# Feature flags
NEXT_PUBLIC_ENABLE_WEBRTC=true
NEXT_PUBLIC_ENABLE_SELF_HOSTED=true
```

---

## Appendix B: Dependencies

```json
{
  "dependencies": {
    "next": "^15.0.0",
    "react": "^19.0.0",
    "react-dom": "^19.0.0",
    "typescript": "^5.0.0",

    "tailwindcss": "^4.0.0",
    "clsx": "^2.0.0",
    "tailwind-merge": "^2.0.0",

    "katex": "^0.16.0",
    "leaflet": "^1.9.0",
    "react-leaflet": "^4.2.0",
    "mermaid": "^10.6.0",
    "chart.js": "^4.4.0",
    "react-chartjs-2": "^5.2.0",

    "xstate": "^5.0.0",
    "zod": "^3.22.0",
    "lucide-react": "^0.300.0"
  },
  "devDependencies": {
    "@types/node": "^20.0.0",
    "@types/react": "^18.0.0",
    "@types/leaflet": "^1.9.0",
    "eslint": "^8.0.0",
    "eslint-config-next": "^15.0.0",
    "prettier": "^3.0.0"
  }
}
```

---

*Document End*
