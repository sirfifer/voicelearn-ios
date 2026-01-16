# Curricula API

**Version:** 1.0.0
**Last Updated:** 2026-01-16
**Base URL:** `http://localhost:8766`

---

## Overview

The Curricula API manages learning content including curricula, topics, visual assets, and transcripts. Content follows the UMCF (UnaMentis Curriculum Format) specification.

---

## Data Models

### Curriculum

```json
{
  "id": "550e8400-e29b-41d4-a716-446655440000",
  "title": "Introduction to Physics",
  "description": "Foundational physics concepts",
  "source": "brilliant",
  "topic_count": 24,
  "modules": [...],
  "created_at": "2026-01-16T10:00:00Z",
  "updated_at": "2026-01-16T12:00:00Z"
}
```

### Topic

```json
{
  "id": "topic-001",
  "title": "Newton's First Law",
  "description": "Law of inertia",
  "order": 1,
  "module_id": "module-001",
  "content": "...",
  "assets": [...],
  "transcript": "..."
}
```

### Visual Asset

```json
{
  "id": "asset-001",
  "type": "image",
  "url": "/assets/curriculum/550e.../topic-001/diagram.png",
  "caption": "Force diagram",
  "position": 3
}
```

---

## Endpoints

### GET /api/curricula

List all curricula.

**Authentication:** Required

**Query Parameters:**
- `archived` (boolean): Include archived curricula (default: false)

**Response (200 OK):**
```json
[
  {
    "id": "550e8400-e29b-41d4-a716-446655440000",
    "title": "Introduction to Physics",
    "description": "Foundational physics concepts",
    "topic_count": 24,
    "source": "brilliant",
    "created_at": "2026-01-16T10:00:00Z"
  },
  {
    "id": "660e8400-e29b-41d4-a716-446655440001",
    "title": "Calculus Fundamentals",
    "description": "Introduction to calculus",
    "topic_count": 36,
    "source": "khan_academy",
    "created_at": "2026-01-15T08:00:00Z"
  }
]
```

---

### GET /api/curricula/archived

List archived curricula.

**Authentication:** Required

**Response (200 OK):**
```json
[
  {
    "file_name": "physics_archive_20260115.zip",
    "title": "Old Physics Course",
    "archived_at": "2026-01-15T12:00:00Z",
    "size_bytes": 15234567
  }
]
```

---

### GET /api/curricula/{curriculum_id}

Get curriculum details.

**Authentication:** Required

**Parameters:**
- `curriculum_id` (path): Curriculum identifier

**Response (200 OK):**
```json
{
  "id": "550e8400-e29b-41d4-a716-446655440000",
  "title": "Introduction to Physics",
  "description": "Foundational physics concepts",
  "source": "brilliant",
  "topic_count": 24,
  "modules": [
    {
      "id": "module-001",
      "title": "Mechanics",
      "order": 1,
      "topics": [
        {
          "id": "topic-001",
          "title": "Newton's First Law",
          "order": 1
        },
        {
          "id": "topic-002",
          "title": "Newton's Second Law",
          "order": 2
        }
      ]
    }
  ],
  "created_at": "2026-01-16T10:00:00Z",
  "updated_at": "2026-01-16T12:00:00Z"
}
```

---

### GET /api/curricula/{curriculum_id}/full

Get full curriculum with all content.

**Authentication:** Required

**Parameters:**
- `curriculum_id` (path): Curriculum identifier

**Response (200 OK):**
```json
{
  "id": "550e8400-e29b-41d4-a716-446655440000",
  "title": "Introduction to Physics",
  "modules": [
    {
      "id": "module-001",
      "title": "Mechanics",
      "topics": [
        {
          "id": "topic-001",
          "title": "Newton's First Law",
          "content": "Full topic content here...",
          "transcript": "Full transcript text...",
          "assets": [
            {
              "id": "asset-001",
              "type": "image",
              "url": "/assets/...",
              "caption": "Force diagram"
            }
          ]
        }
      ]
    }
  ]
}
```

---

### POST /api/curricula/import

Import a new curriculum from UMCF file.

**Authentication:** Required

**Request Body (multipart/form-data):**
- `file`: UMCF ZIP or JSON file

**Response (201 Created):**
```json
{
  "id": "770e8400-e29b-41d4-a716-446655440002",
  "title": "Imported Curriculum",
  "topic_count": 12,
  "import_status": "complete"
}
```

**Errors:**
- `400`: Invalid UMCF format
- `413`: File too large

---

### PUT /api/curricula/{curriculum_id}

Update/save curriculum.

**Authentication:** Required

**Parameters:**
- `curriculum_id` (path): Curriculum identifier

**Request Body:**
```json
{
  "title": "Updated Title",
  "description": "Updated description"
}
```

