# Sessions API (FOV Context)

**Version:** 1.0.0
**Last Updated:** 2026-01-16
**Base URL:** `http://localhost:8766`

---

## Overview

The Sessions API manages voice learning sessions using the FOV (Field of View) context system. FOV maintains conversation history, topic context, and user progress to provide intelligent tutoring responses.

---

## Data Models

### Session

```json
{
  "id": "sess-001",
  "curriculum_id": "550e8400-e29b-41d4-a716-446655440000",
  "topic_id": "topic-001",
  "status": "active",
  "created_at": "2026-01-16T10:00:00Z",
  "started_at": "2026-01-16T10:01:00Z",
  "ended_at": null,
  "turn_count": 5,
  "duration_seconds": 300
}
```

### Session Status

| Status | Description |
|--------|-------------|
| `created` | Session created but not started |
| `active` | Session in progress |
| `paused` | Session temporarily paused |
| `ended` | Session completed |

### Conversation Turn

```json
{
  "id": "turn-001",
  "session_id": "sess-001",
  "role": "user",
  "content": "Can you explain Newton's first law?",
  "audio_url": "/audio/turn-001.mp3",
  "timestamp": "2026-01-16T10:02:00Z",
  "latency_ms": 450
}
```

---

## Session Lifecycle

```
1. Create session
   POST /api/sessions
   └─> Session in "created" status

2. Start session
   POST /api/sessions/{id}/start
   └─> Session in "active" status
   └─> Audio pipeline initialized

3. Conversation loop:
   ├─> User speaks (audio via WebSocket)
   ├─> POST /api/sessions/{id}/turns (transcript)
   ├─> Server processes with FOV context
   └─> Response streamed back

4. Pause/Resume (optional)
   POST /api/sessions/{id}/pause
   POST /api/sessions/{id}/resume

5. End session
   POST /api/sessions/{id}/end
   └─> Session in "ended" status
   └─> Saved to history
```

---

## Endpoints

### POST /api/sessions

Create a new learning session.

**Authentication:** Required

**Request Body:**
```json
{
  "curriculum_id": "550e8400-e29b-41d4-a716-446655440000",
  "topic_id": "topic-001"
}
```

**Response (201 Created):**
```json
{
  "id": "sess-001",
  "curriculum_id": "550e8400-e29b-41d4-a716-446655440000",
  "topic_id": "topic-001",
  "status": "created",
  "created_at": "2026-01-16T10:00:00Z"
}
```

---

### GET /api/sessions

List sessions.

**Authentication:** Required

**Query Parameters:**
- `curriculum_id` (string): Filter by curriculum
- `status` (string): Filter by status (active, paused, ended)
- `limit` (integer): Max results (default: 50)
- `offset` (integer): Pagination offset

**Response (200 OK):**
```json
{
  "sessions": [
    {
      "id": "sess-001",
      "curriculum_id": "550e...",
      "topic_id": "topic-001",
      "topic_title": "Newton's First Law",
      "status": "ended",
      "turn_count": 12,
      "duration_seconds": 900,
      "created_at": "2026-01-16T10:00:00Z"
    }
  ],
  "total": 25,
  "limit": 50,
  "offset": 0
}
```

---

### GET /api/sessions/{session_id}

Get session details.

**Authentication:** Required

**Response (200 OK):**
```json
{
  "id": "sess-001",
  "curriculum_id": "550e8400-e29b-41d4-a716-446655440000",
  "topic_id": "topic-001",
  "topic_title": "Newton's First Law",
  "curriculum_title": "Introduction to Physics",
  "status": "active",
  "turn_count": 5,
  "duration_seconds": 300,
  "created_at": "2026-01-16T10:00:00Z",
  "started_at": "2026-01-16T10:01:00Z",
  "metrics": {
    "stt_latency_median": 180,
    "llm_latency_median": 450,
    "tts_latency_median": 120,
    "e2e_latency_median": 750
  }
}
```

---

### DELETE /api/sessions/{session_id}

Delete a session.

**Authentication:** Required

**Response (200 OK):**
```json
{
  "message": "Session deleted"
}
```

---

### POST /api/sessions/{session_id}/start

Start a session.

**Authentication:** Required

**Response (200 OK):**
```json
{
  "id": "sess-001",
  "status": "active",
  "started_at": "2026-01-16T10:01:00Z",
  "websocket_url": "/ws/audio?session=sess-001"
}
```

---

### POST /api/sessions/{session_id}/pause

Pause an active session.

**Authentication:** Required

**Response (200 OK):**
```json
{
  "id": "sess-001",
  "status": "paused",
  "paused_at": "2026-01-16T10:15:00Z"
}
```

---

### POST /api/sessions/{session_id}/resume

Resume a paused session.

**Authentication:** Required

**Response (200 OK):**
```json
{
  "id": "sess-001",
  "status": "active",
  "resumed_at": "2026-01-16T10:20:00Z"
}
```

---

### POST /api/sessions/{session_id}/end

End a session.

**Authentication:** Required

**Response (200 OK):**
```json
{
  "id": "sess-001",
  "status": "ended",
  "ended_at": "2026-01-16T10:30:00Z",
  "duration_seconds": 1740,
  "turn_count": 15,
  "summary": {
    "topics_covered": ["Newton's First Law", "Inertia"],
    "confidence_score": 0.85
  }
}
```

