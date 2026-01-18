# WebSocket API

**Version:** 1.0.0
**Last Updated:** 2026-01-16
**Base URL:** `ws://localhost:8766`

---

## Overview

The WebSocket API provides real-time communication for audio streaming, live updates, and bidirectional messaging during tutoring sessions.

---

## Endpoints

| Endpoint | Purpose |
|----------|---------|
| `/ws` | General updates (logs, metrics, state) |
| `/ws/audio` | Audio streaming for voice sessions |

---

## Authentication

Include access token as query parameter:

```
ws://localhost:8766/ws?token=<access_token>
```

Or send authentication message after connect:

```json
{
  "type": "auth",
  "token": "<access_token>"
}
```

---

## General WebSocket (`/ws`)

### Connection

```javascript
const ws = new WebSocket('ws://localhost:8766/ws?token=xxx');

ws.onopen = () => {
  console.log('Connected');
};

ws.onmessage = (event) => {
  const message = JSON.parse(event.data);
  handleMessage(message);
};
```

### Message Format

All messages follow this structure:

```json
{
  "type": "message_type",
  "timestamp": "2026-01-16T10:00:00.000Z",
  "data": {}
}
```

### Incoming Message Types

#### `log`
Real-time log message from server:

```json
{
  "type": "log",
  "timestamp": "2026-01-16T10:00:00.000Z",
  "data": {
    "level": "info",
    "message": "Session started",
    "source": "session-manager"
  }
}
```

#### `metric`
System metrics update:

```json
{
  "type": "metric",
  "timestamp": "2026-01-16T10:00:00.000Z",
  "data": {
    "cpu_percent": 25.5,
    "memory_percent": 45.2,
    "active_sessions": 3
  }
}
```

#### `session_update`
Session state change:

```json
{
  "type": "session_update",
  "timestamp": "2026-01-16T10:00:00.000Z",
  "data": {
    "session_id": "sess-001",
    "status": "active",
    "event": "started"
  }
}
```

#### `service_status`
Service status change:

```json
{
  "type": "service_status",
  "timestamp": "2026-01-16T10:00:00.000Z",
  "data": {
    "service_id": "management-api",
    "status": "running",
    "event": "restart"
  }
}
```

#### `import_progress`
Import job progress:

```json
{
  "type": "import_progress",
  "timestamp": "2026-01-16T10:00:00.000Z",
  "data": {
    "job_id": "job-001",
    "progress": 0.65,
    "current_topic": "Newton's Laws"
  }
}
```

### Outgoing Message Types

#### `subscribe`
Subscribe to specific updates:

```json
{
  "type": "subscribe",
  "channels": ["logs", "metrics", "sessions"]
}
```

#### `unsubscribe`
Unsubscribe from channels:

```json
{
  "type": "unsubscribe",
  "channels": ["logs"]
}
```

#### `ping`
Keep-alive ping:

```json
{
  "type": "ping"
}
```

Response:
```json
{
  "type": "pong"
}
```

---

## Audio WebSocket (`/ws/audio`)

### Connection

```javascript
const ws = new WebSocket('ws://localhost:8766/ws/audio?token=xxx&session=sess-001');
```

Query parameters:
- `token`: Access token (required)
- `session`: Session ID (required)

### Protocol

The audio WebSocket uses a mixed binary/JSON protocol:
- **JSON frames**: Control messages
- **Binary frames**: Audio data

### Control Messages

#### `config`
Configure audio settings (send first):

```json
{
  "type": "config",
  "sample_rate": 16000,
  "channels": 1,
  "format": "pcm16",
  "vad_enabled": true,
  "vad_threshold": 0.5
}
```

#### `start_recording`
Begin capturing audio:

```json
{
  "type": "start_recording"
}
```

#### `stop_recording`
Stop capturing, trigger processing:

```json
{
  "type": "stop_recording"
}
```

#### `cancel`
Cancel current processing:

```json
{
  "type": "cancel"
}
```

#### `set_topic`
Change current topic:

```json
{
  "type": "set_topic",
  "topic_id": "topic-002"
}
```

### Audio Data (Binary)

Send raw audio as binary frames:
- Format: PCM 16-bit, mono
- Sample rate: 16000 Hz
- Chunk size: 4096 bytes recommended

### Server Responses

#### `vad_start`
Voice activity detected:

```json
{
  "type": "vad_start",
  "timestamp": "2026-01-16T10:00:00.000Z"
}
```

#### `vad_end`
End of speech detected:

```json
{
  "type": "vad_end",
  "timestamp": "2026-01-16T10:00:01.500Z",
  "duration_ms": 1500
}
```

#### `transcript`
Speech-to-text result:

```json
{
  "type": "transcript",
  "text": "Can you explain Newton's first law?",
  "confidence": 0.95,
  "latency_ms": 180
}
```

