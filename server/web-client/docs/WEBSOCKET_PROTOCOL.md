# WebSocket and Real-time Protocol Guide

This document describes the real-time communication protocols used by the UnaMentis Web Client.

---

## Overview

The web client uses multiple real-time protocols:

| Protocol | Use Case |
|----------|----------|
| WebRTC | OpenAI Realtime voice (lowest latency) |
| WebSocket | Server logs/metrics, fallback STT |
| Server-Sent Events | LLM streaming |

---

## WebRTC (OpenAI Realtime)

### Connection Flow

```
1. Client requests ephemeral token from your server
2. Your server calls OpenAI /v1/realtime/sessions
3. OpenAI returns client_secret (ephemeral token)
4. Client creates RTCPeerConnection
5. Client adds audio track (microphone)
6. Client creates data channel for events
7. Client creates SDP offer
8. Client sends offer to OpenAI /v1/realtime
9. OpenAI returns SDP answer
10. WebRTC connection established
```

### Data Channel Messages

**Client → OpenAI:**

Session Update:
```json
{
  "type": "session.update",
  "session": {
    "modalities": ["text", "audio"],
    "instructions": "You are a helpful tutor...",
    "voice": "coral",
    "turn_detection": {
      "type": "server_vad",
      "threshold": 0.5,
      "prefix_padding_ms": 300,
      "silence_duration_ms": 500
    }
  }
}
```

Create Response:
```json
{
  "type": "response.create",
  "response": {
    "modalities": ["text", "audio"],
    "instructions": "Answer the student's question."
  }
}
```

Cancel Response:
```json
{
  "type": "response.cancel"
}
```

**OpenAI → Client:**

Session Created:
```json
{
  "type": "session.created",
  "session": {
    "id": "session-id",
    "model": "gpt-4o-realtime-preview"
  }
}
```

Input Audio Transcription:
```json
{
  "type": "conversation.item.input_audio_transcription.completed",
  "transcript": "Hello, can you help me?"
}
```

Response Audio Delta:
```json
{
  "type": "response.audio.delta",
  "delta": "base64-encoded-audio-chunk"
}
```

Response Text Delta:
```json
{
  "type": "response.audio_transcript.delta",
  "delta": "Sure, I'd be happy to "
}
```

Response Done:
```json
{
  "type": "response.done",
  "response": {
    "id": "response-id",
    "status": "completed"
  }
}
```

Speech Started:
```json
{
  "type": "input_audio_buffer.speech_started"
}
```

Speech Stopped:
```json
{
  "type": "input_audio_buffer.speech_stopped"
}
```

### Implementation

```typescript
class OpenAIRealtimeConnection {
  private pc: RTCPeerConnection;
  private dc: RTCDataChannel;
  private audioElement: HTMLAudioElement;

  async connect(ephemeralToken: string) {
    this.pc = new RTCPeerConnection();

    // Get microphone
    const stream = await navigator.mediaDevices.getUserMedia({
      audio: {
        sampleRate: 24000,
        channelCount: 1,
        echoCancellation: true,
        noiseSuppression: true,
        autoGainControl: true,
      },
    });

    // Add audio track
    stream.getAudioTracks().forEach(track => {
      this.pc.addTrack(track, stream);
    });

    // Handle remote audio
    this.pc.ontrack = (event) => {
      this.audioElement = new Audio();
      this.audioElement.srcObject = event.streams[0];
      this.audioElement.play();
    };

    // Create data channel
    this.dc = this.pc.createDataChannel('oai-events');
    this.dc.onmessage = this.handleMessage.bind(this);
    this.dc.onopen = () => this.sendSessionConfig();

    // Create offer
    const offer = await this.pc.createOffer();
    await this.pc.setLocalDescription(offer);

    // Send to OpenAI
    const response = await fetch('https://api.openai.com/v1/realtime', {
      method: 'POST',
      headers: {
        'Authorization': `Bearer ${ephemeralToken}`,
        'Content-Type': 'application/sdp',
      },
      body: offer.sdp,
    });

    const answerSdp = await response.text();
    await this.pc.setRemoteDescription({ type: 'answer', sdp: answerSdp });
  }

  private sendSessionConfig() {
    this.send({
      type: 'session.update',
      session: {
        modalities: ['text', 'audio'],
        instructions: 'You are a helpful tutor.',
        voice: 'coral',
        turn_detection: {
          type: 'server_vad',
          threshold: 0.5,
          silence_duration_ms: 500,
        },
      },
    });
  }

  private handleMessage(event: MessageEvent) {
    const message = JSON.parse(event.data);

    switch (message.type) {
      case 'session.created':
        this.onSessionCreated?.(message.session);
        break;

      case 'input_audio_buffer.speech_started':
        this.onSpeechStarted?.();
        break;

      case 'input_audio_buffer.speech_stopped':
        this.onSpeechStopped?.();
        break;

      case 'conversation.item.input_audio_transcription.completed':
        this.onTranscript?.(message.transcript);
        break;

      case 'response.audio_transcript.delta':
        this.onResponseDelta?.(message.delta);
        break;

      case 'response.done':
        this.onResponseComplete?.(message.response);
        break;
    }
  }

  send(message: object) {
    if (this.dc.readyState === 'open') {
      this.dc.send(JSON.stringify(message));
    }
  }

  disconnect() {
    this.audioElement?.pause();
    this.dc?.close();
    this.pc?.close();
  }
}
```