---

## Topic and Position Management

### PUT /api/sessions/{session_id}/topic

Change the current topic.

**Request Body:**
```json
{
  "topic_id": "topic-002"
}
```

**Response (200 OK):**
```json
{
  "message": "Topic updated",
  "topic_id": "topic-002",
  "topic_title": "Newton's Second Law"
}
```

---

### PUT /api/sessions/{session_id}/position

Set playback position in topic content.

**Request Body:**
```json
{
  "position": 5,
  "segment": "introduction"
}
```

**Response (200 OK):**
```json
{
  "message": "Position updated",
  "position": 5
}
```

---

## Conversation Turns

### POST /api/sessions/{session_id}/turns

Add a conversation turn.

**Request Body:**
```json
{
  "role": "user",
  "content": "Can you explain this in simpler terms?",
  "audio_duration_ms": 2500
}
```

**Response (201 Created):**
```json
{
  "id": "turn-006",
  "role": "user",
  "content": "Can you explain this in simpler terms?",
  "timestamp": "2026-01-16T10:05:00Z"
}
```

---

### POST /api/sessions/{session_id}/barge-in

Record a user interruption (barge-in).

**Request Body:**
```json
{
  "timestamp": "2026-01-16T10:05:30Z",
  "interrupted_turn_id": "turn-005"
}
```

**Response (200 OK):**
```json
{
  "message": "Barge-in recorded"
}
```

---

## FOV Context

### GET /api/sessions/{session_id}/context

Get the current FOV context.

**Response (200 OK):**
```json
{
  "session_id": "sess-001",
  "topic": {
    "id": "topic-001",
    "title": "Newton's First Law",
    "position": 5
  },
  "recent_turns": [
    {
      "role": "assistant",
      "content": "Newton's first law states...",
      "timestamp": "2026-01-16T10:04:00Z"
    },
    {
      "role": "user",
      "content": "Can you explain this in simpler terms?",
      "timestamp": "2026-01-16T10:05:00Z"
    }
  ],
  "user_profile": {
    "learning_style": "visual",
    "expertise_level": "beginner"
  }
}
```

---

### POST /api/sessions/{session_id}/context/build

Build LLM context for the next response.

**Request Body:**
```json
{
  "user_message": "What's an example of this?",
  "include_assets": true
}
```

**Response (200 OK):**
```json
{
  "system_prompt": "You are a tutor teaching physics...",
  "messages": [
    {"role": "system", "content": "Current topic: Newton's First Law..."},
    {"role": "assistant", "content": "Newton's first law states..."},
    {"role": "user", "content": "What's an example of this?"}
  ],
  "available_assets": [
    {"id": "asset-001", "type": "diagram", "caption": "Force diagram"}
  ],
  "token_count": 1250
}
```

---

### GET /api/sessions/{session_id}/messages

Get all session messages.

**Response (200 OK):**
```json
{
  "messages": [
    {
      "id": "turn-001",
      "role": "assistant",
      "content": "Welcome! Today we'll learn about...",
      "timestamp": "2026-01-16T10:01:00Z"
    },
    {
      "id": "turn-002",
      "role": "user",
      "content": "What is inertia?",
      "timestamp": "2026-01-16T10:02:00Z"
    }
  ]
}
```

---

## Session Signals and Events

### POST /api/sessions/{session_id}/signals

Record a session signal.

**Request Body:**
```json
{
  "type": "confusion",
  "confidence": 0.7,
  "context": "User asked for clarification twice"
}
```

---

### GET /api/sessions/{session_id}/events

Get session events timeline.

**Response (200 OK):**
```json
{
  "events": [
    {"type": "session_start", "timestamp": "..."},
    {"type": "turn", "turn_id": "turn-001", "timestamp": "..."},
    {"type": "topic_change", "topic_id": "topic-002", "timestamp": "..."},
    {"type": "barge_in", "timestamp": "..."},
    {"type": "session_end", "timestamp": "..."}
  ]
}
```

---

## Debug Endpoints

### GET /api/sessions/{session_id}/debug

Get debug information for a session.

**Response (200 OK):**
```json
{
  "session_id": "sess-001",
  "state": {
    "status": "active",
    "context_size": 2500,
    "memory_usage_mb": 45
  },
  "latencies": {
    "last_turn": {
      "stt_ms": 180,
      "llm_ms": 450,
      "tts_ms": 120,
      "total_ms": 750
    }
  }
}
```

---

### GET /api/fov/health

Check FOV context system health.

**Response (200 OK):**
```json
{
  "status": "healthy",
  "active_sessions": 3,
  "context_cache_size": 150,
  "memory_usage_mb": 512
}
```

---

## Client Implementation Notes

### Session Lifecycle

1. Create session before starting
2. Use WebSocket for audio during active session
3. Periodically sync turns via REST
4. End session explicitly for proper cleanup

### Error Recovery

- On disconnect: attempt reconnect, resume session
- On 409 conflict: refetch session state
- On 404: session may have been cleaned up

---

## Related Documentation

- [Client Spec: Session Tab](../client-spec/02-SESSION_TAB.md)
- [WebSocket API](08-WEBSOCKET.md) - Real-time audio
- [TTS API](04-TTS.md) - Voice synthesis
