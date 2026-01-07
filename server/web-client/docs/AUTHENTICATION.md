# Authentication Guide

This document describes the authentication flow for the UnaMentis Web Client.

---

## Overview

UnaMentis uses JWT-based authentication with refresh token rotation:

- **Access Tokens**: Short-lived JWTs (15 minutes)
- **Refresh Tokens**: Long-lived opaque tokens (30 days)
- **Token Rotation**: New refresh token issued on each refresh
- **Family Tracking**: Detects token reuse attacks

---

## Authentication Flow

### 1. Registration

```
┌──────────┐                    ┌──────────┐
│  Client  │                    │  Server  │
└────┬─────┘                    └────┬─────┘
     │                               │
     │  POST /api/auth/register      │
     │  {email, password, device}    │
     │──────────────────────────────>│
     │                               │
     │  {user, device, tokens}       │
     │<──────────────────────────────│
     │                               │
     │  Store refresh_token          │
     │  (httpOnly cookie or secure)  │
     │                               │
     │  Store access_token           │
     │  (memory only)                │
     │                               │
```

### 2. Login

```
┌──────────┐                    ┌──────────┐
│  Client  │                    │  Server  │
└────┬─────┘                    └────┬─────┘
     │                               │
     │  POST /api/auth/login         │
     │  {email, password, device}    │
     │──────────────────────────────>│
     │                               │
     │  {user, device, tokens}       │
     │<──────────────────────────────│
     │                               │
```

### 3. API Request with Token

```
┌──────────┐                    ┌──────────┐
│  Client  │                    │  Server  │
└────┬─────┘                    └────┬─────┘
     │                               │
     │  GET /api/protected           │
     │  Authorization: Bearer {jwt}  │
     │──────────────────────────────>│
     │                               │
     │  Verify JWT signature         │
     │  Check expiration             │
     │  Extract user_id              │
     │                               │
     │  {data}                       │
     │<──────────────────────────────│
     │                               │
```

### 4. Token Refresh

```
┌──────────┐                    ┌──────────┐
│  Client  │                    │  Server  │
└────┬─────┘                    └────┬─────┘
     │                               │
     │  Access token expired         │
     │  (or expiring soon)           │
     │                               │
     │  POST /api/auth/refresh       │
     │  {refresh_token}              │
     │──────────────────────────────>│
     │                               │
     │  Validate refresh token       │
     │  Check family lineage         │
     │  Generate new token pair      │
     │  Invalidate old refresh       │
     │                               │
     │  {tokens}                     │
     │<──────────────────────────────│
     │                               │
     │  Update stored tokens         │
     │                               │
```

### 5. Logout

```
┌──────────┐                    ┌──────────┐
│  Client  │                    │  Server  │
└────┬─────┘                    └────┬─────┘
     │                               │
     │  POST /api/auth/logout        │
     │  {refresh_token}              │
     │──────────────────────────────>│
     │                               │
     │  Revoke refresh token         │
     │  (and optionally all tokens)  │
     │                               │
     │  {message}                    │
     │<──────────────────────────────│
     │                               │
     │  Clear stored tokens          │
     │                               │
```

---

## Token Storage

### Refresh Token (Most Secure Options)

1. **httpOnly Cookie** (Recommended for web)
   - Set by server with `Set-Cookie: refresh_token=...; HttpOnly; Secure; SameSite=Strict`
   - Automatically sent with requests via `credentials: 'include'`
   - Not accessible to JavaScript (XSS protection)

2. **Secure Storage API** (if available)
   - Use Web Crypto API for encryption
   - Store encrypted token in localStorage

### Access Token

- **Memory only** (JavaScript variable)
- Never in localStorage or sessionStorage
- Lost on page refresh (use refresh token to restore)

### Implementation Example

```typescript
class TokenManager {
  private accessToken: string | null = null;
  private expiresAt: number = 0;

  // Set tokens after login/refresh
  setTokens(tokens: AuthTokens) {
    this.accessToken = tokens.access_token;
    this.expiresAt = Date.now() + tokens.expires_in * 1000;

    // Refresh token is set via httpOnly cookie by server
    // or stored securely here if using API directly
  }

  // Get valid token, refreshing if needed
  async getValidToken(): Promise<string | null> {
    if (!this.accessToken) return null;

    // Refresh 1 minute before expiry
    if (Date.now() > this.expiresAt - 60000) {
      await this.refresh();
    }

    return this.accessToken;
  }

  private async refresh(): Promise<void> {
    const response = await fetch('/api/auth/refresh', {
      method: 'POST',
      credentials: 'include', // Send httpOnly cookies
    });

    if (!response.ok) {
      this.clear();
      throw new Error('Session expired');
    }

    const { tokens } = await response.json();
    this.setTokens(tokens);
  }

  clear() {
    this.accessToken = null;
    this.expiresAt = 0;
  }
}
```

---

## Device Registration

Every client must register a device on login:

```typescript
interface Device {
  fingerprint: string;  // Unique device identifier
  name: string;         // Human-readable name
  type: 'web';          // Device type
  model: string;        // Browser name
  os_version: string;   // Browser version
  app_version: string;  // App version
}
```

### Fingerprint Generation

