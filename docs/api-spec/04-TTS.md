# TTS API

**Version:** 1.0.0
**Last Updated:** 2026-01-16
**Base URL:** `http://localhost:8766`

---

## Overview

The TTS (Text-to-Speech) API provides voice synthesis capabilities with multiple provider support, caching, pre-generation, and voice profile management.

---

## Supported Providers

| Provider | ID | Features |
|----------|-----|----------|
| ElevenLabs | `elevenlabs` | High quality, voice cloning |
| Deepgram | `deepgram` | Low latency, streaming |
| Apple | `apple` | On-device, privacy-focused |
| OpenAI | `openai` | Natural voices |

---

## Data Models

### TTS Request

```json
{
  "text": "Hello, welcome to the lesson.",
  "voice": "alloy",
  "provider": "openai",
  "speed": 1.0,
  "format": "mp3"
}
```

### TTS Profile

```json
{
  "id": "profile-001",
  "name": "Default Tutor",
  "provider": "elevenlabs",
  "voice_id": "21m00Tcm4TlvDq8ikWAM",
  "settings": {
    "stability": 0.5,
    "similarity_boost": 0.75,
    "style": 0.0
  },
  "is_default": true
}
```

---

## Basic TTS Generation

### POST /api/tts

Generate TTS audio.

**Authentication:** Required

**Request Body:**
```json
{
  "text": "Newton's first law states that an object at rest stays at rest.",
  "voice": "alloy",
  "provider": "openai",
  "speed": 1.0,
  "format": "mp3"
}
```

**Response (200 OK):**
- Content-Type: `audio/mpeg`
- Body: Audio binary data

**Alternative JSON Response (with `return_url=true`):**
```json
{
  "audio_url": "/audio/tts/abc123.mp3",
  "duration_ms": 3500,
  "cached": false
}
```

**Parameters:**

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `text` | string | required | Text to synthesize |
| `voice` | string | varies | Voice identifier |
| `provider` | string | default | TTS provider |
| `speed` | number | 1.0 | Playback speed (0.5-2.0) |
| `format` | string | "mp3" | Output format (mp3, wav, ogg) |
| `return_url` | boolean | false | Return URL instead of binary |

---

## Cache Management

### GET /api/tts/cache/stats

Get cache statistics.

**Response (200 OK):**
```json
{
  "entries": 1250,
  "size_bytes": 524288000,
  "size_human": "500 MB",
  "hit_rate": 0.78,
  "hits": 9750,
  "misses": 2750,
  "evictions": 500
}
```

---

### GET /api/tts/cache

Get a specific cache entry.

**Query Parameters:**
- `key`: Cache key (hash of text + voice + settings)

**Response (200 OK):**
```json
{
  "key": "abc123",
  "text": "Newton's first law...",
  "voice": "alloy",
  "created_at": "2026-01-16T10:00:00Z",
  "accessed_at": "2026-01-16T14:00:00Z",
  "access_count": 15,
  "size_bytes": 45000
}
```

---

### PUT /api/tts/cache

Store a cache entry manually.

**Request Body:**
```json
{
  "key": "custom-key",
  "text": "Pre-cached phrase",
  "voice": "alloy",
  "audio_data": "base64encodedaudio..."
}
```

---

### DELETE /api/tts/cache

Clear entire cache.

**Response (200 OK):**
```json
{
  "message": "Cache cleared",
  "entries_removed": 1250
}
```

---

### DELETE /api/tts/cache/expired

Evict expired entries.

**Response (200 OK):**
```json
{
  "message": "Expired entries evicted",
  "entries_removed": 150
}
```

---

### POST /api/tts/cache/evict

LRU eviction to free space.

**Request Body:**
```json
{
  "target_size_mb": 400
}
```

**Response (200 OK):**
```json
{
  "message": "Eviction complete",
  "entries_removed": 200,
  "new_size_mb": 398
}
```

---

## Pre-Generation (Prefetch)

### POST /api/tts/prefetch/topic

Pre-generate audio for an entire topic.

**Request Body:**
```json
{
  "curriculum_id": "550e8400-e29b-41d4-a716-446655440000",
  "topic_id": "topic-001",
  "profile_id": "profile-001"
}
```

**Response (202 Accepted):**
```json
{
  "job_id": "prefetch-001",
  "status": "pending",
  "segments": 45,
  "estimated_duration_seconds": 120
}
```

---

### GET /api/tts/prefetch/status/{job_id}

Get prefetch job status.

**Response (200 OK):**
```json
{
  "job_id": "prefetch-001",
  "status": "running",
  "progress": 0.65,
  "segments_complete": 29,
  "segments_total": 45,
  "errors": []
}
```

---

### DELETE /api/tts/prefetch/{job_id}

