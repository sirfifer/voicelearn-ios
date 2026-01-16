# Authentication API

**Version:** 1.0.0
**Last Updated:** 2026-01-16
**Base URL:** `http://localhost:8766`

---

## Overview

The Authentication API provides user registration, login, token management, and device/session tracking. All authenticated endpoints require a Bearer token obtained from the login endpoint.

---

## Token Lifecycle

### Access Token
- **Validity:** 1 hour
- **Format:** JWT
- **Usage:** Include in `Authorization: Bearer <token>` header

### Refresh Token
- **Validity:** 30 days
- **Format:** Opaque string
- **Usage:** Exchange for new access token via `/api/auth/refresh`

### Token Flow

```
1. User registers or logs in
   └─> Returns access_token + refresh_token

2. Use access_token for API requests
   └─> Include: Authorization: Bearer <access_token>

3. When access_token expires (401 response)
   └─> Call /api/auth/refresh with refresh_token
       └─> Returns new access_token + refresh_token

4. When refresh_token expires
   └─> User must re-authenticate via login
```

---

## Endpoints

### POST /api/auth/register

Create a new user account.

**Authentication:** None required

**Request Body:**
```json
{
  "email": "user@example.com",
  "password": "securepassword123",
  "name": "John Doe"
}
```

**Response (201 Created):**
```json
{
  "id": "550e8400-e29b-41d4-a716-446655440000",
  "email": "user@example.com",
  "name": "John Doe",
  "created_at": "2026-01-16T10:30:00Z",
  "access_token": "eyJhbGciOiJIUzI1NiIs...",
  "refresh_token": "dGhpcyBpcyBhIHJlZnJlc2ggdG9rZW4...",
  "token_type": "Bearer",
  "expires_in": 3600
}
```

**Errors:**
- `400`: Invalid email format or password too short (min 8 chars)
- `409`: Email already registered

---

### POST /api/auth/login

Authenticate user and obtain tokens.

**Authentication:** None required

**Request Body:**
```json
{
  "email": "user@example.com",
  "password": "securepassword123",
  "device_name": "iPhone 15 Pro"
}
```

**Response (200 OK):**
```json
{
  "access_token": "eyJhbGciOiJIUzI1NiIs...",
  "refresh_token": "dGhpcyBpcyBhIHJlZnJlc2ggdG9rZW4...",
  "token_type": "Bearer",
  "expires_in": 3600
}
```

**Errors:**
- `401`: Invalid email or password
- `429`: Too many failed attempts (rate limited)

---

### POST /api/auth/refresh

Exchange refresh token for new access token.

**Authentication:** None required

**Request Body:**
```json
{
  "refresh_token": "dGhpcyBpcyBhIHJlZnJlc2ggdG9rZW4..."
}
```

**Response (200 OK):**
```json
{
  "access_token": "eyJhbGciOiJIUzI1NiIs...",
  "refresh_token": "bmV3IHJlZnJlc2ggdG9rZW4...",
  "token_type": "Bearer",
  "expires_in": 3600
}
```

**Notes:**
- A new refresh token is issued on each refresh
- The old refresh token is invalidated

**Errors:**
- `401`: Invalid or expired refresh token

---

### POST /api/auth/logout

Logout and revoke the current refresh token.

**Authentication:** Required

**Request Body:** None

**Response (200 OK):**
```json
{
  "message": "Logged out successfully"
}
```

---

### GET /api/auth/me

Get the current user's profile.

**Authentication:** Required

**Response (200 OK):**
```json
{
  "id": "550e8400-e29b-41d4-a716-446655440000",
  "email": "user@example.com",
  "name": "John Doe",
  "created_at": "2026-01-16T10:30:00Z",
  "updated_at": "2026-01-16T12:00:00Z"
}
```

---

### PATCH /api/auth/me

Update the current user's profile.

**Authentication:** Required

**Request Body:**
```json
{
  "name": "Jonathan Doe"
}
```

