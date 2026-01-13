# Security & Scaling Guide

Overview of UnaMentis security architecture and scaling roadmap.

## Current Assessment

| Category | Current State | Production Readiness |
|----------|---------------|---------------------|
| **Authentication** | Basic | Beta ready |
| **Multi-Tenancy** | None | Requires implementation |
| **Data Encryption** | iOS Keychain | Partial |
| **Network Security** | HTTPS for cloud | Partial |
| **Privacy Compliance** | Export/deletion exists | Partial |

## Security Highlights

### API Key Management

- iOS Keychain with `kSecAttrAccessibleAfterFirstUnlock`
- Actor-based isolation prevents race conditions
- Secure storage for all provider API keys

### Network Security

| Service | Protocol | Status |
|---------|----------|--------|
| OpenAI | HTTPS | Secure |
| Anthropic | HTTPS | Secure |
| Deepgram | WSS | Secure |
| ElevenLabs | WSS | Secure |
| Self-hosted | HTTP | Local network only |

### Data at Rest

| Data | Protection |
|------|------------|
| API Keys | iOS Keychain encryption |
| UserDefaults | iOS Data Protection |
| Core Data | iOS Data Protection |
| Model files | None (not sensitive) |

## Privacy Architecture

### Tier 1: Maximum Privacy (On-Device)

- STT: Apple Speech Recognition, GLM-ASR On-Device
- TTS: Apple AVSpeechSynthesizer
- LLM: On-device MLX models
- VAD: Silero (already on-device)
- **Data exposure:** ZERO

### Tier 2: High Privacy (Self-Hosted)

- STT: Self-hosted Whisper
- TTS: Piper or VibeVoice
- LLM: Ollama with Llama/Mistral
- **Data exposure:** Internal network only

### Tier 3: Standard Privacy (Cloud with DPA)

- Use cloud providers with signed DPAs
- Require zero-retention policies
- Require SOC 2 Type II compliance
- **Data exposure:** Third-party (contractually protected)

## Scaling Roadmap

### Phase 1: Beta (10-50 Users)

Current architecture with security fixes:
- Add API key authentication
- Enable HTTPS (Let's Encrypt)
- Implement Core Data encryption
- Add consent tracking
- Create privacy policy

### Phase 2: Early Adopters (50-1,000 Users)

Proper backend architecture:
- Migrate to PostgreSQL
- Add connection pooling
- Horizontal scaling for management console
- Redis for session storage
- Rate limiting and input validation

### Phase 3: Growth (1,000-100,000 Users)

Multi-tenant and geographic distribution:
- Kubernetes deployment
- Multi-region PostgreSQL
- Tenant isolation
- Data residency compliance
- SOC 2 Type II preparation

### Phase 4: Scale (100,000+ Users)

Enterprise-grade architecture:
- Service mesh with mTLS
- Customer-managed keys (BYOK)
- Compliance certifications
- 24/7 security operations
- Bug bounty program

## Multi-Tenancy Models

| Tier | Isolation Model | Use Case |
|------|-----------------|----------|
| Free/Individual | Shared DB + RLS | Individual learners |
| Team | Separate Schema | Small orgs (< 100 users) |
| Enterprise | Separate Database | Large orgs (100+ users) |
| Regulated | Dedicated Infrastructure | Healthcare, government |

## Privacy Compliance

| Requirement | Status |
|-------------|--------|
| Right to Access | Export exists |
| Right to Deletion | Clear all exists |
| Right to Portability | JSON export |
| Consent Collection | Toggle exists |
| Data Retention Limits | None (needs implementation) |

## Full Documentation

See `docs/SCALING_SECURITY_MULTITENANCY_ANALYSIS.md` for the complete analysis including:
- Detailed vulnerability assessment
- Input validation requirements
- Rate limiting configuration
- Database schema changes
- Implementation priorities

---

Back to [[Architecture]] | [[Home]]
