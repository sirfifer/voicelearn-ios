# UnaMentis OpenTelemetry Architecture Specification

## Overview

This document specifies the OpenTelemetry (OTel) infrastructure for UnaMentis, providing rich performance metrics, distributed tracing, and analytics capabilities. The architecture is designed to:

1. **Unify observability** - Same metrics visible in-app and in dashboards
2. **Enable AI agent access** - HTTP API endpoints for programmatic analysis
3. **Support local and remote access** - Work on localhost and over the internet
4. **Integrate with existing logging** - Complement the RemoteLogHandler infrastructure

---

## Stack Recommendation: SigNoz

After evaluating options, **SigNoz** is recommended over Grafana LGTM stack for the following reasons:

| Criteria | SigNoz | Grafana LGTM |
|----------|--------|--------------|
| **Ease of Setup** | Single Docker Compose | 4+ separate services |
| **Backend Complexity** | Single (ClickHouse) | Multiple (Loki, Tempo, Mimir) |
| **OpenTelemetry Native** | Yes, built for OTel | Requires Alloy/Collector config |
| **Self-Hosted Maintenance** | Low | High |
| **Unified UI** | Logs + Metrics + Traces in one | Separate views |
| **API Access** | REST API included | Requires additional setup |

### Alternative: Grafana LGTM Stack

If you prefer Grafana's ecosystem:
- **Loki** for logs
- **Tempo** for traces
- **Mimir** for metrics
- **Grafana Alloy** as OTel collector

Both options support the same OpenTelemetry protocols from the iOS app.

---

## Architecture Diagram

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                           UnaMentis iOS App                                 │
│  ┌─────────────────┐  ┌─────────────────┐  ┌─────────────────────────────┐  │
│  │ TelemetryEngine │  │ OTelExporter    │  │ RemoteLogHandler            │  │
│  │ (existing)      │──│ (new)           │  │ (existing - port 8765)      │  │
│  │                 │  │                 │  │                             │  │
│  │ - Latency       │  │ - Metrics       │  │ - Debug logs                │  │
│  │ - Costs         │  │ - Traces        │  │ - Events                    │  │
│  │ - Events        │  │ - Spans         │  │                             │  │
│  └────────┬────────┘  └────────┬────────┘  └─────────────┬───────────────┘  │
│           │                    │                         │                   │
└───────────┼────────────────────┼─────────────────────────┼───────────────────┘
            │                    │                         │
            │          OTLP/gRPC │ (port 4317)             │ HTTP (port 8765)
            │          OTLP/HTTP │ (port 4318)             │
            ▼                    ▼                         ▼