```typescript
async function generateFingerprint(): Promise<string> {
  const components = [
    navigator.userAgent,
    navigator.language,
    screen.width,
    screen.height,
    new Date().getTimezoneOffset(),
    navigator.hardwareConcurrency,
  ];

  const data = components.join('|');
  const encoder = new TextEncoder();
  const hash = await crypto.subtle.digest('SHA-256', encoder.encode(data));

  return Array.from(new Uint8Array(hash))
    .map(b => b.toString(16).padStart(2, '0'))
    .join('');
}
```

---

## Token Family and Reuse Detection

The server tracks token "families" to detect replay attacks:

1. Each login creates a new token family
2. Each refresh creates a new token in the same family
3. If an old refresh token is reused, the entire family is revoked
4. This protects against stolen refresh tokens

### Attack Scenario

```
Attacker steals refresh_token_v1

Legitimate user refreshes:
  refresh_token_v1 → refresh_token_v2

Attacker tries to use stolen token:
  refresh_token_v1 → REJECTED (token reuse detected)

Server revokes entire family:
  refresh_token_v1 ✗
  refresh_token_v2 ✗

Both attacker and user must re-authenticate
```

---

## JWT Structure

Access tokens are JWTs with the following claims:

```json
{
  "sub": "user-uuid",
  "email": "user@example.com",
  "role": "user",
  "device_id": "device-uuid",
  "iat": 1705328400,
  "exp": 1705329300
}
```

### Verification

The server verifies:
1. Signature (HMAC-SHA256 with server secret)
2. Expiration (`exp` claim)
3. Issued-at (`iat` claim)
4. User exists and is active

---

## Error Handling

### Common Auth Errors

| Error Code | HTTP Status | Meaning | Action |
|------------|-------------|---------|--------|
| `invalid_credentials` | 401 | Wrong email/password | Show error, allow retry |
| `account_inactive` | 401 | Account disabled | Contact support |
| `account_locked` | 401 | Too many failures | Wait and retry |
| `token_expired` | 401 | Access token expired | Refresh token |
| `invalid_token` | 401 | Token not valid | Re-authenticate |
| `token_reused` | 401 | Refresh token reused | Re-authenticate |

### Error Handling Flow

```typescript
async function handleAuthError(error: ApiError): Promise<void> {
  switch (error.code) {
    case 'token_expired':
    case 'invalid_token':
    case 'token_reused':
      // Clear tokens and redirect to login
      tokenManager.clear();
      router.push('/login');
      break;

    case 'account_locked':
      // Show lockout message
      showError('Account locked. Try again later.');
      break;

    default:
      // Generic error handling
      showError(error.message);
  }
}
```

---

## Security Best Practices

### Client-Side

1. **Never store access tokens in localStorage**
   - Vulnerable to XSS attacks
   - Use memory-only storage

2. **Use httpOnly cookies for refresh tokens**
   - Cannot be accessed by JavaScript
   - Automatic CSRF protection with SameSite

3. **Implement CSRF protection**
   - Use `SameSite=Strict` cookies
   - Or implement CSRF tokens

4. **Validate redirect URLs**
   - Prevent open redirect attacks
   - Only allow known origins

### API Calls

1. **Always use HTTPS**
   - Tokens must never travel over HTTP

2. **Set appropriate headers**
   ```typescript
   fetch('/api/protected', {
     headers: {
       'Authorization': `Bearer ${accessToken}`,
       'Content-Type': 'application/json',
     },
     credentials: 'include', // For cookies
   });
   ```

3. **Handle token refresh atomically**
   - Deduplicate concurrent refresh requests
   - Queue API calls during refresh

---

## Session Management

### Check Auth State

```typescript
function useAuthState() {
  const [isAuthenticated, setIsAuthenticated] = useState(false);
  const [isLoading, setIsLoading] = useState(true);

  useEffect(() => {
    async function checkAuth() {
      try {
        const token = await tokenManager.getValidToken();
        setIsAuthenticated(!!token);
      } catch {
        setIsAuthenticated(false);
      } finally {
        setIsLoading(false);
      }
    }
    checkAuth();
  }, []);

  return { isAuthenticated, isLoading };
}
```

### Protected Routes

```typescript
function ProtectedRoute({ children }: { children: React.ReactNode }) {
  const { isAuthenticated, isLoading } = useAuthState();
  const router = useRouter();

  useEffect(() => {
    if (!isLoading && !isAuthenticated) {
      router.push('/login');
    }
  }, [isAuthenticated, isLoading]);

  if (isLoading) return <Loading />;
  if (!isAuthenticated) return null;

  return <>{children}</>;
}
```

---

## Rate Limiting

Authentication endpoints have strict rate limits:

| Endpoint | Limit | Window |
|----------|-------|--------|
| `/api/auth/login` | 5 | 60 seconds |
| `/api/auth/register` | 3 | 1 hour |
| `/api/auth/refresh` | 60 | 60 seconds |

### Handling Rate Limits

```typescript
async function loginWithRetry(email: string, password: string) {
  try {
    return await login(email, password);
  } catch (error) {
    if (error.status === 429) {
      const retryAfter = error.headers.get('Retry-After');
      throw new Error(`Too many attempts. Try again in ${retryAfter} seconds.`);
    }
    throw error;
  }
}
```

---

*End of Authentication Guide*
