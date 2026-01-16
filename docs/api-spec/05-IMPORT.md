# Import API

**Version:** 1.0.0
**Last Updated:** 2026-01-16
**Base URL:** `http://localhost:8766`

---

## Overview

The Import API enables importing learning content from external sources including Brilliant.org, Khan Academy, and local files. It manages the import pipeline from discovery through conversion to UMCF format.

---

## Supported Sources

| Source ID | Name | Type | Features |
|-----------|------|------|----------|
| `brilliant` | Brilliant.org | API | Courses, practice problems |
| `khan_academy` | Khan Academy | API | Videos, articles, exercises |
| `file` | Local File | Upload | UMCF ZIP/JSON |
| `url` | Remote URL | Fetch | UMCF file from URL |
| `sample` | Sample Content | Built-in | Demo curricula |

---

## Data Models

### Import Source

```json
{
  "id": "brilliant",
  "name": "Brilliant.org",
  "description": "Interactive courses in math, science, and CS",
  "enabled": true,
  "requires_auth": true,
  "auth_configured": false
}
```

### Import Job

```json
{
  "id": "job-001",
  "source": "brilliant",
  "course_id": "intro-to-physics",
  "status": "running",
  "progress": 0.45,
  "topics_imported": 11,
  "topics_total": 24,
  "error": null,
  "created_at": "2026-01-16T10:00:00Z",
  "completed_at": null
}
```

### Import Job Status

| Status | Description |
|--------|-------------|
| `pending` | Job queued |
| `running` | Import in progress |
| `completed` | Successfully finished |
| `failed` | Error occurred |
| `cancelled` | User cancelled |

---

## Source Discovery

### GET /api/import/sources

Get available import sources.

**Authentication:** Required

**Response (200 OK):**
```json
[
  {
    "id": "brilliant",
    "name": "Brilliant.org",
    "description": "Interactive courses in math, science, and CS",
    "enabled": true,
    "requires_auth": true,
    "auth_configured": true,
    "icon_url": "/static/icons/brilliant.png"
  },
  {
    "id": "khan_academy",
    "name": "Khan Academy",
    "description": "Free educational content",
    "enabled": true,
    "requires_auth": false,
    "auth_configured": true
  },
  {
    "id": "file",
    "name": "Local File",
    "description": "Import from UMCF file",
    "enabled": true,
    "requires_auth": false
  }
]
```

---

### GET /api/import/sources/{source_id}

Get detailed source information.

**Response (200 OK):**
```json
{
  "id": "brilliant",
  "name": "Brilliant.org",
  "description": "Interactive courses in math, science, and CS",
  "enabled": true,
  "requires_auth": true,
  "auth_configured": true,
  "categories": [
    "Math",
    "Science",
    "Computer Science",
    "Foundational"
  ],
  "features": {
    "search": true,
    "browse": true,
    "preview": true
  }
}
```

---

## Course Browsing

### GET /api/import/sources/{source_id}/courses

Browse courses from a source.

**Query Parameters:**
- `category` (string): Filter by category
- `search` (string): Search query
- `limit` (integer): Max results (default: 20)
- `offset` (integer): Pagination offset

**Response (200 OK):**
```json
{
  "courses": [
    {
      "id": "intro-to-physics",
      "title": "Introduction to Physics",
      "description": "Learn the fundamentals of physics",
      "topic_count": 24,
      "duration_estimate": "6 hours",
      "difficulty": "beginner",
      "category": "Science",
      "thumbnail_url": "https://..."
    },
    {
      "id": "calculus-fundamentals",
      "title": "Calculus Fundamentals",
      "description": "Master the basics of calculus",
      "topic_count": 36,
      "duration_estimate": "10 hours",
      "difficulty": "intermediate",
      "category": "Math"
    }
  ],
  "total": 150,
  "limit": 20,
  "offset": 0
}
```

---

### GET /api/import/sources/{source_id}/search

Search courses within a source.

**Query Parameters:**
- `q` (string): Search query (required)
- `limit` (integer): Max results

**Response (200 OK):**
```json
{
  "query": "physics",
  "results": [
    {
      "id": "intro-to-physics",
      "title": "Introduction to Physics",
      "relevance": 0.95
    },
    {
      "id": "quantum-physics",
      "title": "Quantum Physics",
      "relevance": 0.87
    }
  ]
}
```

---

### GET /api/import/sources/{source_id}/courses/{course_id}

Get detailed course information for preview.

**Response (200 OK):**
```json
{
  "id": "intro-to-physics",
  "title": "Introduction to Physics",
  "description": "Learn the fundamentals of physics through interactive lessons...",
  "topic_count": 24,
  "modules": [
    {
      "id": "mechanics",
      "title": "Mechanics",
      "topics": [
        {"id": "newtons-first-law", "title": "Newton's First Law"},
        {"id": "newtons-second-law", "title": "Newton's Second Law"}
      ]
    },
    {
      "id": "thermodynamics",
      "title": "Thermodynamics",
      "topics": [
        {"id": "temperature", "title": "Temperature and Heat"},
        {"id": "entropy", "title": "Entropy"}
      ]
    }
  ],
  "estimated_size_mb": 45,
  "last_updated": "2026-01-10T00:00:00Z"
}
```