**Response (200 OK):**
```json
{
  "id": "550e8400-e29b-41d4-a716-446655440000",
  "title": "Updated Title",
  "description": "Updated description",
  "updated_at": "2026-01-16T15:00:00Z"
}
```

---

### DELETE /api/curricula/{curriculum_id}

Delete a curriculum permanently.

**Authentication:** Required

**Parameters:**
- `curriculum_id` (path): Curriculum identifier

**Response (200 OK):**
```json
{
  "message": "Curriculum deleted"
}
```

**Errors:**
- `404`: Curriculum not found

---

### POST /api/curricula/{curriculum_id}/archive

Archive a curriculum.

**Authentication:** Required

**Parameters:**
- `curriculum_id` (path): Curriculum identifier

**Response (200 OK):**
```json
{
  "message": "Curriculum archived",
  "archive_file": "physics_archive_20260116.zip"
}
```

---

### POST /api/curricula/archived/{file_name}/unarchive

Restore an archived curriculum.

**Authentication:** Required

**Parameters:**
- `file_name` (path): Archive file name

**Response (200 OK):**
```json
{
  "id": "550e8400-e29b-41d4-a716-446655440000",
  "title": "Restored Curriculum",
  "message": "Curriculum restored"
}
```

---

### DELETE /api/curricula/archived/{file_name}

Delete an archived curriculum permanently.

**Authentication:** Required

**Parameters:**
- `file_name` (path): Archive file name

**Response (200 OK):**
```json
{
  "message": "Archive deleted"
}
```

---

### POST /api/curricula/reload

Reload all curricula from disk.

**Authentication:** Required

**Response (200 OK):**
```json
{
  "message": "Curricula reloaded",
  "count": 5
}
```

---

## Topic Endpoints

### GET /api/curricula/{curriculum_id}/topics/{topic_id}/transcript

Get the transcript for a specific topic.

**Authentication:** Required

**Response (200 OK):**
```json
{
  "topic_id": "topic-001",
  "title": "Newton's First Law",
  "transcript": "Newton's first law states that an object at rest stays at rest..."
}
```

---

### GET /api/curricula/{curriculum_id}/topics/{topic_id}/stream-audio

Stream pre-generated audio for a topic.

**Authentication:** Required

**Response (200 OK):**
- Content-Type: `audio/mpeg`
- Streaming audio data

---

## Visual Asset Endpoints

### POST /api/curricula/{curriculum_id}/topics/{topic_id}/assets

Upload a visual asset for a topic.

**Authentication:** Required

**Request Body (multipart/form-data):**
- `file`: Image file (PNG, JPEG, SVG)
- `caption`: Optional caption
- `position`: Position in content (paragraph index)

**Response (201 Created):**
```json
{
  "id": "asset-002",
  "type": "image",
  "url": "/assets/curriculum/550e.../topic-001/asset-002.png",
  "caption": "Velocity diagram",
  "position": 5
}
```

**Errors:**
- `400`: Invalid file type
- `413`: File too large (max 10MB)

---

### PATCH /api/curricula/{curriculum_id}/topics/{topic_id}/assets/{asset_id}

Update asset metadata.

**Authentication:** Required

**Request Body:**
```json
{
  "caption": "Updated caption",
  "position": 7
}
```

**Response (200 OK):**
```json
{
  "id": "asset-002",
  "caption": "Updated caption",
  "position": 7
}
```

---

### DELETE /api/curricula/{curriculum_id}/topics/{topic_id}/assets/{asset_id}

Delete a visual asset.

**Authentication:** Required

**Response (200 OK):**
```json
{
  "message": "Asset deleted"
}
```

---

### POST /api/curricula/{curriculum_id}/preload-assets

Preload all assets for a curriculum.

**Authentication:** Required

**Response (200 OK):**
```json
{
  "message": "Assets preloading",
  "job_id": "preload-001",
  "asset_count": 45
}
```

---

### GET /api/curricula/{curriculum_id}/full-with-assets

Get curriculum with all assets included as base64.

**Authentication:** Required

**Response (200 OK):**
```json
{
  "id": "550e8400-e29b-41d4-a716-446655440000",
  "title": "Introduction to Physics",
  "modules": [...],
  "assets": {
    "asset-001": {
      "type": "image/png",
      "data": "base64encodeddata..."
    }
  }
}
```

---

## Client Implementation Notes

### Caching Strategy

1. Cache curriculum list with 5-minute TTL
2. Cache full curriculum content indefinitely (invalidate on update)
3. Cache assets locally for offline access

### Offline Support

1. Download curriculum via `/full-with-assets`
2. Store in local database
3. Sync on reconnection

---

## Related Documentation

- [Client Spec: Curriculum Tab](../client-spec/03-CURRICULUM_TAB.md)
- [Import API](05-IMPORT.md) - Content import
- [Sessions API](03-SESSIONS.md) - Using curricula in sessions
