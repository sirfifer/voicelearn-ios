# System API

**Version:** 1.0.0
**Last Updated:** 2026-01-16
**Base URL:** `http://localhost:8766`

---

## Overview

The System API provides health checks, metrics, service management, and system monitoring for the UnaMentis server infrastructure.

---

## Health Checks

### GET /health

Basic health check (no authentication required).

**Response (200 OK):**
```json
{
  "status": "healthy",
  "version": "1.0.0",
  "uptime_seconds": 86400,
  "timestamp": "2026-01-16T10:00:00Z"
}
```

**Status Values:**
- `healthy`: All systems operational
- `degraded`: Some services impaired
- `unhealthy`: Critical failures

---

### GET /api/system/metrics

Get detailed system metrics.

**Authentication:** Required

**Response (200 OK):**
```json
{
  "system": {
    "cpu_percent": 25.5,
    "memory_percent": 45.2,
    "memory_used_mb": 2048,
    "memory_total_mb": 4096,
    "disk_percent": 60.0,
    "disk_used_gb": 120,
    "disk_total_gb": 200
  },
  "application": {
    "active_sessions": 5,
    "total_sessions_today": 42,
    "requests_per_minute": 150,
    "average_latency_ms": 85,
    "error_rate": 0.02
  },
  "services": {
    "management_api": {"status": "running", "latency_ms": 5},
    "usm_core": {"status": "running", "latency_ms": 3},
    "web_interface": {"status": "running", "latency_ms": 10}
  }
}
```

---

### GET /api/system/snapshot

Get complete system snapshot.

**Response (200 OK):**
```json
{
  "timestamp": "2026-01-16T10:00:00Z",
  "system": {...},
  "services": [...],
  "recent_errors": [...],
  "performance": {...}
}
```

---

## Service Management

### GET /api/services

List all managed services.

**Response (200 OK):**
```json
[
  {
    "id": "management-api",
    "name": "Management API",
    "status": "running",
    "port": 8766,
    "pid": 12345,
    "uptime_seconds": 86400,
    "memory_mb": 256,
    "cpu_percent": 5.2
  },
  {
    "id": "usm-core",
    "name": "USM Core",
    "status": "running",
    "port": 8787,
    "pid": 12346,
    "uptime_seconds": 86400,
    "memory_mb": 128,
    "cpu_percent": 2.1
  },
  {
    "id": "web-interface",
    "name": "Web Interface",
    "status": "running",
    "port": 3000,
    "pid": 12347,
    "uptime_seconds": 86400,
    "memory_mb": 512,
    "cpu_percent": 3.5
  }
]
```

---

### POST /api/services/{service_id}/start

Start a service.

**Response (200 OK):**
```json
{
  "message": "Service started",
  "service_id": "management-api",
  "pid": 12345
}
```

---

### POST /api/services/{service_id}/stop

Stop a service.

**Response (200 OK):**
```json
{
  "message": "Service stopped",
  "service_id": "management-api"
}
```

---

### POST /api/services/{service_id}/restart

Restart a service.

**Response (200 OK):**
```json
{
  "message": "Service restarted",
  "service_id": "management-api",
  "pid": 12350
}
```

---

### POST /api/services/start-all

Start all services.

**Response (200 OK):**
```json
{
  "message": "All services started",
  "started": ["management-api", "usm-core", "web-interface"]
}
```

---

### POST /api/services/stop-all

Stop all services.

**Response (200 OK):**
```json
{
  "message": "All services stopped",
  "stopped": ["management-api", "usm-core", "web-interface"]
}
```

---

## Model Management

### GET /api/models

List available AI models.

**Response (200 OK):**
```json
[
  {
    "id": "whisper-large-v3",
    "name": "Whisper Large v3",
    "type": "stt",
    "provider": "local",
    "status": "loaded",
    "memory_mb": 1500,
    "parameters": "1.5B"
  },
  {
    "id": "llama-3.2-8b",
    "name": "Llama 3.2 8B",
    "type": "llm",
    "provider": "mlx",
    "status": "unloaded",
    "memory_mb": 4000,
    "parameters": "8B"
  }
]
```

---

### POST /api/models/{model_id}/load

Load a model into memory.

**Response (200 OK):**
```json
{
  "message": "Model loaded",
  "model_id": "whisper-large-v3",
  "load_time_seconds": 5.2,
  "memory_mb": 1500
}
```

---

### POST /api/models/{model_id}/unload

Unload a model from memory.

**Response (200 OK):**
```json
{
  "message": "Model unloaded",
  "model_id": "whisper-large-v3",
  "memory_freed_mb": 1500
}
```

---

### POST /api/models/pull

Download a new model.