---

## WebSocket (Server Connection)

### Management API WebSocket

Connect to receive real-time logs and metrics:

```
ws://localhost:8766/ws
```

### Connection

```typescript
class ServerWebSocket {
  private ws: WebSocket;
  private reconnectAttempts = 0;
  private maxReconnectAttempts = 5;

  connect() {
    this.ws = new WebSocket('ws://localhost:8766/ws');

    this.ws.onopen = () => {
      console.log('Connected to server');
      this.reconnectAttempts = 0;
    };

    this.ws.onmessage = (event) => {
      const message = JSON.parse(event.data);
      this.handleMessage(message);
    };

    this.ws.onclose = () => {
      this.scheduleReconnect();
    };

    this.ws.onerror = (error) => {
      console.error('WebSocket error:', error);
    };
  }

  private handleMessage(message: ServerMessage) {
    switch (message.type) {
      case 'connected':
        console.log('Server stats:', message.data.stats);
        break;

      case 'pong':
        // Heartbeat response
        break;

      case 'log_received':
        this.onLog?.(message.data);
        break;

      case 'metrics_received':
        this.onMetrics?.(message.data);
        break;

      case 'client_status_changed':
        this.onClientStatus?.(message.data);
        break;
    }
  }

  private scheduleReconnect() {
    if (this.reconnectAttempts < this.maxReconnectAttempts) {
      const delay = Math.pow(2, this.reconnectAttempts) * 1000;
      setTimeout(() => {
        this.reconnectAttempts++;
        this.connect();
      }, delay);
    }
  }

  ping() {
    this.send({ type: 'ping' });
  }

  send(message: object) {
    if (this.ws.readyState === WebSocket.OPEN) {
      this.ws.send(JSON.stringify(message));
    }
  }

  disconnect() {
    this.ws?.close();
  }
}
```

### Server Messages

**Connected:**
```json
{
  "type": "connected",
  "data": {
    "server_time": "2024-01-15T12:30:00Z",
    "stats": {
      "total_logs": 150000,
      "online_clients": 12
    }
  }
}
```

**Log Received:**
```json
{
  "type": "log_received",
  "data": {
    "id": "log-id",
    "timestamp": "2024-01-15T12:30:00Z",
    "level": "INFO",
    "label": "SessionManager",
    "message": "Session started",
    "client_name": "Chrome on macOS"
  }
}
```

**Metrics Received:**
```json
{
  "type": "metrics_received",
  "data": {
    "timestamp": "2024-01-15T12:30:00Z",
    "memory_mb": 512,
    "cpu_percent": 45.2,
    "client_name": "Chrome on macOS"
  }
}
```