**Response (200 OK):**
```json
{
  "id": "550e8400-e29b-41d4-a716-446655440000",
  "email": "user@example.com",
  "name": "Jonathan Doe",
  "created_at": "2026-01-16T10:30:00Z",
  "updated_at": "2026-01-16T14:00:00Z"
}
```

---

### POST /api/auth/password

Change the current user's password.

**Authentication:** Required

**Request Body:**
```json
{
  "current_password": "securepassword123",
  "new_password": "evenmoresecure456"
}
```

**Response (200 OK):**
```json
{
  "message": "Password changed successfully"
}
```

**Errors:**
- `401`: Current password is incorrect
- `400`: New password too short (min 8 chars)

---

### GET /api/auth/devices

List all devices registered to the current user.

**Authentication:** Required

**Response (200 OK):**
```json
[
  {
    "id": "device-001",
    "name": "iPhone 15 Pro",
    "last_used": "2026-01-16T14:00:00Z",
    "is_current": true
  },
  {
    "id": "device-002",
    "name": "iPad Pro",
    "last_used": "2026-01-15T09:00:00Z",
    "is_current": false
  }
]
```

---

### DELETE /api/auth/devices/{device_id}

Remove a device and revoke its tokens.

**Authentication:** Required

**Parameters:**
- `device_id` (path): Device identifier

**Response (200 OK):**
```json
{
  "message": "Device removed"
}
```

**Errors:**
- `404`: Device not found
- `400`: Cannot remove current device (logout instead)

---

### GET /api/auth/sessions

List all active sessions for the current user.

**Authentication:** Required

**Response (200 OK):**
```json
[
  {
    "id": "session-001",
    "device_name": "iPhone 15 Pro",
    "created_at": "2026-01-16T10:00:00Z",
    "last_used": "2026-01-16T14:00:00Z",
    "is_current": true
  },
  {
    "id": "session-002",
    "device_name": "iPad Pro",
    "created_at": "2026-01-10T08:00:00Z",
    "last_used": "2026-01-15T09:00:00Z",
    "is_current": false
  }
]
```

---

### DELETE /api/auth/sessions/{session_id}

Terminate a specific session.

**Authentication:** Required

**Parameters:**
- `session_id` (path): Session identifier

**Response (200 OK):**
```json
{
  "message": "Session terminated"
}
```

**Errors:**
- `404`: Session not found
- `400`: Cannot terminate current session (logout instead)

---

## Error Responses

All authentication errors follow this format:

```json
{
  "error": "Human-readable error message",
  "code": "ERROR_CODE"
}
```

### Common Error Codes

| Code | HTTP Status | Description |
|------|-------------|-------------|
| `INVALID_CREDENTIALS` | 401 | Email or password incorrect |
| `TOKEN_EXPIRED` | 401 | Access or refresh token expired |
| `TOKEN_INVALID` | 401 | Malformed or tampered token |
| `EMAIL_EXISTS` | 409 | Email already registered |
| `VALIDATION_ERROR` | 400 | Invalid input data |
| `RATE_LIMITED` | 429 | Too many requests |

---

## Client Implementation Notes

### Token Storage

- Store tokens securely (Keychain on iOS, EncryptedSharedPreferences on Android)
- Never store tokens in plain text or UserDefaults
- Clear tokens on logout

### Token Refresh Strategy

1. Check token expiration before requests (JWT `exp` claim)
2. Proactively refresh when < 5 minutes remaining
3. On 401 response, attempt refresh once
4. If refresh fails, redirect to login

### Rate Limiting

- Login: 5 attempts per 15 minutes per IP
- Register: 3 accounts per hour per IP
- Other endpoints: 100 requests per minute

---

## Related Documentation

- [Client Spec: Settings](../client-spec/07-SETTINGS.md) - Provider configuration
- [WebSocket API](08-WEBSOCKET.md) - WebSocket authentication