┌───────────────────────────────────────────────────────────────────────────────┐
│                        Host Machine (Mac)                                      │
│                                                                                │
│  ┌──────────────────────────────────────────────────┐  ┌───────────────────┐  │
│  │           SigNoz (Docker Compose)                 │  │ Log Server        │  │
│  │                                                   │  │ (Python)          │  │
│  │  ┌─────────────┐  ┌─────────────┐                │  │                   │  │
│  │  │ OTel        │  │ ClickHouse  │                │  │ Port 8765         │  │
│  │  │ Collector   │  │ Database    │                │  │                   │  │
│  │  │ Port 4317/18│  │             │                │  └───────────────────┘  │
│  │  └──────┬──────┘  └──────┬──────┘                │                         │
│  │         │                │                        │                         │
│  │         ▼                ▼                        │                         │
│  │  ┌───────────────────────────────────────────┐   │                         │
│  │  │           SigNoz Web UI                    │   │                         │
│  │  │           Port 3301                        │   │                         │
│  │  │                                            │   │                         │
│  │  │  • Traces Explorer                         │   │                         │
│  │  │  • Metrics Dashboard                       │   │                         │
│  │  │  • Logs Viewer                             │   │                         │
│  │  │  • Alerts                                  │   │                         │
│  │  │  • REST API                                │   │                         │
│  │  └────────────────────────────────────────────┘   │                         │
│  └───────────────────────────────────────────────────┘                         │
│                                                                                │
│  ┌─────────────────────────────────────────────────────────────────────────┐  │
│  │                     Optional: Cloudflare Tunnel                          │  │
│  │                     (for remote AI agent access)                         │  │
│  │                                                                          │  │
│  │  Local:   http://localhost:3301                                          │  │
│  │  Remote:  https://voicelearn-otel.your-tunnel.com                        │  │
│  └─────────────────────────────────────────────────────────────────────────┘  │
│                                                                                │
└────────────────────────────────────────────────────────────────────────────────┘
```

---

## Metrics Specification

### Current TelemetryEngine Metrics (to be exported via OTel)

#### Latency Metrics (Histograms)
| Metric Name | Unit | Description |
|-------------|------|-------------|
| `voicelearn.stt.latency` | ms | Speech-to-text emission time |
| `voicelearn.llm.first_token_latency` | ms | Time to first LLM token |
| `voicelearn.tts.ttfb` | ms | TTS time to first byte |
| `voicelearn.turn.e2e_latency` | ms | End-to-end turn latency |
| `voicelearn.audio.processing_latency` | ms | Audio buffer processing time |

#### Cost Metrics (Counters)
| Metric Name | Unit | Description |
|-------------|------|-------------|
| `voicelearn.cost.stt` | USD | Cumulative STT cost |
| `voicelearn.cost.tts` | USD | Cumulative TTS cost |
| `voicelearn.cost.llm` | USD | Cumulative LLM cost |
| `voicelearn.cost.total` | USD | Total session cost |

#### Session Metrics (Gauges/Counters)
| Metric Name | Type | Description |
|-------------|------|-------------|
| `voicelearn.session.duration` | gauge | Current session duration (seconds) |
| `voicelearn.session.turns` | counter | Total conversation turns |
| `voicelearn.session.interruptions` | counter | User interruption count |
| `voicelearn.session.thermal_throttle_events` | counter | Thermal throttling occurrences |

#### Device Metrics (Gauges)
| Metric Name | Type | Description |
|-------------|------|-------------|
| `voicelearn.device.memory_available` | gauge | Available memory (MB) |
| `voicelearn.device.thermal_state` | gauge | 0=nominal, 1=fair, 2=serious, 3=critical |
| `voicelearn.device.battery_level` | gauge | Battery percentage (0-1) |

### Proposed Additional Metrics

#### Model Performance
| Metric Name | Type | Description |
|-------------|------|-------------|
| `voicelearn.model.load_time` | histogram | On-device model load time |
| `voicelearn.model.inference_time` | histogram | Per-inference latency |
| `voicelearn.model.tokens_per_second` | gauge | Generation throughput |
| `voicelearn.model.memory_usage` | gauge | Model memory footprint (MB) |

#### Network Quality
| Metric Name | Type | Description |
|-------------|------|-------------|
| `voicelearn.network.type` | gauge | 0=none, 1=wifi, 2=cellular |
| `voicelearn.network.latency` | histogram | Network round-trip time |
| `voicelearn.network.failures` | counter | Request failures |

---

## Trace Specification

### Span Hierarchy

```
Session (root span)
├── Turn (conversation turn)
│   ├── STT
│   │   ├── audio_capture
│   │   ├── vad_detection
│   │   └── transcription
│   ├── LLM
│   │   ├── context_preparation
│   │   ├── inference
│   │   └── response_streaming
│   └── TTS
│       ├── synthesis
│       └── playback
├── Turn (next turn)
│   └── ...
└── Session End
```

### Span Attributes

```swift
// Session span
span.setAttribute("session.id", sessionId)
span.setAttribute("session.device_tier", "proMax")
span.setAttribute("session.mode", "onDevice|cloud|hybrid")

// STT span
span.setAttribute("stt.provider", "glm-asr|whisper|deepgram")
span.setAttribute("stt.duration_ms", 1250)
span.setAttribute("stt.transcript_length", 45)
span.setAttribute("stt.is_final", true)

// LLM span
span.setAttribute("llm.provider", "onDevice|openai|anthropic")
span.setAttribute("llm.model", "llama-3b|gpt-4o|claude-3.5")
span.setAttribute("llm.input_tokens", 150)
span.setAttribute("llm.output_tokens", 200)
span.setAttribute("llm.temperature", 0.7)

