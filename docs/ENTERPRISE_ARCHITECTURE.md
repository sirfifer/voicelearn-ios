# UnaMentis Enterprise Architecture Guide

> **Purpose**: This document defines architectural patterns and decisions that ensure UnaMentis remains compatible with enterprise features. All development—iOS, web, and backend—should follow these guidelines to prevent architectural debt.

> **Last Updated**: December 2024
> **Status**: Living Document

---

## Table of Contents

1. [Executive Summary](#1-executive-summary)
2. [Identity & Authentication](#2-identity--authentication)
3. [Authorization & RBAC](#3-authorization--rbac)
4. [Data Privacy & Security](#4-data-privacy--security)
5. [Multi-Tenancy Architecture](#5-multi-tenancy-architecture)
6. [Deployment Models](#6-deployment-models)
7. [Audit & Compliance](#7-audit--compliance)
8. [Current Codebase Compatibility](#8-current-codebase-compatibility)
9. [Implementation Guidelines](#9-implementation-guidelines)
10. [Open Source Stack Recommendations](#10-open-source-stack-recommendations)
11. [Phased Implementation Roadmap](#11-phased-implementation-roadmap)

---

## 1. Executive Summary

### 1.1 Vision

UnaMentis will evolve from a single-user iOS application to an enterprise-ready platform supporting educational institutions, government agencies, and enterprises. This requires:

- **Single Sign-On (SSO)** with existing identity providers
- **Role-Based Access Control (RBAC)** at granular levels
- **Multi-Factor Authentication (MFA)** for sensitive operations
- **Data privacy controls** including encryption and minimization
- **Multi-tenancy** with complete data isolation
- **On-premise deployment** for data sovereignty requirements

### 1.2 Core Principles

| Principle | Description |
|-----------|-------------|
| **Authentication Agnostic** | Services accept standardized tokens; authentication mechanism is external and swappable |
| **Authorization Everywhere** | Every API endpoint and data access path enforces permission checks |
| **Tenant Context Always** | Tenant ID flows through every request, from client to database |
| **Encrypt by Default** | Data encrypted at rest and in transit, always |
| **Audit Everything** | Every state-changing operation produces an audit event |
| **JIT Security** | Prefer ephemeral permissions over standing privileges |
| **Privacy by Design** | Minimize data collection; make privacy the default |
| **Avoid Data When Possible** | The best protection for sensitive data is not having it |

### 1.3 Deployment Models Supported

```
┌─────────────────────────────────────────────────────────────────────┐
│                     Deployment Model Spectrum                        │
├─────────────────┬─────────────────┬─────────────────┬───────────────┤
│  SaaS Multi-    │  SaaS Dedicated │    Hybrid       │  On-Premise   │
│  Tenant         │                 │                 │               │
├─────────────────┼─────────────────┼─────────────────┼───────────────┤
│ Shared infra,   │ Isolated infra  │ On-prem data,   │ Customer-run  │
│ logical tenant  │ per customer    │ cloud compute   │ everything    │
│ isolation       │                 │ burst           │               │
├─────────────────┼─────────────────┼─────────────────┼───────────────┤
│ Schools, small  │ Enterprise with │ Large orgs,     │ Regulated     │
│ organizations   │ isolation needs │ data residency  │ industries    │
└─────────────────┴─────────────────┴─────────────────┴───────────────┘
```

### 1.4 Technology Stack Summary

| Layer | Technology | Rationale |
|-------|------------|-----------|
| **iOS App** | Swift 6, SwiftUI, Core Data | Native performance, existing codebase |
| **Web Frontend** | Next.js 15, React 19, TypeScript | Existing codebase, SSR, API routes |
| **Backend** | Python, FastAPI, SQLAlchemy 2.0 | AI-native ecosystem, async support |
| **Database** | PostgreSQL with RLS | Enterprise-grade, row-level security |
| **Identity** | Keycloak | Full OIDC + SAML2, identity brokering |
| **Authorization** | Open Policy Agent (OPA) | Declarative policies, cloud-native |
| **Observability** | OpenTelemetry + Grafana stack | Vendor-neutral, comprehensive |

---

## 2. Identity & Authentication

### 2.1 SSO Architecture Overview

UnaMentis supports BOTH OIDC/OAuth2 AND SAML2 through an identity broker pattern that normalizes different identity providers into a standard internal token format.

```
┌──────────────────┐     ┌──────────────────┐     ┌──────────────────┐
│   Enterprise     │     │   Identity       │     │   UnaMentis     │
│   IdP            │────▶│   Broker         │────▶│   Services       │
│   (Okta, Azure,  │     │   (Keycloak)     │     │                  │
│    Google, etc.) │     │                  │     │                  │
└──────────────────┘     └──────────────────┘     └──────────────────┘
        │                        │                        │
        │   SAML2 or OIDC       │   Internal JWT         │
        │◀─────────────────────▶│◀──────────────────────▶│
```

**Why an Identity Broker?**
- Normalizes claims from disparate IdPs into consistent format
- Single point for session management and token lifecycle
- Enables IdP switching without application changes
- Provides MFA enforcement layer

### 2.2 Supported Protocols

#### OIDC/OAuth2 (Primary)

**Supported Flows:**
| Flow | Use Case | Security Level |
|------|----------|----------------|
| Authorization Code + PKCE | iOS app, web app | Highest |
| Client Credentials | Service-to-service | High |
| Device Authorization | TV/embedded devices | Medium |

**Required Claims in ID Token:**
```json
{
  "iss": "https://auth.voicelearn.com/realms/main",
  "sub": "user-uuid-here",
  "aud": "voicelearn-client",
  "exp": 1704067200,
  "iat": 1704063600,
  "email": "user@example.com",
  "name": "Display Name",
  "preferred_username": "username",
  "tenant_id": "tenant-uuid",
  "org_id": "org-uuid",
  "roles": ["learner", "instructor"],
  "groups": ["math-101", "physics-201"],
  "permissions": ["curriculum:read:assigned", "session:create:own"]
}
```

#### SAML2 (Enterprise)

**Required Attributes:**
| Attribute | Description | Required |
|-----------|-------------|----------|
| `NameID` | Unique user identifier | Yes |
| `email` | User email | Yes |
| `displayName` | Full name | Yes |
| `memberOf` | Group membership | No |
| `tenantId` | Customer attribute | Yes |

**Security Requirements:**
- Signed assertions (RSA-SHA256 minimum)
- Encrypted assertions for production
- Single Logout (SLO) support
- Assertion validity window ≤ 5 minutes

### 2.3 MFA Integration

MFA is enforced at the identity provider level. UnaMentis must:

1. **Verify MFA Status**: Check `amr` (Authentication Methods References) claim
2. **Require Step-Up**: Request re-authentication for sensitive operations
3. **Support Bypass Policies**: Allow tenant admins to configure requirements

**amr Claim Values:**
```json
{
  "amr": ["pwd", "otp"]      // Password + TOTP verified
  "amr": ["pwd", "hwk"]      // Password + Hardware key (FIDO2)
  "amr": ["pwd", "swk"]      // Password + Software key
  "amr": ["pwd", "sms"]      // Password + SMS (discouraged)
}
```

**Step-Up Authentication Triggers:**
- Accessing curriculum management
- Changing user permissions or roles
- Exporting learning data or transcripts
- API key generation or revocation
- Tenant configuration changes

### 2.4 Token Management

#### Token Types and Lifetimes

| Token | Lifetime | Storage (iOS) | Storage (Web) | Use |
|-------|----------|---------------|---------------|-----|
| Access Token | 15 min | Memory only | Memory/httpOnly cookie | API requests |
| Refresh Token | 7 days | Keychain (encrypted) | httpOnly cookie | Token renewal |
| ID Token | 1 hour | Memory only | Memory | User info display |

#### Token Refresh Pattern

```
┌─────────────────────────────────────────────────────────────────────┐
│                     Token Refresh Timeline                           │
├─────────────────────────────────────────────────────────────────────┤
│                                                                     │
│  Token Issued        Refresh Window        Token Expires            │
│       │                   │                     │                   │
│       ▼                   ▼                     ▼                   │
│  ─────●───────────────────[========]────────────●─────────────────▶ │
│       │                   │        │            │                   │
│       │◀─── 80% life ────▶│        │            │                   │
│       │                   │◀─ 20% ▶│            │                   │
│       │                   │  jitter│            │                   │
│                                                                     │
│  Refresh proactively during the window to avoid expired token       │
│  requests. Add random jitter to prevent thundering herd.            │
└─────────────────────────────────────────────────────────────────────┘
```

**iOS Implementation Pattern:**
```swift
// Pattern: Proactive token refresh with jitter
actor TokenManager {
    private var accessToken: String?
    private var refreshToken: String?
    private var expiresAt: Date?
    private var refreshTask: Task<Void, Never>?

    func scheduleRefresh() {
        guard let expiresAt = expiresAt else { return }

        let lifetime = expiresAt.timeIntervalSinceNow
        let refreshAt = lifetime * 0.8  // Refresh at 80% of lifetime
        let jitter = Double.random(in: 0...(lifetime * 0.1))  // 10% jitter

        refreshTask = Task {
            try? await Task.sleep(for: .seconds(refreshAt + jitter))
            await performRefresh()
        }
    }

    private func performRefresh() async {
        // Refresh implementation
    }
}
```

**Python/FastAPI Pattern:**
```python
from datetime import datetime, timedelta
from jose import jwt, JWTError
from fastapi import Depends, HTTPException, status
from fastapi.security import OAuth2PasswordBearer

oauth2_scheme = OAuth2PasswordBearer(tokenUrl="token")

async def get_current_user(token: str = Depends(oauth2_scheme)) -> User:
    """Validate JWT and extract user context."""
    try:
        payload = jwt.decode(
            token,
            settings.jwt_public_key,
            algorithms=["RS256"],
            audience="voicelearn-api"
        )

        # Check expiration with clock skew tolerance
        exp = datetime.fromtimestamp(payload["exp"])
        if datetime.utcnow() > exp + timedelta(seconds=30):
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Token expired"
            )

        return User(
            id=payload["sub"],
            tenant_id=payload["tenant_id"],
            roles=payload.get("roles", []),
            permissions=payload.get("permissions", [])
        )

    except JWTError:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid token"
        )
```

### 2.5 Session Invalidation

All sessions must be invalidatable through multiple triggers:

| Trigger | Action | Scope |
|---------|--------|-------|
| User logout | Revoke refresh token | Single session |
| Password change | Revoke all tokens | All user sessions |
| Admin force logout | Revoke all tokens | Target user |
| Suspicious activity | Revoke + require MFA | Target user |
| Account disable | Revoke all tokens | All user sessions |

### 2.6 Recommended OSS: Identity

| Component | **Keycloak** (Primary) | Authentik (Alternative) |
|-----------|------------------------|-------------------------|
| License | Apache 2.0 | SSPL |
| Protocols | OIDC, SAML2, LDAP | OIDC, SAML2, LDAP |
| IdP Brokering | Extensive | Good |
| Enterprise IdPs | Okta, Azure AD, Google, ADFS | Most major IdPs |
| Clustering | Yes (Infinispan) | Yes (Redis) |
| Admin UI | Full-featured | Modern, simpler |
| Resource Usage | Higher (Java) | Lower (Python) |
| **Best For** | Full enterprise needs | Smaller deployments |

**Keycloak Deployment:**
```yaml
# docker-compose.yml excerpt
services:
  keycloak:
    image: quay.io/keycloak/keycloak:23.0
    command: start-dev  # Use 'start' for production
    environment:
      KC_DB: postgres
      KC_DB_URL: jdbc:postgresql://db:5432/keycloak
      KC_DB_USERNAME: keycloak
      KC_DB_PASSWORD: ${KC_DB_PASSWORD}
      KC_HOSTNAME: auth.voicelearn.com
      KC_FEATURES: token-exchange,admin-fine-grained-authz
    ports:
      - "8080:8080"
```

---

## 3. Authorization & RBAC

### 3.1 Permission Model

UnaMentis uses a **Resource:Action:Scope** permission model supporting fine-grained access control.

```
┌─────────────────────────────────────────────────────────────────────┐
│                     Permission Structure                             │
├─────────────────────────────────────────────────────────────────────┤
│                                                                     │
│    <resource>:<action>:<scope>                                      │
│                                                                     │
│    Examples:                                                        │
│    ─────────────────────────────────────────────────────────────    │
│    curriculum:read:own        Read own curricula                    │
│    curriculum:read:group      Read curricula shared in group        │
│    curriculum:write:tenant    Write any curriculum in tenant        │
│    session:create:own         Create sessions for self              │
│    analytics:export:org       Export org-wide analytics             │
│    users:manage:tenant        Manage all users in tenant            │
│                                                                     │
└─────────────────────────────────────────────────────────────────────┘
```

#### Resources

| Resource | Description | Available Actions |
|----------|-------------|-------------------|
| `curriculum` | Learning content | create, read, update, delete, publish, assign |
| `topic` | Individual topics | create, read, update, delete |
| `session` | Voice tutoring sessions | create, read, delete, export |
| `transcript` | Session transcripts | read, export, delete |
| `analytics` | Learning analytics | read, export |
| `users` | User management | read, create, update, delete, invite |
| `groups` | Groups/classes | read, create, update, delete, assign |
| `roles` | Role management | read, assign, create |
| `tenant` | Tenant config | read, configure |
| `api_keys` | API key management | create, list, revoke |

#### Scopes

| Scope | Description | Typical Use |
|-------|-------------|-------------|
| `own` | Resources owned by user | Learners |
| `assigned` | Resources assigned to user | Learners |
| `group` | Resources in user's groups | Instructors |
| `org_unit` | Resources in org unit | Dept heads |
| `org` | Resources in organization | Org admins |
| `tenant` | All resources in tenant | Tenant admins |
| `platform` | Cross-tenant (rare) | Platform ops |

### 3.2 Role Hierarchy

```
┌─────────────────────────────────────────────────────────────────────┐
│                        Role Hierarchy                                │
├─────────────────────────────────────────────────────────────────────┤
│                                                                     │
│                    ┌──────────────────┐                             │
│                    │  Platform Admin  │  ◀── SaaS operator only     │
│                    └────────┬─────────┘                             │
│                             │                                       │
│                    ┌────────┴─────────┐                             │
│                    │   Tenant Admin   │  ◀── Customer administrator │
│                    └────────┬─────────┘                             │
│                             │                                       │
│         ┌───────────────────┼───────────────────┐                   │
│         │                   │                   │                   │
│  ┌──────┴──────┐    ┌───────┴───────┐   ┌──────┴──────┐            │
│  │Content Admin│    │ Group Manager │   │  Analyst    │            │
│  └──────┬──────┘    └───────┬───────┘   └─────────────┘            │
│         │                   │                                       │
│         └─────────┬─────────┘                                       │
│                   │                                                 │
│          ┌────────┴────────┐                                        │
│          │   Instructor    │                                        │
│          └────────┬────────┘                                        │
│                   │                                                 │
│          ┌────────┴────────┐                                        │
│          │     Learner     │  ◀── Default role                      │
│          └─────────────────┘                                        │
│                                                                     │
└─────────────────────────────────────────────────────────────────────┘
```

#### Default Role Permissions

**Learner:**
```json
{
  "role": "learner",
  "permissions": [
    "curriculum:read:assigned",
    "topic:read:assigned",
    "session:create:own",
    "session:read:own",
    "transcript:read:own",
    "analytics:read:own"
  ]
}
```

**Instructor:**
```json
{
  "role": "instructor",
  "inherits": ["learner"],
  "permissions": [
    "curriculum:read:group",
    "curriculum:create:own",
    "topic:create:own",
    "topic:update:own",
    "session:read:group",
    "transcript:read:group",
    "analytics:read:group",
    "users:read:group",
    "groups:read:own"
  ]
}
```

**Tenant Admin:**
```json
{
  "role": "tenant_admin",
  "permissions": [
    "curriculum:*:tenant",
    "topic:*:tenant",
    "session:*:tenant",
    "transcript:*:tenant",
    "analytics:*:tenant",
    "users:*:tenant",
    "groups:*:tenant",
    "roles:assign:tenant",
    "tenant:configure:own",
    "api_keys:*:tenant"
  ]
}
```

### 3.3 Just-In-Time (JIT) Security

For elevated operations, implement time-limited permission grants rather than standing privileges.

```
┌─────────────────────────────────────────────────────────────────────┐
│                     JIT Access Flow                                  │
├─────────────────────────────────────────────────────────────────────┤
│                                                                     │
│  1. User requests elevated permission                               │
│     ┌──────────────────────────────────────────────────────────┐   │
│     │ POST /api/jit/request                                     │   │
│     │ {                                                         │   │
│     │   "permissions": ["users:delete:tenant"],                 │   │
│     │   "justification": "Removing inactive accounts per...",   │   │
│     │   "duration": "4h"                                        │   │
│     │ }                                                         │   │
│     └──────────────────────────────────────────────────────────┘   │
│                                │                                    │
│  2. Approval flow (if required)│                                    │
│                                ▼                                    │
│     ┌──────────────────────────────────────────────────────────┐   │
│     │ Approver reviews in admin console                         │   │
│     │ - Sees justification                                      │   │
│     │ - Reviews requested permissions                           │   │
│     │ - Approves/Denies with optional time reduction            │   │
│     └──────────────────────────────────────────────────────────┘   │
│                                │                                    │
│  3. Grant issued               ▼                                    │
│     ┌──────────────────────────────────────────────────────────┐   │
│     │ {                                                         │   │
│     │   "grant_id": "jit-uuid",                                 │   │
│     │   "permissions": ["users:delete:tenant"],                 │   │
│     │   "expires_at": "2024-01-15T14:30:00Z",                  │   │
│     │   "approved_by": "admin-uuid"                             │   │
│     │ }                                                         │   │
│     └──────────────────────────────────────────────────────────┘   │
│                                                                     │
│  4. Permission evaluated at request time                            │
│     - Check standard permissions first                              │
│     - If denied, check active JIT grants                            │
│     - All JIT access is audit-logged                                │
│                                                                     │
└─────────────────────────────────────────────────────────────────────┘
```

**JIT Use Cases:**
- Temporary admin access for troubleshooting
- Time-limited data export permissions
- Cross-tenant access for support staff
- Elevated access during security incidents

### 3.4 Policy Enforcement Points

#### iOS Client (UI Gating)

```swift
// Pattern: Permission-aware view modifier
struct RequiresPermission: ViewModifier {
    let permission: String
    @EnvironmentObject var authContext: AuthContext

    func body(content: Content) -> some View {
        if authContext.hasPermission(permission) {
            content
        } else {
            EmptyView()  // Or disabled state
        }
    }
}

extension View {
    func requiresPermission(_ permission: String) -> some View {
        modifier(RequiresPermission(permission: permission))
    }
}

// Usage
Button("Delete Curriculum") {
    // action
}
.requiresPermission("curriculum:delete:own")
```

#### Backend (FastAPI Middleware)

```python
from functools import wraps
from fastapi import HTTPException, status

def requires_permission(permission: str):
    """Decorator for permission-protected endpoints."""
    def decorator(func):
        @wraps(func)
        async def wrapper(*args, user: User = Depends(get_current_user), **kwargs):
            if not await check_permission(user, permission, kwargs):
                raise HTTPException(
                    status_code=status.HTTP_403_FORBIDDEN,
                    detail=f"Permission denied: {permission}"
                )
            return await func(*args, user=user, **kwargs)
        return wrapper
    return decorator

# Usage
@router.delete("/curricula/{curriculum_id}")
@requires_permission("curriculum:delete:own")
async def delete_curriculum(
    curriculum_id: UUID,
    user: User = Depends(get_current_user)
):
    # Implementation
    pass
```

### 3.5 Recommended OSS: Authorization

| Component | **OPA** (Primary) | Casbin (Alternative) |
|-----------|-------------------|----------------------|
| Policy Language | Rego (declarative) | PERM model (config) |
| Deployment | Sidecar or library | Embedded library |
| Performance | Sub-millisecond | Sub-millisecond |
| Complexity | Higher learning curve | Simpler model |
| Flexibility | Very high | Good for RBAC |
| **Best For** | Complex policies, cloud-native | Simple RBAC |

**OPA Policy Example (Rego):**
```rego
package voicelearn.authz

import future.keywords.if
import future.keywords.in

default allow := false

# Allow users to read their own sessions
allow if {
    input.action == "read"
    input.resource.type == "session"
    input.resource.owner_id == input.user.id
}

# Allow instructors to read sessions in their groups
allow if {
    input.action == "read"
    input.resource.type == "session"
    "instructor" in input.user.roles
    input.resource.group_id in input.user.groups
}

# Allow tenant admins full access within tenant
allow if {
    "tenant_admin" in input.user.roles
    input.resource.tenant_id == input.user.tenant_id
}

# Check JIT grants
allow if {
    some grant in data.jit_grants[input.user.id]
    permission_matches(grant, input)
    time.now_ns() < grant.expires_at_ns
}

permission_matches(grant, input) if {
    grant.resource == input.resource.type
    grant.action == input.action
}
```

---

## 4. Data Privacy & Security

### 4.1 Data Classification

| Level | Label | Examples | Handling |
|-------|-------|----------|----------|
| 1 | **Restricted** | Voice recordings, biometrics | Encrypted, access-logged, short retention |
| 2 | **Confidential** | Transcripts, learning scores | Encrypted, role-restricted |
| 3 | **Internal** | Curriculum content, configs | Access-controlled |
| 4 | **Public** | Published titles, public profiles | No special handling |

### 4.2 Encryption Strategy

#### At Rest

```
┌─────────────────────────────────────────────────────────────────────┐
│                     Encryption Key Hierarchy                         │
├─────────────────────────────────────────────────────────────────────┤
│                                                                     │
│              ┌────────────────────────────────────┐                 │
│              │       Master Key (KEK)             │                 │
│              │   (HSM / Cloud KMS managed)        │                 │
│              └─────────────────┬──────────────────┘                 │
│                                │                                    │
│              ┌─────────────────┼─────────────────┐                  │
│              │                 │                 │                  │
│       ┌──────┴──────┐   ┌──────┴──────┐   ┌──────┴──────┐          │
│       │ Tenant Key  │   │ Tenant Key  │   │ Tenant Key  │          │
│       │   (DEK 1)   │   │   (DEK 2)   │   │   (DEK 3)   │          │
│       └──────┬──────┘   └─────────────┘   └─────────────┘          │
│              │                                                      │
│       ┌──────┴──────┐                                              │
│       │ Field Keys  │  ◀── For column-level encryption             │
│       └─────────────┘                                              │
│                                                                     │
│   Benefits:                                                         │
│   - Tenant isolation (one tenant compromised ≠ all compromised)    │
│   - Key rotation per tenant                                         │
│   - Compliance with data residency (keys can be regional)          │
│                                                                     │
└─────────────────────────────────────────────────────────────────────┘
```

| Layer | Method | Key Management |
|-------|--------|----------------|
| Storage | AES-256-XTS (filesystem) | Cloud KMS / HSM |
| Database | TDE (PostgreSQL) | Database-managed |
| Column | Application encryption | Vault / per-tenant keys |
| Field | Client-side encryption | Per-tenant keys |

**Fields Requiring Column-Level Encryption:**
- `transcript.content` - User speech transcripts
- `session.audio_url` - Voice recording references
- `user.email` - PII (if stored beyond IdP)
- `analytics.raw_data` - Detailed learning patterns

#### In Transit

| Connection | Protocol | Minimum |
|------------|----------|---------|
| Client ↔ API | TLS | 1.3 |
| Service ↔ Service | mTLS | 1.3 |
| API ↔ Database | TLS | 1.2 |

**Certificate Requirements:**
- RSA 2048-bit minimum or P-256 ECDSA
- OCSP stapling enabled
- Rotation every 90 days
- Certificate pinning in iOS for production

### 4.3 Data Minimization

**Principles:**
1. **Collect only what's necessary** for the specific feature
2. **Anonymize** analytics data where individual identity isn't required
3. **Aggregate** rather than store individual data points when possible
4. **Short retention** with automatic deletion
5. **Default to minimal** - opt-in to more data collection

**Voice Data Handling:**
```
┌─────────────────────────────────────────────────────────────────────┐
│                     Voice Data Lifecycle                             │
├─────────────────────────────────────────────────────────────────────┤
│                                                                     │
│  ┌──────────┐    ┌──────────┐    ┌──────────┐    ┌──────────┐     │
│  │  Audio   │───▶│   STT    │───▶│Transcript│───▶│ Summary  │     │
│  │ Capture  │    │ Process  │    │  Store   │    │   Only   │     │
│  └──────────┘    └──────────┘    └──────────┘    └──────────┘     │
│       │                                │              │            │
│       │                                │              │            │
│       ▼                                ▼              ▼            │
│  ┌──────────┐                    ┌──────────┐   ┌──────────┐      │
│  │  DELETE  │                    │  Encrypt │   │  Retain  │      │
│  │ immediate│                    │  at rest │   │ long-term│      │
│  │ after STT│                    │ 30 days  │   │          │      │
│  └──────────┘                    └──────────┘   └──────────┘      │
│                                                                     │
│  Default: Audio deleted immediately after transcription             │
│  Optional: Encrypted audio retention for quality improvement        │
│           (requires explicit consent)                               │
│                                                                     │
└─────────────────────────────────────────────────────────────────────┘
```

### 4.4 PII Handling

#### PII Inventory

| Field | Classification | Storage | Retention | Encryption |
|-------|---------------|---------|-----------|------------|
| Email | PII | Database | Account lifetime | Column |
| Display Name | PII | Database | Account lifetime | No |
| Voice Audio | Biometric | Temp storage | Session or 30 days | Field |
| Transcripts | PII | Database | Per policy | Column |
| Learning History | PII | Database | Per policy | Column |
| IP Address | PII | Logs only | 90 days | No (hashed) |
| Device ID | Identifier | Database | Account lifetime | No |

#### Pseudonymization for Analytics

```python
import hmac
import hashlib
from base64 import urlsafe_b64encode

class Pseudonymizer:
    """Consistent pseudonymization for analytics export."""

    def __init__(self, tenant_key: bytes):
        self.key = tenant_key

    def pseudonymize(self, pii: str) -> str:
        """Generate consistent pseudonym for PII value."""
        mac = hmac.new(self.key, pii.encode(), hashlib.sha256)
        return urlsafe_b64encode(mac.digest()[:16]).decode()

    # Usage: Cross-session analytics without exposing identity
    # pseudonymizer.pseudonymize("user@example.com")
    # → "dGhpcyBpcyBhIHRlc3Q"  (consistent across calls)
```

### 4.5 Compliance Considerations

#### GDPR Requirements

| Requirement | Implementation |
|-------------|----------------|
| Right to Access | `/api/users/{id}/data-export` endpoint |
| Right to Erasure | `/api/users/{id}/delete` with cascade |
| Data Portability | JSON/CSV export in standard format |
| Consent Management | Explicit consent tracking per purpose |
| Processing Records | Audit log with retention |

#### HIPAA Considerations (Healthcare Education)

| Requirement | Implementation |
|-------------|----------------|
| Access Controls | RBAC with audit |
| Audit Logs | Immutable, 6-year retention |
| Encryption | At rest and in transit |
| BAA Support | Template and signing process |
| Minimum Necessary | Role-based data visibility |

### 4.6 Recommended OSS: Secrets

| Component | **Vault** (Primary) | SOPS + Age (GitOps) |
|-----------|---------------------|---------------------|
| Secret Type | Dynamic (DB creds, PKI) | Static (configs) |
| Rotation | Automatic | Manual/CI |
| Audit | Built-in | Git history |
| Complexity | Higher | Lower |
| **Best For** | Runtime secrets | Configuration secrets |

**Vault Pattern for Database Credentials:**
```python
import hvac

class VaultClient:
    """Dynamic database credentials from Vault."""

    def __init__(self):
        self.client = hvac.Client(url=settings.vault_addr)
        self.client.auth.kubernetes.login(
            role="voicelearn-api",
            jwt=self._get_service_account_token()
        )

    async def get_db_credentials(self) -> tuple[str, str]:
        """Get short-lived database credentials."""
        secret = self.client.secrets.database.generate_credentials(
            name="voicelearn-readonly"  # or "voicelearn-readwrite"
        )
        return (
            secret["data"]["username"],
            secret["data"]["password"]
        )
        # Credentials auto-expire and rotate
```

---

## 5. Multi-Tenancy Architecture

### 5.1 Isolation Models

```
┌─────────────────────────────────────────────────────────────────────┐
│                     Isolation Spectrum                               │
├─────────────────────────────────────────────────────────────────────┤
│                                                                     │
│  Logical Isolation              │           Physical Isolation      │
│  (Shared Infrastructure)        │           (Dedicated)             │
│                                 │                                   │
│  ┌───────────────────────────┐  │  ┌───────────────────────────┐   │
│  │     Shared Database       │  │  │   Tenant A    │  Tenant B │   │
│  │  ┌─────┬─────┬─────┐     │  │  │   Database    │  Database │   │
│  │  │ T-A │ T-B │ T-C │     │  │  │               │           │   │
│  │  └─────┴─────┴─────┘     │  │  └───────────────┴───────────┘   │
│  │   Row-Level Security      │  │                                  │
│  └───────────────────────────┘  │                                  │
│                                 │                                   │
│  Pros:                          │  Pros:                            │
│  - Cost efficient               │  - Complete isolation             │
│  - Simpler operations           │  - Custom configurations          │
│  - Faster provisioning          │  - Compliance friendly            │
│                                 │                                   │
│  Cons:                          │  Cons:                            │
│  - Noisy neighbor risk          │  - Higher cost                    │
│  - Complex RLS policies         │  - Slower provisioning            │
│                                 │                                   │
│  Use for:                       │  Use for:                         │
│  - Schools, small orgs          │  - Regulated industries           │
│  - Cost-sensitive customers     │  - Data sovereignty needs         │
│                                 │  - High-security requirements     │
│                                 │                                   │
└─────────────────────────────────────────────────────────────────────┘
```

### 5.2 Tenant Context Propagation

Every request must carry tenant context from client to database:

```
┌──────────┐     ┌──────────┐     ┌──────────┐     ┌──────────┐
│  Client  │────▶│ API GW   │────▶│ Service  │────▶│ Database │
│          │     │          │     │          │     │          │
│ JWT with │     │ Extract  │     │ Context  │     │ RLS uses │
│ tenant_id│     │ tenant_id│     │ carries  │     │ tenant_id│
│          │     │          │     │ tenant_id│     │          │
└──────────┘     └──────────┘     └──────────┘     └──────────┘
      │                │                │                │
      │   Auth token   │  X-Tenant-ID   │  SET config    │
      │◀──────────────▶│◀──────────────▶│◀──────────────▶│
```

#### FastAPI Middleware

```python
from contextvars import ContextVar
from fastapi import Request
from starlette.middleware.base import BaseHTTPMiddleware

# Context variable for tenant - accessible anywhere in request
tenant_context: ContextVar[str] = ContextVar("tenant_id")

class TenantMiddleware(BaseHTTPMiddleware):
    async def dispatch(self, request: Request, call_next):
        # Extract from JWT (already validated)
        user = request.state.user
        tenant_id = user.tenant_id

        # Set context variable
        token = tenant_context.set(tenant_id)

        # Set header for downstream services
        request.state.tenant_id = tenant_id

        try:
            response = await call_next(request)
            return response
        finally:
            tenant_context.reset(token)

def get_tenant_id() -> str:
    """Get current tenant from context."""
    return tenant_context.get()
```

#### PostgreSQL Row-Level Security

```sql
-- Enable RLS on tables
ALTER TABLE sessions ENABLE ROW LEVEL SECURITY;
ALTER TABLE curricula ENABLE ROW LEVEL SECURITY;
ALTER TABLE transcripts ENABLE ROW LEVEL SECURITY;

-- Policy: Users can only see their tenant's data
CREATE POLICY tenant_isolation ON sessions
    FOR ALL
    USING (tenant_id = current_setting('app.tenant_id')::uuid);

CREATE POLICY tenant_isolation ON curricula
    FOR ALL
    USING (tenant_id = current_setting('app.tenant_id')::uuid);

-- Set tenant context at connection time
-- (Done by SQLAlchemy event listener)
SET app.tenant_id = 'tenant-uuid-here';
```

#### SQLAlchemy Tenant Context

```python
from sqlalchemy import event
from sqlalchemy.orm import Session

@event.listens_for(Session, "after_begin")
def set_tenant_context(session, transaction, connection):
    """Set PostgreSQL tenant context for RLS."""
    tenant_id = tenant_context.get(None)
    if tenant_id:
        connection.execute(
            text(f"SET app.tenant_id = '{tenant_id}'")
        )
```

### 5.3 iOS Core Data Tenant Support

All Core Data entities must include tenant context:

```swift
// Pattern: Tenant-aware entity
@objc(Session)
public class Session: NSManagedObject {
    @NSManaged public var id: UUID
    @NSManaged public var tenantId: UUID?  // Nullable for migration
    @NSManaged public var ownerId: UUID?   // User who created
    @NSManaged public var startTime: Date
    // ... other fields
}

// Pattern: Tenant-scoped fetch
extension PersistenceController {
    func fetchSessions(tenantId: UUID) -> [Session] {
        let request = Session.fetchRequest()
        request.predicate = NSPredicate(
            format: "tenantId == %@",
            tenantId as CVarArg
        )
        return try? viewContext.fetch(request) ?? []
    }
}
```

### 5.4 Resource Quotas

```python
from pydantic import BaseModel
from enum import Enum

class TenantTier(str, Enum):
    FREE = "free"
    PRO = "pro"
    ENTERPRISE = "enterprise"

class TenantQuotas(BaseModel):
    """Resource limits per tenant tier."""

    tier: TenantTier

    # Session limits
    max_session_duration_minutes: int = 90
    max_concurrent_sessions: int = 10
    max_sessions_per_day: int = 100

    # Storage limits
    max_storage_gb: int = 10
    max_curricula: int = 50
    max_users: int = 100

    # API limits
    requests_per_minute: int = 100
    requests_per_day: int = 10000

    # Feature flags
    voice_cloning_enabled: bool = False
    advanced_analytics_enabled: bool = False
    export_enabled: bool = True
    sso_enabled: bool = False

    @classmethod
    def for_tier(cls, tier: TenantTier) -> "TenantQuotas":
        defaults = {
            TenantTier.FREE: cls(
                tier=tier,
                max_session_duration_minutes=30,
                max_concurrent_sessions=1,
                max_sessions_per_day=10,
                max_storage_gb=1,
                max_curricula=5,
                max_users=5,
                requests_per_minute=20,
                requests_per_day=1000,
            ),
            TenantTier.PRO: cls(
                tier=tier,
                advanced_analytics_enabled=True,
            ),
            TenantTier.ENTERPRISE: cls(
                tier=tier,
                max_concurrent_sessions=100,
                max_sessions_per_day=10000,
                max_storage_gb=1000,
                max_curricula=1000,
                max_users=10000,
                requests_per_minute=1000,
                requests_per_day=1000000,
                voice_cloning_enabled=True,
                advanced_analytics_enabled=True,
                sso_enabled=True,
            ),
        }
        return defaults.get(tier, defaults[TenantTier.FREE])
```

---

## 6. Deployment Models

### 6.1 SaaS Multi-Tenant Architecture

```
┌─────────────────────────────────────────────────────────────────────┐
│                     SaaS Multi-Tenant Architecture                   │
├─────────────────────────────────────────────────────────────────────┤
│                                                                     │
│                    ┌─────────────────────────────┐                  │
│                    │       Load Balancer         │                  │
│                    │   (TLS termination, WAF)    │                  │
│                    └─────────────┬───────────────┘                  │
│                                  │                                  │
│                    ┌─────────────┴───────────────┐                  │
│                    │        API Gateway          │                  │
│                    │  (Rate limit, auth, route)  │                  │
│                    └─────────────┬───────────────┘                  │
│                                  │                                  │
│    ┌──────────────┬──────────────┼──────────────┬──────────────┐   │
│    │              │              │              │              │   │
│ ┌──┴───┐      ┌───┴──┐      ┌───┴──┐      ┌───┴──┐      ┌───┴──┐ │
│ │ Auth │      │Session│     │Curric│      │Analyt│      │ User │ │
│ │ Svc  │      │ Svc   │     │ Svc  │      │ Svc  │      │ Svc  │ │
│ └──┬───┘      └───┬───┘     └───┬──┘      └───┬──┘      └───┬──┘ │
│    │              │             │             │             │     │
│    └──────────────┴─────────────┼─────────────┴─────────────┘     │
│                                 │                                  │
│                    ┌────────────┴────────────┐                     │
│                    │                         │                     │
│              ┌─────┴─────┐             ┌─────┴─────┐               │
│              │ PostgreSQL│             │   Redis   │               │
│              │ (Primary) │             │  (Cache)  │               │
│              └───────────┘             └───────────┘               │
│                                                                     │
└─────────────────────────────────────────────────────────────────────┘
```

### 6.2 On-Premise Architecture

```
┌─────────────────────────────────────────────────────────────────────┐
│                 Customer Data Center / Private Cloud                 │
├─────────────────────────────────────────────────────────────────────┤
│                                                                     │
│  ┌─────────────────────────────────────────────────────────────┐   │
│  │                    Customer Network                          │   │
│  │                                                              │   │
│  │  ┌──────────────┐       ┌────────────────────────────────┐  │   │
│  │  │   Customer   │       │      UnaMentis Cluster        │  │   │
│  │  │   Identity   │◀─────▶│                                │  │   │
│  │  │   (AD/LDAP/  │ SAML/ │  ┌─────────┐   ┌─────────┐    │  │   │
│  │  │   Keycloak)  │ OIDC  │  │ API Pod │   │ API Pod │    │  │   │
│  │  └──────────────┘       │  └─────────┘   └─────────┘    │  │   │
│  │                         │                                │  │   │
│  │  ┌──────────────┐       │  Configuration:               │  │   │
│  │  │   Customer   │◀──────│  - Identity Provider URL      │  │   │
│  │  │   Database   │       │  - Database connection        │  │   │
│  │  │  (PostgreSQL)│       │  - LLM endpoint (local/cloud) │  │   │
│  │  └──────────────┘       │  - Storage path               │  │   │
│  │                         │                                │  │   │
│  │  ┌──────────────┐       └────────────────────────────────┘  │   │
│  │  │  Self-Hosted │                                           │   │
│  │  │  LLM (Ollama)│◀── Optional: Air-gapped inference        │   │
│  │  └──────────────┘                                           │   │
│  │                                                              │   │
│  └─────────────────────────────────────────────────────────────┘   │
│                                                                     │
└─────────────────────────────────────────────────────────────────────┘
```

### 6.3 Configuration Management

```yaml
# config/base.yaml - Shared defaults
voicelearn:
  version: "1.0.0"

  defaults:
    session_duration_max: 90m
    transcript_retention: 30d

  features:
    voice_cloning: false
    advanced_analytics: true

---
# config/saas.yaml - SaaS overlay
voicelearn:
  deployment:
    mode: "saas"
    region: "us-west-2"

  database:
    host: "${DB_HOST}"  # From secrets
    port: 5432
    name: voicelearn
    rls_enabled: true  # Row-Level Security

  identity:
    provider: "keycloak"
    issuer: "https://auth.voicelearn.com/realms/main"

  observability:
    otel_endpoint: "https://otel.voicelearn.com"
    log_level: "INFO"

---
# config/onprem.yaml - On-premise overlay
voicelearn:
  deployment:
    mode: "onprem"

  database:
    host: "${CUSTOMER_DB_HOST}"
    port: 5432
    name: voicelearn
    rls_enabled: false  # Physical isolation

  identity:
    provider: "saml"
    metadata_url: "${CUSTOMER_IDP_METADATA}"

  llm:
    provider: "self-hosted"
    endpoint: "http://ollama.internal:11434"

  observability:
    otel_endpoint: "${CUSTOMER_OTEL_ENDPOINT}"
    log_level: "DEBUG"
```

---

## 7. Audit & Compliance

### 7.1 Audit Event Schema

```json
{
  "event_id": "evt_01HQXYZ123ABC",
  "event_type": "session.create",
  "event_category": "data_access",
  "timestamp": "2024-01-15T10:30:00.000Z",

  "tenant": {
    "id": "tenant-uuid",
    "name": "Acme School District"
  },

  "actor": {
    "type": "user",
    "id": "user-uuid",
    "email": "teacher@acme.edu",
    "ip_address": "192.168.1.100",
    "user_agent": "UnaMentis/1.0 iOS/18.0",
    "session_id": "session-uuid"
  },

  "resource": {
    "type": "session",
    "id": "resource-uuid",
    "name": "Math Tutoring Session",
    "owner_id": "user-uuid"
  },

  "action": "create",
  "outcome": "success",

  "details": {
    "curriculum_id": "curr-uuid",
    "topic_id": "topic-uuid",
    "duration_planned": 3600
  },

  "context": {
    "request_id": "req-uuid",
    "trace_id": "trace-uuid",
    "service": "session-service",
    "service_version": "1.2.3"
  }
}
```

### 7.2 Event Categories

| Category | Event Types | Retention |
|----------|-------------|-----------|
| **Authentication** | login, logout, mfa_challenge, token_refresh, failed_attempt | 2 years |
| **Authorization** | permission_granted, permission_denied, role_assigned, jit_request | 2 years |
| **Data Access** | read, create, update, delete, export, bulk_operation | 2 years |
| **Admin** | user_created, config_changed, tenant_modified, key_rotated | 7 years |
| **Session** | started, ended, interrupted, error | 1 year |
| **System** | service_start, service_stop, health_check, error | 90 days |

### 7.3 Log Aggregation

```
┌──────────────┐    ┌──────────────┐    ┌──────────────┐
│   iOS App    │    │   Web App    │    │   Backend    │
│              │    │              │    │   Services   │
└──────┬───────┘    └──────┬───────┘    └──────┬───────┘
       │                   │                   │
       └───────────────────┼───────────────────┘
                           │
                    ┌──────┴──────┐
                    │ OpenTelemetry│
                    │  Collector   │
                    └──────┬──────┘
                           │
         ┌─────────────────┼─────────────────┐
         │                 │                 │
    ┌────┴────┐      ┌─────┴─────┐     ┌─────┴─────┐
    │  Loki   │      │  Jaeger   │     │Prometheus │
    │ (Logs)  │      │ (Traces)  │     │ (Metrics) │
    └────┬────┘      └─────┬─────┘     └─────┬─────┘
         │                 │                 │
         └─────────────────┴─────────────────┘
                           │
                    ┌──────┴──────┐
                    │   Grafana   │
                    │ (Dashboards)│
                    └─────────────┘
```

### 7.4 Retention Policies

```python
from datetime import timedelta

RETENTION_POLICIES = {
    # Compliance-driven
    "audit_logs": timedelta(days=730),      # 2 years
    "admin_actions": timedelta(days=2555),  # 7 years
    "auth_events": timedelta(days=730),     # 2 years

    # Privacy-driven (shorter)
    "session_recordings": timedelta(days=30),
    "transcripts": timedelta(days=90),
    "session_metadata": timedelta(days=365),

    # Operational
    "system_logs": timedelta(days=90),
    "metrics": timedelta(days=365),
    "traces": timedelta(days=30),
}

async def enforce_retention():
    """Periodic job to delete expired data."""
    for data_type, retention in RETENTION_POLICIES.items():
        cutoff = datetime.utcnow() - retention
        await delete_before(data_type, cutoff)

        # Audit the deletion
        await emit_audit_event(
            event_type="data.retention_cleanup",
            details={"data_type": data_type, "cutoff": cutoff.isoformat()}
        )
```

---

## 8. Current Codebase Compatibility

### 8.1 iOS Changes Required

#### Add AuthenticatedService Protocol

```swift
// New file: UnaMentis/Services/Protocols/AuthenticatedService.swift

/// Protocol for services that support authentication context
public protocol AuthenticatedService: Actor {
    /// Set authentication context for subsequent requests
    func setAuthContext(_ context: AuthContext) async

    /// Clear authentication (logout)
    func clearAuth() async

    /// Current auth state
    var isAuthenticated: Bool { get async }
}

/// Authentication context passed to services
public struct AuthContext: Sendable, Codable {
    public let accessToken: String
    public let tenantId: UUID
    public let userId: UUID
    public let permissions: Set<String>
    public let expiresAt: Date

    public var isValid: Bool {
        Date() < expiresAt
    }

    public func hasPermission(_ permission: String) -> Bool {
        permissions.contains(permission) ||
        permissions.contains(permission.replacingOccurrences(of: ":own", with: ":*"))
    }
}
```

#### Extend Existing Services

```swift
// Extend SelfHostedLLMService to conform to AuthenticatedService
extension SelfHostedLLMService: AuthenticatedService {
    private static var authContexts: [ObjectIdentifier: AuthContext] = [:]

    public func setAuthContext(_ context: AuthContext) async {
        Self.authContexts[ObjectIdentifier(self)] = context
    }

    public func clearAuth() async {
        Self.authContexts.removeValue(forKey: ObjectIdentifier(self))
    }

    public var isAuthenticated: Bool {
        get async {
            Self.authContexts[ObjectIdentifier(self)]?.isValid ?? false
        }
    }

    // Update request building to include auth
    private func addAuthHeaders(to request: inout URLRequest) async {
        if let context = Self.authContexts[ObjectIdentifier(self)] {
            request.setValue(
                "Bearer \(context.accessToken)",
                forHTTPHeaderField: "Authorization"
            )
            request.setValue(
                context.tenantId.uuidString,
                forHTTPHeaderField: "X-Tenant-ID"
            )
        }
    }
}
```

#### Core Data Migration

```swift
// Add to existing entities (nullable for backward compatibility)

// Session+Extensions.swift
extension Session {
    @NSManaged public var tenantId: UUID?
    @NSManaged public var ownerId: UUID?
}

// Curriculum+Extensions.swift
extension Curriculum {
    @NSManaged public var tenantId: UUID?
    @NSManaged public var visibility: String?  // "private", "group", "tenant"
}

// Topic+Extensions.swift
extension Topic {
    @NSManaged public var tenantId: UUID?
}

// Migration helper
class TenantMigration {
    static func migrateToMultiTenant(context: NSManagedObjectContext) {
        // For existing single-user data, assign a "local" tenant
        let localTenantId = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!

        // Migrate sessions
        let sessions = try? context.fetch(Session.fetchRequest())
        sessions?.forEach { session in
            if session.tenantId == nil {
                session.tenantId = localTenantId
            }
        }

        try? context.save()
    }
}
```

### 8.2 Backend Changes Required

#### Migrate to FastAPI

```python
# server/api/main.py

from fastapi import FastAPI, Depends
from fastapi.middleware.cors import CORSMiddleware
from contextlib import asynccontextmanager

from .middleware import TenantMiddleware, AuthMiddleware
from .routers import sessions, curricula, users, analytics
from .database import engine, create_tables

@asynccontextmanager
async def lifespan(app: FastAPI):
    # Startup
    await create_tables()
    yield
    # Shutdown
    await engine.dispose()

app = FastAPI(
    title="UnaMentis API",
    version="1.0.0",
    lifespan=lifespan
)

# Middleware (order matters - auth before tenant)
app.add_middleware(TenantMiddleware)
app.add_middleware(AuthMiddleware)
app.add_middleware(
    CORSMiddleware,
    allow_origins=["https://app.voicelearn.com"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Routers
app.include_router(sessions.router, prefix="/api/sessions", tags=["sessions"])
app.include_router(curricula.router, prefix="/api/curricula", tags=["curricula"])
app.include_router(users.router, prefix="/api/users", tags=["users"])
app.include_router(analytics.router, prefix="/api/analytics", tags=["analytics"])
```

#### SQLAlchemy Models with Tenant

```python
# server/api/models/base.py

from sqlalchemy import Column, ForeignKey
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import declared_attr
import uuid

class TenantMixin:
    """Mixin for tenant-scoped models."""

    @declared_attr
    def tenant_id(cls):
        return Column(
            UUID(as_uuid=True),
            ForeignKey("tenants.id"),
            nullable=False,
            index=True
        )

class Session(Base, TenantMixin):
    __tablename__ = "sessions"

    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    owner_id = Column(UUID(as_uuid=True), ForeignKey("users.id"), nullable=False)
    start_time = Column(DateTime, nullable=False)
    end_time = Column(DateTime)
    duration = Column(Float)
    config = Column(JSONB)

    # Relationships
    owner = relationship("User", back_populates="sessions")
    transcripts = relationship("TranscriptEntry", back_populates="session")
```

### 8.3 Next.js Auth Integration

```typescript
// server/web/src/middleware.ts

import { NextResponse } from 'next/server';
import type { NextRequest } from 'next/server';

export function middleware(request: NextRequest) {
  // Check for auth token
  const token = request.cookies.get('access_token')?.value;

  // Public paths that don't need auth
  const publicPaths = ['/login', '/api/auth', '/_next', '/favicon.ico'];
  const isPublicPath = publicPaths.some(path =>
    request.nextUrl.pathname.startsWith(path)
  );

  if (!token && !isPublicPath) {
    // Redirect to login
    const loginUrl = new URL('/login', request.url);
    loginUrl.searchParams.set('redirect', request.nextUrl.pathname);
    return NextResponse.redirect(loginUrl);
  }

  // Add tenant header for API routes
  if (request.nextUrl.pathname.startsWith('/api/')) {
    const response = NextResponse.next();
    // Token will contain tenant_id - extract and forward
    // (In production, decode JWT and extract tenant_id)
    return response;
  }

  return NextResponse.next();
}

export const config = {
  matcher: ['/((?!_next/static|_next/image|favicon.ico).*)'],
};
```

---

## 9. Implementation Guidelines

### 9.1 DO Patterns

#### Always Include Tenant Context

```swift
// iOS: Every repository method takes tenant
func fetchSessions(tenantId: UUID, userId: UUID) async throws -> [Session]

// iOS: Every API request includes tenant
request.setValue(context.tenantId.uuidString, forHTTPHeaderField: "X-Tenant-ID")
```

```python
# Python: Every query scoped to tenant
async def get_sessions(tenant_id: UUID, user_id: UUID) -> list[Session]:
    return await db.execute(
        select(Session)
        .where(Session.tenant_id == tenant_id)
        .where(Session.owner_id == user_id)
    )
```

#### Always Check Permissions

```swift
// iOS: Check before action
guard await permissionService.hasPermission("session:create:own") else {
    throw AuthorizationError.forbidden
}
```

```python
# Python: Decorator for endpoints
@router.post("/sessions")
@requires_permission("session:create:own")
async def create_session(request: CreateSessionRequest, user: User = Depends(get_user)):
    pass
```

#### Always Emit Audit Events

```python
# Python: Audit all state changes
async def create_session(request: CreateSessionRequest, user: User):
    session = await session_repo.create(request)

    await audit.emit(AuditEvent(
        event_type="session.create",
        actor_id=user.id,
        resource_type="session",
        resource_id=session.id,
        tenant_id=user.tenant_id,
    ))

    return session
```

#### Design for Token Refresh

```swift
// iOS: Handle 401 with refresh
actor APIClient {
    func request<T: Decodable>(_ endpoint: Endpoint) async throws -> T {
        do {
            return try await performRequest(endpoint)
        } catch APIError.unauthorized {
            try await tokenManager.refresh()
            return try await performRequest(endpoint)  // Retry once
        }
    }
}
```

### 9.2 DO NOT Patterns

#### Never Hardcode Tenant or User IDs

```python
# DON'T
sessions = await db.execute("SELECT * FROM sessions WHERE tenant_id = 'abc123'")

# DO
sessions = await db.execute(
    select(Session).where(Session.tenant_id == bindparam("tenant_id")),
    {"tenant_id": current_tenant_id}
)
```

#### Never Store Tokens in UserDefaults

```swift
// DON'T
UserDefaults.standard.set(accessToken, forKey: "access_token")

// DO
try keychain.store(accessToken, forKey: "access_token", accessibility: .afterFirstUnlock)
```

#### Never Skip Permission Checks

```python
# DON'T - assumes caller has permission
async def delete_session(session_id: UUID):
    return await repo.delete(session_id)

# DO - always verify
async def delete_session(session_id: UUID, user: User):
    session = await repo.get(session_id)
    if session.owner_id != user.id and not user.has_permission("session:delete:tenant"):
        raise PermissionDenied()
    return await repo.delete(session_id)
```

#### Never Log Sensitive Data

```python
# DON'T
logger.info(f"User login: email={user.email}, password={password}")

# DO
logger.info(f"User login: user_id={user.id}")
```

### 9.3 Backward Compatibility

| Version | Auth Mode | Behavior |
|---------|-----------|----------|
| 1.x | None | Local-only, no network features requiring auth |
| 2.x | Optional | Auth if available, graceful fallback to local |
| 3.x | Required | Must authenticate for any network features |

```swift
// Pattern: Graceful auth degradation
enum AuthMode {
    case none       // v1: Local only
    case optional   // v2: Auth if available
    case required   // v3: Must auth
}

actor SessionManager {
    private let authMode: AuthMode

    func startSession() async throws -> Session {
        switch authMode {
        case .none:
            return try await startLocalSession()

        case .optional:
            if let auth = await authService.currentAuth {
                return try await startRemoteSession(auth: auth)
            }
            return try await startLocalSession()

        case .required:
            guard let auth = await authService.currentAuth else {
                throw SessionError.authenticationRequired
            }
            return try await startRemoteSession(auth: auth)
        }
    }
}
```

---

## 10. Open Source Stack Recommendations

### 10.1 Complete Stack

```
┌─────────────────────────────────────────────────────────────────────┐
│                        Technology Stack                              │
├─────────────────────────────────────────────────────────────────────┤
│                                                                     │
│  ┌─ Clients ─────────────────────────────────────────────────────┐ │
│  │  iOS App (Swift/SwiftUI)    Web App (Next.js/React/TS)       │ │
│  └───────────────────────────────────────────────────────────────┘ │
│                                │                                    │
│  ┌─ Edge ────────────────────────────────────────────────────────┐ │
│  │  Traefik (API Gateway, TLS, Rate Limiting)                    │ │
│  └───────────────────────────────────────────────────────────────┘ │
│                                │                                    │
│  ┌─ Identity ────────────────────────────────────────────────────┐ │
│  │  Keycloak (OIDC, SAML2, Identity Brokering, MFA)             │ │
│  └───────────────────────────────────────────────────────────────┘ │
│                                │                                    │
│  ┌─ Application ─────────────────────────────────────────────────┐ │
│  │  FastAPI (Python)                                             │ │
│  │  ├─ SQLAlchemy 2.0 (async ORM)                               │ │
│  │  ├─ Pydantic v2 (validation)                                 │ │
│  │  ├─ Authlib (OAuth2 client)                                  │ │
│  │  └─ python-jose (JWT)                                        │ │
│  │                                                               │ │
│  │  Open Policy Agent (Authorization)                            │ │
│  └───────────────────────────────────────────────────────────────┘ │
│                                │                                    │
│  ┌─ Data ────────────────────────────────────────────────────────┐ │
│  │  PostgreSQL (Primary, RLS)   Redis (Cache)   MinIO (Objects) │ │
│  └───────────────────────────────────────────────────────────────┘ │
│                                │                                    │
│  ┌─ Observability ───────────────────────────────────────────────┐ │
│  │  OpenTelemetry → Loki (Logs) + Jaeger (Traces) + Prometheus  │ │
│  │  Grafana (Visualization)                                      │ │
│  └───────────────────────────────────────────────────────────────┘ │
│                                │                                    │
│  ┌─ Secrets ─────────────────────────────────────────────────────┐ │
│  │  HashiCorp Vault (Dynamic)   SOPS+Age (GitOps)               │ │
│  └───────────────────────────────────────────────────────────────┘ │
│                                                                     │
└─────────────────────────────────────────────────────────────────────┘
```

### 10.2 Component Selection Matrix

| Component | Primary | Alternative | When to Use Alternative |
|-----------|---------|-------------|-------------------------|
| **API Gateway** | Traefik | Kong | Need enterprise features, plugin ecosystem |
| **Identity** | Keycloak | Authentik | Smaller deployment, simpler needs |
| **Authorization** | OPA | Casbin | Simple RBAC only, embedded preferred |
| **Database** | PostgreSQL | - | No alternative recommended |
| **Cache** | Redis | - | No alternative recommended |
| **Object Store** | MinIO | S3 | Using AWS |
| **Logs** | Loki | Elasticsearch | Need full-text search |
| **Traces** | Jaeger | Zipkin | Simpler deployment |
| **Metrics** | Prometheus | - | No alternative recommended |
| **Secrets** | Vault | SOPS | Simple static secrets only |

---

## 11. Phased Implementation Roadmap

### Phase 1: Foundation (Database & Models)

**Goal:** Migrate from in-memory to persistent storage with user/tenant models.

**Tasks:**
- [ ] Set up PostgreSQL with Alembic migrations
- [ ] Define SQLAlchemy models: User, Tenant, Organization
- [ ] Migrate existing Python backend from aiohttp to FastAPI
- [ ] Add tenantId/ownerId to iOS Core Data entities (nullable)
- [ ] Implement basic audit event emission
- [ ] Set up OpenTelemetry collector

**Key Files:**
- `server/api/` - New FastAPI application
- `server/api/models/` - SQLAlchemy models
- `server/api/migrations/` - Alembic migrations

### Phase 2: Authentication

**Goal:** Implement SSO with Keycloak.

**Tasks:**
- [ ] Deploy Keycloak with OIDC realm
- [ ] Implement OIDC flow in Next.js frontend
- [ ] Add JWT validation middleware to FastAPI
- [ ] Extend iOS APIKeyManager for OAuth tokens
- [ ] Implement token refresh on all clients
- [ ] Add login/logout UI flows

**Key Files:**
- `server/web/src/app/(auth)/` - Auth pages
- `server/api/middleware/auth.py` - JWT validation
- `UnaMentis/Core/Auth/` - New iOS auth module

### Phase 3: Authorization & RBAC

**Goal:** Implement permission model and enforcement.

**Tasks:**
- [ ] Define permission model in database
- [ ] Implement role hierarchy
- [ ] Add OPA or Casbin integration
- [ ] Create permission-aware iOS view modifiers
- [ ] Add authorization middleware to all endpoints
- [ ] Build role management admin UI

**Key Files:**
- `server/api/authz/` - Authorization module
- `UnaMentis/Core/Auth/PermissionService.swift`

### Phase 4: Multi-Tenancy

**Goal:** Complete tenant isolation.

**Tasks:**
- [ ] Implement PostgreSQL Row-Level Security
- [ ] Add tenant context propagation middleware
- [ ] Update all queries to be tenant-scoped
- [ ] Implement iOS tenant-aware Core Data queries
- [ ] Add resource quotas per tenant
- [ ] Build tenant admin portal

**Key Files:**
- `server/api/middleware/tenant.py`
- `server/api/migrations/add_rls.py`

### Phase 5: Enterprise Deployment

**Goal:** Production-ready enterprise features.

**Tasks:**
- [ ] Docker/Kubernetes manifests
- [ ] Helm charts for on-premise deployment
- [ ] Add SAML2 support to Keycloak config
- [ ] Implement data encryption at rest
- [ ] Build compliance reporting dashboards
- [ ] Create deployment documentation

**Key Files:**
- `deploy/kubernetes/`
- `deploy/helm/`
- `docs/deployment/`

### Phase 6: Advanced Security

**Goal:** Enterprise-grade security features.

**Tasks:**
- [ ] Implement JIT access system
- [ ] Add step-up authentication flows
- [ ] Build anomaly detection rules
- [ ] Implement API rate limiting
- [ ] Security audit preparation
- [ ] Penetration testing remediation

---

## Appendix A: API Error Codes

| Code | HTTP Status | Description |
|------|-------------|-------------|
| `AUTH_TOKEN_EXPIRED` | 401 | Access token has expired |
| `AUTH_TOKEN_INVALID` | 401 | Token signature invalid |
| `AUTH_MFA_REQUIRED` | 401 | MFA step-up required |
| `AUTHZ_FORBIDDEN` | 403 | Permission denied |
| `TENANT_NOT_FOUND` | 404 | Tenant does not exist |
| `TENANT_SUSPENDED` | 403 | Tenant account suspended |
| `QUOTA_EXCEEDED` | 429 | Resource quota exceeded |
| `RATE_LIMITED` | 429 | Too many requests |

## Appendix B: Environment Variables

| Variable | Description | Required |
|----------|-------------|----------|
| `DATABASE_URL` | PostgreSQL connection string | Yes |
| `REDIS_URL` | Redis connection string | Yes |
| `KEYCLOAK_URL` | Keycloak issuer URL | Yes |
| `JWT_PUBLIC_KEY` | Public key for JWT verification | Yes |
| `VAULT_ADDR` | HashiCorp Vault address | Production |
| `OTEL_EXPORTER_OTLP_ENDPOINT` | OpenTelemetry collector | Yes |

---

*This document is maintained by the UnaMentis architecture team. For questions or updates, create an issue in the repository.*