**Client Status Changed:**
```json
{
  "type": "client_status_changed",
  "data": {
    "client_id": "device-uuid",
    "status": "online",
    "last_heartbeat": "2024-01-15T12:30:00Z"
  }
}
```

---

## WebSocket (STT Fallback)

When WebRTC is unavailable, use WebSocket for STT:

### Deepgram WebSocket

```typescript
class DeepgramWebSocket {
  private ws: WebSocket;

  async connect(apiKey: string) {
    const url = new URL('wss://api.deepgram.com/v1/listen');
    url.searchParams.set('model', 'nova-3');
    url.searchParams.set('language', 'en-US');
    url.searchParams.set('punctuate', 'true');
    url.searchParams.set('interim_results', 'true');
    url.searchParams.set('endpointing', '500');
    url.searchParams.set('encoding', 'linear16');
    url.searchParams.set('sample_rate', '16000');

    this.ws = new WebSocket(url.toString(), ['token', apiKey]);

    this.ws.onmessage = (event) => {
      const data = JSON.parse(event.data);

      if (data.type === 'Results') {
        const alt = data.channel?.alternatives?.[0];
        if (alt) {
          this.onResult?.({
            text: alt.transcript,
            isFinal: data.is_final,
            confidence: alt.confidence,
            words: alt.words,
          });
        }
      }
    };

    return new Promise<void>((resolve, reject) => {
      this.ws.onopen = () => resolve();
      this.ws.onerror = (e) => reject(e);
    });
  }

  sendAudio(buffer: ArrayBuffer) {
    if (this.ws.readyState === WebSocket.OPEN) {
      this.ws.send(buffer);
    }
  }

  close() {
    this.ws?.close();
  }
}
```

### AssemblyAI WebSocket

```typescript
class AssemblyAIWebSocket {
  private ws: WebSocket;

  async connect(apiKey: string) {
    // Get temporary token
    const tokenResponse = await fetch(
      'https://api.assemblyai.com/v2/realtime/token',
      {
        method: 'POST',
        headers: {
          'Authorization': apiKey,
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({ expires_in: 3600 }),
      }
    );
    const { token } = await tokenResponse.json();

    // Connect
    this.ws = new WebSocket(
      `wss://api.assemblyai.com/v2/realtime/ws?sample_rate=16000&token=${token}`
    );

    this.ws.onmessage = (event) => {
      const data = JSON.parse(event.data);

      if (data.message_type === 'PartialTranscript') {
        this.onResult?.({ text: data.text, isFinal: false });
      } else if (data.message_type === 'FinalTranscript') {
        this.onResult?.({
          text: data.text,
          isFinal: true,
          confidence: data.confidence,
        });
      }
    };
  }

  sendAudio(buffer: ArrayBuffer) {
    if (this.ws.readyState === WebSocket.OPEN) {
      // AssemblyAI expects base64
      const base64 = btoa(
        String.fromCharCode(...new Uint8Array(buffer))
      );
      this.ws.send(JSON.stringify({ audio_data: base64 }));
    }
  }
}
```

---

## Server-Sent Events (LLM Streaming)

### OpenAI Streaming

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
    const lines = chunk.split('\n');

    for (const line of lines) {
      if (line.startsWith('data: ')) {
        const data = line.slice(6);
        if (data === '[DONE]') return;

        const parsed = JSON.parse(data);
        const content = parsed.choices[0]?.delta?.content;
        if (content) yield content;
      }
    }
  }
}
```

### Anthropic Streaming

```typescript
async function* streamAnthropic(
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

---

## Error Handling

### WebSocket Errors

```typescript
class WebSocketManager {
  private ws: WebSocket;
  private reconnectAttempts = 0;
  private readonly maxReconnectAttempts = 5;
  private readonly baseDelay = 1000;

  connect(url: string) {
    this.ws = new WebSocket(url);

    this.ws.onclose = (event) => {
      if (event.wasClean) {
        console.log('Connection closed cleanly');
      } else {
        console.error('Connection died');
        this.scheduleReconnect(url);
      }
    };

    this.ws.onerror = (error) => {
      console.error('WebSocket error:', error);
    };
  }

