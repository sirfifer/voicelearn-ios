# Voice Provider Integration Guide

This document describes how to integrate with various STT, LLM, and TTS providers.

---

## Overview

The web client supports multiple providers for each service type:

| Service | Providers |
|---------|-----------|
| STT | OpenAI Realtime, Deepgram, AssemblyAI, Groq |
| LLM | OpenAI, Anthropic, Self-hosted (Ollama) |
| TTS | OpenAI Realtime, ElevenLabs, Deepgram Aura, Self-hosted |

---

## OpenAI Realtime API (Primary)

The OpenAI Realtime API provides the lowest latency through WebRTC.

### Architecture

```
Browser ←──WebRTC──→ OpenAI Realtime API
           ↑
    Ephemeral Token
           ↑
Your Server ←──REST──→ OpenAI API
```

### Ephemeral Token Generation

**Server-side** (never expose API key to client):

```typescript
// POST /api/realtime/token
export async function POST() {
  const response = await fetch('https://api.openai.com/v1/realtime/sessions', {
    method: 'POST',
    headers: {
      'Authorization': `Bearer ${process.env.OPENAI_API_KEY}`,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({
      model: 'gpt-4o-realtime-preview',
      voice: 'coral',
    }),
  });

  const data = await response.json();
  return Response.json({ token: data.client_secret.value });
}
```

### WebRTC Connection

```typescript
async function connectToRealtime() {
  // 1. Get ephemeral token
  const { token } = await fetch('/api/realtime/token', { method: 'POST' }).then(r => r.json());

  // 2. Create peer connection
  const pc = new RTCPeerConnection();

  // 3. Get microphone
  const stream = await navigator.mediaDevices.getUserMedia({
    audio: {
      sampleRate: 24000,
      channelCount: 1,
      echoCancellation: true,
      noiseSuppression: true,
      autoGainControl: true,
    },
  });

  // 4. Add audio track
  stream.getAudioTracks().forEach(track => pc.addTrack(track, stream));

  // 5. Handle remote audio (AI response)
  pc.ontrack = (event) => {
    const audio = new Audio();
    audio.srcObject = event.streams[0];
    audio.play();
  };

  // 6. Create data channel for events
  const dc = pc.createDataChannel('oai-events');
  dc.onmessage = handleRealtimeEvent;

  // 7. Create and send offer
  const offer = await pc.createOffer();
  await pc.setLocalDescription(offer);

  const response = await fetch('https://api.openai.com/v1/realtime', {
    method: 'POST',
    headers: {
      'Authorization': `Bearer ${token}`,
      'Content-Type': 'application/sdp',
    },
    body: offer.sdp,
  });

  // 8. Set remote description
  const answerSdp = await response.text();
  await pc.setRemoteDescription({ type: 'answer', sdp: answerSdp });

  return { pc, dc };
}
```

### Data Channel Events

**Client → Server:**
```json
{
  "type": "response.create",
  "response": {
    "modalities": ["text", "audio"],
    "instructions": "You are a helpful tutor..."
  }
}
```

**Server → Client:**
```json
{
  "type": "response.audio.delta",
  "delta": "base64-audio-chunk"
}
```

```json
{
  "type": "response.audio_transcript.delta",
  "delta": "Hello, "
}
```

### Voice Options

| Voice | Description |
|-------|-------------|
| `alloy` | Balanced |
| `ash` | Warm |
| `ballad` | Soft |
| `coral` | Clear (recommended) |
| `echo` | Neutral |
| `sage` | Wise |
| `shimmer` | Bright |
| `verse` | Expressive |
| `marin` | Natural (new) |
| `cedar` | Calm (new) |

### Audio Format

- Sample rate: 24,000 Hz
- Bit depth: 16-bit
- Channels: Mono
- Codec: Opus (WebRTC native)

---

## Deepgram STT

Deepgram Nova-3 provides high-quality streaming transcription.

### WebSocket Connection

```typescript
class DeepgramSTT {
  private ws: WebSocket | null = null;

  async connect(apiKey: string) {
    const url = new URL('wss://api.deepgram.com/v1/listen');
    url.searchParams.set('model', 'nova-3');
    url.searchParams.set('language', 'en-US');
    url.searchParams.set('punctuate', 'true');
    url.searchParams.set('interim_results', 'true');
    url.searchParams.set('endpointing', '500');

    this.ws = new WebSocket(url.toString(), ['token', apiKey]);

    this.ws.onmessage = (event) => {
      const data = JSON.parse(event.data);
      if (data.channel?.alternatives?.[0]) {
        const result = {
          text: data.channel.alternatives[0].transcript,
          isFinal: data.is_final,
          confidence: data.channel.alternatives[0].confidence,
          words: data.channel.alternatives[0].words,
        };
        this.onResult?.(result);
      }
    };
  }

  sendAudio(buffer: ArrayBuffer) {
    if (this.ws?.readyState === WebSocket.OPEN) {
      this.ws.send(buffer);
    }
  }

  disconnect() {
    this.ws?.close();
    this.ws = null;
  }
}
```