#### `llm_start`
LLM processing started:

```json
{
  "type": "llm_start",
  "timestamp": "2026-01-16T10:00:01.700Z"
}
```

#### `llm_token`
Streaming LLM token:

```json
{
  "type": "llm_token",
  "token": "Newton's"
}
```

#### `llm_complete`
LLM response complete:

```json
{
  "type": "llm_complete",
  "text": "Newton's first law states that...",
  "latency_ms": 450
}
```

#### `tts_start`
TTS generation started:

```json
{
  "type": "tts_start",
  "text_length": 150
}
```

#### `audio`
TTS audio chunk (binary frame):
- Server sends binary audio data
- Format matches configured output format

#### `tts_complete`
TTS generation complete:

```json
{
  "type": "tts_complete",
  "duration_ms": 5000,
  "latency_ms": 120
}
```

#### `turn_complete`
Full turn complete:

```json
{
  "type": "turn_complete",
  "turn_id": "turn-001",
  "metrics": {
    "stt_ms": 180,
    "llm_ms": 450,
    "tts_ms": 120,
    "total_ms": 750
  }
}
```

#### `error`
Error occurred:

```json
{
  "type": "error",
  "code": "STT_TIMEOUT",
  "message": "Speech recognition timed out",
  "recoverable": true
}
```

#### `visual_asset`
Visual asset to display:

```json
{
  "type": "visual_asset",
  "asset": {
    "id": "asset-001",
    "type": "diagram",
    "url": "/media/diagrams/abc123.svg",
    "caption": "Force diagram"
  }
}
```

---

## Connection Management

### Heartbeat

Send ping every 30 seconds:

```json
{"type": "ping"}
```

Server responds:
```json
{"type": "pong"}
```

### Reconnection

On disconnect:
1. Wait 1 second
2. Reconnect with exponential backoff
3. Re-authenticate
4. Resume session if active

### Close Codes

| Code | Meaning |
|------|---------|
| 1000 | Normal closure |
| 1001 | Going away (server shutdown) |
| 1008 | Policy violation (auth failed) |
| 1011 | Server error |
| 4000 | Session ended |
| 4001 | Session not found |
| 4002 | Rate limited |

---

## Client Implementation

### iOS Example

```swift
class AudioWebSocket: NSObject, URLSessionWebSocketDelegate {
    private var webSocket: URLSessionWebSocketTask?

    func connect(sessionId: String, token: String) {
        let url = URL(string: "ws://localhost:8766/ws/audio?token=\(token)&session=\(sessionId)")!
        let session = URLSession(configuration: .default, delegate: self, delegateQueue: nil)
        webSocket = session.webSocketTask(with: url)
        webSocket?.resume()
        receiveMessage()
    }

    func sendAudio(_ data: Data) {
        webSocket?.send(.data(data)) { error in
            if let error = error {
                print("Send error: \(error)")
            }
        }
    }

    func sendControl(_ message: [String: Any]) {
        if let data = try? JSONSerialization.data(withJSONObject: message) {
            webSocket?.send(.string(String(data: data, encoding: .utf8)!)) { _ in }
        }
    }

    private func receiveMessage() {
        webSocket?.receive { [weak self] result in
            switch result {
            case .success(.string(let text)):
                self?.handleJSON(text)
            case .success(.data(let data)):
                self?.handleAudio(data)
            case .failure(let error):
                print("Receive error: \(error)")
            }
            self?.receiveMessage()
        }
    }
}
```

### Web Example

```javascript
class AudioSession {
  constructor(sessionId, token) {
    this.ws = new WebSocket(
      `ws://localhost:8766/ws/audio?token=${token}&session=${sessionId}`
    );

    this.ws.binaryType = 'arraybuffer';

    this.ws.onmessage = (event) => {
      if (event.data instanceof ArrayBuffer) {
        this.handleAudio(event.data);
      } else {
        this.handleJSON(JSON.parse(event.data));
      }
    };
  }

  sendAudio(audioData) {
    this.ws.send(audioData);
  }

  sendControl(message) {
    this.ws.send(JSON.stringify(message));
  }
}
```

---

## Performance Considerations

### Audio Buffering

- Client buffer: 100ms recommended
- Server buffer: 50ms
- Total latency budget: 150ms audio pipeline

### Network Optimization

- Use binary frames for audio (not base64)
- Batch small messages when possible
- Enable WebSocket compression if supported

### Error Recovery

- Reconnect on disconnect
- Re-send pending audio on reconnect
- Handle out-of-order messages gracefully

---

## Related Documentation

- [Client Spec: Session Tab](../client-spec/02-SESSION_TAB.md)
- [Sessions API](03-SESSIONS.md) - REST session management
- [TTS API](04-TTS.md) - TTS configuration
