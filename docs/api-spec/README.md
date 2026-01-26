# UnaMentis Server API Specification

**Version:** 1.1.0
**Status:** Active
**Last Updated:** 2026-01-25
**Base URL:** `http://localhost:8766` (Management API)

---

## Purpose

This specification documents the UnaMentis server API for client developers. It includes both machine-readable OpenAPI specification and human-readable guides for each API category.

**Target Audience:** AI agents and developers building UnaMentis clients or integrating with the server.

---

## Document Index

| Document | Purpose | Endpoints |
|----------|---------|-----------|
| [openapi.yaml](openapi.yaml) | Machine-readable spec | All endpoints |
| [01-AUTHENTICATION.md](01-AUTHENTICATION.md) | Auth flows | `/api/auth/*` |
| [02-CURRICULA.md](02-CURRICULA.md) | Content management | `/api/curricula/*` |
| [03-SESSIONS.md](03-SESSIONS.md) | Learning sessions | `/api/sessions/*` |
| [04-TTS.md](04-TTS.md) | Voice synthesis | `/api/tts/*` |
| [05-IMPORT.md](05-IMPORT.md) | Content import | `/api/import/*`, `/api/sources/*` |
| [06-MEDIA.md](06-MEDIA.md) | Media generation | `/api/media/*` |
| [07-SYSTEM.md](07-SYSTEM.md) | Health & monitoring | `/api/system/*`, `/health` |
| [08-WEBSOCKET.md](08-WEBSOCKET.md) | Real-time protocols | `/ws` |
| [09-KNOWLEDGE-BOWL.md](09-KNOWLEDGE-BOWL.md) | Knowledge Bowl | `/api/kb/*` |

---

## Quick Reference

### Server Components

| Component | Port | Technology | Purpose |
|-----------|------|------------|---------|
| Management API | 8766 | Python/aiohttp | Content administration, API |
| USM Core | 8787 | Rust/Axum | Cross-platform service management |
| USM (Legacy) | 8767 | Swift | macOS menu bar app (original) |
| Operations Console | 3000 | Next.js/React | System/content management |

### Authentication

All authenticated endpoints require:
```
Authorization: Bearer <access_token>
Content-Type: application/json
```

Token lifecycle:
- Access token: 1 hour validity
- Refresh token: 30 days validity
- Use `/api/auth/refresh` to renew

### Common Response Codes

| Code | Meaning |
|------|---------|
| 200 | Success |
| 201 | Created |
| 400 | Bad Request (validation error) |
| 401 | Unauthorized (invalid/expired token) |
| 403 | Forbidden (insufficient permissions) |
| 404 | Not Found |
| 429 | Rate Limited |
| 500 | Internal Server Error |

### Error Response Format

```json
{
  "error": "Human-readable error message",
  "code": "ERROR_CODE",
  "details": {}
}
```

---

## Endpoint Summary

### Authentication (11 endpoints)
- `POST /api/auth/register` - Create account
- `POST /api/auth/login` - Authenticate
- `POST /api/auth/refresh` - Refresh token
- `POST /api/auth/logout` - End session
- `GET /api/auth/me` - Get profile
- `PATCH /api/auth/me` - Update profile
- `POST /api/auth/password` - Change password
- `GET /api/auth/devices` - List devices
- `DELETE /api/auth/devices/{id}` - Remove device
- `GET /api/auth/sessions` - List sessions
- `DELETE /api/auth/sessions/{id}` - End session

### Curricula (15+ endpoints)
- `GET /api/curricula` - List curricula
- `POST /api/curricula` - Import curriculum
- `GET /api/curricula/{id}` - Get details
- `GET /api/curricula/{id}/full` - Get complete content
- `DELETE /api/curricula/{id}` - Delete
- `POST /api/curricula/{id}/archive` - Archive
- Visual asset management endpoints
- Topic transcript endpoints

### Sessions/FOV (16 endpoints)
- Session lifecycle (create, start, pause, resume, end)
- Topic and position management
- Conversation turns
- Context building
- Confidence analysis

### TTS (30+ endpoints)
- Basic TTS generation
- Voice profiles
- Pre-generation system
- Cache management
- TTS Lab experimentation (model selection, configuration tuning)

### Import (8 endpoints)
- Source browsing
- Import jobs
- Progress tracking

### Media (7 endpoints)
- Diagram rendering
- Formula rendering
- Map generation

### System (30+ endpoints)
- Health checks
- Metrics
- Service management
- Model management

### WebSocket
- `/ws` - Audio streaming and real-time sync

---

## Related Documentation

- **Client Feature Spec**: [../client-spec/README.md](../client-spec/README.md)
- **Project Overview**: [../architecture/PROJECT_OVERVIEW.md](../architecture/PROJECT_OVERVIEW.md)
- **Voice Lab Guide**: [../server/VOICE_LAB_GUIDE.md](../server/VOICE_LAB_GUIDE.md)
- **TTS Lab Guide**: [../server/TTS_LAB_GUIDE.md](../server/TTS_LAB_GUIDE.md)

---

## Using the OpenAPI Spec

### View with Swagger UI
```bash
npx @redocly/cli preview-docs openapi.yaml
```

### Validate
```bash
npx @redocly/cli lint openapi.yaml
```

### Generate Client SDK
```bash
# TypeScript
npx openapi-generator-cli generate -i openapi.yaml -g typescript-fetch -o ./sdk

# Swift
npx openapi-generator-cli generate -i openapi.yaml -g swift5 -o ./sdk

# Kotlin
npx openapi-generator-cli generate -i openapi.yaml -g kotlin -o ./sdk
```