### Audio Requirements

- Sample rate: 16,000 Hz
- Bit depth: 16-bit
- Channels: Mono
- Format: Raw PCM (Linear16)

### Response Format

```json
{
  "type": "Results",
  "channel_index": [0, 1],
  "duration": 1.5,
  "start": 0.0,
  "is_final": true,
  "channel": {
    "alternatives": [
      {
        "transcript": "Hello world",
        "confidence": 0.98,
        "words": [
          {
            "word": "Hello",
            "start": 0.1,
            "end": 0.4,
            "confidence": 0.99
          }
        ]
      }
    ]
  }
}
```

### Pricing

- Nova-3: $0.0043/minute
- Nova-2: $0.0036/minute

---

## AssemblyAI STT

AssemblyAI Universal provides streaming transcription.

### WebSocket Connection

```typescript
class AssemblyAISTT {
  private ws: WebSocket | null = null;

  async connect(apiKey: string) {
    // Get temporary token
    const tokenResponse = await fetch('https://api.assemblyai.com/v2/realtime/token', {
      method: 'POST',
      headers: {
        'Authorization': apiKey,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({ expires_in: 3600 }),
    });
    const { token } = await tokenResponse.json();

    // Connect WebSocket
    this.ws = new WebSocket(`wss://api.assemblyai.com/v2/realtime/ws?sample_rate=16000&token=${token}`);

    this.ws.onmessage = (event) => {
      const data = JSON.parse(event.data);
      if (data.message_type === 'PartialTranscript') {
        this.onResult?.({ text: data.text, isFinal: false });
      } else if (data.message_type === 'FinalTranscript') {
        this.onResult?.({ text: data.text, isFinal: true, confidence: data.confidence });
      }
    };
  }

  sendAudio(buffer: ArrayBuffer) {
    if (this.ws?.readyState === WebSocket.OPEN) {
      // Send base64-encoded audio
      const base64 = btoa(String.fromCharCode(...new Uint8Array(buffer)));
      this.ws.send(JSON.stringify({ audio_data: base64 }));
    }
  }
}
```

### Audio Requirements

- Sample rate: 16,000 Hz
- Bit depth: 16-bit
- Encoding: Base64

### Pricing

- Streaming: $0.0050/minute

---

## Groq Whisper STT

Groq provides fast Whisper transcription (batch, not streaming).

```typescript
async function transcribeWithGroq(audioBlob: Blob, apiKey: string): Promise<string> {
  const formData = new FormData();
  formData.append('file', audioBlob, 'audio.wav');
  formData.append('model', 'whisper-large-v3');
  formData.append('response_format', 'json');

  const response = await fetch('https://api.groq.com/openai/v1/audio/transcriptions', {
    method: 'POST',
    headers: {
      'Authorization': `Bearer ${apiKey}`,
    },
    body: formData,
  });

  const data = await response.json();
  return data.text;
}
```

### Pricing

- whisper-large-v3: $0.111/hour

---

## Anthropic Claude LLM

Anthropic Claude for text generation with streaming.

### Streaming Request

```typescript
async function* streamClaude(
  messages: Message[],
  apiKey: string
): AsyncIterable<string> {
  const response = await fetch('https://api.anthropic.com/v1/messages', {
    method: 'POST',
    headers: {
      'x-api-key': apiKey,
      'content-type': 'application/json',
      'anthropic-version': '2023-06-01',
    },
    body: JSON.stringify({
      model: 'claude-3-5-sonnet-20241022',
      max_tokens: 1024,
      stream: true,
      messages: messages.map(m => ({
        role: m.role === 'user' ? 'user' : 'assistant',
        content: m.content,
      })),
    }),
  });

  const reader = response.body!.getReader();
  const decoder = new TextDecoder();

  while (true) {
    const { done, value } = await reader.read();
    if (done) break;

    const chunk = decoder.decode(value);
    const lines = chunk.split('\n');

    for (const line of lines) {
      if (line.startsWith('data: ')) {
        const data = JSON.parse(line.slice(6));
        if (data.type === 'content_block_delta') {
          yield data.delta.text;
        }
      }
    }
  }
}
```

### Models

| Model | Input | Output |
|-------|-------|--------|
| claude-3-5-sonnet-20241022 | $3/1M | $15/1M |
| claude-3-5-haiku-20241022 | $1/1M | $5/1M |
| claude-3-opus-20240229 | $15/1M | $75/1M |

---

## OpenAI LLM

OpenAI GPT-4o for text generation.

### Streaming Request

```typescript
async function* streamOpenAI(
  messages: Message[],
  apiKey: string
): AsyncIterable<string> {
  const response = await fetch('https://api.openai.com/v1/chat/completions', {
    method: 'POST',
    headers: {
      'Authorization': `Bearer ${apiKey}`,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({
      model: 'gpt-4o',
      max_tokens: 1024,
      stream: true,
      messages,
    }),
  });

  const reader = response.body!.getReader();
  const decoder = new TextDecoder();

  while (true) {
    const { done, value } = await reader.read();
    if (done) break;

    const chunk = decoder.decode(value);
    const lines = chunk.split('\n');

    for (const line of lines) {
      if (line.startsWith('data: ') && line !== 'data: [DONE]') {
        const data = JSON.parse(line.slice(6));
        if (data.choices[0]?.delta?.content) {
          yield data.choices[0].delta.content;
        }
      }
    }
  }
}
```

### Models

| Model | Input | Output |
|-------|-------|--------|
| gpt-4o | $2.50/1M | $10/1M |
| gpt-4o-mini | $0.15/1M | $0.60/1M |

---

## ElevenLabs TTS

ElevenLabs for high-quality voice synthesis.

### Streaming Request

```typescript
async function* synthesizeElevenLabs(
  text: string,
  voiceId: string,
  apiKey: string
): AsyncIterable<ArrayBuffer> {
  const response = await fetch(
    `https://api.elevenlabs.io/v1/text-to-speech/${voiceId}/stream`,
    {
      method: 'POST',
      headers: {
        'xi-api-key': apiKey,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        text,
        model_id: 'eleven_turbo_v2_5',
        voice_settings: {
          stability: 0.5,
          similarity_boost: 0.75,
        },
      }),
    }
  );

  const reader = response.body!.getReader();

  while (true) {
    const { done, value } = await reader.read();
    if (done) break;
    yield value.buffer;
  }
}
```

### Voice IDs

| Voice | ID |
|-------|-----|
| Rachel | 21m00Tcm4TlvDq8ikWAM |
| Domi | AZnzlk1XvdvUeBnXmlld |
| Bella | EXAVITQu4vr4xnSDxMaL |
| Antoni | ErXwobaYiN019PkySvjV |

### Audio Format

- Sample rate: 22,050 Hz or 44,100 Hz
- Format: MP3 or PCM

### Pricing

| Model | Cost |
|-------|------|
| eleven_turbo_v2_5 | $0.15/1K chars |
| eleven_multilingual_v2 | $0.18/1K chars |

---

## Deepgram Aura TTS

Deepgram Aura for fast voice synthesis.

### Streaming Request

```typescript
async function* synthesizeDeepgram(
  text: string,
  apiKey: string
): AsyncIterable<ArrayBuffer> {
  const response = await fetch(
    'https://api.deepgram.com/v1/speak?model=aura-asteria-en',
    {
      method: 'POST',
      headers: {
        'Authorization': `Token ${apiKey}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({ text }),
    }
  );

  const reader = response.body!.getReader();

  while (true) {
    const { done, value } = await reader.read();
    if (done) break;
    yield value.buffer;
  }
}
```

### Voice Models

| Voice | Description |
|-------|-------------|
| aura-asteria-en | Female, US English |
| aura-luna-en | Female, US English |
| aura-stella-en | Female, US English |
| aura-athena-en | Female, UK English |
| aura-hera-en | Female, US English |
| aura-orion-en | Male, US English |
| aura-arcas-en | Male, US English |
| aura-perseus-en | Male, US English |
| aura-angus-en | Male, Irish English |
| aura-orpheus-en | Male, US English |
| aura-helios-en | Male, UK English |
| aura-zeus-en | Male, US English |

### Audio Format

- Sample rate: 24,000 Hz
- Format: Linear16 PCM or MP3

### Pricing

- Aura: $0.015/1K chars

---

## Self-Hosted Providers

### Ollama (LLM)

```typescript
async function* streamOllama(
  messages: Message[],
  model: string = 'llama3.2'
): AsyncIterable<string> {
  const response = await fetch('http://localhost:11434/api/chat', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({
      model,
      messages,
      stream: true,
    }),
  });

  const reader = response.body!.getReader();
  const decoder = new TextDecoder();

  while (true) {
    const { done, value } = await reader.read();
    if (done) break;

    const chunk = decoder.decode(value);
    const lines = chunk.split('\n').filter(Boolean);

    for (const line of lines) {
      const data = JSON.parse(line);
      if (data.message?.content) {
        yield data.message.content;
      }
    }
  }
}
```

### Piper TTS (Self-hosted)

```typescript
async function synthesizePiper(text: string): Promise<ArrayBuffer> {
  const response = await fetch('http://localhost:11402/synthesize', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ text }),
  });

  return response.arrayBuffer();
}
```

Audio format: 22,050 Hz WAV

### VibeVoice TTS (Self-hosted)

```typescript
async function synthesizeVibeVoice(text: string): Promise<ArrayBuffer> {
  const response = await fetch('http://localhost:8880/tts', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ text, voice: 'default' }),
  });

  return response.arrayBuffer();
}
```

Audio format: 24,000 Hz WAV

---

## Provider Manager

Manage multiple providers with runtime switching:

```typescript
class ProviderManager {
  private sttProvider: STTProvider;
  private llmProvider: LLMProvider;
  private ttsProvider: TTSProvider;

  private providers = {
    stt: {
      'openai-realtime': OpenAIRealtimeSTT,
      'deepgram': DeepgramSTT,
      'assemblyai': AssemblyAISTT,
    },
    llm: {
      'openai': OpenAILLM,
      'anthropic': AnthropicLLM,
      'ollama': OllamaLLM,
    },
    tts: {
      'openai-realtime': OpenAIRealtimeTTS,
      'elevenlabs': ElevenLabsTTS,
      'deepgram': DeepgramTTS,
    },
  };

  configure(config: ProviderConfig) {
    this.sttProvider = new this.providers.stt[config.stt.provider](config.stt);
    this.llmProvider = new this.providers.llm[config.llm.provider](config.llm);
    this.ttsProvider = new this.providers.tts[config.tts.provider](config.tts);
  }

  async switchProvider(type: 'stt' | 'llm' | 'tts', provider: string) {
    // Disconnect old provider
    // Initialize new provider
  }
}
```

---

## Audio Processing

### Web Audio API Setup

```typescript
async function setupAudioCapture(): Promise<{
  stream: MediaStream;
  context: AudioContext;
  processor: AudioWorkletNode;
}> {
  const stream = await navigator.mediaDevices.getUserMedia({
    audio: {
      sampleRate: 16000,
      channelCount: 1,
      echoCancellation: true,
      noiseSuppression: true,
      autoGainControl: true,
    },
  });

  const context = new AudioContext({ sampleRate: 16000 });
  await context.audioWorklet.addModule('/audio-processor.js');

  const source = context.createMediaStreamSource(stream);
  const processor = new AudioWorkletNode(context, 'audio-processor');

  source.connect(processor);

  return { stream, context, processor };
}
```

### AudioWorklet Processor

```javascript
// public/audio-processor.js
class AudioProcessor extends AudioWorkletProcessor {
  process(inputs, outputs, parameters) {
    const input = inputs[0];
    if (input.length > 0) {
      const samples = input[0];
      // Convert Float32 to Int16
      const int16 = new Int16Array(samples.length);
      for (let i = 0; i < samples.length; i++) {
        int16[i] = Math.max(-32768, Math.min(32767, samples[i] * 32768));
      }
      this.port.postMessage(int16.buffer);
    }
    return true;
  }
}

registerProcessor('audio-processor', AudioProcessor);
```

---

## Cost Optimization

### Provider Cost Comparison

| Service | Provider | Cost |
|---------|----------|------|
| STT | OpenAI Realtime | Included in response |
| STT | Deepgram Nova-3 | $0.0043/min |
| STT | Groq Whisper | $0.111/hour |
| LLM | GPT-4o | $2.50/$10 per 1M tokens |
| LLM | GPT-4o-mini | $0.15/$0.60 per 1M tokens |
| LLM | Claude Sonnet | $3/$15 per 1M tokens |
| TTS | OpenAI Realtime | Included in response |
| TTS | ElevenLabs Turbo | $0.15/1K chars |
| TTS | Deepgram Aura | $0.015/1K chars |

### Cost Tracking

```typescript
interface CostMetrics {
  sttMinutes: number;
  llmInputTokens: number;
  llmOutputTokens: number;
  ttsCharacters: number;
}

function calculateCost(metrics: CostMetrics, providers: ProviderConfig): number {
  let total = 0;

  // STT cost
  if (providers.stt === 'deepgram') {
    total += metrics.sttMinutes * 0.0043;
  }

  // LLM cost
  if (providers.llm === 'openai') {
    total += (metrics.llmInputTokens / 1_000_000) * 2.50;
    total += (metrics.llmOutputTokens / 1_000_000) * 10.00;
  }

  // TTS cost
  if (providers.tts === 'elevenlabs') {
    total += (metrics.ttsCharacters / 1000) * 0.15;
  }

  return total;
}
```

---

*End of Provider Guide*