// TTS span
span.setAttribute("tts.provider", "apple|elevenlabs")
span.setAttribute("tts.text_length", 200)
span.setAttribute("tts.duration_ms", 3500)
```

---

## Integration with Existing Infrastructure

### Relationship to RemoteLogHandler

| Aspect | RemoteLogHandler | OpenTelemetry |
|--------|------------------|---------------|
| **Purpose** | Debug logging | Performance analytics |
| **Data Type** | Text logs with metadata | Structured metrics + traces |
| **Retention** | In-memory buffer (5000) | Persistent (ClickHouse) |
| **Visualization** | Simple web table | Rich dashboards |
| **Querying** | Basic search | SQL queries, aggregations |

**Recommendation**: Keep both systems. They serve different purposes:
- **RemoteLogHandler**: Real-time debugging during development
- **OpenTelemetry**: Long-term performance analysis and trending

### Bridge Implementation

The existing `TelemetryEngine` can export to OpenTelemetry via a new `OTelExporter` component:

```swift
// Conceptual API (to be implemented)
public actor OTelExporter {
    private let tracer: Tracer
    private let meter: Meter

    /// Export latency as histogram
    func exportLatency(_ type: LatencyType, _ value: TimeInterval) {
        let histogram = meter.createDoubleHistogram(name: "voicelearn.\(type.rawValue)")
        histogram.record(value: value * 1000) // Convert to ms
    }

    /// Start a trace span
    func startSpan(name: String, attributes: [String: AttributeValue]) -> Span {
        tracer.spanBuilder(spanName: name)
            .setSpanKind(.client)
            .startSpan()
    }
}
```

---

## Installation & Setup

### Prerequisites

- Docker Desktop for Mac
- 4GB+ RAM available for containers
- Ports 3301, 4317, 4318 available

### Quick Start (SigNoz)

```bash
# Create telemetry directory
mkdir -p telemetry && cd telemetry

# Clone SigNoz
git clone -b main https://github.com/SigNoz/signoz.git
cd signoz/deploy

# Start SigNoz
docker compose -f docker/clickhouse-setup/docker-compose.yaml up -d

# Verify
open http://localhost:3301
```

### Service Management Script

A script similar to `setup_log_service.sh` will be provided:

```bash
./scripts/setup_telemetry_service.sh install   # Install and start
./scripts/setup_telemetry_service.sh status    # Check status
./scripts/setup_telemetry_service.sh stop      # Stop services
./scripts/setup_telemetry_service.sh logs      # View logs
```

---

## iOS SDK Integration

### Dependencies (Package.swift)

```swift
dependencies: [
    .package(url: "https://github.com/open-telemetry/opentelemetry-swift", from: "1.10.0"),
]
```

### Instrumentation Packages

| Package | Purpose |
|---------|---------|
| `OpenTelemetryApi` | Core API for creating spans/metrics |
| `OpenTelemetrySdk` | SDK implementation |
| `OtlpGRPCExporter` | Export to collector via gRPC (recommended) |
| `URLSessionInstrumentation` | Auto-instrument network calls |
| `SDKResourceExtension` | Device/app info as resource attributes |

---

## API Access for AI Agents

### Local Access

```bash
# Query traces
curl http://localhost:3301/api/v1/traces?service=voicelearn

# Query metrics
curl http://localhost:3301/api/v1/metrics?name=voicelearn.llm.first_token_latency

# Get dashboard data
curl http://localhost:3301/api/v1/dashboards
```

### Remote Access (via Cloudflare Tunnel)

For AI agents running in the cloud (Claude Code, GPT CodeX):

```bash
# Install cloudflared
brew install cloudflare/cloudflare/cloudflared

# Create tunnel (one-time)
cloudflared tunnel create voicelearn-otel

# Run tunnel
cloudflared tunnel run --url http://localhost:3301 voicelearn-otel
```

Then configure the AI agent with:
- **URL**: `https://voicelearn-otel.cfargotunnel.com`
- **API Key**: (configured in SigNoz)

### Security Considerations

1. **Local-only by default** - No external exposure until tunnel configured
2. **API key authentication** - SigNoz supports API keys
3. **Read-only access** - AI agents should only query, not modify
4. **Tunnel authentication** - Cloudflare Access can add SSO/OAuth

---

## Dashboard Specifications

### Pre-built Dashboards

#### 1. Session Overview
- Session count, avg duration
- Total turns, interruption rate
- Cost breakdown (pie chart)
- E2E latency trend