**Request Body:**
```json
{
  "model": "llama-3.2-8b",
  "source": "huggingface"
}
```

**Response (202 Accepted):**
```json
{
  "job_id": "pull-001",
  "status": "downloading",
  "progress": 0
}
```

---

### GET /api/models/capabilities

Get model capabilities.

**Response (200 OK):**
```json
{
  "stt": ["whisper-large-v3", "whisper-medium"],
  "llm": ["llama-3.2-8b", "llama-3.2-1b"],
  "tts": ["piper-en-us"],
  "embeddings": ["all-MiniLM-L6-v2"]
}
```

---

## Idle Management

### GET /api/system/idle/status

Get idle status and power state.

**Response (200 OK):**
```json
{
  "state": "active",
  "idle_since": null,
  "active_sessions": 2,
  "last_activity": "2026-01-16T09:58:00Z",
  "power_mode": "performance"
}
```

---

### POST /api/system/idle/config

Configure idle behavior.

**Request Body:**
```json
{
  "idle_timeout_minutes": 30,
  "power_mode_on_idle": "balanced",
  "unload_models_on_idle": true
}
```

---

### POST /api/system/idle/keep-awake

Prevent system from going idle.

**Request Body:**
```json
{
  "duration_minutes": 60,
  "reason": "Pre-generation running"
}
```

---

### POST /api/system/unload-models

Unload all models to free memory.

**Response (200 OK):**
```json
{
  "message": "Models unloaded",
  "memory_freed_mb": 3000
}
```

---

## Diagnostics

### GET /api/system/diagnostic

Get diagnostic configuration.

**Response (200 OK):**
```json
{
  "enabled": true,
  "log_level": "info",
  "metrics_interval_seconds": 60,
  "retain_days": 7
}
```

---

### POST /api/system/diagnostic/toggle

Toggle diagnostic mode.

**Request Body:**
```json
{
  "enabled": true,
  "log_level": "debug"
}
```

---

## Historical Metrics

### GET /api/system/history/hourly

Get hourly metrics for the past 24 hours.

**Response (200 OK):**
```json
{
  "hours": [
    {
      "hour": "2026-01-16T09:00:00Z",
      "cpu_avg": 25.5,
      "memory_avg": 45.2,
      "requests": 1500,
      "errors": 3
    }
  ]
}
```

---

### GET /api/system/history/daily

Get daily metrics for the past 30 days.

---

### GET /api/system/history/summary

Get metrics summary.

**Response (200 OK):**
```json
{
  "today": {
    "sessions": 42,
    "requests": 15000,
    "errors": 12,
    "uptime_percent": 99.9
  },
  "this_week": {...},
  "this_month": {...}
}
```

---

## Logging

### POST /api/logs

Receive logs from clients.

**Request Body:**
```json
{
  "level": "error",
  "message": "Connection timeout",
  "timestamp": "2026-01-16T10:00:00Z",
  "client_name": "iPhone-App",
  "metadata": {
    "session_id": "sess-001",
    "user_id": "user-001"
  }
}
```

---

### GET /api/logs

Retrieve recent logs.

**Query Parameters:**
- `level` (string): Filter by level (debug, info, warn, error)
- `client` (string): Filter by client
- `limit` (integer): Max results
- `since` (datetime): Logs since timestamp

**Response (200 OK):**
```json
{
  "logs": [
    {
      "level": "error",
      "message": "Connection timeout",
      "timestamp": "2026-01-16T10:00:00Z",
      "client_name": "iPhone-App"
    }
  ]
}
```

---

### DELETE /api/logs

Clear logs.

**Response (200 OK):**
```json
{
  "message": "Logs cleared",
  "entries_deleted": 5000
}
```

---

## Clients

### GET /api/clients

Get connected clients.

**Response (200 OK):**
```json
[
  {
    "id": "client-001",
    "name": "iPhone-App",
    "type": "ios",
    "connected_at": "2026-01-16T09:00:00Z",
    "last_heartbeat": "2026-01-16T09:59:30Z",
    "ip_address": "192.168.1.100"
  }
]
```

---

### POST /api/clients/heartbeat

Client heartbeat.

**Request Body:**
```json
{
  "client_id": "client-001",
  "status": "active",
  "session_id": "sess-001"
}
```

---

## Stats

### GET /api/stats

Get aggregated statistics.

**Response (200 OK):**
```json
{
  "total_sessions": 1250,
  "total_turns": 15000,
  "total_audio_hours": 125.5,
  "curricula_count": 15,
  "users_count": 50
}
```

---

## Related Documentation

- [Client Spec: Analytics Tab](../client-spec/06-ANALYTICS_TAB.md)
- [Client Spec: Settings](../client-spec/07-SETTINGS.md)