---

## Import Jobs

### POST /api/import/jobs

Start a new import job.

**Request Body:**
```json
{
  "source": "brilliant",
  "course_id": "intro-to-physics",
  "options": {
    "include_images": true,
    "include_videos": false,
    "selected_modules": ["mechanics"]
  }
}
```

**Response (201 Created):**
```json
{
  "id": "job-001",
  "source": "brilliant",
  "course_id": "intro-to-physics",
  "status": "pending",
  "progress": 0,
  "created_at": "2026-01-16T10:00:00Z"
}
```

---

### GET /api/import/jobs

List import jobs.

**Query Parameters:**
- `status` (string): Filter by status
- `limit` (integer): Max results

**Response (200 OK):**
```json
{
  "jobs": [
    {
      "id": "job-001",
      "source": "brilliant",
      "course_id": "intro-to-physics",
      "course_title": "Introduction to Physics",
      "status": "running",
      "progress": 0.65,
      "created_at": "2026-01-16T10:00:00Z"
    },
    {
      "id": "job-002",
      "source": "khan_academy",
      "course_id": "algebra-basics",
      "course_title": "Algebra Basics",
      "status": "completed",
      "progress": 1.0,
      "created_at": "2026-01-15T14:00:00Z",
      "completed_at": "2026-01-15T14:15:00Z"
    }
  ]
}
```

---

### GET /api/import/jobs/{job_id}

Get job details and progress.

**Response (200 OK):**
```json
{
  "id": "job-001",
  "source": "brilliant",
  "course_id": "intro-to-physics",
  "course_title": "Introduction to Physics",
  "status": "running",
  "progress": 0.65,
  "topics_imported": 16,
  "topics_total": 24,
  "current_topic": "Newton's Third Law",
  "steps": [
    {"name": "Fetching metadata", "status": "completed"},
    {"name": "Downloading content", "status": "completed"},
    {"name": "Processing topics", "status": "running", "progress": 0.67},
    {"name": "Generating transcripts", "status": "pending"},
    {"name": "Finalizing", "status": "pending"}
  ],
  "created_at": "2026-01-16T10:00:00Z",
  "estimated_completion": "2026-01-16T10:12:00Z"
}
```

---

### DELETE /api/import/jobs/{job_id}

Cancel an import job.

**Response (200 OK):**
```json
{
  "message": "Import job cancelled",
  "partial_content_saved": true,
  "topics_saved": 16
}
```

---

### GET /api/import/status

Get general import system status.

**Response (200 OK):**
```json
{
  "active_jobs": 2,
  "queued_jobs": 3,
  "completed_today": 5,
  "failed_today": 1,
  "disk_usage_mb": 2500,
  "disk_limit_mb": 10000
}
```

---

## File Import

### POST /api/curricula/import

Import from uploaded file (alternative endpoint).

**Request (multipart/form-data):**
- `file`: UMCF ZIP or JSON file

**Response (201 Created):**
```json
{
  "curriculum_id": "550e8400-e29b-41d4-a716-446655440000",
  "title": "Imported Curriculum",
  "topic_count": 12
}
```

---

## External Sources (Alternative)

### GET /api/sources

Get enabled external sources (simplified).

**Response (200 OK):**
```json
[
  {
    "id": "brilliant",
    "name": "Brilliant.org",
    "enabled": true
  }
]
```

---

### GET /api/sources/{source_id}/courses

Browse source courses.

---

### POST /api/sources/{source_id}/courses/{course_id}/import

Start import (alternative endpoint).

**Response (202 Accepted):**
```json
{
  "job_id": "job-003",
  "status": "pending"
}
```

---

## Client Implementation Notes

### Import Flow

1. Browse sources via `/api/import/sources`
2. Search/browse courses via `/api/import/sources/{id}/courses`
3. Preview course details via `/api/import/sources/{id}/courses/{course_id}`
4. Start import via `/api/import/jobs`
5. Poll progress via `/api/import/jobs/{job_id}`
6. Access imported curriculum via Curricula API

### Progress Polling

- Poll every 2 seconds during active import
- Use exponential backoff if errors occur
- Show step-by-step progress to user

### Error Handling

- Partial imports can be saved
- Retry individual failed topics
- Allow resumption of cancelled jobs

---

## Related Documentation

- [Client Spec: Curriculum Tab](../client-spec/03-CURRICULUM_TAB.md)
- [Curricula API](02-CURRICULA.md) - Managing imported content