Cancel a prefetch job.

**Response (200 OK):**
```json
{
  "message": "Prefetch job cancelled"
}
```

---

## Voice Profiles

### GET /api/tts/profiles

List all TTS profiles.

**Response (200 OK):**
```json
[
  {
    "id": "profile-001",
    "name": "Default Tutor",
    "provider": "elevenlabs",
    "voice_id": "21m00Tcm4TlvDq8ikWAM",
    "is_default": true
  },
  {
    "id": "profile-002",
    "name": "Calm Voice",
    "provider": "openai",
    "voice_id": "nova",
    "is_default": false
  }
]
```

---

### POST /api/tts/profiles

Create a new profile.

**Request Body:**
```json
{
  "name": "Energetic Tutor",
  "provider": "elevenlabs",
  "voice_id": "EXAVITQu4vr4xnSDxMaL",
  "settings": {
    "stability": 0.3,
    "similarity_boost": 0.8,
    "style": 0.5
  }
}
```

**Response (201 Created):**
```json
{
  "id": "profile-003",
  "name": "Energetic Tutor",
  "provider": "elevenlabs",
  "voice_id": "EXAVITQu4vr4xnSDxMaL",
  "is_default": false
}
```

---

### GET /api/tts/profiles/{profile_id}

Get profile details.

**Response (200 OK):**
```json
{
  "id": "profile-001",
  "name": "Default Tutor",
  "provider": "elevenlabs",
  "voice_id": "21m00Tcm4TlvDq8ikWAM",
  "settings": {
    "stability": 0.5,
    "similarity_boost": 0.75,
    "style": 0.0,
    "use_speaker_boost": true
  },
  "is_default": true,
  "created_at": "2026-01-10T08:00:00Z"
}
```

---

### PUT /api/tts/profiles/{profile_id}

Update a profile.

**Request Body:**
```json
{
  "name": "Updated Name",
  "settings": {
    "stability": 0.6
  }
}
```

---

### DELETE /api/tts/profiles/{profile_id}

Delete a profile.

**Response (200 OK):**
```json
{
  "message": "Profile deleted"
}
```

---

### POST /api/tts/profiles/{profile_id}/set-default

Set as default profile.

**Response (200 OK):**
```json
{
  "message": "Profile set as default"
}
```

---

### POST /api/tts/profiles/{profile_id}/preview

Generate preview audio.

**Request Body:**
```json
{
  "text": "This is a preview of my voice."
}
```

**Response (200 OK):**
```json
{
  "audio_url": "/audio/preview/profile-001.mp3",
  "duration_ms": 2500
}
```

---

### POST /api/tts/profiles/{profile_id}/duplicate

Duplicate a profile.

**Request Body:**
```json
{
  "name": "Copy of Default Tutor"
}
```

**Response (201 Created):**
```json
{
  "id": "profile-004",
  "name": "Copy of Default Tutor"
}
```

---

### GET /api/tts/profiles/{profile_id}/export

Export profile as JSON.

**Response (200 OK):**
```json
{
  "name": "Default Tutor",
  "provider": "elevenlabs",
  "voice_id": "21m00Tcm4TlvDq8ikWAM",
  "settings": {...}
}
```

---

### POST /api/tts/profiles/import

Import a profile from JSON.

**Request Body:**
```json
{
  "name": "Imported Profile",
  "provider": "elevenlabs",
  "voice_id": "...",
  "settings": {...}
}
```

---

## Provider-Specific Settings

### ElevenLabs

| Setting | Type | Range | Default |
|---------|------|-------|---------|
| `stability` | float | 0-1 | 0.5 |
| `similarity_boost` | float | 0-1 | 0.75 |
| `style` | float | 0-1 | 0.0 |
| `use_speaker_boost` | bool | - | true |

### OpenAI

| Setting | Type | Options | Default |
|---------|------|---------|---------|
| `voice` | string | alloy, echo, fable, onyx, nova, shimmer | alloy |
| `speed` | float | 0.25-4.0 | 1.0 |

### Deepgram

| Setting | Type | Options | Default |
|---------|------|---------|---------|
| `model` | string | aura-* | aura-asteria-en |

---

## Client Implementation Notes

### Streaming TTS

For real-time playback, use WebSocket `/ws/audio` with TTS streaming.

### Caching Strategy

1. Check cache before requesting
2. Pre-fetch likely content
3. Respect cache headers

### Error Handling

- `429`: Rate limited, use exponential backoff
- `503`: Provider unavailable, try fallback

---

## Related Documentation

- [Client Spec: Session Tab](../client-spec/02-SESSION_TAB.md)
- [Client Spec: Settings](../client-spec/07-SETTINGS.md)
- [WebSocket API](08-WEBSOCKET.md) - Audio streaming