  private scheduleReconnect(url: string) {
    if (this.reconnectAttempts >= this.maxReconnectAttempts) {
      console.error('Max reconnection attempts reached');
      this.onMaxReconnectAttemptsReached?.();
      return;
    }

    const delay = this.baseDelay * Math.pow(2, this.reconnectAttempts);
    console.log(`Reconnecting in ${delay}ms...`);

    setTimeout(() => {
      this.reconnectAttempts++;
      this.connect(url);
    }, delay);
  }

  resetReconnectAttempts() {
    this.reconnectAttempts = 0;
  }
}
```

### WebRTC Errors

```typescript
class WebRTCManager {
  private pc: RTCPeerConnection;

  setupConnectionMonitoring() {
    this.pc.onconnectionstatechange = () => {
      switch (this.pc.connectionState) {
        case 'connected':
          console.log('WebRTC connected');
          break;

        case 'disconnected':
          console.log('WebRTC disconnected, attempting recovery');
          this.attemptRecovery();
          break;

        case 'failed':
          console.error('WebRTC connection failed');
          this.onConnectionFailed?.();
          break;

        case 'closed':
          console.log('WebRTC connection closed');
          break;
      }
    };

    this.pc.oniceconnectionstatechange = () => {
      if (this.pc.iceConnectionState === 'failed') {
        console.log('ICE connection failed, restarting ICE');
        this.pc.restartIce();
      }
    };
  }

  private async attemptRecovery() {
    // Try to restart ICE
    this.pc.restartIce();

    // If that fails, full reconnection
    setTimeout(() => {
      if (this.pc.connectionState === 'disconnected') {
        this.onRecoveryFailed?.();
      }
    }, 10000);
  }
}
```

---

## Connection State Management

```typescript
type ConnectionState =
  | 'disconnected'
  | 'connecting'
  | 'connected'
  | 'reconnecting'
  | 'error';

class ConnectionManager {
  private state: ConnectionState = 'disconnected';
  private listeners: Set<(state: ConnectionState) => void> = new Set();

  setState(state: ConnectionState) {
    this.state = state;
    this.listeners.forEach(listener => listener(state));
  }

  getState(): ConnectionState {
    return this.state;
  }

  subscribe(listener: (state: ConnectionState) => void) {
    this.listeners.add(listener);
    return () => this.listeners.delete(listener);
  }
}

// React hook
function useConnectionState() {
  const [state, setState] = useState<ConnectionState>('disconnected');

  useEffect(() => {
    return connectionManager.subscribe(setState);
  }, []);

  return state;
}
```

---

## Heartbeat

Keep connections alive with regular heartbeats:

```typescript
class HeartbeatManager {
  private interval: NodeJS.Timeout | null = null;
  private readonly pingInterval = 30000; // 30 seconds
  private lastPong = Date.now();

  start(ws: WebSocket) {
    this.interval = setInterval(() => {
      if (ws.readyState === WebSocket.OPEN) {
        ws.send(JSON.stringify({ type: 'ping' }));

        // Check for missed pongs
        if (Date.now() - this.lastPong > this.pingInterval * 2) {
          console.error('Connection appears dead');
          ws.close();
        }
      }
    }, this.pingInterval);
  }

  onPong() {
    this.lastPong = Date.now();
  }

  stop() {
    if (this.interval) {
      clearInterval(this.interval);
      this.interval = null;
    }
  }
}
```

---

## Message Queuing

Queue messages during disconnection:

```typescript
class MessageQueue {
  private queue: object[] = [];
  private maxSize = 100;

  enqueue(message: object) {
    if (this.queue.length >= this.maxSize) {
      this.queue.shift(); // Remove oldest
    }
    this.queue.push(message);
  }

  flush(ws: WebSocket) {
    while (this.queue.length > 0 && ws.readyState === WebSocket.OPEN) {
      const message = this.queue.shift()!;
      ws.send(JSON.stringify(message));
    }
  }

  clear() {
    this.queue = [];
  }

  get length() {
    return this.queue.length;
  }
}
```

---

*End of WebSocket Protocol Guide*
