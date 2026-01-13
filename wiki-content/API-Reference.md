# API Reference

Management API (port 8766) endpoint documentation.

## Overview

The Management API provides backend services for:
- Curriculum management
- TTS caching
- Session management
- Import orchestration
- Authentication

**Base URL:** `http://localhost:8766`

## Authentication

Most endpoints require JWT authentication:

```bash
curl -H "Authorization: Bearer <token>" http://localhost:8766/api/...
```

### Get Token

```
POST /api/auth/login
Content-Type: application/json

{
  "username": "user",
  "password": "pass"
}
```

Response:
```json
{
  "access_token": "eyJ...",
  "refresh_token": "eyJ...",
  "expires_in": 3600
}
```

## Core Endpoints

### Health Check

```
GET /health
```

Response:
```json
{
  "status": "healthy",
  "timestamp": "2026-01-12T10:00:00Z"
}
```

### Statistics

```
GET /api/stats
```

Response:
```json
{
  "clients_connected": 3,
  "active_sessions": 2,
  "cache_size_mb": 150,
  "uptime_seconds": 3600
}
```

## Curriculum Endpoints

### List Curricula

```
GET /api/curriculum
```

Query Parameters:
- `limit` (default: 50)
- `offset` (default: 0)

### Get Curriculum

```
GET /api/curriculum/{id}
```

### Create Curriculum

```
POST /api/curriculum
Content-Type: application/json

{
  "title": "Introduction to Python",
  "description": "...",
  "content": [...]
}
```

### Update Curriculum

```
PUT /api/curriculum/{id}
Content-Type: application/json

{
  "title": "Updated Title"
}
```

### Delete Curriculum

```
DELETE /api/curriculum/{id}
```

## TTS Endpoints

### Generate TTS

```
POST /api/tts
Content-Type: application/json

{
  "text": "Hello, welcome to the lesson.",
  "voice_id": "nova",
  "provider": "vibevoice",
  "speed": 1.0
}
```

Response: Audio data (binary)

### Cache Statistics

```
GET /api/tts/cache/stats
```

Response:
```json
{
  "total_entries": 1500,
  "size_bytes": 157286400,
  "hit_rate": 0.85,
  "live_pending": 2,
  "background_pending": 5
}
```

### Check Cache

```
GET /api/tts/cache?text=Hello&voice_id=nova&provider=vibevoice&speed=1.0
```

Response:
```json
{
  "cache_hit": true,
  "duration_seconds": 1.5
}
```

### Prefetch Segments

```
POST /api/tts/prefetch/topic
Content-Type: application/json

{
  "curriculum_id": "...",
  "topic_id": "...",
  "voice_id": "nova",
  "provider": "vibevoice"
}
```

## Session Endpoints

### List Sessions

```
GET /api/sessions
```

### Get Session

```
GET /api/sessions/{id}
```

### Create Session

```
POST /api/sessions
Content-Type: application/json

{
  "user_id": "user_123",
  "curriculum_id": "curr_456"
}
```

### Update Session

```
PATCH /api/sessions/{id}
Content-Type: application/json

{
  "playback_position": 150,
  "segment_index": 5
}
```

## Import Endpoints

### List Import Jobs

```
GET /api/imports
```

### Start Import

```
POST /api/imports
Content-Type: application/json

{
  "source": "mit_ocw",
  "course_id": "6.001"
}
```

### Get Import Status

```
GET /api/imports/{id}
```

Response:
```json
{
  "id": "import_123",
  "status": "processing",
  "progress": 0.75,
  "stages_complete": ["download", "validate", "extract"],
  "current_stage": "enrich"
}
```

### Cancel Import

```
DELETE /api/imports/{id}
```

## Deployment Endpoints

### List Deployments

```
GET /api/deployments
```

### Schedule Deployment

```
POST /api/deployments
Content-Type: application/json

{
  "curriculum_id": "...",
  "scheduled_time": "2026-01-15T02:00:00Z",
  "voice_configs": [
    {"voice_id": "nova", "provider": "vibevoice"}
  ]
}
```

### Get Deployment Status

```
GET /api/deployments/{id}
```

### Start Deployment

```
POST /api/deployments/{id}/start
```

### Pause Deployment

```
POST /api/deployments/{id}/pause
```

### Resume Deployment

```
POST /api/deployments/{id}/resume
```

### Cancel Deployment

```
DELETE /api/deployments/{id}
```

## WebSocket Endpoints

### Real-time Updates

```
WS /ws
```

Message types:
- `stats_update` - Dashboard statistics
- `log_entry` - New log entry
- `client_connected` - Client connection
- `client_disconnected` - Client disconnection

### Audio Streaming

```
WS /ws/audio?session_id=xxx
```

See `server/management/README.md` for protocol details.

## Error Responses

All errors follow this format:

```json
{
  "error": "Error message",
  "code": "ERROR_CODE",
  "details": {}
}
```

### Common Error Codes

| Code | HTTP Status | Description |
|------|-------------|-------------|
| `NOT_FOUND` | 404 | Resource not found |
| `VALIDATION_ERROR` | 400 | Invalid request data |
| `UNAUTHORIZED` | 401 | Missing or invalid token |
| `FORBIDDEN` | 403 | Insufficient permissions |
| `RATE_LIMITED` | 429 | Too many requests |
| `SERVER_ERROR` | 500 | Internal server error |

## Rate Limiting

- Default: 100 requests/minute per IP
- Auth endpoints: 10 requests/minute
- TTS generation: 60 requests/minute

## CORS

CORS is enabled for:
- `http://localhost:3000` (Operations Console)
- `http://localhost:3001` (Web Client)

## Related Pages

- [[Server-Development]] - Server development
- [[Voice-Pipeline]] - TTS caching details
- [[Architecture]] - System overview

---

Back to [[Home]]