#### 2. Latency Analysis
- STT/LLM/TTS latency histograms
- P50/P95/P99 over time
- Latency by provider comparison
- Slowest traces list

#### 3. Cost Tracking
- Cost per hour trend
- Cost by service (STT/LLM/TTS)
- Token usage breakdown
- Budget alerts

#### 4. Device Performance
- Thermal state distribution
- Memory pressure events
- Battery impact analysis
- Model inference throughput

### Custom Query Examples

```sql
-- Average E2E latency by provider
SELECT
  JSONExtractString(attributes, 'llm.provider') as provider,
  avg(duration_ms) as avg_latency
FROM spans
WHERE name = 'Turn'
GROUP BY provider

-- Cost per session
SELECT
  session_id,
  sum(value) as total_cost
FROM metrics
WHERE name = 'voicelearn.cost.total'
GROUP BY session_id
```

---

## Implementation Phases

### Phase 1: Infrastructure Setup (Week 1)
- [ ] Deploy SigNoz via Docker Compose
- [ ] Create service management script
- [ ] Verify OTLP endpoints accessible
- [ ] Document setup process

### Phase 2: Basic iOS Integration (Week 2)
- [ ] Add opentelemetry-swift to Package.swift
- [ ] Create OTelExporter wrapper
- [ ] Export existing TelemetryEngine metrics
- [ ] Verify metrics appear in SigNoz

### Phase 3: Tracing (Week 3)
- [ ] Implement span hierarchy for conversation turns
- [ ] Add span attributes for all providers
- [ ] Enable URLSessionInstrumentation
- [ ] Test trace visualization

### Phase 4: Dashboards & API (Week 4)
- [ ] Create pre-built dashboards
- [ ] Configure API access
- [ ] Set up Cloudflare Tunnel (optional)
- [ ] Document API endpoints for AI agents

---

## Files to Create

| File | Purpose |
|------|---------|
| `UnaMentis/Core/Telemetry/OTelExporter.swift` | OpenTelemetry export wrapper |
| `UnaMentis/Core/Telemetry/SpanManager.swift` | Trace span lifecycle management |
| `scripts/setup_telemetry_service.sh` | Service management script |
| `telemetry/docker-compose.yml` | SigNoz configuration |
| `telemetry/dashboards/` | Pre-built dashboard JSON |
| `docs/TELEMETRY_API.md` | API documentation for AI agents |

---

## References

### OpenTelemetry Swift
- [Official Documentation](https://opentelemetry.io/docs/languages/swift/)
- [GitHub Repository](https://github.com/open-telemetry/opentelemetry-swift)
- [Getting Started Guide](https://opentelemetry.io/docs/languages/swift/getting-started/)

### SigNoz
- [SigNoz Documentation](https://signoz.io/docs/)
- [Docker Installation](https://signoz.io/docs/install/docker/)
- [API Reference](https://signoz.io/docs/userguide/query-builder/)

### Grafana Alternative
- [Grafana LGTM Stack](https://grafana.com/docs/opentelemetry/)
- [Grafana Alloy](https://grafana.com/oss/alloy-opentelemetry-collector/)
- [Docker Compose Setup](https://grafana.com/docs/tempo/latest/set-up-for-tracing/setup-tempo/deploy/locally/docker-compose/)

### Mobile Observability
- [Embrace OpenTelemetry](https://embrace.io/opentelemetry-for-mobile/)
- [iOS Instrumentation](https://signoz.io/docs/instrumentation/mobile-instrumentation/opentelemetry-swiftui/)

---

## Decision Log

| Date | Decision | Rationale |
|------|----------|-----------|
| 2025-12-16 | SigNoz over Grafana LGTM | Simpler self-hosted setup, single backend |
| 2025-12-16 | Keep RemoteLogHandler | Different purpose (debug vs analytics) |
| 2025-12-16 | OTLP/gRPC preferred | Production-ready in opentelemetry-swift |
| 2025-12-16 | Cloudflare Tunnel for remote | Secure, no port forwarding needed |

---

## Questions for Future Consideration

1. **Data retention policy**: How long to keep metrics/traces?
2. **Sampling strategy**: Sample all traces or just errors/slow?
3. **Alert configuration**: What thresholds trigger alerts?
4. **Multi-device correlation**: Track same user across devices?
